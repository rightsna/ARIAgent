import { AgentMessage } from "@mariozechner/pi-agent-core";
import { AgentRuntimeContext } from "../../models/agent_runtime";
import { SkillDefinition } from "../../skills";
import { Prompt } from "../../infra/prompt";
import { readCoreMemory, readRecentDailyLogs } from "../memory";
import { ActiveSkill } from "./skill_registry";

export async function buildSystemPrompt(
  persona: string,
  runtimeContext: AgentRuntimeContext,
  agentId: string,
  availableSkills: Pick<SkillDefinition, "name" | "description">[] = [],
  activeSkills: ActiveSkill[] = [],
): Promise<string> {
  const coreMemory = readCoreMemory(agentId);
  const recentDailyLogs = readRecentDailyLogs(agentId);
  const avatarName = runtimeContext.avatarName?.trim() || "ARI";
  const platform = runtimeContext.platform?.trim() || process.platform;
  const loadedSkills = activeSkills.map((skill) => ({
    name: skill.name,
    description: skill.description,
    tools: skill.tools,
    content: skill.content,
  }));

  return Prompt.load("system_prompt.hbs", {
    now_str: new Date().toISOString(),
    avatarName,
    platform,
    persona,
    coreMemory,
    recentDailyLogs,
    skills: availableSkills.map((skill) => ({
      name: skill.name,
      description: skill.description,
    })),
    loadedSkills,
  });
}

export function pruneContext(messages: AgentMessage[]): Promise<AgentMessage[]> {
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

