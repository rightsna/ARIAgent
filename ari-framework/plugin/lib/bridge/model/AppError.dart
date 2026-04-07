class AppError implements Exception {
  final String code;
  final String message;

  AppError(this.code, this.message);

  @override
  String toString() => '$code: $message';

  factory AppError.wsError([String? msg]) {
    return AppError('ws_error', msg ?? 'Network communication failed.');
  }

  factory AppError.parseError([String? msg]) {
    return AppError('parse_error', msg ?? 'Failed to parse response data.');
  }

  factory AppError.timeout() {
    return AppError('timeout', 'Server response timed out.');
  }

  factory AppError.unknown([String? msg]) {
    return AppError('unknown_error', msg ?? 'An unknown error occurred.');
  }
}
