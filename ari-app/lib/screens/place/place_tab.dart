import 'dart:math';

import 'package:ari_agent/providers/avatar_provider.dart';
import 'package:ari_agent/providers/chat_provider.dart';
import 'package:ari_agent/providers/task_provider.dart';
import 'package:ari_agent/providers/config_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/place_avatar.dart';
import 'models/ha_device_item.dart';
import 'widgets/agent_avatar.dart';
import 'widgets/ha_device_icon.dart';
import 'widgets/ha_registration_sheet.dart';

class PlaceTab extends StatefulWidget {
  const PlaceTab({super.key});

  @override
  State<PlaceTab> createState() => _PlaceTabState();
}

class _PlaceTabState extends State<PlaceTab> {
  final Random _random = Random();
  final Map<String, Offset> _avatarPositions = {};
  final Map<String, Offset> _devicePositions = {};
  List<Map<String, dynamic>> _haDevices = [];

  @override
  void initState() {
    super.initState();
    _loadHADevices();
  }

  Future<void> _loadHADevices() async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final devices = await configProvider.getHADevices();
    if (devices != null && mounted) {
      setState(() {
        _haDevices = devices;
        for (final device in _haDevices) {
          _devicePositions.putIfAbsent(device['id'] as String, () => _randomDevicePosition());
        }
      });
    }
  }

  Offset _randomDevicePosition() => Offset(0.05 + _random.nextDouble() * 0.9, 0.15 + _random.nextDouble() * 0.45);
  Offset _randomPosition() => Offset(0.12 + _random.nextDouble() * 0.76, 0.6 + _random.nextDouble() * 0.22);

  @override
  Widget build(BuildContext context) {
    final avatarProvider = context.watch<AvatarProvider>();
    final allProfiles = avatarProvider.allAvatars;
    final currentAvatarId = avatarProvider.currentAvatarId;
    final isWorking = context.watch<ChatProvider>().isLoading;
    final taskProvider = context.watch<TaskProvider>();

    // 로직 호출을 모델 클래스에서 직접 수행
    final scheduledIds = PlaceAvatar.getScheduledWorkingIds(taskProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final avatars = allProfiles.map((profile) {
          _avatarPositions.putIfAbsent(profile.id, () => _seededPosition(_avatarPositions.length, allProfiles.length));
          return PlaceAvatar(
            profile: profile,
            position: _avatarPositions[profile.id]!,
            status: PlaceAvatar.calculateStatus(
              avatarId: profile.id,
              currentAvatarId: currentAvatarId,
              isWorking: isWorking,
              scheduledWorkingIds: scheduledIds,
            ),
          );
        }).toList();

        final devices = _haDevices.map((d) => HADeviceItem(
          rawData: d,
          position: _devicePositions[d['id']] ?? const Offset(0.5, 0.3),
        )).toList();

        return Stack(
          children: [
            Positioned.fill(child: Image.asset('assets/images/room.png', fit: BoxFit.cover)),
            ...devices.map((device) => Positioned(
              left: constraints.maxWidth * device.position.dx - 20,
              top: constraints.maxHeight * device.position.dy - 20,
              child: HADeviceIcon(
                item: device,
                onTap: () async {
                  final configProvider = Provider.of<ConfigProvider>(context, listen: false);
                  final success = await configProvider.controlHADevice(device.id, 'toggle', domain: device.type);
                  if (success) {
                    _loadHADevices();
                  }
                },
              ),
            )),
            ...avatars.map((avatar) => Positioned(
              left: constraints.maxWidth * avatar.position.dx - 48,
              top: constraints.maxHeight * avatar.position.dy - 62,
              child: AgentAvatar(item: avatar),
            )),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: const Color(0xFF6C63FF).withOpacity(0.8),
                onPressed: () => setState(() {
                  for (final id in _avatarPositions.keys) _avatarPositions[id] = _randomPosition();
                  for (final id in _devicePositions.keys) _devicePositions[id] = _randomDevicePosition();
                }),
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: FloatingActionButton(
                heroTag: 'ha_connect',
                backgroundColor: const Color(0xFFFF5722).withOpacity(0.8),
                onPressed: () => _startHAConnection(context).then((_) => _loadHADevices()),
                child: const Icon(Icons.home_filled, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _seededPosition(int index, int total) {
    if (total <= 1) return const Offset(0.5, 0.72);
    final x = (0.15 + (0.7 / (total - 1) * index)).clamp(0.15, 0.85);
    final y = (0.66 + ((index % 2) * 0.08)).clamp(0.6, 0.82);
    return Offset(x, y);
  }

  Future<void> _startHAConnection(BuildContext context) async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final existing = await configProvider.getHACredentials();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HARegistrationSheet(
        existing: existing,
        onSubmit: (url, token) {
          Navigator.pop(context);
          _submitHARegistration(context, url, token);
        },
      ),
    );
  }

  Future<void> _submitHARegistration(BuildContext context, String url, String token) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orange)));
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final result = await configProvider.saveHACredentials(url, token);
    if (!context.mounted) return;
    Navigator.pop(context);
    if (result['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Home Assistant 서버 연동에 성공했습니다.'), backgroundColor: Colors.green));
    } else {
      showDialog(context: context, builder: (context) => AlertDialog(title: const Text('연동 실패'), content: Text(result['error'] ?? '알 수 없는 오류가 발생했습니다.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))]));
    }
  }
}
