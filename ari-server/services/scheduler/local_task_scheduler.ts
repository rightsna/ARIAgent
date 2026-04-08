import { logger } from "../../infra/logger.js";
import { Task } from "../../models/task.js";
import { getTasks } from "../../repositories/task_repository.js";
import { NodeScheduleAdapter } from "./node_schedule_adapter.js";
import {
  LocalTaskSchedulerOptions,
  PersistedOneOffTask,
  RestoreResult,
  ScheduleOperationResult,
  ScheduledJobHandle,
  SchedulerAdapter,
} from "./types.js";

function defaultTaskExecutor(task: Task): Promise<void> {
  logger.info(
    `[LocalTaskScheduler] Placeholder execution only: ${task.id} (${task.label})`,
  );
  return Promise.resolve();
}

function resolveOneOffDate(
  task: PersistedOneOffTask,
  now: Date = new Date(),
): Date | null {
  const scheduledFor = task.scheduledFor?.trim();
  if (scheduledFor) {
    const parsed = new Date(scheduledFor);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const parts = task.cron.split(" ");
  if (parts.length < 5) {
    return null;
  }

  const minute = Number(parts[0]);
  const hour = Number(parts[1]);
  const day = Number(parts[2]);
  const month = Number(parts[3]);

  if (
    [minute, hour, day, month].some((value) => Number.isNaN(value))
  ) {
    return null;
  }

  const currentYear = now.getFullYear();
  let candidate = new Date(currentYear, month - 1, day, hour, minute, 0, 0);
  if (candidate.getTime() < now.getTime()) {
    candidate = new Date(currentYear + 1, month - 1, day, hour, minute, 0, 0);
  }

  return Number.isNaN(candidate.getTime()) ? null : candidate;
}

export class LocalTaskScheduler {
  private readonly adapter: SchedulerAdapter;
  private readonly executeTask: (task: Task) => Promise<void>;
  private readonly jobs = new Map<string, ScheduledJobHandle>();
  private readonly runningTaskIds = new Set<string>();

  constructor(options: LocalTaskSchedulerOptions = {}) {
    this.adapter = options.adapter ?? new NodeScheduleAdapter();
    this.executeTask = options.executeTask ?? defaultTaskExecutor;
  }

  async restoreFromDisk(): Promise<RestoreResult> {
    const tasks = getTasks();
    const restored: ScheduleOperationResult[] = [];
    const failed: Array<{ taskId: string; message: string }> = [];
    const persistedTaskIds = new Set(tasks.map((task) => task.id));

    for (const taskId of Array.from(this.jobs.keys())) {
      if (!persistedTaskIds.has(taskId)) {
        this.cancelTask(taskId);
      }
    }

    for (const task of tasks) {
      try {
        restored.push(await this.scheduleTask(task));
      } catch (error) {
        failed.push({
          taskId: task.id,
          message: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return { restored, failed };
  }

  async scheduleTask(task: Task): Promise<ScheduleOperationResult> {
    this.cancelTask(task.id);

    if (task.enabled === false) {
      return {
        taskId: task.id,
        status: "skipped_disabled",
        reason: "Task is disabled.",
      };
    }

    const onRun = this.createRunHandler(task);

    if (task.isOneOff) {
      const runAt = resolveOneOffDate(task);
      if (!runAt) {
        return {
          taskId: task.id,
          status: "skipped_missing_date",
          mode: "date",
          reason: "Could not resolve a one-off execution date.",
        };
      }

      if (runAt.getTime() <= Date.now()) {
        return {
          taskId: task.id,
          status: "skipped_past_due",
          mode: "date",
          nextRunAt: runAt.toISOString(),
          reason: "One-off task is already in the past.",
        };
      }

      const handle = await this.adapter.scheduleDate(task, runAt, onRun);
      this.jobs.set(task.id, handle);

      return {
        taskId: task.id,
        status: "scheduled",
        mode: "date",
        nextRunAt: runAt.toISOString(),
      };
    }

    const handle = await this.adapter.scheduleCron(task, onRun);
    this.jobs.set(task.id, handle);

    return {
      taskId: task.id,
      status: "scheduled",
      mode: "cron",
      nextRunAt: handle.nextInvocation?.()?.toISOString(),
    };
  }

  async resyncTask(taskId: string): Promise<ScheduleOperationResult> {
    const task = getTasks().find((candidate) => candidate.id === taskId);
    if (!task) {
      this.cancelTask(taskId);
      return {
        taskId,
        status: "not_found",
        reason: "Task was not found in tasks.json.",
      };
    }

    return this.scheduleTask(task);
  }

  cancelTask(taskId: string): ScheduleOperationResult {
    const handle = this.jobs.get(taskId);
    if (!handle) {
      return {
        taskId,
        status: "not_found",
        reason: "No in-memory job is registered for this task.",
      };
    }

    handle.cancel();
    this.jobs.delete(taskId);

    return {
      taskId,
      status: "cancelled",
    };
  }

  getSnapshot(): Array<{
    taskId: string;
    nextRunAt?: string;
  }> {
    return Array.from(this.jobs.entries()).map(([taskId, handle]) => ({
      taskId,
      nextRunAt: handle.nextInvocation?.()?.toISOString(),
    }));
  }

  async shutdown(): Promise<void> {
    for (const taskId of Array.from(this.jobs.keys())) {
      this.cancelTask(taskId);
    }

    await this.adapter.shutdown?.();
  }

  private createRunHandler(task: Task): () => Promise<void> {
    return async () => {
      if (this.runningTaskIds.has(task.id)) {
        logger.warn(
          `[LocalTaskScheduler] Task already running, skipping duplicate trigger: ${task.id}`,
        );
        return;
      }

      this.runningTaskIds.add(task.id);
      logger.info(
        `[LocalTaskScheduler] Triggered task: ${task.id} (${task.label}) via ${this.adapter.name}`,
      );

      try {
        await this.executeTask(task);

        if (task.isOneOff) {
          this.jobs.delete(task.id);
        }
      } catch (error) {
        logger.error(
          `[LocalTaskScheduler] Task execution failed: ${task.id}`,
          error,
        );
      } finally {
        this.runningTaskIds.delete(task.id);
      }
    };
  }
}
