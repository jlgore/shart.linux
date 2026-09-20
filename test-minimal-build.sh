#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}  Minimal Packer Build Test${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

cd packer

# Clean
rm -rf output-debug

# First, let's test with the minimal preseed
echo -e "${GREEN}[INFO]${NC} Testing with minimal preseed configuration"
echo -e "${YELLOW}[NOTE]${NC} Using preseed-minimal.cfg for testing"

# Create a temporary modified debug build that uses minimal preseed
cat > debug-minimal.pkr.hcl << 'EOF'
packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "debian_version" {
  type    = string
  default = "13.1.0"
}

source "qemu" "debian" {
  iso_url      = "https://cdimage.debian.org/debian-cd/${var.debian_version}/amd64/iso-cd/debian-${var.debian_version}-amd64-netinst.iso"
  iso_checksum = "file:https://cdimage.debian.org/debian-cd/${var.debian_version}/amd64/iso-cd/SHA256SUMS"
  
  output_directory = "output-debug"
  vm_name         = "test.qcow2"
  
  disk_size       = "5G"
  memory          = "2048"
  cpus            = 2
  
  accelerator     = "tcg"
  format          = "qcow2"
  
  headless        = true
  vnc_bind_address = "0.0.0.0"
  
  net_device = "virtio-net"
  
  boot_wait          = "10s"
  boot_key_interval  = "10ms"
  
  boot_command = [
    "<esc><wait>",
    "auto ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed-minimal.cfg ",
    "debian-installer=en_US.UTF-8 ",
    "locale=en_US.UTF-8 ",
    "kbd-chooser/method=us ",
    "keyboard-configuration/xkb-keymap=us ",
    "netcfg/get_hostname=shart ",
    "fb=false ",
    "debconf/frontend=noninteractive ",
    "<enter>"
  ]

  http_directory = "http"
  
  ssh_username = "root"
  ssh_password = "shart123"
  ssh_timeout = "30m"
  ssh_handshake_attempts = 100
  
  shutdown_command = "shutdown -P now"
}

build {
  sources = ["source.qemu.debian"]
  
  provisioner "shell" {
    inline = [
      "echo 'SSH connection successful!'",
      "hostname",
      "uname -a"
    ]
  }
}
EOF

echo -e "${GREEN}[INFO]${NC} Starting build with VNC on port 5900"
echo -e "${YELLOW}[TIP]${NC} Connect with: vncviewer localhost:5900"
echo ""

PACKER_LOG=1 packer build -on-error=ask debug-minimal.pkr.hcl

echo -e "${GREEN}[SUCCESS]${NC} Test completed!"