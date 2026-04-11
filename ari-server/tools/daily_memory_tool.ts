import { Type, Static } from "@sinclair/typebox";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { appendDailyMemory } from "../services/memory.js";

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

const dailyParameters = Type.Object({
  content: Type.String({ description: "오늘의 일일 로그 파일에 추가할 마크다운 텍스트" }),
  topics: Type.Optional(
    Type.Array(Type.String(), {
      description: "이 로그의 주제 카테고리 (예: ['코딩', '일정', '완료된작업'])",
    }),
  ),
  entities: Type.Optional(
    Type.Array(entitySchema, {
      description: "이 로그에서 언급되는 주요 엔티티 목록",
    }),
  ),
  importance: Type.Optional(
    Type.Union(
      [Type.Literal("low"), Type.Literal("normal"), Type.Literal("high")],
      { description: "로그의 중요도. 기본값: normal" },
    ),
  ),
});

export const appendDailyMemoryTool: AgentTool<typeof dailyParameters> = {
  name: "append_daily_memory",
  label: "Append Daily Memory",
  description:
    "오늘의 일일 로그 파일 끝에 내용을 추가합니다. " +
    "단기 작업 기록, 오늘의 진행 상황, 임시 메모에 사용합니다. " +
    "고급 관계 지능이 활성화된 경우 topics와 entities를 함께 제공하면 의미 검색 품질이 향상됩니다.",
  parameters: dailyParameters,
  execute: async (_toolCallId: string, args: Static<typeof dailyParameters>) => {
    try {
      appendDailyMemory(args.content, undefined, {
        topics: args.topics,
        entities: args.entities,
        importance: args.importance,
      });
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
