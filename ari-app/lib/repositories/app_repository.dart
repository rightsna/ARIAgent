import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// AppRepository: 설치된 앱 폴더를 직접 스캔하여 목록을 관리합니다.
class AppRepository {
  static final AppRepository _instance = AppRepository._internal();
  factory AppRepository() => _instance;
  AppRepository._internal();

  String get _homePath {
    final String home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return home;
  }

  String get _appsDirPath {
    return p.join(_homePath, '.ari-agent', 'apps');
  }

  String get _legacySkillsDirPath {
    return p.join(_homePath, '.ari-agent', 'skills');
  }

  /// 설치된 앱 목록을 폴더에서 직접 읽어옵니다.
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final directories = [
        Directory(_legacySkillsDirPath),
        Directory(_appsDirPath),
      ];
      final Map<String, Map<String, dynamic>> appsById = {};

      for (final dir in directories) {
        if (!await dir.exists()) {
          debugPrint('[AppRepository] App directory not found: ${dir.path}');
          continue;
        }

        final List<FileSystemEntity> entities = dir.listSync();

        for (final entity in entities) {
          if (entity is! Directory) continue;

          final folderName = p.basename(entity.path);
          final infoFile = File(p.join(entity.path, 'app_info.json'));
          final skillFile = File(p.join(entity.path, 'SKILL.md'));
          final iconFile = File(p.join(entity.path, 'icon.png'));

          String title = folderName;
          String? icon;
          String? iconPath;
          String? description;

          if (await iconFile.exists()) {
            iconPath = iconFile.path;
          }

          if (await infoFile.exists()) {
            try {
              final infoContent = await infoFile.readAsString();
              final Map<String, dynamic> info = jsonDecode(infoContent);
              title = info['name'] ?? folderName;
              description = info['description'];
              if (info['icon'] != null) {
                icon = info['icon'];
              }
            } catch (e) {
              debugPrint(
                '[AppRepository] Error parsing app_info.json in $folderName: $e',
              );
            }
          }

          if (await skillFile.exists()) {
            final content = await skillFile.readAsString();
            if (title == folderName) {
              title = _parseTitle(content) ?? folderName;
            }
            icon ??= _parseIcon(content);
            description ??= _parseDescription(content);
          }

          appsById[folderName] = {
            'id': folderName,
            'title': title,
            'icon': icon,
            'iconPath': iconPath,
            'description': description,
            'isCustom': true,
          };
        }
      }

      final apps = appsById.values.toList();

      // 제목 순으로 정렬
      apps.sort(
        (a, b) => (a['title'] as String).compareTo(b['title'] as String),
      );
      return apps;
    } catch (e) {
      debugPrint('[AppRepository] Error scanning app directories: $e');
      return [];
    }
  }

  /// `SKILL.md`에서 `Icon: <name>` 패턴을 찾아 파싱합니다.
  String? _parseIcon(String content) {
    final lines = content.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('icon:')) {
        return trimmed.substring(5).trim();
      }
    }
    return null;
  }

  /// SKILL.md의 첫 번째 H1(# )을 찾아 제목으로 사용합니다.
  String? _parseTitle(String content) {
    final match = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
    return match?.group(1)?.trim();
  }

  /// SKILL.md에서 첫 번째 의미 있는 문장을 찾아 설명으로 사용합니다.
  String? _parseDescription(String content) {
    final lines = content.split('\n');
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('#') ||
          trimmed.startsWith('```') ||
          trimmed.toLowerCase().startsWith('tools:') ||
          trimmed.toLowerCase().startsWith('사용 도구:')) {
        continue;
      }
      return trimmed;
    }
    return null;
  }
}
