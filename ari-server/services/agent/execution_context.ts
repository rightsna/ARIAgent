import { AsyncLocalStorage } from "async_hooks";

export type AgentExecutionContext = {
  agentId: string;
  appId?: string;
};

const executionContextStore = new AsyncLocalStorage<AgentExecutionContext>();

export function runWithExecutionContext<T>(
  context: AgentExecutionContext,
  callback: () => Promise<T>,
): Promise<T> {
  return executionContextStore.run(context, callback);
}

export function getExecutionContext(): AgentExecutionContext | undefined {
  return executionContextStore.getStore();
}
