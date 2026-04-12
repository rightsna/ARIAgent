# 🤖 AI 에이전트 가이드: 프로젝트 개발 및 아리 연동 표준 (Project Development & Integration Standards)

> [!IMPORTANT]
> 이 문서는 AI(코딩 에이전트)를 위한 기술 규격서입니다.
> 1단계(환경 설정 및 표준)와 2단계(플러그인 연동 및 프로토콜)가 하나로 통합된 마스터 문서입니다.

이 문서는 `ari-framework/guide/` 폴더의 단일 기준 문서입니다. 프로젝트를 시작할 때 AI 에이전트와 사용자는 먼저 이 파일을 확인하고, 여기 적힌 규칙을 기준으로 요구사항을 정리한 뒤 구현과 연동을 동시에 진행합니다.

---

## 1. 개발 환경 설정 및 준비 (Environment Setup)

작업을 시작하기 전, 에이전트는 다음 환경이 준비되어 있는지 확인해야 합니다.

1.  **Flutter & Dart SDK**: 시스템에 Flutter가 설치되어 있어야 합니다. (`flutter doctor`로 확인)
2.  **Git 및 계정 연동**: GitHub 등 원격 저장소를 사용하는 경우, clone/push/pull 권한과 계정 연동 상태를 먼저 확인합니다.
3.  **배포 타겟 확인**: 개발 시작 전, 대상 플랫폼(macOS, Windows 등)을 확인하고 그에 맞는 설정과 빌드 경로를 사용합니다.
4.  **프로젝트 생성**: 신규 프로젝트인 경우 아래 명령어로 시작합니다.
    ```bash
    flutter create --platforms=macos,windows [plugin_name]
    ```

---

## 2. 개발 표준 및 구조 (Coding Standards)

1.  **단순화 & 격리**: 각 기능은 `lib/components/[feature_name]/` 하위에 완전히 독립적으로 구성합니다.
2.  **비개발자 중심**: 복잡한 로직, 프로토콜 처리, 상태 전이처럼 이해 비용이 높은 부분에는 한글 주석을 추가합니다.
3.  **폴더 구조 규격**:
    ```text
    lib/
    ├── components/              # 독립된 기능 모듈
    │   ├── [feature_name]/      # 각 기능명 (snake_case)
    │   │   ├── screens/         # UI 화면
    │   │   ├── repositories/    # 데이터 소스 (API, DB)
    │   │   ├── providers/       # 상태 관리 (ChangeNotifier)
    │   │   ├── models/          # 데이터 모델
    │   │   └── services/        # 비즈니스 로직
    ├── shared/                  # 전역 공통 자원
    └── main.dart                # 앱 진입점 및 연동 초기화
    ```

---

## 3. 아리 에이전트 연동 (ARI Integration)

AI가 앱을 직접 제어할 수 있도록 `ari_plugin`을 연동해야 합니다.

### 3.1 의존성 추가 (`pubspec.yaml`)
프로젝트의 `pubspec.yaml`에 아래와 같이 `ari_plugin`을 추가합니다.

```yaml
dependencies:
  flutter:
    sdk: flutter
  ari_plugin:
    git:
      url: https://github.com/rightsna/ARIAgent.git
      ref: main
      path: ari-framework/plugin
```

### 3.2 핵심 구현 (Implementation)
`main.dart`에서 `AriAgent`를 초기화하고 연결한 뒤 핸들러를 등록합니다. 필요하면 실행 인자 또는 환경값으로 URL을 주입할 수 있으며, 규격화된 개발을 위해 `protocol_config.dart` 파일을 분리하여 관리하는 것을 권장합니다.

- **서버 접속 정보**: 기본값은 `ws://127.0.0.1:29277`이며, 필요시 `url` 또는 `host`/`port`로 초기화할 수 있습니다.
- **App Protocol Handler**: 에이전트의 명령(`COMMAND`)과 예약 상태 조회 명령(`GET_STATE`)을 처리합니다.

