import fs from "fs";
import os from "os";
import path from "path";
import { spawn } from "child_process";
import { DATA_DIR, rmDirSyncSafe } from "../infra/data.js";
import { findAppExecutable } from "../infra/runtime_paths.js";
import { router } from "../system/router.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import { initAgent } from "../services/agent/index.js";

/**
 * /LAUNCH_APP
 * 특정 앱을 실행합니다.
 */
router.on("/LAUNCH_APP", async (ws, params) => {
  const { appId } = params as { appId: string };
  logger.info(`[Apps] Launching app: ${appId} from ${ws.uuid}`);

  if (!appId) {
    return ws.send("/LAUNCH_APP", { ok: false, error: "appId is required" });
  }

  try {
    if (UserSocketHandler.isAppConnected(appId)) {
      return ws.send("/LAUNCH_APP", {
        id: params.id,
        ok: true,
        data: { alreadyRunning: true, message: `'${appId}'가 이미 실행 중입니다.` },
      });
    }

    const executable = findAppExecutable(appId);

    if (!executable) {
      throw new Error(`실행 파일을 찾을 수 없습니다: ${appId}`);
    }

    const launchLogDir = path.join(DATA_DIR, "launch-logs");
    fs.mkdirSync(launchLogDir, { recursive: true });
    const launchLogPath = path.join(launchLogDir, `${appId}.log`);
    const stdoutFd = fs.openSync(launchLogPath, "a");
    const stderrFd = fs.openSync(launchLogPath, "a");

    const bundlePath =
      process.platform === "darwin"
        ? executable.split("/Contents/MacOS/")[0]
        : null;
    const launcherExecutable =
      process.platform === "darwin" ? "open" : executable;
    const defaultArgs: string[] = [];
    const launcherArgs =
      process.platform === "darwin" && bundlePath
        ? defaultArgs.length > 0
          ? ["-n", bundlePath, "--args", ...defaultArgs]
          : ["-n", bundlePath]
        : defaultArgs;

    const child = spawn(launcherExecutable, launcherArgs, {
      detached: process.platform === "darwin" ? false : true,
      stdio: ["ignore", stdoutFd, stderrFd],
      cwd: path.dirname(executable),
      env: {
        ...process.env,
        HOME: process.env.HOME ?? os.homedir(),
        USERPROFILE: process.env.USERPROFILE ?? os.homedir(),
      },
    });
    child.on("spawn", () => {
      logger.info(
        `[Apps] Spawned ${appId} (pid: ${child.pid ?? "unknown"}) log: ${launchLogPath}`,
      );
    });
    child.on("exit", (code: number | null, signal: NodeJS.Signals | null) => {
      logger.warn(
        `[Apps] ${appId} exited (code: ${code ?? "null"}, signal: ${signal ?? "null"})`,
      );
    });
    child.on("error", (error: any) => {
      logger.error(`[Apps] Failed to spawn ${appId}: ${error.message}`);
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
  if (!name) {
    return ws.send("/DELETE_SKILL", { ok: false, error: "Name is required" });
  }

  try {
    const skillDir = path.join(DATA_DIR, "skills", name);

    if (fs.existsSync(skillDir)) {
      rmDirSyncSafe(skillDir);
      await initAgent();
      logger.info(`[Skills] Skill ${name} deleted and agent re-initialized`);
      ws.send("/DELETE_SKILL", { ok: true, data: { success: true } });
    } else {
      logger.warn(`[Skills] Skill ${name} not found`);
      ws.send("/DELETE_SKILL", {
        ok: false,
        error: "Skill not found in user skills",
      });
    }
  } catch (e) {
    logger.error(`[Skills] Error deleting skill ${name}: ${e}`);
    ws.send("/DELETE_SKILL", { ok: false, error: String(e) });
  }
});
