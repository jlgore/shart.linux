# shart.linux Packer Configuration

This directory contains the Packer configuration for building shart.linux VM images.

## Prerequisites

- [Packer](https://www.packer.io/downloads) >= 1.10.0
- QEMU/KVM for virtualization
- Internet connection for downloading Debian ISO and packages

## Usage

### Build locally

```bash
# From repository root
./scripts/build-vm-packer.sh qcow2
./scripts/build-vm-packer.sh vmdk

# Or directly with Packer
cd packer
packer init .
packer build -var "output_format=qcow2" shart-linux.pkr.hcl
```

Note: The build script resolves the latest Debian stable automatically. To pin a specific point release, set `DEBIAN_VERSION=x.y.z`. Older point releases may be moved to the Debian CD archive and would require updating the base URL in the template if you intentionally target them.

### Variables

- `output_format`: Image format (`qcow2` or `vmdk`)
- `accelerator`: QEMU accelerator (`kvm` or `tcg`; default `kvm`). The build script falls back to `tcg` when `/dev/kvm` is not writable.
- `disk_interface`: Disk interface (`virtio`, `scsi`, `ide`, `sata`; default `virtio`).
- `disk_size`: Disk size (default: `3G`).
- `memory`: RAM for build VM (default: `2048`).
- `cpus`: Number of CPUs (default: `2`).
- `vnc_bind_address`: Bind address for VNC (default: `127.0.0.1`). Set to `0.0.0.0` only for debugging on trusted networks.
- `debian_version`: Debian release used for the installer ISO and checksum lookup. The build script auto-detects the latest stable from `current` and passes it to Packer unless you override via env var `DEBIAN_VERSION` or `-var`. The template’s default is pinned for reproducibility.
- `enable_cloud_init` (bool): Install and enable cloud-init (default: `true`). Recommended for most cloud providers (OpenStack, CloudStack, Proxmox, generic KVM).
- `harden_ssh` (bool): Disable password auth and root login in the final image (default: `true`). Packer still uses password auth during provisioning, but the final image ships hardened.
- `install_open_vm_tools` (bool): Install `open-vm-tools` (default: `false`). Set `true` when building `vmdk` for VMware.
- `install_terraform` (bool): Install Terraform inside the image (default: `false`). Typically not recommended for cloud images; leave `false` unless you have a specific use case.
- `create_local_user` (bool): Create a local user in the image (default: `false`). With cloud-init, users+keys are usually injected by the platform.
- `local_username`, `local_password`: Credentials for the local user when `create_local_user=true`.

### Custom variables

```bash
DEBIAN_VERSION=12.8.0 packer build \
  -var "output_format=vmdk" \
  -var "accelerator=tcg" \
  -var "install_open_vm_tools=true" \
  -var "enable_cloud_init=true" \
  -var "harden_ssh=true" \
  -var "disk_size=5G" \
  -var "memory=4096" \
  -var "debian_version=${DEBIAN_VERSION}" \
  shart-linux.pkr.hcl
```

## Files

- `shart-linux.pkr.hcl`: Main Packer template
- `simple-build.pkr.hcl.disabled`: Alternate minimal template (rename to `.pkr.hcl` to use directly)
- `http/preseed.cfg`: Debian preseed configuration for automated installation
- `scripts/`: Provisioning scripts
  - `install-packages.sh`: Install base packages
  - `configure-system.sh`: System configuration (cloud-init aware; enables qemu-guest-agent)
  - `install-terraform.sh`: Optional Terraform install (guarded by `install_terraform`)
  - `create-users.sh`: Optional local user creation (guarded by `create_local_user`)
  - `cleanup.sh`: Clean up before image creation, optional SSH hardening and cloud-init reset

## Output

Built images are placed in `output-{format}/` directory and copied to the repository root as `shart-linux.{format}`.

## Cloud image guidance

- Install `cloud-init` and `qemu-guest-agent` for most KVM-based providers. This template does so by default.
- Consider `open-vm-tools` when producing `vmdk` for VMware/ESXi/vSphere; enable via `-var install_open_vm_tools=true`.
- The image ships with SSH password login and root login disabled by default after provisioning. Use platform-injected SSH keys or a cloud-init `#cloud-config` to access.
- If your cloud requires UEFI rather than BIOS, we can add an optional `efi_boot` toggle that uses OVMF on the build host. Let me know and I’ll wire that in.
