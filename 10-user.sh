#!/usr/bin/env bash
# Stage 10: second sudo account, for remote support and recovery.
# The target user (maria) is created during the Ubuntu installation itself;
# this stage adds a second administrator and fixes group membership.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "10 users: second sudo account"

if is_done 10 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 10 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo

SECOND_USER="${SECOND_USER:-mikhail}"

section "primary user"
if id maria >/dev/null 2>&1; then
    ok "primary user maria exists"
    for group in sudo docker libvirt kvm; do
        if getent group "$group" >/dev/null 2>&1; then
            run $SUDO usermod -aG "$group" maria
        fi
    done
    ok "maria groups: $(id -nG maria)"
else
    warn "user maria not found: create it during the Ubuntu installation (do not rename it later)"
fi

section "second sudo user: $SECOND_USER"
if is_dry; then
    printf '+ adduser %s && passwd %s && usermod -aG sudo,adm,docker,libvirt,kvm %s\n' \
        "$SECOND_USER" "$SECOND_USER" "$SECOND_USER"
else
    if id "$SECOND_USER" >/dev/null 2>&1; then
        ok "$SECOND_USER already exists"
    else
        $SUDO adduser --gecos "$SECOND_USER" --disabled-password "$SECOND_USER"
        log "set the password for $SECOND_USER:"
        $SUDO passwd "$SECOND_USER"
    fi
    for group in sudo adm docker libvirt kvm; do
        if getent group "$group" >/dev/null 2>&1; then
            $SUDO usermod -aG "$group" "$SECOND_USER"
        fi
    done
    ok "$SECOND_USER groups: $(id -nG "$SECOND_USER")"
fi

mark_done 10
ok "stage 10 finished"
