import { router } from "../system/router.js";
import { saveSettings } from "../repositories/setting_repository.js";
import { initAgent, getPluginsInfo } from "../services/agent/index.js";
import { getCurrentState } from "../services/agent/index.js";
import { logger } from "../infra/logger.js";

router.on("/SETTINGS", async (ws, params) => {
  logger.info(`[Settings] Update requested by ${ws.uuid}`);
  const state = getCurrentState();
  if (params.providers) {
    logger.info(`[Settings] Updating providers: ${params.providers.length} items`);
    const incoming = (params.providers as any[]).filter((p) => !!p.provider && !!p.model);
    const existing = state.providers || [];

    const nextProviders = incoming.map((inc) => {
      if (!inc.apiKey || inc.apiKey.includes("••")) {
        const matched = existing.find((ex: any) => ex.provider === inc.provider);
        inc.apiKey = matched?.apiKey || "";
      }
      return inc;
    });

    state.setProviders(nextProviders);
    saveSettings({ PROVIDERS: state.providers as any });
    await initAgent(state);
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

router.on("/PLUGINS.SKILLS", async (ws, _params) => {
  logger.info(`[Plugins] Skills requested from ${ws.uuid}`);
  const { skills } = await getPluginsInfo();
  ws.send("/PLUGINS.SKILLS", { ok: true, data: { skills } });
});

router.on("/PLUGINS.APPS", async (ws, _params) => {
  logger.info(`[Plugins] Apps requested from ${ws.uuid}`);
  const { apps } = await getPluginsInfo();
  ws.send("/PLUGINS.APPS", { ok: true, data: { apps } });
});

router.on("/PLUGINS.TOOLS", async (ws, _params) => {
  logger.info(`[Plugins] Tools requested from ${ws.uuid}`);
  const { tools } = await getPluginsInfo();
  ws.send("/PLUGINS.TOOLS", {
    ok: true,
    data: { tools: tools.map((t) => ({ name: t.name, description: t.description })) },
  });
});
