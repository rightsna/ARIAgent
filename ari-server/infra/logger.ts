import moment from "moment";
import winston, { Logger } from "winston";
import winstonDaily from "winston-daily-rotate-file";
import fs from "fs";
import os from "os";
import path from "path";
import { EventEmitter } from "events";
import TransportStream from "winston-transport";

export const logEventEmitter = new EventEmitter();

const { combine, timestamp, label, printf, colorize, errors } = winston.format;

// 콘솔 로그 옵션
const consoleOptions = {
  level: process.env.MODE === "production" ? "warn" : "debug",
  handleExceptions: false,
  json: false,
};

// 타임스탬프 포맷 함수
const timeStampFormat = (): string => moment().format("YYYY-MM-DD HH:mm:ss.SSS ZZ");

// 로그 출력 포맷 정의
const myFormat = printf(({ level, message, label, timestamp, stack, ...metadata }) => {
  let logStr = `${timestamp} [${label}] ${level}: ${message}`;
  if (stack) {
    logStr += `\n${stack}`;
  } else if (metadata && Object.keys(metadata).length > 0) {
    // metadata에 정보가 있으면 (예: Error가 필드가 아닌 메타로 넘어왔을 때) JSON으로 추가 표시
    // 다만 timestamp, label 등 가공 전 필드도 올 수 있으므로 필터링 필요할 수 있음
    // winston 3.x에서는 metadata에 이미 가공된 필드들이 섞여있을 수 있음
    const metaStr = JSON.stringify(metadata);
    if (metaStr !== "{}") {
      logStr += ` ${metaStr}`;
    }
  }
  return logStr;
});

let currentLogDir = path.join(os.homedir(), ".ari-agent", "logs");
let currentConsoleTransport: TransportStream | null = null;

function disableConsoleTransport() {
  if (currentConsoleTransport && "silent" in currentConsoleTransport) {
    (currentConsoleTransport as TransportStream & { silent: boolean }).silent = true;
  }
}

function handleConsoleStreamError(error: NodeJS.ErrnoException) {
  if (error?.code === "EPIPE") {
    disableConsoleTransport();
  }
}

process.stdout?.on?.("error", handleConsoleStreamError);
process.stderr?.on?.("error", handleConsoleStreamError);

function createLoggerOptions(logDir: string) {
  const consoleDir = path.join(logDir, "console");
  const exceptionDir = path.join(logDir, "exception");

  try {
    fs.mkdirSync(consoleDir, { recursive: true });
    fs.mkdirSync(exceptionDir, { recursive: true });
  } catch {
    // 파일 로그 경로 생성 실패 시에도 콘솔 로깅은 유지
  }

  currentConsoleTransport = new winston.transports.Console({
    ...consoleOptions,
    format: combine(colorize(), myFormat),
  });

  return {
    format: combine(errors({ stack: true }), label({ label: "was" }), timestamp({ format: timeStampFormat }), myFormat),
    transports: [
      new winstonDaily({
        dirname: consoleDir,
        filename: `%DATE%.log`,
        datePattern: "yyyy-MM-DD",
        maxFiles: 1000,
        level: process.env.MODE === "production" ? "info" : "debug",
        json: false,
      }),
      currentConsoleTransport,
    ],
    exceptionHandlers: [
      new winstonDaily({
        dirname: exceptionDir,
        filename: `%DATE%_exception.log`,
        datePattern: "yyyy-MM-DD",
        maxFiles: 1000,
        json: false,
      }),
    ],
    rejectionHandlers: [
      new winstonDaily({
        dirname: exceptionDir,
        filename: `%DATE%_rejection.log`,
        datePattern: "yyyy-MM-DD",
        maxFiles: 1000,
        json: false,
      }),
    ],
    exitOnError: false,
  };
}

// winston 로거 생성
export const logger: Logger = winston.createLogger(createLoggerOptions(currentLogDir));

// 로거 이벤트를 EventEmitter로 브로드캐스트
logger.on("data", (info) => {
  logEventEmitter.emit("log", info);
});

export function setupPath(logDir: string = path.join(os.homedir(), ".ari-agent", "logs")): void {
  currentLogDir = logDir;
  logger.configure(createLoggerOptions(currentLogDir));
}

// 로그 네임스페이스 정의
export namespace log {
  export const info = (...messages: any[]): void => {
    logger.info(messages.join(" "));
  };
  export const report = (...messages: any[]): void => {
    logger.info(messages.join(" "));
  };
  export const warn = (...messages: any[]): void => {
    logger.warn(messages.join(" "));
  };
  export const error = (...messages: any[]): void => {
    const formattedMessages = messages.map((m) => {
      if (m instanceof Error) {
        return m.stack || m.message;
      }
      if (typeof m === "object") {
        try {
          return JSON.stringify(m, null, 2);
        } catch {
          return String(m);
        }
      }
      return String(m);
    });
    logger.error(formattedMessages.join(" "));
  };
  export const log = (...messages: any[]): void => {
    console.log(...messages);
  };
}
