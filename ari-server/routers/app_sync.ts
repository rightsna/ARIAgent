import { router } from "../system/router.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import { getCurrentState, getPluginsInfo } from "../services/agent/index.js";

router.on("/HEALTH", async (ws) => {
  logger.info(`[Health] Check from ${ws.uuid}`);
  const state = getCurrentState();
  const plugins = await getPluginsInfo();
  ws.send("/HEALTH", {
    ok: true,
    data: {
      status: "ok",
      hasApiKey: state.availableProviders.length > 0,
      providers: (state.providers || []).map((p: any) => ({
        provider: p.provider,
        model: p.model,
        hasApiKey: !!p.apiKey,
      })),
      model: state.currentModel,
      provider: state.currentProvider,
      engine: "pi-agent-core",
      tools: plugins.tools.map((t) => t.name),
      skills: plugins.skills.map((s) => s.name),
    },
  });
});

/**
 * /GET_CONNECTED_APPS
 * 현재 서버에 활성 상태로 연결된 앱 ID 목록을 반환합니다.
 */
router.on("/GET_CONNECTED_APPS", async (ws, params) => {
  const connectedIds = UserSocketHandler.getConnectedAppIds();
  ws.send("/GET_CONNECTED_APPS", {
    id: params.id,
    ok: true,
    data: { connectedIds },
  });
});

/**
 * /APP.REGISTER
 * 앱이 자신을 서버에 등록하고 상태를 보고할 때 사용 (Standardized)
 */
router.on("/APP.REGISTER", (ws, params) => {
  const { appId } = params;
  if (!appId) {
    return ws.send("/APP.REGISTER", { ok: false, message: "appId required" });
  }

  // 소켓에 appId만 식별용으로 바인딩 (Pull 방식을 위해)
  ws.appId = appId;
  logger.info(`[AppSync] App registered: ${appId}`);

  // 연결된 앱 목록 브로드캐스트
  UserSocketHandler.broadcastConnectedApps();

  // 성공 응답
  ws.send("/APP.REGISTER", { ok: true, data: { appId } });
});

/**
 * /APP.COMMAND_RESPONSE
 * 명령 실행 후 앱으로부터 결과를 받을 때 (동기식 commandApp 호출의 응답)
 */
router.on("/APP.COMMAND_RESPONSE", (ws, params) => {
  const { requestId, result } = params;
  const appId = ws.appId || "unknown";
  
  // 결과 내부에 에러 정보가 있는지 확인
  const isError = result?.status === "error" || result?.ok === false;
  const statusMsg = isError ? `❌ Error: ${result?.message || "Unknown error"}` : "✅ Success";

  logger.info(`[AppSync] Command response from ${appId} (req:${requestId || "N/A"}): ${statusMsg}`);
  
  if (isError) {
    logger.debug(`[AppSync] Detailed error from ${appId}: ${JSON.stringify(result)}`);
  }
});
