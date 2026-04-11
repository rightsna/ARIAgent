import path from "path";
import fs from "fs";
import { DATA_DIR, appendTextSync } from "../infra/data.js";

// 채팅 로그와 별도 디렉토리에 저장 → 대화 초기화와 무관하게 유지
const USAGE_DIR = path.join(DATA_DIR, "usage_logs");

export interface TokenUsage {
  input: number;
  output: number;
  totalTokens: number;
}

export interface UsageSummary {
  total: TokenUsage;
  byModel: Record<string, TokenUsage>;
  byDay: { date: string; input: number; output: number; totalTokens: number }[];
}

function emptyUsage(): TokenUsage {
  return { input: 0, output: 0, totalTokens: 0 };
}

function addUsage(a: TokenUsage, b: TokenUsage): TokenUsage {
  return {
    input: a.input + (b.input ?? 0),
    output: a.output + (b.output ?? 0),
    totalTokens: a.totalTokens + (b.totalTokens ?? 0),
  };
}

/**
 * 토큰 사용량을 별도 로그 파일에 기록합니다.
 * 채팅 로그와 독립적으로 관리되어 대화 초기화와 무관합니다.
 */
export function appendUsageLog(
  agentId: string,
  entry: {
    requestId: string;
    provider: string;
    model: string;
    usage: any;
    source?: string;
  },
): void {
  if (!fs.existsSync(USAGE_DIR)) {
    fs.mkdirSync(USAGE_DIR, { recursive: true });
  }
  const filePath = path.join(USAGE_DIR, `${agentId}.jsonl`);
  const line = JSON.stringify({
    ...entry,
    agentId,
    timestamp: new Date().toISOString(),
  }) + "\n";
  appendTextSync(filePath, line);
}

/**
 * 특정 에이전트의 토큰 사용량을 집계합니다.
 */
export function readUsageSummary(
  agentId: string,
  startDate?: string, // "YYYY-MM-DD"
  endDate?: string,   // "YYYY-MM-DD"
): UsageSummary {
  const filePath = path.join(USAGE_DIR, `${agentId}.jsonl`);
  const summary: UsageSummary = {
    total: emptyUsage(),
    byModel: {},
    byDay: [],
  };

  if (!fs.existsSync(filePath)) {
    return summary;
  }

  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.trim().split("\n").filter((l) => l.trim() !== "");

  const dayMap = new Map<string, TokenUsage>();

  for (const line of lines) {
    let entry: any;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }

    if (!entry.usage || (entry.usage.totalTokens ?? 0) === 0) continue;

    const timestamp: string = entry.timestamp || "";
    const date = timestamp.slice(0, 10); // "YYYY-MM-DD"

    if (startDate && date < startDate) continue;
    if (endDate && date > endDate) continue;

    const usage: TokenUsage = {
      input: entry.usage.input ?? 0,
      output: entry.usage.output ?? 0,
      totalTokens: entry.usage.totalTokens ?? 0,
    };

    summary.total = addUsage(summary.total, usage);

    const model: string = entry.model || "unknown";
    summary.byModel[model] = addUsage(summary.byModel[model] ?? emptyUsage(), usage);

    const existing = dayMap.get(date) ?? emptyUsage();
    dayMap.set(date, addUsage(existing, usage));
  }

  summary.byDay = Array.from(dayMap.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, u]) => ({ date, ...u }));

  return summary;
}
