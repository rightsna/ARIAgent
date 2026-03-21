import { router } from "../system/router";
import { handleGetTasksWs, handleTasksSyncWs, handleTasksCrontabWs, handleTasksResultsWs } from "../services/task";
import { UserSocketHandler } from "../system/ws";
import { logger } from "../infra/logger";

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

// 크론 작업(run_task.ts)으로부터 결과를 받아 모든 클라이언트에게 브로드캐스트
router.on("/TASKS.NOTIFY_RESULT", async (ws, params) => {
  logger.info(`📡 Inbound: /TASKS.NOTIFY_RESULT from client [${ws.uuid}] for [${params.label || "unknown"}]`);

  // 브로드캐스트 데이터 구성
  const broadcastData = {
    taskId: params.taskId,
    label: params.label,
    result: params.result,
    executedAt: new Date().toISOString(),
  };

  // /TASK_RESULT 채널로 모든 클라이언트에게 전송 (MQ의 Publish 역할)
  UserSocketHandler.broadcast("/TASK_RESULT", broadcastData);

  logger.info(`📡 MQ: Broadcaster finished for [${params.label || "unknown"}]`);
  ws.send("/TASKS.NOTIFY_RESULT", { ok: true });
});
