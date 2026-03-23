class Response {
  Response({required this.d, required this.m, required this.r});

  bool r;
  String m;
  Object d;

  Response.fromJson(Map<String, dynamic> json)
    : r = _safeBool(json['ok']),
      m = _safeString(json['message'] ?? json['error']),
      d = json['data'] ?? {};

  static bool _safeBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'ok' || lower == 'true' || lower == '1') return true;
      if (lower == 'err' || lower == 'false' || lower == '0') return false;
    }
    return false;
  }

  static String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) {
      try {
        return Uri.decodeFull(value);
      } catch (_) {
        return value;
      }
    }
    return value.toString();
  }
}
