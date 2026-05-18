PACKER_FILE ?= rocky9-arm64.pkr.hcl
BOX_NAME ?= rocky9-arm64-qemu.box

.PHONY: build validate extract-boot clean distclean

build: extract-boot validate
	packer build -force -var "rocky_iso_checksum=sha256:$$(scripts/resolve-iso-checksum.sh)" $(PACKER_FILE)

validate:
	rm -rf .packer-validate-output
	packer validate -var 'output_directory=.packer-validate-output' -var "rocky_iso_checksum=sha256:$$(scripts/resolve-iso-checksum.sh)" $(PACKER_FILE)

extract-boot:
	scripts/extract-boot.sh

clean:
	rm -rf output-rocky9-arm64 .packer-validate-output box

distclean: clean
	rm -rf boot packer_cache $(BOX_NAME)