**추가 패턴 (ProtocolConfig)**:
```dart
// lib/protocol_config.dart
import 'package:ari_plugin/ari_plugin.dart';

class ProtocolConfig {
  static const String appId = 'my_app_id';

  static AppProtocolHandler createHandler() => AppProtocolHandler(
    appId: appId,
    onCommand: (command, params) => handleCommand(
      command: command,
      params: params,
    ),
    onGetState: () => { 'status': 'ready' },
  );

  static dynamic handleCommand({
    required String command,
    required Map<String, dynamic> params,
  }) {
    if (command == 'MY_ACTION') return {'status': 'success'};
    return null;
  }
}
```

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:ari_plugin/ari_plugin.dart';
import 'protocol_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 연결 초기화
  AriAgent.init();
  AriAgent.connect();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppProtocolHandler handler;

  @override
  void initState() {
    super.initState();
    handler = ProtocolConfig.createHandler();
    handler.start();
  }

  @override
  void dispose() {
    handler.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('ARI connected app')),
      ),
    );
  }
}
```

---

## 4. 통신 프로토콜 규격 (Communication Protocol)

에이전트와 앱은 WebSocket을 통해 아래와 같이 실시간 소통합니다.

1.  **플러그인 등록**: `/APP.REGISTER {"appId": "..."}` (연결 시 자동 수행)
2.  **명령 수신 (COMMAND)**: `/APP.COMMAND {"command": "...", "params": {...}}`
    - 명령어 중 `GET_STATE`는 앱의 현재 상태를 요청하는 예약된 명령어입니다.
3.  **결과 응답**: `/APP.COMMAND_RESPONSE {"requestId": "...", "result": {...}}`
4.  **에이전트 메시지 전송**: `/AGENT` 요청을 사용해 서버의 에이전트에 메시지를 전달합니다.
    - 앱이 스스로 서버(에이전트)에게 특정 사건이나 요청을 전달할 때 사용합니다.
    - **중요**: 이 요청을 보내면 서버의 에이전트가 내용을 분석하고 사용자에게 **자연스러운 문장**으로 답변을 생성하여 전달할 수 있습니다.

---

### 4.1 편의 메서드 (Helper Methods)
`AriAgent` 클래스는 위 프로토콜을 쉽게 사용할 수 있도록 래퍼 메서드를 제공합니다.

- **등록**: `AriAgent.register(appId)`
- **메시지 전송**: `AriAgent.call('/AGENT', {'appId': appId, 'message': '메시지', 'requestId': '...', 'platform': appId})`
- **응답**: `AriAgent.sendResponse(requestId: id, result: data)`

---

---

## 5. 실무 지침 및 배포 (Guidelines)

1.  **독립성**: 특정 컴포넌트 폴더 하나만 복사해도 작동할 수 있도록 외부 참조를 최소화합니다.
2.  **SKILL.md 필수**: 에이전트가 앱을 다루는 법을 설명하는 `SKILL.md` 파일을 프로젝트 루트에 포함합니다.
    - 내용: `appId`, 지원 명령어, 자연어 요청 대응 규칙 등 (예: `ari-framework/sample_basic/SKILL.md` 형식 참고)
3.  **배포**: 데스크탑(macOS, Windows) 배포 규격을 따르며, 필요시 Vercel(Web) 등을 지원합니다.

> [!NOTE]
> 사용자 설치 앱의 최종 배포 경로는 최신 기준으로 `~/.ari-agent/apps/<app_id>`를 사용합니다.
> `~/.ari-agent/skills`는 레거시 호환 경로로만 취급하세요.

---

> [!TIP]
> 기술 사양은 AI가 직접 분석합니다. 에이전트는 이 통합 가이드를 바탕으로 사용자의 요구사항을 프로젝트의 규격에 맞게 자동화하여 구현합니다.
