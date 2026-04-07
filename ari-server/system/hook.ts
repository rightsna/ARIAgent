import { log } from "../infra/logger.js";

export function setupGlobalErrorHandlers() {
  process.on("uncaughtException", (error) => {
    log.error("[Global] Uncaught Exception:", error);
    // Note: We don't exit(1) here as it's an agent that should try to stay alive, 
    // but in many node apps, it's recommended to restart.
  });

  process.on("unhandledRejection", (reason, promise) => {
    log.error("[Global] Unhandled Rejection at:", promise, "Reason:", reason);
  });

  process.on("warning", (warning) => {
    log.warn("[Global] Node Warning:", warning.name, warning.message, warning.stack);
  });
}
