import path from "path";
import { DATA_DIR, readJsonSync, writeJsonSync } from "../infra/data.js";
import { Task } from "../models/task.js";

const TASKS_FILE = path.join(DATA_DIR, "tasks.json");

export function initTasksFileIfMissing(): void {
  const data = readJsonSync(TASKS_FILE);
  if (data === null) {
    saveTasks([]);
  }
}

export function getTasks(): Task[] {
  const rawData = readJsonSync<any[]>(TASKS_FILE, []);
  if (!rawData || !Array.isArray(rawData)) return [];
  return rawData.map((task) => Task.fromJson(task));
}

export function saveTasks(tasks: Task[]): void {
  writeJsonSync(TASKS_FILE, tasks);
}
