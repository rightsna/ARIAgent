import { Type, Static } from "@sinclair/typebox";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { updateCoreMemory, readCoreMemory } from "../services/memory.js";

const memoryParameters = Type.Object({
  content: Type.Optional(Type.String({ description: "MEMORY.md 파일에 새로 덮어씌울 전체 마크다운 내용" })),
  read_only: Type.Optional(Type.Boolean({ description: "true로 설정하면 수정하지 않고 현재 메모리 내용을 반환하기만 합니다. 기본값은 false." })),
});

export const updateCoreMemoryTool: AgentTool<typeof memoryParameters> = {
  name: "update_core_memory",
  label: "Update Core Memory",
  description:
    "장기 기억(MEMORY.md)을 읽거나 전체 내용을 새 문서로 덮어씁니다. 사용자 프로필, 장기 규칙, 계속 기억할 사실에 사용합니다.",
  parameters: memoryParameters,
  execute: async (toolCallId: string, args: Static<typeof memoryParameters>) => {
    if (args.read_only) {
      const current = readCoreMemory();
      return {
        content: [{ type: "text", text: current ? current : "현재 MEMORY.md 가 비어있습니다." }],
        details: null,
      };
    }

    if (!args.content) {
      return {
        content: [{ type: "text", text: "Error: 업데이트하려면 'content' 인자가 필요합니다." }],
        details: null,
      };
    }

    try {
      updateCoreMemory(args.content);
      return {
        content: [{ type: "text", text: "MEMORY.md (장기 기억) 업데이트가 성공적으로 완료되었습니다." }],
        details: null,
      };
    } catch (e: any) {
      return {
        content: [{ type: "text", text: `Failed to update core memory: ${e.message}` }],
        details: null,
      };
    }
  },
};
