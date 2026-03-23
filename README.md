## 실습: Docker & k3d를 이용한 LLM 서빙 최적화

#### 📋 사전 준비 사항 & 설치 가이드

이 과제는 Mac, Linux, Windows를 지원합니다. 운영 체제에 맞는 안내에 따라 필요한 도구들(`Docker`, `kubectl`, `k3d`, `hey` 및 `make` 등 기본 유틸리티)을 설치해 주세요.

**🍎 1. macOS 설치 안내**

- **Docker**: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)을 설치합니다.
- **터미널 도구**: 필요한 모든 CLI 도구를 설치하는 통합 자동화 스크립트를 제공합니다. 파이썬이 설치되어 있어야 합니다 (Mac은 기본 설치됨). 다음을 실행하세요:
  ```bash
  python3 setup/install.py
  ```

**🐧 2. Linux 설치 안내 (및 Windows WSL2)**

- **Docker**: `curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`
- **터미널 도구**: 필요한 모든 CLI 도구를 설치하는 통합 자동화 스크립트를 제공합니다. 다음을 실행하세요:
  ```bash
  python3 setup/install.py
  ```

**🪟 3. Windows 설치 안내**

> **💡 강력 권장 사항:** 이 과제에서는 **[WSL2 (Ubuntu)](https://learn.microsoft.com/en-us/windows/wsl/install)**를 사용하고 위의 Linux 설치 안내를 따르는 것을 강력히 권장합니다. Windows 기본 환경은 종종 bash 스크립트(`.sh`) 및 경로 포맷 문제로 인해 원활하게 작동하지 않습니다. 그러나 Windows 기본 환경을 선호하는 경우 아래의 지침을 참조하세요.

- **Docker**: [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)를 설치합니다.
- **터미널 도구**: 파이썬(`python`)이 설치되어 있다면 다음 스크립트로 CLI 도구(kubectl, k3d, hey)를 자동 설치할 수 있습니다:
  ```powershell
  python setup/install.py
  ```
  파이썬이 없다면 직접 Winget을 통해 수동으로 설치할 수 있습니다:
  - `winget install -e --id Kubernetes.kubectl`
  - `winget install k3d` (또는 `choco install k3d`)
  - [hey Windows 실행 파일](https://hey-release.s3.us-east-2.amazonaws.com/hey_windows_amd64.exe)을 다운로드하고 시스템 PATH에 추가합니다.

---

#### 시나리오

본 실습에서는 3GB에 달하는 거대한 LLM 이미지를 150MB 미만으로 경량화하고, k3d(Kubernetes) 환경에서 자동 스케일링(HPA) 및 무중단 업데이트를 구현하는 서버리스급 인프라를 구축해봅시다!

#### ⚠️ 기본 규칙 (Ground Rules)

- `baseline/` 또는 `scripts/` 디렉터리 내부를 **절대 수정하지 마세요**. 채점 로직과 초기 시나리오가 포함되어 있습니다.
- 코드를 작성하거나 설정을 변경할 때는 **오직** `solution/` 디렉터리 내부에서만 작업해야 합니다.
- 이 과제를 시작하기 전에 반드시 docker를 실행하세요.

#### PHASE 1: 이미지 분석 및 베이스라인 구축

1. **모의 모델 가중치 다운로드**

   ```bash
   # 실습용 가중치 파일 생성
   python3 baseline/model_downloader.py
   ```

2. **베이스라인(Heavy) 이미지 빌드**

   ```bash
   docker build -t llm-heavy -f baseline/Dockerfile.heavy baseline/
   ```

3. **이미지 크기 및 레이어 분석**
   `docker history llm-heavy` 명령어를 통해 어떤 레이어에서 용량을 가장 많이 차지하는지 확인합니다.
   - **분석 포인트**: 빌드 도구 포함 여부와 이미지 내부에 복사된 모델 가중치(weights)의 크기를 체크하세요.

#### PHASE 2: Multi-stage 빌드를 통한 최적화

`solution/Dockerfile.slim` 파일을 작성하여 이미지 크기를 줄입니다.

> **Tip:** 가중치는 이미지에 포함하지 않고, 배포 시 k3d의 `hostPath` 볼륨을 통해 주입합니다.

#### PHASE 3: k3d 클러스터 배포 및 트러블슈팅

1. **클러스터 초기화 및 이미지 푸시**

   ```bash
   # 클러스터 생성
   python3 scripts/k3d_setup.py

   # 슬림 이미지 빌드 및 로컬 레지스트리 푸시
   docker build -t localhost:5050/llm-slim:latest -f solution/Dockerfile.slim .
   docker push localhost:5050/llm-slim:latest
   ```

   > **주의:** `deployment.yaml`에서는 레지스트리 내부 주소인 `llm-registry:5000/llm-slim:latest`를 사용해야 파드가 이미지를 가져올 수 있습니다.

2. **인프라 적용 및 OOM(Out Of Memory) 확인**
   - `solution/k3d/` 내 매니페스트를 적용합니다. (`kubectl apply -f solution/k3d/`)
   - `kubectl get pods -w`로 관찰 시, 메모리 제한(`50Mi`)으로 인해 파드가 `OOMKilled` 및 `CrashLoopBackOff` 상태가 되는 것을 확인합니다.

3. **리소스 수정 및 Self-Healing 검증**
   - `deployment.yaml`의 메모리 제한을 `800Mi`로 상향 조정한 후 다시 배포합니다.
   - 파드가 `Running` 상태가 되면, 임의로 파드를 삭제(`kubectl delete pod <이름>`)하여 쿠버네티스가 자동으로 새 파드를 생성하는지 확인합니다.

#### PHASE 4: 오토스케일링 및 ConfigMap 활용

1. **HPA(Horizontal Pod Autoscaler) 작동 테스트**
   `hey` 도구를 사용하여 부하를 발생시키고 파드 개수가 1개에서 3개로 늘어나는지 확인합니다.

   ```bash
   hey -z 60s -c 10 -m POST -H "Content-Type: application/json" -d '{"prompt":"hello"}' http://localhost:8080/completion
   ```

2. **ConfigMap을 이용한 무중단 롤링 업데이트**
   - `configmap.yaml`에 `MODEL_NAME`, `CTX_SIZE` 값을 설정합니다.
   - `deployment.yaml`에서 `envFrom`을 통해 해당 값을 참조하도록 수정합니다.
   - `CTX_SIZE`를 `4096`으로 변경 후 재배포하여, 기존 파드가 순차적으로 교체되는 Rolling Update 과정을 `kubectl get pods -w`로 확인합니다.

#### PHASE 5: 최종 확인 및 제출

1. **자동 채점 스크립트 실행**

   ```bash
   python3 scripts/check_hw.py
   ```

   `submission_report.txt`가 생성되었는지 확인하세요.

2. 생성한 파일이 “0324 Docker/ Kubernetes” 폴더에

   `본인 이름_submission_report.txt`로 업로드 하시면 됩니다

---

### 🌟 검증 체크리스트 (Verification Check-list)

| 수행 항목 (Action Taken)     | 예상 결과 (Expected Result - Pod Status / Events) |
| ---------------------------- | ------------------------------------------------- |
| **50Mi 제한으로 배포**       | `OOMKilled` 로 다운됨                             |
| **제한을 800Mi로 수정**      | 상태가 `Running (Ready 1/1)` 로 변경됨            |
| **부하 테스트 실행 (`hey`)** | `3개의 파드로 스케일업 (HPA 작동)`                |
| **ConfigMap 업데이트**       | 기존 파드 `Terminating`, 새 파드 `Running`        |
| **`check_hw.sh` 실행**       | `ZERO_DOWNTIME_TEST: PASS (0 dropped requests)`   |
