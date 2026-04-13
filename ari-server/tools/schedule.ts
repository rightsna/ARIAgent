import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { handleDeleteTaskWs, registerScheduledTask } from "../services/task.js";
import { getExecutionContext } from "../services/agent/execution_context.js";
import { logger } from "../infra/logger.js";
import { t } from "../infra/i18n.js";
import { getTasks } from "../repositories/task_repository.js";
import { type ScheduleSpec, scheduleSpecToLabel } from "../models/schedule_spec.js";

function resolveExecutionContext(): { agentId: string; appId?: string } {
  const context = getExecutionContext();
  return {
    agentId: context?.agentId || "default",
    appId: context?.appId,
  };
}

export const registerScheduleTool: AgentTool = {
  name: "register_schedule",
  label: "스케줄 등록",
  description: "반복 작업 또는 1회성 알림을 스케줄러에 등록한다. 1회성은 scheduleType을 'once'로 지정하고 startAt에 실행 일시를 넣는다.",
  parameters: Type.Object({
    scheduleType: Type.String({
      description:
        "스케줄 유형. 반드시 다음 중 하나: 'once'(1회성), 'every_n_minutes'(N분마다), 'every_n_hours'(N시간마다), 'daily'(매일), 'weekly'(매주 특정 요일), 'monthly'(매월 특정 일), 'yearly'(매년 특정 날짜)",
    }),
    every: Type.Optional(
      Type.Number({
        description: "every_n_minutes / every_n_hours 유형에서 N 값 (예: 5분마다 → 5)",
      }),
    ),
    hour: Type.Optional(
      Type.Number({
        description: "daily / weekly / monthly 유형에서 실행 시각의 '시' (0-23)",
      }),
    ),
    minute: Type.Optional(
      Type.Number({
        description: "daily / weekly / monthly 유형에서 실행 시각의 '분' (0-59)",
      }),
    ),
    days: Type.Optional(
      Type.Array(Type.Number(), {
        description: "weekly 유형 실행 요일 배열. 0=일, 1=월, 2=화, 3=수, 4=목, 5=금, 6=토 (예: 월·수·금 → [1,3,5])",
      }),
    ),
    day: Type.Optional(
      Type.Number({
        description: "monthly / yearly 유형 실행 일 (1-31, 예: 15일 → 15)",
      }),
    ),
    month: Type.Optional(
      Type.Number({
        description: "yearly 유형 실행 월 (1-12, 예: 3월 → 3)",
      }),
    ),
    prompt: Type.String({ description: "스케줄 시간에 LLM이 실행할 프롬프트" }),
    label: Type.String({ description: "작업 이름 (짧게, 예: '뉴스 브리핑')" }),
    startAt: Type.Optional(Type.String({
      description: "스케줄 시작 일시 (ISO 8601). 'once' 타입에서는 실행 일시. 반복 타입에서는 이 시각 이후부터 실행. 생략 시 즉시 시작. 예: '2026-05-01T09:00:00+09:00'",
    })),
    endAt: Type.Optional(Type.String({
      description: "스케줄 종료 일시 (ISO 8601). 반복 타입 전용. 이 시각 이후에는 실행 안 함. 생략 시 무한 반복. 예: '2026-06-30T23:59:59+09:00'",
    })),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { scheduleType, every, hour, minute, days, day, month, prompt, label, startAt, endAt } = params as {
      scheduleType: string;
      every?: number;
      hour?: number;
      minute?: number;
      days?: number[];
      day?: number;
      month?: number;
      prompt: string;
      label: string;
      startAt?: string;
      endAt?: string;
    };
    const { agentId, appId } = resolveExecutionContext();

    // ── 1회성 ──────────────────────────────────────────────────────
    if (scheduleType === "once") {
      if (!startAt) {
        return {
          content: [{ type: "text" as const, text: "'once' 타입은 startAt(실행 일시)이 필요합니다." }],
          details: { ok: false },
        };
      }
      const runAt = new Date(startAt);
      if (Number.isNaN(runAt.getTime())) {
        return {
          content: [{ type: "text" as const, text: `올바르지 않은 날짜 형식입니다: ${startAt}` }],
          details: { ok: false },
        };
      }
      logger.info(`📅 Tool[schedule/once]: ${label} → ${startAt} [Agent: ${agentId}]`);
      await registerScheduledTask({
        prompt, label, agentId, appId,
        isOneOff: true,
        startAt: runAt.toISOString(),
        // endAt = startAt + 59초 (서버에서 자동 설정)
      });
      return {
        content: [{ type: "text" as const, text: `✅ "${label}" 알림이 ${runAt.toLocaleString("ko-KR")}에 등록되었습니다.` }],
        details: { ok: true, scheduledAt: runAt.toISOString() },
      };
    }

    // ── 반복 ──────────────────────────────────────────────────────
    let spec: ScheduleSpec;
    switch (scheduleType) {
      case "every_n_minutes":
        spec = { type: "every_n_minutes", every: every ?? 1 };
        break;
      case "every_n_hours":
        spec = { type: "every_n_hours", every: every ?? 1 };
        break;
      case "daily":
        spec = { type: "daily", hour: hour ?? 9, minute: minute ?? 0 };
        break;
      case "weekly":
        spec = { type: "weekly", days: days ?? [1], hour: hour ?? 9, minute: minute ?? 0 };
        break;
      case "monthly":
        spec = { type: "monthly", day: day ?? 1, hour: hour ?? 9, minute: minute ?? 0 };
        break;
      case "yearly":
        spec = { type: "yearly", month: month ?? 1, day: day ?? 1, hour: hour ?? 9, minute: minute ?? 0 };
        break;
      default:
        return {
          content: [{ type: "text" as const, text: `알 수 없는 scheduleType: ${scheduleType}` }],
          details: { ok: false },
        };
    }

    const specLabel = scheduleSpecToLabel(spec);
    logger.info(`📅 Tool[schedule]: ${label} (${specLabel}) [Agent: ${agentId}, startAt: ${startAt ?? "즉시"}, endAt: ${endAt ?? "무한"}]`);
    await registerScheduledTask({ scheduleSpec: spec, prompt, label, agentId, appId, isOneOff: false, startAt, endAt });
    return {
      content: [{ type: "text" as const, text: t("tool.schedule.registered", { label, schedule: specLabel }) }],
      details: {},
    };
  },
};

export const listSchedulesTool: AgentTool = {
  name: "list_schedules",
  label: "스케줄 조회",
  description:
    "현재 활성 에이전트에 등록된 스케줄 목록을 조회한다. 스케줄 삭제/수정 전에 어떤 taskId와 label이 있는지 먼저 확인할 때 사용한다.",
  parameters: Type.Object({}),
  execute: async () => {
    const { agentId: activeAgentId } = resolveExecutionContext();
    const tasks = getTasks().filter(
      (task) => (task.agentId || "default") === activeAgentId,
    );

    if (tasks.length === 0) {
      return {
        content: [{ type: "text" as const, text: t("tool.schedule.list.empty") }],
        details: { ok: true, count: 0, tasks: [] },
      };
    }

    const lines = tasks.map((task, index) => {
      const oneOff = task.isOneOff ? "1회성" : "반복";
      const enabled = task.enabled === false ? "비활성" : "활성";
      const scheduleDisplay = task.scheduleSpec
        ? scheduleSpecToLabel(task.scheduleSpec)
        : (task.isOneOff ? `${new Date(task.startAt).toLocaleString("ko-KR")} (1회성)` : "알 수 없음");
      return `${index + 1}. [${task.id}] ${task.label} | ${scheduleDisplay} | ${oneOff} | ${enabled}`;
    });

    return {
      content: [
        {
          type: "text" as const,
          text: `${t("tool.schedule.list.header", { count: tasks.length })}\n${lines.join("\n")}`,
        },
      ],
      details: {
        ok: true,
        count: tasks.length,
        tasks: tasks.map((task) => ({
          taskId: task.id,
          label: task.label,
          scheduleSpec: task.scheduleSpec,
          startAt: task.startAt,
          endAt: task.endAt,
          agentId: task.agentId || "default",
          isOneOff: task.isOneOff === true,
          enabled: task.enabled !== false,
        })),
      },
    };
  },
};

export const deleteScheduleTool: AgentTool = {
  name: "delete_schedule",
  label: "스케줄 삭제",
  description:
    "이미 등록된 스케줄을 실제로 삭제한다. 애매하면 먼저 list_schedules로 taskId를 확인한 뒤 taskId로 삭제한다. taskId가 없으면 현재 활성 에이전트 기준으로 label과 정확히 일치하는 스케줄을 삭제한다.",
  parameters: Type.Object({
    taskId: Type.Optional(
      Type.String({
        description: "삭제할 스케줄의 task ID. 알고 있으면 이 값을 우선 사용한다.",
      }),
    ),
    label: Type.Optional(
      Type.String({
        description: "삭제할 스케줄 이름. taskId를 모를 때 현재 활성 에이전트의 동일 label 스케줄을 찾는다.",
      }),
    ),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { taskId, label } = params as { taskId?: string; label?: string };
    const { agentId: activeAgentId } = resolveExecutionContext();

    if (!taskId && !label) {
      return {
        content: [
          {
            type: "text" as const,
            text: t("tool.schedule.delete.missing_params"),
          },
        ],
        details: { ok: false },
      };
    }

    let targetTaskId = taskId?.trim();

    if (!targetTaskId) {
      const normalizedLabel = label!.trim();
      const matchedTasks = getTasks().filter(
        (task) =>
          (task.agentId || "default") === activeAgentId &&
          task.label.trim() === normalizedLabel,
      );

      if (matchedTasks.length === 0) {
        return {
          content: [
            {
              type: "text" as const,
              text: t("tool.schedule.delete.not_found", {
                agentId: activeAgentId,
                label: normalizedLabel,
              }),
            },
          ],
          details: { ok: false, agentId: activeAgentId, label: normalizedLabel },
        };
      }

      if (matchedTasks.length > 1) {
        return {
          content: [
            {
              type: "text" as const,
              text: t("tool.schedule.delete.ambiguous", {
                count: matchedTasks.length,
              }),
            },
          ],
          details: {
            ok: false,
            ambiguous: true,
            matches: matchedTasks.map((task) => ({
              taskId: task.id,
              label: task.label,
              agentId: task.agentId || "default",
            })),
          },
        };
      }

      targetTaskId = matchedTasks[0].id;
    }

    logger.info(
      `🗑️ Tool[delete_schedule]: taskId=${targetTaskId} [Agent: ${activeAgentId}]`,
    );
    const result = await handleDeleteTaskWs({ taskId: targetTaskId });

    return {
      content: [
        {
          type: "text" as const,
          text: result.success
              ? t("tool.schedule.delete.success", { taskId: targetTaskId })
              : t("tool.schedule.delete.failed", { taskId: targetTaskId }),
        },
      ],
      details: {
        ok: result.success,
        taskId: targetTaskId,
      },
    };
  },
};

export const TOOLS = [
  listSchedulesTool,
  registerScheduleTool,
  deleteScheduleTool,
];
