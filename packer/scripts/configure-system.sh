#!/bin/bash
set -euo pipefail

ENABLE_CLOUD_INIT=${ENABLE_CLOUD_INIT:-true}

echo "Configuring system..."

# Configure hostname and hosts
echo "shart-linux" > /etc/hostname
cat > /etc/hosts << 'EOF'
127.0.0.1   localhost
127.0.1.1   shart-linux
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Configure sources.list dynamically based on current codename (bookworm/trixie/etc.)
CODENAME=$(lsb_release -cs 2>/dev/null || echo bookworm)
cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian/ ${CODENAME} main
deb http://deb.debian.org/debian-security/ ${CODENAME}-security main
deb http://deb.debian.org/debian/ ${CODENAME}-updates main
EOF

# Enable essential services
systemctl enable ssh
systemctl enable systemd-resolved
systemctl enable qemu-guest-agent || true

# Prefer cloud-init to manage networking if enabled; otherwise, install a generic DHCP config
if [[ "${ENABLE_CLOUD_INIT}" == "true" ]]; then
  echo "Using cloud-init to manage networking (no static systemd-networkd config)."
  # Ensure networkd is enabled but let cloud-init write configs if needed
  systemctl enable systemd-networkd
  # Remove any existing generic network configs that may conflict
  rm -f /etc/systemd/network/20-dhcp.network || true
else
  echo "Configuring generic DHCP for ethernet devices via systemd-networkd..."
  systemctl enable systemd-networkd
  cat > /etc/systemd/network/20-dhcp.network << 'EOF'
[Match]
Name=e*

[Network]
DHCP=yes
EOF
fi

if [[ -x /usr/lib/systemd/systemd-sysusers ]]; then
  systemd-sysusers || true
fi

# Configure MOTD display
grep -q '/etc/motd' /etc/bash.bashrc || echo 'cat /etc/motd' >> /etc/bash.bashrc
grep -q 'PS1=' /etc/bash.bashrc || echo 'export PS1="[\u@shart-linux \W]$ "' >> /etc/bash.bashrc

# Configure GRUB for serial console compatibility
cat >> /etc/default/grub << 'EOF'
GRUB_TIMEOUT=3
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
EOF
update-grub || true

# Enable cloud-init services when installed
if [[ "${ENABLE_CLOUD_INIT}" == "true" ]] && command -v cloud-init >/dev/null 2>&1; then
  systemctl enable cloud-init cloud-init-local cloud-config cloud-final || true
fi

echo "System configuration completed"
