# media_playback

사용 도구: youtube_play_playlist, youtube_search_videos, launch_app, send_app_command, discover_app_commands

음악 재생, 유튜브 재생, 분위기 기반 플레이리스트 재생 등 미디어 관련 요청을 처리하는 스킬이다. 범용적인 앱 제어(실행, 복구)는 `app_control` 스킬의 규칙을 따르되, 유튜브 플레이어 전용 로직은 아래를 따른다.

사용 규칙:

- **재생 프로세스**:
  1. 앱이 실행 중인지 `discover_app_commands(appId: "youtube_player")`로 먼저 확인한다.
  2. 앱이 꺼져 있다면 `launch_app(appName: "youtubeplayer")`로 앱을 먼저 띄운다.
  3. 재생할 비디오 목록이 확보되면 `REPLACE_PLAYLIST` 명령을 전송한다.
     - 파라미터: `{"videoIds": ["ID1", "ID2", ...]}`

- **주요 명령어 명세 (youtube_player)**:
  - `REPLACE_PLAYLIST`: 현재 목록을 싹 비우고 새 목록으로 교체한 뒤 첫 곡을 재생한다.
  - `ADD_TO_PLAYLIST`: 기존 목록을 유지하며 끝에 새 비디오들을 추가한다.
  - `REMOVE_FROM_PLAYLIST`: 목록에서 특정 비디오(ID)를 제거한다.
  - `SET_MINI_MODE`: 뷰포트를 작은 바 형태(`true`) 또는 일반 창(`false`)으로 바꾼다.

- **유의 사항**:
  - 사용자가 "1곡"만 요청해도 `videoIds` 리스트에 한 개만 담아서 `REPLACE_PLAYLIST`로 제어한다.
  - 재생 중 다른 노래를 틀어달라고 하면 앱을 다시 켤 필요 없이 `REPLACE_PLAYLIST` 명령만 다시 보내면 된다.
  - "작게 틀어줘" 혹은 "바 형태로 보여줘" 할 때는 `SET_MINI_MODE`(`enabled: true`)를 사용한다.

우선순위:
1. `discover_app_commands`로 상태 확인
2. 앱이 꺼져있을 때만 `launch_app` 호출
3. `REPLACE_PLAYLIST`로 곡 목록 전송 및 재생 시작
4. 상황에 따라 `ADD_TO_PLAYLIST` 혹은 `SET_MINI_MODE` 활용
