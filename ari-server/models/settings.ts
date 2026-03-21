import { logger } from "../infra/logger";
export type AuthType = "apikey" | "oauth";

export class AIProviderConfig {
  provider: string;
  model: string;
  apiKey: string;
  authType: AuthType;

  constructor(data: any = {}) {
    this.provider = data?.provider || "";
    this.model = data?.model || "";
    this.apiKey = data?.apiKey || "";
    this.authType = data?.authType || "apikey";
  }
}

export class Settings {
  PORT: number;
  IS_PINNED: boolean;
  AVATAR_SIZE: string;
  PROVIDERS: AIProviderConfig[];
  OPENAI_API_KEY: string;
  OPENAI_MODEL: string;
  PROVIDER: string;

  constructor(data: any = {}) {
    this.PORT = data?.PORT || 29277;
    this.IS_PINNED = data?.IS_PINNED !== undefined ? data.IS_PINNED : true;
    this.AVATAR_SIZE = data?.AVATAR_SIZE || "medium";

    if (Array.isArray(data?.PROVIDERS)) {
      this.PROVIDERS = data.PROVIDERS.map((p: any) => new AIProviderConfig(p));
    } else {
      this.PROVIDERS = [];
    }

    this.OPENAI_API_KEY = data?.OPENAI_API_KEY || "";
    this.OPENAI_MODEL = data?.OPENAI_MODEL || "gpt-4o-mini";
    this.PROVIDER = data?.PROVIDER || "openai";
  }

  static fromJson(jsonStr: string | any): Settings {
    try {
      const data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
      return new Settings(data);
    } catch (e) {
      logger.error("Settings parsing error:", e);
      return new Settings();
    }
  }
}
