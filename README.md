# shart.linux

A parody Debian-based Linux distribution inspired by Amazon Linux 2/AL2023, built specifically for CTF scenarios and educational purposes.

## Features

- 🎯 **CTF-Optimized**: Minimal attack surface with essential tools pre-installed
- 🛠️ **Terraform Ready**: HashiCorp repository configured with Terraform pre-installed
- 📦 **Multi-Format**: Available as both container images and VM disk images
- 🏗️ **Multi-Architecture**: Supports AMD64 and ARM64 architectures
- 🚀 **Automated Builds**: GitHub Actions CI/CD with security scanning

## Quick Start

### Container Usage

```bash
# Pull the latest image
docker pull ghcr.io/your-username/shart.linux:latest

# Run interactively
docker run -it --rm ghcr.io/your-username/shart.linux:latest

# Check Terraform installation
docker run --rm ghcr.io/your-username/shart.linux:latest terraform version
```

### VM Usage

1. Download VM images from the [releases page](https://github.com/your-username/shart.linux/releases)
2. Choose your format:
   - `shart-linux.qcow2` for QEMU/KVM
   - `shart-linux.vmdk` for VMware

#### QEMU Example
```bash
# Download the qcow2 image
wget https://github.com/your-username/shart.linux/releases/latest/download/shart-linux.qcow2

# Boot with QEMU
qemu-system-x86_64 -m 512 -hda shart-linux.qcow2
```

#### VMware Example
Import the `shart-linux.vmdk` file into VMware Workstation/vSphere.

### Default Credentials

- **Root**: `root` / `shart123`  
- **User**: `ctfuser` / `shart123`

## Development

### Building Locally

#### Container Image
```bash
docker build -t shart.linux:local container/
docker run -it --rm shart.linux:local
```

#### VM Image
```bash
# Requires root privileges
sudo ./scripts/build-vm.sh qcow2
# or
sudo ./scripts/build-vm.sh vmdk
```

### Project Structure

```
shart.linux/
├── assets/
│   └── motd.txt              # ASCII art MOTD
├── container/
│   └── Dockerfile            # Container image definition
├── scripts/
│   └── build-vm.sh          # VM image build script
├── vm/                      # VM-specific configurations
├── .github/workflows/
│   └── build.yml            # CI/CD pipeline
└── CLAUDE.md               # Development guidance
```

## Customizations

### Message of the Day (MOTD)
Features custom ASCII art branding that displays on login, parodying Amazon Linux.

### HashiCorp Repository
Pre-configured with official HashiCorp Debian repository for easy installation of:
- Terraform (pre-installed)
- Vault, Consul, Nomad (available via `apt install`)

### System Configuration
- Hostname: `shart-linux`
- Custom shell prompt: `[user@shart-linux dir]$`
- Minimal service footprint for security
- SSH enabled for VM images

## Use Cases

- **CTF Competitions**: Isolated, controlled environment for challenges
- **Security Training**: Practice environment with known configurations
- **Development**: Terraform testing and development
- **Educational**: Learning Linux system administration

## Security Notes

- Default passwords are intentionally weak for CTF scenarios
- Change default credentials in production use
- Images undergo automated security scanning via Trivy
- Minimal package installation reduces attack surface

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally using the build commands above
5. Submit a pull request

## License

This project is for educational and entertainment purposes. See [LICENSE](LICENSE) for details.

## Disclaimer

This is a parody project and is not affiliated with Amazon Web Services or Amazon Linux. It's designed purely for educational and CTF purposes.