## HW: k3d를 위한 LLM 워크로드 최적화 (Optimizing LLM Workloads for k3d)

#### 📋 사전 준비 사항 & 설치 가이드

이 과제는 Mac, Linux, Windows를 지원합니다. 운영 체제에 맞는 안내에 따라 필요한 도구들(`Docker`, `kubectl`, `k3d`, `hey` 및 `make` 등 기본 유틸리티)을 설치해 주세요.

**🍎 1. macOS 설치 안내**

- **Docker**: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)을 설치합니다.
- **터미널 도구**: 필요한 모든 CLI 도구를 설치하는 자동화 스크립트를 제공합니다. 다음을 실행하세요:
  ```bash
  bash setup/install_mac.sh
  ```

**🐧 2. Linux 설치 안내 (및 Windows WSL2)**

- **Docker**: `curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`
- **터미널 도구**: kubectl, k3d, hey를 설치하는 자동화 스크립트를 제공합니다. 다음을 실행하세요:
  ```bash
  bash setup/install_linux_wsl.sh
  ```

**🪟 3. Windows 설치 안내**

> **💡 강력 권장 사항:** 이 과제에서는 **[WSL2 (Ubuntu)](https://learn.microsoft.com/en-us/windows/wsl/install)**를 사용하고 위의 Linux 설치 안내를 따르는 것을 강력히 권장합니다. Windows 기본 환경은 종종 bash 스크립트(`.sh`) 및 경로 포맷 문제로 인해 원활하게 작동하지 않습니다. 그러나 Windows 기본 환경을 선호하는 경우 아래의 지침을 참조하세요.

- **Docker**: [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)를 설치합니다.
- **터미널 도구**: Winget을 통해 수동으로 설치할 수 있습니다:
  - `winget install -e --id Kubernetes.kubectl`
  - `winget install k3d` (또는 `choco install k3d`)
  - [hey Windows 실행 파일](https://hey-release.s3.us-east-2.amazonaws.com/hey_windows_amd64.exe)을 다운로드하고 시스템 PATH에 추가합니다.

---

#### 시나리오

당신은 AI 스타트업의 DevOps 엔지니어입니다. 연구원으로부터 "도커화된(Dockerized)" LLM 서버(`Dockerfile.heavy`)를 전달받았지만, 크기가 3GB에 달하고 배포에 수 분이 걸리며, k3d 클러스터에 배포 시 메모리 제한으로 인해 즉시 다운됩니다.

**여러분의 목표**: 이미지 크기를 150MB 미만으로 줄이고 자동으로 스케일링이 가능하도록 만드는 것입니다.

#### ⚠️ 기본 규칙 (Ground Rules)

- `baseline/` 또는 `scripts/` 디렉터리 내부를 **절대 수정하지 마세요**. 채점 로직과 초기 시나리오가 포함되어 있습니다.
- 코드를 작성하거나 설정을 변경할 때는 **오직** `solution/` 디렉터리 내부에서만 작업해야 합니다.
- 이 과제를 시작하기 전에 반드시 docker를 실행하세요.

#### 1단계: 불필요한 크기 분석 (Analyze the Bloat)

1. 먼저, 모의 모델 가중치(weights)를 다운로드합니다:
   ```bash
   bash baseline/model_downloader.sh
   ```
2. 베이스라인 이미지를 빌드합니다:
   ```bash
   docker build -t llm-heavy -f baseline/Dockerfile.heavy baseline/
   ```
3. `docker history llm-heavy` 명령어를 실행합니다.
4. 분석하기: 어디에서 용량을 가장 많이 차지하고 있나요? (힌트: 빌드 도구와 모델 가중치를 확인하세요).

#### 2단계: 최적화 과제 (The Optimization Challenge)

1. `/solution` 폴더 내에 있는 `Dockerfile.slim`을 확인하세요.
2. 반드시 Multi-stage 빌드를 사용해야 합니다.
3. 반드시 슬림 베이스 이미지(예: `debian:slim` 또는 `python:3.10-slim`)를 사용해야 합니다.
4. 모델 가중치를 이미지 안으로 **복사(COPY)하면 안 됩니다**. 대신 k3d의 hostPath 볼륨을 사용하세요.

#### 3단계: k3d 배포 (k3d Deployment)

1. 클러스터 초기화: `bash scripts/k3d_setup.sh` 실행.
2. 슬림 이미지를 빌드하고 로컬 레지스트리로 푸시합니다:
   ```bash
   docker build -t localhost:5050/llm-slim:latest -f solution/Dockerfile.slim .
   docker push localhost:5050/llm-slim:latest
   ```
   _(참고: pc에서 `localhost:5050`으로 푸시하지만, 쿠버네티스 노드들은 자신들만의 가상 네트워크에서 실행되므로 내부 이름인 `llm-registry:5000/llm-slim:latest`를 사용하여 이미지를 가져와야 합니다! deployment.yaml 파일에 이를 사용하세요)._
3. `solution/k3d/` 경로의 매니페스트 파일들을 완성하고 배포합니다:
   ```bash
   kubectl apply -f solution/k3d/
   ```
4. **검증 (OOM 경험하기!)**: `deployment.yaml`은 시작 시 메모리 제한이 의도적으로 매우 낮은 `50Mi`로 설정되어 있습니다. 먼저 그대로 배포해 보세요.
5. 즉시 `kubectl get pods -w` 명령어를 실행합니다(`-w`는 watch 모드). 파드가 **`OOMKilled`** 에러와 함께 다운되는 것을 볼 수 있습니다. **더 중요한 것은**, 복제본(replica) 개수를 유지하기 위해 쿠버네티스가 즉시 재시작을 시도하거나 새 파드를 생성하려고 하며, 결국 `CrashLoopBackOff` 상태가 되는 과정을 지켜볼 수 있다는 것입니다! _(`Ctrl+C`를 눌러 watch 모드를 종료하세요)._
6. 이제 `solution/k3d/deployment.yaml`을 수정하여 메모리 제한을 정상적인 값(예: `800Mi`)으로 변경하고 다시 배포합니다. `kubectl get pods -w`를 다시 실행하여 파드들이 성공적으로 안정적인 `Running` 상태에 도달하는 것을 확인하세요! _(`Ctrl+C`를 눌러 watch 모드를 종료하세요)._
7. **카오스 테스트 (Self-Healing)**: 파드들이 `Running` 상태가 되면, 정상적으로 실행 중인 파드 이름 중 하나를 복사하여 다음 명령어를 통해 수동으로 강제 종료해 봅니다:
   ```bash
   kubectl delete pod <파드-이름>
   ```
8. 즉시 `kubectl get pods`를 실행합니다. 요청된 복제본 개수를 유지하기 위해 쿠버네티스가 여러분이 종료한 파드를 대체할 _완전히 새로운 파드_를 즉시 생성하는 것을 볼 수 있습니다! 이것은 여러분의 Deployment가 스스로 복구(self-healing)할 수 있음을 증명합니다.

#### 4단계: 부하 테스트 & 스케일링 (Load & Scale)

트래픽을 발생시켜 HPA를 작동시킵니다:

```bash
hey -z 60s -c 10 -m POST -H "Content-Type: application/json" -d '{"prompt":"hello"}' http://localhost:8080/completion
```

1분 정도 기다리면서, 클러스터 규모가 1개의 파드에서 3개의 파드로 실시간으로 늘어나는 것을 확인하세요.

#### 5단계: 무중단 롤링 업데이트 (The Rolling Update)

현재 배포 구성은 하드코딩되어 있습니다. ConfigMap을 사용하여 유연하게 변경해 봅시다.

1. `solution/k3d/configmap.yaml` 파일에 `MODEL_NAME: "qwen2-0.5b-q4.gguf"` 및 `CTX_SIZE: "2048"` 키 값을 채워 넣습니다.
2. 해당 값들을 환경 변수로 읽어오도록 `deployment.yaml`을 업데이트하세요 (힌트: `envFrom` 사용).
3. 업데이트된 매니페스트를 적용합니다 (`kubectl apply -f solution/k3d/`).
4. 업그레이드를 시뮬레이션하기 위해, `configmap.yaml`의 `CTX_SIZE` 값을 `"4096"`으로 변경하고 다시 적용(`re-apply`)해 보세요.
5. 즉시 `kubectl get pods -w`를 실행하여 기존 파드가 종료되고 새로운 파드가 시작되는 **롤링 업데이트(Rolling Update)**가 수행되는 모습을 시각적으로 확인해 보세요.
6. `kubectl logs <파드-이름>` 명령어로 새 파드 중 하나의 로그를 확인하여 변경된 컨텍스트 크기가 출력되는지 검증하세요! _(참고: 최종 `check_hw.sh` 자동 채점 스크립트는 클러스터에 대해 엄격한 무중단(Zero-Downtime) 트래픽 테스트를 자동으로 실행합니다!)_

#### 6단계: 최종 제출 (Final Submission)

`bash scripts/check_hw.sh`를 실행하여 `submission_report.txt`를 생성합니다. 이 스크립트는 이미지 크기, 레이어 수 및 클러스터 안정성을 검증합니다. 제출하기 전에 결과가 요구 사항과 일치하는지 확인하세요.

---

### 🌟 검증 체크리스트 (Verification Check-list)

| 수행 항목 (Action Taken)            | 예상 결과 (Expected Result - Pod Status / Events) |
| ----------------------------------- | ----------------------------------------------- |
| **50Mi 제한으로 배포**              | `OOMKilled` 로 다운됨                           |
| **제한을 800Mi로 수정**             | 상태가 `Running (Ready 1/1)` 로 변경됨          |
| **부하 테스트 실행 (`hey`)**        | `3개의 파드로 스케일업 (HPA 작동)`                |
| **ConfigMap 업데이트**              | 기존 파드 `Terminating`, 새 파드 `Running`      |
| **`check_hw.sh` 실행**              | `ZERO_DOWNTIME_TEST: PASS (0 dropped requests)` |
