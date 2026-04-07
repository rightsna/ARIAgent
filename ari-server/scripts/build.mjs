import fs from "fs";
import path from "path";
import { spawnSync } from "child_process";
import { fileURLToPath } from "url";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const distDir = path.join(rootDir, "dist");
const standaloneDir = path.join(rootDir, "build", "standalone");
const standaloneBinaryName = process.platform === "win32" ? "ari-server.exe" : "ari-server";
const nodeBinDir = path.dirname(process.execPath);
const existingPath = process.env.PATH ?? process.env.Path ?? "";
const pathWithNode = process.platform === "win32"
  ? `${nodeBinDir};${existingPath}`
  : `${nodeBinDir}:${existingPath}`;

function runCommand(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: rootDir,
    stdio: "inherit",
    env: {
      ...process.env,
      PATH: pathWithNode,
      Path: pathWithNode,
    },
    ...options,
  });

  if (result.error) {
    console.error(`[build] Error running command ${command}:`, result.error);
    process.exit(1);
  }

  if (result.status !== 0) {
    console.error(`[build] Command ${command} failed with exit code ${result.status}`);
    process.exit(result.status ?? 1);
  }
}

function tryRunCommand(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: rootDir,
    stdio: "inherit",
    env: {
      ...process.env,
      PATH: pathWithNode,
      Path: pathWithNode,
    },
    ...options,
  });

  return result.status === 0;
}

function copyDirIfExists(sourceRelative, targetRoot) {
  const source = path.join(rootDir, sourceRelative);
  if (!fs.existsSync(source)) {
    return;
  }

  const target = path.join(targetRoot, sourceRelative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, { recursive: true });
}

function copySkills(targetRoot) {
  const skillsDir = path.join(rootDir, "skills");
  if (!fs.existsSync(skillsDir)) {
    return;
  }

  const targetDir = path.join(targetRoot, "skills");
  fs.mkdirSync(targetDir, { recursive: true });

  for (const entry of fs.readdirSync(skillsDir)) {
    fs.cpSync(path.join(skillsDir, entry), path.join(targetDir, entry), {
      recursive: true,
    });
  }
}

function copyNodeModuleIfExists(moduleName, targetRoot) {
  const source = path.join(rootDir, "node_modules", ...moduleName.split("/"));
  if (!fs.existsSync(source)) {
    return;
  }

  const target = path.join(targetRoot, "node_modules", ...moduleName.split("/"));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, { recursive: true });
}

function copyNodeModuleTree(moduleName, targetRoot, visited = new Set()) {
  if (visited.has(moduleName)) {
    return;
  }
  visited.add(moduleName);

  const source = path.join(rootDir, "node_modules", ...moduleName.split("/"));
  if (!fs.existsSync(source)) {
    console.warn(`[build] Warning: node module not found for standalone copy: ${moduleName}`);
    return;
  }

  copyNodeModuleIfExists(moduleName, targetRoot);

  const packageJsonPath = path.join(source, "package.json");
  if (!fs.existsSync(packageJsonPath)) {
    return;
  }

  try {
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
    const dependencies = Object.keys(packageJson.dependencies ?? {});
    for (const dependency of dependencies) {
      copyNodeModuleTree(dependency, targetRoot, visited);
    }
  } catch (error) {
    console.warn(
      `[build] Warning: failed to inspect dependencies for ${moduleName}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

function cleanDir(targetDir) {
  console.log(`[build] Cleaning directory: ${targetDir}`);
  fs.rmSync(targetDir, { recursive: true, force: true });
  fs.mkdirSync(targetDir, { recursive: true });
}

function buildTypeScript() {
  const tscCommand = process.platform === "win32"
    ? "cmd.exe"
    : path.join(rootDir, "node_modules", ".bin", "tsc");
  const tscArgs = process.platform === "win32"
    ? ["/c", path.join(rootDir, "node_modules", ".bin", "tsc.cmd")]
    : [];

  cleanDir(distDir);
  runCommand(tscCommand, tscArgs);
  fs.writeFileSync(
    path.join(distDir, "package.json"),
    JSON.stringify({
      type: "module",
      main: "index.js",
    }, null, 2),
  );
  copyDirIfExists("template", distDir);
  copySkills(distDir);
}

async function buildStandalone() {
  try {
    const { build: esbuild } = await import("esbuild");
    buildTypeScript();
    cleanDir(standaloneDir);

    const bundleFile = path.join(standaloneDir, "server.bundle.cjs");
    const launcherFile = path.join(standaloneDir, "sea-launcher.cjs");
    const seaConfigPath = path.join(standaloneDir, "sea-config.json");
    const seaBlobPath = path.join(standaloneDir, "sea-prep.blob");
    const outputBinaryPath = path.join(standaloneDir, standaloneBinaryName);

    await esbuild({
      entryPoints: [path.join(rootDir, "index.ts")],
      outfile: bundleFile,
      bundle: true,
      platform: "node",
      format: "cjs",
      target: "node22",
      sourcemap: false,
      logLevel: "info",
      external: [
        "playwright",
        "playwright-core",
        "chromium-bidi",
        "fsevents",
      ],
    });

    fs.writeFileSync(
      launcherFile,
      [
        'const { createRequire } = require("node:module");',
        'const path = require("node:path");',
        'const entryRequire = createRequire(path.join(path.dirname(process.execPath), "sea-launcher.cjs"));',
        'entryRequire("./server.bundle.cjs");',
        "",
      ].join("\n"),
    );

    fs.writeFileSync(seaConfigPath, JSON.stringify({
      main: launcherFile,
      output: seaBlobPath,
      disableExperimentalSEAWarning: true,
      useSnapshot: false,
      useCodeCache: false,
    }, null, 2));

    runCommand(process.execPath, ["--experimental-sea-config", seaConfigPath]);

    fs.copyFileSync(process.execPath, outputBinaryPath);

    if (process.platform === "darwin") {
      tryRunCommand("codesign", ["--remove-signature", outputBinaryPath], {
        stdio: "ignore",
      });
    }

    const postjectCli = require.resolve("postject/dist/cli.js");
    const postjectArgs = [
      postjectCli,
      outputBinaryPath,
      "NODE_SEA_BLOB",
      seaBlobPath,
      "--sentinel-fuse",
      "NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2",
    ];

    if (process.platform === "darwin") {
      postjectArgs.push("--macho-segment-name", "NODE_SEA");
    }

    runCommand(process.execPath, postjectArgs);
    if (process.platform === "darwin") {
      const didSign = tryRunCommand("codesign", ["--sign", "-", "--force", outputBinaryPath]);
      if (!didSign) {
        console.warn("[build] Warning: ad-hoc codesign failed for standalone macOS binary; continuing with unsigned runtime.");
      }
    }
    fs.chmodSync(outputBinaryPath, 0o755);

    copyDirIfExists("template", standaloneDir);
    copySkills(standaloneDir);
    copyNodeModuleTree("playwright", standaloneDir);
    copyNodeModuleTree("playwright-core", standaloneDir);
    copyNodeModuleTree("chromium-bidi", standaloneDir);
    copyNodeModuleTree("node-schedule", standaloneDir);

    fs.rmSync(launcherFile, { force: true });
    fs.rmSync(seaConfigPath, { force: true });
    fs.rmSync(seaBlobPath, { force: true });
  } catch (err) {
    console.error("[build] FATAL ERROR:", err);
    process.exit(1);
  }
}

const mode = process.argv[2] ?? "build";

if (mode === "standalone") {
  await buildStandalone();
} else {
  buildTypeScript();
}
