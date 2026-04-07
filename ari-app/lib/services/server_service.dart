import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:flutter/foundation.dart';

import '../repositories/config_repository.dart';

class ServerService {
  static final ServerService _instance = ServerService._internal();
  factory ServerService() => _instance;
  ServerService._internal();

  Process? _process;

  String get _serverFolder => 'ari-server';
  String get _serverExecutableName =>
      Platform.isWindows ? 'ari-server.exe' : 'ari-server';

  String get _nodeExecutable {
    final root = findProjectRoot();
    final candidates = <String>[];

    // 1. Check for bundled node inside .app/Contents/Resources/bin (macOS)
    if (Platform.isMacOS) {
      candidates.add(
        p.join(root, 'AriAgent.app', 'Contents', 'Resources', 'bin', 'node'),
      );
      candidates.add(p.join(root, 'Contents', 'Resources', 'bin', 'node'));
    }

    // 2. Check for bundled node in bin/ next to executable (Windows/Portable)
    candidates.add(
      p.join(root, 'bin', Platform.isWindows ? 'node.exe' : 'node'),
    );

    // 3. Fallback to standard system paths
    candidates.addAll([
      r'C:\Program Files\nodejs\node.exe',
      r'C:\Program Files (x86)\nodejs\node.exe',
      '/usr/local/bin/node',
      '/opt/homebrew/bin/node',
      '/usr/bin/node',
      '/bin/node',
    ]);

    return _resolveExecutable(
      candidates: candidates,
      defaultCommand: Platform.isWindows ? 'node.exe' : 'node',
    );
  }

  String get _npmExecutable {
    final root = findProjectRoot();
    final candidates = <String>[];

    // 1. Check for bundled npm (usually alongside node)
    if (Platform.isMacOS) {
      candidates.add(
        p.join(root, 'AriAgent.app', 'Contents', 'Resources', 'bin', 'npm'),
      );
      candidates.add(p.join(root, 'Contents', 'Resources', 'bin', 'npm'));
    }
    candidates.add(p.join(root, 'bin', Platform.isWindows ? 'npm.cmd' : 'npm'));

    // 2. Fallbacks
    candidates.addAll([
      r'C:\Program Files\nodejs\npm.cmd',
      r'C:\Program Files (x86)\nodejs\npm.cmd',
      '/usr/local/bin/npm',
      '/opt/homebrew/bin/npm',
      '/usr/bin/npm',
      '/bin/npm',
    ]);

    return _resolveExecutable(
      candidates: candidates,
      defaultCommand: Platform.isWindows ? 'npm.cmd' : 'npm',
    );
  }

  String _resolveExecutable({
    required List<String> candidates,
    required String defaultCommand,
  }) {
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return defaultCommand;
  }

  String findProjectRoot() {
    final exePath = Platform.resolvedExecutable;
    final candidates = <String>{};

    if (exePath.contains(
      '.app${Platform.pathSeparator}Contents${Platform.pathSeparator}',
    )) {
      var dir = File(exePath).parent.path;
      for (var i = 0; i < 3; i++) {
        dir = Directory(dir).parent.path;
      }
      candidates.add(dir);

      var devDir = dir;
      for (var i = 0; i < 4; i++) {
        if (File(
          '$devDir${Platform.pathSeparator}ari-app${Platform.pathSeparator}pubspec.yaml',
        ).existsSync()) {
          candidates.add(devDir);
          break;
        }
        devDir = Directory(devDir).parent.path;
      }
    }

    candidates.add(Directory.current.path);
    candidates.add(Directory.current.parent.path);

    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      candidates.add(
        '$home${Platform.pathSeparator}.ari-agent${Platform.pathSeparator}app-versions${Platform.pathSeparator}latest',
      );
      candidates.add(
        '$home${Platform.pathSeparator}Desktop${Platform.pathSeparator}ARIAgent',
      );
    }

    for (final dir in candidates) {
      final normalizedDir = dir.endsWith('${Platform.pathSeparator}ari-app')
          ? Directory(dir).parent.path
          : dir;
      if (_looksLikeProjectRoot(normalizedDir)) {
        return normalizedDir;
      }
    }

