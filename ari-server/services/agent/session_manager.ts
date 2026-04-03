import { Agent, AgentMessage, AgentTool } from "@mariozechner/pi-agent-core";
import { AIProviderConfig } from "../../models/settings";
import { createApiKeyResolver, findFirstUsableProvider, resolveModel } from "./provider_selector";
import { getCurrentState } from "./index";
import { ActiveSkill } from "./skill_registry";
import { readChatLogs } from "../../repositories/chat_log_repository";

export interface AgentSession {
  agent: Agent;
  activeProvider: AIProviderConfig | null;
  activeProviderIndex: number;
  activeSkills: ActiveSkill[];
  activeSkillToolNames: Set<string>;
  runtimeTools: AgentTool[];
}

const agentsMap = new Map<string, AgentSession>();

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

  // 파일 시스템에서 최근 대화 로그 로드 (최근 20개)
  const { logs } = readChatLogs(agentId, 0, 20);
  const initialMessages: AgentMessage[] = logs
    .filter((log: any) => log.type === "chat")
    .reverse() // readChatLogs는 최신순이므로 Agent 포맷에 맞게 과거순으로 정렬
    .map((log: any) => {
      if (log.isUser) {
        return {
          role: "user",
          content: [{ type: "text", text: log.message }],
        } as any;
      } else {
        return {
          role: "assistant",
          content: [{ type: "text", text: log.message }],
          // AI 응답의 경우 필수 필드(api, provider 등) 추가 (타입 호환성)
          api: "historical",
          provider: "historical",
          model: "historical",
          usage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 },
        } as any;
      }
    }) as AgentMessage[];

  const { provider: initialProvider, index: initialProviderIndex } = findFirstUsableProvider(activeProviders, onInvalidProvider);

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
      messages: initialMessages,
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

export function getSession(agentId: string): AgentSession | undefined {
  return agentsMap.get(agentId);
}

export function clearAgentSession(agentId: string): void {
  const session = agentsMap.get(agentId);
  if (session && session.agent) {
    session.agent.abort();
  }
  agentsMap.delete(agentId);
}

export function clearAllAgentSessions(): void {
  for (const session of agentsMap.values()) {
    if (session.agent) session.agent.abort();
  }
  agentsMap.clear();
}
