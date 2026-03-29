import { setActiveAgentId } from "../memory";
import { getSettings } from "../../repositories/setting_repository";
import { getAgentsConfig } from "../../repositories/agent_repository";
import { AgentsConfig } from "../../models/agent";
import { AgentRuntimeContext, ChatWithAgentResult, PluginInfo } from "../../models/agent_runtime";
import { Settings, AIProviderConfig } from "../../models/settings";
import { AgentState, createDefaultState } from "../../models/agent_state";
import { logger } from "../../infra/logger";
import { buildSystemPrompt, pruneContext } from "./context_builder";
import { extractFinalResponseText } from "./response_parser";
import { buildSessionTools, buildSessionToolsSync, clearToolCache, loadMainTools } from "./tool_registry";
import { getAttemptOrder, resolveModel, resolveApiKey, isOAuthProvider } from "./provider_selector";
import { AgentSession, clearAgentSession, clearAllAgentSessions, getOrCreateSession, saveSession } from "./session_manager";
import { cloneActiveSkills, clearSkillCache, collectSkillToolNames, loadAvailableSkills, mergeActiveSkill } from "./skill_registry";

const _state: AgentState = createDefaultState();
let activeProviders: AIProviderConfig[] = [];
let currentTools = [] as Awaited<ReturnType<typeof loadMainTools>>;
let currentSkills = [] as Awaited<ReturnType<typeof loadAvailableSkills>>;
type ProgressReporter = (message: string) => void;

export async function initAgent(providersConfig?: AIProviderConfig[]): Promise<void> {
  const globalSettings = getSettings(new Settings()) || {};
  clearToolCache();
  clearSkillCache();
  currentTools = await loadMainTools();
  currentSkills = await loadAvailableSkills();

  if (providersConfig && providersConfig.length > 0) {
    _state.providers = providersConfig;
  } else if (globalSettings.PROVIDERS && globalSettings.PROVIDERS.length > 0) {
    _state.providers = globalSettings.PROVIDERS;
  } else {
    _state.providers = [
      {
        provider: globalSettings.PROVIDER || "openai",
        model: globalSettings.OPENAI_MODEL || "gpt-4o-mini",
        apiKey: globalSettings.OPENAI_API_KEY || "",
        authType: "apikey",
      },
    ];
  }

  const active = _state.providers.find((provider) => !!provider.apiKey) || _state.providers[0];
  _state.currentApiKey = active?.apiKey || globalSettings.OPENAI_API_KEY || "";
  _state.currentModel = active?.model || globalSettings.OPENAI_MODEL || "gpt-4o-mini";
  _state.currentProvider = active?.provider || globalSettings.PROVIDER || "openai";

  // OAuth 프로바이더는 apiKey가 없어도 oauth credentials가 있으면 활성화됩니다.
  // isOAuthProvider로 판별하거나 authType === 'oauth' 이면 포함시킵니다.
  activeProviders = (_state.providers || []).filter((provider: AIProviderConfig) => !!provider.apiKey || provider.authType === "oauth" || isOAuthProvider(provider.provider));
  clearAllAgentSessions();

  if (activeProviders.length === 0) {
    logger.info("⚠️  활성화된 API Key 없음 — 에코 모드 (대화는 가능하나 동작이 제한됩니다)");
    return;
  }

  logger.info(`✅ AgentPi initialized. (${activeProviders.length} providers loaded, current: ${_state.currentProvider}/${_state.currentModel})`);
}

