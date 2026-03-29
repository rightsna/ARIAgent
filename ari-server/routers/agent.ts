import { router } from "../system/router";
import { chatWithAgent } from "../services/agent";

// /AGENT
router.on("/AGENT", async (ws, params) => {
  const message = params.message as string;
  const requestId = (params.requestId as string) || "";
  const persona = (params.persona as string) || "";
  const avatarName = (params.avatarName as string) || "";
  const platform = (params.platform as string) || "";
  const agentId = params.agentId as string;

  if (!message) {
    return ws.send("/AGENT", { ok: false, message: "message required" });
  }

  try {
    const result = await chatWithAgent(
      message,
      persona,
      agentId,
      {
        avatarName,
        platform,
      },
      (progressMessage) => {
        ws.send("/AGENT.PROGRESS", {
          ok: true,
          data: {
            requestId,
            message: progressMessage,
          },
        });
      },
    );
    ws.send("/AGENT", {
      ok: true,
      data: { response: result.responseText, requestId },
    });
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

// /AGENT.HISTORY
router.on("/AGENT.HISTORY", async (ws, params) => {
  const agentId = params.agentId as string;
  const { getChatLogs } = require("../repositories/chat_log_repository");
  const history = getChatLogs(agentId);
  ws.send("/AGENT.HISTORY", { ok: true, data: { history, agentId } });
});
