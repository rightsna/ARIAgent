import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { logger } from "../infra/logger.js";

async function executeDelay(toolName: string, seconds: number) {
  logger.info(`⏳ Tool[${toolName}]: Waiting for ${seconds}s...`);
  await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
  return {
    content: [
      { type: "text" as const, text: `✅ ${seconds}초 동안 대기 완료.` },
    ],
    details: { seconds },
  };
};

export const sleepTool: AgentTool = {
  name: "sleep",
  label: "대기",
  description:
    "지정한 초(second)만큼 대기합니다. API 속도 제한(Rate Limit)이 발생하거나, 다음 작업을 수행하기 전 물리적인 시간이 필요할 때 사용합니다.",
  parameters: Type.Object({
    seconds: Type.Number({ description: "대기할 초 단위 시간 (예: 2)" }),
  }),
  execute: async (_id, params) =>
    executeDelay("sleep", (params as { seconds: number }).seconds),
};

export const TOOLS = [sleepTool];
