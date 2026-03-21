import path from "path";
import fs from "fs";
import { DATA_DIR, ensureDirSync, readJsonSync, writeJsonSync, readDirSyncSafe } from "../infra/data";
import { TaskResult } from "../models/task_result";

const TASK_RESULTS_DIR = path.join(DATA_DIR, "task_results");
const OLD_RESULTS_DIR = path.join(DATA_DIR, "results");

// Backward compatibility: Rename old results directory to task_results if it exists
if (fs.existsSync(OLD_RESULTS_DIR) && !fs.existsSync(TASK_RESULTS_DIR)) {
  fs.renameSync(OLD_RESULTS_DIR, TASK_RESULTS_DIR);
}

export function ensureTaskResultDirSync(): void {
  ensureDirSync(TASK_RESULTS_DIR);
}

export function getTaskResultFiles(): string[] {
  return readDirSyncSafe(TASK_RESULTS_DIR);
}

export function getTaskResultByFile(filename: string): TaskResult | null {
  const rawData = readJsonSync<any>(path.join(TASK_RESULTS_DIR, filename), null);
  if (!rawData) return null;
  return TaskResult.fromJson(rawData);
}

export function saveTaskResult(taskId: string, resultData: TaskResult | any): void {
  ensureTaskResultDirSync();
  writeJsonSync(path.join(TASK_RESULTS_DIR, `${taskId}.json`), resultData);
}
