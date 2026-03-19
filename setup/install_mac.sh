#!/bin/bash
set -e

echo "========================================"
echo "Installing macOS dependencies..."
echo "========================================"

if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed. Please install it first from https://brew.sh/"
    exit 1
fi

echo "Installing kubectl, k3d, and hey..."
brew install kubectl k3d hey

echo "========================================"
echo "All CLI tools installed successfully!"
echo "Note: You must install Docker Desktop manually from https://docs.docker.com/desktop/install/mac-install/"
echo "========================================"
