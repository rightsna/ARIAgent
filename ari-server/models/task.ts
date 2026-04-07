/**
 * 스케줄링된 작업 정보를 정의하는 모델
 */
export class Task {
  id: string; // 고유 ID (Timestamp 등)
  prompt: string; // 에이전트에게 전달할 명령 내용
  cron: string; // 실행 주기 (Cron 표현식)
  label: string; // 사용자에게 보여줄 이름
  agentId?: string; // 어떤 아바타의 스케줄인지 기록 (기본: default)
  appId?: string;   // 어떤 앱에서 생성한 스케줄인지 기록
  isOneOff?: boolean; // 1회성 스케줄 여부
  scheduledFor?: string; // 1회성 스케줄의 절대 실행 시각
  enabled: boolean; // 활성화 여부
  createdAt: string; // 생성 일시
  lastRunAt?: string; // 마지막 실행 시각
  lastResult?: string; // 마지막 실행 결과
  lastError?: string; // 마지막 실행 오류

  constructor(data: any = {}) {
    this.id = data?.id || Date.now().toString();
    this.prompt = data?.prompt || "";
    this.cron = data?.cron || "";
    this.label = data?.label || "";
    this.agentId = data?.agentId || "default";
    this.appId = data?.appId;
    this.isOneOff = data?.isOneOff !== undefined ? data.isOneOff : false;
    this.scheduledFor = data?.scheduledFor;
    this.enabled = data?.enabled !== undefined ? data.enabled : true;
    this.createdAt = data?.createdAt || new Date().toISOString();
    this.lastRunAt = data?.lastRunAt;
    this.lastResult = data?.lastResult;
    this.lastError = data?.lastError;
  }

  static fromJson(jsonStr: string | any): Task {
    try {
      const data = typeof jsonStr === "string" ? JSON.parse(jsonStr) : jsonStr;
      return new Task(data || {});
    } catch {
      return new Task();
    }
  }
}
