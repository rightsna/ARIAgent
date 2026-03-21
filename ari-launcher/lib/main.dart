import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const LauncherApp());
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARIAgent',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      ),
      debugShowCheckedModeBanner: false,
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  static const String _launcherInstallFolderName = 'ARIAgent Launcher';
  static const String _launcherExecutableName = 'ARI_Launcher.exe';
  static const String _appInstallFolderName = 'ARIAgent';

  String _statusMessage = 'Checking for updates...';
  double _progress = 0.0;
  bool _isDownloading = false;

  final String updateFeedUrl = const String.fromEnvironment(
    'ARI_UPDATE_FEED_URL',
    defaultValue: 'https://ariwith.me/version.json',
  );

  @override
  void initState() {
    super.initState();
    _checkAndUpdate();
  }

  String? get _localAppDataDir => Platform.environment['LOCALAPPDATA'];

  String? get _homeDir =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  String get _launcherInstallDir {
    final localAppData = _localAppDataDir;
    if (localAppData == null || localAppData.isEmpty) {
      throw Exception('Could not determine LocalAppData.');
    }
    return '$localAppData\\Programs\\$_launcherInstallFolderName';
  }

  String get _installedLauncherPath =>
      '$_launcherInstallDir\\$_launcherExecutableName';

  String get _windowsAppBaseDir {
    final localAppData = _localAppDataDir;
    if (localAppData == null || localAppData.isEmpty) {
      throw Exception('Could not determine LocalAppData.');
    }
    return '$localAppData\\Programs\\$_appInstallFolderName\\app-versions';
  }

  String get _installedExecutableRelativePath {
    if (Platform.isWindows) {
      return 'AriAgent.exe';
    }
    return 'AriAgent.app/Contents/MacOS/AriAgent';
  }

  String get _downloadPlatformKey {
    if (Platform.isWindows) {
      return 'windows';
    }
    return 'macos';
  }

  String _installedExecutablePath(String latestDir) {
    return '$latestDir/$_installedExecutableRelativePath';
  }

  Map<String, dynamic> _readPlatformMetadata(Map<String, dynamic> decoded) {
    final platforms = decoded['platforms'];
    if (platforms is Map<String, dynamic>) {
      final platformData = platforms[_downloadPlatformKey];
      if (platformData is Map<String, dynamic>) {
        return platformData;
      }
    }
    return const <String, dynamic>{};
  }

  Future<void> _checkAndUpdate() async {
    try {
      if (Platform.isWindows) {
        final relaunched = await _ensureWindowsLauncherInstalled();
        if (relaunched) {
          return;
        }
      }

      final homeDir = _homeDir;
      final baseDirPath = Platform.isWindows
          ? _windowsAppBaseDir
          : (() {
              if (homeDir == null || homeDir.isEmpty) {
                throw Exception('Could not determine the home directory.');
              }
              return '$homeDir/.ari-agent/app-versions';
            })();
      final baseDir = Directory(baseDirPath);
      final latestDir = Directory('${baseDir.path}/latest');

      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      final localVersionCode = prefs.getInt('local_version_code') ?? 0;

      setState(() {
        _statusMessage = 'Checking the update feed...';
      });

      final response = await http.get(Uri.parse(updateFeedUrl));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load the update feed. (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final platformMetadata = _readPlatformMetadata(decoded);
      final remoteVersionCode =
          int.tryParse(
            platformMetadata['versionCode']?.toString() ??
                decoded['versionCode']?.toString() ??
                '0',
          ) ??
          0;

      final installedExecutable = File(
        _installedExecutablePath(latestDir.path),
      );
      final needsUpdate =
          remoteVersionCode > localVersionCode ||
          !installedExecutable.existsSync();

      if (needsUpdate) {
        final downloads = decoded['downloads'] as Map<String, dynamic>? ?? {};
        final downloadEntry = downloads[_downloadPlatformKey];
        final downloadUrlRaw =
            platformMetadata['url']?.toString() ??
            (downloadEntry is Map<String, dynamic>
                ? downloadEntry['url']?.toString()
                : null);

        if (downloadUrlRaw == null || downloadUrlRaw.isEmpty) {
          throw Exception('No download URL is available for this platform.');
        }

        final feedUri = Uri.parse(updateFeedUrl);
        final parsedUrl = Uri.tryParse(downloadUrlRaw);
        final finalUrl = (parsedUrl != null && parsedUrl.hasScheme)
            ? parsedUrl.toString()
            : feedUri.resolve(downloadUrlRaw).toString();

        await _downloadAndExtract(finalUrl, baseDir.path, latestDir.path);
        await prefs.setInt('local_version_code', remoteVersionCode);
      }

      if (!File(_installedExecutablePath(latestDir.path)).existsSync()) {
        throw Exception('Installed executable was not found after update.');
      }

      await _launchApp(latestDir.path);
    } catch (error) {
      setState(() {
        _statusMessage = 'Update error: $error\nTrying the last installed app.';
        _isDownloading = false;
      });
      try {
        final fallbackHomeDir = _homeDir;
        if (!Platform.isWindows &&
            (fallbackHomeDir == null || fallbackHomeDir.isEmpty)) {
          return;
        }
        final latestDir = Directory(
          '${Platform.isWindows ? _windowsAppBaseDir : '$fallbackHomeDir/.ari-agent/app-versions'}/latest',
        );
        if (File(
          '${latestDir.path}/$_installedExecutableRelativePath',
        ).existsSync()) {
          await Future.delayed(const Duration(seconds: 3));
          await _launchApp(latestDir.path);
        }
      } catch (_) {}
    }
  }

  Future<void> _downloadAndExtract(
    String url,
    String baseDir,
    String latestDir,
  ) async {
    setState(() {
      _statusMessage = 'Downloading the latest version...';
      _isDownloading = true;
      _progress = 0.0;
    });

    if (!url.toLowerCase().endsWith('.zip')) {
      throw Exception(
        'Automatic installation currently supports zip packages only.',
      );
    }

    final zipFile = File('$baseDir/update.zip');
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Download failed. (${response.statusCode})');
    }

    final totalBytes = response.contentLength ?? 0;
    var receivedBytes = 0;
    final sink = zipFile.openWrite();

    await for (final chunk in response.stream) {
      receivedBytes += chunk.length;
      sink.add(chunk);
      if (totalBytes > 0) {
        setState(() {
          _progress = receivedBytes / totalBytes;
        });
      }
    }
    await sink.flush();
    await sink.close();

    setState(() {
      _statusMessage = 'Extracting the update...';
      _isDownloading = false;
    });

    final latestDirectory = Directory(latestDir);
    final stagingDir = Directory('$baseDir/latest_staging');
    final backupDir = Directory('$baseDir/latest_backup');

    if (stagingDir.existsSync()) {
      stagingDir.deleteSync(recursive: true);
    }
    stagingDir.createSync(recursive: true);

    try {
      if (Platform.isWindows) {
        await _extractZipOnWindows(zipFile.path, stagingDir.path);
      } else {
        await _extractZipOnMac(zipFile.path, stagingDir.path);
      }

      final stagedExecutable = File(_installedExecutablePath(stagingDir.path));
      if (!stagedExecutable.existsSync()) {
        throw Exception(
          'The extracted package does not contain the app executable.',
        );
      }

      if (backupDir.existsSync()) {
        backupDir.deleteSync(recursive: true);
      }

      if (latestDirectory.existsSync()) {
        latestDirectory.renameSync(backupDir.path);
      }

      stagingDir.renameSync(latestDirectory.path);

      if (backupDir.existsSync()) {
        backupDir.deleteSync(recursive: true);
      }
    } catch (_) {
      if (latestDirectory.existsSync()) {
        latestDirectory.deleteSync(recursive: true);
      }
      if (backupDir.existsSync()) {
        backupDir.renameSync(latestDirectory.path);
      }
      rethrow;
    } finally {
      if (stagingDir.existsSync()) {
        stagingDir.deleteSync(recursive: true);
      }
    }

    if (zipFile.existsSync()) {
      zipFile.deleteSync();
    }
  }

  Future<bool> _ensureWindowsLauncherInstalled() async {
    final currentExecutable = File(Platform.resolvedExecutable);
    final currentDir = currentExecutable.parent;
    final installedExecutable = File(_installedLauncherPath);
    final installedDir = Directory(_launcherInstallDir);

    final currentDirPath = currentDir.absolute.path.toLowerCase();
    final installedDirPath = installedDir.absolute.path.toLowerCase();
    if (currentDirPath == installedDirPath) {
      return false;
    }

    setState(() {
      _statusMessage = 'Installing launcher for Windows...';
    });

    if (installedDir.existsSync()) {
      installedDir.deleteSync(recursive: true);
    }
    installedDir.createSync(recursive: true);

    await _copyDirectory(currentDir, installedDir);
    await _createWindowsShortcuts(installedExecutable.path);

    if (!installedExecutable.existsSync()) {
      throw Exception(
        'Installed launcher executable was not found at ${installedExecutable.path}.',
      );
    }

    await Process.start(
      installedExecutable.path,
      const [],
      mode: ProcessStartMode.detached,
      workingDirectory: installedDir.path,
    );
    exit(0);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      final targetPath = '${destination.path}${Platform.pathSeparator}$name';

      if (entity is Directory) {
        final newDirectory = Directory(targetPath);
        if (!newDirectory.existsSync()) {
          newDirectory.createSync(recursive: true);
        }
        await _copyDirectory(entity, newDirectory);
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  Future<void> _createWindowsShortcuts(String launcherPath) async {
    final appData = Platform.environment['APPDATA'];
    final userProfile = Platform.environment['USERPROFILE'];
    if (appData == null ||
        appData.isEmpty ||
        userProfile == null ||
        userProfile.isEmpty) {
      return;
    }

    final startMenuDir = Directory(
      '$appData\\Microsoft\\Windows\\Start Menu\\Programs',
    );
    final desktopDir = Directory('$userProfile\\Desktop');

    if (!startMenuDir.existsSync()) {
      startMenuDir.createSync(recursive: true);
    }
    if (!desktopDir.existsSync()) {
      desktopDir.createSync(recursive: true);
    }

    final startMenuShortcut = '${startMenuDir.path}\\ARIAgent.lnk';
    final desktopShortcut = '${desktopDir.path}\\ARIAgent.lnk';

    await _createWindowsShortcut(shortcutPath: startMenuShortcut, targetPath: launcherPath);
    await _createWindowsShortcut(shortcutPath: desktopShortcut, targetPath: launcherPath);
  }

  Future<void> _createWindowsShortcut({
    required String shortcutPath,
    required String targetPath,
  }) async {
    final escapedShortcutPath = shortcutPath.replaceAll("'", "''");
    final escapedTargetPath = targetPath.replaceAll("'", "''");
    final escapedWorkingDir = File(targetPath).parent.path.replaceAll(
      "'",
      "''",
    );

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      r"$ws = New-Object -ComObject WScript.Shell; " +
          r"$shortcut = $ws.CreateShortcut('" +
          escapedShortcutPath +
          r"'); " +
          r"$shortcut.TargetPath = '" +
          escapedTargetPath +
          r"'; " +
          r"$shortcut.WorkingDirectory = '" +
          escapedWorkingDir +
          r"'; " +
          r"$shortcut.IconLocation = '" +
          escapedTargetPath +
          r",0'; " +
          r"$shortcut.Save()",
    ]);

    if (result.exitCode != 0) {
      throw Exception('Shortcut creation failed: ${result.stderr}');
    }
  }

  Future<void> _extractZipOnWindows(String zipPath, String outputDir) async {
    final escapedZipPath = zipPath.replaceAll("'", "''");
    final escapedOutputDir = outputDir.replaceAll("'", "''");
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      "Expand-Archive -LiteralPath '$escapedZipPath' -DestinationPath '$escapedOutputDir' -Force",
    ]);
    if (result.exitCode != 0) {
      throw Exception('Extraction failed: ${result.stderr}');
    }
  }

  Future<void> _extractZipOnMac(String zipPath, String outputDir) async {
    final unzipResult = await Process.run('unzip', [
      '-o',
      '-q',
      zipPath,
      '-d',
      outputDir,
    ]);
    if (unzipResult.exitCode != 0) {
      throw Exception('Extraction failed: ${unzipResult.stderr}');
    }
  }

  Future<void> _launchApp(String latestDir) async {
    setState(() {
      _statusMessage = 'Launching ARIAgent...';
    });

    if (Platform.isWindows) {
      final exePath = '$latestDir/AriAgent.exe';
      if (!File(exePath).existsSync()) {
        throw Exception('Executable not found: $exePath');
      }
      await Process.start(exePath, const [], mode: ProcessStartMode.detached);
      exit(0);
    }

    final appPath = '$latestDir/AriAgent.app';
    await Process.start('open', [appPath], mode: ProcessStartMode.detached);
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.sparkles, size: 80, color: Colors.white),
            const SizedBox(height: 32),
            const Text(
              'ARIAgent',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_isDownloading)
              SizedBox(
                width: 250,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                    minHeight: 6,
                  ),
                ),
              )
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
