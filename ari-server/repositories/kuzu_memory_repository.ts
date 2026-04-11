import path from "path";
import crypto from "crypto";
import { DATA_DIR, ensureDirSync } from "../infra/data.js";
import { logger } from "../infra/logger.js";
import { EMBEDDING_DIM } from "../services/embedding.js";

const KUZU_DIR = path.join(DATA_DIR, "kuzu_memory");

let db: any = null;
let conn: any = null;

// ─────────────────────────────────────────────
// 연결 및 스키마
// ─────────────────────────────────────────────

async function getConnection(): Promise<any> {
  if (conn) return conn;

  ensureDirSync(KUZU_DIR);
  const kuzu = await import("kuzu");
  db = new kuzu.default.Database(KUZU_DIR);
  conn = new kuzu.default.Connection(db);
  await initSchema();
  return conn;
}

async function tryQuery(c: any, cypher: string): Promise<void> {
  try {
    const r = await c.query(cypher);
    r.close?.();
  } catch (e: any) {
    if (!e.message?.includes("already exists")) {
      logger.error(`[KuzuMemory] 쿼리 실패: ${e.message}\n${cypher}`);
      throw e;
    }
  }
}

async function initSchema(): Promise<void> {
  const c = conn;

  // ── 노드 테이블 ──────────────────────────────
  await tryQuery(c, `
    CREATE NODE TABLE Memory(
      id        STRING,
      agentId   STRING,
      content   STRING,
      memType   STRING,
      importance STRING,
      ts        INT64,
      embedding FLOAT[${EMBEDDING_DIM}],
      PRIMARY KEY(id)
    )
  `);

  await tryQuery(c, `
    CREATE NODE TABLE Entity(
      id         STRING,
      name       STRING,
      entityType STRING,
      PRIMARY KEY(id)
    )
  `);

  await tryQuery(c, `
    CREATE NODE TABLE Topic(
      id   STRING,
      name STRING,
      PRIMARY KEY(id)
    )
  `);

  // ── 엣지 테이블 ──────────────────────────────
  await tryQuery(c, `CREATE REL TABLE MENTIONS(FROM Memory TO Entity)`);
  await tryQuery(c, `CREATE REL TABLE ABOUT(FROM Memory TO Topic)`);
  await tryQuery(c, `CREATE REL TABLE FOLLOWS(FROM Memory TO Memory)`);

  logger.info(`[KuzuMemory] 스키마 준비 완료`);
}

// ─────────────────────────────────────────────
// 내부 유틸
// ─────────────────────────────────────────────

function esc(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

async function fetchOne(c: any, cypher: string): Promise<Record<string, any> | null> {
  const r = await c.query(cypher);
  const rows = await r.getAll();
  r.close?.();
  return rows.length > 0 ? rows[0] : null;
}

/** Entity를 찾거나 없으면 생성하고 id를 반환 */
async function upsertEntity(c: any, name: string, entityType: string): Promise<string> {
  const existing = await fetchOne(
    c,
    `MATCH (e:Entity) WHERE e.name = '${esc(name)}' AND e.entityType = '${esc(entityType)}' RETURN e.id AS id`,
  );
  if (existing) return existing.id as string;

  const id = crypto.randomUUID();
  await tryQuery(c, `CREATE (:Entity {id: '${id}', name: '${esc(name)}', entityType: '${esc(entityType)}'})`);
  return id;
}

/** Topic을 찾거나 없으면 생성하고 id를 반환 */
async function upsertTopic(c: any, name: string): Promise<string> {
  const existing = await fetchOne(
    c,
    `MATCH (t:Topic) WHERE t.name = '${esc(name)}' RETURN t.id AS id`,
  );
  if (existing) return existing.id as string;

  const id = crypto.randomUUID();
  await tryQuery(c, `CREATE (:Topic {id: '${id}', name: '${esc(name)}'})`);
  return id;
}

/** 같은 에이전트의 직전 Memory id를 반환 */
async function getLastMemoryId(c: any, agentId: string): Promise<string | null> {
  const row = await fetchOne(
    c,
    `MATCH (m:Memory) WHERE m.agentId = '${esc(agentId)}' RETURN m.id AS id, m.ts AS ts ORDER BY m.ts DESC LIMIT 1`,
  );
  return row ? (row.id as string) : null;
}

function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom === 0 ? 0 : dot / denom;
}

