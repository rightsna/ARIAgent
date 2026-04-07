import fs from "fs";
import path from "path";
import os from "os";
let cachedIsSeaFn: (() => boolean) | null | undefined;

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

function getEntryDir(): string {
  const entryFile = process.argv[1];
  if (entryFile) {
    return path.dirname(path.resolve(entryFile));
  }

  return path.dirname(process.execPath);
}

export function isBundledServer(): boolean {
  if (cachedIsSeaFn === undefined) {
    cachedIsSeaFn = null;
    try {
      // Older Node runtimes may not provide node:sea at all.
      const dynamicRequire = Function(
        "return typeof require !== 'undefined' ? require : null;",
      )() as ((specifier: string) => unknown) | null;

      const seaModule = dynamicRequire?.("node:sea") as
        | { isSea?: () => boolean }
        | undefined;
      if (typeof seaModule?.isSea === "function") {
        cachedIsSeaFn = seaModule.isSea;
      }
    } catch {
      cachedIsSeaFn = null;
    }
  }

  try {
    return cachedIsSeaFn?.() ?? false;
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
  const entryDir = getEntryDir();
  const candidates = isBundledServer()
    ? uniquePaths([
        execDir,
        path.join(execDir, "ari-server"),
      ])
    : uniquePaths([
        process.cwd(),
        path.join(process.cwd(), "ari-server"),
        entryDir,
        path.resolve(entryDir, ".."),
        path.resolve(entryDir, "..", ".."),
      ]);

  for (const candidate of candidates) {
    if (hasServerRuntimeMarkers(candidate)) {
      return candidate;
    }
  }

  return isBundledServer() ? execDir : path.resolve(entryDir, "..");
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
    getWorkspaceRoot(),
    path.join(getWorkspaceRoot(), "ari-app", "build", "macos", "Build", "Products", "Debug"),
    path.join(getWorkspaceRoot(), "ari-app", "build", "macos", "Build", "Products", "Release"),
  ]);

  return candidates.filter((candidate) => fs.existsSync(candidate));
}

export function getBundleRoot(): string {
  const roots = getBundleRoots();
  return roots.length > 0 ? roots[0] : path.join(os.homedir(), ".ari-agent", "skills");
}

export function findAppExecutable(appId: string): string | null {
  const bundleRoots = getBundleRoots();

  if (process.platform === "darwin") {
    for (const root of bundleRoots) {
      const appIdNoUnderscore = appId.replace(/_/g, "");
      const candidates = [
        appId,
        appIdNoUnderscore,
        appId.charAt(0).toUpperCase() + appId.slice(1).replace(/_/g, ""),
        "app",
        "AriAgent",
      ];

      for (const cand of candidates) {
        const paths = [
          path.join(root, appId, `${cand}.app`, "Contents", "MacOS", cand),
          path.join(root, appId, "app.app", "Contents", "MacOS", cand),
          path.join(root, appId, "Contents", "MacOS", cand),
          path.join(root, `${cand}.app`, "Contents", "MacOS", cand),
          path.join(root, `${appId}.app`, "Contents", "MacOS", cand),
          path.join(root, cand, "Contents", "MacOS", cand),
        ];

        for (const p of paths) {
          if (fs.existsSync(p)) return p;
        }

        const bundlePaths = [
          path.join(root, appId, `${cand}.app`),
          path.join(root, appId, "app.app"),
          path.join(root, `${cand}.app`),
          path.join(root, `${appId}.app`),
        ];
        for (const bp of bundlePaths) {
          const macOsDir = path.join(bp, "Contents", "MacOS");
          if (fs.existsSync(macOsDir)) {
            const files = fs.readdirSync(macOsDir).filter((f: string) => !f.startsWith("."));
            if (files.length > 0) return path.join(macOsDir, files[0]);
          }
        }
      }
    }
  } else if (process.platform === "win32") {
    for (const root of bundleRoots) {
      const appIdNoUnderscore = appId.replace(/_/g, "");
      const paths = [
        path.join(root, appId, "app.exe"),
        path.join(root, appId, `${appId}.exe`),
        path.join(root, appId, `${appIdNoUnderscore}.exe`),
        path.join(root, `${appId}.exe`),
        path.join(root, `${appIdNoUnderscore}.exe`),
      ];
      for (const p of paths) {
        if (fs.existsSync(p)) return p;
      }
    }
  }

  return null;
}
