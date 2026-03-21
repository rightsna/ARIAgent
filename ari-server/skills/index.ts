import fs from "fs";
import path from "path";
import { readDirSyncSafe, DATA_DIR, ensureDirSync } from "../infra/data";
import { resolveServerPath } from "../infra/runtime_paths";

export interface SkillDefinition {
  name: string;
  title: string;
  description: string;
  tools: string[];
  content: string;
  filePath: string;
  isCustom?: boolean;
}

function parseSkillTools(content: string): string[] {
  const lines = content.split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    const match = line.match(/^(?:사용 도구|Tools)\s*:\s*(.+)$/i);
    if (!match?.[1]) continue;

    return match[1]
      .split(",")
      .map((value) => value.trim())
      .filter((value) => value.length > 0);
  }

  return [];
}

function parseSkillDescription(content: string): string {
  const lines = content.split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith("#")) continue;
    if (line.startsWith("```")) continue;
    if (/^(?:사용 도구|Tools)\s*:/i.test(line)) continue;
    return line;
  }
  return "추가 지침을 담고 있는 스킬입니다.";
}

function loadSkillsFromDir(dirPath: string): SkillDefinition[] {
  const skills: SkillDefinition[] = [];
  if (!fs.existsSync(dirPath)) return skills;

  const entries = readDirSyncSafe(dirPath);
  for (const entry of entries) {
    const skillDir = path.join(dirPath, entry);
    let stat: fs.Stats;
    try {
      stat = fs.statSync(skillDir);
    } catch {
      continue;
    }

    if (!stat.isDirectory()) continue;

    const skillFilePath = path.join(skillDir, "SKILL.md");
    if (!fs.existsSync(skillFilePath)) continue;

    const content = fs.readFileSync(skillFilePath, "utf8").trim();
    if (!content) continue;

    skills.push({
      name: entry,
      title: entry,
      description: parseSkillDescription(content),
      tools: parseSkillTools(content),
      content,
      filePath: skillFilePath,
    });
  }
  return skills;
}

export async function loadAllSkills(): Promise<SkillDefinition[]> {
  const skillMap = new Map<string, SkillDefinition>();

  // 1. 기본 제공 스킬 후보지들
  const builtInDirs = [
    resolveServerPath("skills"),
    __dirname,
    path.join(__dirname, "..", "..", "skills"), // dist 환경 등 대비
    path.join(process.cwd(), "skills"),
  ];

  // 기본 스킬 로드 (중복 발생 시 덮어쓰기 위해 순차 로드)
  for (const dir of builtInDirs) {
    const skills = loadSkillsFromDir(dir);
    for (const skill of skills) {
      skillMap.set(skill.name, { ...skill, isCustom: false });
    }
  }

  // 2. 커스텀 스킬 (User Data Dir)
  const userSkillsDir = path.join(DATA_DIR, "skills");
  ensureDirSync(userSkillsDir);
  const userSkills = loadSkillsFromDir(userSkillsDir);
  for (const skill of userSkills) {
    // 커스텀 스킬이 항상 우선순위를 갖도록 마지막에 덮어씀
    skillMap.set(skill.name, { ...skill, isCustom: true });
  }

  const result = Array.from(skillMap.values());
  result.sort((a, b) => a.name.localeCompare(b.name));
  return result;
}
