import fs from "fs";
import path from "path";
import { readDirSyncSafe, DATA_DIR, ensureDirSync } from "../infra/data.js";
import { getBundleRoots, resolveServerPath } from "../infra/runtime_paths.js";

export interface SkillDefinition {
  name: string;
  title: string;
  description: string;
  tools: string[];
  content: string;
  filePath: string;
  isCustom?: boolean;
  isApp?: boolean;
  icon?: string;
  iconPath?: string;
}

export type AppDefinition = SkillDefinition;

function parseSkillTools(content: string): string[] {
  const lines = content.split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    // Remove markdown bold formatting, but DO NOT remove underscores because tool names use them!
    const plainLine = line.replace(/\*/g, "");
    
    // Match variations like "사용 도구:", "Tools:", "사용 도구 (Tools):"
    const match = plainLine.match(/^(?:사용\s*도구|Tools).*?:\s*(.+)$/i);
    if (!match?.[1]) continue;

    return match[1]
      .split(",")
      .map((value) => value.replace(/`/g, "").trim())
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

function parseSkillIcon(content: string): string | undefined {
  const lines = content.split(/\r?\n/);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    // Case-insensitive match for "Icon: <name>"
    const match = line.match(/^Icon\s*:\s*(.+)$/i);
    if (match?.[1]) return match[1].trim();
  }
  return undefined;
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

    const iconFilePath = path.join(skillDir, "icon.png");
    skills.push({
      name: entry,
      title: entry,
      description: parseSkillDescription(content),
      tools: parseSkillTools(content),
      icon: parseSkillIcon(content),
      iconPath: fs.existsSync(iconFilePath) ? iconFilePath : undefined,
      content,
      filePath: skillFilePath,
      isApp: fs.existsSync(path.join(skillDir, "app.app")) || fs.existsSync(path.join(skillDir, "app_info.json")),
    });
  }
  return skills;
}

export async function loadAllSkills(): Promise<SkillDefinition[]> {
  const skillMap = new Map<string, SkillDefinition>();

  // 1. 기본 제공 스킬
  const builtInDirs = [
    resolveServerPath("skills"),
    path.join(process.cwd(), "skills"),
    path.join(process.cwd(), "ari-server", "skills"),
  ];

  for (const dir of builtInDirs) {
    for (const skill of loadSkillsFromDir(dir)) {
      if (skill.isApp) continue;
      skillMap.set(skill.name, { ...skill, isCustom: false });
    }
  }

  // 2. 커스텀 스킬 (~/.ari-agent/skills) — 앱 제외
  const userSkillsDir = path.join(DATA_DIR, "skills");
  ensureDirSync(userSkillsDir);
  for (const skill of loadSkillsFromDir(userSkillsDir)) {
    if (skill.isApp) continue;
    skillMap.set(skill.name, { ...skill, isCustom: true });
  }

  const result = Array.from(skillMap.values());
  result.sort((a, b) => a.name.localeCompare(b.name));
  return result;
}

export async function loadAllApps(): Promise<AppDefinition[]> {
  const appMap = new Map<string, AppDefinition>();

  // 1. 번들 루트 (설치된 .app 패키지 등)
  for (const dir of getBundleRoots()) {
    for (const skill of loadSkillsFromDir(dir)) {
      if (!skill.isApp) continue;
      appMap.set(skill.name, { ...skill, isCustom: true });
    }
  }

  // 2. 레거시: ~/.ari-agent/skills 에 isApp으로 설치된 항목
  const legacySkillsDir = path.join(DATA_DIR, "skills");
  for (const skill of loadSkillsFromDir(legacySkillsDir)) {
    if (!skill.isApp) continue;
    appMap.set(skill.name, { ...skill, isCustom: true });
  }

  // 3. 사용자 앱 (~/.ari-agent/apps) — 여기가 새 기본 위치
  const userAppsDir = path.join(DATA_DIR, "apps");
  ensureDirSync(userAppsDir);
  for (const skill of loadSkillsFromDir(userAppsDir)) {
    appMap.set(skill.name, { ...skill, isCustom: true, isApp: true });
  }

  const result = Array.from(appMap.values());
  result.sort((a, b) => a.name.localeCompare(b.name));
  return result;
}
