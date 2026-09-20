#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

ENABLE_CLOUD_INIT=${ENABLE_CLOUD_INIT:-true}
INSTALL_OPEN_VM_TOOLS=${INSTALL_OPEN_VM_TOOLS:-false}

echo "Installing base packages..."
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  wget \
  apt-transport-https \
  vim \
  htop \
  git \
  jq \
  unzip \
  net-tools \
  sudo \
  qemu-guest-agent \
  gdisk \
  parted

if [[ "${ENABLE_CLOUD_INIT}" == "true" ]]; then
  echo "Installing cloud-init and related utilities..."
  apt-get install -y -qq --no-install-recommends \
    cloud-init \
    cloud-guest-utils \
    cloud-initramfs-growroot
fi

if [[ "${INSTALL_OPEN_VM_TOOLS}" == "true" ]]; then
  echo "Installing open-vm-tools (vSphere/VMware optimizations)..."
  apt-get install -y -qq --no-install-recommends open-vm-tools
fi

echo "Package installation completed"
