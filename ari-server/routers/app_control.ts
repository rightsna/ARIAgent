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
import { execPromise } from "../tools/bash.js";

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

/**
 * /APP.UPDATE
 * 호스트 앱(ARIAgent 등)을 직접 다운로드·교체·재실행합니다.
 * AI 없이 Flutter 클라이언트가 직접 호출합니다.
 *
 * params:
 *   url              - 새 버전 .zip 다운로드 주소
 *   appName          - 앱 이름 (로그용)
 *   appExecutablePath - 현재 실행 중인 앱의 실행 파일 경로 (Platform.resolvedExecutable)
 */
router.on("/APP.UPDATE", async (ws, params) => {
  const { url, appName = "app", appExecutablePath } = params as {
    url: string;
    appName: string;
    appExecutablePath: string;
  };

  logger.info(`[AppUpdate] Received update request for '${appName}' from ${url}`);

  if (!url || !appExecutablePath) {
    return ws.send("/APP.UPDATE", { ok: false, error: "url and appExecutablePath are required" });
  }

  const tempDir = path.join(os.tmpdir(), `ari-host-update-${Date.now()}`);

  try {
    // 1. 임시 디렉토리 준비
    fs.mkdirSync(tempDir, { recursive: true });
    const zipPath = path.join(tempDir, "update.zip");
    const extractDir = path.join(tempDir, "extracted");
    fs.mkdirSync(extractDir, { recursive: true });

    // 2. 다운로드
    ws.send("/APP.UPDATE.PROGRESS", { stage: "downloading", message: "새 버전 다운로드 중..." });
    logger.info(`[AppUpdate] Downloading to ${zipPath}`);
    await execPromise(`curl -L "${url}" -o "${zipPath}"`);

    // 3. 압축 해제
    ws.send("/APP.UPDATE.PROGRESS", { stage: "extracting", message: "압축 해제 중..." });
    logger.info(`[AppUpdate] Extracting to ${extractDir}`);
    if (process.platform === "win32") {
      await execPromise(`powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${extractDir}' -Force"`);
    } else {
      await execPromise(`unzip -o "${zipPath}" -d "${extractDir}"`);
    }

    // 4. 압축 해제 결과에서 앱 번들 찾기
    const findAppBundle = (dir: string): string | null => {
      const items = fs.readdirSync(dir).filter(f => !f.startsWith(".") && f !== "__MACOSX");
      for (const item of items) {
        const itemPath = path.join(dir, item);
        const stat = fs.statSync(itemPath);
        if (process.platform === "darwin" && item.endsWith(".app") && stat.isDirectory()) {
          return itemPath;
        }
        if (process.platform === "win32" && item.endsWith(".exe") && stat.isFile()) {
          return itemPath;
        }
        if (stat.isDirectory()) {
          const found = findAppBundle(itemPath);
          if (found) return found;
        }
      }
      return null;
    };

    const newAppBundle = findAppBundle(extractDir);
    if (!newAppBundle) {
      throw new Error("압축 파일에서 앱 번들(.app / .exe)을 찾을 수 없습니다.");
    }
    logger.info(`[AppUpdate] Found new bundle: ${newAppBundle}`);

    // 5. 현재 앱 번들 경로 계산
    let currentAppBundle: string;
    if (process.platform === "darwin") {
      // e.g. /Applications/ARIAgent.app/Contents/MacOS/ARIAgent → /Applications/ARIAgent.app
      const parts = appExecutablePath.split("/Contents/MacOS/");
      if (parts.length < 2) throw new Error(`올바르지 않은 실행 파일 경로: ${appExecutablePath}`);
      currentAppBundle = parts[0];
    } else {
      currentAppBundle = path.dirname(appExecutablePath);
    }
    logger.info(`[AppUpdate] Current bundle: ${currentAppBundle}`);

    // 6. 교체 스크립트 생성 후 detached 실행 (서버·앱이 종료돼도 안전)
    ws.send("/APP.UPDATE.PROGRESS", { stage: "installing", message: "업데이트 설치 중..." });

    if (process.platform === "darwin") {
      const scriptPath = path.join(tempDir, "apply_update.sh");
      const script = [
        "#!/bin/bash",
        "sleep 2",
        `rm -rf "${currentAppBundle}"`,
        `mv "${newAppBundle}" "${currentAppBundle}"`,
        `open "${currentAppBundle}"`,
        `rm -rf "${tempDir}"`,
      ].join("\n");
      fs.writeFileSync(scriptPath, script, { mode: 0o755 });
      const child = spawn("bash", [scriptPath], { detached: true, stdio: "ignore" });
      child.unref();

    } else if (process.platform === "win32") {
      const scriptPath = path.join(tempDir, "apply_update.bat");
      const newExe = newAppBundle; // .exe path
      const script = [
        "@echo off",
        "timeout /t 2 /nobreak >nul",
        `del /f /q "${currentAppBundle}"`,
        `move "${newExe}" "${currentAppBundle}"`,
        `start "" "${currentAppBundle}"`,
      ].join("\r\n");
      fs.writeFileSync(scriptPath, script);
      const child = spawn("cmd", ["/c", scriptPath], { detached: true, stdio: "ignore", windowsHide: true });
      child.unref();
    }

    // 7. 클라이언트에 완료 알림 → 클라이언트가 exit(0) 호출
    ws.send("/APP.UPDATE", { ok: true, data: { message: "업데이트 준비 완료. 앱을 재시작합니다." } });
    logger.info(`[AppUpdate] Update script launched. Waiting for client to close.`);

  } catch (error: any) {
    logger.error(`[AppUpdate] Failed: ${error.message}`);
    if (fs.existsSync(tempDir)) fs.rmSync(tempDir, { recursive: true, force: true });
    ws.send("/APP.UPDATE", { ok: false, error: error.message });
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

router.on("/DELETE_APP", async (ws, params) => {
  const { name } = params;
  logger.info(`[Apps] Deleting app: ${name}`);
  if (!name) {
    return ws.send("/DELETE_APP", { ok: false, error: "Name is required" });
  }

  try {
    // 새 apps 디렉토리 우선, 레거시 skills 디렉토리도 확인
    const appsDir = path.join(DATA_DIR, "apps", name);
    const legacyDir = path.join(DATA_DIR, "skills", name);
    const targetDir = fs.existsSync(appsDir) ? appsDir : fs.existsSync(legacyDir) ? legacyDir : null;

    if (targetDir) {
      rmDirSyncSafe(targetDir);
      await initAgent();
      logger.info(`[Apps] App ${name} deleted and agent re-initialized`);
      ws.send("/DELETE_APP", { ok: true, data: { success: true } });
      UserSocketHandler.broadcast("/INSTALLED_APPS_CHANGED", { appId: name });
    } else {
      logger.warn(`[Apps] App ${name} not found`);
      ws.send("/DELETE_APP", { ok: false, error: "App not found" });
    }
  } catch (e) {
    logger.error(`[Apps] Error deleting app ${name}: ${e}`);
    ws.send("/DELETE_APP", { ok: false, error: String(e) });
  }
});
