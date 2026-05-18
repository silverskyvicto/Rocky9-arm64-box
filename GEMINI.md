# Rocky Linux 9 ARM64 Vagrant Box Build

This project automates the creation of a Rocky Linux 9.7 (aarch64) Vagrant box for the `vagrant-qemu` provider. It uses HashiCorp Packer with the QEMU builder, specifically optimized for running on Apple Silicon (macOS) via the `hvf` accelerator.

## Project Structure

- `rocky9-arm64.pkr.hcl`: The main Packer configuration file defining the build process.
- `http/ks.cfg`: A Kickstart file for automated OS installation (Rocky Linux 9).
- `scripts/cleanup.sh`: A shell script for cleaning up the VM before finalizing the image.
- `Rocky-9.7-aarch64-minimal.iso.CHECKSUM`: Checksum file for the source ISO.

## Prerequisites

- **Packer:** Installed and available in the system path.
- **QEMU:** Specifically `qemu-system-aarch64` with EFI support (EDK2).
  - Note: EFI firmware paths are configured for Homebrew on macOS (`/opt/homebrew/share/qemu/`).
- **Vagrant QEMU provider:** Install with `vagrant plugin install vagrant-qemu`.
- **Plugins:** The `qemu` Packer plugin is required.

## Building the Box

To build the Vagrant box, follow these steps:

1. **Initialize Packer Plugins:**
   ```bash
   packer init rocky9-arm64.pkr.hcl
   ```

2. **Run the Build:**
   ```bash
   packer build rocky9-arm64.pkr.hcl
   ```

The build process will:
1. Download the Rocky Linux ISO (if not already cached).
2. Boot a QEMU VM and install the OS using the Kickstart file.
3. Run the `cleanup.sh` provisioner.
4. Post-process the output into a `.box` file (`rocky9-arm64-qemu.box`).

## Using the Box

```bash
vagrant box add rocky9-arm64-qemu rocky9-arm64-qemu.box
mkdir -p test-rocky9-arm64
cd test-rocky9-arm64
vagrant init rocky9-arm64-qemu
vagrant up --provider qemu
```

## Development Conventions

- **Default User:** `vagrant` (password: `vagrant`) with passwordless sudo.
- **Architecture:** aarch64 (ARM64).
- **Output Format:** qcow2 inside a Vagrant box compatible with `vagrant-qemu`.
- **Minimal Environment:** The OS is installed with the `@^minimal-environment` group to keep the box size small.

## Customization

- **EFI Firmware:** If your EDK2 firmware paths differ from the Homebrew defaults, update the `efi_firmware_code` and `efi_firmware_vars` variables in `rocky9-arm64.pkr.hcl`.
- **Software Packages:** Add or remove packages in the `%packages` section of `http/ks.cfg`.
- **SSH Key:** The `%post` section of `http/ks.cfg` installs Vagrant's standard insecure public key for the `vagrant` user.
