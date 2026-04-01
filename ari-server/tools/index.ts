import path from "path";
import fs from "fs";
import { readDirSyncSafe, DATA_DIR, ensureDirSync } from "../infra/data";
import { AgentTool } from "@mariozechner/pi-agent-core";
import { logger } from "../infra/logger";
import { TOOLS as APP_CONTROL_TOOLS } from "./app_control";
import { TOOLS as BASH_TOOLS } from "./bash";
import { TOOLS as CREATE_SKILL_TOOLS } from "./create_skill";
import { TOOLS as CREDENTIAL_TOOLS } from "./credentials";
import { TOOLS as RELOAD_SKILLS_TOOLS } from "./reload_skills";
import { TOOLS as SCHEDULE_TOOLS } from "./schedule";
import { TOOLS as WEB_BROWSER_TOOLS } from "./web_browser";
import { TOOLS as WEB_FETCH_TOOLS } from "./web_fetch";
import { TOOLS as YOUTUBE_SEARCH_TOOLS } from "./youtube_search";
import { TOOLS as UTILS_TOOLS } from "./utils";
import { TOOLS as HA_TOOLS } from "./homeassistant";
import { updateCoreMemoryTool } from "./core_memory_tool";
import { appendDailyMemoryTool } from "./daily_memory_tool";
import { readSkillTool } from "./read_skill";

const BUILT_IN_TOOLS = [
  ...APP_CONTROL_TOOLS,
  ...BASH_TOOLS,
  ...CREATE_SKILL_TOOLS,
  ...CREDENTIAL_TOOLS,
  ...RELOAD_SKILLS_TOOLS,
  ...SCHEDULE_TOOLS,
  ...WEB_BROWSER_TOOLS,
  ...WEB_FETCH_TOOLS,
  ...YOUTUBE_SEARCH_TOOLS,
  ...UTILS_TOOLS,
  ...HA_TOOLS,
  updateCoreMemoryTool,
  appendDailyMemoryTool,
  readSkillTool,
] as AgentTool[];

async function loadToolsFromDir(dirPath: string): Promise<AgentTool[]> {
  const tools: AgentTool[] = [];
  if (!fs.existsSync(dirPath)) return tools;

  const files = readDirSyncSafe(dirPath);
  for (const file of files) {
    if (!file.endsWith(".ts") && !file.endsWith(".js") && !file.endsWith(".mjs") && !file.endsWith(".cjs")) {
      continue;
    }

    try {
      const modulePath = path.resolve(dirPath, file);
      const module = await import(modulePath);

      if (module.TOOLS && Array.isArray(module.TOOLS)) {
        tools.push(...module.TOOLS);
      } else {
        for (const key of Object.keys(module)) {
          const val = module[key];
          if (val && typeof val === "object" && typeof val.execute === "function" && typeof val.name === "string") {
            tools.push(val);
          }
        }
      }
    } catch (err) {
      logger.warn(`Failed to load tool from ${file} in ${dirPath}:`, err);
    }
  }
  return tools;
}

export async function loadAllTools(): Promise<AgentTool[]> {
  const toolMap = new Map<string, AgentTool>();

  for (const tool of BUILT_IN_TOOLS) {
    toolMap.set(tool.name, tool);
  }

  const userToolsDir = path.join(DATA_DIR, "tools");
  ensureDirSync(userToolsDir);
  const userTools = await loadToolsFromDir(userToolsDir);
  for (const tool of userTools) {
    toolMap.set(tool.name, tool);
  }

  return Array.from(toolMap.values());
}
