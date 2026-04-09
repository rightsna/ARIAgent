import { AgentMessage } from "@mariozechner/pi-agent-core";
import { setActiveAgentId, setActiveAppId } from "../memory.js";
import { getSettings } from "../../repositories/setting_repository.js";
import { getAgentsConfig } from "../../repositories/agent_repository.js";
import { appendChatLog } from "../../repositories/chat_log_repository.js";
import { AgentInfo, AgentsConfig } from "../../models/agent.js";
import {
  ChatWithAgentResult,
  PendingAgentResponse,
} from "../../models/agent_response.js";
import {
  Settings,
  AIProviderConfig,
  AIProviders,
  AvailablePlugins,
} from "../../models/settings.js";
import { logger } from "../../infra/logger.js";
import { buildSystemPrompt, pruneContext } from "./context_builder.js";
import { extractFinalResponseText } from "./response_parser.js";
import { getOAuthStatus } from "../oauth/index.js";
import {
  clearAgentSession,
  clearAllAgentSessions,
  getOrCreateSession,
  getSession,
} from "./session_manager.js";
import { clearSkillCache, loadAvailableApps, loadAvailableSkills, loadSkillsForPrompt } from "../tools/skill_registry.js";
import { clearToolCache, loadMainTools } from "../tools/tool_registry.js";
import { isOAuthProvider } from "./provider_selector.js";
import { UserSocketHandler } from "../../system/ws.js";

const agentState = new AIProviders();
let currentTools = [] as Awaited<ReturnType<typeof loadMainTools>>;
let currentSkills = [] as Awaited<ReturnType<typeof loadAvailableSkills>>;

function getSessionForAgent(agentProfile: AgentInfo) {
  return getOrCreateSession(
    agentProfile,
    agentState,
    pruneContext,
    (provider, error) => {
      logger.warn(
        `[AgentPi] Invalid model config (${provider.provider}, ${provider.model}): `,
        error,
      );
    },
  );
}

export async function initAgent(
  providersConfig?: AIProviders,
): Promise<void> {
  const globalSettings = getSettings(new Settings()) || {};
  const state = agentState;

  clearToolCache();
  clearSkillCache();
  currentTools = await loadMainTools();
  currentSkills = await loadSkillsForPrompt();

  if (providersConfig && providersConfig.providers.length > 0) {
    state.setProviders(providersConfig.providers);
  } else if (globalSettings.PROVIDERS && globalSettings.PROVIDERS.length > 0) {
    state.setProviders(globalSettings.PROVIDERS);
  } else {
    state.setProviders([
      new AIProviderConfig({
        provider: globalSettings.PROVIDER || "openai",
        model: globalSettings.OPENAI_MODEL || "gpt-4o-mini",
        apiKey: globalSettings.OPENAI_API_KEY || "",
        authType: "apikey",
      }),
    ]);
  }
  const active =
    state.providers.find((provider) => !!provider.apiKey) || state.providers[0];
  state.currentModel =
    active?.model || globalSettings.OPENAI_MODEL || "gpt-4o-mini";
  state.currentProvider =
    active?.provider || globalSettings.PROVIDER || "openai";

  state.setAvailableProviders(
    (state.providers || []).filter((provider: AIProviderConfig) => {
      if (provider.apiKey) return true;
      if (
        provider.authType === "oauth" ||
        isOAuthProvider(provider.provider)
      ) {
        const oauthStatus = getOAuthStatus(provider.provider as any);
        if (!oauthStatus.loggedIn) {
          logger.warn(
            `[AgentPi] OAuth provider ${provider.provider} is not logged in. Skipping.`,
          );
          return false;
        }
        return true;
      }
      return false;
    }),
  );
  clearAllAgentSessions();

  if (state.availableProviders.length === 0) {
    logger.info(
      "⚠️  활성화된 API Key 없음 — 에코 모드 (대화는 가능하나 동작이 제한됩니다)",
    );
    return;
  }

  logger.info(
    `✅ AgentPi initialized. (${state.availableProviders.length} providers loaded, current: ${state.currentProvider}/${state.currentModel})`,
  );
}

export function getCurrentState() {
  return agentState;
}

export async function getPluginsInfo(): Promise<AvailablePlugins> {
  getSettings(new Settings());
  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }
  const [skills, apps] = await Promise.all([
    loadAvailableSkills(),
    loadAvailableApps(),
  ]);
  return { tools: currentTools, skills, apps };
}

