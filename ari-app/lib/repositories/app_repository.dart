import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// AppRepository: ~/.ari-agent/skills 폴더를 직접 스캔하여 설치된 앱 목록을 관리합니다.
class AppRepository {
  static final AppRepository _instance = AppRepository._internal();
  factory AppRepository() => _instance;
  AppRepository._internal();

  String get _skillsDirPath {
    final String home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.ari-agent', 'skills');
  }

  /// 설치된 앱(커스텀 스킬) 목록을 폴더에서 직접 읽어옵니다.
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final dir = Directory(_skillsDirPath);
      if (!await dir.exists()) {
        debugPrint('[AppRepository] Skills directory not found: $_skillsDirPath');
        return [];
      }

      final List<Map<String, dynamic>> apps = [];
      final List<FileSystemEntity> entities = dir.listSync();

      for (final entity in entities) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          final infoFile = File(p.join(entity.path, 'app_info.json'));
          final skillFile = File(p.join(entity.path, 'SKILL.md'));
          final iconFile = File(p.join(entity.path, 'icon.png'));
          
          String title = folderName;
          String? icon;
          String? iconPath;
          String? description;

          // 0. icon.png 파일 존재 여부 확인 (최우선 경로)
          if (await iconFile.exists()) {
            iconPath = iconFile.path;
          }

          // 1. app_info.json에서 기본 정보를 가져옵니다 (최우선)
          if (await infoFile.exists()) {
            try {
              final infoContent = await infoFile.readAsString();
              final Map<String, dynamic> info = jsonDecode(infoContent);
              title = info['name'] ?? folderName;
              description = info['description'];
              // JSON에 icon 필드가 있다면 문자열 아이콘 값으로 사용
              if (info['icon'] != null) {
                icon = info['icon'];
              }
            } catch (e) {
              debugPrint('[AppRepository] Error parsing app_info.json in $folderName: $e');
            }
          }

          // 2. SKILL.md에서 추가 정보를 보완합니다.
          if (await skillFile.exists()) {
            final content = await skillFile.readAsString();
            // JSON에 없는 경우에만 파싱하여 채움
            if (title == folderName) {
               title = _parseTitle(content) ?? folderName;
            }
            if (icon == null) {
              icon = _parseIcon(content);
            }
            if (description == null) {
              description = _parseDescription(content);
            }
          }

          apps.add({
            'id': folderName,
            'title': title,
            'icon': icon,
            'iconPath': iconPath,
            'description': description,
            'isCustom': true,
          });
        }
      }
      
      // 제목 순으로 정렬
      apps.sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
      return apps;
    } catch (e) {
      debugPrint('[AppRepository] Error scanning skills: $e');
      return [];
    }
  }

  /// SKILL.md에서 "Icon: <name>" 패턴을 찾아 파싱합니다.
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
          trimmed.toLowerCase().startsWith('사용 도구:')) continue;
      return trimmed;
    }
    return null;
  }
}
