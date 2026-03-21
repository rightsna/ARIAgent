export class TaskResult {
  taskId: string;
  prompt: string;
  label: string;
  result: string;
  executedAt: string;

  constructor(data: any = {}) {
    this.taskId = data?.taskId || "";
    this.prompt = data?.prompt || "";
    this.label = data?.label || "";
    this.result = data?.result || "";
    this.executedAt = data?.executedAt || new Date().toISOString();
  }

  static fromJson(jsonStr: string | any): TaskResult {
    try {
      const data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
      return new TaskResult(data || {});
    } catch {
      return new TaskResult();
    }
  }
}
