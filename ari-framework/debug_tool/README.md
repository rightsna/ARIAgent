# ARI WebSocket Debug Tool

ARI 서버에 클라이언트로 연결하여 Flutter 앱 명령을 AI 없이 직접 테스트하는 CLI 도구입니다.

---

## 사전 조건

ARI 서버와 대상 Flutter 앱이 먼저 실행 중이어야 합니다.

---

## 사용법

```bash
cd ari-framework/debug_tool
dart run bin/debug_tool.dart -cmd <COMMAND> [options]
```

| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `-ip` | `127.0.0.1` | ARI 서버 주소 |
| `-port` | `29277` | ARI 서버 포트 |
| `-app` | `bitnari` | 대상 앱 ID |
| `-cmd` | (필수) | 전송할 명령 |
| `-params` | `{}` | 명령 파라미터 (JSON) |
| `-timeout` | `60` | 응답 대기 타임아웃 (초) |
| `-v` | - | 상세 로그 출력 |

---

## 예시

```bash
dart run bin/debug_tool.dart -cmd GET_APP_STATUS

dart run bin/debug_tool.dart -cmd GET_STRATEGY -params '{"symbol":"KRW-BTC"}'

dart run bin/debug_tool.dart -app aristock -cmd GET_ANALYSIS -params '{"symbol":"005930"}'
```

---

## 통신 흐름

```
debug_tool ──▶ ARI 서버 (/APP.CALL) ──▶ Flutter 앱
               ARI 서버 ◀── 응답
debug_tool ◀── 결과 출력
```
