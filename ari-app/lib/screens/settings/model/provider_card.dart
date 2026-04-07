import 'package:flutter/material.dart';
import 'provider_meta.dart';
import 'oauth/oauth_section.dart';
import 'widgets/api_key_input.dart';
import 'widgets/settings_dropdown.dart';

class ProviderCard extends StatefulWidget {
  final ProviderItem item;
  final int index;
  final int totalCount;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const ProviderCard({
    super.key,
    required this.item,
    required this.index,
    required this.totalCount,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard> {
  ProviderItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final meta = metaFor(item.provider);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildDropdownRow(meta),
          const SizedBox(height: 8),
          if (meta.isOAuth)
            OAuthSection(item: item)
          else
            ApiKeyInput(item: item, onChanged: () => setState(() {})),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Priority ${widget.index + 1}',
          style: const TextStyle(
            color: Color(0xFF6C63FF),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            if (widget.index > 0)
              GestureDetector(
                onTap: widget.onMoveUp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ),
            if (widget.index < widget.totalCount - 1)
              GestureDetector(
                onTap: widget.onMoveDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
              ),
            if (widget.totalCount > 1)
              GestureDetector(
                onTap: widget.onRemove,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 2.0),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownRow(ProviderMeta meta) {
    return Row(
      children: [
        Expanded(
          child: SettingsDropdown(
            value: item.provider,
            items: allProviders
                .map((m) => DropdownMenuItem(value: m.id, child: Text(m.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                final newMeta = metaFor(v);
                setState(() {
                  item.provider = v;
                  item.authType = newMeta.isOAuth ? 'oauth' : 'apikey';
                  item.model = newMeta.models.firstOrNull?.id ?? '';
                  item.oauthLoggedIn = false;
                  if (!newMeta.isOAuth) {
                    item.apiKeyController.clear();
                    item.hasApiKey = false;
                  }
                });
                widget.onChanged();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildModelDropdown(meta)),
      ],
    );
  }

  Widget _buildModelDropdown(ProviderMeta meta) {
    final models = meta.models.isNotEmpty
        ? meta.models
        : [ModelItem(id: item.model, label: item.model)];
    final currentModel = models.any((m) => m.id == item.model)
        ? item.model
        : models.first.id;
    return SettingsDropdown(
      value: currentModel,
      items: models
          .map((m) => DropdownMenuItem(value: m.id, child: Text(m.label)))
          .toList(),
      onChanged: (v) {
        if (v != null) {
          setState(() => item.model = v);
          widget.onChanged();
        }
      },
    );
  }
}
