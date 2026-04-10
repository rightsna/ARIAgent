import path from "path";
import { DATA_DIR, fileExistsSync, readJsonSync, writeJsonSync } from "../infra/data.js";
import { TelegramChannelConfig, ChannelType } from "../models/channel.js";

const CHANNELS_DIR = path.join(DATA_DIR, "channels");

function channelFilePath(type: ChannelType): string {
  return path.join(CHANNELS_DIR, `${type}.json`);
}

export function getTelegramConfig(): TelegramChannelConfig {
  const filePath = channelFilePath("telegram");
  if (!fileExistsSync(filePath)) {
    return defaultTelegramConfig();
  }
  const data = readJsonSync<TelegramChannelConfig>(filePath);
  return data ?? defaultTelegramConfig();
}

export function saveTelegramConfig(config: TelegramChannelConfig): void {
  writeJsonSync(channelFilePath("telegram"), config);
}

function defaultTelegramConfig(): TelegramChannelConfig {
  return {
    type: "telegram",
    enabled: false,
    botToken: "",
    allowedChatIds: [],
    agentId: undefined,
  };
}
