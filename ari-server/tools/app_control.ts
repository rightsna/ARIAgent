import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { exec, spawn } from "child_process";
import fs from "fs";
import os from "os";
import path from "path";
import { appStateService } from "../services/app_state_service.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import {
  getBundleRoots,
  getWorkspaceRoot,
  findAppExecutable,
} from "../infra/runtime_paths.js";
import { DATA_DIR } from "../infra/data.js";
import { loadAllApps } from "../skills/index.js";
import { execPromise } from "./bash.js";

function resolveAppExecutable(appName: string): string {
  const executable = findAppExecutable(appName);
  if (executable) return executable;
  throw new Error(`로컬 ${appName} 실행 파일을 찾지 못했습니다.`);
}

/**
 * read_app_state
 * 특정 앱의 현재 상태를 읽어오는 범용 도구
 */
export const readAppStateTool: AgentTool = {
  name: "read_app_state",
  label: "앱 상태 읽기",
  description:
    "특정 앱(ID 기반)의 현재 상태를 동기화하여 읽어옵니다. 사용자가 앱에서 수정한 내용을 확인할 때 사용합니다.",
  parameters: Type.Object({
    appId: Type.String({
      description: "읽어올 앱의 식별자 (예: notepad, youtube_player)",
    }),
  }),
  execute: async (_id, params) => {
    const { appId } = params as { appId: string };

    try {
      // Pull 방식: 앱에게 직접 질의하여 최신 상태를 가져옴
      const result = await UserSocketHandler.commandApp(appId, 'GET_STATE');

      return {
        content: [
          {
            type: "text",
            text: `✅ '${appId}' 앱의 실시간 상태:\n${JSON.stringify(result, null, 2)}`,
          },
        ],
        details: { state: result },
      };
    } catch (error: any) {
      logger.warn(
        `[read_app_state] Failed to query '${appId}': ${error.message}. Falling back to cache.`,
      );

      // 실패 시 캐시된 상태라도 반환 (Fallback)
      const state = appStateService.getState(appId);
      if (!state) {
        return {
          content: [
            {
              type: "text",
              text: `❌ '${appId}' 앱과의 실시간 동기화에 실패했으며 캐시된 정보도 없습니다: ${error.message}`,
            },
          ],
          details: { appId, success: false, error: error.message },
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `⚠️ '${appId}' 앱 실시간 조회 실패(캐시 데이터 반환):\n${JSON.stringify(state.state, null, 2)}`,
          },
        ],
        details: { state: state.state, cached: true },
      };
    }
  },
};

/**
 * send_app_command
 * 특정 앱에 명령을 보내는 범용 원격 제어 도구
 */
export const sendAppCommandTool: AgentTool = {
  name: "send_app_command",
  label: "앱 명령 전송",
  description:
    "실행 중인 특정 앱에 제어 명령을 보냅니다. 해당 앱의 SKILL.md 파일에서 지원하는 명령어 목록을 먼저 확인하십시오.",
  parameters: Type.Object({
    appId: Type.String({
      description: "명령을 받을 앱의 식별자 (예: youtube_player, notepad)",
    }),
    command: Type.String({
      description: "실행할 명령어 (예: UPDATE, PLAY, PAUSE 등)",
    }),
    params: Type.Optional(
      Type.Any({ description: "명령어에 필요한 파라미터 객체" }),
    ),
  }),
  execute: async (_id, params) => {
    const {
      appId,
      command,
      params: cmdParams,
    } = params as { appId: string; command: string; params?: any };

    try {
      const result = await UserSocketHandler.commandApp(
        appId,
        command,
        cmdParams || {},
      );

      // 앱에서 반환한 결과 내부에 명시적인 '에러' 상태가 있는지 확인
      const isAppError = result?.status === "error" || result?.ok === false;

      if (isAppError) {
        return {
          content: [
            {
              type: "text",
              text: `❌ '${appId}' 앱에서 명령 실행 중 에러가 발생했습니다:\n${result?.message || JSON.stringify(result)}`,
            },
          ],
          details: {
            appId,
            command,
            params: cmdParams,
            result,
            success: false,
            error: result?.message,
          },
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `🚀 '${appId}' 앱의 '${command}' 실행 결과:\n${JSON.stringify(result, null, 2)}`,
          },
        ],
        details: { appId, command, params: cmdParams, result, success: true },
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: "text",
            text: `❌ '${appId}' 앱으로 명령 전송 또는 실행 실패: ${error.message}`,
          },
        ],
        details: { appId, command, success: false, error: error.message },
      };
    }
  },
};

