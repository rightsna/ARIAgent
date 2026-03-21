import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { exec } from "child_process";
import { logger } from "../infra/logger";

export function execPromise(cmd: string, opts?: { timeout?: number }): Promise<string> {
  return new Promise((resolve, reject) => {
    exec(cmd, { maxBuffer: 1024 * 1024, ...opts }, (err, stdout, stderr) => {
      err ? reject(new Error(stderr || err.message)) : resolve(stdout || stderr);
    });
  });
}

function isDangerous(cmd: string): boolean {
  return [/\brm\s+(-[a-zA-Z]*)?r/, /\bsudo\b/, /\bmkfs\b/, /\bdd\s+if=/, /\bshutdown\b/, /\breboot\b/, /\bkill\s+-9/].some((p) => p.test(cmd));
}

export const executeBashTool: AgentTool = {
  name: "execute_bash",
  label: "Bash 실행",
  description: "macOS에서 bash 명령어를 실행한다. 파일 목록, 시스템 정보 조회 등 읽기 전용 명령만 허용. rm, sudo 등 위험 명령 금지.",
  parameters: Type.Object({
    command: Type.String({ description: "실행할 bash 명령어 (예: ls -la ~/Desktop)" }),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const command = (params as { command: string }).command;
    logger.info(`🔧 Tool[bash]: ${command}`);
    if (isDangerous(command)) {
      throw new Error("⚠️ 보안상 실행이 차단된 명령어입니다.");
    }
    const output = await execPromise(command, { timeout: 15000 });
    return {
      content: [{ type: "text" as const, text: output }],
      details: {},
    };
  },
};

export const TOOLS = [executeBashTool];
