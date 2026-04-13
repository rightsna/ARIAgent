import { Task } from "../models/task.js";
import type { ScheduleSpec } from "../models/schedule_spec.js";
import { initTasksFileIfMissing, getTasks, saveTasks } from "../repositories/task_repository.js";
import { logger } from "../infra/logger.js";
import { getTaskScheduler } from "./scheduler/runtime.js";
import { runScheduledTask } from "./jobs/run_task.js";
import { UserSocketHandler } from "../system/ws.js";

// 초기 다운 방지: tasks.json이 없으면 빈 배열로 자동 생성
initTasksFileIfMissing();

// 서버 시작 시 만료된 1회성 태스크 정리
cleanupExpiredOneOffTasks();

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
  await refreshScheduler();
}

export async function handleTasksCrontabWs(_params: Record<string, unknown>): Promise<void> {
  const scheduler = getTaskScheduler();
  if (!scheduler) {
    logger.warn("[LocalTaskScheduler] Sync requested before scheduler initialization.");
    return;
  }

  const result = await scheduler.restoreFromDisk();
  logger.info(
    `[LocalTaskScheduler] Sync complete: ${result.restored.length} restored, ${result.failed.length} failed.`,
  );
}

// ── 스케줄러 자동 갱신 + 모든 클라이언트에 변경 알림 ──
export async function refreshScheduler(): Promise<void> {
  await handleTasksCrontabWs({});
  UserSocketHandler.broadcast("/TASKS.UPDATED", { tasks: getTasks() });
}

/** @deprecated refreshScheduler 사용 권장 */
export const refreshCrontab = refreshScheduler;

// ── 개별 CRUD API 핸들러 ──

export async function handleAddTaskWs(params: Record<string, unknown>): Promise<{ task: Task }> {
  const id = Date.now().toString();
  const now = new Date().toISOString();
  const startAt = (params.startAt as string) || now;

  // 1회성 태스크: endAt = startAt + 59초 (별도 지정이 없으면 자동 설정)
  const endAt: string | undefined =
    (params.endAt as string | undefined) ??
    (params.isOneOff ? new Date(new Date(startAt).getTime() + 59_000).toISOString() : undefined);

  const task = new Task({
    id,
    prompt: params.prompt,
    scheduleSpec: params.scheduleSpec,
    label: params.label,
    agentId: params.agentId || "default",
    appId: params.appId,
    isOneOff: params.isOneOff || false,
    enabled: true,
    startAt,
    endAt,
    createdAt: now,
  });

  const tasks = getTasks();
  tasks.push(task);
  saveTasks(tasks);
  logger.info(`➕ Task 추가: "${task.label}" [${tasks.length}개]`);

  await refreshScheduler();
  return { task };
}

export async function handleDeleteTaskWs(params: Record<string, unknown>): Promise<{ success: boolean }> {
  const taskId = params.taskId as string;
  const tasks = getTasks();
  const filtered = tasks.filter((t) => t.id !== taskId);

  if (filtered.length === tasks.length) {
    logger.warn(`⚠️ Task 삭제 실패: ID ${taskId} 없음`);
    return { success: false };
  }

  saveTasks(filtered);
  logger.info(`🗑️ Task 삭제: ${taskId} [${filtered.length}개 남음]`);

  await refreshScheduler();
  return { success: true };
}

export async function handleToggleTaskWs(params: Record<string, unknown>): Promise<{ task: Task | null }> {
  const taskId = params.taskId as string;
  const tasks = getTasks();
  const idx = tasks.findIndex((t) => t.id === taskId);

  if (idx === -1) {
    logger.warn(`⚠️ Task 토글 실패: ID ${taskId} 없음`);
    return { task: null };
  }

  tasks[idx].enabled = !tasks[idx].enabled;
  saveTasks(tasks);
  logger.info(`🔄 Task 토글: "${tasks[idx].label}" → ${tasks[idx].enabled ? "활성" : "비활성"}`);

  await refreshScheduler();
  return { task: tasks[idx] };
}

export async function handleRunTaskWs(
  params: Record<string, unknown>,
): Promise<{ taskId: string; started: boolean }> {
  const taskId = params.taskId as string;
  const tasks = getTasks();
  const task = tasks.find((t) => t.id === taskId);

  if (!task) {
    throw new Error(`Task ID ${taskId}를 찾을 수 없음`);
  }

  await runScheduledTask(task);
  return { taskId: task.id, started: true };
}

// ── Agent Tool용 ──

export async function registerScheduledTask(taskData: {
  scheduleSpec?: ScheduleSpec;
  prompt: string;
  label: string;
  agentId?: string;
  appId?: string;
  isOneOff?: boolean;
  startAt?: string;
  endAt?: string;
}): Promise<void> {
  const { scheduleSpec, prompt, label, agentId, appId, isOneOff, startAt, endAt } = taskData;
  await handleAddTaskWs({
    scheduleSpec,
    prompt,
    label,
    agentId: agentId || "default",
    appId,
    isOneOff: isOneOff || false,
    startAt,
    endAt,
  });
}

// 서버 시작 시 이미 지나간 1회성 태스크를 tasks.json에서 제거
export function cleanupExpiredOneOffTasks(): void {
  const tasks = getTasks();
  const now = new Date();

  const expired = tasks.filter((t) => {
    if (!t.isOneOff) return false;
    const runAt = new Date(t.startAt);
    return !Number.isNaN(runAt.getTime()) && runAt < now;
  });

  if (expired.length === 0) return;

  const remaining = tasks.filter((t) => !expired.find((e) => e.id === t.id));
  saveTasks(remaining);
  logger.info(`🧹 만료된 1회성 태스크 ${expired.length}개 정리: ${expired.map((t) => t.label).join(", ")}`);
}
