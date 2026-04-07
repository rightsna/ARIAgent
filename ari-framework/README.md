# 🔌 ari-framework: 프로젝트 개발 및 연동 가이드

이 문서는 **Flutter 기반 프로젝트**를 ARIAgent와 연동하여 AI가 앱을 직접 제어할 수 있도록 설정하고 개발하는 가이드입니다.

---

## 🚀 개발 및 배포 프로세스 (2단계)

기존의 환경 설정과 플러그인 연동 과정이 하나로 통합되어, 이제 아래의 **2단계 워크플로우**를 따라 진행됩니다.

**개발 환경 구성 및 기능 연동** → **설치 및 테스트**

---

### Step 1. 개발 환경 구성 및 아리 연동 (통합 가이드)

프로젝트의 표준 규격 정의부터 `ari_plugin`을 이용한 에이전트 연동까지 한 번에 진행합니다. `ari-framework/setup` 폴더 내의 통합 마스터 문서를 AI에게 읽어달라고 요청하세요.

- **통합 지침 (AI 전용)**: [setup/README.md](https://github.com/rightsna/ARIAgent/blob/main/ari-framework/setup/README.md)
- _이 문서는 환경 구축, 코딩 표준, 그리고 플러그인 연동 규격(WebSocket 프로토콜)을 모두 포함하고 있습니다._

**🤖 요청 예제:**

```text
https://github.com/rightsna/ARIAgent/blob/main/ari-framework/setup/README.md 파일을 읽고 프로젝트 환경 설정과 아리 에이전트 연동을 시작해줘.
```

### Step 2. 설치 및 테스트 (데스크탑앱 전용)

모든 기능 개발과 연동이 완료되면, AI에게 아래 배포 문서를 확인하여 최종 설치 프로세스를 진행하도록 요청하세요.

- **배포 지침 (AI 전용)**: [distribution/README.md](https://github.com/rightsna/ARIAgent/blob/main/ari-framework/distribution/README.md)

**🤖 요청 예제:**

```text
https://github.com/rightsna/ARIAgent/blob/main/ari-framework/distribution/README.md 파일을 읽고, 현재 개발된 앱을 빌드해서 로컬에 설치 및 테스트해줘.
```

---

> [!TIP]
> 기술적인 세부 규격이나 설치 체크리스트는 AI가 `setup/README.md`를 통해 직접 분석합니다. 개발자는 위 가이드에 따라 AI에게 적절한 요청(Prompt)만 전달하면 모든 작업이 자동으로 진행됩니다.
