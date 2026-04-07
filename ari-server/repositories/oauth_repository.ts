import path from "path";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync } from "../infra/data.js";
import { logger } from "../infra/logger.js";

export type OAuthProvider = "openai-codex" | "anthropic" | "github-copilot" | "google-gemini-cli" | "google-antigravity";

export interface OAuthCredentials {
  type: "oauth";
  [key: string]: any;
}

export type OAuthCredentialsMap = Partial<Record<OAuthProvider, OAuthCredentials>>;

const OAUTH_FILE = path.join(DATA_DIR, "oauth.json");

export function loadOAuthCredentials(): OAuthCredentialsMap {
  if (!fileExistsSync(OAUTH_FILE)) {
    return {};
  }
  try {
    return readJsonSync<OAuthCredentialsMap>(OAUTH_FILE) ?? {};
  } catch (e) {
    logger.error("[OAuthRepo] Failed to load oauth.json:", e);
    return {};
  }
}

export function saveOAuthCredentials(map: OAuthCredentialsMap): void {
  try {
    writeJsonSync(OAUTH_FILE, map);
    logger.info("[OAuthRepo] OAuth credentials saved.");
  } catch (e) {
    logger.error("[OAuthRepo] Failed to save oauth.json:", e);
  }
}

export function getProviderCredentials(provider: OAuthProvider): OAuthCredentials | null {
  const map = loadOAuthCredentials();
  return map[provider] ?? null;
}

export function setProviderCredentials(provider: OAuthProvider, credentials: OAuthCredentials): void {
  const map = loadOAuthCredentials();
  map[provider] = credentials;
  saveOAuthCredentials(map);
}

export function deleteProviderCredentials(provider: OAuthProvider): void {
  const map = loadOAuthCredentials();
  delete map[provider];
  saveOAuthCredentials(map);
}
