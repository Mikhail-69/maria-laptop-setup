#!/usr/bin/env bash
# Create a new Windows 11 VM and open the interactive installer.
set -euo pipefail

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
trap 'printf "Stopped at line %s. Existing VM data was not deleted.\n" "$LINENO" >&2' ERR

name=Windows11
ram=8192
cpus=4
disk_gb=120
uri=qemu:///system
vm_dir=/var/lib/libvirt/images/windows11

[[ $(id -u) != 0 ]] || fail 'Run as your normal desktop user, without sudo.'
[[ $(uname -m) == x86_64 ]] || fail 'This script requires an x86_64 host.'
for tool in sudo virsh virt-install virt-manager qemu-img curl python3 7z; do
    command -v "$tool" >/dev/null || fail "Required command missing: $tool (complete stage 07 first)."
done
[[ -c /dev/kvm ]] || fail '/dev/kvm is missing.'
total_mb=$(awk '/MemTotal:/ {print int($2/1024)}' /proc/meminfo)
(( total_mb >= 11000 )) || fail 'At least 11 GiB host RAM is required for these settings.'
(( $(nproc) >= cpus )) || fail 'Fewer than four CPU threads are available.'
sudo -v
sudo virsh -c "$uri" list --all >/dev/null
if sudo virsh -c "$uri" dominfo "$name" >/dev/null 2>&1; then
    fail "VM $name already exists. Open virt-manager; this script will not recreate it."
fi
if sudo test -e "$vm_dir"; then
    fail "$vm_dir already exists; preserving its contents."
fi
sudo test -d /var/lib/libvirt/images || fail 'Complete stage 07 first.'
free_kb=$(df -Pk /var/lib/libvirt/images | awk 'END {print $4}')
(( free_kb > (disk_gb + 20) * 1024 * 1024 )) || fail 'At least 140 GiB free disk space is required.'

work=$(mktemp -d "$HOME/windows11-setup-XXXXXXXX")
printf 'Working directory: %s\n' "$work"
printf 'Paste an absolute ISO file path or a direct HTTPS ISO download URL from Microsoft: '
IFS= read -r input </dev/tty
if [[ "$input" == https://* ]]; then
    python3 - "$input" <<'PY'
import sys
from urllib.parse import urlsplit
host = (urlsplit(sys.argv[1]).hostname or '').lower()
if not any(host == domain or host.endswith('.' + domain)
           for domain in ('microsoft.com', 'windowsupdate.com')):
    sys.exit('Use a direct download URL from the official Microsoft download page.')
PY
    curl -fL --proto '=https' --proto-redir '=https' --retry 2 \
        --connect-timeout 20 --max-time 10800 \
        -o "$work/Windows11.iso.part" "$input"
    mv "$work/Windows11.iso.part" "$work/Windows11.iso"
    iso="$work/Windows11.iso"
else
    iso=$(realpath -e -- "$input")
fi
[[ -f "$iso" && -r "$iso" ]] || fail 'ISO file is missing or unreadable.'
(( $(stat -c %s "$iso") > 2000000000 )) || fail 'File is too small for this Windows installer.'
7z l "$iso" > "$work/iso-contents.txt"
python3 - "$work/iso-contents.txt" <<'PY'
import pathlib, sys
listing = pathlib.Path(sys.argv[1]).read_text(errors='replace').lower().replace('\\', '/')
if 'efi/boot/bootx64.efi' not in listing:
    sys.exit('An x64 UEFI boot loader was not found in the ISO.')
if not any(name in listing for name in ('sources/install.wim', 'sources/install.esd')):
    sys.exit('Windows installation image was not found in the ISO.')
print('Windows x64 installation media structure: OK')
PY
printf '\nISO SHA256:\n'
sha256sum "$iso"
printf 'Paste the expected SHA256 from Microsoft, or press Enter to skip checksum comparison: '
IFS= read -r expected </dev/tty
if [[ -n "$expected" ]]; then
    [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || fail 'Invalid SHA256.'
    actual=$(sha256sum "$iso" | awk '{print $1}')
    [[ "${actual,,}" == "${expected,,}" ]] || fail 'ISO checksum mismatch.'
else
    printf 'Publisher checksum comparison skipped; structural checks only.\n'
fi

sudo virsh -c "$uri" net-info default >/dev/null
if ! sudo virsh -c "$uri" net-list --name | grep -qx default; then
    sudo virsh -c "$uri" net-start default
fi
sudo virsh -c "$uri" net-autostart default

# An exclusive directory reserves the disk path. Never reuse existing media.
sudo mkdir -m 0755 "$vm_dir"
sudo cp --reflink=auto -- "$iso" "$vm_dir/Windows11.iso"
sudo chmod 0644 "$vm_dir/Windows11.iso"
args=(
    --connect "$uri" --name "$name" --virt-type kvm
    --osinfo win11 --machine q35 --cpu host-passthrough
    --vcpus "${cpus},sockets=1,cores=${cpus},threads=1" --memory "$ram"
    --boot uefi,firmware.secure-boot=yes,firmware.enrolled-keys=yes
    --features smm=on
    --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb
    --disk "path=$vm_dir/system.qcow2,size=$disk_gb,format=qcow2,bus=sata"
    --cdrom "$vm_dir/Windows11.iso"
    --network network=default,model=e1000e
    --graphics spice,listen=127.0.0.1 --video vga
    --noautoconsole
)
if sudo test -f /var/lib/libvirt/images/virtio-win.iso; then
    args+=(--disk path=/var/lib/libvirt/images/virtio-win.iso,device=cdrom,bus=sata,readonly=on)
fi

# Validate firmware selection before allocating the virtual disk.
sudo virt-install "${args[@]}" --print-xml > "$work/domain-preview.xml"
sudo virt-install "${args[@]}" --wait 0
sudo virsh -c "$uri" dominfo "$name"

printf '\nVM created; Windows installation has NOT finished yet.\n'
printf 'In its console press a key to boot from CD, then follow Windows Setup.\n'
printf 'Install only onto the new 120 GiB virtual disk.\n'
virt-manager --connect "$uri" --show-domain-console "$name" >/dev/null 2>&1 &
