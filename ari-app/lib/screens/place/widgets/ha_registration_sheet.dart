import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HARegistrationSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Function(String, String) onSubmit;

  const HARegistrationSheet({
    super.key,
    this.existing,
    required this.onSubmit,
  });

  @override
  State<HARegistrationSheet> createState() => _HARegistrationSheetState();
}

class _HARegistrationSheetState extends State<HARegistrationSheet> {
  late TextEditingController urlController;
  late TextEditingController tokenController;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: widget.existing?['url'] ?? '');
    tokenController = TextEditingController(text: widget.existing?['token'] ?? '');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF03A9F4);
    const accentColor = Color(0xFFFF5722);
    const bgColor = Color(0xFFF8FAFC);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 45,
            height: 6,
            margin: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryColor, Color(0xFF0288D1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.hub_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Home Assistant',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              widget.existing != null ? '서버 연결 정보를 수정합니다' : '스마트 홈의 두뇌와 연결하세요',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 18, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildModernTextField(
                    controller: urlController,
                    hint: 'http://192.168.1.100:8123',
                    icon: Icons.link_rounded,
                    label: '서버 주소 (URL)',
                    helper: '로컬 IP 또는 외부 접속 도메인을 입력하세요.',
                  ),
                  const SizedBox(height: 24),
                  _buildModernTextField(
                    controller: tokenController,
                    hint: 'eyJ... 로 시작하는 토큰 문자열',
                    icon: Icons.vpn_key_rounded,
                    label: '롱리브 액세스 토큰',
                    helper: 'HA 프로필 하단에서 생성한 토큰을 입력하세요.',
                    isPassword: true,
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [accentColor, const Color(0xFFFF7043)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        final url = urlController.text.trim();
                        final token = tokenController.text.trim();
                        if (url.isNotEmpty && token.isNotEmpty) {
                          widget.onSubmit(url, token);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        widget.existing != null ? '변경사항 저장하기' : 'Home Assistant 연동 시작',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                  const Divider(height: 1),
                  const SizedBox(height: 32),
                  
                  // 설치 안내 섹션
                  const Text(
                    '아직 Home Assistant가 없으신가요?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          title: '공식 사이트',
                          subtitle: '설치 가이드 보기',
                          icon: Icons.open_in_new_rounded,
                          color: const Color(0xFF0F172A),
                          onTap: () => _launchUrl('https://www.home-assistant.io/installation/'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          title: '아리에게 묻기',
                          subtitle: '설치 방법 상담',
                          icon: Icons.auto_awesome_rounded,
                          color: const Color(0xFF6C63FF),
                          onTap: () {
                            Navigator.pop(context);
                            // 참고: 실제 채팅 탭 이동 로직은 상위에서 처리하거나 가이드 메시지 노출
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('채팅 탭에서 "HA 설치 도와줘"라고 물어보세요!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String label,
    required String helper,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.blueGrey[200], fontSize: 14),
              prefixIcon: Icon(icon, color: const Color(0xFF03A9F4).withOpacity(0.6), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(helper, style: TextStyle(color: Colors.blueGrey[300], fontSize: 11, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
