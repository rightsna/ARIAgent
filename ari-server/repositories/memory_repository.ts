import path from "path";
import { DATA_DIR, ensureDirSync, fileExistsSync, readTextSync, writeTextSync, appendTextSync, unlinkSyncSafe, rmDirSyncSafe } from "../infra/data";

function getWorkspaceDir(agentId?: string): string {
  if (agentId && agentId !== "default") {
    return path.join(DATA_DIR, "agents", agentId, "workspace");
  }
  return path.join(DATA_DIR, "workspace");
}

function getMemoryDir(agentId?: string): string {
  return path.join(getWorkspaceDir(agentId), "memory");
}

export function hasWorkspace(agentId?: string): boolean {
  return fileExistsSync(getWorkspaceDir(agentId));
}

// Core Memory (MEMORY.md)
export function readCoreMemory(agentId?: string): string {
  return readTextSync(path.join(getWorkspaceDir(agentId), "MEMORY.md"));
}

export function writeCoreMemory(agentId: string | undefined, content: string): void {
  const wsDir = getWorkspaceDir(agentId);
  ensureDirSync(wsDir);
  writeTextSync(path.join(wsDir, "MEMORY.md"), content);
}

export function removeCoreMemory(agentId?: string): void {
  unlinkSyncSafe(path.join(getWorkspaceDir(agentId), "MEMORY.md"));
}

// Daily Memory
export function hasDailyMemory(agentId: string | undefined, filename: string): boolean {
  return fileExistsSync(path.join(getMemoryDir(agentId), filename));
}

export function appendDailyMemoryLine(agentId: string | undefined, filename: string, content: string): void {
  const mDir = getMemoryDir(agentId);
  ensureDirSync(mDir);
  appendTextSync(path.join(mDir, filename), content);
}

export function readDailyMemory(agentId: string | undefined, filename: string): string {
  return readTextSync(path.join(getMemoryDir(agentId), filename));
}

export function removeDailyMemoryDir(agentId?: string): void {
  rmDirSyncSafe(getMemoryDir(agentId));
}
