import { logger } from "../infra/logger";

export interface AppState {
  appId: string;
  state: Record<string, any>;
  lastUpdated: number;
}

class AppStateService {
  private static instance: AppStateService;
  private states = new Map<string, AppState>();

  private constructor() {}

  public static getInstance(): AppStateService {
    if (!AppStateService.instance) {
      AppStateService.instance = new AppStateService();
    }
    return AppStateService.instance;
  }

  /**
   * 앱 상태 업데이트
   */
  public updateState(appId: string, state: Record<string, any>): void {
    const now = Date.now();
    this.states.set(appId, {
      appId,
      state,
      lastUpdated: now,
    });
    // logger.debug(`[AppStateService] Updated state for ${appId}`);
  }

  /**
   * 앱 상태 조회
   */
  public getState(appId: string): AppState | undefined {
    return this.states.get(appId);
  }

  /**
   * 모든 앱 상태 목록 조회
   */
  public getAllStates(): AppState[] {
    return Array.from(this.states.values());
  }
}

export const appStateService = AppStateService.getInstance();
