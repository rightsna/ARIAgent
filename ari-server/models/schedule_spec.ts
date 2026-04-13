/**
 * 사용자 친화적 스케줄 명세
 * cron 문자열 대신 구조화된 객체로 저장한다.
 */
export type ScheduleSpec =
  | { type: "every_n_minutes"; every: number }
  | { type: "every_n_hours"; every: number }
  | { type: "daily"; hour: number; minute: number }
  | { type: "weekly"; days: number[]; hour: number; minute: number }
  | { type: "monthly"; day: number; hour: number; minute: number }
  | { type: "yearly"; month: number; day: number; hour: number; minute: number };

const DAY_NAMES_KO = ["일", "월", "화", "수", "목", "금", "토"];

/** ScheduleSpec → 5-필드 cron 문자열 (node-schedule 용) */
export function scheduleSpecToCron(spec: ScheduleSpec): string {
  switch (spec.type) {
    case "every_n_minutes":
      return spec.every === 1 ? "* * * * *" : `*/${spec.every} * * * *`;
    case "every_n_hours":
      return spec.every === 1 ? "0 * * * *" : `0 */${spec.every} * * *`;
    case "daily":
      return `${spec.minute} ${spec.hour} * * *`;
    case "weekly":
      return `${spec.minute} ${spec.hour} * * ${spec.days.join(",")}`;
    case "monthly":
      return `${spec.minute} ${spec.hour} ${spec.day} * *`;
    case "yearly":
      return `${spec.minute} ${spec.hour} ${spec.day} ${spec.month} *`;
  }
}

/** ScheduleSpec → 한국어 설명 (UI 표시용) */
export function scheduleSpecToLabel(spec: ScheduleSpec): string {
  const pad = (n: number) => String(n).padStart(2, "0");

  switch (spec.type) {
    case "every_n_minutes":
      return spec.every === 1 ? "매분" : `${spec.every}분마다`;
    case "every_n_hours":
      return spec.every === 1 ? "매시간" : `${spec.every}시간마다`;
    case "daily":
      return `매일 ${spec.hour}:${pad(spec.minute)}`;
    case "weekly": {
      const dayStr = spec.days.map((d) => DAY_NAMES_KO[d] ?? d).join("·");
      return `매주 ${dayStr} ${spec.hour}:${pad(spec.minute)}`;
    }
    case "monthly":
      return `매월 ${spec.day}일 ${spec.hour}:${pad(spec.minute)}`;
    case "yearly":
      return `매년 ${spec.month}월 ${spec.day}일 ${spec.hour}:${pad(spec.minute)}`;
  }
}
