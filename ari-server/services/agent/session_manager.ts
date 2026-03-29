import { Agent, AgentMessage, AgentTool } from "@mariozechner/pi-agent-core";
import { AIProviderConfig } from "../../models/settings";
import { createApiKeyResolver, findFirstUsableProvider, resolveModel } from "./provider_selector";
import { getCurrentState } from "./index";
import { ActiveSkill } from "./skill_registry";

export interface AgentSession {
  agent: Agent;
  activeProvider: AIProviderConfig | null;
  activeProviderIndex: number;
  activeSkills: ActiveSkill[];
  activeSkillToolNames: Set<string>;
  runtimeTools: AgentTool[];
}

const agentsMap = new Map<string, AgentSession>();

import { getChatLogs, saveChatLogs } from "../../repositories/chat_log_repository";

export function getOrCreateSession(
  agentId: string,
  activeProviders: AIProviderConfig[],
  transformContext: (messages: AgentMessage[]) => Promise<AgentMessage[]>,
  onInvalidProvider?: (provider: AIProviderConfig, error: unknown) => void,
): AgentSession {
  const existing = agentsMap.get(agentId);
  if (existing) {
    return existing;
  }

  const { provider: initialProvider, index: initialProviderIndex } = findFirstUsableProvider(activeProviders, onInvalidProvider);

  // Load history from disk
  const history = getChatLogs(agentId);

  const session: AgentSession = {
    agent: null as unknown as Agent,
    activeProvider: initialProvider,
    activeProviderIndex: initialProviderIndex,
    activeSkills: [],
    activeSkillToolNames: new Set<string>(),
    runtimeTools: [],
  };

  const agent = new Agent({
    initialState: {
      systemPrompt: "",
      model: resolveModel(initialProvider),
      thinkingLevel: "medium",
      tools: [],
      messages: history,
    },
    transformContext,
    getApiKey: createApiKeyResolver(
      () => getCurrentState()?.currentApiKey,
      () => session.activeProvider,
    ),
  });

  session.agent = agent;
  agentsMap.set(agentId, session);
  return session;
}

export function saveSession(agentId: string): void {
  const session = agentsMap.get(agentId);
  if (session && session.agent) {
    saveChatLogs(agentId, session.agent.state.messages);
  }
}

export function clearAgentSession(agentId: string): void {
  agentsMap.delete(agentId);
}

export function clearAllAgentSessions(): void {
  agentsMap.clear();
}
