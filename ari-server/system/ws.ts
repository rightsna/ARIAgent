import { DateTime } from "luxon";
import WebSocket from "ws";
import { logger, log } from "../infra/logger";
import { router } from "./router";

// UserSocket 인터페이스를 확장하여 명시적으로 사용
export interface UserSocket extends WebSocket {
  isAlive: boolean;
  uuid: string;
  appId?: string; // 연결된 앱의 ID
  sysInfo: Record<string, any>;

  // 프로젝트 프로토콜 기반 전송으로 통합 (Polymorphic)
  send(cmd: string, data: any): void;
  send(data: any, cb?: (err?: Error) => void): void;
}

export namespace UserSocketHandler {
  let keepAlive: NodeJS.Timeout;
  const clients: UserSocket[] = [];

  export const startKeepAlive = () => {
    const now = DateTime.local();
    log.report(`VER = ${process.env.VERSION}`);
    log.report(`SERVER MODE = ${process.env.MODE}`);
    log.report(
      `TIME = ${now.toFormat("yyyy-LL-dd HH:mm:ss.SSS")} (${Math.floor(now.toSeconds())})`,
    );
    log.report(
      `TIMEZONE = ${DateTime.now().setZone("Asia/Seoul").toFormat("yyyy-LL-dd HH:mm:ss.SSS ZZZ")}`,
    );

    const timeout = Number(process.env.KEEP_ALIVE_TIMEOUT) || 30000;
    keepAlive = setInterval(() => {
      clients.forEach((ws) => {
        if (!ws.isAlive) {
          ws.terminate();
          return;
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, timeout);
  };

  export const onConnect = (socket: WebSocket, req: any) => {
    const ws = socket as UserSocket;

    const getUniqueID = (): string => {
      const s4 = () =>
        Math.floor((1 + Math.random()) * 0x10000)
          .toString(16)
          .substring(1);
      return `${s4()}${s4()}-${s4()}`;
    };

    const rawSend = ws.send.bind(ws);

    // Polyfill send to support (cmd, data) and (raw)
    ws.send = function (arg1: any, arg2?: any): void {
      if (typeof arg1 === "string" && arg2 !== undefined) {
        const result_str = `${arg1} ${JSON.stringify(arg2)}`;
        rawSend(result_str);
      } else {
        rawSend(arg1, arg2);
      }
    };

    ws.on("pong", () => {
      ws.isAlive = true;
    });

    ws.on("message", async (data: WebSocket.Data) => {
      const dataStr = data.toString();
      if (!dataStr.includes("/APP.REGISTER")) {
        logger.debug(`📥 Inbound: ${dataStr.substring(0, 100)}`);
      }
      ws.isAlive = true;
      try {
        await router.parse(ws, dataStr);
      } catch (err: any) {
        logger.error(`Error parsing message: ${err}`);
      }
    });

    ws.on("close", () => {
      logger.info(
        `closed uuid = ${ws.uuid}${ws.appId ? ` (${ws.appId})` : ""}`,
      );
      const index = clients.findIndex((item) => item.uuid === ws.uuid);
      if (index !== -1) {
        clients.splice(index, 1);
      }
      // Notify all clients if an app socket was closed
      if (ws.appId) {
        broadcastConnectedApps();
      }
    });

    ws.on("error", (err) => {
      logger.error(`error = ${ws.uuid}: ${err.message}`);
      if (ws.appId) {
        broadcastConnectedApps();
      }
    });

    ws.isAlive = true;
    ws.uuid = getUniqueID();
    clients.push(ws);

    const greetingParams = {
      ver: process.env.VERSION,
      dt: DateTime.local().toFormat("yyyy-LL-dd HH:mm"),
      mode: process.env.MODE,
    };
    ws.send("/GREETING", greetingParams);
    logger.info(`CLIENT connected = ${clients.length} (uuid: ${ws.uuid})`);
  };

  export const broadcast = (cmd: string, data: any, targetAppIds?: string[]) => {
    clients.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        if (targetAppIds && targetAppIds.length > 0) {
          // 특정 앱 아이디가 지정된 경우 필터링
          if (ws.appId && targetAppIds.includes(ws.appId)) {
            ws.send(cmd, data);
          }
        } else {
          // 지정되지 않은 경우 전체 브로드캐스트
          ws.send(cmd, data);
        }
      }
    });
  };

  /**
   * 실시간 연결된 앱 목록을 모든 클라이언트에게 전송합니다.
   */
  export const broadcastConnectedApps = () => {
    const connectedIds = getConnectedAppIds();
    broadcast("/CONNECTED_APPS_CHANGED", { connectedIds });
  };

  export const commandApp = async (
    appId: string,
    command: string,
    params: any = {},
    timeoutMs = 10000,
  ): Promise<any> => {
    const target = clients.find((c) => c.appId === appId);
    if (!target || target.readyState !== WebSocket.OPEN) {
      throw new Error(`App '${appId}' is not connected.`);
    }

    const requestId = Math.random().toString(36).substring(7);

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        router.off(`/APP.COMMAND_RESPONSE:${requestId}`);
        reject(
          new Error(
            `Command '${command}' to '${appId}' timed out (${timeoutMs}ms)`,
          ),
        );
      }, timeoutMs);

      router.once(`/APP.COMMAND_RESPONSE:${requestId}`, (ws, data) => {
        clearTimeout(timeout);
        resolve(data.result);
      });

      target.send("/APP.COMMAND", { appId, command, requestId, params });
      logger.debug(
        `[WS] Sent Command to ${appId}: ${command} (req:${requestId})`,
      );
    });
  };

  export const isAppConnected = (appId: string): boolean => {
    return clients.some(
      (c) =>
        (c.appId === appId ||
          c.appId?.replace("_", "") === appId.replace("_", "")) &&
        c.readyState === WebSocket.OPEN,
    );
  };

  export const getConnectedAppIds = (): string[] => {
    return clients
      .filter((c) => c && c.readyState === 1 && c.appId) // 1 === WebSocket.OPEN
      .map((c) => c.appId!);
  };
}
