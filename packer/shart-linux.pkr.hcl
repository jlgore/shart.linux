packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "output_format" {
  type        = string
  description = "Output format for the VM image"
  default     = "qcow2"
  validation {
    condition     = contains(["qcow2", "vmdk"], var.output_format)
    error_message = "Output format must be either 'qcow2' or 'vmdk'."
  }
}

variable "accelerator" {
  type        = string
  description = "QEMU accelerator to use (kvm or tcg)"
  default     = "kvm"
  validation {
    condition     = contains(["kvm", "tcg"], var.accelerator)
    error_message = "Accelerator must be either 'kvm' or 'tcg'."
  }
}

variable "disk_size" {
  type        = string
  description = "Size of the disk image"
  default     = "3G"
}

variable "disk_interface" {
  type        = string
  description = "Disk interface for the virtual disk"
  default     = "virtio"
  validation {
    condition     = contains(["virtio", "scsi", "ide", "sata"], var.disk_interface)
    error_message = "Disk interface must be one of: virtio, scsi, ide, sata."
  }
}

variable "memory" {
  type        = string
  description = "Amount of memory for the build VM"
  default     = "2048"
}

variable "cpus" {
  type        = number
  description = "Number of CPUs for the build VM"
  default     = 2
}

// Pin Debian release to ensure checksum matches
variable "debian_version" {
  type        = string
  description = "Debian release version (e.g., 13.1.0)"
  default     = "13.1.0"
}

variable "vnc_bind_address" {
  type        = string
  description = "Address to bind the VNC server to (for debug builds)"
  default     = "127.0.0.1"
}

variable "install_terraform" {
  type        = bool
  description = "Install Terraform inside the image (not typical for cloud images)"
  default     = false
}

variable "install_open_vm_tools" {
  type        = bool
  description = "Install open-vm-tools (recommended when building vmdk for VMware)"
  default     = false
}

variable "enable_cloud_init" {
  type        = bool
  description = "Install and enable cloud-init for first-boot configuration"
  default     = true
}

variable "harden_ssh" {
  type        = bool
  description = "Harden SSH by disabling password auth and root login in the final image"
  default     = true
}

variable "create_local_user" {
  type        = bool
  description = "Create a local default user in the image (not needed with cloud-init)"
  default     = false
}

variable "local_username" {
  type        = string
  description = "Username to create if create_local_user is true"
  default     = "debian"
}

variable "local_password" {
  type        = string
  description = "Password for the created user if create_local_user is true"
  sensitive   = true
  default     = "changeMe123!"
}

source "qemu" "debian" {
  // Use versioned paths so the ISO filename appears in the checksum file
  iso_url      = "https://cdimage.debian.org/debian-cd/${var.debian_version}/amd64/iso-cd/debian-${var.debian_version}-amd64-netinst.iso"
  iso_checksum = "file:https://cdimage.debian.org/debian-cd/${var.debian_version}/amd64/iso-cd/SHA256SUMS"

  output_directory = "output-${var.output_format}"
  vm_name          = "shart-linux.${var.output_format}"

  disk_size = var.disk_size
  memory    = var.memory
  cpus      = var.cpus

  accelerator    = var.accelerator
  format         = var.output_format
  disk_interface = var.disk_interface

  headless         = true
  vnc_bind_address = var.vnc_bind_address

  net_device = "virtio-net"

  boot_wait         = "10s"
  boot_key_interval = "10ms"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><end>",
    " auto=true priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "debian-installer/locale=en_US.UTF-8 ",
    "debian-installer/language=en ",
    "debian-installer/country=US ",
    "keyboard-configuration/xkb-keymap=us ",
    "netcfg/choose_interface=auto ",
    "netcfg/get_hostname=shart-linux ",
    "netcfg/get_domain=local ",
    "fb=false ",
    "debconf/frontend=noninteractive ",
    "console-setup/ask_detect=false ",
    "console-keymaps-at/keymap=us ",
    "grub-installer/bootdev=/dev/vda ",
    " --- ",
    "<f10>"
  ]

  http_directory = "http"

  ssh_username           = "root"
  ssh_password           = "shart123"
  ssh_timeout            = "20m"
  ssh_handshake_attempts = 60
  ssh_pty                = true

  shutdown_command = "shutdown -P now"
}

build {
  sources = ["source.qemu.debian"]

  provisioner "shell" {
    environment_vars = [
      "OUTPUT_FORMAT=${var.output_format}",
      "INSTALL_TERRAFORM=${var.install_terraform}",
      "INSTALL_OPEN_VM_TOOLS=${var.install_open_vm_tools}",
      "ENABLE_CLOUD_INIT=${var.enable_cloud_init}",
      "CREATE_LOCAL_USER=${var.create_local_user}",
      "LOCAL_USERNAME=${var.local_username}",
      "LOCAL_PASSWORD=${var.local_password}",
    ]
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "apt-get update -qq",
      "apt-get upgrade -y -qq"
    ]
  }

  provisioner "file" {
    source      = "../assets/motd.txt"
    destination = "/etc/motd"
  }

  provisioner "shell" {
    environment_vars = [
      "OUTPUT_FORMAT=${var.output_format}",
      "INSTALL_OPEN_VM_TOOLS=${var.install_open_vm_tools}",
      "ENABLE_CLOUD_INIT=${var.enable_cloud_init}",
    ]
    script = "scripts/install-packages.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "ENABLE_CLOUD_INIT=${var.enable_cloud_init}",
    ]
    script = "scripts/configure-system.sh"
  }

  provisioner "shell" {
    only = ["qemu.debian"]
    environment_vars = [
      "INSTALL_TERRAFORM=${var.install_terraform}",
    ]
    script = "scripts/install-terraform.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "CREATE_LOCAL_USER=${var.create_local_user}",
      "LOCAL_USERNAME=${var.local_username}",
      "LOCAL_PASSWORD=${var.local_password}",
    ]
    script = "scripts/create-users.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "HARDEN_SSH=${var.harden_ssh}",
      "ENABLE_CLOUD_INIT=${var.enable_cloud_init}",
    ]
    script = "scripts/cleanup.sh"
  }

  post-processor "shell-local" {
    inline = [
      "echo 'VM image built successfully: output-${var.output_format}/shart-linux.${var.output_format}'",
      "sha256sum output-${var.output_format}/shart-linux.${var.output_format} > shart-linux.${var.output_format}.sha256",
      "if command -v qemu-img >/dev/null 2>&1; then qemu-img info output-${var.output_format}/shart-linux.${var.output_format}; fi"
    ]
  }
}
