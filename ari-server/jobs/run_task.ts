import fs from "fs";
import { Task } from "../models/task.js";
import { getSettings } from "../repositories/setting_repository.js";
import { getTasks, saveTasks } from "../repositories/task_repository.js";
import { getTaskScheduler } from "../services/scheduler/runtime.js";

function timestamp() {
  return new Date().toISOString().replace("T", " ").substring(0, 19);
}

import { WebSocket } from "ws";

import { Settings } from "../models/settings.js";
import { logger } from "../infra/logger.js";

async function getServerPort() {
  const config = getSettings(new Settings());
  return config.PORT || 29277;
}

type RunScheduledTaskOptions = {
  exitProcess?: boolean;
};

export async function runScheduledTask(
  taskId: string,
  options: RunScheduledTaskOptions = {},
): Promise<void> {
  const exitProcess = options.exitProcess === true;
  fs.appendFileSync("/tmp/run_task_ari.log", `[${timestamp()}] STARTING with argv: ${JSON.stringify(process.argv)}\n`);
  logger.info(`[${timestamp()}] 🔔 작업 실행 시작: ${taskId}`);

  const tasks: Task[] = getTasks();
  if (tasks.length === 0) {
    logger.info("❌ tasks.json이 없거나 비어 있습니다.");
    throw new Error("tasks.json이 없거나 비어 있습니다.");
  }
  const task = tasks.find((t: Task) => t.id === taskId);

  if (!task) {
    logger.info(`❌ 작업 ID ${taskId}를 찾을 수 없음`);
    throw new Error(`작업 ID ${taskId}를 찾을 수 없음`);
  }

  if (task.enabled === false) {
    logger.info("⏸️ 비활성 작업 — 스킵");
    return;
  }

  const port = await getServerPort();
  const requestId = `sys-task-${taskId}-${Date.now()}`;
  let responseHandled = false;

  // 단일 WebSocket 연결로 모든 작업 처리 (Persistent Connection 방식)
  await new Promise<void>((resolve, reject) => {
    const ws = new WebSocket(`ws://localhost:${port}`);
    let settled = false;
    let timeoutId: NodeJS.Timeout | null = null;

    const finish = (error?: Error) => {
      if (settled) {
        return;
      }
      settled = true;
      if (timeoutId) {
        clearTimeout(timeoutId);
      }

      if (
        ws.readyState === WebSocket.OPEN ||
        ws.readyState === WebSocket.CONNECTING
      ) {
        ws.close();
      }

      if (error) {
        reject(error);
      } else {
        resolve();
      }
    };

    ws.on("open", () => {
      logger.info(`[${timestamp()}] 🔌 에이전트 연결 성공 (Port: ${port})`);

      // 1. AI 응답 요청 (COMMAND {JSON} 형식)
      const request = `/AGENT ${JSON.stringify({
        message: task.prompt,
        requestId,
        agentId: task.agentId || "default",
        ...(task.appId ? { appId: task.appId } : {}),
      })}`;
      logger.info(`[${timestamp()}] 📤 AI 응답 요청 전송: ${request.substring(0, 100)}...`);
      ws.send(request);
    });

    ws.on("message", async (data) => {
      const dataStr = data.toString();
      logger.info(`[${timestamp()}] 📥 에이전트 응답 수신 raw: ${dataStr.substring(0, 100)}...`);
      try {
        const firstSpace = dataStr.indexOf(" ");
        if (firstSpace === -1) {
          logger.info(`[${timestamp()}] ⚠️ 명령어 없음: ${dataStr}`);
          return;
        }

        const cmd = dataStr.substring(0, firstSpace);
        const res = JSON.parse(dataStr.substring(firstSpace + 1));

        if (cmd === "/AGENT" && res.ok === false) {
          throw new Error(res.message || "스케줄 작업 실행 중 오류가 발생했습니다.");
        }

        if (
          cmd === "/APP.PUSH" &&
          res.ok === true &&
          res.data?.requestId === requestId &&
          !responseHandled
        ) {
          responseHandled = true;
          const response = res.data?.response || "응답 없음";
          logger.info(`[${timestamp()}] ✅ AI 응답 수신완료 (내용: ${response.substring(0, 50)}...)`);

          // 2. UI 알림 요청 (동일한 커넥션 사용 - 로컬 MQ Gateway 역할)
          const notify = `/TASKS.NOTIFY_RESULT ${JSON.stringify({
            taskId,
            label: task.label,
            result: response,
            agentId: task.agentId || "default",
          })}`;
          logger.info(`[${timestamp()}] 📤 UI 알림 전송: ${notify}`);
          ws.send(notify);

          // 마지막 단계: 1회성 스케줄러 삭제 및 마무리
          if (task.isOneOff) {
            await cleanupOneOffTask(taskId, tasks);
          }
        }

        // UI 알림 요청에 대한 확인이 오면 종료 (/TASKS.NOTIFY_RESULT)
        if (cmd === "/TASKS.NOTIFY_RESULT") {
          logger.info(`[${timestamp()}] ✅ 모든 작업 완료 및 UI 알림 전송됨.`);
          finish();
        }
      } catch (err) {
        logger.error(`[${timestamp()}] ❌ 처리 중 오류:`, err);
        finish(err instanceof Error ? err : new Error(String(err)));
      }
    });

    ws.on("error", (err) => {
      logger.error(`❌ 에이전트 연결 실패: ${err.message}`);
      finish(err);
    });

    // 타임아웃 방지
    timeoutId = setTimeout(() => {
      logger.error("❌ 작업 타임아웃 (30초)");
      finish(new Error("작업 타임아웃 (30초)"));
    }, 30000);
  });

  if (exitProcess) {
    process.exit(0);
  }
}

async function main() {
  if (process.argv.length < 3) {
    logger.info("Usage: node run_task.js <task_id>");
    process.exit(1);
  }

  const taskId = process.argv[2];
  await runScheduledTask(taskId, { exitProcess: true });
}

async function cleanupOneOffTask(taskId: string, tasks: Task[]) {
  logger.info(`[${timestamp()}] 🗑️ 1회성 스케줄러 삭제 처리 중...`);
  const remainingTasks = tasks.filter((t: Task) => t.id !== taskId);
  saveTasks(remainingTasks);

  const scheduler = getTaskScheduler();
  if (!scheduler) {
    logger.warn("  ⚠️ 로컬 스케줄러가 초기화되지 않아 즉시 동기화하지 못했습니다.");
    return;
  }

  await scheduler.restoreFromDisk();
  logger.info("  🗓️ 로컬 스케줄러 갱신 완료");
}

function isDirectRunTaskEntry(): boolean {
  const entryFile = process.argv[1];
  return entryFile ? /(?:^|[\\/])run_task\.(?:[cm]?js|ts)$/.test(entryFile) : false;
}

if (isDirectRunTaskEntry()) {
  main().catch((error) => {
    logger.error(error);
    process.exit(1);
  });
}