export const launchAppTool: AgentTool = {
  name: "launch_app",
  label: "앱 실행",
  description:
    "지정된 앱을 실행합니다. 환경변수와 명령행 인자를 전달할 수 있습니다.",
  parameters: Type.Object({
    appName: Type.String({
      description: "실행할 앱의 이름",
    }),
    env: Type.Optional(
      Type.Record(Type.String(), Type.String(), {
        description: "앱에 전달할 환경변수 (선택)",
      }),
    ),
    args: Type.Optional(
      Type.Array(Type.String(), {
        description: "앱에 전달할 명령행 인자 (선택)",
      }),
    ),
  }),
  execute: async (_id, params) => {
    const { appName, env, args } = params as {
      appName: string;
      env?: Record<string, string>;
      args?: string[];
    };

    if (UserSocketHandler.isAppConnected(appName)) {
      return {
        content: [
          {
            type: "text",
            text: `⚠️ '${appName}' 앱이 이미 실행 중이며 서버에 연결되어 있습니다. 새로운 작업을 수행하려면 'send_app_command'를 사용하세요.`,
          },
        ],
        details: { appName, success: false, alreadyRunning: true },
      };
    }

    const executable = resolveAppExecutable(appName);
    logger.info(
      `[AppLifecycle] Launching app '${appName}' via: ${executable} (args: ${JSON.stringify(args || [])})`,
    );

    const launchLogDir = path.join(DATA_DIR, "launch-logs");
    fs.mkdirSync(launchLogDir, { recursive: true });
    const launchLogPath = path.join(launchLogDir, `${appName}.log`);
    const stdoutFd = fs.openSync(launchLogPath, "a");
    const stderrFd = fs.openSync(launchLogPath, "a");

    const defaultArgs = args || [];

    const bundlePath =
      process.platform === "darwin"
        ? executable.split("/Contents/MacOS/")[0]
        : null;
    const launcherExecutable =
      process.platform === "darwin" ? "open" : executable;
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
        ...env,
      },
    });

    child.on("error", (error: any) => {
      logger.error(`[AppLifecycle] ${appName} 실행 실패: ${error.message}`);
    });
    child.on("spawn", () => {
      logger.info(
        `[AppLifecycle] ${appName} spawned (pid: ${child.pid ?? "unknown"}) log: ${launchLogPath}`,
      );
    });
    child.on("exit", (code, signal) => {
      logger.warn(
        `[AppLifecycle] ${appName} exited (code: ${code ?? "null"}, signal: ${signal ?? "null"})`,
      );
    });
    child.unref();

    return {
      content: [{ type: "text", text: `✅ '${appName}' 앱을 실행했습니다.` }],
      details: { appName, success: true },
    };
  },
};

