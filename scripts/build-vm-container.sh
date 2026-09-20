#!/bin/bash

set -e

# shart.linux VM Build Script (Container-Friendly Version)
# Creates bootable VM images in qcow2 or vmdk format
# Optimized for running inside Docker containers (like act)

OUTPUT_FORMAT="${1:-qcow2}"
WORK_DIR="$(pwd)/build"
CHROOT_DIR="$WORK_DIR/chroot"
IMAGE_NAME="shart-linux.$OUTPUT_FORMAT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

cleanup() {
    log "Cleaning up..."
    
    # Unmount filesystems
    if mountpoint -q "$CHROOT_DIR/dev/pts" 2>/dev/null; then
        umount "$CHROOT_DIR/dev/pts" || true
    fi
    if mountpoint -q "$CHROOT_DIR/dev" 2>/dev/null; then
        umount "$CHROOT_DIR/dev" || true
    fi
    if mountpoint -q "$CHROOT_DIR/sys" 2>/dev/null; then
        umount "$CHROOT_DIR/sys" || true
    fi
    if mountpoint -q "$CHROOT_DIR/proc" 2>/dev/null; then
        umount "$CHROOT_DIR/proc" || true
    fi
    
    # Clean up work directory mounts
    if [[ -d "$WORK_DIR/mnt" ]]; then
        if mountpoint -q "$WORK_DIR/mnt/dev" 2>/dev/null; then
            umount "$WORK_DIR/mnt/dev" || true
        fi
        if mountpoint -q "$WORK_DIR/mnt/proc" 2>/dev/null; then
            umount "$WORK_DIR/mnt/proc" || true
        fi
        if mountpoint -q "$WORK_DIR/mnt/sys" 2>/dev/null; then
            umount "$WORK_DIR/mnt/sys" || true
        fi
        if mountpoint -q "$WORK_DIR/mnt" 2>/dev/null; then
            umount "$WORK_DIR/mnt" || true
        fi
    fi
    
    # Clean up loop devices
    for loop in $(losetup -j "$WORK_DIR/disk.raw" 2>/dev/null | cut -d: -f1); do
        losetup -d "$loop" 2>/dev/null || true
    done
}

trap cleanup EXIT

main() {
    log "Starting shart.linux VM build (format: $OUTPUT_FORMAT) - Container Mode"
    
    check_root
    
    # Install additional tools needed for containers
    log "Installing container-specific tools..."
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends kpartx udev debian-archive-keyring || warn "Some tools may not be available in container"
    
    # Clean previous builds
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    
    log "Creating base Debian system with debootstrap..."
    debootstrap --arch=amd64 --variant=minbase bookworm "$CHROOT_DIR" http://deb.debian.org/debian/ > /tmp/debootstrap.log 2>&1 || {
        error "Debootstrap failed. Check /tmp/debootstrap.log for details"
    }
    
    log "Setting up chroot environment..."
    mount -t proc /proc "$CHROOT_DIR/proc"
    mount -t sysfs /sys "$CHROOT_DIR/sys"
    mount -o bind /dev "$CHROOT_DIR/dev"
    mount -o bind /dev/pts "$CHROOT_DIR/dev/pts"
    
    log "Configuring system in chroot..."
    
    # Copy MOTD
    cp assets/motd.txt "$CHROOT_DIR/etc/motd"
    
    # Configure hostname and hosts
    echo "shart-linux" > "$CHROOT_DIR/etc/hostname"
    cat > "$CHROOT_DIR/etc/hosts" << EOF
127.0.0.1   localhost
127.0.1.1   shart-linux
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

    # Configure sources.list
    cat > "$CHROOT_DIR/etc/apt/sources.list" << EOF
deb http://deb.debian.org/debian/ bookworm main
deb-src http://deb.debian.org/debian/ bookworm main
deb http://deb.debian.org/debian-security/ bookworm-security main
deb-src http://deb.debian.org/debian-security/ bookworm-security main
deb http://deb.debian.org/debian/ bookworm-updates main
deb-src http://deb.debian.org/debian/ bookworm-updates main
EOF

    # Install packages and configure system (with container-friendly settings)
    chroot "$CHROOT_DIR" /bin/bash -c "
        export DEBIAN_FRONTEND=noninteractive
        export RUNLEVEL=1
        
        # Prevent services from starting during package installation
        cat > /usr/sbin/policy-rc.d << POLICY
#!/bin/sh
exit 101
POLICY
        chmod +x /usr/sbin/policy-rc.d
        
        apt-get update -qq
        apt-get install -y -qq --no-install-recommends linux-image-amd64 grub-pc systemd-sysv \
            ca-certificates curl gnupg lsb-release software-properties-common \
            wget apt-transport-https vim htop git jq unzip openssh-server \
            sudo net-tools
        
        # Add HashiCorp repository
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | tee /etc/apt/sources.list.d/hashicorp.list
        
        apt-get update -qq
        apt-get install -y -qq terraform
        
        # Configure services (will be enabled but not started due to policy-rc.d)
        systemctl enable ssh || true
        systemctl enable systemd-networkd || true
        systemctl enable systemd-resolved || true
        
        # Configure basic networking
        cat > /etc/systemd/network/20-dhcp.network << NETEOF
