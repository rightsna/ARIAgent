import fs from "fs";
import path from "path";
import os from "os";
import { logger } from "./logger.js";

export const DATA_DIR = path.join(os.homedir(), ".ari-agent");

/**
 * 디렉토리가 존재하지 않으면 생성합니다.
 */
export function ensureDirSync(dirPath: string): void {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

/**
 * 파일이 존재하는지 확인합니다.
 */
export function fileExistsSync(filePath: string): boolean {
  return fs.existsSync(filePath);
}

/**
 * JSON 파일을 읽어 객체로 반환합니다. 파일이 없으면 defaultValue를 반환합니다.
 */
export function readJsonSync<T>(filePath: string, defaultValue?: T): T | null {
  if (fs.existsSync(filePath)) {
    try {
      const content = fs.readFileSync(filePath, "utf-8");
      return JSON.parse(content) as T;
    } catch (err) {
      logger.error(`[Data] Error parsing JSON from ${filePath}:`, err);
    }
  }
  return defaultValue !== undefined ? defaultValue : null;
}

/**
 * 객체를 JSON 파일로 저장합니다.
 */
export function writeJsonSync(filePath: string, data: any): void {
  ensureDirSync(path.dirname(filePath));
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), "utf-8");
}

/**
 * 텍스트 파일을 읽습니다. 파일이 없으면 defaultValue를 반환합니다.
 */
export function readTextSync(filePath: string, defaultValue: string = ""): string {
  if (fs.existsSync(filePath)) {
    try {
      return fs.readFileSync(filePath, "utf-8");
    } catch (err) {
      logger.error(`[Data] Error reading text from ${filePath}:`, err);
    }
  }
  return defaultValue;
}

/**
 * 텍스트 파일을 저장합니다.
 */
export function writeTextSync(filePath: string, content: string): void {
  ensureDirSync(path.dirname(filePath));
  fs.writeFileSync(filePath, content, "utf-8");
}

/**
 * 텍스트를 파일 끝에 추가합니다.
 */
export function appendTextSync(filePath: string, content: string): void {
  ensureDirSync(path.dirname(filePath));
  fs.appendFileSync(filePath, content, "utf-8");
}

/**
 * 파일을 삭제합니다. (존재할 경우에만)
 */
export function unlinkSyncSafe(filePath: string): void {
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
  }
}

/**
 * 디렉토리를 재귀적으로 삭제합니다. (존재할 경우에만)
 */
export function rmDirSyncSafe(dirPath: string): void {
  if (fs.existsSync(dirPath)) {
    fs.rmSync(dirPath, { recursive: true, force: true });
  }
}

/**
 * 디렉토리 내의 파일 목록을 반환합니다.
 */
export function readDirSyncSafe(dirPath: string): string[] {
  if (fs.existsSync(dirPath)) {
    return fs.readdirSync(dirPath);
  }
  return [];
}
