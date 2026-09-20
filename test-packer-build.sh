#!/bin/bash

# Test script for debugging Packer build
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[INFO]${NC} Testing Packer build with VNC enabled for debugging"
echo -e "${YELLOW}[NOTE]${NC} VNC will be available on port 5900 (display :0)"
echo ""

cd packer

# Clean previous builds
rm -rf output-*

# Run Packer with debug output and VNC
echo -e "${GREEN}[INFO]${NC} Starting Packer build..."
echo -e "${GREEN}[INFO]${NC} Connect via VNC to localhost:5900 to watch the installation"
echo ""

ACCEL="kvm"; [[ ! -w /dev/kvm ]] && ACCEL="tcg"
PACKER_LOG=1 packer build \
    -var "output_format=qcow2" \
    -var "accelerator=${ACCEL}" \
    -var "vnc_bind_address=0.0.0.0" \
    -var "enable_cloud_init=true" \
    -var "harden_ssh=false" \
    -on-error=ask \
    shart-linux.pkr.hcl

echo -e "${GREEN}[SUCCESS]${NC} Build completed successfully!"
