import { router } from "../system/router";
import { chatWithAgent } from "../services/agent";
import { Prompt } from "../infra/prompt";
import { UserSocketHandler } from "../system/ws";

// /AGENT
router.on("/AGENT", async (ws, params) => {
  const {
    requestId = "",
    persona = "",
    avatarName = "",
    platform = "",
    agentId,
    source = "user", // 'user' | 'app'
    appId,
    type,
    details,
    broadcast: shouldBroadcast = false,
  } = params;

  let message = params.message as string;

  if (!message) {
    return ws.send("/AGENT", { ok: false, message: "message required" });
  }

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
        const payload = {
          ok: true,
          data: { requestId, message: progressMessage },
        };
        // 브로드캐스트 모드이거나 앱 소스인 경우 전체 방송
        if (shouldBroadcast || source === "app") {
          UserSocketHandler.broadcast("/AGENT.PROGRESS", payload);
        } else {
          ws.send("/AGENT.PROGRESS", payload);
        }
      },
    );

    const responsePayload = {
      ok: true,
      data: { response: result.responseText, requestId, appId },
    };

    // 최종 응답 전송 방식 결정
    if (shouldBroadcast || source === "app") {
      // 자발적 보고에 대한 답변은 /AGENT 대신 /AGENT.PUSH로 방송 (채팅방 UI 트리거용)
      UserSocketHandler.broadcast("/AGENT.PUSH", responsePayload);
      // 요청자에게는 작업 완료 응답만 별도로 전송 (command call fulfillment용)
      ws.send("/AGENT", { ok: true, data: { status: "broadcasted", requestId } });
    } else {
      ws.send("/AGENT", responsePayload);
    }
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

// /AGENT.SET_HISTORY
router.on("/AGENT.SET_HISTORY", async (ws, params) => {
  const agentId = params.agentId as string;
  const history = params.history as any[];
  if (!agentId || !history) return;

  const { setAgentHistory } = require("../services/agent");
  setAgentHistory(agentId, history);
  ws.send("/AGENT.SET_HISTORY", { ok: true, data: { agentId, count: history.length } });
});
