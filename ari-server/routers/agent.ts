import { router } from "../system/router.js";
import {
  abortAgent,
  clearAgentInstance,
  dropPendingResponse,
  submitAgentRequest,
} from "../services/agent/index.js";
import { Prompt } from "../infra/prompt.js";
import { UserSocketHandler } from "../system/ws.js";
import { logger } from "../infra/logger.js";
import { getAgentsConfig } from "../repositories/agent_repository.js";
import { AgentInfo, AgentsConfig } from "../models/agent.js";

function resolveAgentId(agentId?: string): string {
  return agentId || getAgentsConfig(new AgentsConfig()).selected || "default";
}

// /AGENT
router.on("/AGENT", async (ws, params) => {
  const {
    requestId = "",
    persona = "",
    avatarName = "",
    platform = "",
    agentId,
    source = "user", // 'user' | 'app' — 앱 소스일 경우 메시지 템플릿 래핑에 사용
    appId,
    type,
    details,
  } = params;

  let message = params.message as string;
  const currentAgentId = resolveAgentId(agentId as string | undefined);

  if (!message) {
    return ws.send("/AGENT", { ok: false, message: "message required" });
  }

  // 앱 소스인 경우 템플릿 적용 (동적 래핑)
  if (source === "app") {
    message = await Prompt.load("app_report.hbs", {
      appId: appId || ws.appId || "unknown",
      message,
      type: type || "info",
      detailsJson: JSON.stringify(details || {}),
    });
  }

  try {
    const result = await submitAgentRequest(
      message,
      new AgentInfo({
        id: currentAgentId,
        name: avatarName || (source === "app" ? "ARI" : "ARI"),
        persona,
        platform: platform || (source === "app" ? "system" : undefined),
        appId: appId || ws.appId || undefined,
      }),
      (progressMessage) => {
        // 프로그래스는 항상 전체 브로드캐스트
        UserSocketHandler.broadcast("/AGENT.PROGRESS", {
          ok: true,
          data: { requestId, message: progressMessage },
        });
      },
      {
        requestId,
        agentId: currentAgentId,
        originalMessage: params.message,
        appId: appId || ws.appId || undefined,
      },
    );

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
