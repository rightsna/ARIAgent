import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:ari_plugin/ari_plugin.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _personaController = TextEditingController();
  String? _lastAvatarId;

  @override
  void initState() {
    super.initState();
    // 초기화 시점에는 provider를 사용할 수 없으므로, 빌드 시점에 동기화 처리를 합니다.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _personaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = context.watch<AvatarProvider>();
    final imagePath = avatar.imagePath.trim();
    final isAssetImage = imagePath.startsWith('assets/');
    final avatarImageFile = imagePath.isNotEmpty && !isAssetImage
        ? File(imagePath)
        : null;
    final hasAvatarImage =
        isAssetImage ||
        (avatarImageFile != null && avatarImageFile.existsSync());

    // 에이전트가 완벽하게 전환되었을 때(ID가 달라졌을 때) 컨트롤러 텍스트 동기화
    if (_lastAvatarId != avatar.currentAvatarId) {
      _nameController.text = avatar.name;
      _personaController.text = avatar.persona;
      _lastAvatarId = avatar.currentAvatarId;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.image,
              );
              if (result != null && result.files.single.path != null) {
                avatar.updateImagePath(result.files.single.path!);
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A1A2E),
                    border: Border.all(
                      color: const Color(0xFF6C63FF),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: hasAvatarImage
                        ? (isAssetImage
                              ? Image.asset(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/avatar.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.file(
                                  avatarImageFile!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/avatar.png',
                                    fit: BoxFit.cover,
                                  ),
                                ))
                        : Image.asset(
                            'assets/images/avatar.png',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF6C63FF),
                    child: const Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Avatar Name',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6C63FF)),
              ),
            ),
            onChanged: (val) {
              avatar.updateName(val);
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _personaController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Persona / System Prompt',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              hintText: 'LLM에게 부여할 역할이나 말투 등을 입력하세요. (예: 친절하고 다정한 어조로 답변해줘)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6C63FF)),
              ),
            ),
            onChanged: (val) {
              avatar.updatePersona(val);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            '이곳에서 프로필 사진과 이름을 변경하면 채팅창 위젯에도 즉시 반영됩니다.\nPersona는 이 에이전트의 AI 성격 및 역할 정의에 사용됩니다.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
