import path from "path";
import fs from "fs";
import { DATA_DIR, ensureDirSync } from "../infra/data.js";
import { logger } from "../infra/logger.js";

const MODEL_CACHE_DIR = path.join(DATA_DIR, "models");
const MODEL_NAME = "Xenova/multilingual-e5-small";
export const EMBEDDING_DIM = 384;

// multilingual-e5 계열은 저장(passage)과 검색(query) 시 다른 프리픽스가 필요합니다.
const PASSAGE_PREFIX = "passage: ";
const QUERY_PREFIX = "query: ";

export type EmbeddingStatus = "idle" | "loading" | "downloading" | "ready" | "error";

type EmbeddingState = {
  status: EmbeddingStatus;
  error?: string;
};

let state: EmbeddingState = { status: "idle" };
let extractorInstance: any = null;

export function getEmbeddingStatus(): EmbeddingState {
  return { ...state };
}

function isModelCached(): boolean {
  try {
    const modelDir = path.join(MODEL_CACHE_DIR, ...MODEL_NAME.split("/"));
    if (!fs.existsSync(modelDir)) return false;
    const files = fs.readdirSync(modelDir);
    return files.some((f) => f.endsWith(".onnx") || f.endsWith(".json"));
  } catch {
    return false;
  }
}

export async function initEmbeddingModel(): Promise<void> {
  if (state.status === "ready" || state.status === "downloading" || state.status === "loading") return;

  const cached = isModelCached();
  state = { status: cached ? "loading" : "downloading" };
  logger.info(cached
    ? `[Embedding] 모델 캐시 로드 중: ${MODEL_NAME}`
    : `[Embedding] 모델 다운로드 시작: ${MODEL_NAME} (~280MB)`
  );

  try {
    ensureDirSync(MODEL_CACHE_DIR);

    const { pipeline, env } = await import("@xenova/transformers");
    (env as any).cacheDir = MODEL_CACHE_DIR;
    (env as any).allowLocalModels = true;
    (env as any).allowRemoteModels = true;

    extractorInstance = await pipeline("feature-extraction", MODEL_NAME, {
      progress_callback: (progress: any) => {
        if (progress?.status === "downloading") {
          const pct = progress.progress != null ? Math.round(progress.progress) : "?";
          logger.info(`[Embedding] 다운로드 중... ${pct}%`);
        }
      },
    });

    state = { status: "ready" };
    logger.info(`[Embedding] 모델 준비 완료: ${MODEL_NAME}`);
  } catch (e: any) {
    state = { status: "error", error: e.message };
    logger.error(`[Embedding] 모델 로드 실패:`, e);
    throw e;
  }
}

/**
 * 메모리 저장 시 사용 — "passage: " 프리픽스 적용
 */
export async function embedPassage(text: string): Promise<number[]> {
  return embedRaw(PASSAGE_PREFIX + text);
}

/**
 * 메모리 검색 시 사용 — "query: " 프리픽스 적용
 */
export async function embedQuery(text: string): Promise<number[]> {
  return embedRaw(QUERY_PREFIX + text);
}

async function embedRaw(text: string): Promise<number[]> {
  if (state.status !== "ready" || !extractorInstance) {
    throw new Error(`Embedding model not ready (status: ${state.status})`);
  }
  const output = await extractorInstance(text, { pooling: "mean", normalize: true });
  return Array.from(output.data) as number[];
}
