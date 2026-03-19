#!/bin/bash
# Initialize k3d cluster for "The Great Slim-Down" HW

set -e

# Destroy existing cluster if it exists
k3d cluster delete llm-cluster 2>/dev/null || true

echo "Creating k3d cluster 'llm-cluster' with a local registry..."

# Ensure model_data directory exists for the volume mount
mkdir -p "$(pwd)/model_data"

# Create cluster with:
# 1. Local registry
# 2. Host volume mapped to /model_data on all nodes for the mock physical volume
# 3. Port mapping 8080:80 to expose Ingress on localhost:8080
k3d cluster create llm-cluster \
  --registry-create llm-registry:0.0.0.0:5000 \
  --volume "$(pwd)/model_data:/model_data@all" \
  --port "8080:80@loadbalancer" \
  --servers 1

echo "Cluster 'llm-cluster' is ready."
echo "Waiting for metrics-server to be ready (required for HPA)..."
sleep 15
kubectl wait --for=condition=Ready pods -n kube-system -l k8s-app=metrics-server --timeout=120s || echo "Warning: metrics-server took too long to be ready. It may still be starting."

echo ""
echo "=========================================================="
echo "Cluster setup complete! 🚀"
echo ""
echo "Your local registry is running at: localhost:5000"
echo "You can tag and push your slim image here before deploying:"
echo "  docker tag llm-slim localhost:5000/llm-slim:latest"
echo "  docker push localhost:5000/llm-slim:latest"
echo "=========================================================="
