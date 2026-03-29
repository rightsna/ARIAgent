import path from "path";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync, ensureDirSync } from "../infra/data";
import { AgentMessage } from "@mariozechner/pi-agent-core";

function getChatLogPath(agentId: string): string {
  if (agentId && agentId !== "default") {
    return path.join(DATA_DIR, "agents", agentId, "workspace", "chat_history.json");
  }
  return path.join(DATA_DIR, "workspace", "chat_history.json");
}

export function getChatLogs(agentId: string): AgentMessage[] {
  const file = getChatLogPath(agentId);
  if (!fileExistsSync(file)) return [];
  return readJsonSync<AgentMessage[]>(file) || [];
}

export function saveChatLogs(agentId: string, messages: AgentMessage[]): void {
  const file = getChatLogPath(agentId);
  ensureDirSync(path.dirname(file));
  // 최근 50개만 저장 (컨텍스트 관리)
  const toSave = messages.slice(-50);
  writeJsonSync(file, toSave);
}
