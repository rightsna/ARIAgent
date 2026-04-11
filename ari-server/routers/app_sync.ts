import { router } from "../system/router.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import { getCurrentState, getPluginsInfo } from "../services/agent/index.js";
import { getSettings } from "../repositories/setting_repository.js";
import { Settings } from "../models/settings.js";
import { getEmbeddingStatus } from "../services/embedding.js";

router.on("/HEALTH", async (ws) => {
  logger.info(`[Health] Check from ${ws.uuid}`);
  const state = getCurrentState();
  const plugins = await getPluginsInfo();
  const settings = getSettings(new Settings());
  const embStatus = getEmbeddingStatus();
  ws.send("/HEALTH", {
    ok: true,
    data: {
      status: "ok",
      hasApiKey: state.availableProviders.length > 0,
      isSetupMode: state.availableProviders.length > 0 &&
        state.availableProviders.every((p: any) => p.provider === "ari-cloud"),
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
      useAdvancedMemory: settings.USE_ADVANCED_MEMORY,
      embeddingModelStatus: embStatus.status,
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
 * /APP.CALL
 * 외부 클라이언트(debug tool 등)가 특정 앱에 명령을 직접 호출할 때 사용.
 * commandApp()을 호출하고 결과를 요청자에게 돌려줍니다.
 */
router.on("/APP.CALL", async (ws, params) => {
  const { appId, command, params: cmdParams = {}, requestId } = params;

  if (!appId || !command) {
    return ws.send("/APP.CALL", {
      requestId,
      ok: false,
      message: "appId and command are required",
    });
  }

  try {
    const result = await UserSocketHandler.commandApp(appId, command, cmdParams);
    ws.send("/APP.CALL", { requestId, ok: true, result });
  } catch (err: any) {
    ws.send("/APP.CALL", { requestId, ok: false, message: err.message });
  }
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
