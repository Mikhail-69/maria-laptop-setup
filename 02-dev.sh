#!/usr/bin/env bash
# Stage 02: git/gh, Go, uv, bun, Java, Docker, PyCharm.
# Safe to re-run.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
# shellcheck source=versions.env
source "$REPO_DIR/versions.env"

stage_start "02 dev: git, gh, go, uv, bun, java, docker, pycharm"

if is_done 02 && [[ "${FORCE:-0}" != "1" ]]; then
    ok "stage 02 already done (FORCE=1 to rerun)"
    exit 0
fi

require_sudo
apt_refresh

section "git and gh"
install_apt git
if ! is_dry; then
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
        "$(dpkg --print-architecture)" \
        | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    $SUDO apt-get update -qq
fi
install_apt gh

section "java"
install_apt default-jdk

section "docker"
if ! is_dry; then
    $SUDO install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    $SUDO chmod go+r /etc/apt/keyrings/docker.gpg
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
        "$(dpkg --print-architecture)" "$UBUNTU_CODENAME" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
    $SUDO apt-get update -qq
fi
install_apt docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! is_dry; then
    $SUDO systemctl enable --now docker >/dev/null 2>&1 || warn "docker service did not start"
    if id maria >/dev/null 2>&1; then
        $SUDO usermod -aG docker maria
        ok "maria added to the docker group (re-login required)"
    else
        warn "user maria does not exist yet, run 10-user.sh first for group membership"
    fi
fi

section "go $GO_VERSION"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
download "https://go.dev/dl/${GO_TARBALL}" "$DOWNLOAD_DIR/$GO_TARBALL"
if is_dry; then
    printf '+ rm -rf /usr/local/go && tar -C /usr/local -xzf %s\n' "$DOWNLOAD_DIR/$GO_TARBALL"
else
    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf "$DOWNLOAD_DIR/$GO_TARBALL"
    printf '%s\n' 'export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin"' \
        | $SUDO tee /etc/profile.d/go.sh >/dev/null
    mkdir -p "$HOME/go/bin"
fi

section "uv"
if command -v uv >/dev/null 2>&1 && ! is_dry; then
    ok "uv already installed ($(uv --version))"
else
    info "installing uv to ~/.local/bin"
    run_sh 'curl -fsSL https://astral.sh/uv/install.sh | sh'
fi

section "bun"
if command -v bun >/dev/null 2>&1 && ! is_dry; then
    ok "bun already installed ($(bun --version))"
else
    info "installing bun to ~/.bun"
    run_sh 'curl -fsSL https://bun.sh/install | bash'
fi

section "pycharm"
install_snap pycharm-community --classic

mark_done 02
ok "stage 02 finished"
