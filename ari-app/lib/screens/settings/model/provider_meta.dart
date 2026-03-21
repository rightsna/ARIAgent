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
      ModelItem(id: 'gpt-5.3-codex', label: 'gpt-5.3-codex'),
      ModelItem(id: 'gpt-5.3-codex-spark', label: 'gpt-5.3-codex-spark'),
      ModelItem(id: 'gpt-5.2-codex', label: 'gpt-5.2-codex'),
      ModelItem(id: 'gpt-5.2', label: 'gpt-5.2'),
      ModelItem(id: 'gpt-5.1-codex-max', label: 'gpt-5.1-codex-max'),
      ModelItem(id: 'gpt-5.1-codex-mini', label: 'gpt-5.1-codex-mini'),
      ModelItem(id: 'gpt-5.1', label: 'gpt-5.1'),
    ],
    isOAuth: true,
  ),
  ProviderMeta(
    id: 'openai',
    label: 'OpenAI',
    models: [
      ModelItem(id: 'gpt-4o', label: 'gpt-4o'),
      ModelItem(id: 'gpt-4o-mini', label: 'gpt-4o-mini'),
      ModelItem(id: 'gpt-4.1', label: 'gpt-4.1'),
      ModelItem(id: 'gpt-4.1-mini', label: 'gpt-4.1-mini'),
      ModelItem(id: 'o3', label: 'o3'),
      ModelItem(id: 'o4-mini', label: 'o4-mini'),
    ],
  ),
  ProviderMeta(
    id: 'anthropic',
    label: 'Anthropic',
    models: [
      ModelItem(
        id: 'claude-3-5-sonnet-latest',
        label: 'claude-3-5-sonnet-latest',
      ),
      ModelItem(
        id: 'claude-3-5-haiku-latest',
        label: 'claude-3-5-haiku-latest',
      ),
      ModelItem(
        id: 'claude-3-7-sonnet-latest',
        label: 'claude-3-7-sonnet-latest',
      ),
    ],
  ),
  ProviderMeta(
    id: 'google',
    label: 'Gemini',
    models: [
      ModelItem(id: 'gemini-2.5-flash', label: 'gemini-2.5-flash'),
      ModelItem(id: 'gemini-2.0-flash', label: 'gemini-2.0-flash'),
      ModelItem(id: 'gemini-1.5-pro', label: 'gemini-1.5-pro'),
    ],
  ),
  ProviderMeta(
    id: 'xai',
    label: 'xAI (Grok)',
    models: [
      ModelItem(id: 'grok-3', label: 'grok-3'),
      ModelItem(id: 'grok-3-mini', label: 'grok-3-mini'),
      ModelItem(id: 'grok-2', label: 'grok-2'),
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
      ModelItem(id: 'mixtral-8x7b-32768', label: 'mixtral-8x7b-32768'),
    ],
  ),
  ProviderMeta(
    id: 'mistral',
    label: 'Mistral',
    models: [
      ModelItem(id: 'mistral-large-latest', label: 'mistral-large-latest'),
      ModelItem(id: 'mistral-small-latest', label: 'mistral-small-latest'),
      ModelItem(id: 'codestral-latest', label: 'codestral-latest'),
    ],
  ),
  ProviderMeta(
    id: 'github-copilot',
    label: 'GitHub Copilot (OAuth)',
    models: [
      ModelItem(id: 'gpt-4o', label: 'gpt-4o'),
      ModelItem(id: 'claude-3.5-sonnet', label: 'claude-3.5-sonnet'),
      ModelItem(id: 'gemini-2.0-flash-001', label: 'gemini-2.0-flash-001'),
    ],
    isOAuth: true,
  ),
  ProviderMeta(
    id: 'google-gemini-cli',
    label: 'Google Gemini CLI (OAuth)',
    models: [
      ModelItem(id: 'gemini-2.5-flash', label: 'gemini-2.5-flash'),
      ModelItem(id: 'gemini-2.0-flash', label: 'gemini-2.0-flash'),
    ],
    isOAuth: true,
  ),
  ProviderMeta(
    id: 'google-antigravity',
    label: 'Antigravity (OAuth)',
    models: [
      ModelItem(id: 'gemini-3-flash', label: 'gemini-2.0-flash'),
      ModelItem(id: 'claude-sonnet-4-5', label: 'claude-3-5-sonnet'),
      ModelItem(id: 'gpt-oss-120b-medium', label: 'gpt-4o'),
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
