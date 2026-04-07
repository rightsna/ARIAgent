import { Type, Static } from "@sinclair/typebox";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { appendDailyMemory } from "../services/memory.js";

const dailyParameters = Type.Object({
  content: Type.String({ description: "오늘의 일일 로그 파일에 추가할 마크다운 텍스트" }),
});

export const appendDailyMemoryTool: AgentTool<typeof dailyParameters> = {
  name: "append_daily_memory",
  label: "Append Daily Memory",
  description:
    "오늘의 일일 로그 파일 끝에 내용을 추가합니다. 단기 작업 기록, 오늘의 진행 상황, 임시 메모에 사용합니다.",
  parameters: dailyParameters,
  execute: async (toolCallId: string, args: Static<typeof dailyParameters>) => {
    try {
      appendDailyMemory(args.content);
      return {
        content: [{ type: "text", text: "오늘의 일일 로그가 성공적으로 추가되었습니다." }],
        details: null,
      };
    } catch (e: any) {
      return {
        content: [{ type: "text", text: `Failed to append daily memory: ${e.message}` }],
        details: null,
      };
    }
  },
};
