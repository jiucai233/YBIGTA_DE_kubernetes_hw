#!/usr/bin/env bash
set -e

OS=$(uname -s)
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

echo "========================================"
echo "Installing dependencies for $OS ($ARCH)..."
echo "========================================"

if [ "$OS" = "Darwin" ]; then
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not installed. Visit https://brew.sh/"
        exit 1
    fi
    brew install kubectl k3d hey
elif [ "$OS" = "Linux" ]; then
    echo "1/3: Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl

    echo "2/3: Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

    echo "3/3: Installing hey..."
    sudo curl -L -o /usr/local/bin/hey "https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_${ARCH}"
    sudo chmod +x /usr/local/bin/hey
fi

echo "========================================"
echo "All CLI tools installed successfully!"
echo "Note: You must ensure Docker Desktop is installed and running."
echo "========================================"
