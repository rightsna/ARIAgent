import { logger } from "../infra/logger";
export class AgentProfile {
  id: string;
  name: string;
  imagePath: string;
  description: string;
  persona: string;

  constructor(data: any = {}) {
    this.id = data?.id || "default";
    this.name = data?.name || "ARI";
    this.imagePath = data?.imagePath || "";
    this.description = data?.description || "Default AI Assistant";
    this.persona = data?.persona || "";
  }

  static fromJson(jsonStr: string | any): AgentProfile {
    const data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
    return new AgentProfile(data || {});
  }
}

export class AgentsConfig {
  selected: string;
  agents: AgentProfile[];

  constructor(data: any = {}) {
    this.selected = data?.selected || "default";

    if (Array.isArray(data?.agents)) {
      this.agents = data.agents.map((a: any) => AgentProfile.fromJson(a));
    } else {
      this.agents = [];
    }
  }

  static fromJson(jsonStr: string | any): AgentsConfig {
    try {
      let data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;

      // 마이그레이션 로직: 구형 Map 포맷이거나, 배열 포맷인 경우를 감지하여 변환
      if (Array.isArray(data)) {
        data = { selected: "default", agents: data };
      } else if (data && !data.agents) {
        const agentsArray = Object.values(data).filter((a) => typeof a === "object");
        data = { selected: "default", agents: agentsArray };
      }

      const config = new AgentsConfig(data);

      // 아무 에이전트 정보가 없으면 기본 ARI 하나 추가
      if (config.agents.length === 0) {
        config.agents.push(new AgentProfile());
      }

      return config;
    } catch (e) {
      logger.error("AgentsConfig parsing error:", e);
      const defaultConfig = new AgentsConfig();
      defaultConfig.agents.push(new AgentProfile());
      return defaultConfig;
    }
  }
}
