export type AgentRuntimeStatus = "idle" | "working";

export type AgentRuntimeState = {
  agentId: string;
  status: AgentRuntimeStatus;
  requestId?: string;
  source?: "user" | "app" | "task";
  updatedAt: string;
};

const runtimeStates = new Map<string, AgentRuntimeState>();

export function markAgentWorking(params: {
  agentId: string;
  requestId?: string;
  source?: "user" | "app" | "task";
}): AgentRuntimeState {
  const next: AgentRuntimeState = {
    agentId: params.agentId,
    status: "working",
    requestId: params.requestId,
    source: params.source,
    updatedAt: new Date().toISOString(),
  };
  runtimeStates.set(params.agentId, next);
  return next;
}

export function markAgentIdle(agentId: string): AgentRuntimeState {
  const next: AgentRuntimeState = {
    agentId,
    status: "idle",
    updatedAt: new Date().toISOString(),
  };
  runtimeStates.set(agentId, next);
  return next;
}

export function getAllAgentRuntimeStates(): AgentRuntimeState[] {
  return Array.from(runtimeStates.values());
}