    return candidates.isNotEmpty ? candidates.last : Directory.current.path;
  }

  bool _looksLikeProjectRoot(String dir) {
    return File(
          '$dir${Platform.pathSeparator}$_serverFolder${Platform.pathSeparator}package.json',
        ).existsSync() ||
        File(
          '$dir${Platform.pathSeparator}$_serverFolder${Platform.pathSeparator}build${Platform.pathSeparator}standalone${Platform.pathSeparator}$_serverExecutableName',
        ).existsSync() ||
        File(
          '$dir${Platform.pathSeparator}$_serverFolder${Platform.pathSeparator}$_serverExecutableName',
        ).existsSync() ||
        File(
          '$dir${Platform.pathSeparator}$_serverFolder${Platform.pathSeparator}dist${Platform.pathSeparator}index.js',
        ).existsSync();
  }

  bool _isBundledServerRuntime(String executablePath) {
    final executable = File(executablePath);
    if (!executable.existsSync()) {
      return false;
    }

    final serverDir = executable.parent.path;
    return File(p.join(serverDir, 'server.bundle.cjs')).existsSync() &&
        Directory(p.join(serverDir, 'template')).existsSync() &&
        Directory(p.join(serverDir, 'skills')).existsSync();
  }

  String? _findBundledServerExecutable(String root) {
    final candidates = <String>[
      p.join(root, _serverFolder, 'build', 'standalone', _serverExecutableName),
      p.join(root, _serverFolder, _serverExecutableName),
    ];

    if (Platform.isMacOS) {
      candidates.addAll([
        p.join(
          root,
          'AriAgent.app',
          'Contents',
          'Resources',
          _serverFolder,
          _serverExecutableName,
        ),
        p.join(
          root,
          'Contents',
          'Resources',
          _serverFolder,
          _serverExecutableName,
        ),
      ]);
    }

    for (final candidate in candidates) {
      if (_isBundledServerRuntime(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  Future<void> killExistingServer() async {
    final port = ConfigRepository().port;
    try {
      final pids = await _findListeningPids(port);
      for (final targetPid in pids) {
        if (targetPid == pid) {
          continue;
        }

        final command = await _readProcessCommand(targetPid);
        if (!_isManagedServerCommand(command)) {
          continue;
        }

        debugPrint(
          '[ServerService] terminating process on port $port (PID: $targetPid)',
        );
        await _terminatePid(targetPid);
      }
    } catch (_) {}
  }

  Future<List<int>> _findListeningPids(int port) async {
    if (Platform.isWindows) {
      final result = await Process.run('cmd', [
        '/c',
        'netstat -ano -p tcp | findstr LISTENING | findstr :$port',
      ]);
      final matches = <int>{};
      for (final line in result.stdout.toString().split(RegExp(r'\r?\n'))) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length < 5) {
          continue;
        }
        final localAddress = parts[1];
        final state = parts[3].toUpperCase();
        final pidValue = int.tryParse(parts.last);
        if (state == 'LISTENING' &&
            pidValue != null &&
            localAddress.endsWith(':$port')) {
          matches.add(pidValue);
        }
      }
      return matches.toList();
    }

    final result = await Process.run('/bin/sh', [
      '-c',
      'lsof -nP -iTCP:$port -sTCP:LISTEN -t',
    ]);
    return result.stdout
        .toString()
        .split('\n')
        .map((line) => int.tryParse(line.trim()))
        .whereType<int>()
        .toList();
  }

  Future<String> _readProcessCommand(int targetPid) async {
    if (Platform.isWindows) {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_Process -Filter "ProcessId = $targetPid").CommandLine',
      ]);
      return result.stdout.toString().trim();
    }

    final result = await Process.run('/bin/sh', [
      '-c',
      'ps -p $targetPid -o command=',
    ]);
    return result.stdout.toString().trim();
  }

  bool _isManagedServerCommand(String command) {
    if (command.isEmpty) {
      return false;
    }

    final serverDir =
        '${findProjectRoot()}${Platform.pathSeparator}$_serverFolder'
            .toLowerCase();
    final lower = command.toLowerCase();

    if (lower.contains(serverDir)) {
      return true;
    }

    if (lower.contains(_serverExecutableName.toLowerCase())) {
      return true;
    }

    if (lower.contains('node') &&
        (lower.contains('dist${Platform.pathSeparator}index.js') ||
            lower.contains('index.js') ||
            lower.contains('index.ts') ||
            lower.contains('ts-node') ||
            lower.contains('tsx'))) {
      return true;
    }

    return lower.contains('npm') && lower.contains('build');
  }

  Future<void> _terminatePid(int targetPid) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', '$targetPid', '/T', '/F']);
      return;
    }

    await Process.run('/bin/sh', ['-c', 'kill $targetPid']);

    for (var i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      final check = await Process.run('/bin/sh', [
        '-c',
        'ps -p $targetPid -o pid=',
      ]);
      if (check.stdout.toString().trim().isEmpty) {
        return;
      }
    }

    await Process.run('/bin/sh', ['-c', 'kill -9 $targetPid']);
  }

  Future<bool> startServer({
    String? version,
    String? mode,
    required Function(String) onLog,
    required Function(String) onErrorLog,
    required Function(int) onExit,
  }) async {
    await killExistingServer();

    try {
      final root = findProjectRoot();
      final bundledServerExecutable = kDebugMode
          ? null
          : _findBundledServerExecutable(root);
      final serverDir = bundledServerExecutable != null
          ? File(bundledServerExecutable).parent.path
          : '$root${Platform.pathSeparator}$_serverFolder';
      final rootPackageJson = File(
        '$serverDir${Platform.pathSeparator}package.json',
      );
      final distDir = Directory(
        '$serverDir${Platform.pathSeparator}dist',
      );
      final distEntrypoint = File(
        '$serverDir${Platform.pathSeparator}dist${Platform.pathSeparator}index.js',
      );
      final distPackageJson = File(
        '$serverDir${Platform.pathSeparator}dist${Platform.pathSeparator}package.json',
      );
      final hasRootPackageJson = rootPackageJson.existsSync();
      final hasDistEntrypoint = distEntrypoint.existsSync();
      final hasDistPackageJson = distPackageJson.existsSync();
      final isDistOnlyRuntime =
          !hasRootPackageJson && hasDistEntrypoint && hasDistPackageJson;
      onLog('Starting local server... ($_serverFolder)');

      if (bundledServerExecutable == null &&
          !hasRootPackageJson &&
          !isDistOnlyRuntime) {
        onLog(
          'package.json not found and dist runtime is incomplete: $serverDir',
        );
        return false;
      }

      // Only install and build if strictly necessary (usually dev environments)
      if (bundledServerExecutable == null &&
          !isDistOnlyRuntime &&
          !Directory(
            '$serverDir${Platform.pathSeparator}node_modules',
          ).existsSync()) {
        try {
          onLog('Running npm install...');
          final npmResult = await Process.run(_npmExecutable, [
            'install',
          ], workingDirectory: serverDir);
          if (npmResult.exitCode != 0) {
            onErrorLog(npmResult.stderr.toString());
            // Continue anyway, maybe node_modules is there but npm failed
          }
        } catch (e) {
          onLog('Skipping npm install as npm is not available: $e');
        }
      }

      if (bundledServerExecutable == null &&
          !isDistOnlyRuntime &&
          (kDebugMode ||
              !Directory(
                '$serverDir${Platform.pathSeparator}dist',
              ).existsSync() ||
              !File(
                '$serverDir${Platform.pathSeparator}dist${Platform.pathSeparator}index.js',
              ).existsSync())) {
        try {
          onLog('Running build...');
          final buildResult = await Process.run(_nodeExecutable, [
            'scripts/build.mjs',
          ], workingDirectory: serverDir);
          if (buildResult.exitCode != 0) {
            onErrorLog(buildResult.stderr.toString());
            return false;
          }
        } catch (e) {
          onErrorLog('Failed to run build: $e');
          return false;
        }
      }

      if (bundledServerExecutable != null) {
        _process = await Process.start(
          bundledServerExecutable,
          [],
          workingDirectory: serverDir,
          environment: {
            'PORT': ConfigRepository().port.toString(),
            'MODE': mode ?? (kDebugMode ? 'development' : 'production'),
            'VERSION': version ?? '0.0.0',
            'ARI_SERVER_ROOT': serverDir,
            'ARI_WORKSPACE_ROOT': root,
            'NODE_PATH': p.join(serverDir, 'node_modules'),
            ...Platform.environment,
          },
        );
      } else {
        final serverScript = distEntrypoint.path;
        if (!hasDistEntrypoint) {
          onErrorLog('Built entrypoint not found: $serverScript');
          return false;
        }

        _process = await Process.start(
          _nodeExecutable,
          ['dist/index.js'],
          workingDirectory: serverDir,
          environment: {
            'PORT': ConfigRepository().port.toString(),
            'MODE': mode ?? (kDebugMode ? 'development' : 'production'),
            'VERSION': version ?? '0.0.0',
            'ARI_SERVER_ROOT': serverDir,
            'ARI_WORKSPACE_ROOT': root,
            ...Platform.environment,
          },
        );
      }

      _process!.stdout.transform(systemEncoding.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onLog(line.trim());
          }
        }
      });

      _process!.stderr.transform(systemEncoding.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onErrorLog(line.trim());
          }
        }
      });

      _process!.exitCode.then((code) {
        onExit(code);
        _process = null;
      });

      await Future.delayed(const Duration(seconds: 3));
      try {
        final ws = await WebSocket.connect(ConfigRepository().wsUrl);
        await ws.close();
        onLog('Local server is reachable.');
        return true;
      } catch (_) {
        return _process != null;
      }
    } catch (error) {
      onErrorLog('Failed to start server: $error');
      return false;
    }
  }

  Future<void> stopServer(Function(String) onLog) async {
    onLog('Stopping local server...');
    if (_process != null) {
      _process!.kill(
        Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigterm,
      );
      await Future.delayed(const Duration(seconds: 2));
      _process?.kill(ProcessSignal.sigkill);
      _process = null;
    }
    await killExistingServer();
    onLog('Local server stopped.');
  }

  void dispose() => _process?.kill();
}
