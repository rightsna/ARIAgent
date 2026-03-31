import { loadAllSkills, SkillDefinition } from "../../skills";

export type ActiveSkill = Pick<SkillDefinition, "name" | "description" | "tools" | "content" | "isApp">;

export async function loadAvailableSkills(): Promise<SkillDefinition[]> {
  return await loadAllSkills();
}

export function clearSkillCache(): void {
  // 캐시를 사용하지 않으므로 본문을 비웁니다.
}

function cloneSkill(skill: ActiveSkill): ActiveSkill {
  return {
    name: skill.name,
    description: skill.description,
    tools: [...skill.tools],
    content: skill.content,
    isApp: skill.isApp,
  };
}

export function cloneActiveSkills(skills: ActiveSkill[]): ActiveSkill[] {
  return skills.map(cloneSkill);
}

export function mergeActiveSkill(activeSkills: ActiveSkill[], details: any): ActiveSkill[] {
  if (!details?.ok || typeof details?.name !== "string" || typeof details?.content !== "string") {
    return cloneActiveSkills(activeSkills);
  }

  const nextSkill: ActiveSkill = {
    name: details.name,
    description: typeof details.description === "string" ? details.description : "",
    tools: Array.isArray(details.tools) ? details.tools.filter((tool: unknown): tool is string => typeof tool === "string") : [],
    content: details.content,
    isApp: !!details.isApp,
  };

  const remaining = activeSkills.filter((skill) => skill.name !== nextSkill.name);
  return [...cloneActiveSkills(remaining), nextSkill];
}

export function collectSkillToolNames(activeSkills: ActiveSkill[]): Set<string> {
  const toolNames = new Set<string>();

  for (const skill of activeSkills) {
    for (const toolName of skill.tools) {
      if (toolName.trim()) {
        toolNames.add(toolName.trim());
      }
    }
  }

  return toolNames;
}
