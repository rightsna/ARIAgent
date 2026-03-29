import { router } from "../system/router";
import { saveSettings } from "../repositories/setting_repository";
import { initAgent, getPluginsInfo } from "../services/agent";
import { getCurrentState } from "../services/agent";
import { logger } from "../infra/logger";
import { UserSocketHandler } from "../system/ws";

/**
 * /GET_CONNECTED_APPS
 * 현재 서버에 활성 상태로 연결된 앱 ID 목록을 반환합니다.
 */
router.on("/GET_CONNECTED_APPS", async (ws, params) => {
  const connectedIds = UserSocketHandler.getConnectedAppIds();
  ws.send("/GET_CONNECTED_APPS", {
    id: params.id,
    ok: true,
    data: { connectedIds },
  });
});

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


/**
 * /LAUNCH_APP
 * 특정 앱을 실행합니다.
 */
router.on("/LAUNCH_APP", async (ws, params) => {
  const { appId } = params as { appId: string };
  const { UserSocketHandler } = require("../system/ws");
  logger.info(`[Apps] Launching app: ${appId} from ${ws.uuid}`);

  if (!appId) {
    return ws.send("/LAUNCH_APP", { ok: false, error: "appId is required" });
  }

  try {
    // 1. 이미 연결되어 있는지 확인
    if (UserSocketHandler.isAppConnected(appId)) {
      return ws.send("/LAUNCH_APP", { 
        id: params.id,
        ok: true, 
        data: { alreadyRunning: true, message: `'${appId}'가 이미 실행 중입니다.` } 
      });
    }

    // 2. 실행 권한 및 경로 확인 후 spawn
    const { spawn } = require("child_process");
    const { getBundleRoots } = require("../infra/runtime_paths");
    const fs = require("fs");
    const path = require("path");
    const os = require("os");

    const bundleRoots = getBundleRoots();
    let executable = "";

    if (process.platform === "darwin") {
      for (const root of bundleRoots) {
        const appIdNoUnderscore = appId.replace(/_/g, "");
        const paths = [
          path.join(root, appId, "app.app", "Contents", "MacOS", appId),
          path.join(root, appId, "app.app", "Contents", "MacOS", appIdNoUnderscore),
          path.join(root, appId, "app.app", "Contents", "MacOS", "app"),
          path.join(root, appId, "Contents", "MacOS", "app"),
          path.join(root, appId, "Contents", "MacOS", appId),
          path.join(root, appId, "Contents", "MacOS", appIdNoUnderscore),
          path.join(root, appId, `${appId}.app`, "Contents", "MacOS", appId),
          path.join(root, appId, `${appIdNoUnderscore}.app`, "Contents", "MacOS", appIdNoUnderscore),
        ];
        for (const p of paths) {
          if (fs.existsSync(p)) {
            executable = p;
            break;
          }
        }
        if (executable) break;
      }
    } else if (process.platform === "win32") {
      for (const root of bundleRoots) {
        const appIdNoUnderscore = appId.replace(/_/g, "");
        const paths = [
          path.join(root, appId, "app.exe"),
          path.join(root, appId, `${appId}.exe`),
          path.join(root, appId, `${appIdNoUnderscore}.exe`),
          path.join(root, `${appId}.exe`),
          path.join(root, `${appIdNoUnderscore}.exe`),
        ];
        for (const p of paths) {
          if (fs.existsSync(p)) {
            executable = p;
            break;
          }
        }
        if (executable) break;
      }
    }

    if (!executable) {
      throw new Error(`실행 파일을 찾을 수 없습니다: ${appId}`);
    }

    const child = spawn(executable, [], {
      detached: true,
      stdio: "ignore",
      env: {
        ...process.env,
        HOME: process.env.HOME ?? os.homedir(),
        USERPROFILE: process.env.USERPROFILE ?? os.homedir(),
      },
    });
    child.unref();

    ws.send("/LAUNCH_APP", {
      id: params.id,
      ok: true,
      data: { success: true, message: `'${appId}' 앱을 실행했습니다.` },
    });
  } catch (error: any) {
    logger.error(`[Apps] Failed to launch ${appId}: ${error.message}`);
    ws.send("/LAUNCH_APP", {
      id: params.id,
      ok: false,
      error: error.message,
    });
  }
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
