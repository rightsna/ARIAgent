import {
  readCoreMemory as dataReadCoreMemory,
  writeCoreMemory as dataWriteCoreMemory,
  appendDailyMemoryLine,
  readDailyMemory,
  writeDailyMemory,
  hasWorkspace,
  hasDailyMemory,
  removeCoreMemory,
  removeDailyMemoryDir,
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
import { Settings, AIProviders } from "../models/settings.js";
import { logger } from "../infra/logger.js";
import { getExecutionContext } from "./agent/execution_context.js";
import { completeSimple } from "@mariozechner/pi-ai";
import { findFirstUsableProvider, resolveModel, resolveApiKey } from "./agent/provider_selector.js";

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

  summarizeDailyLogIfNeeded(activeId, getTodayString()).catch((e) =>
    logger.error(`[Memory] Auto-summarization failed:`, e),
  );
}

function readDailyLogByDate(dateStr: string, agentId?: string): string {
  const activeId = resolveAgentId(agentId);
  const summary = readDailyMemory(activeId, `summary-${dateStr}.md`);
  const log = readDailyMemory(activeId, `${dateStr}.md`);

  let result = "";
  if (summary) result += `[Summary Log: ${dateStr}]\n${summary}`;
  if (log) result += (result ? "\n\n" : "") + `### Log Data from ${dateStr}\n` + log;
  return result;
}

export function readRecentDailyLogs(agentId?: string, maxLines = 10): string {
  const yesterdayLog = readDailyLogByDate(getYesterdayString(), agentId);
  const todayLog = readDailyLogByDate(getTodayString(), agentId);

  let result = "";
  if (yesterdayLog) result += yesterdayLog + "\n\n";
  if (todayLog) result += todayLog + "\n\n";

  const trimmed = result.trim();
  if (!trimmed) return "";

  const lines = trimmed.split("\n");
  return lines.length > maxLines ? lines.slice(-maxLines).join("\n") : trimmed;
}

const DAILY_LOG_SUMMARIZE_THRESHOLD = 800;

async function summarizeDailyLogIfNeeded(agentId: string, dateStr: string): Promise<void> {
  const logFilename = `${dateStr}.md`;
  const summaryFilename = `summary-${dateStr}.md`;

  const logContent = readDailyMemory(agentId, logFilename);
  if (logContent.length <= DAILY_LOG_SUMMARIZE_THRESHOLD) return;

  const existingSummary = readDailyMemory(agentId, summaryFilename);
  if (existingSummary) return;

  const settings = getSettings(new Settings());
  const providers = new AIProviders({ providers: settings.PROVIDERS });
  if (providers.availableProviders.length === 0) return;

  let firstProvider: ReturnType<typeof findFirstUsableProvider>;
  try {
    firstProvider = findFirstUsableProvider(providers);
  } catch {
    return;
  }

  const model = resolveModel(firstProvider.provider);
  const apiKey = await resolveApiKey(firstProvider.provider);

  logger.info(`[Memory] Summarizing daily log for ${agentId} (${dateStr}), length=${logContent.length}`);

  const result = await completeSimple(model, {
    systemPrompt: "You are a concise summarizer. Summarize the following daily activity log into a brief paragraph (3-5 sentences). Focus on key decisions, tasks completed, and important facts. Be factual and concise.",
    messages: [{ role: "user", content: logContent, timestamp: Date.now() }],
  }, { apiKey: apiKey ?? undefined });

  const summary = result.content
    .filter((b: any) => b.type === "text")
    .map((b: any) => b.text)
    .join("")
    .trim();

  if (!summary) return;

  writeDailyMemory(agentId, summaryFilename, summary);
  writeDailyMemory(agentId, logFilename, "");
  logger.info(`[Memory] Daily log summarized and cleared for ${agentId} (${dateStr})`);
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

/**
 * 현재 대화 쿼리와 의미론적으로 관련된 메모리를 검색합니다. (고급 관계 지능 전용)
 * Entity/Topic 정보가 있으면 컨텍스트에 함께 포함됩니다.
 */
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
