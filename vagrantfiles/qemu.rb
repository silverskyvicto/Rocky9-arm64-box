require "rbconfig"

host_os = RbConfig::CONFIG["host_os"]
host_cpu = RbConfig::CONFIG["host_cpu"]

unless host_cpu == "arm64" || host_cpu == "aarch64"
  raise "This box requires an arm64/aarch64 host, but detected #{host_cpu}."
end

accelerator =
  case host_os
  when /darwin/
    "hvf"
  when /linux/
    "kvm"
  else
    "tcg"
  end

qemu_dir =
  [
    "/opt/homebrew/share/qemu",
    "/usr/local/share/qemu",
    "/usr/share/qemu",
  ].find { |path| Dir.exist?(path) }

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "qemu" do |qe|
    qe.arch = "aarch64"
    qe.machine = "virt,accel=#{accelerator},highmem=off"
    qe.cpu = "host"
    qe.smp = "2"
    qe.memory = "2G"
    qe.net_device = "virtio-net-device"
    qe.drive_interface = "virtio"
    qe.qemu_dir = qemu_dir if qemu_dir
    qe.firmware_format = "raw"
  end
end
