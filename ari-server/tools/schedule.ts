import { AgentTool } from "@mariozechner/pi-agent-core";
import { Type } from "@mariozechner/pi-ai";
import { registerScheduledTask } from "../services/task";
import { getActiveAgentId } from "../services/memory";
import { logger } from "../infra/logger";

export const registerScheduleTool: AgentTool = {
  name: "register_schedule",
  label: "반복 스케줄 등록",
  description: "매일, 매주, 매시간 등 정기적으로 반복되는 작업을 crontab에 등록한다. (1회성 알림은 이 도구 대신 register_one_off_schedule 도구를 사용할 것)",
  parameters: Type.Object({
    cron: Type.String({
      description: "cron 표현식 (예: '0 9 * * *'=매일9시, '0 18 * * *'=매일18시)",
    }),
    prompt: Type.String({ description: "스케줄 시간에 LLM이 실행할 프롬프트" }),
    label: Type.String({ description: "작업 이름 (짧게, 예: '뉴스 브리핑')" }),
  }),
  execute: async (_toolCallId, params, _signal, _onUpdate) => {
    const { cron, prompt, label } = params as { cron: string; prompt: string; label: string };
    const agentId = getActiveAgentId();
    logger.info(`📅 Tool[schedule]: ${label} (${cron}) [Agent: ${agentId}, OneOff: false]`);
    await registerScheduledTask({ cron, prompt, label, agentId, isOneOff: false });
    return {
      content: [{ type: "text" as const, text: `✅ 반복 스케줄 등록 완료: "${label}" (${cron})` }],
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

    // 현재 시간에 분을 더해서 cron으로 변환
    const d = new Date(Date.now() + delayMinutes * 60000);
    const cron = `${d.getMinutes()} ${d.getHours()} ${d.getDate()} ${d.getMonth() + 1} *`;

    logger.info(`📅 Tool[one_off_schedule]: ${label} (${cron}) [Agent: ${agentId}] computed from +${delayMinutes}m`);
    await registerScheduledTask({ cron, prompt, label, agentId, isOneOff: true });

    return {
      content: [{ type: "text" as const, text: `✅ 1회성 스케줄 등록 완료: "${label}" (${delayMinutes}분 뒤 예정)` }],
      details: {},
    };
  },
};

export const TOOLS = [registerScheduleTool, registerOneOffScheduleTool];
