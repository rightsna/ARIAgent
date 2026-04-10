import { router } from "../system/router.js";
import { getTelegramConfig, saveTelegramConfig } from "../repositories/channel_repository.js";
import {
  testTelegramConnection,
  startTelegramPolling,
  stopTelegramPolling,
  restartTelegramPolling,
  isTelegramPollingActive,
} from "../services/channels/telegram_service.js";

/**
 * /CHANNEL.GET {type: "telegram"}
 * 채널 설정을 조회합니다.
 */
router.on("/CHANNEL.GET", async (ws, params) => {
  const { type } = params;

  if (type === "telegram") {
    const config = getTelegramConfig();
    // botToken은 마스킹하여 반환
    const masked = config.botToken
      ? config.botToken.replace(/:.+/, ":***")
      : "";
    ws.send("/CHANNEL.GET", {
      ok: true,
      data: {
        ...config,
        botToken: masked,
        isPolling: isTelegramPollingActive(),
      },
    });
    return;
  }

  ws.send("/CHANNEL.GET", { ok: false, message: `Unknown channel type: ${type}` });
});

/**
 * /CHANNEL.SAVE {type: "telegram", botToken, allowedChatIds, agentId}
 * 채널 설정을 저장하고 polling을 재시작합니다.
 */
router.on("/CHANNEL.SAVE", async (ws, params) => {
  const { type } = params;

  if (type === "telegram") {
    const existing = getTelegramConfig();

    const botToken =
      typeof params.botToken === "string" && params.botToken && !params.botToken.includes("***")
        ? params.botToken.trim()
        : existing.botToken;

    const allowedChatIds = Array.isArray(params.allowedChatIds)
      ? (params.allowedChatIds as any[]).map(Number).filter((n) => !isNaN(n))
      : existing.allowedChatIds;

    const agentId =
      typeof params.agentId === "string" ? params.agentId || undefined : existing.agentId;

    const updated = {
      ...existing,
      botToken,
      allowedChatIds,
      agentId,
    };

    saveTelegramConfig(updated);

    // 활성화 상태이면 polling 재시작
    if (updated.enabled) {
      restartTelegramPolling();
    }

    ws.send("/CHANNEL.SAVE", { ok: true, data: { type: "telegram" } });
    return;
  }

  ws.send("/CHANNEL.SAVE", { ok: false, message: `Unknown channel type: ${type}` });
});

/**
 * /CHANNEL.TOGGLE {type: "telegram", enabled: boolean}
 * 채널을 활성화/비활성화합니다.
 */
router.on("/CHANNEL.TOGGLE", async (ws, params) => {
  const { type, enabled } = params;

  if (type === "telegram") {
    const config = getTelegramConfig();

    if (!config.botToken) {
      ws.send("/CHANNEL.TOGGLE", {
        ok: false,
        message: "Bot Token을 먼저 설정해 주세요.",
      });
      return;
    }

    config.enabled = !!enabled;
    saveTelegramConfig(config);

    if (config.enabled) {
      restartTelegramPolling();
    } else {
      stopTelegramPolling();
    }

    ws.send("/CHANNEL.TOGGLE", {
      ok: true,
      data: { type: "telegram", enabled: config.enabled, isPolling: isTelegramPollingActive() },
    });
    return;
  }

  ws.send("/CHANNEL.TOGGLE", { ok: false, message: `Unknown channel type: ${type}` });
});

/**
 * /CHANNEL.TEST {type: "telegram"}
 * 봇 토큰이 유효한지 확인합니다.
 */
router.on("/CHANNEL.TEST", async (ws, params) => {
  const { type } = params;

  if (type === "telegram") {
    // 파라미터로 전달된 토큰 우선, 없으면 저장된 토큰 사용
    let token =
      typeof params.botToken === "string" && !params.botToken.includes("***")
        ? params.botToken.trim()
        : "";

    if (!token) {
      const config = getTelegramConfig();
      token = config.botToken;
    }

    if (!token) {
      ws.send("/CHANNEL.TEST", { ok: false, message: "Bot Token이 없습니다." });
      return;
    }

    const result = await testTelegramConnection(token);
    ws.send("/CHANNEL.TEST", {
      ok: result.ok,
      data: result.ok ? { botName: result.botName } : undefined,
      message: result.ok ? undefined : result.message,
    });
    return;
  }

  ws.send("/CHANNEL.TEST", { ok: false, message: `Unknown channel type: ${type}` });
});
