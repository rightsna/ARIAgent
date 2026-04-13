import { SchedulerAdapter, ScheduledJobHandle } from "./types.js";

type NodeScheduleJob = {
  cancel(): boolean;
  nextInvocation?: () => Date | { toDate(): Date } | null;
};

type NodeScheduleModule = {
  scheduleJob(
    spec: string | Date,
    callback: () => Promise<void> | void,
  ): NodeScheduleJob;
  gracefulShutdown?: () => Promise<void>;
};

const dynamicImport = new Function(
  "specifier",
  "return import(specifier);",
) as (specifier: string) => Promise<unknown>;

function normalizeNodeScheduleModule(mod: unknown): NodeScheduleModule {
  const candidate = (mod as { default?: unknown })?.default ?? mod;
  if (
    !candidate ||
    typeof candidate !== "object" ||
    typeof (candidate as NodeScheduleModule).scheduleJob !== "function"
  ) {
    throw new Error(
      "node-schedule 모듈을 찾을 수 없거나 scheduleJob 함수를 확인할 수 없습니다.",
    );
  }

  return candidate as NodeScheduleModule;
}

function normalizeNextInvocation(job: NodeScheduleJob): Date | null {
  const rawNextInvocation = job.nextInvocation?.();
  if (!rawNextInvocation) {
    return null;
  }

  if (rawNextInvocation instanceof Date) {
    return rawNextInvocation;
  }

  if (
    typeof rawNextInvocation === "object" &&
    typeof rawNextInvocation.toDate === "function"
  ) {
    return rawNextInvocation.toDate();
  }

  return null;
}

async function loadNodeScheduleModule(): Promise<NodeScheduleModule> {
  const runtimeModule = await dynamicImport("node-schedule");
  return normalizeNodeScheduleModule(runtimeModule);
}

export class NodeScheduleAdapter implements SchedulerAdapter {
  readonly name = "node-schedule";

  async scheduleCron(
    _taskId: string,
    cronExpr: string,
    onRun: () => Promise<void> | void,
  ): Promise<ScheduledJobHandle> {
    const scheduler = await loadNodeScheduleModule();
    const job = scheduler.scheduleJob(cronExpr, onRun);

    return {
      cancel: () => job.cancel(),
      nextInvocation: () => normalizeNextInvocation(job),
    };
  }

  async scheduleDate(
    _taskId: string,
    runAt: Date,
    onRun: () => Promise<void> | void,
  ): Promise<ScheduledJobHandle> {
    const scheduler = await loadNodeScheduleModule();
    const job = scheduler.scheduleJob(runAt, onRun);

    return {
      cancel: () => job.cancel(),
      nextInvocation: () => normalizeNextInvocation(job),
    };
  }

  async shutdown(): Promise<void> {
    const scheduler = await loadNodeScheduleModule();
    if (typeof scheduler.gracefulShutdown === "function") {
      await scheduler.gracefulShutdown();
    }
  }
}
