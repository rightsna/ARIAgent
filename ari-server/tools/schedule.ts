import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { handleDeleteTaskWs, registerScheduledTask } from "../services/task.js";
import { getActiveAgentId, getActiveAppId } from "../services/memory.js";
import { logger } from "../infra/logger.js";
import { t } from "../infra/i18n.js";
import { getTasks } from "../repositories/task_repository.js";

export const registerScheduleTool: AgentTool = {
  name: "register_schedule",
  label: "반복 스케줄 등록",
  description: "매분, 매시간, 매일, 매주 등 정기적으로 반복되는 작업을 로컬 스케줄러에 등록한다. 1분마다 반복 알림도 지원한다. (1회성 알림은 이 도구 대신 register_one_off_schedule 도구를 사용할 것)",
  parameters: Type.Object({
    cron: Type.String({
      description: "cron 표현식 (예: '* * * * *'=매분, '*/5 * * * *'=5분마다, '0 9 * * *'=매일9시, '0 18 * * *'=매일18시)",
    }),
    prompt: Type.String({ description: "스케줄 시간에 LLM이 실행할 프롬프트" }),
    label: Type.String({ description: "작업 이름 (짧게, 예: '뉴스 브리핑')" }),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { cron, prompt, label } = params as { cron: string; prompt: string; label: string };
    const agentId = getActiveAgentId();
    const appId = getActiveAppId();
    logger.info(`📅 Tool[schedule]: ${label} (${cron}) [Agent: ${agentId}, App: ${appId}, OneOff: false]`);
    await registerScheduledTask({ cron, prompt, label, agentId, appId, isOneOff: false });
    return {
      content: [{ type: "text" as const, text: t("tool.schedule.registered", { label, cron }) }],
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
    const agentId = getActiveAgentId();
    const appId = getActiveAppId();

    const d = new Date(Date.now() + delayMinutes * 60000);
    // 표시와 하위 호환을 위해 cron도 유지하지만, 실제 1회성 시각은 scheduledFor를 우선 저장한다.
    const cron = `${d.getMinutes()} ${d.getHours()} ${d.getDate()} ${d.getMonth() + 1} *`;
    const scheduledFor = d.toISOString();

    logger.info(`📅 Tool[one_off_schedule]: ${label} (${scheduledFor}) [Agent: ${agentId}, App: ${appId}] computed from +${delayMinutes}m`);
    await registerScheduledTask({ cron, prompt, label, agentId, appId, isOneOff: true, scheduledFor });

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
    const activeAgentId = getActiveAgentId();
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
      return `${index + 1}. [${task.id}] ${task.label} | ${task.cron} | ${oneOff} | ${enabled}`;
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
          cron: task.cron,
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
    const activeAgentId = getActiveAgentId();

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
              cron: task.cron,
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
