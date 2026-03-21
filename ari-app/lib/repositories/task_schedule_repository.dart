import 'package:ari_agent/models/scheduled_task.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 예정된 작업의 CRUD를 처리하는 Hive 기반 레포지토리
class TaskScheduleRepository {
  static const String _boxName = kDebugMode
      ? 'scheduled_tasks_test'
      : 'scheduled_tasks';
  late Box<Map> _box;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<Map>(_boxName);
    _initialized = true;
    debugPrint('[TaskScheduleRepository] 초기화 완료. ${_box.length}개 작업');
  }

  List<ScheduledTask> getAllTasks() {
    return _box.values
        .map((m) => ScheduledTask.fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  ScheduledTask? getTask(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return ScheduledTask.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> saveTask(ScheduledTask task) async {
    await _box.put(task.id, task.toMap());
  }

  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }
}
