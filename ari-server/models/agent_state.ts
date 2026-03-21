import { AIProviderConfig } from "./settings";

/**
 * 서버의 현재 에이전트 및 연동 상태를 정의하는 모델
 */
export interface AgentState {
  currentApiKey: string;
  currentModel: string;
  currentProvider: string;
  providers: AIProviderConfig[];
}

/**
 * 초기 기본 상태 객체를 생성합니다.
 */
export function createDefaultState(): AgentState {
  return {
    currentApiKey: "",
    currentModel: "gpt-4o-mini",
    currentProvider: "openai",
    providers: [],
  };
}