// ─────────────────────────────────────────────
// 공개 API
// ─────────────────────────────────────────────

export type MemoryType = "core" | "daily";
export type Importance = "low" | "normal" | "high";

export interface EntityInput {
  name: string;
  type?: "person" | "tool" | "concept" | "place" | "other";
}

export interface InsertMemoryOptions {
  agentId: string;
  content: string;
  memType: MemoryType;
  embedding: number[];
  topics?: string[];
  entities?: EntityInput[];
  importance?: Importance;
}

export interface MemorySearchResult {
  content: string;
  memType: string;
  importance: string;
  score: number;
  topics: string[];
  entities: Array<{ name: string; type: string }>;
}

/**
 * 메모리 노드를 그래프에 삽입하고 Entity/Topic 노드와 연결합니다.
 */
export async function insertMemoryNode(opts: InsertMemoryOptions): Promise<void> {
  const c = await getConnection();
  const {
    agentId, content, memType, embedding,
    topics = [], entities = [], importance = "normal",
  } = opts;

  const id = crypto.randomUUID();
  const ts = Date.now();
  const embStr = `[${embedding.join(",")}]`;

  // 1. Memory 노드 생성
  await tryQuery(c, `
    CREATE (:Memory {
      id: '${id}',
      agentId: '${esc(agentId)}',
      content: '${esc(content)}',
      memType: '${memType}',
      importance: '${importance}',
      ts: ${ts},
      embedding: ${embStr}
    })
  `);

  // 2. FOLLOWS 엣지 — 직전 Memory와 시간 순서 연결
  const prevId = await getLastMemoryId(c, agentId);
  if (prevId && prevId !== id) {
    await tryQuery(c, `
      MATCH (prev:Memory {id: '${prevId}'}), (cur:Memory {id: '${id}'})
      CREATE (prev)-[:FOLLOWS]->(cur)
    `);
  }

  // 3. Entity 노드 upsert + MENTIONS 엣지
  for (const ent of entities) {
    const entityType = ent.type ?? "concept";
    const entId = await upsertEntity(c, ent.name, entityType);
    await tryQuery(c, `
      MATCH (m:Memory {id: '${id}'}), (e:Entity {id: '${entId}'})
      CREATE (m)-[:MENTIONS]->(e)
    `);
  }

  // 4. Topic 노드 upsert + ABOUT 엣지
  for (const topicName of topics) {
    const topicId = await upsertTopic(c, topicName);
    await tryQuery(c, `
      MATCH (m:Memory {id: '${id}'}), (t:Topic {id: '${topicId}'})
      CREATE (m)-[:ABOUT]->(t)
    `);
  }
}

/**
 * 벡터 유사도 기반으로 관련 메모리를 검색합니다.
 * 각 결과에 연결된 Entity와 Topic 정보도 함께 반환합니다.
 */
