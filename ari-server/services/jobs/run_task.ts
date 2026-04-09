import fs from "fs";
import path from "path";
import os from "os";
import { spawn } from "child_process";

import { Task } from "../../models/task.js";
import { AgentInfo } from "../../models/agent.js";
import { Settings } from "../../models/settings.js";
import { getSettings } from "../../repositories/setting_repository.js";
import { getTasks, saveTasks } from "../../repositories/task_repository.js";
import { getTaskScheduler } from "../scheduler/runtime.js";
import { executeAgentRequest } from "../agent/index.js";
import { UserSocketHandler } from "../../system/ws.js";
import { findAppExecutable } from "../../infra/runtime_paths.js";
import { DATA_DIR } from "../../infra/data.js";
import { logger } from "../../infra/logger.js";

const DEFAULT_TIMEOUT_SEC = 120;
const APP_CONNECT_WAIT_MS = 30_000;
const APP_CONNECT_POLL_MS = 500;

// ──────────────────────────────────────────────────────────────────────────────
// App lifecycle helpers
// ──────────────────────────────────────────────────────────────────────────────

async function launchAppHeadless(appId: string, port: number): Promise<void> {
  const executable = findAppExecutable(appId);
  if (!executable) throw new Error(`실행 파일을 찾을 수 없습니다: ${appId}`);

  const launchLogDir = path.join(DATA_DIR, "launch-logs");
  fs.mkdirSync(launchLogDir, { recursive: true });
  const launchLogPath = path.join(launchLogDir, `${appId}.log`);
  const stdoutFd = fs.openSync(launchLogPath, "a");
  const stderrFd = fs.openSync(launchLogPath, "a");

  const headlessArgs = [`--headless`, `--port=${port}`];
  const bundlePath =
    process.platform === "darwin"
      ? executable.split("/Contents/MacOS/")[0]
      : null;

  const launcherExecutable = process.platform === "darwin" ? "open" : executable;
  const launcherArgs =
    process.platform === "darwin" && bundlePath
      ? ["-n", bundlePath, "--args", ...headlessArgs]
      : headlessArgs;

  const child = spawn(launcherExecutable, launcherArgs, {
    detached: process.platform !== "darwin",
    stdio: ["ignore", stdoutFd, stderrFd],
    cwd: path.dirname(executable),
    env: {
      ...process.env,
      HOME: process.env.HOME ?? os.homedir(),
      USERPROFILE: process.env.USERPROFILE ?? os.homedir(),
    },
  });

  child.on("error", (err) =>
    logger.error(`[AppLifecycle] ${appId} 실행 실패: ${err.message}`),
  );
  child.on("spawn", () =>
    logger.info(`[AppLifecycle] ${appId} spawned (pid: ${child.pid ?? "unknown"})`),
  );
  child.unref();
}

async function waitForAppConnection(appId: string): Promise<void> {
  const deadline = Date.now() + APP_CONNECT_WAIT_MS;
  while (Date.now() < deadline) {
    if (UserSocketHandler.isAppConnected(appId)) return;
    await new Promise((r) => setTimeout(r, APP_CONNECT_POLL_MS));
  }
  throw new Error(`앱 '${appId}'이 ${APP_CONNECT_WAIT_MS / 1000}초 내에 연결되지 않았습니다.`);
}

async function checkIsHeadless(appId: string): Promise<boolean> {
  try {
    const status = await UserSocketHandler.commandApp(appId, "GET_APP_STATUS");
    return status?.data?.isHeadless === true;
  } catch {
    return false; // 확인 실패 시 안전하게 종료하지 않음
  }
}

async function terminateApp(appId: string): Promise<void> {
  await new Promise<void>((resolve) => {
    let child;
    if (process.platform === "darwin") {
      child = spawn("pkill", ["-x", appId], { stdio: "ignore" });
    } else if (process.platform === "win32") {
      child = spawn("taskkill", ["/IM", `${appId}.exe`, "/F"], {
        stdio: "ignore",
        windowsHide: true,
      });
    } else {
      resolve();
      return;
    }
    child.on("error", () => resolve());
    child.on("exit", () => resolve());
  });
  await new Promise((r) => setTimeout(r, 250));
}

// ──────────────────────────────────────────────────────────────────────────────
// Main entry
// ──────────────────────────────────────────────────────────────────────────────

type RunScheduledTaskOptions = {
  exitProcess?: boolean;
};

