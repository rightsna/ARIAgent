import 'package:flutter/material.dart';

// ─── 프로바이더 메타데이터 ───────────────────────────────────

class ModelItem {
  final String id;
  final String label;

  const ModelItem({required this.id, required this.label});
}

class ProviderMeta {
  final String id;
  final String label;
  final List<ModelItem> models;
  final bool isOAuth;

  const ProviderMeta({
    required this.id,
    required this.label,
    required this.models,
    this.isOAuth = false,
  });
}

const allProviders = [
  ProviderMeta(
    id: 'openai-codex',
    label: 'OpenAI Codex (OAuth)',
    models: [
      ModelItem(id: 'gpt-5.4-pro', label: 'gpt-5.4-pro'),
      ModelItem(id: 'gpt-5.4', label: 'gpt-5.4'),
      ModelItem(id: 'gpt-5.4-mini', label: 'gpt-5.4-mini'),
      ModelItem(id: 'gpt-5.3-codex', label: 'gpt-5.3-codex'),
      ModelItem(id: 'gpt-5.3-codex-spark', label: 'gpt-5.3-codex-spark'),
      ModelItem(id: 'gpt-5.2-codex', label: 'gpt-5.2-codex'),
      ModelItem(id: 'gpt-5.2', label: 'gpt-5.2'),
    ],
    isOAuth: true,
  ),
  ProviderMeta(
    id: 'openai',
    label: 'OpenAI',
    models: [
      ModelItem(id: 'gpt-5.4', label: 'gpt-5.4'),
      ModelItem(id: 'gpt-5.4-mini', label: 'gpt-5.4-mini'),
      ModelItem(id: 'gpt-5.2', label: 'gpt-5.2'),
      ModelItem(id: 'gpt-5.1', label: 'gpt-5.1'),
      ModelItem(id: 'gpt-5', label: 'gpt-5'),
      ModelItem(id: 'gpt-5-mini', label: 'gpt-5-mini'),
      ModelItem(id: 'gpt-4.1', label: 'gpt-4.1'),
      ModelItem(id: 'gpt-4.1-mini', label: 'gpt-4.1-mini'),
      ModelItem(id: 'gpt-4.1-nano', label: 'gpt-4.1-nano'),
      ModelItem(id: 'gpt-4o', label: 'gpt-4o'),
      ModelItem(id: 'gpt-4o-mini', label: 'gpt-4o-mini'),
      ModelItem(id: 'o3-pro', label: 'o3-pro'),
      ModelItem(id: 'o3', label: 'o3'),
      ModelItem(id: 'o1', label: 'o1'),
      ModelItem(id: 'o4-mini', label: 'o4-mini'),
    ],
  ),
  ProviderMeta(
    id: 'anthropic',
    label: 'Anthropic',
    models: [
      ModelItem(id: 'claude-opus-4-6', label: 'claude-opus-4-6'),
      ModelItem(id: 'claude-sonnet-4-6', label: 'claude-sonnet-4-6'),
      ModelItem(id: 'claude-haiku-4-5', label: 'claude-haiku-4-5'),
      ModelItem(
        id: 'claude-3-7-sonnet-latest',
        label: 'claude-3-7-sonnet-latest',
      ),
      ModelItem(
        id: 'claude-3-5-sonnet-latest',
        label: 'claude-3-5-sonnet-latest',
      ),
      ModelItem(
        id: 'claude-3-5-haiku-latest',
        label: 'claude-3-5-haiku-latest',
      ),
    ],
  ),
  ProviderMeta(
    id: 'google',
    label: 'Gemini',
    models: [
      ModelItem(id: 'gemini-3.1-pro-preview', label: 'gemini-3.1-pro-preview'),
      ModelItem(id: 'gemini-3-flash-preview', label: 'gemini-3-flash-preview'),
      ModelItem(id: 'gemini-2.5-pro', label: 'gemini-2.5-pro'),
      ModelItem(id: 'gemini-2.5-flash', label: 'gemini-2.5-flash'),
      ModelItem(id: 'gemini-2.5-flash-lite', label: 'gemini-2.5-flash-lite'),
    ],
  ),
  ProviderMeta(
    id: 'xai',
    label: 'xAI (Grok)',
    models: [
      ModelItem(id: 'grok-4', label: 'grok-4'),
      ModelItem(id: 'grok-4-fast', label: 'grok-4-fast'),
      ModelItem(id: 'grok-code-fast-1', label: 'grok-code-fast-1'),
      ModelItem(id: 'grok-3', label: 'grok-3'),
      ModelItem(id: 'grok-3-fast', label: 'grok-3-fast'),
      ModelItem(id: 'grok-3-mini', label: 'grok-3-mini'),
    ],
  ),
  ProviderMeta(
    id: 'groq',
    label: 'Groq',
    models: [
      ModelItem(
        id: 'llama-3.3-70b-versatile',
        label: 'llama-3.3-70b-versatile',
      ),
      ModelItem(id: 'llama-3.1-8b-instant', label: 'llama-3.1-8b-instant'),
    ],
  ),
  ProviderMeta(
    id: 'mistral',
    label: 'Mistral',
    models: [
      ModelItem(id: 'mistral-large-latest', label: 'mistral-large-latest'),
      ModelItem(id: 'mistral-medium-latest', label: 'mistral-medium-latest'),
      ModelItem(id: 'mistral-small-latest', label: 'mistral-small-latest'),
      ModelItem(id: 'codestral-latest', label: 'codestral-latest'),
    ],
  ),
  ProviderMeta(
    id: 'github-copilot',
    label: 'GitHub Copilot (OAuth)',
    models: [
      ModelItem(id: 'gpt-5.4', label: 'gpt-5.4'),
      ModelItem(id: 'gpt-5', label: 'gpt-5'),
      ModelItem(id: 'gpt-4.1', label: 'gpt-4.1'),
      ModelItem(id: 'gpt-4o', label: 'gpt-4o'),
      ModelItem(id: 'claude-sonnet-4.6', label: 'claude-sonnet-4.6'),
      ModelItem(id: 'claude-opus-4.6', label: 'claude-opus-4.6'),
      ModelItem(id: 'claude-sonnet-4', label: 'claude-sonnet-4'),
      ModelItem(id: 'claude-3.5-sonnet', label: 'claude-3.5-sonnet'),
      ModelItem(id: 'gemini-3.1-pro-preview', label: 'gemini-3.1-pro-preview'),
      ModelItem(id: 'gemini-3-flash-preview', label: 'gemini-3-flash-preview'),
      ModelItem(id: 'gemini-2.5-pro', label: 'gemini-2.5-pro'),
      ModelItem(id: 'gemini-2.0-flash-001', label: 'gemini-2.0-flash-001'),
      ModelItem(id: 'grok-code-fast-1', label: 'grok-code-fast-1'),
    ],
    isOAuth: true,
  ),
  ProviderMeta(
    id: 'google-gemini-cli',
    label: 'Google Gemini CLI (OAuth)',
    models: [
      ModelItem(id: 'gemini-3.1-pro-preview', label: 'gemini-3.1-pro-preview'),
      ModelItem(id: 'gemini-3-flash-preview', label: 'gemini-3-flash-preview'),
      ModelItem(id: 'gemini-2.5-pro', label: 'gemini-2.5-pro'),
      ModelItem(id: 'gemini-2.5-flash', label: 'gemini-2.5-flash'),
    ],
    isOAuth: true,
  ),
  ProviderMeta(
    id: 'deepseek',
    label: 'DeepSeek',
    models: [
      ModelItem(id: 'deepseek-v3.2', label: 'deepseek-v3.2'),
      ModelItem(id: 'deepseek-v3.1', label: 'deepseek-v3.1'),
      ModelItem(id: 'deepseek-v3', label: 'deepseek-v3'),
      ModelItem(id: 'deepseek-r1', label: 'deepseek-r1'),
    ],
  ),
  ProviderMeta(
    id: 'google-antigravity',
    label: 'Antigravity (OAuth)',
    models: [
      ModelItem(id: 'gemini-3.1-pro-high', label: 'gemini-3.1-pro-high'),
      ModelItem(id: 'gemini-3.1-pro-low', label: 'gemini-3.1-pro-low'),
      ModelItem(id: 'gemini-3-flash', label: 'gemini-3-flash'),
    ],
    isOAuth: true,
  ),
];

ProviderMeta metaFor(String id) => allProviders.firstWhere(
  (m) => m.id == id,
  orElse: () => ProviderMeta(id: id, label: id, models: []),
);

// ─── 프로바이더 아이템 (설정화면 내부 상태) ─────────────────

class ProviderItem {
  String provider;
  String model;
  bool hasApiKey;
  bool apiKeyObscured;
  String authType; // 'apikey' | 'oauth'
  bool oauthLoggedIn;
  final TextEditingController apiKeyController;

  ProviderItem({
    required this.provider,
    required this.model,
    required this.hasApiKey,
    this.authType = 'apikey',
    this.oauthLoggedIn = false,
  }) : apiKeyObscured = true,
       apiKeyController = TextEditingController(
         text: hasApiKey ? '••••••••••••••••' : '',
       );

  void dispose() {
    apiKeyController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'model': model,
      'authType': authType,
      if (authType != 'oauth')
        'apiKey': apiKeyController.text.contains('••')
            ? null
            : apiKeyController.text.trim(),
    };
  }
}
