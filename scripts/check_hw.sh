#!/usr/bin/env bash
# check_hw.sh - Auto-Grader Logic

echo "Running checks..."

# 1. IMAGE SIZE CHECK
# Target: < 1024MB (without weights)
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
OOM_EVIDENCE=$(kubectl get events --all-namespaces | grep -iE "OOM|BackOff" | wc -l | tr -d ' ')

# 5. LIMITS CHECK
# Verify they fixed the memory limit in the deployment
CURRENT_LIMIT=$(kubectl get deployment llm-server -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "Unknown")

# 6. ZERO DOWNTIME TEST (Rolling Update)
echo "Running Zero-Downtime Rolling Update Test (blasting high-volume traffic for ~35s)..."
rm -f /tmp/hw_zd_test.log

# We use 'hey' to blast the server with 4 concurrent workers for 35 seconds
# This unleashes tens of thousands of requests to heavily test the load balancer routing
hey -z 35s -c 4 http://localhost:8080/health > /tmp/hw_zd_test.log 2>&1 &
HEY_PID=$!

# Give hey 2 seconds to warm up
sleep 2

# Trigger rollout and wait
kubectl rollout restart deployment llm-server >/dev/null 2>&1
kubectl rollout status deployment llm-server --timeout=90s >/dev/null 2>&1 || true

# Wait for hey to finish its 35s burst so we get the complete summary
wait $HEY_PID 2>/dev/null || true

# Extract 200 OK
SUCCESS_COUNT=$(grep "\[200\]" /tmp/hw_zd_test.log | awk '{print $2}')
SUCCESS_COUNT=${SUCCESS_COUNT:-0}

# Extract HTTP 502/503 errors and natively failed Connection Refusals
HTTP_ERRORS=$(sed -n '/Status code distribution:/,/Error distribution:/p' /tmp/hw_zd_test.log | grep -E '\[[0-9]{3}\]' | grep -v '\[200\]' | awk '{s+=$2} END {print s}')
NET_ERRORS=$(sed -n '/Error distribution:/,$p' /tmp/hw_zd_test.log | grep -E '\[[0-9]+\]' | grep -oE '\[[0-9]+\]' | tr -d '[]' | awk '{s+=$1} END {print s}')

HTTP_ERRORS=${HTTP_ERRORS:-0}
NET_ERRORS=${NET_ERRORS:-0}
FAILED_COUNT=$((HTTP_ERRORS + NET_ERRORS))
TOTAL_COUNT=$((SUCCESS_COUNT + FAILED_COUNT))

if [ "$TOTAL_COUNT" -eq 0 ]; then 
  DROP_RATE=100
  TOTAL_COUNT=1
else
  DROP_RATE=$((FAILED_COUNT * 100 / TOTAL_COUNT))
fi

if [ "$DROP_RATE" -le 5 ]; then
  ZD_RESULT="PASS ($DROP_RATE% drop rate | $FAILED_COUNT dropped / $TOTAL_COUNT total) *Tolerating <5% drop rate"
else
  ZD_RESULT="FAIL ($DROP_RATE% drop rate | $FAILED_COUNT dropped / $TOTAL_COUNT total) *Too many drops, your rolling update config is missing probes"
fi
rm -f /tmp/hw_zd_test.log

# GENERATE REPORT
{
  echo "PC_NAME: $(hostname)"
  echo "OS_INFO: $(uname -srm)"
  echo "IMAGE_SIZE_MB: $SIZE_MB"
  echo "LAYER_COUNT: $LAYER_COUNT"
  echo "K3D_READY_PODS: $POD_STATUS"
  echo "OOM_ENCOUNTERED (Events): $OOM_EVIDENCE"
  echo "CURRENT_MEMORY_LIMIT: $CURRENT_LIMIT"
  echo "ZERO_DOWNTIME_TEST: $ZD_RESULT"
} > submission_report.txt

echo "Check complete. Generated submission_report.txt:"
cat submission_report.txt