export async function chatWithAgent(
  message: string,
  agentProfile: AgentInfo = new AgentInfo(),
  onProgress?: (message: string) => void,
  pendingResponse?: PendingAgentResponse,
): Promise<ChatWithAgentResult> {
  const currentAgentId =
    agentProfile.id || getAgentsConfig(new AgentsConfig()).selected || "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: currentAgentId,
  });
  setActiveAgentId(currentAgentId);
  setActiveAppId(currentAgentProfile.appId);

  if (agentState.availableProviders.length === 0) {
    return {
      responseText: `[에코 모드] "${message}"\n\n⚠️ Settings에서 하나 이상의 AI Provider API Key를 추가하세요.`,
    };
  }

  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }

  currentSkills = await loadAvailableSkills();

  const session = getSessionForAgent(currentAgentProfile);
  session.agentInfo.availableSkills = currentSkills;
  session.ensureLifecycleAttached();
  if (pendingResponse) {
    session.enqueueRequest(pendingResponse);
  }

  const systemPrompt = await buildSystemPrompt(session.agentInfo);
  const result = await session.runInference(
    message,
    systemPrompt,
    agentState,
    onProgress,
  );

  if (!result.success) {
    if (result.aborted) {
      return { responseText: "", aborted: true };
    }

    if (result.lastError) {
      return {
        responseText: `❌ 모든 프로바이더에서 오류가 발생했습니다: ${result.lastError.message}`,
      };
    }

    return {
      responseText: "❌ 사용 가능한 프로바이더가 없습니다.",
    };
  }

  return {
    responseText:
      result.responseText ||
      extractFinalResponseText(session.agent) ||
      "처리 중 오류가 발생했습니다.",
  };
}

export async function submitAgentRequest(
  message: string,
  agentProfile: AgentInfo,
  onProgress: ((message: string) => void) | undefined,
  pendingResponse: PendingAgentResponse,
): Promise<{ status: "follow_up" | "broadcasted" | "cancelled" }> {
  const agentId = pendingResponse.agentId || agentProfile.id || "default";
  const currentAgentProfile = new AgentInfo({
    ...agentProfile,
    id: agentId,
  });

  if (agentState.availableProviders.length === 0) {
    const responseText = `[에코 모드] "${message}"\n\n⚠️ Settings에서 하나 이상의 AI Provider API Key를 추가하세요.`;
    UserSocketHandler.broadcast("/AGENT.REQUEST", {
      message: pendingResponse.originalMessage,
      requestId: pendingResponse.requestId,
    });
    appendChatLog(agentId, {
      type: "chat",
      isUser: true,
      message: pendingResponse.originalMessage,
      requestId: pendingResponse.requestId,
    });
    appendChatLog(agentId, {
      type: "chat",
      isUser: false,
      message: responseText,
      requestId: pendingResponse.requestId,
    });
    UserSocketHandler.broadcast("/APP.PUSH", {
      ok: true,
      data: {
        response: responseText,
        requestId: pendingResponse.requestId,
        appId: pendingResponse.appId,
      },
    });
    return { status: "broadcasted" };
  }

  const session = getSessionForAgent(currentAgentProfile);
  session.ensureLifecycleAttached();
  session.enqueueRequest(pendingResponse);

  if (session.agent.state.isStreaming) {
    session.agent.followUp({
      role: "user",
      content: [{ type: "text", text: message }],
      timestamp: Date.now(),
    } as AgentMessage);
    UserSocketHandler.broadcast("/AGENT.FOLLOW_UP", {
      ok: true,
      data: {
        requestId: pendingResponse.requestId,
        message: pendingResponse.originalMessage,
        agentId,
        reason: "busy",
      },
    });
    logger.info(
      `[AgentPi] Follow-up queued for ${agentId} (${pendingResponse.requestId})`,
    );
    return { status: "follow_up" };
  }

  if (
    session.currentPendingResponse &&
    session.currentPendingResponse.requestId !== pendingResponse.requestId
  ) {
    logger.warn(
      `[AgentPi] Clearing stale current pending request for ${agentId}: ${session.currentPendingResponse.requestId}`,
    );
    session.currentPendingResponse = null;
  }

  const stalePendingRequests = session.pendingResponses.filter(
    (item) => item.requestId !== pendingResponse.requestId,
  );
  if (stalePendingRequests.length > 0) {
    logger.warn(
      `[AgentPi] Clearing ${stalePendingRequests.length} stale pending request(s) before immediate execution for ${agentId}.`,
    );
    session.pendingResponses = session.pendingResponses.filter(
      (item) => item.requestId === pendingResponse.requestId,
    );
  }

  session.beginNextRequest();
  const result = await chatWithAgent(
    message,
    agentProfile,
    onProgress,
  );

  if (result.aborted) {
    session.removeRequest(pendingResponse.requestId);
    return { status: "cancelled" };
  }

  return { status: "broadcasted" };
}

export function dropPendingResponse(agentId: string, requestId: string): void {
  const session = getSession(agentId);
  if (!session) {
    return;
  }

  session.removeRequest(requestId);
}

export function clearAgentInstance(agentId: string) {
  clearAgentSession(agentId);
  logger.info(`[AgentPi] Instance cleared for: ${agentId}`);
}

export function abortAgent(agentId: string) {
  const session = getSession(agentId);
  if (session && session.agent) {
    session.agent.clearAllQueues();
    session.resetRequestQueue();
    session.agent.abort();
    logger.info(`[AgentPi] Thinking aborted for: ${agentId}`);
  } else {
    logger.warn(`[AgentPi] No active session to abort for: ${agentId}`);
  }
}
