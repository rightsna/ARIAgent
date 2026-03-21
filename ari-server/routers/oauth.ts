import { router } from "../system/router";
import { startOAuthLogin, resolveOAuthPrompt, getOAuthStatus, logoutOAuth, getAllOAuthStatuses, OAUTH_PROVIDER_LABELS, type LoginEvent } from "../services/oauth";
import type { OAuthProvider } from "../repositories/oauth_repository";
import { logger } from "../infra/logger";

// ─── 지원 프로바이더 목록 조회 ───────────────────────────────
router.on("/OAUTH_PROVIDERS", async (ws, _params) => {
  const statuses = getAllOAuthStatuses();
  ws.send("/OAUTH_PROVIDERS", {
    ok: true,
    data: {
      providers: statuses.map((s) => ({
        id: s.provider,
        label: OAUTH_PROVIDER_LABELS[s.provider],
        loggedIn: s.loggedIn,
      })),
    },
  });
});

// ─── 로그인 플로우 시작 ──────────────────────────────────────
// 로그인 진행 이벤트는 별도의 push 메시지(/OAUTH_EVENT)로 앱에 전송
router.on("/OAUTH_LOGIN", async (ws, params) => {
  const provider = params.provider as OAuthProvider;
  if (!provider) {
    return ws.send("/OAUTH_LOGIN", { ok: false, message: "provider is required" });
  }

  logger.info(`[OAuthRouter] Starting OAuth login for: ${provider}`);

  // 즉시 시작 응답 후 비동기 로그인 실행
  ws.send("/OAUTH_LOGIN", { ok: true, data: { started: true, provider } });

  startOAuthLogin(provider, (event: LoginEvent) => {
    ws.send("/OAUTH_EVENT", { provider, ...event });
  }).catch((err) => {
    logger.error(`[OAuthRouter] Unexpected error in login flow for ${provider}:`, err);
    ws.send("/OAUTH_EVENT", { provider, type: "error", message: err?.message || "Unknown error" });
  });
});

// ─── 사용자 입력(코드) 전달 ──────────────────────────────────
router.on("/OAUTH_PROMPT", async (ws, params) => {
  const provider = params.provider as OAuthProvider;
  const value = params.value as string;

  if (!provider || value === undefined) {
    return ws.send("/OAUTH_PROMPT", { ok: false, message: "provider and value are required" });
  }

  const resolved = resolveOAuthPrompt(provider, value);
  ws.send("/OAUTH_PROMPT", { ok: true, data: { resolved } });
});

// ─── 특정 프로바이더 로그인 상태 조회 ─────────────────────
router.on("/OAUTH_STATUS", async (ws, params) => {
  const provider = params.provider as OAuthProvider;
  if (!provider) {
    return ws.send("/OAUTH_STATUS", { ok: false, message: "provider is required" });
  }

  const status = getOAuthStatus(provider);
  ws.send("/OAUTH_STATUS", {
    ok: true,
    data: {
      provider: status.provider,
      loggedIn: status.loggedIn,
      label: OAUTH_PROVIDER_LABELS[provider],
    },
  });
});

// ─── 로그아웃 ──────────────────────────────────────────────
router.on("/OAUTH_LOGOUT", async (ws, params) => {
  const provider = params.provider as OAuthProvider;
  if (!provider) {
    return ws.send("/OAUTH_LOGOUT", { ok: false, message: "provider is required" });
  }

  logoutOAuth(provider);
  ws.send("/OAUTH_LOGOUT", { ok: true, data: { provider, loggedOut: true } });
});
