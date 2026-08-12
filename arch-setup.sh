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

  # Timestamped backup dir, created lazily by backup() on first collision.
  local backup_dir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

  # Move an existing path out of the way instead of clobbering it.
  backup() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0
    mkdir -p "$backup_dir"
    local rel="${target#"$HOME"/}"
    mkdir -p "$backup_dir/$(dirname "$rel")"
    mv "$target" "$backup_dir/$rel"
    warn "backed up $target -> $backup_dir/$rel"
  }

  # Shell configs
  for f in .bashrc .zshrc; do
    backup "$HOME/$f"
    cp "$SCRIPT_DIR/shells/$f" "$HOME/$f"
  done

  # Everything under sway-config-files/ maps 1:1 into ~/.config/
  log "Installing ~/.config from sway-config-files/"
  mkdir -p "$HOME/.config"
  local entry name
  for entry in "$SCRIPT_DIR"/sway-config-files/*; do
    [[ -e "$entry" ]] || continue          # empty glob guard
    name="$(basename "$entry")"
    backup "$HOME/.config/$name"
    cp -r "$entry" "$HOME/.config/$name"
  done

  # VSCodium settings (repo keeps it as .jsonc; VSCodium reads settings.json)
  log "Installing VSCodium settings"
  mkdir -p "$HOME/.config/VSCodium/User"
  backup "$HOME/.config/VSCodium/User/settings.json"
  cp "$SCRIPT_DIR/vscode/settings.jsonc" "$HOME/.config/VSCodium/User/settings.json"

  # Local binaries: local-binaries/* -> ~/.local/bin/ (sway keybinds call these by
  # path, e.g. $ss = ~/.local/bin/screenshot).
  log "Installing ~/.local/bin from local-binaries/"
  mkdir -p "$HOME/.local/bin"
  for entry in "$SCRIPT_DIR"/local-binaries/*; do
    [[ -f "$entry" ]] || continue
    name="$(basename "$entry")"
    backup "$HOME/.local/bin/$name"
    install -Dm755 "$entry" "$HOME/.local/bin/$name"
  done

  # waybar's memory script and anything else shipped executable needs +x
  chmod +x "$HOME/.config/waybar/scripts/"* 2>/dev/null || true

  unset -f backup
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
# 5b. Bun
# ---------------------------------------------------------------------------
# Installs to ~/.bun; both shell rc files already put ~/.bun/bin on PATH.
setup_bun() {
  if [[ -x "$HOME/.bun/bin/bun" ]]; then
    log "bun already installed — upgrading"
    "$HOME/.bun/bin/bun" upgrade
    return
  fi
  log "Installing bun"
  curl -fsSL https://bun.com/install | bash
}

# ---------------------------------------------------------------------------
# 5c. Python virtualenv
# ---------------------------------------------------------------------------
# Arch's Python is externally managed (PEP 668), so `pip install` outside a venv
# is refused. This is the general-purpose env to activate for that:
#   source ~/.venv/bin/activate
setup_python() {
  local venv="$HOME/.venv"
  if [[ -d "$venv" ]]; then
    log "venv already exists at $venv — skipping"
  else
    log "Creating Python venv at $venv"
    python -m venv "$venv"
  fi
  "$venv/bin/python" -m pip install --upgrade pip setuptools wheel
}

# ---------------------------------------------------------------------------
# 6. Packages
# ---------------------------------------------------------------------------
PACMAN_PKGS=(
  # base system / firmware / boot
  amd-ucode base base-devel efibootmgr linux linux-firmware mkinitcpio sbctl
  sudo zram-generator

  # hardware / graphics
  intel-media-driver libva-intel-driver mesa vulkan-intel vulkan-nouveau
  vulkan-radeon xf86-video-amdgpu xf86-video-ati xf86-video-nouveau
  xorg-server xorg-xinit

  # networking
  bind bluez-utils iwd network-manager-applet networkmanager nmap openssh
  wireless_tools wpa_supplicant

  # sway session (see sway-config-files/) — swayfx itself is in AUR_PKGS
  autotiling awww brightnessctl cliphist grim hypridle hyprlock playerctl
  polkit-kde-agent rofi slurp swaybg swayidle swaylock swaync waybar
  wl-clipboard wmenu xdg-desktop-portal-gtk xdg-desktop-portal-wlr xdg-utils

  # audio
  pavucontrol pipewire pipewire-alsa pipewire-pulse wireplumber

  # theming / fonts / toolkit config
  noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme qt5ct qt6ct
  qt6-wayland ttf-jetbrains-mono-nerd xsettingsd

  # terminal, shell tooling, TUI apps
  btop cava fastfetch foot htop hyfetch jq kitty lazygit python python-pip
  ripgrep sassc zsh zsh-completions bash-completion
  yazi zenith bottom

  # editors / files / archives
  7zip ark dolphin exfatprogs gptfdisk nano poppler smartmontools
  testdisk unzip vim wget zip

  # desktop apps
  chromium firefox git github-cli ibus inkscape librewolf libreoffice-fresh
  obs-studio prismlauncher steam vlc

  # plasma / display manager (second session, kept alongside sway)
  plasma-desktop plasma-login-manager plasma-meta sddm
)

# yay is omitted on purpose — it's built from source in install_yay().
AUR_PKGS=(
  archy-screenshot discord-canary docker-desktop equicord-installer-bin eww
  oh-my-posh-bin spotify swayfx vscodium-bin waypaper zen-browser-bin
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
  setup_bun
  setup_python

  log "Done."
}

main "$@"
