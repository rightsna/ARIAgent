import { router } from "../system/router.js";
import { readUsageSummary } from "../repositories/usage_repository.js";

/**
 * /USAGE.GET {agentId, startDate?, endDate?}
 * 특정 에이전트의 토큰 사용량 요약을 조회합니다.
 *
 * 응답:
 * {
 *   ok: true,
 *   data: {
 *     total: { promptTokens, completionTokens, totalTokens },
 *     byModel: { [modelName]: { promptTokens, completionTokens, totalTokens } },
 *     byDay: [ { date, promptTokens, completionTokens, totalTokens } ]
 *   }
 * }
 */
router.on("/USAGE.GET", async (ws, params) => {
  const { agentId, startDate, endDate } = params;

  if (!agentId) {
    return ws.send("/USAGE.GET", { ok: false, message: "agentId required" });
  }

  try {
    const summary = readUsageSummary(
      agentId as string,
      startDate as string | undefined,
      endDate as string | undefined,
    );
    ws.send("/USAGE.GET", { ok: true, data: summary });
  } catch (err: any) {
    ws.send("/USAGE.GET", { ok: false, message: err.message });
  }
});
