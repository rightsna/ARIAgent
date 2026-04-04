import fs from "fs";
import path from "path";
import { Task, ARI_CRON_TAG } from "../models/task";
import { getSettings } from "../repositories/setting_repository";
import { getTasks, saveTasks } from "../repositories/task_repository";
import { saveTaskResult } from "../repositories/task_result_repository";
import { TaskResult } from "../models/task_result";
import { getCronLogFilePath, getCronTempFilePath, writeCronTempConfig, removeCronTempConfig } from "../repositories/cron_repository";
import { getServerRootDir, isBundledServer } from "../infra/runtime_paths";

function timestamp() {
  return new Date().toISOString().replace("T", " ").substring(0, 19);
}

import { WebSocket } from "ws";

import { Settings } from "../models/settings";
import { logger } from "../infra/logger";

async function getServerPort() {
  const config = getSettings(new Settings());
  return config.PORT || 29277;
}

const { exec } = require("child_process");
const util = require("util");
const execPromise = util.promisify(exec);

function getRunTaskInvocation(taskId: string, agentId: string): string {
  if (isBundledServer()) {
    return `"${process.execPath}" --run-task "${taskId}" --agent="${agentId}"`;
  }

  const serverRoot = getServerRootDir();
  const runTaskTs = path.join(serverRoot, "jobs", "run_task.ts");
  const runTaskJs = path.join(serverRoot, "dist", "jobs", "run_task.js");
  const runTaskScript = fs.existsSync(runTaskJs) ? runTaskJs : runTaskTs;
  const nodeBin = process.execPath;
  const useTsRegister = runTaskScript.endsWith(".ts");

  return useTsRegister
    ? `${nodeBin} -r ts-node/register "${runTaskScript}" "${taskId}" --agent="${agentId}"`
    : `${nodeBin} "${runTaskScript}" "${taskId}" --agent="${agentId}"`;
}

export async function runScheduledTask(taskId: string): Promise<void> {
  fs.appendFileSync("/tmp/run_task_ari.log", `[${timestamp()}] STARTING with argv: ${JSON.stringify(process.argv)}\n`);
  logger.info(`[${timestamp()}] 🔔 작업 실행 시작: ${taskId}`);

  const tasks: Task[] = getTasks();
  if (tasks.length === 0) {
    logger.info("❌ tasks.json이 없거나 비어 있습니다.");
    process.exit(1);
  }
  const task = tasks.find((t: Task) => t.id === taskId);

  if (!task) {
    logger.info(`❌ 작업 ID ${taskId}를 찾을 수 없음`);
    process.exit(1);
  }

  if (task.enabled === false) {
    logger.info("⏸️ 비활성 작업 — 스킵");
    process.exit(0);
  }

  const port = await getServerPort();

  // 단일 WebSocket 연결로 모든 작업 처리 (Persistent Connection 방식)
  const ws = new WebSocket(`ws://localhost:${port}`);

  ws.on("open", () => {
    logger.info(`[${timestamp()}] 🔌 에이전트 연결 성공 (Port: ${port})`);

    // 1. AI 응답 요청 (COMMAND {JSON} 형식)
    const request = `/AGENT ${JSON.stringify({
      message: task.prompt,
      agentId: task.agentId || "default",
    })}`;
    logger.info(`[${timestamp()}] 📤 AI 응답 요청 전송: ${request.substring(0, 100)}...`);
    ws.send(request);
  });

  ws.on("message", async (data) => {
    const dataStr = data.toString();
    logger.info(`[${timestamp()}] 📥 에이전트 응답 수신 raw: ${dataStr.substring(0, 100)}...`);
    try {
      const firstSpace = dataStr.indexOf(" ");
      if (firstSpace === -1) {
        logger.info(`[${timestamp()}] ⚠️ 명령어 없음: ${dataStr}`);
        return;
      }

      const cmd = dataStr.substring(0, firstSpace);
      const res = JSON.parse(dataStr.substring(firstSpace + 1));

      // AI 응답이 도착했을 때 (/AGENT)
      if (cmd === "/AGENT") {
        const response = res.data?.response || "응답 없음";
        logger.info(`[${timestamp()}] ✅ AI 응답 수신완료 (내용: ${response.substring(0, 50)}...)`);

        // 2. UI 알림 요청 (동일한 커넥션 사용 - 로컬 MQ Gateway 역할)
        const notify = `/TASKS.NOTIFY_RESULT ${JSON.stringify({
          taskId,
          label: task.label,
          result: response,
        })}`;
        logger.info(`[${timestamp()}] 📤 UI 알림 전송: ${notify}`);
        ws.send(notify);

        // 결과 저장
        saveResultData(taskId, task, response);

        // 마지막 단계: 1회성 스케줄러 삭제 및 마무리
        if (task.isOneOff) {
          await cleanupOneOffTask(taskId, tasks);
        }
      }

      // UI 알림 요청에 대한 확인이 오면 종료 (/TASKS.NOTIFY_RESULT)
      if (cmd === "/TASKS.NOTIFY_RESULT") {
        logger.info(`[${timestamp()}] ✅ 모든 작업 완료 및 UI 알림 전송됨.`);
        ws.close();
        process.exit(0);
      }
    } catch (err) {
      logger.error(`[${timestamp()}] ❌ 처리 중 오류:`, err);
      ws.close();
      process.exit(1);
    }
  });

  ws.on("error", (err) => {
    logger.error(`❌ 에이전트 연결 실패: ${err.message}`);
    process.exit(1);
  });

  // 타임아웃 방지
  setTimeout(() => {
    logger.error("❌ 작업 타임아웃 (30초)");
    ws.close();
    process.exit(1);
  }, 30000);
}

