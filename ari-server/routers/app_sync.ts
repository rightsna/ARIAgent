import { router } from "../system/router";
import { UserSocketHandler } from "../system/ws";
import { logger } from "../infra/logger";
import { chatWithAgent } from "../services/agent";
import { Prompt } from "../infra/prompt";

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
