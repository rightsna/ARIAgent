import fs from "fs";
import path from "path";
import os from "os";
import { router } from "../system/router.js";
import { getAgentsConfig, saveAgents } from "../repositories/agent_repository.js";
import { AgentsConfig } from "../models/agent.js";

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

router.on("/AGENTS.IMAGE.SAVE", async (ws, params) => {
  const id = params.id as string;
  const sourcePath = params.sourcePath as string;

  if (!id || !sourcePath) {
    return ws.send("/AGENTS.IMAGE.SAVE", { ok: false, message: "id and sourcePath required" });
  }

  try {
    const imagesDir = path.join(os.homedir(), ".ari-agent", "images");
    if (!fs.existsSync(imagesDir)) {
      fs.mkdirSync(imagesDir, { recursive: true });
    }

    const ext = path.extname(sourcePath);
    const destPath = path.join(imagesDir, `${id}${ext}`);

    if (path.resolve(sourcePath) === path.resolve(destPath)) {
      return ws.send("/AGENTS.IMAGE.SAVE", { ok: true, data: { imagePath: sourcePath } });
    }

    fs.copyFileSync(sourcePath, destPath);
    ws.send("/AGENTS.IMAGE.SAVE", { ok: true, data: { imagePath: destPath } });
  } catch (e: any) {
    ws.send("/AGENTS.IMAGE.SAVE", { ok: false, message: e.message });
  }
});
