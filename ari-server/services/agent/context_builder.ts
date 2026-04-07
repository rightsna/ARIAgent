import { AgentMessage } from "@mariozechner/pi-agent-core";
import { AgentInfo } from "../../models/agent.js";
import { Prompt } from "../../infra/prompt.js";
import { logger } from "../../infra/logger.js";
import { UserSocketHandler } from "../../system/ws.js";
import { readCoreMemory, readRecentDailyLogs } from "../memory.js";

export async function buildSystemPrompt(
  agentProfile: AgentInfo,
): Promise<string> {
  const agentId = agentProfile.id || "default";
  const coreMemory = readCoreMemory(agentId);
  const recentDailyLogs = readRecentDailyLogs(agentId);
  const avatarName = agentProfile.name.trim() || "ARI";
  const platform = agentProfile.platform?.trim() || process.platform;
  const connectedAppIds = UserSocketHandler.getConnectedAppIds();
  const loadedSkills = agentProfile.toLoadedSkills(agentProfile.activeSkills);

  const systemPrompt = await Prompt.load("system_prompt.hbs", {
    now_str: new Date().toISOString(),
    avatarName,
    platform,
    persona: agentProfile.persona,
    currentAppId: agentProfile.appId,
    connectedAppIds,
    coreMemory,
    recentDailyLogs,
    skills: agentProfile.promptSkills,
    apps: agentProfile.toPromptApps(connectedAppIds),
    loadedSkills,
  });

  // logger.debug(`[Agent] Built System Prompt:\n${systemPrompt}`);

  return systemPrompt;
}

export function pruneContext(
  messages: AgentMessage[],
): Promise<AgentMessage[]> {
  const maxMessages = 60; // 기본 메시지 유지 개수를 60개로 상향
  if (messages.length <= maxMessages) {
    return Promise.resolve(messages);
  }

  // 도구 호출(assistant)과 그 결과(tool)가 서로 끊어지지 않도록,
  // 항상 'user' 메시지부터 시작하는 안전한 자르기 지점을 찾습니다.
  let startIndex = messages.length - maxMessages;
  while (startIndex < messages.length - 1) {
    if (messages[startIndex].role === "user") {
      break;
    }
    startIndex++;
  }

  // 만약 윈도우 내에서 user 메시지를 찾지 못하면(매우 드문 경우),
  // 기존처럼 단순히 뒤에서부터 자릅니다.
  if (startIndex >= messages.length - 1) {
    startIndex = messages.length - maxMessages;
  }

  return Promise.resolve(messages.slice(startIndex));
}
