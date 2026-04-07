import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export function moduleFilePath(metaUrl: string): string {
  return fileURLToPath(metaUrl);
}

export function moduleDir(metaUrl: string): string {
  return path.dirname(moduleFilePath(metaUrl));
}

export function isMainModule(metaUrl: string): boolean {
  const entryFile = process.argv[1];
  if (!entryFile) {
    return false;
  }

  return pathToFileURL(path.resolve(entryFile)).href === metaUrl;
}
