#!/bin/bash
set -euo pipefail

HARDEN_SSH=${HARDEN_SSH:-true}
ENABLE_CLOUD_INIT=${ENABLE_CLOUD_INIT:-true}

echo "Performing image cleanup and finalization..."

# Harden SSH in final image if requested
if [[ "${HARDEN_SSH}" == "true" ]]; then
  echo "Hardening SSH: disabling password auth and root login..."
  if [[ -f /etc/ssh/sshd_config ]]; then
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config || true
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config || true
  fi
  # Lock root account; cloud-init typically creates a user and injects keys.
  passwd -l root || true
fi

# Cloud-init cleanup so first boot runs fresh
if [[ "${ENABLE_CLOUD_INIT}" == "true" ]] && command -v cloud-init >/dev/null 2>&1; then
  echo "Cleaning cloud-init state..."
  cloud-init clean --logs || true
  rm -rf /var/lib/cloud/* || true
fi

# Clean package cache
apt-get clean
rm -rf /var/lib/apt/lists/*

# Clear temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear logs
find /var/log -type f -exec truncate -s 0 {} \; || true

# Clear user bash histories (ignore errors in non-interactive shells)
history -c || true
history -w || true
rm -f /root/.bash_history || true

# Clear SSH host keys (regenerated on first boot)
rm -f /etc/ssh/ssh_host_* || true

# Ensure qemu-guest-agent is enabled for better integration
systemctl enable qemu-guest-agent || true

# Zero out free space for better compression
if command -v dd >/dev/null 2>&1; then
  dd if=/dev/zero of=/EMPTY bs=1M || true
  rm -f /EMPTY
fi

sync || true

echo "Cleanup completed"
