import { Agent, AgentMessage } from "@mariozechner/pi-agent-core";
import { AgentInfo } from "../../models/agent.js";
import { AIProviders } from "../../models/settings.js";
import {
  createApiKeyResolver,
  findFirstUsableProvider,
  resolveModel,
} from "./provider_selector.js";
import { readChatLogs } from "../../repositories/chat_log_repository.js";
import { AgentSession } from "./agent_session.js";

const agentsMap = new Map<string, AgentSession>();

export function getOrCreateSession(
  agentInfo: AgentInfo,
  providers: AIProviders,
  transformContext: (messages: AgentMessage[]) => Promise<AgentMessage[]>,
  onInvalidProvider?: (provider: AIProviders["availableProviders"][number], error: unknown) => void,
): AgentSession {
  const agentId = agentInfo.id || "default";
  const existing = agentsMap.get(agentId);
  if (existing) {
    existing.agentInfo.updateFrom(agentInfo);
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

  const { provider: initialProvider } =
    findFirstUsableProvider(providers, onInvalidProvider);

  const session = new AgentSession(agentInfo);

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
      () => session.resolvedApiKey,
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