async function main() {
  if (process.argv.length < 3) {
    logger.info("Usage: node run_task.js <task_id>");
    process.exit(1);
  }

  const taskId = process.argv[2];
  await runScheduledTask(taskId);
}

function saveResultData(taskId: string, task: any, result: string) {
  const resultData = new TaskResult({
    taskId,
    prompt: task.prompt,
    label: task.label,
    result,
    executedAt: new Date().toISOString(),
  });
  saveTaskResult(taskId, resultData);
  logger.info(`  💾 결과 저장 완료`);
}

async function cleanupOneOffTask(taskId: string, tasks: Task[]) {
  logger.info(`[${timestamp()}] 🗑️ 1회성 스케줄러 삭제 처리 중...`);
  const remainingTasks = tasks.filter((t: Task) => t.id !== taskId);
  saveTasks(remainingTasks);

  try {
    const { stdout } = await execPromise("crontab -l 2>/dev/null").catch(() => ({ stdout: "" }));
    const otherLines = stdout.split("\n").filter((l: string) => l.trim() && !l.includes(ARI_CRON_TAG));
    const enabled = remainingTasks.filter((t: Task) => t.enabled !== false);

    const projectRoot = getServerRootDir();

    const ariLines = enabled.map((t: Task) => {
      const aid = t.agentId || "default";
      const logFile = getCronLogFilePath();
      const nodePathExport = isBundledServer() ? ` export NODE_PATH="${path.join(projectRoot, "node_modules")}" &&` : "";
      const taskCommand = getRunTaskInvocation(t.id, aid);
      return `${t.cron} export PATH=/usr/local/bin:/opt/homebrew/bin:$PATH &&${nodePathExport} cd ${projectRoot} && ${taskCommand} >> "${logFile}" 2>&1 # ${ARI_CRON_TAG}`;
    });

    const allLines = [...otherLines, ...ariLines];
    const tmp = getCronTempFilePath();
    const content = allLines.length > 0 ? allLines.join("\n") + "\n" : "";
    writeCronTempConfig(content);
    if (allLines.length > 0) {
      await execPromise(`crontab ${tmp}`);
    } else {
      await execPromise("crontab -r").catch(() => {});
    }
    removeCronTempConfig();
    logger.info(`  📅 crontab 갱신 완료`);
  } catch (e: any) {
    logger.info(`❌ crontab 갱신 실패: ${e.message}`);
  }
}

if (require.main === module) {
  main().catch(logger.error);
}
