import { router } from "../system/router";
import { saveSettings } from "../repositories/setting_repository";
import { initAgent, getPluginsInfo } from "../services/agent";
import { getCurrentState } from "../services/agent";
import { logger } from "../infra/logger";

router.on("/HEALTH", async (ws, params) => {
  logger.info(`[Health] Check from ${ws.uuid}`);
  const state = getCurrentState();
  const plugins = await getPluginsInfo();
  ws.send("/HEALTH", {
    ok: true,
    data: {
      status: "ok",
      hasApiKey: state.providers ? state.providers.length > 0 : !!state.currentApiKey,
      providers: (state.providers || []).map((p: any) => ({
        provider: p.provider,
        model: p.model,
        hasApiKey: !!p.apiKey,
      })),
      model: state.currentModel,
      provider: state.currentProvider,
      engine: "pi-agent-core",
      tools: plugins.tools.map((t) => t.name),
      skills: plugins.skills.map((s) => s.name),
    },
  });
});

router.on("/SETTINGS", async (ws, params) => {
  logger.info(`[Settings] Update requested by ${ws.uuid}`);
  const state = getCurrentState();
  if (params.providers) {
    logger.info(`[Settings] Updating providers: ${params.providers.length} items`);
    const incoming = (params.providers as any[]).filter((p) => !!p.provider && !!p.model);
    const existing = state.providers || [];

    state.providers = incoming.map((inc) => {
      if (!inc.apiKey || inc.apiKey.includes("••")) {
        const matched = existing.find((ex: any) => ex.provider === inc.provider);
        inc.apiKey = matched?.apiKey || "";
      }
      return inc;
    });

    saveSettings({ PROVIDERS: state.providers as any });
    await initAgent(state.providers);
    return ws.send("/SETTINGS", { ok: true, data: { success: true, providers: state.providers } });
  }

  if (params.apiKey) {
    logger.info(`[Settings] Updating API Key`);
    state.currentApiKey = params.apiKey;
  }
  if (params.model) {
    logger.info(`[Settings] Changing model to: ${params.model}`);
    state.currentModel = params.model;
  }
  if (params.provider) {
    logger.info(`[Settings] Changing provider to: ${params.provider}`);
    state.currentProvider = params.provider;
  }

  if (params.port) {
    logger.info(`[Settings] Changing port to: ${params.port}`);
    saveSettings({ PORT: Number(params.port) });
  }

  if (params.apiKey || params.model || params.provider) {
    saveSettings({
      OPENAI_API_KEY: state.currentApiKey,
      OPENAI_MODEL: state.currentModel,
      PROVIDER: state.currentProvider,
    });
    await initAgent();
  }

  ws.send("/SETTINGS", { ok: true, data: { success: true, model: state.currentModel, provider: state.currentProvider } });
});

router.on("/PLUGINS", async (ws, params) => {
  logger.info(`[Plugins] Requesting list from ${ws.uuid}`);
  const plugins = await getPluginsInfo();
  ws.send("/PLUGINS", {
    ok: true,
    data: {
      tools: plugins.tools.map((t) => ({ name: t.name, description: t.description })),
      skills: plugins.skills,
    },
  });
});

router.on("/DELETE_SKILL", async (ws, params) => {
  const { name } = params;
  logger.info(`[Skills] Deleting skill: ${name}`);
  if (!name) return ws.send("/DELETE_SKILL", { ok: false, error: "Name is required" });

  try {
    const { DATA_DIR, rmDirSyncSafe } = require("../infra/data");
    const path = require("path");
    const skillDir = path.join(DATA_DIR, "skills", name);

    // Verify it exists first
    const fs = require("fs");
    if (fs.existsSync(skillDir)) {
      rmDirSyncSafe(skillDir);
      await initAgent(); // Refresh plugins
      logger.info(`[Skills] Skill ${name} deleted and agent re-initialized`);
      ws.send("/DELETE_SKILL", { ok: true, data: { success: true } });
    } else {
      logger.warn(`[Skills] Skill ${name} not found`);
      ws.send("/DELETE_SKILL", { ok: false, error: "Skill not found in user skills" });
    }
  } catch (e) {
    logger.error(`[Skills] Error deleting skill ${name}: ${e}`);
    ws.send("/DELETE_SKILL", { ok: false, error: String(e) });
  }
});
