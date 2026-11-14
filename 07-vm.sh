#!/usr/bin/env bash
# Stage 07: KVM/QEMU/libvirt host for the Windows 11 machine.
# Creating the VM itself is a separate script: vm/create-vm.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=versions.env
source "$REPO_DIR/versions.env"

stage_start "07 vm: kvm, qemu, libvirt, virt-manager"

if is_done 07 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 07 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo
apt_refresh

section "virtualization packages"
install_apt \
    qemu-system-x86 qemu-utils \
    libvirt-daemon-system libvirt-clients \
    bridge-utils virtinst \
    virt-manager \
    ovmf swtpm swtpm-tools \
    virtiofsd guestfs-tools libosinfo-bin \
    genisoimage wimtools \
    cpu-checker

section "hardware virtualization check"
if ! is_dry; then
    if command -v kvm-ok >/dev/null 2>&1; then
        if kvm-ok | grep -q "KVM acceleration can be used"; then
            ok "KVM acceleration available"
        else
            warn "KVM acceleration is not available: enable VT-x/AMD-V in the laptop firmware"
        fi
    fi
fi

section "groups and services"
if ! is_dry; then
    $SUDO systemctl enable --now libvirtd >/dev/null 2>&1 || warn "libvirtd did not start"
    for user in maria mikhail; do
        if id "$user" >/dev/null 2>&1; then
            $SUDO usermod -aG libvirt,kvm "$user"
            ok "$user added to libvirt,kvm"
        fi
    done
    $SUDO virsh net-start default >/dev/null 2>&1 || true
    $SUDO virsh net-autostart default >/dev/null 2>&1 || true
fi

section "virtio drivers iso"
download "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso" \
    "$DOWNLOAD_DIR/virtio-win.iso"
if ! is_dry; then
    $SUDO mkdir -p /var/lib/libvirt/images
    $SUDO cp -n "$DOWNLOAD_DIR/virtio-win.iso" /var/lib/libvirt/images/virtio-win.iso
    ok "virtio-win.iso copied to /var/lib/libvirt/images/"
fi

section "next step"
log "Put the Windows 11 ISO into vm/iso/ (or set VM_ISO_URL in versions.env),"
log "then run:  bash vm/create-vm.sh"

mark_done 07
ok "stage 07 finished"
