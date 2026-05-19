packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/qemu"
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
  default = "rocky9-arm64-qemu.box"
}

variable "disk_size" {
  type    = string
  default = "20G"
}

variable "disk_virtual_size" {
  type    = number
  default = 20
}

variable "output_directory" {
  type    = string
  default = "output-rocky9-arm64"
}

variable "efi_firmware_code" {
  type    = string
  default = "/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
}

variable "efi_firmware_vars" {
  type    = string
  default = "/opt/homebrew/share/qemu/edk2-arm-vars.fd"
}

variable "boot_kernel" {
  type    = string
  default = "boot/vmlinuz"
}

variable "boot_initrd" {
  type    = string
  default = "boot/initrd.img"
}

variable "qemu_binary" {
  type    = string
  default = "qemu-system-aarch64"
}

variable "qemu_accelerator" {
  type    = string
  default = "hvf"
}

variable "qemu_machine_type" {
  type    = string
  default = "virt,highmem=off"
}

source "qemu" "rocky9_arm64" {
  vm_name          = "rocky9-arm64"
  output_directory = var.output_directory

  iso_url      = var.rocky_iso_url
  iso_checksum = var.rocky_iso_checksum

  qemu_binary  = var.qemu_binary
  machine_type = var.qemu_machine_type
  cpu_model    = "host"

  accelerator = var.qemu_accelerator

  cpus   = 2
  memory = 2048

  disk_size      = var.disk_size
  format         = "qcow2"
  disk_interface = "virtio"
  net_device     = "virtio-net-device"

  headless = true

  efi_boot = true

  efi_firmware_code = var.efi_firmware_code
  efi_firmware_vars = var.efi_firmware_vars

  qemuargs = [
    ["-kernel", var.boot_kernel],
    ["-initrd", var.boot_initrd],
    ["-append", "inst.stage2=hd:LABEL=Rocky-9-7-aarch64-dvd inst.text inst.cmdline inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg console=ttyAMA0,115200n8"],
    ["-serial", "file:${var.output_directory}/serial.log"],
    ["-device", "qemu-xhci"],
    ["-device", "usb-kbd"],
    ["-device", "usb-mouse"]
  ]

  http_directory = "http"

  communicator = "none"

  boot_wait    = "5s"
  boot_command = []
}

build {
  sources = ["source.qemu.rocky9_arm64"]

  post-processor "shell-local" {
    inline = [
      "rm -rf box",
      "mkdir -p box",
      "cp ${var.output_directory}/rocky9-arm64 box/box.img",
      "cat > box/metadata.json <<'EOF'\n{\"provider\":\"qemu\",\"format\":\"qcow2\",\"virtual_size\":${var.disk_virtual_size},\"architecture\":\"arm64\",\"disks\":[{\"path\":\"box.img\",\"format\":\"qcow2\"}]}\nEOF",
      "cp vagrantfiles/qemu.rb box/Vagrantfile",
      "tar -C box -czf ${var.box_name} box.img metadata.json Vagrantfile"
    ]
  }
}
