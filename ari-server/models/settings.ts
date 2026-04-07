import { AgentTool } from "@mariozechner/pi-agent-core";
import { SkillDefinition } from "../skills/index.js";
import { logger } from "../infra/logger.js";
export type AuthType = "apikey" | "oauth";

export interface AvailablePlugins {
  tools: AgentTool[];
  skills: SkillDefinition[];
}

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

export class AIProviders {
  providers: AIProviderConfig[];
  availableProviders: AIProviderConfig[];
  currentModel: string;
  currentProvider: string;

  constructor(data: any = {}) {
    this.providers = this.normalizeProviders(data?.providers ?? data?.PROVIDERS);
    this.availableProviders = this.normalizeProviders(
      data?.availableProviders,
    );

    const initialProvider =
      this.findProvider(
        data?.currentProvider ?? data?.PROVIDER,
        data?.currentModel ?? data?.OPENAI_MODEL,
      ) ??
      this.providers.find((provider) => !!provider.apiKey) ??
      this.providers[0];

    this.currentModel =
      data?.currentModel ?? initialProvider?.model ?? data?.OPENAI_MODEL ?? "gpt-4o-mini";
    this.currentProvider =
      data?.currentProvider ?? initialProvider?.provider ?? data?.PROVIDER ?? "openai";
  }

  setProviders(providers: AIProviderConfig[]): void {
    this.providers = this.normalizeProviders(providers);
    this.availableProviders = [];
    const current =
      this.activeConfig ??
      this.providers.find((provider) => !!provider.apiKey) ??
      this.providers[0];

    if (current) {
      this.currentProvider = current.provider;
      this.currentModel = current.model;
      return;
    }

    this.currentModel = "gpt-4o-mini";
    this.currentProvider = "openai";
  }

  setAvailableProviders(providers: AIProviderConfig[]): void {
    this.availableProviders = this.normalizeProviders(providers);
  }

  get activeConfig(): AIProviderConfig | null {
    return (
      this.findProvider(this.currentProvider, this.currentModel) ??
      this.findProvider(this.currentProvider) ??
      this.providers[0] ??
      null
    );
  }

  get startingAvailableProviderIndex(): number {
    const exactMatchIndex = this.availableProviders.findIndex(
      (provider) =>
        provider.provider === this.currentProvider &&
        provider.model === this.currentModel,
    );
    if (exactMatchIndex !== -1) {
      return exactMatchIndex;
    }

    const providerMatchIndex = this.availableProviders.findIndex(
      (provider) => provider.provider === this.currentProvider,
    );
    if (providerMatchIndex !== -1) {
      return providerMatchIndex;
    }

    return 0;
  }

  get currentApiKey(): string {
    return this.activeConfig?.apiKey ?? "";
  }

  set currentApiKey(apiKey: string) {
    const activeConfig = this.activeConfig;
    if (activeConfig) {
      activeConfig.apiKey = apiKey;
      return;
    }

    const fallbackProvider = new AIProviderConfig({
      provider: this.currentProvider,
      model: this.currentModel,
      apiKey,
      authType: "apikey",
    });
    this.providers = [fallbackProvider];
  }

  private normalizeProviders(providers: any): AIProviderConfig[] {
    if (!Array.isArray(providers)) {
      return [];
    }

    return providers.map((provider: any) =>
      provider instanceof AIProviderConfig
        ? provider
        : new AIProviderConfig(provider),
    );
  }

  private findProvider(providerName?: string, modelName?: string): AIProviderConfig | undefined {
    if (providerName && modelName) {
      const exactMatch = this.providers.find(
        (provider) =>
          provider.provider === providerName && provider.model === modelName,
      );
      if (exactMatch) {
        return exactMatch;
      }
    }

    if (providerName) {
      return this.providers.find((provider) => provider.provider === providerName);
    }

    if (modelName) {
      return this.providers.find((provider) => provider.model === modelName);
    }

    return undefined;
  }
}

export class Settings {
  PORT: number;
  IS_PINNED: boolean;
  AVATAR_SIZE: string;
  LANGUAGE: string;
  PROVIDERS: AIProviderConfig[];
  OPENAI_API_KEY: string;
  OPENAI_MODEL: string;
  PROVIDER: string;

  constructor(data: any = {}) {
    this.PORT = data?.PORT || 29277;
    this.IS_PINNED = data?.IS_PINNED !== undefined ? data.IS_PINNED : true;
    this.AVATAR_SIZE = data?.AVATAR_SIZE || "medium";
    this.LANGUAGE = data?.LANGUAGE || "ko";

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
