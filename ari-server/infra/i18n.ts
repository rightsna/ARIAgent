import { getSettings } from "../repositories/setting_repository.js";
import { Settings } from "../models/settings.js";

export type ServerLocale = "ko" | "en";

type TranslationValue = string | ((params?: Record<string, unknown>) => string);

const translations: Record<ServerLocale, Record<string, TranslationValue>> = {
  ko: {
    "tool.progress.read_skill": "스킬 문서를 읽는 중...",
    "tool.progress.execute_bash": "로컬 명령을 실행하는 중...",
    "tool.progress.sleep": "잠시 대기하는 중...",
    "tool.progress.update_core_memory": "핵심 메모리를 갱신하는 중...",
    "tool.progress.append_daily_memory": "일상 메모리를 기록하는 중...",
    "tool.progress.list_schedules": "등록된 일정을 확인하는 중...",
    "tool.progress.register_schedule": "일정을 등록하는 중...",
    "tool.progress.delete_schedule": "일정을 삭제하는 중...",
    "tool.progress.default": (params) => `${params?.toolName ?? "tool"} 실행 중...`,

    "tool.schedule.registered": (params) =>
      `✅ 반복 스케줄 등록 완료: "${params?.label ?? ""}" (${params?.cron ?? ""})`,
    "tool.schedule.one_off_registered": (params) =>
      `✅ 1회성 스케줄 등록 완료: "${params?.label ?? ""}" (${params?.delayMinutes ?? ""}분 뒤 예정)`,
    "tool.schedule.list.empty": "현재 활성 에이전트에 등록된 스케줄이 없습니다.",
    "tool.schedule.list.header": (params) =>
      `현재 등록된 스케줄 ${params?.count ?? 0}개입니다:`,
    "tool.schedule.delete.missing_params":
      "삭제할 스케줄의 taskId 또는 label 중 하나는 꼭 필요합니다.",
    "tool.schedule.delete.not_found": (params) =>
      `삭제할 스케줄을 찾지 못했습니다. (agent: ${params?.agentId ?? ""}, label: "${params?.label ?? ""}")`,
    "tool.schedule.delete.ambiguous": (params) =>
      `같은 이름의 스케줄이 ${params?.count ?? 0}개 있습니다. taskId를 지정해서 다시 요청해주세요.`,
    "tool.schedule.delete.success": (params) =>
      `✅ 스케줄 삭제 완료: ${params?.taskId ?? ""}`,
    "tool.schedule.delete.failed": (params) =>
      `삭제할 스케줄을 찾지 못했습니다: ${params?.taskId ?? ""}`,
  },
  en: {
    "tool.progress.read_skill": "Reading the skill document...",
    "tool.progress.execute_bash": "Running a local command...",
    "tool.progress.sleep": "Waiting briefly...",
    "tool.progress.update_core_memory": "Updating core memory...",
    "tool.progress.append_daily_memory": "Writing daily memory...",
    "tool.progress.list_schedules": "Checking registered schedules...",
    "tool.progress.register_schedule": "Registering the schedule...",
    "tool.progress.delete_schedule": "Deleting the schedule...",
    "tool.progress.default": (params) => `Running ${params?.toolName ?? "tool"}...`,

    "tool.schedule.registered": (params) =>
      `✅ Recurring schedule registered: "${params?.label ?? ""}" (${params?.cron ?? ""})`,
    "tool.schedule.one_off_registered": (params) =>
      `✅ One-off schedule registered: "${params?.label ?? ""}" (${params?.delayMinutes ?? ""} minutes later)`,
    "tool.schedule.list.empty": "There are no schedules registered for the active agent.",
    "tool.schedule.list.header": (params) =>
      `There are ${params?.count ?? 0} registered schedules:`,
    "tool.schedule.delete.missing_params":
      "Either taskId or label is required to delete a schedule.",
    "tool.schedule.delete.not_found": (params) =>
      `Could not find a matching schedule. (agent: ${params?.agentId ?? ""}, label: "${params?.label ?? ""}")`,
    "tool.schedule.delete.ambiguous": (params) =>
      `Found ${params?.count ?? 0} schedules with the same label. Please retry with a taskId.`,
    "tool.schedule.delete.success": (params) =>
      `✅ Schedule deleted: ${params?.taskId ?? ""}`,
    "tool.schedule.delete.failed": (params) =>
      `Could not find the schedule to delete: ${params?.taskId ?? ""}`,
  },
};

function normalizeLocale(value?: string | null): ServerLocale {
  if (!value) {
    return "ko";
  }

  const normalized = value.trim().toLowerCase();
  if (normalized.startsWith("en")) {
    return "en";
  }
  return "ko";
}

export function getServerLocale(): ServerLocale {
  const settings = getSettings(new Settings());
  return normalizeLocale(settings.LANGUAGE || process.env.ARI_LANGUAGE || process.env.LANG);
}

export function t(
  key: string,
  params?: Record<string, unknown>,
  locale: ServerLocale = getServerLocale(),
): string {
  const entry =
    translations[locale][key] ??
    translations.ko[key] ??
    translations.en[key];

  if (!entry) {
    return key;
  }

  return typeof entry === "function" ? entry(params) : entry;
}
