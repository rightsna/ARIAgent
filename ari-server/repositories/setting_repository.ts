import path from "path";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync, readTextSync } from "../infra/data.js";
import { Settings } from "../models/settings.js";
import { logger } from "../infra/logger.js";

const SETTINGS_FILE = path.join(DATA_DIR, "settings.json");

export function getSettingsText(defaultText: string): string {
  if (!fileExistsSync(SETTINGS_FILE)) {
    return defaultText;
  }
  return readTextSync(SETTINGS_FILE) || defaultText;
}

export function getSettings(defaultConfig: Settings): Settings {
  if (!fileExistsSync(SETTINGS_FILE)) {
    saveSettings(defaultConfig);
    return defaultConfig;
  }
  try {
    const configData = readJsonSync<any>(SETTINGS_FILE, null);
    if (!configData) return defaultConfig;
    return Settings.fromJson(configData);
  } catch (e) {
    logger.error(`설정 파일 파싱 오류, 디폴트값으로 초기화합니다:`, e);
    saveSettings(defaultConfig);
    return defaultConfig;
  }
}

export function saveSettings(settings: any): void {
  const existing = readJsonSync<any>(SETTINGS_FILE, {});
  const merged = { ...existing, ...settings };
  writeJsonSync(SETTINGS_FILE, merged);
}
