# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

shart.linux is a parody Linux distribution based on Debian, mimicking Amazon Linux 2/AL2023. The project builds container and VM images via GitHub Actions and publishes them to GitHub Container Registry (GHCR) and GitHub Artifacts for use in CTF games.

## Core Architecture

### Build Process
- **Base**: Debian bookworm-slim container image (containers) / Debian bookworm netinst ISO (VMs)
- **Build Method**: Multi-stage Docker builds (containers) / Packer with automated Debian installation (VMs)
- **CI/CD**: GitHub Actions workflows with matrix builds for multiple architectures (amd64, arm64)
- **Distribution**: Images pushed to GHCR (`ghcr.io/owner/shart.linux`) and artifacts stored in GitHub releases

### Key Components

**Container Images**:
- `container/`: Dockerfile and related files for containerized shart.linux
- Multi-architecture support using Docker Buildx
- Optimized layers for CTF deployment scenarios

**VM Images**:  
- `packer/`: Packer templates and provisioning scripts for building bootable VM images
- Uses automated Debian installation with preseed configuration
- GRUB2 bootloader configuration for legacy BIOS and UEFI
- Supports multiple output formats (qcow2, vmdk)

**GitHub Actions**:
- `.github/workflows/build.yml`: Main build workflow
- Matrix strategy for multiple image types and architectures
- Automated testing and security scanning

## Essential Commands

### Build locally
```bash
# Build container image
docker build -t shart.linux:latest container/

# Build VM image with Packer
./scripts/build-vm-packer.sh qcow2
./scripts/build-vm-packer.sh vmdk

# Build VM image directly with Packer
cd packer && packer build -var "output_format=qcow2" shart-linux.pkr.hcl

# Test container locally
docker run -it --rm shart.linux:latest
```

### Development workflow
```bash
# Validate Dockerfile
docker build --dry-run container/

# Validate Packer template
cd packer && packer validate shart-linux.pkr.hcl

# Test scripts without building
shellcheck scripts/*.sh packer/scripts/*.sh

# Check GitHub Actions syntax
yamllint .github/workflows/
```

## Customizations

### MOTD (Message of the Day)
- ASCII art stored in `assets/motd.txt`
- Installed to `/etc/motd` during build process
- Parodies Amazon Linux branding with "shart" theme

### Package Sources
- HashiCorp Debian repository configured for Terraform installation
- GPG key verification implemented in build scripts
- Repository: `https://apt.releases.hashicorp.com`

### Default Software
- Terraform (latest stable from HashiCorp repo)
- Standard Debian utilities optimized for CTF environments
- No unnecessary services or daemons to minimize attack surface

## Build Artifacts

**Container Registry**:
- `ghcr.io/owner/shart.linux:latest` - Rolling latest build
- `ghcr.io/owner/shart.linux:v*` - Tagged releases
- Multi-arch manifests for amd64/arm64

**GitHub Releases**:
- VM disk images (qcow2, vmdk formats) 
- Container tarballs for offline deployment
- SHA256 checksums and GPG signatures

## Testing Strategy

Images are validated through:
- Container security scanning (Trivy)
- Boot testing in QEMU for VM images  
- Terraform functionality verification
- MOTD display confirmation

## Security Considerations

- Minimal base system reduces attack surface
- No default root password (key-based access only)
- Package signatures verified during build
- Build process runs in isolated GitHub Actions runners