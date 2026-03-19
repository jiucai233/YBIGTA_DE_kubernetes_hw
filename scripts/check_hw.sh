#!/bin/bash
# check_hw.sh - Auto-Grader Logic

echo "Running checks..."

# 1. IMAGE SIZE CHECK
# Target: < 150MB (without weights)
SLIM_SIZE=$(docker inspect llm-slim --format='{{.Size}}' 2>/dev/null || echo "0")
if [ "$SLIM_SIZE" == "0" ]; then
    echo "Error: llm-slim image not found locally."
    SIZE_MB=0
else
    SIZE_MB=$((SLIM_SIZE/1024/1024))
fi

# 2. LAYER COUNT CHECK 
# Proves they didn't just 'squash' the heavy image.
# Multi-stage builds usually have < 10 layers.
LAYER_COUNT=$(docker image inspect llm-slim --format '{{len .RootFS.Layers}}' 2>/dev/null || echo "0")

# 3. K3D READYNESS
# Check if 3/3 pods are 'Running' and if HPA is initialized.
POD_STATUS=$(kubectl get deployment llm-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ -z "$POD_STATUS" ]; then
    POD_STATUS="0"
fi

# 4. EVENT SCAN
# Ensure the student actually saw the OOM error before fixing it.
OOM_EVIDENCE=$(kubectl get events --all-namespaces | grep -i "OOMKilled" | wc -l | tr -d ' ')

# 5. LIMITS CHECK
# Verify they fixed the memory limit in the deployment
CURRENT_LIMIT=$(kubectl get deployment llm-server -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "Unknown")

# 6. ZERO DOWNTIME TEST (Rolling Update)
echo "Running Zero-Downtime Rolling Update Test (this takes ~1 minute)..."
rm -f /tmp/hw_zd_fails.log
ping_server() {
  while true; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
    if [ "$HTTP_STATUS" != "200" ]; then
      echo "1" >> /tmp/hw_zd_fails.log
    fi
    sleep 0.5
  done
}
ping_server &
PING_PID=$!

# Trigger rollout and wait
kubectl rollout restart deployment llm-server >/dev/null 2>&1
kubectl rollout status deployment llm-server --timeout=90s >/dev/null 2>&1 || true
kill $PING_PID 2>/dev/null || true

FAILED_COUNT=0
if [ -f /tmp/hw_zd_fails.log ]; then
  FAILED_COUNT=$(wc -l < /tmp/hw_zd_fails.log | tr -d ' ')
fi

if [ "$FAILED_COUNT" -eq 0 ]; then
  ZD_RESULT="PASS (0 dropped requests)"
else
  ZD_RESULT="FAIL ($FAILED_COUNT dropped requests)"
fi
rm -f /tmp/hw_zd_fails.log

# GENERATE REPORT
{
  echo "IMAGE_SIZE_MB: $SIZE_MB"
  echo "LAYER_COUNT: $LAYER_COUNT"
  echo "K3D_READY_PODS: $POD_STATUS"
  echo "OOM_ENCOUNTERED (Events): $OOM_EVIDENCE"
  echo "CURRENT_MEMORY_LIMIT: $CURRENT_LIMIT"
  echo "ZERO_DOWNTIME_TEST: $ZD_RESULT"
} > submission_report.txt

echo "Check complete. Generated submission_report.txt:"
cat submission_report.txt
