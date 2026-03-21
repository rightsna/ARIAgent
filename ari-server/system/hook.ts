import { log } from "../infra/logger";

export function setupGlobalErrorHandlers() {
  // 전역 예외 처리: uncaughtException
  process.on("uncaughtException", (error) => {
    log.error("잡히지 않은 예외:", error);
  });

  // 전역 예외 처리: unhandledRejection
  process.on("unhandledRejection", (reason: any, promise) => {
    log.error("처리되지 않은 프로미스 거부:", promise, "이유:", reason);
  });
}
