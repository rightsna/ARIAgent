# 🔌 ari-framework: 프로젝트 연동 가이드

이 문서는 **Flutter 기반 프로젝트**를 ARIAgent와 연동하여 AI가 앱을 직접 제어할 수 있도록 설정하는 가이드입니다.

---

## 🚀 연동 프로세스 (3단계)

플러그인 연동 및 배포는 아래의 **3단계 워크플로우**를 따라 진행됩니다.

**기초 환경 구성** → **기능 개발 및 연동** → **설치 및 배포**

---

### Step 1. 개발 환경 설정

`ari-framework/setup` 폴더 내의 마스터 문서들을 구성하여 프로젝트의 표준 규격과 방향성을 정의합니다.

- **설정 지침**: [setup/README.md](https://github.com/rightsna/ARIAgent/blob/main/ari-framework/setup/README.md)
- _이미 `setup/README.md`가 정리된 기존 프로젝트라면 이 단계를 건너뛰고 바로 2단계로 진행하세요._

**🤖 요청 예제:**

```text
https://github.com/rightsna/ARIAgent/blob/main/ari-framework/setup/README.md 파일을 읽고 프로젝트 환경 설정을 시작해줘.
```

### Step 2. 아리에이전트 연동 및 기능 개발 (데스크탑앱 전용)

AI가 프로젝트의 규격을 완벽히 이해하고 개발할 수 있도록 아래 플러그인 문서를 읽으라고 요청하세요.

- **플러그인 지침 (AI 전용)**: [plugin/README.md](https://github.com/rightsna/ARIAgent/blob/main/ari-framework/plugin/README.md)

**🤖 요청 예제:**

```text
https://github.com/rightsna/ARIAgent/blob/main/ari-framework/plugin/README.md 파일을 참고해서, 플러그인 연동 규격에 맞는 코드를 내 앱에 작성하고 구현해줘.
```

### Step 3. 설치 및 배포 (데스크탑앱 전용)

모든 기능 개발이 완료되면, AI에게 아래 배포 문서를 확인하여 최종 설치 프로세스를 진행하도록 요청하세요.

- **배포 지침 (AI 전용)**: [distribution/README.md](https://github.com/rightsna/ARIAgent/blob/main/ari-framework/distribution/README.md)

**🤖 요청 예제:**

```text
https://github.com/rightsna/ARIAgent/blob/main/ari-framework/distribution/README.md 파일을 읽고, 현재 개발된 앱을 배포해줘.
```

---

> [!TIP]
> 기술적인 세부 규격이나 설치 체크리스트는 AI가 `INSTRUCTION` 파일들을 통해 직접 분석합니다. 개발자는 위 가이드에 따라 AI에게 적절한 요청(Prompt)만 전달하면 모든 작업이 자동으로 진행됩니다.
