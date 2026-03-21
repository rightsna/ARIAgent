import fs from "fs";
import path from "path";
import os from "os";
import { isSea } from "node:sea";

function uniquePaths(paths: string[]): string[] {
  return Array.from(new Set(paths.filter(Boolean).map((entry) => path.resolve(entry))));
}

function hasServerRuntimeMarkers(dirPath: string): boolean {
  return fs.existsSync(path.join(dirPath, "package.json")) ||
    fs.existsSync(path.join(dirPath, "template")) ||
    fs.existsSync(path.join(dirPath, "skills"));
}

function hasWorkspaceMarkers(dirPath: string): boolean {
  return fs.existsSync(path.join(dirPath, "README.md")) ||
    fs.existsSync(path.join(dirPath, "ari-app", "pubspec.yaml"));
}

export function isBundledServer(): boolean {
  try {
    return isSea();
  } catch {
    return false;
  }
}

export function getServerRootDir(): string {
  const override = process.env.ARI_SERVER_ROOT;
  if (override && hasServerRuntimeMarkers(override)) {
    return path.resolve(override);
  }

  const execDir = path.dirname(process.execPath);
  const candidates = isBundledServer()
    ? uniquePaths([
        execDir,
        path.join(execDir, "ari-server"),
      ])
    : uniquePaths([
        process.cwd(),
        path.join(process.cwd(), "ari-server"),
        path.resolve(__dirname, ".."),
        path.resolve(__dirname, "..", ".."),
      ]);

  for (const candidate of candidates) {
    if (hasServerRuntimeMarkers(candidate)) {
      return candidate;
    }
  }

  return isBundledServer() ? execDir : path.resolve(__dirname, "..");
}

export function getWorkspaceRoot(): string {
  const override = process.env.ARI_WORKSPACE_ROOT;
  if (override && hasWorkspaceMarkers(override)) {
    return path.resolve(override);
  }

  const serverRoot = getServerRootDir();
  const candidates = uniquePaths([
    path.resolve(serverRoot, ".."),
    path.resolve(serverRoot, "..", ".."),
    process.cwd(),
    path.resolve(process.cwd(), ".."),
  ]);

  for (const candidate of candidates) {
    if (hasWorkspaceMarkers(candidate)) {
      return candidate;
    }
  }

  return path.resolve(serverRoot, "..");
}

export function resolveServerPath(...segments: string[]): string {
  return path.join(getServerRootDir(), ...segments);
}

export function getBundleRoots(): string[] {
  const candidates = uniquePaths([
    path.join(os.homedir(), ".ari-agent", "plugin"),
    path.join(os.homedir(), ".ari-agent", "skills"),
  ]);

  return candidates.filter((candidate) => fs.existsSync(candidate));
}

export function getBundleRoot(): string {
  const roots = getBundleRoots();
  return roots.length > 0 ? roots[0] : path.join(os.homedir(), ".ari-agent", "skills");
}
