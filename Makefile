PACKER_FILE ?= rocky9-arm64.pkr.hcl
VBOX_PACKER_FILE ?= rocky9-arm64-virtualbox.pkr.hcl
BOX_NAME ?= rocky9-arm64-qemu.box
VBOX_BOX_NAME ?= rocky9-arm64-virtualbox.box
ROCKY_ISO_CHECKSUM = sha256:$(shell scripts/resolve-iso-checksum.sh)
QEMU_HOST_VARS = $(shell scripts/qemu-host-vars.sh)
VBOX_ISO ?= packer_cache/Rocky-9.7-aarch64-minimal-vbox.iso
VBOX_ISO_CHECKSUM = sha256:$(shell shasum -a 256 "$(VBOX_ISO)" | awk '{print $$1}')
VBOX_LOG_ENV = VBOX_RELEASE_LOG_DEST=nofile VBOX_LOG_DEST=nofile

.PHONY: build build-vbox build-vbox-debug validate validate-vbox prepare-vbox-iso extract-boot clean distclean

build: extract-boot validate
	packer build -force -var "rocky_iso_checksum=$(ROCKY_ISO_CHECKSUM)" $(QEMU_HOST_VARS) $(PACKER_FILE)

build-vbox: prepare-vbox-iso validate-vbox
	$(VBOX_LOG_ENV) packer build -force -var "rocky_iso_url=$(VBOX_ISO)" -var "rocky_iso_checksum=$(VBOX_ISO_CHECKSUM)" -var "box_name=$(VBOX_BOX_NAME)" $(VBOX_PACKER_FILE)

build-vbox-debug: prepare-vbox-iso validate-vbox
	$(VBOX_LOG_ENV) packer build -force -on-error=ask -var "rocky_iso_url=$(VBOX_ISO)" -var "rocky_iso_checksum=$(VBOX_ISO_CHECKSUM)" -var "box_name=$(VBOX_BOX_NAME)" -var "keep_registered=true" $(VBOX_PACKER_FILE)

validate:
	rm -rf .packer-validate-output
	packer validate -var 'output_directory=.packer-validate-output' -var "rocky_iso_checksum=$(ROCKY_ISO_CHECKSUM)" $(QEMU_HOST_VARS) $(PACKER_FILE)

validate-vbox:
	rm -rf .packer-validate-output-vbox
	packer validate -var 'output_directory=.packer-validate-output-vbox' -var "rocky_iso_checksum=$(ROCKY_ISO_CHECKSUM)" -var "box_name=$(VBOX_BOX_NAME)" $(VBOX_PACKER_FILE)

prepare-vbox-iso:
	scripts/prepare-vbox-iso.sh >/dev/null

extract-boot:
	scripts/extract-boot.sh

clean:
	rm -rf output-rocky9-arm64 output-rocky9-arm64-virtualbox .packer-validate-output .packer-validate-output-vbox box

distclean: clean
	rm -rf boot packer_cache $(BOX_NAME) $(VBOX_BOX_NAME)
