import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int versionCode;
  final bool mandatory;
  final String notes;
  final String releasedAt;
  final String? macosUrl;
  final String? windowsUrl;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.mandatory,
    required this.notes,
    required this.releasedAt,
    this.macosUrl,
    this.windowsUrl,
  });

  static const String ariCdnBaseUrl = 'https://d34z72svq84n71.cloudfront.net';

  String? downloadUrlForCurrentPlatform({bool full = true}) {
    String? url;
    if (Platform.isMacOS) {
      url = macosUrl;
    } else if (Platform.isWindows) {
      url = windowsUrl;
    }

    if (url != null && full && !url.startsWith('http')) {
      return '$ariCdnBaseUrl/${url.startsWith('/') ? url.substring(1) : url}';
    }
    return url;
  }
}

class AppUpdateService {
  final String feedUrl;
  
  const AppUpdateService({required this.feedUrl});

  String get _platformKey {
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    return '';
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (feedUrl.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(feedUrl);
    if (uri == null) {
      return null;
    }

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final platformMetadata = _readPlatformMetadata(decoded);

      final latestVersion =
          platformMetadata['latestVersion']?.toString().trim().isNotEmpty == true
          ? platformMetadata['latestVersion'].toString().trim()
          : decoded['latestVersion']?.toString().trim().isNotEmpty == true
          ? decoded['latestVersion'].toString().trim()
          : null;
          
      final versionCode =
          int.tryParse(
            platformMetadata['versionCode']?.toString() ??
                decoded['versionCode']?.toString() ??
                '',
          ) ??
          currentVersionCode;

      if (latestVersion == null) {
        return null;
      }

      final versionComparison = _compareVersions(latestVersion, currentVersion);
      final hasUpdate =
          versionComparison > 0 ||
          (versionComparison == 0 && versionCode > currentVersionCode);

      if (!hasUpdate) {
        return null;
      }

      final downloads = decoded['downloads'] is Map<String, dynamic>
          ? decoded['downloads'] as Map<String, dynamic>
          : const <String, dynamic>{};

      return AppUpdateInfo(
        latestVersion: latestVersion,
        versionCode: versionCode,
        mandatory:
            platformMetadata['mandatory'] == true ||
            decoded['mandatory'] == true,
        notes:
            platformMetadata['notes']?.toString() ??
            decoded['notes']?.toString() ??
            '',
        releasedAt:
            platformMetadata['releasedAt']?.toString() ??
            decoded['releasedAt']?.toString() ??
            '',
        macosUrl: _readPlatformDownloadUrl(uri, 'macos', decoded, downloads),
        windowsUrl: _readPlatformDownloadUrl(uri, 'windows', decoded, downloads),
      );
    } catch (_) {
      return null;
    }
  }

  String? _readDownloadUrl(Uri feedUri, dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final value = raw['url']?.toString().trim();
      if (value != null && value.isNotEmpty) {
        final parsed = Uri.tryParse(value);
        if (parsed == null) {
          return null;
        }
        return parsed.hasScheme
            ? parsed.toString()
            : feedUri.resolveUri(parsed).toString();
      }
    }
    return null;
  }

  Map<String, dynamic> _readPlatformMetadata(Map<String, dynamic> decoded) {
    if (_platformKey.isEmpty) {
      return const <String, dynamic>{};
    }

    final platforms = decoded['platforms'];
    if (platforms is Map<String, dynamic>) {
      final platformData = platforms[_platformKey];
      if (platformData is Map<String, dynamic>) {
        return platformData;
      }
    }

    return const <String, dynamic>{};
  }

  String? _readPlatformDownloadUrl(
    Uri feedUri,
    String platformKey,
    Map<String, dynamic> decoded,
    Map<String, dynamic> downloads,
  ) {
    final platforms = decoded['platforms'];
    if (platforms is Map<String, dynamic>) {
      final platformData = platforms[platformKey];
      final url = _readDownloadUrl(feedUri, platformData);
      if (url != null) {
        return url;
      }
    }
    return _readDownloadUrl(feedUri, downloads[platformKey]);
  }

  int _compareVersions(String left, String right) {
    final leftParts = _normalizeParts(left);
    final rightParts = _normalizeParts(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var i = 0; i < maxLength; i++) {
      final leftValue = i < leftParts.length ? leftParts[i] : 0;
      final rightValue = i < rightParts.length ? rightParts[i] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  List<int> _normalizeParts(String value) {
    final sanitized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return sanitized
        .split('.')
        .map((part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '0') ?? 0)
        .toList();
  }
}
