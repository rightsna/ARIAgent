import { Task } from "../../models/task.js";
import { logger } from "../../infra/logger.js";
import { LocalTaskScheduler } from "./local_task_scheduler.js";
import { LocalTaskSchedulerOptions, RestoreResult } from "./types.js";

let scheduler: LocalTaskScheduler | null = null;

export function initializeTaskScheduler(
  options: LocalTaskSchedulerOptions = {},
): LocalTaskScheduler {
  if (scheduler) {
    return scheduler;
  }

  scheduler = new LocalTaskScheduler(options);
  logger.info("[LocalTaskScheduler] Initialized.");
  return scheduler;
}

export function getTaskScheduler(): LocalTaskScheduler | null {
  return scheduler;
}

export async function restoreTaskScheduler(): Promise<RestoreResult | null> {
  if (!scheduler) {
    return null;
  }

  return scheduler.restoreFromDisk();
}

export async function syncTaskScheduler(task: Task): Promise<void> {
  if (!scheduler) {
    return;
  }

  await scheduler.scheduleTask(task);
}

export function cancelTaskScheduler(taskId: string): void {
  scheduler?.cancelTask(taskId);
}

export async function shutdownTaskScheduler(): Promise<void> {
  if (!scheduler) {
    return;
  }

  await scheduler.shutdown();
  scheduler = null;
}
