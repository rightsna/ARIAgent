import { router } from "../system/router.js";
import { clearAgentMemory, readCoreMemory, readRecentDailyLogs, updateCoreMemory } from "../services/memory.js";
import { clearAgentInstance } from "../services/agent/index.js";
import { getEmbeddingStatus, initEmbeddingModel } from "../services/embedding.js";
import { getMemoryStats } from "../repositories/kuzu_memory_repository.js";
import { getSettings } from "../repositories/setting_repository.js";
import { Settings } from "../models/settings.js";

router.on("/MEMORY.GET", async (ws, params) => {
  const agentId = (params.agentId as string) || "default";
  const core = readCoreMemory(agentId);
  const daily = readRecentDailyLogs(agentId);
  ws.send("/MEMORY.GET", { ok: true, data: { core, daily } });
});

router.on("/MEMORY.UPDATE", async (ws, params) => {
  const agentId = (params.agentId as string) || "default";
  const content = params.content as string;
  updateCoreMemory(content, agentId);
  ws.send("/MEMORY.UPDATE", { ok: true, data: { success: true } });
});

router.on("/MEMORY.CLEAR", async (ws, params) => {
  const agentId = (params.agentId as string) || "default";
  clearAgentMemory(agentId);
  clearAgentInstance(agentId);
  ws.send("/MEMORY.CLEAR", { ok: true, data: { success: true } });
});

router.on("/MEMORY.MODEL_STATUS", async (ws, _params) => {
  const embStatus = getEmbeddingStatus();
  ws.send("/MEMORY.MODEL_STATUS", {
    ok: true,
    data: {
      status: embStatus.status,
      error: embStatus.error ?? null,
    },
  });
});

router.on("/MEMORY.STATS", async (ws, params) => {
  const agentId = (params.agentId as string) || "default";
  const settings = getSettings(new Settings());
  if (!settings.USE_ADVANCED_MEMORY) {
    return ws.send("/MEMORY.STATS", { ok: true, data: { enabled: false } });
  }
  try {
    const stats = await getMemoryStats(agentId);
    ws.send("/MEMORY.STATS", { ok: true, data: { enabled: true, ...stats } });
  } catch (e: any) {
    ws.send("/MEMORY.STATS", { ok: false, data: { error: e.message } });
  }
});

router.on("/MEMORY.MODEL_DOWNLOAD", async (ws, _params) => {
  const current = getEmbeddingStatus();
  if (current.status === "downloading") {
    return ws.send("/MEMORY.MODEL_DOWNLOAD", {
      ok: true,
      data: { message: "이미 다운로드 중입니다." },
    });
  }
  if (current.status === "ready") {
    return ws.send("/MEMORY.MODEL_DOWNLOAD", {
      ok: true,
      data: { message: "모델이 이미 준비되어 있습니다." },
    });
  }
  initEmbeddingModel().catch(() => {});
  ws.send("/MEMORY.MODEL_DOWNLOAD", {
    ok: true,
    data: { message: "모델 다운로드를 시작했습니다." },
  });
});
