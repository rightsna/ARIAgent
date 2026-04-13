import { logger } from "../../infra/logger.js";
import { Task } from "../../models/task.js";
import { scheduleSpecToCron } from "../../models/schedule_spec.js";
import { getTasks } from "../../repositories/task_repository.js";
import { NodeScheduleAdapter } from "./node_schedule_adapter.js";
import {
  LocalTaskSchedulerOptions,
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

function resolveOneOffDate(task: Task): Date | null {
  const parsed = new Date(task.startAt);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
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

    if (task.endAt && new Date(task.endAt) < new Date()) {
      return {
        taskId: task.id,
        status: "skipped_expired",
        reason: `Task endAt (${task.endAt}) is in the past.`,
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
          reason: "Could not parse startAt as a valid date.",
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

      const handle = await this.adapter.scheduleDate(task.id, runAt, onRun);
      this.jobs.set(task.id, handle);

      return {
        taskId: task.id,
        status: "scheduled",
        mode: "date",
        nextRunAt: runAt.toISOString(),
      };
    }

    if (!task.scheduleSpec) {
      return {
        taskId: task.id,
        status: "skipped_missing_date",
        mode: "cron",
        reason: "scheduleSpec is missing on recurring task.",
      };
    }

    const cronExpr = scheduleSpecToCron(task.scheduleSpec);
    const handle = await this.adapter.scheduleCron(task.id, cronExpr, onRun);
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
      // endAt 지난 반복 태스크 → 크론 취소
      if (!task.isOneOff && task.endAt && new Date(task.endAt) < new Date()) {
        logger.info(
          `[LocalTaskScheduler] Task expired (endAt: ${task.endAt}), cancelling cron: ${task.id}`,
        );
        this.cancelTask(task.id);
        return;
      }

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
          // 1회성: DB는 유지, 메모리 잡 핸들만 제거
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