export const terminateAppTool: AgentTool = {
  name: "terminate_app",
  label: "앱 종료",
  description: "실행 중인 지정된 앱을 강제 종료합니다.",
  parameters: Type.Object({
    appName: Type.String({
      description: "종료할 앱의 이름",
    }),
  }),
  execute: async (_id, params) => {
    const { appName } = params as { appName: string };

    logger.info(`[AppLifecycle] Terminating app: ${appName}`);

    await new Promise<void>((resolve) => {
      let child;
      if (process.platform === "darwin") {
        child = spawn("pkill", ["-x", appName], { stdio: "ignore" });
      } else if (process.platform === "win32") {
        child = spawn("taskkill", ["/IM", `${appName}.exe`, "/F"], {
          stdio: "ignore",
          windowsHide: true,
        });
      } else {
        resolve();
        return;
      }
      child.on("error", () => resolve());
      child.on("exit", () => resolve());
    });

    await new Promise((resolve) => setTimeout(resolve, 250));

    return {
      content: [{ type: "text", text: `✅ '${appName}' 앱을 종료했습니다.` }],
      details: { appName, success: true },
    };
  },
};

/**
 * install_app
 * 외부 URL(.zip)로부터 ARI 앱을 다운로드하여 설치하거나 업데이트합니다.
 */
export const installAppTool: AgentTool = {
  name: "install_app",
  label: "앱 설치 및 업데이트",
  description:
    "외부 URL(.zip)로부터 ARI 앱을 다운로드하여 설치하거나 기존 앱을 업데이트합니다.",
  parameters: Type.Object({
    url: Type.String({ description: "설치할 앱의 .zip 다운로드 주소" }),
    appId: Type.Optional(
      Type.String({ description: "앱의 식별자 (생략 시 파일명에서 추출)" }),
    ),
    force: Type.Optional(
      Type.Boolean({ description: "버전이 같거나 낮아도 강제로 설치합니다." }),
    ),
  }),
  execute: async (_id, params) => {
    const {
      url,
      appId: providedAppId,
      force,
    } = params as { url: string; appId?: string; force?: boolean };

    // 1. appId 추출
    let appId = providedAppId;
    if (!appId) {
      const urlParts = url.split("/");
      const fileName = urlParts[urlParts.length - 1];
      appId = fileName.split("-")[0].replace(".zip", "");
    }

    logger.info(`[AppInstall] Starting installation for ${appId} from ${url}`);

    const tempDir = path.join(DATA_DIR, "tmp_install", appId);
    const skillsDir = path.join(DATA_DIR, "apps", appId);

    try {
      // 2. 준비
      if (fs.existsSync(tempDir))
        fs.rmSync(tempDir, { recursive: true, force: true });
      fs.mkdirSync(tempDir, { recursive: true });

      // 3. 다운로드
      const zipPath = path.join(tempDir, "app.zip");
      logger.info(`[AppInstall] Downloading to ${zipPath}`);
      await execPromise(`curl -L "${url}" -o "${zipPath}"`);

      // 4. 압축 해제
      const extractDir = path.join(tempDir, "extracted");
      fs.mkdirSync(extractDir, { recursive: true });
      logger.info(`[AppInstall] Extracting to ${extractDir}`);

      if (process.platform === "win32") {
        await execPromise(
          `powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${extractDir}' -Force"`,
        );
      } else {
        await execPromise(`unzip -o "${zipPath}" -d "${extractDir}"`);
      }

      // 5. 설치물 찾기 (중첩 폴더 및 __MACOSX 대응)
      let sourceDir = extractDir;
      const items = fs
        .readdirSync(extractDir)
        .filter((f) => !f.startsWith(".") && f !== "__MACOSX");

      if (
        items.length === 1 &&
        fs.statSync(path.join(extractDir, items[0])).isDirectory()
      ) {
        // 유효한 폴더가 하나만 있다면 그 안으로 들어감
        sourceDir = path.join(extractDir, items[0]);
      }

      // 6. 버전 확인 로직
      const newInfoPath = path.join(sourceDir, "app_info.json");
      const oldInfoPath = path.join(skillsDir, "app_info.json");

      if (fs.existsSync(newInfoPath) && fs.existsSync(oldInfoPath)) {
        try {
          const newInfo = JSON.parse(fs.readFileSync(newInfoPath, "utf-8"));
          const oldInfo = JSON.parse(fs.readFileSync(oldInfoPath, "utf-8"));

          const newVer = newInfo.version_code ?? newInfo.version;
          const oldVer = oldInfo.version_code ?? oldInfo.version;

          if (newVer <= oldVer && !force) {
            return {
              content: [
                {
                  type: "text",
                  text: `ℹ️ 이미 최신 버전(${oldInfo.version})이 설치되어 있습니다. (새로 설치하려는 버전: ${newInfo.version})\n강제로 설치하려면 '강제 설치' 옵션을 사용하세요.`,
                },
              ],
              details: {
                appId,
                success: true,
                updated: false,
                currentVersion: oldInfo.version,
              },
            };
          }
        } catch (err: any) {
          logger.warn(
            `[AppInstall] Version check comparison failed: ${err.message}`,
          );
        }
      }

      // 7. 실제 설치
      if (fs.existsSync(skillsDir)) {
        logger.info(`[AppInstall] Removing existing app at ${skillsDir}`);
        fs.rmSync(skillsDir, { recursive: true, force: true });
      }
      fs.mkdirSync(path.dirname(skillsDir), { recursive: true });

      logger.info(`[AppInstall] Moving ${sourceDir} to ${skillsDir}`);
      fs.renameSync(sourceDir, skillsDir);

      // 8. 스킬 리로드
      await loadAllApps();

      return {
        content: [
          {
            type: "text",
            text: `✅ '${appId}' 앱이 성공적으로 설치(업데이트)되었습니다.`,
          },
        ],
        details: { appId, success: true },
      };
    } catch (error: any) {
      logger.error(`[AppInstall] Failed to install ${appId}: ${error.message}`);
      return {
        content: [
          {
            type: "text",
            text: `❌ '${appId}' 앱 설치 중 오류 발생: ${error.message}`,
          },
        ],
        details: { appId, success: false, error: error.message },
      };
    } finally {
      // 8. 정리
      if (fs.existsSync(tempDir))
        fs.rmSync(tempDir, { recursive: true, force: true });
    }
  },
};

