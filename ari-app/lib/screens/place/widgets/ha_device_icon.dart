import 'package:flutter/material.dart';
import '../models/ha_device_item.dart';

class HADeviceIcon extends StatelessWidget {
  final HADeviceItem item;
  final VoidCallback? onTap;

  const HADeviceIcon({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final name = item.name;
    final type = item.type;
    final state = item.state;
    final isOn = item.isOn;

    IconData icon;
    Color color;

    switch (type) {
      case 'light':
        icon = Icons.lightbulb;
        color = Colors.yellow;
        break;
      case 'switch':
        icon = Icons.power;
        color = Colors.green;
        break;
      case 'media_player':
        icon = Icons.play_circle_filled;
        color = Colors.blue;
        break;
      case 'climate':
        icon = Icons.ac_unit;
        color = Colors.cyan;
        break;
      case 'fan':
        icon = Icons.cyclone;
        color = Colors.teal;
        break;
      case 'cover':
        icon = Icons.window;
        color = Colors.brown;
        break;
      default:
        icon = Icons.settings_remote;
        color = Colors.grey;
    }

    return Tooltip(
      message: '$name ($state)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isOn ? color : Colors.grey).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: (isOn ? color : Colors.grey).withOpacity(0.6),
                width: 2,
              ),
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: isOn ? color : Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
