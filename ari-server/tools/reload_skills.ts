import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { loadAllSkills } from "../skills/index.js";

export const reloadSkillsTool: AgentTool = {
  name: "reload_skills",
  label: "스킬 목록 갱신",
  description: "파일 시스템에서 스킬 정보를 다시 읽어와 사용 가능한 스킬 목록을 최신화합니다. 새로운 스킬을 생성하거나 수정한 후 사용하세요.",
  parameters: Type.Object({}),
  execute: async () => {
    const skills = await loadAllSkills();
    const skillNames = skills.map((s) => s.name).join(", ");

    return {
      content: [
        {
          type: "text" as const,
          text: `스킬 목록이 성공적으로 갱신되었습니다.\n현재 사용 가능한 스킬: ${skillNames}`,
        },
      ],
      details: {
        ok: true,
        skills: skills.map((s) => ({ name: s.name, description: s.description })),
      },
    };
  },
};

export const TOOLS = [reloadSkillsTool];
