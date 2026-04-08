import { Task } from "../../models/task.js";

export interface ScheduledJobHandle {
  cancel(): boolean;
  nextInvocation?(): Date | null;
}

export interface SchedulerAdapter {
  readonly name: string;
  scheduleCron(
    task: Task,
    onRun: () => Promise<void> | void,
  ): Promise<ScheduledJobHandle>;
  scheduleDate(
    task: Task,
    runAt: Date,
    onRun: () => Promise<void> | void,
  ): Promise<ScheduledJobHandle>;
  shutdown?(): Promise<void>;
}

export interface LocalTaskSchedulerOptions {
  adapter?: SchedulerAdapter;
  executeTask?: (task: Task) => Promise<void>;
}

export interface ScheduleOperationResult {
  taskId: string;
  status:
    | "scheduled"
    | "skipped_disabled"
    | "skipped_missing_date"
    | "skipped_past_due"
    | "cancelled"
    | "not_found";
  mode?: "cron" | "date";
  nextRunAt?: string;
  reason?: string;
}

export interface RestoreResult {
  restored: ScheduleOperationResult[];
  failed: Array<{ taskId: string; message: string }>;
}

export type PersistedOneOffTask = Task & {
  scheduledFor?: string;
};
