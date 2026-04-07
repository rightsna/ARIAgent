import { router } from "../system/router.js";
import { clearAgentMemory, readCoreMemory, readRecentDailyLogs, updateCoreMemory } from "../services/memory.js";
import { clearAgentInstance } from "../services/agent/index.js";

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
