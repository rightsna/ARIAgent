import axios from "axios";
import { logger } from "../../infra/logger.js";
import { getTelegramConfig, saveTelegramConfig } from "../../repositories/channel_repository.js";
import { executeAgentRequest } from "../agent/index.js";

const TELEGRAM_API = "https://api.telegram.org/bot";

let pollingActive = false;
let pollingTimer: NodeJS.Timeout | undefined;
let lastUpdateId = 0;

// ─────────────────────────────────────────────
// Telegram API helpers
// ─────────────────────────────────────────────

async function telegramGet(token: string, method: string, params: Record<string, any> = {}): Promise<any> {
  const url = `${TELEGRAM_API}${token}/${method}`;
  const res = await axios.get(url, { params, timeout: 35000 });
  return res.data;
}

async function telegramPost(token: string, method: string, data: Record<string, any>): Promise<any> {
  const url = `${TELEGRAM_API}${token}/${method}`;
  const res = await axios.post(url, data, { timeout: 10000 });
  return res.data;
}

export async function sendTelegramMessage(token: string, chatId: number, text: string): Promise<void> {
  try {
    await telegramPost(token, "sendMessage", {
      chat_id: chatId,
      text,
      parse_mode: "Markdown",
    });
  } catch {
    // Markdown 파싱 실패 시 plain text로 재시도
    try {
      await telegramPost(token, "sendMessage", { chat_id: chatId, text });
    } catch (err: any) {
      logger.error(`[Telegram] sendMessage 실패 (chatId=${chatId}): ${err.message}`);
    }
  }
}

export async function testTelegramConnection(token: string): Promise<{ ok: boolean; botName?: string; message?: string }> {
  try {
    const res = await telegramGet(token, "getMe");
    if (res.ok) {
      return { ok: true, botName: res.result.username };
    }
    return { ok: false, message: res.description || "Unknown error" };
  } catch (err: any) {
    return { ok: false, message: err.message };
  }
}

// ─────────────────────────────────────────────
// Long-polling loop
// ─────────────────────────────────────────────

async function pollOnce(token: string, agentId?: string): Promise<void> {
  let updates: any[];
  try {
    const res = await telegramGet(token, "getUpdates", {
      offset: lastUpdateId + 1,
      timeout: 30,
      allowed_updates: ["message"],
    });
    if (!res.ok || !Array.isArray(res.result)) return;
    updates = res.result;
  } catch (err: any) {
    if (!err.message?.includes("ECONNRESET") && !err.code?.includes("ECONNABORTED")) {
      logger.warn(`[Telegram] getUpdates 오류: ${err.message}`);
    }
    return;
  }

  for (const update of updates) {
    lastUpdateId = Math.max(lastUpdateId, update.update_id);

    const msg = update.message;
    if (!msg || !msg.text) continue;

    const chatId: number = msg.chat.id;
    const text: string = msg.text;
    const fromName: string = msg.from?.first_name || msg.from?.username || "Unknown";

    logger.info(`[Telegram] 메세지 수신 from ${fromName} (chatId=${chatId}): ${text}`);

    // 에이전트에 메세지 전달 후 응답 대기
    try {
      const requestId = `telegram-${Date.now()}-${chatId}`;
      const result = await executeAgentRequest({
        message: text,
        requestId,
        agentId: agentId || undefined,
        source: "user",
        platform: "telegram",
        details: {
          chatId: String(chatId),
          fromName,
        },
        waitForCompletion: true,
      });

      const responseText = result.responseText || "✅ 처리 완료";

      // 읽어온 토큰으로 응답 전송
      const currentConfig = getTelegramConfig();
      if (currentConfig.enabled && currentConfig.botToken) {
        await sendTelegramMessage(currentConfig.botToken, chatId, responseText);
      }
    } catch (err: any) {
      logger.error(`[Telegram] 에이전트 처리 오류: ${err.message}`);
      try {
        await sendTelegramMessage(token, chatId, `❌ 오류가 발생했습니다: ${err.message}`);
      } catch {}
    }
  }
}

async function pollingLoop(): Promise<void> {
  while (pollingActive) {
    const config = getTelegramConfig();
    if (!config.enabled || !config.botToken) {
      // 설정이 비활성화되면 루프 종료
      pollingActive = false;
      break;
    }
    await pollOnce(config.botToken, config.agentId);
  }
  logger.info("[Telegram] Polling 종료");
}

// ─────────────────────────────────────────────
// Public lifecycle API
// ─────────────────────────────────────────────

export function startTelegramPolling(): void {
  const config = getTelegramConfig();
  if (!config.enabled || !config.botToken) {
    logger.info("[Telegram] 비활성화 상태 — polling 시작 안 함");
    return;
  }
  if (pollingActive) {
    logger.info("[Telegram] 이미 polling 중");
    return;
  }

  pollingActive = true;
  lastUpdateId = 0;
  logger.info("[Telegram] Polling 시작");
  void pollingLoop();
}

export function stopTelegramPolling(): void {
  if (!pollingActive) return;
  pollingActive = false;
  if (pollingTimer) {
    clearTimeout(pollingTimer);
    pollingTimer = undefined;
  }
  logger.info("[Telegram] Polling 중지 요청");
}

export function restartTelegramPolling(): void {
  stopTelegramPolling();
  // 현재 진행 중인 getUpdates 요청이 끝날 때까지 잠깐 대기 후 재시작
  pollingTimer = setTimeout(() => {
    pollingTimer = undefined;
    startTelegramPolling();
  }, 1000);
}

export function isTelegramPollingActive(): boolean {
  return pollingActive;
}
