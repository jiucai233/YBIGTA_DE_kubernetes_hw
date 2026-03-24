## HW: Optimizing LLM Workloads for k3d

#### 📋 Prerequisites & Installation Guide

> **💡 STRONGLY RECOMMENDED (GitHub Codespaces):** 
> We highly recommend using **GitHub Codespaces** for this homework! Simply click the `<> Code` button on the repository, navigate to the `Codespaces` tab, and create a new one. A fully configured cloud environment (with Docker, K3d, etc., pre-installed) will open right in your browser. Just run the commands detailed below in the terminal and enjoy the homework!

This homework also supports local Mac, Linux, and Windows. If running locally, please follow the instructions below to install the required tools.

**🍎 1. macOS Instructions**

- **Docker**: Install [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/).
- **Terminal Tools**: We have provided a unified automated script for all required CLI tools. Run:
  ```bash
  bash setup/setup.sh
  ```

**🐧 2. Linux Instructions (and Windows WSL2)**

- **Docker**: `curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`
- **Terminal Tools**: We have provided a unified automated script for kubectl, k3d, and hey. Run:
  ```bash
  bash setup/setup.sh
  ```

**🪟 3. Windows Instructions**

> **💡 STRONGLY RECOMMENDED:** It is highly advised to use **[WSL2 (Ubuntu)](https://learn.microsoft.com/en-us/windows/wsl/install)** for this assignment and follow the Linux instructions above. Windows native environments often struggle with bash scripts (`.sh`) and path formatting. However, native instructions are provided below if you prefer.

- **Docker**: Install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/).
- **Terminal Tools**: You can install them manually via Winget:
  - `winget install -e --id Kubernetes.kubectl`
  - `winget install k3d` (or `choco install k3d`)
  - Download the [hey Windows executable](https://hey-release.s3.us-east-2.amazonaws.com/hey_windows_amd64.exe) and add it to your System PATH.

---

#### The Scenario

You are a DevOps Engineer at an AI startup. A researcher gave you a "Dockerized" LLM server (`Dockerfile.heavy`), but it is 3GB, takes minutes to deploy, and crashes instantly when put into your k3d cluster due to memory limits.

Your Goal: Slim down the image to under 1GB and make it scale automatically.

#### ⚠️ Ground Rules

- **DO NOT** modify anything inside the `baseline/` or `scripts/` directories. These contain the grading logic and the starting scenario.
- You should **only** write code and configuration inside the `solution/` directory.
- Run docker before you start to do this homework.

#### Step 1: Analyze the Bloat

1. First, download the mock model weights:
   ```bash
   bash baseline/model_downloader.sh
   ```
2. Build the baseline image:
   ```bash
   docker build -t llm-heavy -f baseline/Dockerfile.heavy baseline/
   ```
3. Run `docker history llm-heavy`.
4. Identify: Where is the space going? (Hint: Check build tools and model weights).
5. **Clean up**: After analyzing, delete the heavy image to free up ~3GB of disk space:
   ```bash
   docker rmi llm-heavy
   ```

#### Step 2: The Optimization Challenge

1. Check `Dockerfile.slim` in the `/solution` folder.
2. Must use Multi-stage builds.
3. Must use a slim base image (e.g., `debian:slim` or `python:3.10-slim`).
4. **Must NOT COPY** the model weights into the image. Use a hostPath volume in k3d instead.

#### Step 3: k3d Deployment

1. Initialize the cluster: `bash scripts/k3d_setup.sh`.
2. Build and push your slim image to the local registry:
   ```bash
   docker build -t localhost:5050/llm-slim:latest -f solution/Dockerfile.slim .
   docker push localhost:5050/llm-slim:latest
   ```
   _(Note: While you push to `localhost:5050` from your pc, your Kubernetes nodes run in their own virtual network and must pull the image using its internal name: `llm-registry:5000/llm-slim:latest`! Use this in your deployment.yaml)._
3. Complete the manifests in `solution/k3d/` and deploy them:
   ```bash
   kubectl apply -f solution/k3d/
   ```
4. **Validation (The OOM Experience!)**: The `deployment.yaml` starts with a memory limit of `10Mi`, which is intentionally too low. Deploy it as-is first.
5. Immediately run `kubectl get pods -w` (the `-w` stands for watch mode). You will see the Pod crash with an **`OOMKilled`** error. **More importantly**, you will watch Kubernetes instantly try to restart it or create a new one to maintain the replica count, eventually resulting in a `CrashLoopBackOff`! _(Press `Ctrl+C` to exit watch mode)._
6. Now, edit your `solution/k3d/deployment.yaml`, change the memory limit to a normal value (e.g., `800Mi`), and deploy again. Run `kubectl get pods -w` again to watch the Pods successfully reach a stable `Running` state! _(Press `Ctrl+C` to exit watch mode)._
7. **The Chaos Test (Self-Healing)**: Once your pods are `Running`, copy the name of one of your pods and manually assassinate it by running:
   ```bash
   kubectl delete pod <pod-name>
   ```
8. Immediately run `kubectl get pods`. You will see Kubernetes instantly creating a _brand new pod_ to replace the one you killed to maintain the requested replica count! This proves your Deployment is self-healing.

#### Step 4: Load & Scale

Generate traffic to trigger the HPA:

```bash
hey -z 60s -c 10 -m POST -H "Content-Type: application/json" -d '{"prompt":"hello"}' http://localhost:8080/completion
```

Wait a minute and watch your cluster grow from 1 Pod to 3 Pods in real-time.

#### Step 5: The Rolling Update (Zero Downtime)

Right now, your deployment configuration is hardcoded. Let's make it flexible using a ConfigMap.

1. Fill out the `solution/k3d/configmap.yaml` file with the keys `MODEL_NAME: "qwen2-0.5b-q4.gguf"` and `CTX_SIZE: "2048"`.
2. Update your `deployment.yaml` to read these as Environment Variables (hint: use `envFrom`).
3. Apply the updated manifests (`kubectl apply -f solution/k3d/`).
4. To simulate an upgrade, change the `CTX_SIZE` in your `configmap.yaml` to `"4096"` and re-apply.
5. Quickly run `kubectl get pods -w` to watch the **Rolling Update** happen visually (old pods terminate while new ones start).
6. Check the logs of one of your new pods using `kubectl logs <pod-name>` to verify it prints the new context size! _(Note: The final `check_hw.sh` auto-grader will automatically run a rigorous Zero-Downtime traffic test on your cluster!)_

#### Step 6: Final Submission

Run `bash scripts/check_hw.sh` to generate `submission_report.txt`. This script verifies your image size, layer count, and cluster stability. Ensure your results match the requirements before submitting.

---

### 🌟 Verification Check-list

| Action Taken                  | Expected Result (Pod Status / Events)           |
| ----------------------------- | ----------------------------------------------- |
| **Deploying with 10Mi Limit** | Crashes with `OOMKilled`                        |
| **Fixing Limit to 800Mi**     | Status becomes `Running (Ready 1/1)`            |
| **Running Load Test (`hey`)** | Scales up to `3 Pods (HPA Triggered)`           |
| **Updating ConfigMap**        | `Terminating` old Pods, `Running` new Pods      |
| **Running `check_hw.sh`**     | `ZERO_DOWNTIME_TEST: PASS (0 dropped requests)` |
