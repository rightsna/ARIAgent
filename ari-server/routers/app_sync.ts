import { router } from "../system/router";
import { appStateService } from "../services/app_state_service";
import { UserSocketHandler } from "../system/ws";
import { logger } from "../infra/logger";

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

  // 성공 응답
  ws.send("/APP.REGISTER", { ok: true, data: { appId } });
});

/**
 * /APP.COMMAND.RESPONSE
 * 명령 실행 후 앱으로부터 결과를 받을 때 (선택사항)
 */
router.on("/APP.COMMAND_RESPONSE", (ws, params) => {
  const { appId, command, success, result } = params;
  logger.info(`[AppSync] Command response from ${appId}: ${command} (Success: ${success})`);
});
