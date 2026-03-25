<p align="center">
  <img src="ari-app/assets/images/logo.png" width="120" alt="ARI Agent Logo">
</p>

# ARI 에이전트 프로젝트 가이드

- **웹 사이트 및 개발 가이드**: [https://ariwith.me](https://ariwith.me)

## 개요

ARI 에이전트는 로컬 우선(local-first) 데스크톱 AI 비서입니다.

**핵심 비전: "도구의 진화에서 앱 생성으로"**

- 단순한 코드 조각(도구)에서 완전한 실행 환경(앱)으로의 이동.
- 기능들은 각자의 UI(Flutter/React)와 로직을 가진 독립적인 프로세스로 캡슐화됩니다.
- 시스템은 헤드리스 앱(Headless App)과 단순 도구(Simple Tool)를 통합된 "앱(App)" 엔티티로 취급합니다.

현재 역할 분담:

- `ari-server`는 실제 런타임입니다.
  에이전트 상태, 도구 실행, 스킬, 스케줄링, 메모리 및 로컬 자동화를 소유합니다.
  연결된 모든 앱의 중앙 조정자 역할을 합니다.
- `ari-app`은 데스크톱 UI 클라이언트(메인 쉘)입니다.
  RPC 요청을 보내고, 채팅을 렌더링하며, 런타임 상태를 표시합니다.
- `ari-framework`는 외부 앱 연동을 위한 규격 및 가이드라인입니다.
  새로운 기능이나 앱이 ARI 에이전트와 표준 프로토콜로 통신할 수 있도록 설정하는 도구 세트를 제공합니다.
- 외부 앱(예: `youtube_player`, `notepad`)은 `~/.ari-agent/skills` 폴더 아래에 설치될 수 있습니다.
  이러한 앱들은 일단 실행되면 표준화된 프로토콜을 통해 통신합니다.

핵심 아키텍처 규칙:

- 로컬 서버가 실행 권한을 가집니다.
- Flutter 앱 쉘은 자동화의 핵심이 아닙니다.
- 클라우드 모델은 추론을 제공하지만, 로컬 동작은 `ari-server`에 의해 오케스트레이션됩니다.

## 현재 런타임 아키텍처

```text
Flutter 앱 (쉘) <-> 로컬 서버 (ari-server) <-> 에이전트 런타임 (agent)
                                            \-> 표준 기능 앱 동기화 프로토콜 (REGISTER/COMMAND)
                                             \
                                              -> 외부 앱 (~/.ari-agent/skills에 설치됨)
```

### 앱 쉘 (`ari-app`)

- UI 전용
- WebSocket RPC를 통해 `/AGENT`, `/SETTINGS`, `/HEALTH`, `/PLUGINS`, `/MEMORY.*` 등을 전송
- 쉘 명령을 직접 실행하지 않음
- 메인 창 및 영구 탐색 관리

### 로컬 서버 (`ari-server`)

- 메인 런타임 및 RPC 라우터 호스팅
- **중앙 상태 레지스트리 (`AppStateService`)**: `appId`별로 연결된 모든 앱의 최신 상태를 관리합니다.
- 메모리, 작업 예약, 로컬 자동화 및 도구 실행을 소유합니다.
- `services/agent`를 활성 에이전트 구현으로 사용합니다.
- 기능 앱의 라이프사이클을 실행하고 관리합니다.

### 에이전트 런타임 (`ari-server/services/agent`)

- `index.ts`: 공용 엔트리포인트 및 오케스트레이션
- `context_builder.ts`: 시스템 프롬프트 구축 및 컨텍스트 정리
- `provider_selector.ts`: 제공자 선택 및 모델 결정
- `session_manager.ts`: 에이전트별 세션 상태
- `skill_registry.ts`: 사용 가능한 스킬 캐시 및 활성 스킬 상태
- `tool_registry.ts`: 메인 도구 목록 및 세션 도구 확장
- `response_parser.ts`: 최종 비서 텍스트 추출

현재 `agent` 동작:

- `agentId`당 하나의 `Agent` 세션을 유지
- 턴(turn) 간에 메시지 상태 재사용
- 동일한 메시지 스냅샷에서 구성된 제공자들에 대해 추론 재시도
- 메인 도구들로 시작
- `read_skill`을 통해 스킬을 세션 상태로 로드할 수 있음
- 로드된 스킬 지침을 다음 시스템 프롬프트에 추가
- 스킬에 선언된 도구 목록에서 즉석으로 허용된 도구 확장

## 표준화된 앱 동기화 프로토콜

높은 확장성을 달성하기 위해 모든 앱(내장 앱 포함)은 공통 동기화 프로토콜을 따릅니다.

- **`APP.REGISTER`**: 앱이 연결될 때 자신의 `appId`를 알립니다.
- **`APP.COMMAND`**: 서버가 특정 앱에 명령(예: `UPDATE`, `PLAY`)을 보냅니다.
- **`APP.QUERY` & `APP.QUERY_RESPONSE`**: 서버가 앱에 정보를 동적으로 요청합니다(`GET_STATE`, `GET_COMMANDS`).
  - 클라이언트 측에서 이 프로토콜은 `AppProtocolHandler`(Flutter 앱의 경우)를 통해 추상화되어 `appId`, `onCommand`, `onGetState`, `onGetCommands` 콜백을 간단히 주입할 수 있습니다.

- **범용 도구 (Universal Tools)**:
  - `launch_app(appName, parameters)`: 번들/폴더 이름으로 앱을 실행합니다.
  - `terminate_app(appId)`: 통신 ID로 실행 중인 앱을 종료합니다.
  - `discover_app_commands(appId)`: 앱에서 지원하는 명령 목록을 동적으로 가져옵니다.
  - `read_app_state(appId)`: 앱의 실시간 동적 상태를 가져옵니다.
  - `send_app_command(appId, command, data)`: 앱에 특정 명령을 보냅니다.

## 현재 도구 / 스킬 규칙

- 메인 도구는 `agent/tool_registry.ts`에 정의되어 있습니다.
- **동적 로딩**:
  - 도구와 스킬은 `~/.ari-agent/tools` 및 `~/.ari-agent/skills`에서 동적으로 로드됩니다.
  - `reload_skills` 도구를 사용하여 서버를 재시작하지 않고 파일 변경 사항을 동기화할 수 있습니다.
- **주요 메인 도구**:
  - `execute_bash`: 직접적인 쉘 실행.
  - `launch_app`, `terminate_app`, `discover_app_commands`, `read_app_state`, `send_app_command`: 통합된 앱 라이프사이클 및 통신 제어.
  - `create_skill`: ARI가 자신의 능력을 확장하기 위한 자기 진화형 도구.
  - `web_browse`, `web_fetch`: 외부 정보 수집.
  - `update_core_memory`, `append_daily_memory`: 지속성 및 컨텍스트 관리.
  - `read_skill`: 스킬 주입을 통한 능력 확장.

## 프롬프트 규칙

- `agent`는 `ari-server/template/system_prompt.hbs`를 사용합니다.
- 시스템 프롬프트는 앱 중심 아키텍처를 반영해야 합니다.
- ARI는 가능하면 단순한 코드보다는 전문화된 앱을 만들거나 사용하여 문제를 해결하도록 권장되어야 합니다.

## 디렉토리 구조

```text
ARIAgent/
├── ari-app/                     # Flutter 데스크톱 UI 쉘
├── ari-server/                  # 메인 런타임 (상태 관리, 도구 실행, RPC)
├── ari-launcher/                # 업데이트 확인 및 앱 실행기
└── ari-framework/               # 앱 연동 규격 및 개발 프레임워크/가이드 (flutter)
```

## 🚀 예제 연동 앱 (Sample Apps)

ARI 프레임워크를 활용하여 개발된 예제 프로젝트들입니다. 에이전트 연동 및 구현의 참고 자료로 활용하세요.

- [ARIStock (주식 분석)](https://github.com/rightsna/ARIStock)
- [ARINotePad (스마트 메모장)](https://github.com/rightsna/ARINotePad)
- [ARIYoutubePlayer (유튜브 플레이어)](https://github.com/rightsna/ARIYoutubePlayer)

## 개발 규칙

1. **앱 단위로 생각하기**: 기능은 이상적으로 표준화된 인터페이스를 가진 '앱'으로 캡슐화되어야 합니다.
2. **권한은 `ari-server`에 있음**: 앱은 상태를 보고하지만, 다음에 일어날 일은 서버가 결정합니다.
3. **표준 프로토콜 우선**: `send_app_command`로 달성할 수 있다면 앱 전용 도구(예: `notepad_write`)를 만드는 것을 피하세요.
4. **자기 진화 (Self-Evolution)**: ARI가 `~/.ari-agent/` 아래에 자신의 도구와 스킬을 직접 생성할 수 있도록 지원합니다.
5. **로깅**: 모든 백엔드 작업에는 `ari-server/infra/logger.ts`의 `logger`를 사용하세요.
6. **인코딩**: 모든 텍스트 파일(소스 코드, 마크다운, JSON 등)은 교차 플랫폼 호환성을 위해 **UTF-8 (BOM 없음)**으로 저장하고 **LF**를 줄바꿈 문자로 사용해야 합니다.

### 런처 패키징 규칙

- Windows 런처 패키지에는 `ARI_Launcher.exe`가 포함되어야 합니다.
- 런처 빌드 버전은 `ari-app/pubspec.yaml`의 버전/빌드 번호를 따라야 합니다.
