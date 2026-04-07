import 'dart:io';
import 'package:flutter/material.dart';
import '../models/place_avatar.dart';

class AgentAvatar extends StatelessWidget {
  final PlaceAvatar item;

  const AgentAvatar({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final avatar = item.profile;
    final statusText = item.status;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF13132B),
            border: Border.all(color: const Color(0xFF6C63FF), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(child: _buildAvatarImage(avatar)),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 76, maxWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC13132B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avatar.name.trim().isEmpty ? 'ARI' : avatar.name.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage(dynamic avatar) {
    final imagePath = avatar.imagePath.toString().trim();
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/avatar.png',
          width: 96,
          height: 96,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(file, width: 96, height: 96, fit: BoxFit.cover);
      }
    }

    return Image.asset(
      'assets/images/avatar.png',
      width: 96,
      height: 96,
      fit: BoxFit.cover,
    );
  }
}
