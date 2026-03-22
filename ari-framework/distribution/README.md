# Installation & Testing Guide (AI Only)

> [!IMPORTANT]
> 이 문서는 AI(코딩 에이전트)를 위한 설치 및 테스트 가이드라인입니다.

### 1. 로컬에서 설치 및 테스트

코딩 에이전트는 아래 순서로 진행합니다.

1. 프로젝트를 빌드합니다.
2. 빌드 산출물에서 실행 가능한 바이너리와 `SKILL.md`를 준비합니다.
3. 결과물을 `~/.ari-agent/skills/<app_id>` 아래에 복사합니다.
4. 예시 배포 경로는 `~/.ari-agent/skills/notepad` 형태입니다.
5. ARIAgent를 재실행해서 새 앱과 `SKILL.md`를 다시 읽게 합니다.

**요청 예시:**
```text
이 프로젝트를 빌드해서 바이너리와 SKILL.md를 준비하고,
~/.ari-agent/skills/notepad 아래에 복사한 뒤,
ARIAgent를 재실행해줘.
```

### 2. GitHub에서 배포

코딩 에이전트는 아래 순서로 진행합니다.

1. GitHub 저장소를 clone 또는 다운로드합니다.
2. 프로젝트를 빌드합니다.
3. 빌드 산출물에서 실행 가능한 바이너리와 `SKILL.md`를 준비합니다.
4. 결과물을 `~/.ari-agent/skills/<app_id>` 아래에 복사합니다.
5. ARIAgent를 재실행해서 새 앱과 `SKILL.md`를 다시 읽고 테스트합니다.

**요청 예시:**
```text
https://github.com/owner/repo 저장소를 받아서 빌드하고,
바이너리와 SKILL.md를 ~/.ari-agent/skills/notepad 아래에 복사한 뒤,
ARIAgent를 재실행해서 설치 및 테스트해줘.
```

---

### 체크 포인트 (검증)

- `~/.ari-agent/skills/<app_id>` 폴더가 생성되어 있어야 합니다.
- 실행 가능한 바이너리가 들어 있어야 합니다.
- `SKILL.md`가 함께 들어 있어야 합니다.
- ARIAgent 재실행 후 앱이 인식되어야 합니다.