/**
 * list_apps
 * 연결된 앱과 설치된 앱의 목록을 조회합니다.
 */
export const listAppsTool: AgentTool = {
  name: "list_apps",
  label: "앱 목록 조회",
  description:
    "현재 서버에 연결된 실시간 앱 ID 목록과 설치된 번들 앱 목록을 조회합니다. 명령을 내릴 앱의 식별자를 찾을 때 사용합니다.",
  parameters: Type.Object({}),
  execute: async () => {
    // 1. 실시간 연결된 앱 ID 가져오기
    const connectedIds = UserSocketHandler.getConnectedAppIds();

    // 2. 설치된 앱 목록 가져오기 (폴더 기준)
    const bundleRoots = getBundleRoots();
    const installedApps: string[] = [];

    for (const root of bundleRoots) {
      if (fs.existsSync(root)) {
        const items = fs.readdirSync(root).filter((dir) => {
          const stats = fs.statSync(path.join(root, dir));
          return (
            stats.isDirectory() && !dir.startsWith(".") && dir !== "__MACOSX"
          );
        });
        installedApps.push(...items);
      }
    }

    const uniqueInstalled = Array.from(new Set(installedApps));

    return {
      content: [
        {
          type: "text",
          text:
            `📱 ARI 앱 목록:\n\n` +
            `🟢 연결됨 (Connected):\n${connectedIds.length > 0 ? connectedIds.map((id) => `- ${id}`).join("\n") : "(없음)"}\n\n` +
            `📦 설치됨 (Installed):\n${uniqueInstalled.length > 0 ? uniqueInstalled.map((id) => `- ${id}`).join("\n") : "(없음)"}`,
        },
      ],
      details: { connected: connectedIds, installed: uniqueInstalled },
    };
  },
};

export const TOOLS = [
  listAppsTool,
  readAppStateTool,
  sendAppCommandTool,
  launchAppTool,
  terminateAppTool,
  installAppTool,
];
