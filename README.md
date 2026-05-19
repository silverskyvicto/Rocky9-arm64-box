# Rocky9-arm64-box

Rocky Linux 9.7 aarch64 の Vagrant box を、Apple Silicon Mac 上の QEMU/HVF または Linux arm64 上の QEMU/KVM 向けに作成するための Packer 設定です。

## 前提

- Apple Silicon Mac または Linux arm64/aarch64 ホスト
- QEMU
  - macOS: Homebrew 版 QEMU
  - Linux: `qemu-system-aarch64` と AAVMF/EDK2 firmware
- Packer
- Vagrant
- vagrant-qemu plugin
- VirtualBox 7.2 以降 (VirtualBox 用 box を作る場合)
- p7zip
- xorriso (VirtualBox 用 ISO を作る場合)

```sh
brew install qemu packer p7zip xorriso
vagrant plugin install vagrant-qemu
```

Linux arm64 ではディストリビューションに応じて QEMU/KVM と firmware パッケージを入れてください。例として Debian/Ubuntu 系では `qemu-system-arm` と `qemu-efi-aarch64`、RHEL 系では `qemu-kvm` と `edk2-aarch64` が必要です。

## ビルド

通常は次のコマンドだけで、boot assets の抽出、Packer 設定検証、box 作成まで実行します。

```sh
make build
```

`make build` は `scripts/qemu-host-vars.sh` でホストを判定し、macOS arm64 では `hvf`、Linux arm64/aarch64 では `kvm` を Packer に渡します。生成される QEMU 用 box の Vagrantfile も実行時にホストを判定するため、Apple Silicon macOS と Linux arm64 のどちらでも同じ box を起動できます。

生成される box は次のファイルです。

```text
rocky9-arm64-qemu.box
```

作成した box は次のように追加できます。

```sh
vagrant box add --force rocky9-arm64-qemu rocky9-arm64-qemu.box
```

## VirtualBox 用 box のビルド

VirtualBox 用 box は別ターゲットで作成します。

```sh
make build-vbox
```

生成される box は次のファイルです。

```text
rocky9-arm64-virtualbox.box
```

作成した box は次のように追加できます。

```sh
vagrant box add --force rocky9-arm64-virtualbox rocky9-arm64-virtualbox.box
```

VirtualBox 版は QEMU 版と異なり、ISO の UEFI/GRUB から起動します。VirtualBox ARM では Packer のキー入力が使えないため、`scripts/prepare-vbox-iso.sh` が元の Rocky ISO の起動情報を保ったまま GRUB 設定と Kickstart だけを差し替えた VirtualBox 用 ISO を `packer_cache/Rocky-9.7-aarch64-minimal-vbox.iso` に生成します。インストール後は再起動して SSH 接続を待ち、Packer が shutdown してから box 化します。そのため `boot/` の抽出は不要です。また、VirtualBox ではインストールディスクが通常 `sda` として見えるため、専用の `http/ks-vbox.cfg` を使います。

VirtualBox ARM ではインストールに時間がかかることがあるため、SSH 待ちは既定で 90 分にしています。途中状態を確認したい場合は次のデバッグ用ターゲットを使います。失敗時に VM を残し、Packer が停止するので、ログに出る `rdp://127.0.0.1:PORT` へ接続して画面を確認できます。

```sh
make build-vbox-debug
```

## ISO の指定

`make build` は `scripts/extract-boot.sh` を先に実行します。このスクリプトは次の順で Rocky Linux 9.7 aarch64 minimal ISO を探します。

1. `ISO_PATH` で指定された ISO
2. Packer のキャッシュディレクトリ、通常は `~/.cache/packer`
3. `packer_cache/Rocky-9.7-aarch64-minimal.iso` へのダウンロード

ISO の checksum は `scripts/resolve-iso-checksum.sh` が `Rocky-9.7-aarch64-minimal.iso.CHECKSUM` を取得して解決します。取得した CHECKSUM ファイルは `packer_cache/` に保存され、Git には含めません。Packer 実行時も `Makefile` から `rocky_iso_checksum` 変数として渡します。

ローカルに ISO がある場合は、次のように指定できます。

```sh
ISO_PATH=/path/to/Rocky-9.7-aarch64-minimal.iso make build
```

## なぜ boot/ を抽出するのか

この Packer 設定では QEMU の direct kernel boot を使います。

```hcl
["-kernel", var.boot_kernel],
["-initrd", var.boot_initrd],
["-append", "... inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ..."],
```

つまり、ISO 内の GRUB を経由せず、ISO に含まれるインストーラ用 `vmlinuz` と `initrd.img` を QEMU に直接渡して Anaconda を起動します。そのため、ビルド前に ISO から次の2ファイルを取り出しておく必要があります。

```text
boot/vmlinuz
boot/initrd.img
```

本リポジトリではこれを手作業にせず、`scripts/extract-boot.sh` と `Makefile` で自動化しています。`boot/` は ISO から再生成できる大きめのバイナリなので Git には含めません。

## direct kernel boot を採用した理由

当初は通常の ISO ブート、つまり UEFI から ISO 内の GRUB メニューを起動し、Packer の `boot_command` で Kickstart パラメータを入力する方式も試しました。しかし Apple Silicon Mac 上の QEMU/VNC 経由入力では、GRUB へのキー入力タイミングや入力位置が不安定で、Kickstart なしの通常インストーラへ落ちることがありました。

direct kernel boot では GRUB へのキー入力を避けられます。Packer が QEMU に `-kernel`、`-initrd`、`-append` を直接渡すため、Kickstart URL や serial console の指定が安定して反映されます。

一方で direct kernel boot のまま `reboot` すると、インストール後も再びインストーラ用カーネルで起動してしまいます。そのため `http/ks.cfg` では `poweroff` を使い、インストール完了後に VM を停止させています。Packer 側は `communicator = "none"` とし、SSH 接続を待たずに VM の停止を待ってから box を作成します。

## 主なファイル

- `rocky9-arm64.pkr.hcl`: Packer/QEMU/Vagrant box 作成設定
- `rocky9-arm64-virtualbox.pkr.hcl`: Packer/VirtualBox/Vagrant box 作成設定
- `http/ks.cfg`: Rocky Linux の Kickstart
- `http/ks-vbox.cfg`: VirtualBox 用の Rocky Linux Kickstart
- `scripts/extract-boot.sh`: ISO から `boot/vmlinuz` と `boot/initrd.img` を抽出
- `scripts/qemu-host-vars.sh`: QEMU build 用の accelerator と EFI firmware path をホストに応じて解決
- `scripts/prepare-vbox-iso.sh`: VirtualBox 用に GRUB/Kickstart 入り ISO を生成
- `scripts/resolve-iso-checksum.sh`: Rocky Linux の CHECKSUM ファイルを取得し、ISO の SHA256 を解決
- `Makefile`: `make build` などのビルド用入口

## よく使うコマンド

```sh
make extract-boot
make prepare-vbox-iso
make validate
make validate-vbox
make build
make build-vbox
make build-vbox-debug
make clean
make distclean
```
