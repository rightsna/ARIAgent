import { Agent } from "@mariozechner/pi-agent-core";

export interface AgentToolResultSummary {
  toolName: string;
  details: any;
  isError: boolean;
}

export interface ChatWithAgentResult {
  responseText: string;
  aborted?: boolean;
}

export interface PendingAgentResponse {
  requestId: string;
  agentId: string;
  originalMessage: string;
  appId?: string;
  source?: "user" | "app" | "task";
}

export interface AgentPassResult {
  responseText: string;
  toolResults: AgentToolResultSummary[];
  finalAgent: Agent | null;
  lastError: Error | null;
  success: boolean;
}
