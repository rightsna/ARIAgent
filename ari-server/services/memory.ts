import {
  readCoreMemory as dataReadCoreMemory,
  writeCoreMemory as dataWriteCoreMemory,
  appendDailyMemoryLine,
  readDailyMemory,
  hasWorkspace,
  hasDailyMemory,
  removeCoreMemory,
  removeDailyMemoryDir,
  listDailyMemoryFiles,
} from "../repositories/memory_repository.js";
import {
  insertMemoryNode,
  deleteCoreMemoryNodes,
  deleteAllMemoryNodes,
  searchMemoryNodes,
  EntityInput,
  Importance,
} from "../repositories/kuzu_memory_repository.js";
import { embedPassage, embedQuery, getEmbeddingStatus } from "./embedding.js";
import { getSettings } from "../repositories/setting_repository.js";
import { Settings } from "../models/settings.js";
import { logger } from "../infra/logger.js";
import { getExecutionContext } from "./agent/execution_context.js";

function isAdvancedMemoryReady(): boolean {
  const settings = getSettings(new Settings());
  if (!settings.USE_ADVANCED_MEMORY) return false;
  return getEmbeddingStatus().status === "ready";
}

function resolveAgentId(agentId?: string): string {
  return agentId || getExecutionContext()?.agentId || "default";
}

export interface MemoryGraphMeta {
  topics?: string[];
  entities?: EntityInput[];
  importance?: Importance;
}

export function updateCoreMemory(
  newContent: string,
  agentId?: string,
  meta: MemoryGraphMeta = {},
): void {
  const activeId = resolveAgentId(agentId);
  dataWriteCoreMemory(activeId, newContent);

  if (isAdvancedMemoryReady()) {
    (async () => {
      try {
        await deleteCoreMemoryNodes(activeId);
        const chunks = chunkText(newContent, 500);
        for (const chunk of chunks) {
          if (!chunk.trim()) continue;
          const embedding = await embedPassage(chunk);
          await insertMemoryNode({
            agentId: activeId,
            content: chunk,
            memType: "core",
            embedding,
            topics: meta.topics,
            entities: meta.entities,
            importance: meta.importance ?? "normal",
          });
        }
      } catch (e) {
        logger.error(`[Memory] Kuzu core memory sync failed:`, e);
      }
    })();
  }
}

export function readCoreMemory(agentId?: string): string {
  const activeId = resolveAgentId(agentId);
  return dataReadCoreMemory(activeId);
}

function getTodayString(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function getYesterdayString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function appendDailyMemory(
  content: string,
  agentId?: string,
  meta: MemoryGraphMeta = {},
): void {
  const activeId = resolveAgentId(agentId);
  const todayFilename = `${getTodayString()}.md`;

  const prefix = !hasDailyMemory(activeId, todayFilename)
    ? `# Daily Log: ${getTodayString()}\n\n`
    : "\n\n";

  appendDailyMemoryLine(activeId, todayFilename, prefix + content);
}

function parseDailyEntries(dateStr: string, agentId: string): string[] {
  const log = readDailyMemory(agentId, `${dateStr}.md`);
  if (!log.trim()) return [];
  return log
    .split(/\n{2,}/)
    .map((e) => e.trim())
    .filter((e) => e && !e.startsWith("# Daily Log:"));
}

export function readRecentDailyLogs(agentId?: string, maxEntries = 10): string {
  const activeId = resolveAgentId(agentId);
  const yesterday = parseDailyEntries(getYesterdayString(), activeId);
  const today = parseDailyEntries(getTodayString(), activeId);

  const all = [...yesterday, ...today];
  const recent = all.slice(-maxEntries);
  return recent.join("\n\n");
}

export function searchDailyLogs(query: string, agentId?: string): string {
  const activeId = resolveAgentId(agentId);
  const lowerQuery = query.toLowerCase();
  const files = listDailyMemoryFiles(activeId);
  const matches: string[] = [];

  for (const filename of files) {
    const dateStr = filename.replace(".md", "");
    const entries = parseDailyEntries(dateStr, activeId);
    for (const entry of entries) {
      if (entry.toLowerCase().includes(lowerQuery)) {
        matches.push(`[${dateStr}] ${entry}`);
      }
    }
  }

  return matches.join("\n\n");
}

export function clearAgentMemory(agentId?: string): void {
  const activeId = resolveAgentId(agentId);
  if (!hasWorkspace(activeId)) return;

  removeCoreMemory(activeId);
  removeDailyMemoryDir(activeId);

  deleteAllMemoryNodes(activeId).catch((e) =>
    logger.error(`[Memory] Kuzu clear failed:`, e),
  );

  logger.info(`[Memory] Cleared memory for agent: ${activeId}`);
}

export async function searchRelevantMemories(
  query: string,
  agentId?: string,
  topK: number = 5,
): Promise<string> {
  const activeId = resolveAgentId(agentId);
  try {
    const queryEmbedding = await embedQuery(query);
    const results = await searchMemoryNodes(activeId, queryEmbedding, topK);
    if (results.length === 0) return "";

    return results
      .filter((r) => r.score > 0.3)
      .map((r) => {
        const tags: string[] = [];
        if (r.topics.length > 0) tags.push(`주제: ${r.topics.join(", ")}`);
        if (r.entities.length > 0) tags.push(`관련: ${r.entities.map((e) => e.name).join(", ")}`);
        const meta = tags.length > 0 ? ` (${tags.join(" | ")})` : "";
        return `[${r.memType}${meta}]\n${r.content}`;
      })
      .join("\n\n");
  } catch (e) {
    logger.error(`[Memory] 관련 메모리 검색 실패:`, e);
    return "";
  }
}

function chunkText(text: string, maxLen: number): string[] {
  const paragraphs = text.split(/\n{2,}/);
  const chunks: string[] = [];
  let current = "";

  for (const para of paragraphs) {
    if ((current + "\n\n" + para).length > maxLen && current) {
      chunks.push(current.trim());
      current = para;
    } else {
      current = current ? current + "\n\n" + para : para;
    }
  }
  if (current.trim()) chunks.push(current.trim());
  return chunks;
}
