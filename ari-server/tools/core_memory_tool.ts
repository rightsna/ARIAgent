import { Type, Static } from "@sinclair/typebox";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { updateCoreMemory, readCoreMemory } from "../services/memory.js";

const entitySchema = Type.Object({
  name: Type.String({ description: "엔티티 이름 (예: TypeScript, 홍길동, VSCode)" }),
  type: Type.Optional(
    Type.Union(
      [
        Type.Literal("person"),
        Type.Literal("tool"),
        Type.Literal("concept"),
        Type.Literal("place"),
        Type.Literal("other"),
      ],
      { description: "엔티티 유형: person(사람), tool(도구/기술), concept(개념), place(장소), other" },
    ),
  ),
});

const memoryParameters = Type.Object({
  content: Type.Optional(
    Type.String({ description: "MEMORY.md 파일에 새로 덮어씌울 전체 마크다운 내용" }),
  ),
  topics: Type.Optional(
    Type.Array(Type.String(), {
      description: "이 기억의 주제 카테고리 (예: ['코딩', '사용자정보', '규칙', '일정'])",
    }),
  ),
  entities: Type.Optional(
    Type.Array(entitySchema, {
      description: "이 기억에서 언급되는 주요 엔티티 목록",
    }),
  ),
  importance: Type.Optional(
    Type.Union(
      [Type.Literal("low"), Type.Literal("normal"), Type.Literal("high")],
      { description: "기억의 중요도. high는 검색 시 우선순위가 높아집니다. 기본값: normal" },
    ),
  ),
  read_only: Type.Optional(
    Type.Boolean({ description: "true로 설정하면 수정하지 않고 현재 메모리 내용을 반환하기만 합니다." }),
  ),
});

export const updateCoreMemoryTool: AgentTool<typeof memoryParameters> = {
  name: "update_core_memory",
  label: "Update Core Memory",
  description:
    "장기 기억(MEMORY.md)을 읽거나 전체 내용을 새 문서로 덮어씁니다. " +
    "사용자 프로필, 장기 규칙, 계속 기억할 사실에 사용합니다. " +
    "고급 관계 지능이 활성화된 경우 topics와 entities를 함께 제공하면 의미 검색 품질이 향상됩니다.",
  parameters: memoryParameters,
  execute: async (_toolCallId: string, args: Static<typeof memoryParameters>) => {
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
      updateCoreMemory(args.content, undefined, {
        topics: args.topics,
        entities: args.entities,
        importance: args.importance,
      });
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
