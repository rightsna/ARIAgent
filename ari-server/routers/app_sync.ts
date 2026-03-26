import { router } from "../system/router";
import { UserSocketHandler } from "../system/ws";
import { logger } from "../infra/logger";
import { chatWithAgent } from "../services/agent";

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
 * /APP.REPORT
 * 앱이 서버(및 사용자)에게 자발적으로 보내는 상태 보고 또는 메시지
 * 이제 서버(에이전트)가 이 내용을 읽고 "생각"한 뒤 자연스럽게 답변합니다.
 */
router.on("/APP.REPORT", async (ws, params) => {
  const { appId, message, type } = params;
  logger.info(`[AppSync] Proactive report from ${appId}: ${message} (${type || "info"})`);

  const requestId = `report-${Date.now()}`;
  const proactivePrompt = `[시스템 보고] '${appId}' 앱으로부터 보고가 도착했습니다: "${message}"\n이 정보를 사용자에게 자연스럽게 설명해주고 필요하다면 그에 따른 의견을 덧붙여줘.`;

  try {
    // 에이전트가 생각하고 답변을 생성하도록 유도
    const result = await chatWithAgent(
      proactivePrompt,
      "", // persona
      undefined, // agentId
      { platform: "system" },
      (progressMessage) => {
        // 본앱 UI에 에이전트의 "생각 중" 상태를 전달
        UserSocketHandler.broadcast("/AGENT.PROGRESS", {
          ok: true,
          data: {
            requestId,
            message: progressMessage,
          },
        });
      },
    );

    // 생성된 자연스러운 답변을 본앱 UI로 전송 (자발적 푸시이므로 /AGENT.PUSH 사용)
    UserSocketHandler.broadcast("/AGENT.PUSH", {
      ok: true,
      data: {
        response: result.responseText,
        requestId,
        appId, // 출처 정보 포함
      },
    });
  } catch (err: any) {
    logger.error(`[AppSync] Failed to process proactive report from ${appId}: ${err.message}`);
  }
});

/**
 * /APP.COMMAND_RESPONSE
 * 명령 실행 후 앱으로부터 결과를 받을 때 (선택사항)
 */
router.on("/APP.COMMAND_RESPONSE", (ws, params) => {
  const { appId, command, success, result } = params;
  logger.info(`[AppSync] Command response from ${appId}: ${command} (Success: ${success})`);
});