export async function runScheduledTask(
  taskOrId: Task | string,
  options: RunScheduledTaskOptions = {},
): Promise<void> {
  // Task 객체 또는 ID 문자열 모두 수용
  let task: Task | undefined;
  if (typeof taskOrId === "string") {
    task = getTasks().find((t: Task) => t.id === taskOrId);
    if (!task) throw new Error(`작업 ID ${taskOrId}를 찾을 수 없음`);
  } else {
    task = taskOrId;
  }

  logger.info(`🔔 작업 실행 시작: ${task.id} (${task.label})`);

  if (!task.enabled) {
    logger.info("⏸️ 비활성 작업 — 스킵");
    return;
  }

  const timeoutMs = (task.timeout ?? DEFAULT_TIMEOUT_SEC) * 1000;
  const managedAppId = task.managedAppId;
  let launchedByTask = false;

  // ── 앱 라이프사이클: 실행 전 ───────────────────────────────────────────────
  if (managedAppId) {
    if (UserSocketHandler.isAppConnected(managedAppId)) {
      logger.info(`✅ '${managedAppId}' 이미 연결됨 — 런치 스킵`);
    } else {
      logger.info(`🚀 '${managedAppId}' 연결 안됨 → 헤드리스 런치`);
      try {
        const config = getSettings(new Settings());
        const port = config.PORT || 29277;
        await launchAppHeadless(managedAppId, port);
        await waitForAppConnection(managedAppId);
        launchedByTask = true;
        logger.info(`✅ '${managedAppId}' 연결 완료`);
      } catch (err: any) {
        const errorMsg = `앱 런치 실패: ${err.message}`;
        logger.error(`❌ ${errorMsg}`);
        persistTaskResult(task.id, { lastRunAt: new Date().toISOString(), lastError: errorMsg });
        if (options.exitProcess) process.exit(1);
        return;
      }
    }
  }

  // ── AI 에이전트 직접 호출 ────────────────────────────────────────────────
  try {
    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(
        () => reject(new Error(`작업 타임아웃 (${task.timeout ?? DEFAULT_TIMEOUT_SEC}초)`)),
        timeoutMs,
      ),
    );

    const result = await Promise.race([
      executeAgentRequest({
        message: task.prompt,
        requestId: task.id,
        agentId: task.agentId || "default",
        appId: task.appId,
        source: "task",
        waitForCompletion: true,
      }),
      timeoutPromise,
    ]);

    if (result.status === "cancelled") {
      throw new Error("작업이 취소되었습니다.");
    }

    const responseText = result.responseText || "응답 없음";
    logger.info(`✅ 완료: ${responseText.substring(0, 80)}...`);
    const executedAt = new Date().toISOString();

    persistTaskResult(task.id, {
      lastRunAt: executedAt,
      lastResult: responseText,
      lastError: undefined,
    });

    UserSocketHandler.broadcast("/TASK_RESULT", {
      taskId: task.id,
      agentId: task.agentId || "default",
      label: task.label,
      result: responseText,
      executedAt,
    });

    if (task.isOneOff) {
      await cleanupOneOffTask(task.id);
    }
  } catch (err: any) {
    logger.error(`❌ 실행 오류: ${err.message}`);
    persistTaskResult(task.id, {
      lastRunAt: new Date().toISOString(),
      lastError: err.message,
    });
  } finally {
    // ── 앱 라이프사이클: 실행 후 ─────────────────────────────────────────────
    if (launchedByTask && managedAppId) {
      const isHeadless = await checkIsHeadless(managedAppId);
      if (isHeadless) {
        logger.info(`🛑 헤드리스 앱 '${managedAppId}' 종료`);
        await terminateApp(managedAppId).catch((err) =>
          logger.warn(`⚠️ 앱 종료 실패: ${err.message}`),
        );
      } else {
        logger.info(`ℹ️ '${managedAppId}' UI 모드로 전환됨 — 종료 스킵`);
      }
    }
  }

  if (options.exitProcess) process.exit(0);
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

async function cleanupOneOffTask(taskId: string) {
  saveTasks(getTasks().filter((t: Task) => t.id !== taskId));
  const scheduler = getTaskScheduler();
  if (scheduler) await scheduler.restoreFromDisk();
}

function persistTaskResult(
  taskId: string,
  data: { lastRunAt: string; lastResult?: string; lastError?: string },
): void {
  const tasks = getTasks();
  const index = tasks.findIndex((t) => t.id === taskId);
  if (index === -1) return;

  tasks[index].lastRunAt = data.lastRunAt;
  if (data.lastResult !== undefined) tasks[index].lastResult = data.lastResult;
  if (data.lastError !== undefined) tasks[index].lastError = data.lastError;
  else delete tasks[index].lastError;

  saveTasks(tasks);
}

// ──────────────────────────────────────────────────────────────────────────────
// CLI entry (하위 호환 — 직접 실행 시)
// ──────────────────────────────────────────────────────────────────────────────

function isDirectRunTaskEntry(): boolean {
  const entryFile = process.argv[1];
  return entryFile ? /(?:^|[\\/])run_task\.(?:[cm]?js|ts)$/.test(entryFile) : false;
}

if (isDirectRunTaskEntry()) {
  const taskId = process.argv[2];
  if (!taskId) {
    logger.info("Usage: node run_task.js <task_id>");
    process.exit(1);
  }
  runScheduledTask(taskId, { exitProcess: true }).catch((err) => {
    logger.error(err);
    process.exit(1);
  });
}
