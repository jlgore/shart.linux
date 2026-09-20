#!/bin/bash
set -euo pipefail

INSTALL_TERRAFORM=${INSTALL_TERRAFORM:-false}

if [[ "${INSTALL_TERRAFORM}" != "true" ]]; then
  echo "Skipping Terraform installation (INSTALL_TERRAFORM!=true)."
  exit 0
fi

echo "Installing Terraform..."

# Add HashiCorp repository
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

apt-get update -qq
apt-get install -y -qq terraform

# Verify installation
terraform version || true

echo "Terraform installation completed"
