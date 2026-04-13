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
  label: "반복 스케줄 등록",
  description: "매분, 매시간, 매일, 매주, 매월 등 정기적으로 반복되는 작업을 로컬 스케줄러에 등록한다. (1회성 알림은 register_one_off_schedule 사용)",
  parameters: Type.Object({
    scheduleType: Type.String({
      description:
        "반복 유형. 반드시 다음 중 하나: 'every_n_minutes'(N분마다), 'every_n_hours'(N시간마다), 'daily'(매일), 'weekly'(매주 특정 요일), 'monthly'(매월 특정 일), 'yearly'(매년 특정 날짜)",
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
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { scheduleType, every, hour, minute, days, day, month, prompt, label } = params as {
      scheduleType: string;
      every?: number;
      hour?: number;
      minute?: number;
      days?: number[];
      day?: number;
      month?: number;
      prompt: string;
      label: string;
    };
    const { agentId, appId } = resolveExecutionContext();

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
    logger.info(`📅 Tool[schedule]: ${label} (${specLabel}) [Agent: ${agentId}, App: ${appId}, OneOff: false]`);
    await registerScheduledTask({ scheduleSpec: spec, prompt, label, agentId, appId, isOneOff: false });
    return {
      content: [{ type: "text" as const, text: t("tool.schedule.registered", { label, schedule: specLabel }) }],
      details: {},
    };
  },
};

export const registerOneOffScheduleTool: AgentTool = {
  name: "register_one_off_schedule",
  label: "1회성 스케줄 등록",
  description: "딱 한 번만 울려야 하는 알림('5분 뒤', '내일 1시' 등)을 등록한다. 지정된 시간에 1회 실행 후 자동 삭제된다.",
  parameters: Type.Object({
    delayMinutes: Type.Number({
      description:
        "현재 시간을 기준으로 몇 분 뒤에 실행할 것인지 지정. (예: '5분 뒤'면 5, '1시간 뒤'면 60, 내일 오후 1시라면 지금부터 내일 오후 1시까지의 시간을 분 단위로 계산해서 입력)",
    }),
    prompt: Type.String({ description: "지정된 시간에 LLM이 실행할 프롬프트 (예: '5분이 지났습니다. 사용자에게 알림을 전달해주세요.')" }),
    label: Type.String({ description: "작업 이름 (짧게, 예: '5분 뒤 타이머')" }),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { delayMinutes, prompt, label } = params as { delayMinutes: number; prompt: string; label: string };
    const { agentId, appId } = resolveExecutionContext();

    const scheduledFor = new Date(Date.now() + delayMinutes * 60000).toISOString();

    logger.info(`📅 Tool[one_off_schedule]: ${label} (${scheduledFor}) [Agent: ${agentId}, App: ${appId}] computed from +${delayMinutes}m`);
    await registerScheduledTask({ prompt, label, agentId, appId, isOneOff: true, scheduledFor });

    return {
      content: [
        {
          type: "text" as const,
          text: t("tool.schedule.one_off_registered", { label, delayMinutes }),
        },
      ],
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
        : (task.scheduledFor ? `${new Date(task.scheduledFor).toLocaleString("ko-KR")} (1회성)` : "알 수 없음");
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
          scheduledFor: task.scheduledFor,
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
  registerOneOffScheduleTool,
  deleteScheduleTool,
];
