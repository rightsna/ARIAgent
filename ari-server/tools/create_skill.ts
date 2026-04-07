import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import path from "path";
import fs from "fs";
import { DATA_DIR, ensureDirSync } from "../infra/data.js";
import { loadAllSkills } from "../skills/index.js";

export const createSkillTool: AgentTool = {
  name: "create_skill",
  label: "스킬 생성",
  description: "새로운 커스텀 스킬을 생성하고 등록합니다. 스킬 이름, 설명, 사용 도구, 지침 내용을 입력받아 파일로 저장합니다.",
  parameters: Type.Object({
    name: Type.String({ description: "스킬 이름 (영문 소문자와 언더바만 사용, 예: coding_helper)" }),
    description: Type.String({ description: "스킬에 대한 간략한 설명" }),
    tools: Type.Array(Type.String(), { description: "이 스킬에서 사용할 도구 목록 (예: ['execute_bash', 'web_browser'])" }),
    content: Type.String({ description: "스킬의 상세 지침 내용 (Markdown 형식)" }),
  }),
  execute: async (_toolCallId, params) => {
    const { name, description, tools, content } = params as {
      name: string;
      description: string;
      tools: string[];
      content: string;
    };

    const skillName = name.trim().toLowerCase().replace(/\s+/g, "_");
    if (!skillName) {
      throw new Error("스킬 이름이 유효하지 않습니다.");
    }

    const userSkillsDir = path.join(DATA_DIR, "skills", skillName);
    ensureDirSync(userSkillsDir);

    const skillFilePath = path.join(userSkillsDir, "SKILL.md");

    // SKILL.md 파일 내용 구성
    const fileContent = [`사용 도구: ${tools.join(", ")}`, "", `# ${description}`, "", content].join("\n");

    fs.writeFileSync(skillFilePath, fileContent, "utf8");

    // 등록 확인을 위해 다시 로드 시도
    const updatedSkills = await loadAllSkills();
    const isRegistered = updatedSkills.some((s) => s.name === skillName);

    return {
      content: [
        {
          type: "text" as const,
          text: `스킬 '${skillName}'이(가) 성공적으로 생성 및 등록되었습니다. ${isRegistered ? "(자동 리로드 완료)" : ""}`,
        },
      ],
      details: {
        ok: true,
        name: skillName,
        filePath: skillFilePath,
      },
    };
  },
};

export const TOOLS = [createSkillTool];