[Match]
Name=e*

[Network]
DHCP=yes
NETEOF
        
        # Create ctf user
        useradd -m -s /bin/bash ctfuser
        echo 'ctfuser:shart123' | chpasswd
        usermod -aG sudo ctfuser
        
        # Configure MOTD display
        echo 'cat /etc/motd' >> /etc/bash.bashrc
        echo 'export PS1=\"[\u@shart-linux \W]$ \"' >> /etc/bash.bashrc
        
        # Set root password
        echo 'root:shart123' | chpasswd
        
        # Remove policy-rc.d
        rm -f /usr/sbin/policy-rc.d
        
        # Clean up
        apt-get clean
        rm -rf /var/lib/apt/lists/*
    "
    
    log "Creating disk image..."
    
    # Create raw disk image (3GB)
    dd if=/dev/zero of="$WORK_DIR/disk.raw" bs=1M count=3072
    
    # Create partition table and partition using sfdisk (more container-friendly)
    sfdisk "$WORK_DIR/disk.raw" << SFDISK_EOF
label: dos
label-id: 0x12345678
device: $WORK_DIR/disk.raw
unit: sectors

$WORK_DIR/disk.raw1 : start=2048, type=83, bootable
SFDISK_EOF
    
    # Set up loop device with partition support
    LOOP_DEVICE=$(losetup --find --show --partscan "$WORK_DIR/disk.raw")
    if [[ -z "$LOOP_DEVICE" ]]; then
        error "Failed to create loop device"
    fi
    
    # Give the kernel time to create partition devices
    sleep 2
    
    # Check if partition device exists, create manually if needed
    PART_DEVICE="${LOOP_DEVICE}p1"
    if [[ ! -b "$PART_DEVICE" ]]; then
        warn "Partition device not found, trying kpartx..."
        kpartx -av "$LOOP_DEVICE" || true
        sleep 1
        # kpartx creates devices in /dev/mapper/
        MAPPER_DEVICE=$(kpartx -l "$LOOP_DEVICE" | head -1 | awk '{print "/dev/mapper/" $1}')
        if [[ -b "$MAPPER_DEVICE" ]]; then
            PART_DEVICE="$MAPPER_DEVICE"
        else
            error "Could not create partition device"
        fi
    fi
    
    log "Using partition device: $PART_DEVICE"
    
    # Format partition (faster with fewer inodes)
    mkfs.ext4 -F -O ^has_journal "$PART_DEVICE"
    
    # Mount partition and copy system
    mkdir -p "$WORK_DIR/mnt"
    mount "$PART_DEVICE" "$WORK_DIR/mnt"
    
    log "Copying system to disk image..."
    rsync -a --exclude=proc --exclude=sys --exclude=dev "$CHROOT_DIR/" "$WORK_DIR/mnt/"
    
    # Create essential directories that were excluded
    mkdir -p "$WORK_DIR/mnt/proc" "$WORK_DIR/mnt/sys" "$WORK_DIR/mnt/dev"
    
    # Install GRUB
    log "Installing GRUB bootloader..."
    mount -o bind /dev "$WORK_DIR/mnt/dev"
    mount -o bind /proc "$WORK_DIR/mnt/proc"
    mount -o bind /sys "$WORK_DIR/mnt/sys"
    
    chroot "$WORK_DIR/mnt" grub-install --target=i386-pc --no-floppy --force "$LOOP_DEVICE"
    chroot "$WORK_DIR/mnt" update-grub
    
    # Configure GRUB defaults
    cat >> "$WORK_DIR/mnt/etc/default/grub" << GRUBEOF
GRUB_TIMEOUT=3
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
GRUBEOF
    chroot "$WORK_DIR/mnt" update-grub
    
    # Configure fstab
    UUID=$(blkid -s UUID -o value "$PART_DEVICE")
    echo "UUID=$UUID / ext4 defaults 0 1" > "$WORK_DIR/mnt/etc/fstab"
    
    # Cleanup mounts
    umount "$WORK_DIR/mnt/dev" || true
    umount "$WORK_DIR/mnt/proc" || true  
    umount "$WORK_DIR/mnt/sys" || true
    umount "$WORK_DIR/mnt"
    
    # Clean up partition mapping if we used kpartx
    if [[ "$PART_DEVICE" == /dev/mapper/* ]]; then
        kpartx -dv "$LOOP_DEVICE" || true
    fi
    
    # Detach loop device
    losetup -d "$LOOP_DEVICE"
    
    log "Converting to $OUTPUT_FORMAT format..."
    case "$OUTPUT_FORMAT" in
        qcow2)
            qemu-img convert -f raw -O qcow2 -c "$WORK_DIR/disk.raw" "$IMAGE_NAME"
            ;;
        vmdk)
            qemu-img convert -f raw -O vmdk "$WORK_DIR/disk.raw" "$IMAGE_NAME"
            ;;
        *)
            error "Unsupported format: $OUTPUT_FORMAT"
            ;;
    esac
    
    # Cleanup
    rm -rf "$WORK_DIR"
    
    log "VM image created: $IMAGE_NAME"
    log "Default credentials: root/shart123 or ctfuser/shart123"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi