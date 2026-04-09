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
import { loadAllApps } from "../skills/index.js";

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
  const normalizedPlatform =
    typeof platform === "string" ? platform.trim() : "";
  let resolvedAppId =
    (typeof appId === "string" ? appId.trim() : "") ||
    ws.appId ||
    undefined;

  if (!message) {
    return ws.send("/AGENT", { ok: false, message: "message required" });
  }

  if (!resolvedAppId && normalizedPlatform) {
    const apps = await loadAllApps();
    if (apps.some((entry) => entry.name === normalizedPlatform)) {
      resolvedAppId = normalizedPlatform;
    }
  }

  // 앱 소스인 경우 템플릿 적용 (동적 래핑)
  if (source === "app") {
    message = await Prompt.load("app_report.hbs", {
      appId: resolvedAppId || "unknown",
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
        platform: normalizedPlatform || (source === "app" ? "system" : undefined),
        appId: resolvedAppId,
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
        appId: resolvedAppId,
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
