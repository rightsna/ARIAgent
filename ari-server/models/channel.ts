export interface TelegramChannelConfig {
  type: "telegram";
  enabled: boolean;
  botToken: string;
  allowedChatIds: number[]; // 빈 배열이면 모든 채팅 허용
  agentId?: string; // 어느 에이전트로 라우팅할지 (없으면 default)
}

export type ChannelConfig = TelegramChannelConfig;

export type ChannelType = "telegram";