export async function searchMemoryNodes(
  agentId: string,
  queryEmbedding: number[],
  topK: number = 5,
): Promise<MemorySearchResult[]> {
  const c = await getConnection();

  // 전체 Memory + 연결 정보를 한 번에 가져오기
  const r = await c.query(`
    MATCH (m:Memory)
    WHERE m.agentId = '${esc(agentId)}'
    OPTIONAL MATCH (m)-[:MENTIONS]->(e:Entity)
    OPTIONAL MATCH (m)-[:ABOUT]->(t:Topic)
    RETURN
      m.id AS id,
      m.content AS content,
      m.memType AS memType,
      m.importance AS importance,
      m.embedding AS embedding,
      collect(DISTINCT t.name) AS topics,
      collect(DISTINCT {name: e.name, type: e.entityType}) AS entities
  `);

  const rows: any[] = await r.getAll();
  r.close?.();

  if (!rows || rows.length === 0) return [];

  // 중요도에 따른 가중치
  const importanceWeight: Record<string, number> = { high: 1.2, normal: 1.0, low: 0.8 };

  return rows
    .map((row) => {
      const baseSim = cosineSimilarity(queryEmbedding, row.embedding);
      const weight = importanceWeight[row.importance] ?? 1.0;
      return {
        content: row.content as string,
        memType: row.memType as string,
        importance: row.importance as string,
        score: baseSim * weight,
        topics: (row.topics as string[]).filter(Boolean),
        entities: (row.entities as any[]).filter((e) => e?.name),
      };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

/**
 * core 타입 메모리 전체 삭제 (MEMORY.md 교체 시)
 */
export async function deleteCoreMemoryNodes(agentId: string): Promise<void> {
  const c = await getConnection();
  await tryQuery(c, `
    MATCH (m:Memory)
    WHERE m.agentId = '${esc(agentId)}' AND m.memType = 'core'
    DETACH DELETE m
  `);
}

/**
 * 에이전트의 모든 메모리 삭제
 */
export async function deleteAllMemoryNodes(agentId: string): Promise<void> {
  const c = await getConnection();
  await tryQuery(c, `
    MATCH (m:Memory)
    WHERE m.agentId = '${esc(agentId)}'
    DETACH DELETE m
  `);
}

export interface MemoryStats {
  coreCount: number;
  dailyCount: number;
  entityCount: number;
  topicCount: number;
  mentionsCount: number;
  aboutCount: number;
  followsCount: number;
}

/**
 * 에이전트의 그래프 메모리 통계를 반환합니다.
 */
export async function getMemoryStats(agentId: string): Promise<MemoryStats> {
  const c = await getConnection();

  async function count(cypher: string): Promise<number> {
    const r = await c.query(cypher);
    const rows = await r.getAll();
    r.close?.();
    if (!rows || rows.length === 0) return 0;
    const val = Object.values(rows[0])[0];
    return typeof val === "number" ? val : 0;
  }

  const aid = esc(agentId);

  // Kuzu는 단일 connection에서 동시 쿼리 불가 — 순차 실행
  const coreCount     = await count(`MATCH (m:Memory) WHERE m.agentId = '${aid}' AND m.memType = 'core' RETURN count(m) AS n`);
  const dailyCount    = await count(`MATCH (m:Memory) WHERE m.agentId = '${aid}' AND m.memType = 'daily' RETURN count(m) AS n`);
  const entityCount   = await count(`MATCH (m:Memory)-[:MENTIONS]->(e:Entity) WHERE m.agentId = '${aid}' RETURN count(DISTINCT e.id) AS n`);
  const topicCount    = await count(`MATCH (m:Memory)-[:ABOUT]->(t:Topic) WHERE m.agentId = '${aid}' RETURN count(DISTINCT t.id) AS n`);
  const mentionsCount = await count(`MATCH (m:Memory)-[:MENTIONS]->(:Entity) WHERE m.agentId = '${aid}' RETURN count(*) AS n`);
  const aboutCount    = await count(`MATCH (m:Memory)-[:ABOUT]->(:Topic) WHERE m.agentId = '${aid}' RETURN count(*) AS n`);
  const followsCount  = await count(`MATCH (m:Memory)-[:FOLLOWS]->(:Memory) WHERE m.agentId = '${aid}' RETURN count(*) AS n`);

  return { coreCount, dailyCount, entityCount, topicCount, mentionsCount, aboutCount, followsCount };
}
