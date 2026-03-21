import path from "path";
import { execPromise } from "../tools/bash";
import { Task, ARI_CRON_TAG } from "../models/task";
import { initTasksFileIfMissing, getTasks, saveTasks } from "../repositories/task_repository";
import { ensureTaskResultDirSync, getTaskResultFiles, getTaskResultByFile } from "../repositories/task_result_repository";
import { getCronLogFilePath, getCronTempFilePath, writeCronTempConfig, removeCronTempConfig } from "../repositories/cron_repository";
import { logger } from "../infra/logger";
import { getServerRootDir, isBundledServer } from "../infra/runtime_paths";

// 초기 다운 방지: tasks.json이 없으면 빈 배열로 자동 생성
initTasksFileIfMissing();

// 결과 디렉토리 초기화
ensureTaskResultDirSync();

// 실행 파일 환경 감지 (ts-node 환경이면 .ts 원본 사용, 아니면 dist의 .js 사용)
const isTs = __filename.endsWith(".ts");
const PROJECT_ROOT = getServerRootDir();
export const RUN_TASK_SCRIPT = isTs ? path.join(PROJECT_ROOT, "jobs", "run_task.ts") : path.join(PROJECT_ROOT, "jobs", "run_task.js");

// crontab 실행을 위한 절대 경로 설정
const NODE_BIN = process.execPath;
export const NODE_PATH = isTs ? `${NODE_BIN} -r ts-node/register` : NODE_BIN;

function getTaskRunnerCommand(taskId: string, agentId: string): string {
  if (isBundledServer()) {
    return `"${process.execPath}" --run-task "${taskId}" --agent="${agentId}"`;
  }

  return isTs
    ? `${NODE_BIN} -r ts-node/register "${RUN_TASK_SCRIPT}" "${taskId}" --agent="${agentId}"`
    : `${NODE_BIN} "${RUN_TASK_SCRIPT}" "${taskId}" --agent="${agentId}"`;
}

export function handleGetTasksWs(): { tasks: Task[] } | { error: string } {
  try {
    const data = getTasks();
    return { tasks: data };
  } catch (err: unknown) {
    return { error: (err as Error).message };
  }
}

export async function handleTasksSyncWs(params: Record<string, unknown>): Promise<void> {
  const tasks = params.tasks as Task[];
  saveTasks(tasks);
  logger.info(`📋 tasks.json 동기화: ${tasks.length}개`);
}

export async function handleTasksCrontabWs(params: Record<string, unknown>): Promise<void> {
  const tasks = params.tasks as Task[];
  let existing = "";
  try {
    existing = await execPromise("crontab -l 2>/dev/null");
  } catch {}

  const otherLines = existing.split("\n").filter((l) => l.trim() && !l.includes(ARI_CRON_TAG));
  const ariLines = tasks
    .filter((t) => t.enabled !== false)
    .map((t) => {
      const aid = t.agentId || "default";
      const logFile = getCronLogFilePath();
      const nodePathExport = isBundledServer() ? ` export NODE_PATH="${path.join(PROJECT_ROOT, "node_modules")}" &&` : "";
      // PATH를 명시적으로 지정하여 cron 환경(env)에서 node를 찾을 수 있게 함
      const taskCommand = getTaskRunnerCommand(t.id, aid);
      return `${t.cron} export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH &&${nodePathExport} cd ${PROJECT_ROOT} && ${taskCommand} >> "${logFile}" 2>&1 # ${ARI_CRON_TAG}`;
    });

  const all = [...otherLines, ...ariLines];

  const tmp = getCronTempFilePath();
  const content = all.length > 0 ? all.join("\n") + "\n" : "";
  writeCronTempConfig(content);

  if (all.length > 0) {
    await execPromise(`crontab ${tmp}`);
  } else {
    await execPromise("crontab -r").catch(() => {});
  }
  removeCronTempConfig();
  logger.info(`📅 crontab: ${ariLines.length}개 작업`);
}

export function handleTasksResultsWs(): { results: Record<string, unknown> } | { error: string } {
  try {
    const results: Record<string, unknown> = {};
    const files = getTaskResultFiles();
    for (const f of files) {
      if (f.endsWith(".json")) {
        const d = getTaskResultByFile(f);
        if (d && d.taskId) {
          results[d.taskId as string] = d;
        }
      }
    }
    return { results };
  } catch (err: unknown) {
    return { error: (err as Error).message };
  }
}

export async function registerScheduledTask(taskData: { cron: string; prompt: string; label: string; agentId?: string; isOneOff?: boolean }): Promise<void> {
  const { cron, prompt, label, agentId, isOneOff } = taskData;
  const id = Date.now().toString();

  let tasks: Task[] = getTasks();

  tasks.push({
    id,
    prompt,
    cron,
    label,
    agentId: agentId || "default",
    isOneOff: isOneOff || false,
    enabled: true,
    createdAt: new Date().toISOString(),
  });
  saveTasks(tasks);
  logger.info(`💾 tasks.json 저장 (${tasks.length}개)`);

  try {
    let existing = "";
    try {
      existing = await execPromise("crontab -l 2>/dev/null");
    } catch {}
    const otherLines = existing.split("\n").filter((l) => l.trim() && !l.includes(ARI_CRON_TAG) && !l.includes(id));
    const enabledTasks = tasks.filter((t) => t.enabled !== false);
    const ariLines = enabledTasks.map((t) => {
      const aid = t.agentId || "default";
      const logFile = getCronLogFilePath();
      const nodePathExport = isBundledServer() ? ` export NODE_PATH="${path.join(PROJECT_ROOT, "node_modules")}" &&` : "";
      const taskCommand = getTaskRunnerCommand(t.id, aid);
      return `${t.cron} export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH &&${nodePathExport} cd ${PROJECT_ROOT} && ${taskCommand} >> "${logFile}" 2>&1 # ${ARI_CRON_TAG}`;
    });
    const all = [...otherLines, ...ariLines];
    const tmp = getCronTempFilePath();
    const content = all.length > 0 ? all.join("\n") + "\n" : "";
    writeCronTempConfig(content);

    if (all.length > 0) {
      await execPromise(`crontab ${tmp}`);
    } else {
      await execPromise("crontab -r").catch(() => {});
    }
    removeCronTempConfig();
    logger.info(`📅 crontab 업데이트 (${ariLines.length}개)`);
  } catch (e: unknown) {
    logger.error("❌ crontab 등록 실패:", (e as Error).message);
  }
}
