packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = ">= 1.1.5"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

variable "rocky_iso_url" {
  type    = string
  default = "https://dl.rockylinux.org/pub/rocky/9/isos/aarch64/Rocky-9.7-aarch64-minimal.iso"
}

# Makefile から実行する場合は scripts/resolve-iso-checksum.sh で取得した値を渡す。
# この default は Packer を直接実行する場合の fallback。
variable "rocky_iso_checksum" {
  type    = string
  default = "sha256:7a73b4dc3426053082d1a3fb28cc594f92133354b5ec16ccd5fd06875c35645f"
}

variable "box_name" {
  type    = string
  default = "rocky9-arm64-virtualbox.box"
}

variable "disk_size" {
  type    = number
  default = 20480
}

variable "output_directory" {
  type    = string
  default = "output-rocky9-arm64-virtualbox"
}

variable "virtualbox_guest_os_type" {
  type    = string
  default = "RedHat9_arm64"
}

variable "ssh_timeout" {
  type    = string
  default = "90m"
}

variable "keep_registered" {
  type    = bool
  default = false
}

source "virtualbox-iso" "rocky9_arm64" {
  vm_name          = "rocky9-arm64-virtualbox"
  output_directory = var.output_directory

  iso_url      = var.rocky_iso_url
  iso_checksum = var.rocky_iso_checksum

  guest_os_type = var.virtualbox_guest_os_type
  firmware      = "efi"

  cpus   = 2
  memory = 2048

  disk_size            = var.disk_size
  hard_drive_interface = "sata"
  iso_interface        = "sata"
  sata_port_count      = 4

  headless = true

  communicator = "ssh"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout  = var.ssh_timeout

  shutdown_command = "echo 'vagrant' | sudo -S /sbin/poweroff"
  shutdown_timeout = "10m"

  boot_wait    = "10s"
  boot_command = []

  guest_additions_mode = "disable"
  keep_registered      = var.keep_registered

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--rtcuseutc", "on"],
    ["modifyvm", "{{ .Name }}", "--boot1", "dvd"],
    ["modifyvm", "{{ .Name }}", "--boot2", "disk"],
    ["modifyvm", "{{ .Name }}", "--boot3", "none"],
    ["modifyvm", "{{ .Name }}", "--boot4", "none"]
  ]
}

build {
  sources = ["source.virtualbox-iso.rocky9_arm64"]

  post-processor "vagrant" {
    output               = var.box_name
    provider_override    = "virtualbox"
    vagrantfile_template = "vagrantfiles/virtualbox.rb"
    keep_input_artifact  = false
  }
}
