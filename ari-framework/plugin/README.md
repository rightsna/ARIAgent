# Plugin Guide (AI Only)

> [!IMPORTANT]
> 이 문서는 AI(코딩 에이전트)를 위한 기술 규격서입니다.

이 가이드를 통해 일관된 통신 프로토콜을 구현하면, ARI 에이전트가 사용자의 앱을 실행하고, 상태를 파악하며, 다양한 명령을 내릴 수 있게 됩니다.

---

### 1. 개요 (Overview)

**ARIAgent Flutter Plugin App**은 프로젝트의 기능을 확장하는 독립적인 프로세스입니다. ARI 에이전트는 이 플러그인을 통해 다음과 같은 작업을 수행합니다.

- **앱 제어**: 필요에 따라 플러그인을 실행(`launch_app`)하거나 종료(`terminate_app`)합니다.
- **상호작용**: 표준화된 인터페이스(WebSocket)를 통해 실시간 명령을 내리고 데이터를 주고받습니다.
- **상태 파악**: 앱의 현재 상태를 읽어와 사용자에게 보고하거나 다음 행동을 결정합니다.

---

### 2. 명명 규칙 및 위치 (Naming & Location)

- **위치**: ARI 연동용 Flutter 플러그인 프로젝트는 프로젝트 구조에 맞는 독립 디렉터리에 배치합니다.
- **폴더명**: 소문자와 언더바(`_`)를 사용하는 snake_case 형식을 사용합니다. (예: `notepad`, `youtube_player`)
- **App ID**: ARI 서버와 통신할 때 사용하는 유일한 식별자로, 폴더명과 동일하게 설정하는 것을 권장합니다.

---

### 3. 프로젝트 초기 설정 (Project Setup)

Flutter 프로젝트로 플러그인을 제작할 때는 데스크톱(macOS, Windows) 타겟에 최적화하여 생성합니다.

```bash
# 새로운 AI 연동 플러그인 생성 예시
flutter create --platforms=macos,windows my_plugin_app
```

---

### 4. 연동 핵심 방법 (Core Implementation)

제작한 프로젝트를 ARI와 연동하는 가장 빠르고 확실한 방법은 **`ARIPlugin` 패키지를 dependency로 연결하고 프로토콜을 구현**하는 것입니다.

1.  **패키지 추가**: 앱의 `pubspec.yaml`에 `ari_plugin` git dependency를 추가합니다.
2.  **패키지 import**: 코드에서 `package:ari_plugin/ari_plugin.dart`를 import 합니다.
3.  **프로토콜 구현**: `AppProtocolHandler`를 통해 에이전트의 명령(`COMMAND`)과 쿼리(`QUERY`)에 대응하는 로직을 앱에 맞게 작성합니다.
4.  **연결 초기화**: 앱 시작 시 `WsManager` 또는 `WebSocketService`로 전달받은 `host`, `port`에 접속합니다.

#### 4.1 앱에서 dependency로 연결하기

**A. 일반 사용자 (GitHub 원격 저장소 연결)**
외부 프로젝트에서 `ari_plugin`을 사용하려면 아래와 같이 GitHub URL과 경로를 지정합니다.

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

**B. 로컬 개발 (동일 저장소 내 연동)**
`ARIAgent` 프로젝트 내의 다른 앱(예: `ari-app`)에서는 로컬 경로를 직접 참조하여 개발할 수 있습니다.

```yaml
dependencies:
  flutter:
    sdk: flutter
  ari_plugin:
    path: ../ari-framework/plugin  # 프로젝트 구조에 따라 경로 조정 필요
```

`ARIPlugin` 패키지 내부 의존성은 아래와 같습니다.

```yaml
dependencies:
  flutter:
    sdk: flutter
  connectivity_plus: ^7.0.0
  web_socket_channel: ^3.0.3
```

#### 4.2 앱 코드에서 import 하기

```dart
import 'package:ari_plugin/ari_plugin.dart';
```

---

### 5. 실행 인자 규격 (Launcher Arguments)

ARI 서버는 플러그인을 실행할 때 통신에 필요한 포트와 호스트 정보를 인자로 전달합니다. `main.dart`에서 이를 수신하여 서버에 접속해야 합니다.

- **Port**: `--port=29277` (또는 환경변수 `ARI_PORT`)
- **Host**: `--host=127.0.0.1` (또는 환경변수 `ARI_HOST`)

#### main.dart 예시

```dart
import 'package:ari_plugin/ari_plugin.dart';

Future<void> main(List<String> args) async {
  String? readArg(String prefix) {
    for (final arg in args) {
      if (arg.startsWith(prefix)) return arg.substring(prefix.length);
    }
    return null;
  }

  final port = readArg('--port=') ?? const String.fromEnvironment('ARI_PORT');
  final host = readArg('--host=') ??
      const String.fromEnvironment('ARI_HOST', defaultValue: '127.0.0.1');

  WsManager.init(host: host, port: int.tryParse(port) ?? WsManager.defaultPort);
  WsManager.connect();

  final handler = AppProtocolHandler(
    appId: 'my_plugin_id',
    onCommand: (command, params) async {
      if (command == 'DO_ACTION') {
        // 동작 수행 후 결과 리턴 (자동으로 /APP.COMMAND_RESPONSE 전송)
        return {'status': 'success', 'data': 'action_completed'};
      }
      return null;
    },
    onGetState: () => {
      'connected': WsManager.isConnected,
    },
    onGetCommands: () => {
      'DO_ACTION': 'Executes the main action of the app',
    },
  );

  handler.start();

  // runApp(...)
}
```

---

### 6. ARI 통신 프로토콜 (Communication Protocol)

에이전트와 플러그인은 WebSocket을 통해 실시간으로 소통합니다. 모든 메시지는 `명령어 {JSON_데이터}` 형식을 따릅니다.

#### 6.1 플러그인 등록 (App Registration)
- **보내기**: `/APP.REGISTER {"appId": "my_plugin_id"}`

#### 6.2 에이전트 명령 수신 (App Command)
- **받기**: `/APP.COMMAND {"appId": "...", "command": "DO_ACTION", "params": {...}}`

#### 6.3 상태 보고 및 쿼리 (App Query)
- **받기**: `/APP.QUERY {"appId": "...", "queryType": "GET_STATE", "requestId": "..."}`
- **응답**: `/APP.QUERY_RESPONSE {"requestId": "...", "result": {...}}`

#### 6.4 명령 실행 결과 응답 (App Command Response)
- **보내기**: `/APP.COMMAND_RESPONSE {"requestId": "...", "result": {...}}`
  - *비고: `onCommand`에서 `null`이 아닌 값을 리턴할 경우 자동으로 전송됩니다.*

---

### 7. 스킬 정의서 포함 (SKILL.md)

플러그인을 배포할 때는 에이전트가 이 앱을 어떻게 다뤄야 하는지 설명하는 **`SKILL.md` 파일을 반드시 포함**해야 합니다.

- **내용**: 앱 식별자(`appId`), 지원하는 명령어 목록, 자연어 요청에 따른 도구 사용 규칙 등.
- **역할**: 에이전트는 이 파일을 읽고 사용자의 의도에 맞춰 플러그인에 어떤 `COMMAND`를 보낼지 결정합니다.
