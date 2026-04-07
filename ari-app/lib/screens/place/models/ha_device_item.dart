import 'package:flutter/material.dart';

class HADeviceItem {
  final Map<String, dynamic> rawData;
  final Offset position;

  HADeviceItem({
    required this.rawData,
    required this.position,
  });

  String get id => rawData['id'] as String;
  String get name => rawData['name'] ?? 'Device';
  String get type => rawData['type'] ?? 'unknown';
  String get state => rawData['state'] ?? 'off';
  bool get isOn => state != 'off' && state != 'unavailable';

  HADeviceItem copyWith({
    Map<String, dynamic>? rawData,
    Offset? position,
  }) {
    return HADeviceItem(
      rawData: rawData ?? this.rawData,
      position: position ?? this.position,
    );
  }
}
