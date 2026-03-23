import subprocess
import os
import time

def main():
    print("Destroying existing cluster if it exists...")
    subprocess.run(["k3d", "cluster", "delete", "llm-cluster"], stderr=subprocess.DEVNULL)
    
    print("Creating k3d cluster 'llm-cluster' with a local registry...")
    os.makedirs("model_data", exist_ok=True)
    
    mount_path = os.path.abspath("model_data")
    volume_arg = f"{mount_path}:/model_data@all"
    
    subprocess.run([
        "k3d", "cluster", "create", "llm-cluster",
        "--registry-create", "llm-registry:0.0.0.0:5050",
        "--volume", volume_arg,
        "--port", "8080:80@loadbalancer",
        "--servers", "1"
    ], check=True)
    
    print("Cluster 'llm-cluster' is ready.")
    print("Waiting for metrics-server to be ready (required for HPA)...")
    time.sleep(15)
    
    try:
        subprocess.run([
            "kubectl", "wait", "--for=condition=Ready", "pods",
            "-n", "kube-system", "-l", "k8s-app=metrics-server", "--timeout=120s"
        ], check=True)
    except subprocess.CalledProcessError:
        print("Warning: metrics-server took too long to be ready. It may still be starting.")

    print("\n==========================================================")
    print("Cluster setup complete! 🚀\n")
    print("Your local registry is running at: localhost:5000")
    print("You can tag and push your slim image here before deploying:")
    print("  docker tag llm-slim localhost:5000/llm-slim:latest")
    print("  docker push localhost:5000/llm-slim:latest")
    print("==========================================================")

if __name__ == "__main__":
    main()
