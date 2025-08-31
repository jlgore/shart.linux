#!/bin/bash

set -e

# shart.linux VM Build Script
# Creates bootable VM images in qcow2 or vmdk format

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
    if mountpoint -q "$CHROOT_DIR/proc" 2>/dev/null; then
        umount "$CHROOT_DIR/proc" || true
    fi
    if mountpoint -q "$CHROOT_DIR/sys" 2>/dev/null; then
        umount "$CHROOT_DIR/sys" || true
    fi
    if mountpoint -q "$CHROOT_DIR/dev/pts" 2>/dev/null; then
        umount "$CHROOT_DIR/dev/pts" || true
    fi
    if mountpoint -q "$CHROOT_DIR/dev" 2>/dev/null; then
        umount "$CHROOT_DIR/dev" || true
    fi
}

trap cleanup EXIT

main() {
    log "Starting shart.linux VM build (format: $OUTPUT_FORMAT)"
    
    check_root
    
    # Clean previous builds
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    
    log "Creating base Debian system with debootstrap..."
    debootstrap --arch=amd64 --variant=minbase bookworm "$CHROOT_DIR" http://deb.debian.org/debian/
    
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

    # Install packages and configure system
    chroot "$CHROOT_DIR" /bin/bash -c "
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y linux-image-amd64 grub-pc systemd-sysv \
            ca-certificates curl gnupg lsb-release software-properties-common \
            wget apt-transport-https vim htop git jq unzip openssh-server \
            sudo net-tools
        
        # Add HashiCorp repository
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
        echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | tee /etc/apt/sources.list.d/hashicorp.list
        
        apt-get update
        apt-get install -y terraform
        
        # Configure services  
        systemctl enable ssh
        systemctl enable systemd-networkd
        systemctl enable systemd-resolved
        
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
        
        # Clean up
        apt-get clean
        rm -rf /var/lib/apt/lists/*
    "
    
    log "Creating disk image..."
    
    # Create raw disk image (2GB)
    dd if=/dev/zero of="$WORK_DIR/disk.raw" bs=1M count=2048
    
    # Create partition table and partition
    parted "$WORK_DIR/disk.raw" mklabel msdos
    parted "$WORK_DIR/disk.raw" mkpart primary ext4 1MiB 100%
    parted "$WORK_DIR/disk.raw" set 1 boot on
    
    # Set up loop device
    LOOP_DEVICE=$(losetup --find --show "$WORK_DIR/disk.raw")
    if [[ -z "$LOOP_DEVICE" ]]; then
        error "Failed to create loop device"
    fi
    partprobe "$LOOP_DEVICE" || error "Failed to probe partitions"
    
    # Format partition
    mkfs.ext4 -F "${LOOP_DEVICE}p1"
    
    # Mount partition and copy system
    mkdir -p "$WORK_DIR/mnt"
    mount "${LOOP_DEVICE}p1" "$WORK_DIR/mnt"
    
    log "Copying system to disk image..."
    rsync -av "$CHROOT_DIR/" "$WORK_DIR/mnt/"
    
    # Install GRUB
    log "Installing GRUB bootloader..."
    mount -o bind /dev "$WORK_DIR/mnt/dev"
    mount -o bind /proc "$WORK_DIR/mnt/proc"
    mount -o bind /sys "$WORK_DIR/mnt/sys"
    
    chroot "$WORK_DIR/mnt" grub-install --target=i386-pc --no-floppy "$LOOP_DEVICE"
    chroot "$WORK_DIR/mnt" update-grub
    
    # Configure GRUB defaults for better compatibility
    cat >> "$WORK_DIR/mnt/etc/default/grub" << GRUBEOF
GRUB_TIMEOUT=3
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
GRUBEOF
    chroot "$WORK_DIR/mnt" update-grub
    
    # Configure fstab
    UUID=$(blkid -s UUID -o value "${LOOP_DEVICE}p1")
    echo "UUID=$UUID / ext4 defaults 0 1" > "$WORK_DIR/mnt/etc/fstab"
    
    # Cleanup mounts
    umount "$WORK_DIR/mnt/dev" || true
    umount "$WORK_DIR/mnt/proc" || true  
    umount "$WORK_DIR/mnt/sys" || true
    umount "$WORK_DIR/mnt"
    
    # Detach loop device
    losetup -d "$LOOP_DEVICE"
    
    log "Converting to $OUTPUT_FORMAT format..."
    case "$OUTPUT_FORMAT" in
        qcow2)
            qemu-img convert -f raw -O qcow2 "$WORK_DIR/disk.raw" "$IMAGE_NAME"
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