#!/bin/bash
set -e

echo "========================================"
echo "Installing Linux & WSL dependencies..."
echo "========================================"

echo "1/3: Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "2/3: Installing k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "3/3: Installing hey..."
sudo wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 -O /usr/local/bin/hey
sudo chmod +x /usr/local/bin/hey

echo "========================================"
echo "All CLI tools installed successfully!"
echo "Note: You must ensure Docker is installed and running."
echo "========================================"
