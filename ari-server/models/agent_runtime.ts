import { Agent, AgentTool } from "@mariozechner/pi-agent-core";
import { SkillDefinition } from "../skills";

export interface PluginInfo {
  tools: AgentTool[];
  skills: SkillDefinition[];
}

export interface AgentToolResultSummary {
  toolName: string;
  details: any;
  isError: boolean;
}

export interface ChatWithAgentResult {
  responseText: string;
}

export interface AgentRuntimeContext {
  avatarName?: string;
  platform?: string;
}

export interface AgentPassResult {
  responseText: string;
  toolResults: AgentToolResultSummary[];
  finalAgent: Agent | null;
  lastError: Error | null;
  success: boolean;
}
