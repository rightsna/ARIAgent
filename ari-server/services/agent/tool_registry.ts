import { AgentTool } from "@mariozechner/pi-agent-core";
import { loadAllTools } from "../../tools";

const MAIN_TOOL_NAMES = new Set<string>([
  "execute_bash",
  "register_schedule",
  "register_one_off_schedule",
  "update_core_memory",
  "append_daily_memory",
  "read_skill",
  "set_credential",
  "get_credential",
  "delete_credential",
  "web_browse",
  "web_fetch",
  "read_app_state",
  "send_app_command",
]);

let cachedAllTools: AgentTool[] = [];
let cachedMainTools: AgentTool[] = [];

export async function loadMainTools(): Promise<AgentTool[]> {
  const allTools = await loadAllTools();
  cachedAllTools = allTools;
  cachedMainTools = allTools.filter((tool) => MAIN_TOOL_NAMES.has(tool.name));
  return cachedMainTools;
}

async function loadCachedTools(): Promise<AgentTool[]> {
  const allTools = await loadAllTools();
  cachedAllTools = allTools;
  return allTools;
}

function buildMergedTools(mainTools: AgentTool[], allTools: AgentTool[], extraToolNames: Iterable<string>): AgentTool[] {
  const merged = new Map<string, AgentTool>();

  for (const tool of mainTools) {
    merged.set(tool.name, tool);
  }

  for (const toolName of extraToolNames) {
    const tool = allTools.find((entry) => entry.name === toolName);
    if (tool) {
      merged.set(tool.name, tool);
    }
  }

  return [...merged.values()];
}

export async function buildSessionTools(extraToolNames: Iterable<string>): Promise<AgentTool[]> {
  const allTools = await loadCachedTools();
  const mainTools = await loadMainTools();
  return buildMergedTools(mainTools, allTools, extraToolNames);
}

export function buildSessionToolsSync(extraToolNames: Iterable<string>): AgentTool[] {
  // 런타임 중(inference phase)에는 최신 상태가 캐시에 이미 로드되어 있어야 합니다.
  return buildMergedTools(cachedMainTools, cachedAllTools, extraToolNames);
}

export function clearToolCache(): void {
  // 캐시를 사용하지 않으므로 비워둡니다.
}