export async function chatWithAgent(
  message: string,
  persona: string = "",
  agentId?: string,
  runtimeContext: AgentRuntimeContext = {},
  onProgress?: ProgressReporter,
): Promise<ChatWithAgentResult> {
  // 이번 요청이 어느 대화 세션에 속하는지 결정합니다.
  const currentAgentId = agentId || getAgentsConfig(new AgentsConfig()).selected || "default";
  setActiveAgentId(currentAgentId);

  // 사용 가능한 프로바이더가 없으면 즉시 에코 모드 응답을 반환합니다.
  if (activeProviders.length === 0) {
    return {
      responseText: `[에코 모드] "${message}"\n\n⚠️ Settings에서 하나 이상의 AI Provider API Key를 추가하세요.`,
    };
  }

  // 기본 툴 목록은 첫 요청 시점에 지연 로드합니다.
  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }

  // 스킬 목록은 파일 시스템의 최신 상태를 반영하기 위해 매 요청마다 로드합니다.
  currentSkills = await loadAvailableSkills();

  // 세션을 준비하고, 현재 요청 기준 시스템 프롬프트를 구성합니다.
  const session = getOrCreateSession(currentAgentId, activeProviders, pruneContext, (provider, error) => {
    logger.warn(`[AgentPi] Invalid model config (${provider.provider}, ${provider.model}): `, error);
  });
  const systemPrompt = await buildSystemPrompt(persona, runtimeContext, currentAgentId, currentSkills, session.activeSkills);
  const result = await runInference(session, message, systemPrompt, onProgress);

  // 대화 기록 저장
  saveSession(currentAgentId);

  // 실패 결과를 사용자 응답 형태로 정리합니다.
  if (!result.success) {
    if (result.lastError) {
      return {
        responseText: `❌ 모든 프로바이더에서 오류가 발생했습니다: ${result.lastError.message}`,
      };
    }

    return {
      responseText: "❌ 사용 가능한 프로바이더가 없습니다.",
    };
  }

  // 스트리밍 텍스트를 우선 사용하고, 없으면 최종 assistant 메시지에서 추출합니다.
  return {
    responseText: result.responseText || extractFinalResponseText(session.agent) || "처리 중 오류가 발생했습니다.",
  };
}

async function runInference(
  session: AgentSession,
  userMessage: string,
  systemPrompt: string,
  onProgress?: ProgressReporter,
): Promise<{ responseText: string; lastError: Error | null; success: boolean }> {
  // 프로바이더가 없으면 추론을 시작하지 않습니다.
  if (activeProviders.length === 0) {
    return {
      responseText: "",
      lastError: new Error("No active AI providers configured."),
      success: false,
    };
  }

  // 각 프로바이더 재시도가 같은 대화 상태에서 시작되도록 현재 메시지를 스냅샷합니다.
  const agent = session.agent;
  const baseMessages = agent.state.messages.slice();
  const baseSkills = cloneActiveSkills(session.activeSkills);
  const baseSkillToolNames = new Set(session.activeSkillToolNames);
  let lastError: Error | null = null;

  // 현재 프로바이더부터 시작해서 나머지 프로바이더를 순서대로 시도합니다.
  for (const providerIndex of getAttemptOrder(activeProviders.length, session.activeProviderIndex)) {
    const provider = activeProviders[providerIndex];
    session.activeProvider = provider;
    session.activeProviderIndex = providerIndex;

    _state.currentApiKey = provider.apiKey;
    _state.currentModel = provider.model;
    _state.currentProvider = provider.provider;

    // 재시도 전마다 에이전트 상태를 추론 시작 직전 스냅샷으로 되돌립니다.
    agent.replaceMessages(baseMessages.slice());
    agent.state.error = undefined;
    session.activeSkills = cloneActiveSkills(baseSkills);
    session.activeSkillToolNames = new Set(baseSkillToolNames);

    let model;
    try {
      model = resolveModel(provider);
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      logger.warn(`[AgentPi] Invalid model config (${provider.provider}, ${provider.model}): `, error);
      continue;
    }

    // OAuth 프로바이더는 추론 직전에 동적으로 API Key를 획득합니다.
    let resolvedApiKey = provider.apiKey;
    if (provider.authType === "oauth" || isOAuthProvider(provider.provider)) {
      const oauthKey = await resolveApiKey(provider);
      if (!oauthKey) {
        lastError = new Error(`OAuth token not available for ${provider.provider}. Please log in first.`);
        logger.warn(`[AgentPi] No OAuth token for ${provider.provider}, skipping.`);
        continue;
      }
      resolvedApiKey = oauthKey;
      logger.info(`[AgentPi] OAuth token resolved for ${provider.provider}.`);
    }

    // 현재 프로바이더 기준 모델과 실행 설정을 에이전트에 반영합니다.
    _state.currentApiKey = resolvedApiKey;
    onProgress?.(activeProviders.length > 1 ? `${provider.provider} 모델로 추론 중...` : "생각하는 중...");
    agent.setModel(model);
    agent.setSystemPrompt(systemPrompt);
    agent.setThinkingLevel("medium");
    const preparedTools = await buildSessionTools(session.activeSkillToolNames);
    session.runtimeTools.splice(0, session.runtimeTools.length, ...preparedTools);
    agent.setTools(session.runtimeTools);

    // 응답 스트리밍 중에는 text delta를 누적해서 결과 문자열을 만듭니다.
    let responseText = "";
    const unsubscribe = agent.subscribe((event) => {
      if (event.type === "message_update" && event.assistantMessageEvent.type === "text_delta") {
        responseText += event.assistantMessageEvent.delta;
      }
      if (event.type === "tool_execution_start") {
        onProgress?.(describeToolProgress(event.toolName));
      }
      if (event.type === "tool_execution_end" && event.toolName === "read_skill" && !event.isError) {
        session.activeSkills = mergeActiveSkill(session.activeSkills, event.result?.details);
        session.activeSkillToolNames = collectSkillToolNames(session.activeSkills);
        const nextTools = buildSessionToolsSync(session.activeSkillToolNames);
        session.runtimeTools.splice(0, session.runtimeTools.length, ...nextTools);
        agent.setTools(session.runtimeTools);
        onProgress?.("스킬 지침을 반영하는 중...");
      }
    });

    try {
      await agent.prompt(userMessage);
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      unsubscribe();
      onProgress?.("다른 모델로 다시 시도하는 중...");
      logger.warn(`❌ [AgentPi] Provider ${provider.provider} threw before completion: ${lastError.message}`);
      continue;
    }

    unsubscribe();

    // 에이전트 내부 오류가 있으면 다음 프로바이더로 넘어갑니다.
    if (agent.state.error) {
      lastError = new Error(agent.state.error);
      onProgress?.("다른 모델로 다시 시도하는 중...");
      logger.warn(`❌ [AgentPi] Provider ${provider.provider} failed: ${agent.state.error}. Trying next provider if available.`);
      continue;
    }

    // 스트리밍 텍스트가 비어 있으면 최종 assistant 메시지에서 응답을 추출합니다.
    if (!responseText) {
      responseText = extractFinalResponseText(agent);
    }

    logger.info(`✅ [AgentPi] Response success (${provider.provider}/${provider.model})`);
    return {
      responseText,
      lastError: null,
      success: true,
    };
  }

  // 모든 프로바이더가 실패하면 원래 대화 상태로 복구합니다.
  agent.replaceMessages(baseMessages);
  agent.state.error = undefined;
  session.activeSkills = baseSkills;
  session.activeSkillToolNames = baseSkillToolNames;

  return {
    responseText: "",
    lastError,
    success: false,
  };
}

