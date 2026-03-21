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
  const maxMessages = 40;
  if (messages.length <= maxMessages) {
    return Promise.resolve(messages);
  }

  return Promise.resolve(messages.slice(-maxMessages));
}
