import 'package:flutter/material.dart';

class SettingsDropdown extends StatelessWidget {
  final String value;
  final List<DropdownMenuItem<String>> items;
  final Function(String?) onChanged;

  const SettingsDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF111122),
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        icon: Icon(
          Icons.expand_more,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
