import { router } from "../system/router";
import { readChatLogs, clearChatLogs } from "../repositories/chat_log_repository";

/**
 * /CHAT.GET_HISTORY {agentId, index, size}
 * 특정 에이전트의 대화 이력을 조회합니다.
 */
router.on("/CHAT.GET_HISTORY", async (ws, params) => {
  const { agentId, index = 0, size = 20 } = params;
  
  if (!agentId) {
    return ws.send("/CHAT.GET_HISTORY", { ok: false, message: "agentId required" });
  }

  try {
    const { logs, total } = readChatLogs(agentId as string, Number(index), Number(size));
    ws.send("/CHAT.GET_HISTORY", { ok: true, data: { logs, total } });
  } catch (err: any) {
    ws.send("/CHAT.GET_HISTORY", { ok: false, message: err.message });
  }
});

/**
 * /CHAT.CLEAR {agentId}
 * 특정 에이전트의 대화 이력을 삭제합니다.
 */
router.on("/CHAT.CLEAR", async (ws, params) => {
  const { agentId } = params;
  
  if (!agentId) {
    return ws.send("/CHAT.CLEAR", { ok: false, message: "agentId required" });
  }

  try {
    clearChatLogs(agentId as string);
    ws.send("/CHAT.CLEAR", { ok: true, data: { agentId } });
  } catch (err: any) {
    ws.send("/CHAT.CLEAR", { ok: false, message: err.message });
  }
});
