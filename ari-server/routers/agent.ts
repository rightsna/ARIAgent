import { router } from "../system/router.js";
import {
  abortAgent,
  clearAgentInstance,
  dropPendingResponse,
  executeAgentRequest,
} from "../services/agent/index.js";
import { logger } from "../infra/logger.js";
import { getAgentsConfig } from "../repositories/agent_repository.js";
import { AgentsConfig } from "../models/agent.js";

function resolveAgentId(agentId?: string): string {
  return agentId || getAgentsConfig(new AgentsConfig()).selected || "default";
}

// /AGENT
router.on("/AGENT", async (ws, params) => {
  const requestId = (params.requestId as string | undefined) || "";
  const currentAgentId = resolveAgentId(params.agentId as string | undefined);

  try {
    const result = await executeAgentRequest({
      message: params.message as string,
      requestId,
      persona: (params.persona as string | undefined) || "",
      avatarName: (params.avatarName as string | undefined) || "",
      platform: (params.platform as string | undefined) || "",
      agentId: currentAgentId,
      source: (params.source as "user" | "app" | "task" | undefined) || "user",
      appId: params.appId as string | undefined,
      socketAppId: ws.appId,
      type: params.type as string | undefined,
      details:
        params.details && typeof params.details === "object" && !Array.isArray(params.details)
          ? (params.details as Record<string, unknown>)
          : undefined,
    });

    if (result.status === "cancelled") {
      dropPendingResponse(currentAgentId, requestId);
      logger.info(`[/AGENT] Request cancelled by user: ${requestId}`);
      ws.send("/AGENT", { ok: true, data: { status: "cancelled", requestId } });
      return;
    }

    ws.send("/AGENT", { ok: true, data: { status: result.status, requestId } });
  } catch (err: any) {
    dropPendingResponse(currentAgentId, requestId);
    ws.send("/AGENT", { ok: false, message: err.message });
  }
});

// /AGENT.CANCEL
router.on("/AGENT.CANCEL", async (ws, params) => {
  const agentId = resolveAgentId(params.agentId as string | undefined);

  abortAgent(agentId);
  ws.send("/AGENT.CANCEL", { ok: true, data: { agentId } });
});

// /AGENT.RESET
router.on("/AGENT.RESET", async (ws, params) => {
  const agentId = resolveAgentId(params.agentId as string | undefined);

  clearAgentInstance(agentId);
  ws.send("/AGENT.RESET", { ok: true, data: { agentId } });
});
