import { router } from "../system/router";
import { getAgentsConfig, saveAgents } from "../repositories/agent_repository";
import { AgentsConfig } from "../models/agent";

router.on("/AGENTS", async (ws, params) => {
  const config = getAgentsConfig(new AgentsConfig());
  ws.send("/AGENTS", { ok: true, data: config });
});

router.on("/AGENTS.SAVE", async (ws, params) => {
  const payload = params.agents as any;
  if (!payload) return ws.send("/AGENTS.SAVE", { ok: false, message: "agents data required" });

  const config = getAgentsConfig(new AgentsConfig());
  const newConfig = Array.isArray(payload) ? { selected: config.selected, agents: payload } : payload;

  saveAgents(newConfig);
  ws.send("/AGENTS.SAVE", { ok: true, data: { success: true } });
});

router.on("/AGENTS.SET_SELECTED", async (ws, params) => {
  const id = params.id as string;
  if (!id) return ws.send("/AGENTS.SET_SELECTED", { ok: false, message: "id required" });

  const config = getAgentsConfig(new AgentsConfig());
  config.selected = id;
  saveAgents(config);
  ws.send("/AGENTS.SET_SELECTED", { ok: true, data: { success: true } });
});
