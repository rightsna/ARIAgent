import { Type, Static } from "@sinclair/typebox";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { searchDailyLogs, searchRelevantMemories } from "../services/memory.js";
import { getSettings } from "../repositories/setting_repository.js";
import { Settings } from "../models/settings.js";
import { getEmbeddingStatus } from "../services/embedding.js";

function isAdvancedMemoryReady(): boolean {
  const settings = getSettings(new Settings());
  if (!settings.USE_ADVANCED_MEMORY) return false;
  return getEmbeddingStatus().status === "ready";
}

const searchParameters = Type.Object({
  query: Type.String({ description: "검색할 키워드 또는 질문" }),
});

export const searchMemoryTool: AgentTool<typeof searchParameters> = {
  name: "search_memory",
  label: "Search Memory",
  description:
    "과거 로그에서 관련 기록을 검색합니다. " +
    "특정 날짜의 활동, 과거 결정사항, 언급된 주제 등을 찾을 때 사용합니다.",
  parameters: searchParameters,
  execute: async (_toolCallId: string, args: Static<typeof searchParameters>) => {
    try {
      const parts: string[] = [];

      const fileResult = searchDailyLogs(args.query);
      if (fileResult) parts.push(`[로그 검색]\n${fileResult}`);

      if (isAdvancedMemoryReady()) {
        const kuzuResult = await searchRelevantMemories(args.query, undefined, 8);
        if (kuzuResult) parts.push(`[메모리 검색]\n${kuzuResult}`);
      }

      const result = parts.join("\n\n");

      if (!result) {
        return {
          content: [{ type: "text", text: "검색 결과가 없습니다." }],
          details: null,
        };
      }

      return {
        content: [{ type: "text", text: result }],
        details: null,
      };
    } catch (e: any) {
      return {
        content: [{ type: "text", text: `검색 실패: ${e.message}` }],
        details: null,
      };
    }
  },
};
