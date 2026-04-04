import {
  readCoreMemory as dataReadCoreMemory,
  writeCoreMemory as dataWriteCoreMemory,
  appendDailyMemoryLine,
  readDailyMemory,
  hasWorkspace,
  hasDailyMemory,
  removeCoreMemory,
  removeDailyMemoryDir,
} from "../repositories/memory_repository";
import { logger } from "../infra/logger";

let activeAgentId: string = "default";
let activeAppId: string | undefined = undefined;

export function setActiveAgentId(id: string) {
  activeAgentId = id;
}

export function getActiveAgentId(): string {
  return activeAgentId;
}

export function setActiveAppId(id: string | undefined) {
  activeAppId = id;
}

export function getActiveAppId(): string | undefined {
  return activeAppId;
}

export function updateCoreMemory(newContent: string, agentId?: string): void {
  const activeId = agentId || activeAgentId;
  dataWriteCoreMemory(activeId, newContent);
}

/**
 * 장기 기억(MEMORY.md)을 읽어옵니다. 없으면 빈 문자열 반환.
 */
export function readCoreMemory(agentId?: string): string {
  const activeId = agentId || activeAgentId;
  return dataReadCoreMemory(activeId);
}

/**
 * YYYY-MM-DD 형식의 오늘 날짜 문자열 반환
 */
function getTodayString(): string {
  const d = new Date();
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * YYYY-MM-DD 형식의 어제 날짜 문자열 반환
 */
function getYesterdayString(): string {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * 오늘 날짜의 Daily Log 파일에 내용을 추가(Append)합니다.
 */
export function appendDailyMemory(content: string, agentId?: string): void {
  const activeId = agentId || activeAgentId;
  const todayFilename = `${getTodayString()}.md`;

  let prefix = "";
  if (!hasDailyMemory(activeId, todayFilename)) {
    prefix = `# Daily Log: ${getTodayString()}\n\n`;
  } else {
    prefix = "\n\n";
  }

  appendDailyMemoryLine(activeId, todayFilename, prefix + content);
}

/**
 * 특정 일자의 로그를 읽어옵니다. (ex: "2026-02-26")
 */
function readDailyLogByDate(dateStr: string, agentId?: string): string {
  const activeId = agentId || activeAgentId;
  const content = readDailyMemory(activeId, `${dateStr}.md`);
  if (content) {
    return `### Log Data from ${dateStr}\n` + content;
  }
  return "";
}

/**
 * 어제와 오늘의 Daily Log를 합쳐서 반환합니다.
 */
export function readRecentDailyLogs(agentId?: string): string {
  const yesterdayLog = readDailyLogByDate(getYesterdayString(), agentId);
  const todayLog = readDailyLogByDate(getTodayString(), agentId);

  let result = "";
  if (yesterdayLog) result += yesterdayLog + "\n\n";
  if (todayLog) result += todayLog + "\n\n";

  return result.trim();
}

/**
 * 특정 에이전트의 모든 기억(MEMORY.md 및 Daily Logs)을 초기화합니다.
 */
export function clearAgentMemory(agentId?: string): void {
  const activeId = agentId || activeAgentId;
  if (!hasWorkspace(activeId)) return;

  removeCoreMemory(activeId);
  removeDailyMemoryDir(activeId);

  logger.info(`[Memory] Cleared memory for agent: ${activeId}`);
}
