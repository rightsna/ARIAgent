import { router } from "../system/router";
import { handleGetTasksWs, handleTasksSyncWs, handleTasksCrontabWs, handleTasksResultsWs, handleAddTaskWs, handleDeleteTaskWs, handleToggleTaskWs, handleRunTaskWs } from "../services/task";
import { UserSocketHandler } from "../system/ws";
import { logger } from "../infra/logger";
import { appendChatLog } from "../repositories/chat_log_repository";
import { getActiveAgentId } from "../services/memory";

router.on("/TASKS", async (ws, params) => {
  const data = await handleGetTasksWs();
  ws.send("/TASKS", { ok: true, data: data });
});

router.on("/TASKS.SYNC", async (ws, params) => {
  await handleTasksSyncWs(params);
  ws.send("/TASKS.SYNC", { ok: true, data: { success: true } });
});

router.on("/TASKS.CRONTAB", async (ws, params) => {
  await handleTasksCrontabWs(params);
  ws.send("/TASKS.CRONTAB", { ok: true, data: { success: true } });
});

router.on("/TASKS.RESULTS", async (ws, params) => {
  const data = await handleTasksResultsWs();
  ws.send("/TASKS.RESULTS", { ok: true, data: data });
});

// ── 개별 CRUD API ──

router.on("/TASKS.ADD", async (ws, params) => {
  const data = await handleAddTaskWs(params);
  ws.send("/TASKS.ADD", { ok: true, data });
});

router.on("/TASKS.DELETE", async (ws, params) => {
  const data = await handleDeleteTaskWs(params);
  ws.send("/TASKS.DELETE", { ok: true, data });
});

router.on("/TASKS.TOGGLE", async (ws, params) => {
  const data = await handleToggleTaskWs(params);
  ws.send("/TASKS.TOGGLE", { ok: true, data });
});

router.on("/TASKS.RUN", async (ws, params) => {
  const data = await handleRunTaskWs(params);
  ws.send("/TASKS.RUN", { ok: true, data });
});

// 크론 작업(run_task.ts)으로부터 결과를 받아 모든 클라이언트에게 브로드캐스트
router.on("/TASKS.NOTIFY_RESULT", async (ws, params) => {
  logger.info(`📡 Inbound: /TASKS.NOTIFY_RESULT from client [${ws.uuid}] for [${params.label || "unknown"}]`);

  const agentId = getActiveAgentId();

  // 브로드캐스트 데이터 구성
  const broadcastData = {
    taskId: params.taskId,
    label: params.label,
    result: params.result,
    executedAt: new Date().toISOString(),
  };

  // 태스크 결과 저장
  appendChatLog(agentId, {
    type: 'task',
    taskId: params.taskId,
    label: params.label,
    result: params.result
  });

  // /TASK_RESULT 채널로 모든 클라이언트에게 전송 (MQ의 Publish 역할)
  UserSocketHandler.broadcast("/TASK_RESULT", broadcastData);

  logger.info(`📡 MQ: Broadcaster finished for [${params.label || "unknown"}]`);
  ws.send("/TASKS.NOTIFY_RESULT", { ok: true });
});

