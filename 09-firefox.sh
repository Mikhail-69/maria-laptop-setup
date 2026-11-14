#!/usr/bin/env bash
# Stage 09: Firefox add-ons from the current profile, plus Russian UI.
# Add-ons are downloaded from addons.mozilla.org, so they stay signed and
# updatable. Nothing is signed in to a Firefox account.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

stage_start "09 firefox: add-ons and preferences"

if is_done 09 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 09 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo

section "firefox"
if command -v firefox >/dev/null 2>&1; then
    ok "firefox already installed"
else
    install_snap firefox
fi

section "profile"
PROFILE_ROOT=""
for candidate in "$HOME/snap/firefox/common/.mozilla/firefox" "$HOME/.mozilla/firefox"; do
    [[ -d "$candidate" ]] && PROFILE_ROOT="$candidate" && break
done

if is_dry; then
    printf '+ resolve firefox profile\n'
else
    if [[ -z "$PROFILE_ROOT" ]]; then
        info "initialising the Firefox profile"
        timeout 30 firefox --headless --screenshot "$DOWNLOAD_DIR/firefox-init.png" about:blank >/dev/null 2>&1 || true
        for candidate in "$HOME/snap/firefox/common/.mozilla/firefox" "$HOME/.mozilla/firefox"; do
            [[ -d "$candidate" ]] && PROFILE_ROOT="$candidate" && break
        done
    fi
    [[ -n "$PROFILE_ROOT" ]] || die "firefox profile directory not found"
    ok "profile root: $PROFILE_ROOT"
fi

if ! is_dry; then
    if pgrep -x firefox >/dev/null 2>&1; then
        die "close Firefox before running this stage (add-ons cannot be installed into a running profile)"
    fi
    PROFILE="$(find "$PROFILE_ROOT" -maxdepth 1 -mindepth 1 -type d -name '*.default*' | head -1)"
    [[ -n "$PROFILE" ]] || die "no *.default* profile inside $PROFILE_ROOT"
    info "profile: $PROFILE"

    mkdir -p "$PROFILE/extensions"

    section "add-ons"
    installed=0
    failed=()
    while IFS= read -r id; do
        [[ -z "$id" || "$id" == \#* ]] && continue
        enc="${id//\{/%7B}"
        enc="${enc//\}/%7D}"
        ext_url="$(curl -fsSL "https://addons.mozilla.org/api/v5/addons/addon/${enc}/" \
            | jq -r '.current_version.file.url // empty' 2>/dev/null || true)"
        if [[ -z "$ext_url" ]]; then
            failed+=("$id")
            continue
        fi
        if curl -fsSL -o "$PROFILE/extensions/${id}.xpi" "$ext_url"; then
            installed=$((installed + 1))
        else
            failed+=("$id")
        fi
    done < <(grep -vE '^\s*(#|$)' "$REPO_DIR/assets/firefox-addons.txt")

    ok "add-ons downloaded: $installed"
    if ((${#failed[@]})); then
        warn "could not fetch: ${failed[*]}"
    fi

    section "preferences"
    cat > "$PROFILE/user.js" <<'EOF'
// Installed by maria-laptop-setup
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
user_pref("extensions.startupScanScopes", 15);
user_pref("intl.locale.requested", "ru");
user_pref("browser.startup.homepage", "https://www.youtube.com/feed/subscriptions");
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
EOF
    ok "user.js written"
fi

section "russian interface"
if ! is_dry; then
    log "Firefox UI language is set to ru via user.js. If the interface stays English,"
    log "open Settings -> General -> Language and add Russian (the snap ships locales)."
fi

mark_done 09
ok "stage 09 finished"
