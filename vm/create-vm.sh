#!/usr/bin/env bash
# Creates the Windows 11 virtual machine on top of stage 07.
# Run from the repository root:  bash vm/create-vm.sh
#
# Requirements:
#   - stage 07 finished (kvm, qemu, libvirt, virt-manager, ovmf, swtpm)
#   - Windows 11 ISO placed in vm/iso/
#   - ~120 GB free on /var/lib/libvirt/images

source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../versions.env
source "$REPO_DIR/versions.env"

stage_start "vm: create Windows 11"

require_sudo

ISO_DIR="$REPO_DIR/vm/iso"
WIN_ISO="$(find "$ISO_DIR" -maxdepth 1 -type f -iname '*.iso' ! -iname 'autounattend*' 2>/dev/null | head -1 || true)"
VIRTIO_ISO="/var/lib/libvirt/images/virtio-win.iso"
AUTOUNATTEND="$REPO_DIR/vm/autounattend.xml"
DISK="/var/lib/libvirt/images/${VM_NAME,,}.qcow2"

if [[ -z "$WIN_ISO" ]]; then
    die "Windows 11 ISO not found in $ISO_DIR
Download it from https://www.microsoft.com/software-download/windows11
(or set VM_ISO_URL in versions.env) and put it into vm/iso/"
fi
if [[ ! -f "$VIRTIO_ISO" ]]; then
    die "$VIRTIO_ISO is missing, run 07-vm.sh first"
fi
if [[ -f "$DISK" ]] && [[ "${FORCE:-0}" != "1" ]]; then
    die "$DISK already exists, refusing to overwrite (FORCE=1 to recreate)"
fi

if [[ -f "$WIN_ISO" ]]; then
    info "windows iso: $WIN_ISO"
fi
if command -v wiminfo >/dev/null 2>&1; then
    info "editions in the ISO (use the index in autounattend.xml):"
    wiminfo "$WIN_ISO" 2>/dev/null | grep -E "^(Index|Name|Edition)" | head -20 || true
fi

# Optional answer file: build a tiny ISO so Windows Setup picks it up.
AUTOUNATTEND_ARGS=()
if [[ -f "$AUTOUNATTEND" ]] && command -v genisoimage >/dev/null 2>&1; then
    info "building autounattend.iso"
    if ! is_dry; then
        genisoimage -quiet -o "$REPO_DIR/vm/autounattend.iso" -J -R "$AUTOUNATTEND"
    fi
    AUTOUNATTEND_ARGS=(--disk "path=$REPO_DIR/vm/autounattend.iso,device=cdrom,readonly=on")
else
    warn "autounattend.xml will not be used (genisoimage missing or file absent): install Windows manually"
fi

info "creating VM $VM_NAME: ${VM_CPUS} vCPU, ${VM_RAM_MB} MB RAM, ${VM_DISK_GB} GB disk"

virt-install \
    --name "$VM_NAME" \
    --osinfo win11 \
    --machine q35 \
    --cpu host-passthrough \
    --vcpus "$VM_CPUS" \
    --memory "$VM_RAM_MB" \
    --boot uefi,loader_secure=yes \
    --features smm=on \
    --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
    --disk "path=$DISK,size=$VM_DISK_GB,format=qcow2,bus=virtio,cache=writeback" \
    --cdrom "$WIN_ISO" \
    --disk "path=$VIRTIO_ISO,device=cdrom,readonly=on" \
    "${AUTOUNATTEND_ARGS[@]}" \
    --network network=default,model=virtio \
    --graphics spice,listen=127.0.0.1 \
    --video qxl \
    --sound none \
    --noautoconsole

ok "VM created. Open it with:  virt-manager"
log "After Windows is installed, run vm/post-install.ps1 inside the VM (see vm/README.md)"
