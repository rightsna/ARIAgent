import path from "path";
import { DATA_DIR, writeTextSync, unlinkSyncSafe } from "../infra/data";

const CRON_TMP_FILE = path.join(DATA_DIR, ".crontab_tmp");
const CRON_LOG_FILE = path.join(DATA_DIR, "cron.log");

export function getCronTempFilePath(): string {
  return CRON_TMP_FILE;
}

export function writeCronTempConfig(content: string): void {
  writeTextSync(CRON_TMP_FILE, content);
}

export function removeCronTempConfig(): void {
  unlinkSyncSafe(CRON_TMP_FILE);
}

export function getCronLogFilePath(): string {
  return CRON_LOG_FILE;
}
