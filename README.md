## HW: Optimizing LLM Workloads for k3d

#### 📋 Prerequisites & Installation Guide
This homework supports Mac, Linux, and Windows. Please follow the instructions for your specific operating system to install the required tools (`Docker`, `kubectl`, `k3d`, `hey`, and standard utilities like `make`).

**🍎 1. macOS Instructions**
* **Docker**: Install [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/).
* **Terminal Tools**: We have provided an automated script for all required CLI tools. Run:
  ```bash
  bash setup/install_mac.sh
  ```

**🐧 2. Linux Instructions (and Windows WSL2)**
* **Docker**: `curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`
* **Terminal Tools**: We have provided an automated script for kubectl, k3d, and hey. Run:
  ```bash
  bash setup/install_linux_wsl.sh
  ```

**🪟 3. Windows Instructions**
> **💡 STRONGLY RECOMMENDED:** It is highly advised to use **[WSL2 (Ubuntu)](https://learn.microsoft.com/en-us/windows/wsl/install)** for this assignment and follow the Linux instructions above. Windows native environments often struggle with bash scripts (`.sh`) and path formatting. However, native instructions are provided below if you prefer.

* **Docker**: Install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/).
* **Terminal Tools**: You can install them manually via Winget:
  * `winget install -e --id Kubernetes.kubectl`
  * `winget install k3d` (or `choco install k3d`)
  * Download the [hey Windows executable](https://hey-release.s3.us-east-2.amazonaws.com/hey_windows_amd64.exe) and add it to your System PATH.

---

#### The Scenario

You are a DevOps Engineer at an AI startup. A researcher gave you a "Dockerized" LLM server (`Dockerfile.heavy`), but it is 3GB, takes minutes to deploy, and crashes instantly when put into your k3d cluster due to memory limits.

Your Goal: Slim down the image to under 150MB and make it scale automatically.

#### ⚠️ Ground Rules

- **DO NOT** modify anything inside the `baseline/` or `scripts/` directories. These contain the grading logic and the starting scenario.
- You should **only** write code and configuration inside the `solution/` directory.

#### Step 1: Analyze the Bloat

1. Build the baseline image (this will also download the mock model weights): 
   ```bash
   make build-heavy
   ```
3. Run `docker history llm-heavy`.
4. Identify: Where is the space going? (Hint: Check build tools and model weights).

#### Step 2: The Optimization Challenge

1. Create `Dockerfile.slim` in the `/solution` folder.
2. Must use Multi-stage builds.
3. Must use a slim base image (e.g., `debian:slim` or `python:3.10-slim`).
4. **Must NOT COPY** the model weights into the image. Use a hostPath volume in k3d instead.

#### Step 3: k3d Deployment

1. Initialize the cluster: `make setup-k3d` (or `bash scripts/k3d_setup.sh`).
2. Build and push your slim image to the local registry:
   ```bash
   docker build -t localhost:5000/llm-slim:latest -f solution/Dockerfile.slim solution/
   docker push localhost:5000/llm-slim:latest
   ```
3. Complete the manifests in `solution/k3d/` and deploy them:
   ```bash
   kubectl apply -f solution/k3d/
   ```
4. **Validation (The OOM Experience!)**: The `deployment.yaml` starts with a memory limit of `50Mi`, which is intentionally too low. Deploy it as-is first.
5. Check your pods (`kubectl get pods`) and events (`kubectl get events`). You should see it crash with an **`OOMKilled`** error.
6. Now, edit your `solution/k3d/deployment.yaml`, change the memory limit to a normal value (e.g., `800Mi`), and deploy again to watch the Pod successfully reach `Running`!

#### Step 4: Load & Scale

Generate traffic to trigger the HPA:

```bash
hey -z 60s -c 10 http://localhost:8080/completion -d '{"prompt": "Hi"}'
```

Wait a minute and watch your cluster grow from 1 Pod to 3 Pods in real-time.

#### Step 5: The Rolling Update (Zero Downtime)

Right now, your deployment configuration is hardcoded. Let's make it flexible using a ConfigMap.
1. Fill out the `solution/k3d/configmap.yaml` file with the keys `MODEL_NAME: "qwen2-0.5b-q4.gguf"` and `CTX_SIZE: "2048"`.
2. Update your `deployment.yaml` to read these as Environment Variables (hint: use `envFrom`).
3. Apply the updated manifests (`kubectl apply -f solution/k3d/`).
4. Now, let's simulate a zero-downtime upgrade! Change the `CTX_SIZE` in your `configmap.yaml` to `"4096"` and re-apply.
5. Quickly run `kubectl get pods -w` to watch the **Rolling Update** happen (old pods terminate while new ones start).
6. Check the logs of a new pod using `kubectl logs <pod-name>` to verify it prints the new context size!

#### Step 6: Final Submission

Run `make report` to generate `submission_report.txt`. This script verifies your image size, layer count, and cluster stability. Ensure your results match the requirements before submitting.

---
### 🌟 Verification Check-list

| Action Taken | Expected Result (Pod Status / Events) |
|---|---|
| **Deploying with 50Mi Limit** | Crashes with `OOMKilled` |
| **Fixing Limit to 800Mi** | Status becomes `Running (Ready 1/1)` |
| **Running Load Test (`hey`)** | Scales up to `3 Pods (HPA Triggered)` |
| **Updating ConfigMap** | `Terminating` old Pods, `Running` new Pods |
