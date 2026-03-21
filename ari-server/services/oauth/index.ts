import { loginOpenAICodex, loginAnthropic, loginGitHubCopilot, loginGeminiCli, loginAntigravity, getOAuthApiKey } from "@mariozechner/pi-ai";
import type { OAuthCredentials } from "@mariozechner/pi-ai";
import { type OAuthProvider, getProviderCredentials, setProviderCredentials, deleteProviderCredentials } from "../../repositories/oauth_repository";
import { logger } from "../../infra/logger";

// ─── 프로바이더별 표시명 ─────────────────────────────────────
export const OAUTH_PROVIDER_LABELS: Record<OAuthProvider, string> = {
  "openai-codex": "OpenAI Codex",
  anthropic: "Anthropic (OAuth)",
  "github-copilot": "GitHub Copilot",
  "google-gemini-cli": "Google Gemini CLI",
  "google-antigravity": "Antigravity",
};

// ─── 로그인 이벤트 ─────────────────────────────────────────
export type LoginEvent =
  | { type: "auth_url"; authUrl: string; instructions?: string }
  | { type: "prompt"; promptMessage: string }
  | { type: "progress"; message: string }
  | { type: "done"; message: string }
  | { type: "error"; message: string };

type LoginProgressCallback = (event: LoginEvent) => void;

// ─── 현재 진행 중인 로그인 플로우의 prompt 대기 큐 ─────────
// 앱이 /OAUTH_PROMPT 를 통해 응답을 보낼 때까지 resolve를 보관
const pendingPrompts: Map<OAuthProvider, (value: string) => void> = new Map();

// ─── 프로바이더별 로그인 플로우 ─────────────────────────────
export async function startOAuthLogin(provider: OAuthProvider, onEvent: LoginProgressCallback): Promise<void> {
  let credentials: OAuthCredentials;

  try {
    switch (provider) {
      case "openai-codex":
        credentials = await loginOpenAICodex({
          onAuth: (info) => {
            logger.info(`[OAuth] Auth URL for openai-codex: ${info.url}`);
            onEvent({ type: "auth_url", authUrl: info.url, instructions: info.instructions });
          },
          onPrompt: async (prompt) => {
            logger.info(`[OAuth] Prompt for openai-codex: ${prompt.message}`);
            onEvent({ type: "prompt", promptMessage: prompt.message });
            return waitForPromptReply(provider);
          },
          onProgress: (message) => {
            onEvent({ type: "progress", message });
          },
        });
        break;

      case "anthropic":
        credentials = await loginAnthropic(
          (url) => {
            logger.info(`[OAuth] Auth URL for anthropic: ${url}`);
            onEvent({ type: "auth_url", authUrl: url });
          },
          async () => {
            onEvent({ type: "prompt", promptMessage: "인증 코드를 입력하세요" });
            return waitForPromptReply(provider);
          },
        );
        break;

      case "github-copilot":
        credentials = await loginGitHubCopilot({
          onAuth: (url, instructions) => {
            logger.info(`[OAuth] Auth URL for github-copilot: ${url}`);
            onEvent({ type: "auth_url", authUrl: url, instructions });
          },
          onPrompt: async (prompt) => {
            onEvent({ type: "prompt", promptMessage: prompt.message });
            return waitForPromptReply(provider);
          },
          onProgress: (message) => {
            onEvent({ type: "progress", message });
          },
        });
        break;

      case "google-gemini-cli":
        credentials = await loginGeminiCli(
          (info) => {
            logger.info(`[OAuth] Auth URL for google-gemini-cli: ${info.url}`);
            onEvent({ type: "auth_url", authUrl: info.url, instructions: info.instructions });
          },
          (message) => {
            onEvent({ type: "progress", message });
          },
        );
        break;

      case "google-antigravity":
        credentials = await loginAntigravity(
          (info) => {
            logger.info(`[OAuth] Auth URL for google-antigravity: ${info.url}`);
            onEvent({ type: "auth_url", authUrl: info.url, instructions: info.instructions });
          },
          (message) => {
            onEvent({ type: "progress", message });
          },
        );
        break;

      default:
        throw new Error(`Unsupported OAuth provider: ${provider}`);
    }

    setProviderCredentials(provider, { type: "oauth", ...credentials });
    logger.info(`[OAuth] Login successful for ${provider}`);
    onEvent({ type: "done", message: "로그인 완료" });
  } catch (err: any) {
    logger.error(`[OAuth] Login failed for ${provider}:`, err);
    onEvent({ type: "error", message: err?.message || "로그인 실패" });
  }
}

// ─── prompt 응답을 앱에서 보낼 때 사용 ─────────────────────
function waitForPromptReply(provider: OAuthProvider): Promise<string> {
  return new Promise<string>((resolve) => {
    pendingPrompts.set(provider, resolve);
  });
}

export function resolveOAuthPrompt(provider: OAuthProvider, value: string): boolean {
  const resolve = pendingPrompts.get(provider);
  if (resolve) {
    pendingPrompts.delete(provider);
    resolve(value);
    return true;
  }
  return false;
}

// ─── 저장된 credentials로 API Key 획득 (자동 토큰 갱신) ────
export async function getOAuthApiKeyForProvider(provider: OAuthProvider): Promise<string | null> {
  const credentials = getProviderCredentials(provider);
  if (!credentials) return null;

  const credMap = { [provider]: credentials } as any;

  try {
    const result = await getOAuthApiKey(provider as any, credMap);
    if (!result) {
      logger.warn(`[OAuth] getOAuthApiKey returned null for ${provider}`);
      return null;
    }

    // 갱신된 credentials가 있으면 저장
    if (result.newCredentials) {
      setProviderCredentials(provider, { type: "oauth", ...result.newCredentials });
    }

    return result.apiKey;
  } catch (err) {
    logger.error(`[OAuth] Failed to get API key for ${provider}:`, err);
    return null;
  }
}

// ─── 로그인 상태 확인 ────────────────────────────────────────
export function getOAuthStatus(provider: OAuthProvider): { loggedIn: boolean; provider: OAuthProvider } {
  const credentials = getProviderCredentials(provider);
  return { loggedIn: !!credentials, provider };
}

// ─── 로그아웃 ────────────────────────────────────────────────
export function logoutOAuth(provider: OAuthProvider): void {
  deleteProviderCredentials(provider);
  logger.info(`[OAuth] Logged out from ${provider}`);
}

// ─── 모든 OAuth 프로바이더 상태 ────────────────────────────
export function getAllOAuthStatuses() {
  const providers: OAuthProvider[] = ["openai-codex", "anthropic", "github-copilot", "google-gemini-cli", "google-antigravity"];
  return providers.map(getOAuthStatus);
}
