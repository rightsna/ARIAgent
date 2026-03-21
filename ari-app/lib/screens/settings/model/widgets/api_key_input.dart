import 'package:flutter/material.dart';
import '../provider_meta.dart';

class ApiKeyInput extends StatefulWidget {
  final ProviderItem item;
  final VoidCallback onChanged;

  const ApiKeyInput({super.key, required this.item, required this.onChanged});

  @override
  State<ApiKeyInput> createState() => _ApiKeyInputState();
}

class _ApiKeyInputState extends State<ApiKeyInput> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111122),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: item.apiKeyController,
              obscureText: item.apiKeyObscured,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'API Key 입력 (sk-...)',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onTap: () {
                if (item.apiKeyController.text.contains('••')) {
                  item.apiKeyController.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: Icon(
              item.apiKeyObscured ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
            onPressed: () {
              setState(() => item.apiKeyObscured = !item.apiKeyObscured);
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }
}
