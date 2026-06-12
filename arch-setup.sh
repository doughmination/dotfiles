#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }

# Directory this script lives in (your dotfiles repo root), so dotfile copies
# work no matter where you invoke it from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Passwordless sudo for wheel  (+ clear /etc/sudoers.d/)
# ---------------------------------------------------------------------------
# Done first so every later sudo call in this script runs unattended.
# Heads-up: NOPASSWD means anything running as your user can become root with
# no prompt. Convenient, but a real reduction in your security posture.
configure_sudo() {
  log "Enabling passwordless sudo for the wheel group"

  local tmp
  tmp="$(mktemp)"
  sudo cat /etc/sudoers > "$tmp"

  # Uncomment the stock NOPASSWD wheel line if it's present...
  sed -i 's/^#\s*%wheel\s\+ALL=(ALL:ALL)\s\+NOPASSWD:\s\+ALL.*/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' "$tmp"
  # ...and if there's still no active rule, append one.
  if ! grep -qE '^\s*%wheel\s+ALL=\(ALL:ALL\)\s+NOPASSWD:\s+ALL' "$tmp"; then
    printf '\n%%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n' >> "$tmp"
  fi

  # Validate BEFORE installing — a malformed sudoers file locks you out of sudo.
  if sudo visudo -cf "$tmp" >/dev/null; then
    sudo install -m 0440 -o root -g root "$tmp" /etc/sudoers
    log "sudoers updated and validated"
  else
    warn "sudoers validation FAILED — original left untouched, aborting"
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"

  # Clear drop-in rules (runs after the main file is in place, so sudo never
  # lapses). NOTE: this also removes any package-provided sudo rules.
  log "Clearing /etc/sudoers.d/"
  sudo find /etc/sudoers.d/ -mindepth 1 -delete
}

# ---------------------------------------------------------------------------
# 2. Dotfiles
# ---------------------------------------------------------------------------
setup_dotfiles() {
  log "Copying dotfiles"
  cp "$SCRIPT_DIR/shells/.bashrc" "$HOME/.bashrc"
}

# ---------------------------------------------------------------------------
# 3. multilib repository  (needed for steam's 32-bit deps)
# ---------------------------------------------------------------------------
enable_multilib() {
  if grep -q '^\[multilib\]' /etc/pacman.conf; then
    log "multilib already enabled — skipping"
    return
  fi
  log "Enabling multilib repository"
  # Uncomment the stock two-line [multilib] block. The DB gets synced by the
  # -Syu in install_packages, so no separate refresh needed here.
  sudo sed -i '/^#\s*\[multilib\]/,/^#\s*Include/ s/^#\s*//' /etc/pacman.conf
}

# ---------------------------------------------------------------------------
# 4. yay (AUR helper)
# ---------------------------------------------------------------------------
install_yay() {
  if command -v yay &>/dev/null; then
    log "yay already installed — skipping"
    return
  fi

  log "Installing build prerequisites"
  sudo pacman -S --needed --noconfirm base-devel git

  log "Building yay-bin from the AUR"
  local build_dir="$HOME/yay-bin"
  if [[ -d "$build_dir/.git" ]]; then
    git -C "$build_dir" pull --ff-only
  else
    rm -rf "$build_dir"
    git clone https://aur.archlinux.org/yay-bin.git "$build_dir"
  fi
  ( cd "$build_dir" && makepkg -si --noconfirm )
}

# ---------------------------------------------------------------------------
# 5. Node via nvm
# ---------------------------------------------------------------------------
setup_node() {
  log "Installing nvm + Node"
  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
  fi

  # nvm.sh references some unset variables, which clashes with `set -u`.
  # Relax that one flag only while sourcing and using nvm.
  set +u
  \. "$NVM_DIR/nvm.sh"
  nvm install 24            # Active LTS
  nvm install 26            # "Current" until it promotes to LTS in Oct 2026
  set -u

  # Under nvm, global npm packages are per Node version. These land on whatever
  # version is active now (26, the last installed). corepack is no longer
  # bundled with Node 25+, so installing it explicitly is required.
  npm install -g corepack @dotenvx/dotenvx
  corepack enable pnpm
  corepack enable yarn
}

# ---------------------------------------------------------------------------
# 6. Packages
# ---------------------------------------------------------------------------
PACMAN_PKGS=(
  amd-ucode ark base base-devel bind bottom chromium dolphin efibootmgr
  exfatprogs firefox git github-cli gptfdisk htop hyfetch inkscape
  intel-media-driver iwd kate kitty lazygit libreoffice-fresh
  libva-intel-driver linux linux-firmware nano network-manager-applet
  networkmanager nmap obs-studio plasma-meta plasma-workspace prismlauncher
  sddm smartmontools steam sudo testdisk vim vlc vulkan-intel vulkan-nouveau
  vulkan-radeon wget wireless_tools wpa_supplicant xdg-utils
  xf86-video-amdgpu xf86-video-ati xf86-video-nouveau xorg-server xorg-xinit
  zenith zram-generator
)

# yay is omitted on purpose — it's built from source in install_yay().
AUR_PKGS=(
  discord-canary docker-desktop equicord-installer-bin spotify vscodium-bin
  zen-browser-bin
)

install_packages() {
  if ((${#PACMAN_PKGS[@]})); then
    # -Syu: refresh DBs (incl. the freshly-enabled multilib), do a full system
    # upgrade, and install. First run may pull a lot, including a new kernel.
    log "Refreshing, upgrading, and installing pacman packages"
    sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"
  fi
  if ((${#AUR_PKGS[@]})); then
    log "Installing AUR packages"
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  if [[ ${EUID} -eq 0 ]]; then
    warn "Run this as your normal user, not root. Aborting."
    exit 1
  fi

  configure_sudo
  setup_dotfiles
  enable_multilib
  install_yay
  setup_node
  install_packages

  log "Done."
}

main "$@"
