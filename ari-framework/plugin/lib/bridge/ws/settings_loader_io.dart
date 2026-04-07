import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>?> loadAriAgentSettings() async {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;

  final file = File('$home/.ari-agent/settings.json');
  if (!await file.exists()) return null;

  final raw = await file.readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) {
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  return null;
}
