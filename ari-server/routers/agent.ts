import { router } from "../system/router";
import { chatWithAgent } from "../services/agent";
import { Prompt } from "../infra/prompt";
import { UserSocketHandler } from "../system/ws";
import { appendChatLog } from "../repositories/chat_log_repository";

// /AGENT
router.on("/AGENT", async (ws, params) => {
  const {
    requestId = "",
    persona = "",
    avatarName = "",
    platform = "",
    agentId,
    source = "user", // 'user' | 'app' — 앱 소스일 경우 메시지 템플릿 래핑에 사용
    appId,
    type,
    details,
  } = params;

  let message = params.message as string;

  if (!message) {
    return ws.send("/AGENT", { ok: false, message: "message required" });
  }

  // 사용자 질문 저장
  appendChatLog(agentId, { type: 'chat', isUser: true, message, requestId });

  // 사용자 질문을 모든 클라이언트에 브로드캐스트 (주식앱 등 다른 앱의 채팅창에도 표시)
  // /AGENT 재사용 시 루프 위험이 있으므로 별도 프로토콜 사용
  UserSocketHandler.broadcast("/AGENT.REQUEST", { message: params.message, requestId });

  // 앱 소스인 경우 템플릿 적용 (동적 래핑)
  if (source === "app") {
    message = await Prompt.load("app_report.hbs", {
      appId: appId || ws.appId || "unknown",
      message,
      type: type || "info",
      detailsJson: JSON.stringify(details || {}),
    });
  }

  try {
    const result = await chatWithAgent(
      message,
      persona,
      agentId,
      {
        avatarName: avatarName || (source === "app" ? "ARI" : undefined),
        platform: platform || (source === "app" ? "system" : undefined),
      },
      (progressMessage) => {
        // 프로그래스는 항상 전체 브로드캐스트
        UserSocketHandler.broadcast("/AGENT.PROGRESS", {
          ok: true,
          data: { requestId, message: progressMessage },
        });
      },
    );

    // AI 응답 저장
    appendChatLog(agentId, { type: 'chat', isUser: false, message: result.responseText, requestId });

    // 응답은 항상 /APP.PUSH 로 전체 브로드캐스트 (본앱, 써드파티앱 모두 수신)
    UserSocketHandler.broadcast("/APP.PUSH", {
      ok: true,
      data: { response: result.responseText, requestId, appId },
    });

    // 요청자에게 완료 확인 (call 의 Promise 해제용)
    ws.send("/AGENT", { ok: true, data: { status: "broadcasted", requestId } });
  } catch (err: any) {
    ws.send("/AGENT", { ok: false, message: err.message });
  }
});

// /AGENT.CANCEL
router.on("/AGENT.CANCEL", async (ws, params) => {
  const agentId = params.agentId as string;
  if (!agentId) return;

  const { abortAgent } = require("../services/agent");
  abortAgent(agentId);
  ws.send("/AGENT.CANCEL", { ok: true, data: { agentId } });
});
