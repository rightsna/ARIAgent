import 'package:flutter/foundation.dart';

class LogProvider extends ChangeNotifier {
  // Singleton pattern for global access
  static final LogProvider _instance = LogProvider._internal();
  factory LogProvider() => _instance;
  LogProvider._internal();

  final List<String> _logs = [];
  String _lastReceivedCommand = '(None)';
  String _lastReceivedParams = '{}';
  
  /// Unmodifiable list of logs for UI display
  List<String> get logs => List.unmodifiable(_logs);

  String get lastReceivedCommand => _lastReceivedCommand;
  String get lastReceivedParams => _lastReceivedParams;

  /// Update the last received command and notify listeners
  void updateReceivedCommand(String command, String params) {
    _lastReceivedCommand = command;
    _lastReceivedParams = params;
    notifyListeners();
  }

  /// Add a new log entry and notify listeners
  void add(String msg) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.insert(0, '[$timestamp] $msg');
    
    // Keep only the last 50 logs
    if (_logs.length > 50) {
      _logs.removeLast();
    }
    
    notifyListeners();
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
