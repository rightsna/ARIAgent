import http from "http";
import { setMaxListeners } from "events";
import { WebSocketServer } from "ws";
import { getPluginsInfo, initAgent, getCurrentState } from "./services/agent";
import { getSettings } from "./repositories/setting_repository";
import { getAgentsConfig } from "./repositories/agent_repository";
import { AgentsConfig } from "./models/agent";
import { Settings } from "./models/settings";
import { UserSocketHandler } from "./system/ws";
import { setupGlobalErrorHandlers } from "./system/hook";

// 개별 라우터 등록 (side effect)
import "./routers/agent";
import "./routers/agents";
import "./routers/config";
import "./routers/task";
import "./routers/memory";
import "./routers/oauth";
import "./routers/app_sync";
import { logger } from "./infra/logger";
import { runScheduledTask } from "./jobs/run_task";

/**
 * 상태 초기화
 */
async function initState(config: any): Promise<void> {
  // 에이전트 설정 로드 (마이그레이션 트리거)
  getAgentsConfig(new AgentsConfig());

  // Agent 서비스 초기화 (state 포함)
  await initAgent(config.PROVIDERS && config.PROVIDERS.length > 0 ? config.PROVIDERS : undefined);
}

/**
 * HTTP 서버 생성
 */
function createHttpServer(): http.Server {
  return http.createServer((req, res) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
    } else {
      res.writeHead(404);
      res.end();
    }
  });
}

/**
 * WebSocket 서버 설정
 */
function setupWebSocket(server: http.Server): void {
  const wss = new WebSocketServer({ server });
  wss.on("connection", (ws, req) => {
    UserSocketHandler.onConnect(ws, req);
  });
}

/**
 * 메인 엔트리 포인트
 */
async function main() {
  const runTaskFlagIndex = process.argv.indexOf("--run-task");
  if (runTaskFlagIndex >= 0) {
    const taskId = process.argv[runTaskFlagIndex + 1];
    if (!taskId) {
      throw new Error("Missing task id after --run-task");
    }

    await runScheduledTask(taskId);
    return;
  }

  setMaxListeners(200);

  // 전역 에러 핸들러 설정
  setupGlobalErrorHandlers();

  // 1. 설정 로드
  const config = getSettings(new Settings()) || {};
  const envPort = Number.parseInt(process.env.PORT || "", 10);
  const port = Number.isFinite(envPort) && envPort > 0 ? envPort : config.PORT || 29277;

  // 2. 초기화 (Agent & State)
  await initState(config);
  const state = getCurrentState();

  // 3. 플래그인 정보 확인
  const plugins = await getPluginsInfo();

  logger.info(`\n╔═══════════════════════════════════════╗`);
  logger.info(`║ 🤖 ARI Server v${(process.env.VERSION || "0.0.0").padEnd(14)} ║`);
  logger.info(`╠═══════════════════════════════════════╣`);
  logger.info(`║  🔌 WebSocket ws://localhost:${port.toString().padEnd(7)} ║`);
  logger.info(`║  📡 API: ${state.currentApiKey ? "Connected" : "Not Set  "}              ║`);
  logger.info(`║  🧠 Model: ${state.currentModel.padEnd(23)} ║`);
  logger.info(`║  ⚙️  Engine: pi-agent-core             ║`);
  logger.info(`║  🔧 Tools: ${plugins.tools.length.toString().padEnd(3)} Skills: ${plugins.skills.length.toString().padEnd(3)}           ║`);
  logger.info(`╚═══════════════════════════════════════╝\n`);

  // 4. 서버 시작
  const server = createHttpServer();
  setupWebSocket(server);

  server.listen(port, "127.0.0.1", () => {
    logger.info(`🛰️ Server listening on 127.0.0.1:${port}`);
  });

  // 5. WebSocket keep-alive 시작
  UserSocketHandler.startKeepAlive();
}

main().catch((err) => {
  logger.error("❌ 에이전트 시작 중 오류:", err);
});
