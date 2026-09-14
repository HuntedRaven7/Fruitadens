set shell := ["bash", "-c"]

# Image configuration
REGISTRY := "ghcr.io"
IMAGE_NAME := "fruitadens"
UPSTREAM_IMAGE := "quay.io/fedora/fedora-coreos:stable"

# Streams
streams := stable testing

# Derived
containerfile := "Containerfile"
date := `date +%Y%m%d`

.PHONY: help clean build push test-vm validate installer-build installer-push installer-iso

help:
	@echo "Fruitadens build system"
	@echo ""
	@echo "Targets:"
	@echo "  build        - Build the Containerfile.in (preprocess with cpp)"
	@echo "  build-stable - Build and tag as :stable-YYYYMMDD and :stable"
	@echo "  build-testing- Build and tag as :testing-YYYYMMDD and :testing"
	@echo "  push         - Push all stream tags to registry"
	@echo "  test-vm      - Boot image in QEMU via bootc install --via-loopback"
	@echo "  clean        - Remove generated Containerfile and build artifacts"
	@echo ""
	@echo "Installer targets:"
	@echo "  installer-build  - Build the installer container image"
	@echo "  installer-push   - Push the installer container image"
	@echo "  installer-iso    - Build a bootable installer ISO (requires lorax)"

build:
	cpp -P -C -traditional-cpp Containerfile.in > $(containerfile)
	podman build --layers -f $(containerfile) -t $(REGISTRY)/$(IMAGE_NAME):local .

build-stable: build
	podman tag $(REGISTRY)/$(IMAGE_NAME):local $(REGISTRY)/$(IMAGE_NAME):stable-$(date)
	podman tag $(REGISTRY)/$(IMAGE_NAME):local $(REGISTRY)/$(IMAGE_NAME):stable

build-testing: build
	podman tag $(REGISTRY)/$(IMAGE_NAME):local $(REGISTRY)/$(IMAGE_NAME):testing-$(date)
	podman tag $(REGISTRY)/$(IMAGE_NAME):local $(REGISTRY)/$(IMAGE_NAME):testing

push-stable: build-stable
	podman push $(REGISTRY)/$(IMAGE_NAME):stable-$(date)
	podman push $(REGISTRY)/$(IMAGE_NAME):stable

push-testing: build-testing
	podman push $(REGISTRY)/$(IMAGE_NAME):testing-$(date)
	podman push $(REGISTRY)/$(IMAGE_NAME):testing

push: push-stable push-testing

test-vm: build
	podman run --rm --privileged \
		-v /var/lib/containers:/var/lib/containers \
		-v /dev:/dev \
		--security-opt label=type:unconfined_t \
		$(REGISTRY)/$(IMAGE_NAME):local \
		bootc install to-disk --via-loopback /tmp/fruitadens.raw
	qemu-system-x86_64 \
		-m 2048 \
		-smp 2 \
		-drive file=/tmp/fruitadens.raw,format=raw \
		-netdev user,id=net0 \
		-device virtio-net-pci,netdev=net0 \
		-nographic

validate:
	cpp -P -C -traditional-cpp Containerfile.in > $(containerfile)
	podman build --layers -f $(containerfile) -t $(REGISTRY)/$(IMAGE_NAME):validate .
	podman run --rm $(REGISTRY)/$(IMAGE_NAME):validate bootc container lint

clean:
	rm -f $(containerfile)
	rm -f /tmp/fruitadens.raw

installer-build:
	podman build -t ghcr.io/fruitadens/fruitadens-installer:latest installer/

installer-push: installer-build
	podman push ghcr.io/fruitadens/fruitadens-installer:latest

installer-iso: installer-build
	installer/build-iso.sh
