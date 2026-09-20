#!/bin/bash

set -e

# shart.linux Packer VM Build Script
# Creates bootable VM images using Packer

OUTPUT_FORMAT="${1:-qcow2}"
DEBIAN_VERSION_OVERRIDE="${DEBIAN_VERSION:-}"

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

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v packer &> /dev/null; then
        error "Packer is not installed. Please install Packer first."
    fi
    
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        error "QEMU is not installed. Please install qemu-kvm."
    fi
    
    # Check if we can use KVM acceleration
    if [[ ! -w /dev/kvm ]]; then
        warn "KVM acceleration not available. Falling back to TCG (slower)."
        export PACKER_ACCELERATOR_FALLBACK="tcg"
    else
        export PACKER_ACCELERATOR_FALLBACK="kvm"
    fi
}

detect_latest_debian_version() {
    local sums_url="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
    # Try to fetch the current stable SHA256SUMS and extract the version from the netinst filename
    if command -v curl >/dev/null 2>&1; then
        local sums filename version
        if sums=$(curl -fsSL "$sums_url" 2>/dev/null); then
            filename=$(echo "$sums" | awk '{print $2}' | grep -E '^debian-[0-9]+\.[0-9]+\.[0-9]+-amd64-netinst\.iso$' | head -n1)
            if [[ -n "$filename" ]]; then
                version=$(echo "$filename" | sed -E 's/^debian-([0-9]+\.[0-9]+\.[0-9]+)-amd64-netinst\.iso$/\1/')
                echo "$version"
                return 0
            fi
        fi
    fi
    return 1
}

main() {
    log "Starting shart.linux VM build with Packer (format: $OUTPUT_FORMAT)"
    
    check_dependencies
    
    # Validate format
    case "$OUTPUT_FORMAT" in
        qcow2|vmdk)
            ;;
        *)
            error "Unsupported format: $OUTPUT_FORMAT. Use 'qcow2' or 'vmdk'"
            ;;
    esac
    
    # Clean previous builds
    rm -rf packer/output-*
    rm -f shart-linux.$OUTPUT_FORMAT*
    
    # Change to packer directory
    cd packer
    
    # Resolve Debian version (auto-detect latest stable unless overridden)
    local debian_version=""
    if [[ -n "$DEBIAN_VERSION_OVERRIDE" ]]; then
        debian_version="$DEBIAN_VERSION_OVERRIDE"
        log "Using Debian version from override: $debian_version"
    else
        if debian_version=$(detect_latest_debian_version); then
            log "Detected latest Debian stable: $debian_version"
        else
            warn "Could not auto-detect Debian version; falling back to template default."
        fi
    fi

    log "Initializing Packer..."
    packer init .
    
    log "Building VM image with Packer..."
    PACKER_VARS=(
      -var "output_format=$OUTPUT_FORMAT"
      -var "accelerator=$PACKER_ACCELERATOR_FALLBACK"
      -var "enable_cloud_init=true"
      -var "harden_ssh=true"
    )
    # Install open-vm-tools automatically for vmdk builds
    if [[ "$OUTPUT_FORMAT" == "vmdk" ]]; then
      PACKER_VARS+=( -var "install_open_vm_tools=true" )
    fi
    if [[ -n "$debian_version" ]]; then
      PACKER_VARS+=( -var "debian_version=$debian_version" )
    fi
    packer build "${PACKER_VARS[@]}" shart-linux.pkr.hcl
    
    # Move output to root directory
    log "Moving output files..."
    mv "output-$OUTPUT_FORMAT/shart-linux.$OUTPUT_FORMAT" ../
    
    # Calculate checksum
    cd ..
    sha256sum "shart-linux.$OUTPUT_FORMAT" > "shart-linux.$OUTPUT_FORMAT.sha256"
    
    log "VM image created: shart-linux.$OUTPUT_FORMAT"
    log "Checksum file: shart-linux.$OUTPUT_FORMAT.sha256"
    log "Default credentials: root/shart123 or ctfuser/shart123"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
