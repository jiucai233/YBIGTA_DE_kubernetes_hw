import subprocess
import time
import os
import threading
import urllib.request
import platform

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return ""

def check_image():
    out = run_cmd('docker inspect llm-slim --format="{{.Size}}"')
    if not out or out == "0":
        print("Error: llm-slim image not found locally.")
        return 0, 0
    size_mb = int(out) // 1024 // 1024
    
    layer_count = run_cmd('docker image inspect llm-slim --format="{{len .RootFS.Layers}}"')
    if not layer_count:
        layer_count = run_cmd('docker image inspect llm-slim --format "{{len .RootFS.Layers}}"')
    return size_mb, layer_count or "0"

def get_pod_status():
    status = run_cmd("kubectl get deployment llm-server -o jsonpath='{.status.readyReplicas}'")
    return status.strip("'\"") if status else "0"

def get_oom_evidence():
    events = run_cmd("kubectl get events --all-namespaces")
    return str(events.lower().count("oomkilled"))

def get_current_limit():
    limit = run_cmd("kubectl get deployment llm-server -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'")
    return limit.strip("'\"") if limit else "Unknown"

def main():
    print("Running checks...")
    
    size_mb, layer_count = check_image()
    pod_status = get_pod_status()
    oom_evidence = get_oom_evidence()
    current_limit = get_current_limit()
    
    print("Running Zero-Downtime Rolling Update Test (this takes ~1 minute)...")
    
    failed_count = [0]
    stop_ping = [False]
    
    def ping_server():
        while not stop_ping[0]:
            try:
                req = urllib.request.Request("http://localhost:8080/health")
                with urllib.request.urlopen(req, timeout=1) as response:
                    if response.status != 200:
                        failed_count[0] += 1
            except Exception:
                failed_count[0] += 1
            time.sleep(0.5)
            
    thread = threading.Thread(target=ping_server)
    thread.daemon = True
    thread.start()
    
    subprocess.run("kubectl rollout restart deployment llm-server", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run("kubectl rollout status deployment llm-server --timeout=90s", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    stop_ping[0] = True
    thread.join(timeout=2)
    
    if failed_count[0] == 0:
        zd_result = "PASS (0 dropped requests)"
    else:
        zd_result = f"FAIL ({failed_count[0]} dropped requests)"
        
    report = f"""PC_NAME: {platform.node()}
OS_INFO: {platform.system()} {platform.release()}
IMAGE_SIZE_MB: {size_mb}
LAYER_COUNT: {layer_count}
K3D_READY_PODS: {pod_status}
OOM_ENCOUNTERED (Events): {oom_evidence}
CURRENT_MEMORY_LIMIT: {current_limit}
ZERO_DOWNTIME_TEST: {zd_result}
"""
    
    with open("submission_report.txt", "w") as f:
        f.write(report)
        
    print("Check complete. Generated submission_report.txt:")
    print(report)

if __name__ == "__main__":
    main()
