import path from "path";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync } from "../infra/data.js";
import { AgentsConfig } from "../models/agent.js";
import { logger } from "../infra/logger.js";

const AGENTS_FILE = path.join(DATA_DIR, "agents.json");

export function getAgentsConfig(defaultConfig: AgentsConfig): AgentsConfig {
  if (!fileExistsSync(AGENTS_FILE)) {
    saveAgents(defaultConfig);
    return defaultConfig;
  }
  try {
    const configData = readJsonSync<any>(AGENTS_FILE, null);
    if (!configData) return defaultConfig;
    return AgentsConfig.fromJson(configData);
  } catch (e) {
    logger.error(`에이전트 설정 파싱 오류:`, e);
    return defaultConfig;
  }
}

export function saveAgents(agents: AgentsConfig | any): void {
  writeJsonSync(AGENTS_FILE, agents);
}