function describeToolProgress(toolName: string): string {
  switch (toolName) {
    case "read_skill":
      return "스킬 문서를 읽는 중...";
    case "execute_bash":
      return "로컬 명령을 실행하는 중...";
    case "update_core_memory":
      return "핵심 메모리를 갱신하는 중...";
    case "append_daily_memory":
      return "일상 메모리를 기록하는 중...";
    case "register_schedule":
    case "register_one_off_schedule":
      return "일정을 등록하는 중...";
    case "youtube_play":
      return "유튜브에서 영상을 재생하는 중...";
    case "youtube_play_playlist":
      return "유튜브 플레이리스트를 재생하는 중...";
    case "youtube_search_videos":
      return "유튜브 영상을 찾는 중...";
    default:
      return `${toolName} 실행 중...`;
  }
}

//---

export function getCurrentState(): AgentState {
  return _state;
}

export async function getPluginsInfo(): Promise<PluginInfo> {
  getSettings(new Settings());
  if (currentTools.length === 0) {
    currentTools = await loadMainTools();
  }
  if (currentSkills.length === 0) {
    currentSkills = await loadAvailableSkills();
  }
  return { tools: currentTools, skills: currentSkills };
}

export function clearAgentInstance(agentId: string) {
  clearAgentSession(agentId);
  logger.info(`[AgentPi] Instance cleared for: ${agentId}`);
}

export function abortAgent(agentId: string) {
  const session = getOrCreateSession(agentId, activeProviders, pruneContext);
  if (session && session.agent) {
    session.agent.abort();
    logger.info(`[AgentPi] Thinking aborted for: ${agentId}`);
  }
}
