import path from "path";
import fs from "fs";
import { DATA_DIR, appendTextSync, unlinkSyncSafe } from "../infra/data.js";

const LOGS_DIR = path.join(DATA_DIR, "chat_logs");

/**
 * 로그 항목을 JSONL 파일에 추가합니다.
 */
export function appendChatLog(agentId: string, entry: any): void {
  const filePath = path.join(LOGS_DIR, `${agentId}.jsonl`);
  const logEntry = {
    ...entry,
    agentId,
    timestamp: entry.timestamp || new Date().toISOString()
  };
  const line = JSON.stringify(logEntry) + "\n";
  appendTextSync(filePath, line);
}

/**
 * 로그를 최신순으로 페이지네이션하여 조회합니다.
 */
export function readChatLogs(agentId: string, index: number, size: number): { logs: any[], total: number } {
  const filePath = path.join(LOGS_DIR, `${agentId}.jsonl`);
  if (!fs.existsSync(filePath)) {
    return { logs: [], total: 0 };
  }

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.trim().split("\n").filter(l => l.trim() !== "");
  const total = lines.length;
  
  // 최신순 정렬 (역순) 후 슬라이싱
  const paginatedLines = lines.reverse().slice(index, index + size);
  
  const logs = paginatedLines.map(line => {
    try {
      return JSON.parse(line);
    } catch (e) {
      return null;
    }
  }).filter(l => l !== null);

  return { logs, total };
}

/**
 * 특정 에이전트의 전체 로그 개수를 반환합니다.
 */
export function countChatLogs(agentId: string): number {
  const filePath = path.join(LOGS_DIR, `${agentId}.jsonl`);
  if (!fs.existsSync(filePath)) return 0;
  
  const content = fs.readFileSync(filePath, "utf-8");
  return content.trim().split("\n").filter(l => l.trim() !== "").length;
}

/**
 * 최근 유저 메세지를 최신순으로 N개 반환합니다.
 */
export function readRecentUserMessages(agentId: string, count: number): string[] {
  const filePath = path.join(LOGS_DIR, `${agentId}.jsonl`);
  if (!fs.existsSync(filePath)) return [];

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.trim().split("\n").filter((l) => l.trim() !== "");

  const userMessages: string[] = [];
  for (let i = lines.length - 1; i >= 0 && userMessages.length < count; i--) {
    try {
      const entry = JSON.parse(lines[i]);
      if (entry.type === "chat" && entry.isUser === true && entry.message) {
        userMessages.unshift(entry.message);
      }
    } catch {
      // skip
    }
  }
  return userMessages;
}

/**
 * 특정 에이전트의 로그 파일을 삭제합니다.
 */
export function clearChatLogs(agentId: string): void {
  const filePath = path.join(LOGS_DIR, `${agentId}.jsonl`);
  unlinkSyncSafe(filePath);
}
