import { getModel } from "@mariozechner/pi-ai";
import { AIProviderConfig, AIProviders } from "../../models/settings.js";
import { getOAuthApiKeyForProvider } from "../oauth/index.js";
import type { OAuthProvider } from "../../repositories/oauth_repository.js";

// 이제 서버는 별도의 매핑 테이블을 관리하지 않습니다.
// 모든 ID 제어는 클라이언트(ari-app)의 provider_meta.dart에서 수행합니다.

export function providerNameFor(config: AIProviderConfig): string {
  return config.provider;
}

export function modelNameFor(config: AIProviderConfig): string {
  return config.model;
}

export function resolveModel(config: AIProviderConfig) {
  const provider = providerNameFor(config);
  const modelId = modelNameFor(config);
  let model = getModel(provider as any, modelId as any);

  if (!model) {
    throw new Error(`Model ${modelId} not found in provider ${provider}.`);
  }

  return model;
}

// OAuth 프로바이더 목록
const OAUTH_PROVIDERS = new Set<string>(["openai-codex", "github-copilot", "google-gemini-cli", "google-antigravity"]);

export function isOAuthProvider(provider: string): boolean {
  return OAUTH_PROVIDERS.has(provider);
}

// OAuth 프로바이더의 API Key를 동적으로 획득한다
export async function resolveApiKey(config: AIProviderConfig): Promise<string | null> {
  if (config.authType === "oauth" || isOAuthProvider(config.provider)) {
    return await getOAuthApiKeyForProvider(config.provider as OAuthProvider);
  }
  return config.apiKey || null;
}

export function createApiKeyResolver(
  getCurrentApiKey: () => string | undefined,
) {
  return () => getCurrentApiKey();
}

export function findFirstUsableProvider(
  providers: AIProviders,
  onInvalid?: (
    provider: AIProviders["availableProviders"][number],
    error: unknown,
  ) => void,
): { provider: AIProviderConfig; index: number } {
  for (let i = 0; i < providers.availableProviders.length; i++) {
    try {
      resolveModel(providers.availableProviders[i]);
      return { provider: providers.availableProviders[i], index: i };
    } catch (error) {
      onInvalid?.(providers.availableProviders[i], error);
    }
  }

  throw new Error("No valid AI provider model configuration found.");
}

export function getAttemptOrder(providerCount: number, startIndex: number): number[] {
  if (providerCount === 0) {
    return [];
  }

  const normalizedStart = ((startIndex % providerCount) + providerCount) % providerCount;
  return Array.from({ length: providerCount }, (_, offset) => (normalizedStart + offset) % providerCount);
}
