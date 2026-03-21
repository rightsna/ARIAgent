# app_control

사용 도구: launch_app, terminate_app, send_app_command, discover_app_commands, read_app_state

ARI Agent 시스템 환경에서 외부 애플리케이션(번들 앱)의 생명주기와 원격 제어를 관리하는 핵심 스킬이다.

사용 규칙:

- **생명주기 관리 원칙**:
  - 앱을 제어하기 전 **반드시** `discover_app_commands(appId: "APP_ID")`를 호출하여 앱이 현재 실행 중인지, 어떤 명령어를 지원하는지 확인해야 한다.
  - 앱이 이미 실행 중이라면 **절대로** `launch_app`을 중복 호출하지 않는다. 시스템에서 실행을 거부할 수 있다.
  - 새로운 작업이나 상태 변경이 필요할 때는 앱을 껐다 켜는(`terminate` -> `launch`) 대신, 실행 중인 앱에 `send_app_command`를 보내는 것이 원칙이다.

- **장애 복구 (Recovery Logic)**:
  - `send_app_command`나 `read_app_state` 실행 결과 "연결되어 있지 않습니다" (not connected) 라는 오류가 발생하면, 사용자가 수동으로 앱을 껐거나 연결이 끊긴 것으로 판단한다.
  - 이 경우 즉시 `launch_app`을 통해 앱을 재실행하고, 원래 보내려던 명령을 다시 시도한다.
  - 사용자에게 "앱을 켜야 한다"고 설명하기보다 에이전트가 직접 앱을 다시 띄워 작업을 완수하는 것을 우선한다.

- **명령어 탐색**:
  - 개별 앱이 어떤 고유 명령어를 지원하는지 모를 때는 항상 `discover_app_commands`를 사용한다. 반환된 명세(JSON)를 바탕으로 파라미터를 구성하여 `send_app_command`를 사용한다.

- **상태 동기화**:
  - 앱의 화면 내용이나 내부 변수 값이 궁금할 때는 `read_app_state`를 사용한다. 이는 앱의 최신 상태를 실시간으로 가져온다.

우선순위:
1. `discover_app_commands`로 앱 존재 및 명령어 확인
2. (앱이 꺼져있을 때만) `launch_app` 실행
3. (앱이 켜져있을 때) `send_app_command`로 제어
4. 도구 실패 시(연결 오류 등) `launch_app`으로 자동 복구 시도
