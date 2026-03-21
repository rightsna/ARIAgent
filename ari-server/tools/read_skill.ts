import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { loadAllSkills } from "../skills";

export const readSkillTool: AgentTool = {
  name: "read_skill",
  label: "스킬 읽기",
  description: "등록된 스킬의 지침 내용을 읽어와 다음 작업에 참고합니다.",
  parameters: Type.Object({
    name: Type.String({ description: "읽을 스킬 이름" }),
  }),
  execute: async (_toolCallId, params) => {
    const skillName = String((params as { name: string } | undefined)?.name || "").trim();
    if (!skillName) {
      return {
        content: [{ type: "text" as const, text: "스킬 이름이 필요합니다." }],
        details: {
          ok: false,
          error: "스킬 이름이 필요합니다.",
        },
      };
    }

    const skills = await loadAllSkills();
    const skill = skills.find((entry) => entry.name === skillName);

    if (!skill) {
      return {
        content: [{ type: "text" as const, text: `스킬 '${skillName}' 을(를) 찾을 수 없습니다.` }],
        details: {
          ok: false,
          error: `스킬 '${skillName}' 을(를) 찾을 수 없습니다.`,
          availableSkills: skills.map((entry) => entry.name),
        },
      };
    }

    return {
      content: [
        {
          type: "text" as const,
          text: [
            `스킬 이름: ${skill.name}`,
            skill.tools.length > 0
              ? `이 스킬에서 사용할 수 있는 도구: ${skill.tools.join(", ")}`
              : null,
            "같은 요청에서는 이 스킬을 다시 읽지 말고, 아래 지침에 따라 바로 도구를 사용하세요.",
            "",
            skill.content,
          ]
            .filter((line): line is string => !!line)
            .join("\n"),
        },
      ],
      details: {
        ok: true,
        name: skill.name,
        description: skill.description,
        tools: skill.tools,
        content: skill.content,
        filePath: skill.filePath,
      },
    };
  },
};
