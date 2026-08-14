#!/usr/bin/env bash
# arch-setup.sh

set -euo pipefail

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }

# Repo root, so copies work from any cwd
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FONT_ZIPS=(
  "ComicCode|https://m.doughmination.gay/zip?path=f%2FComic-Code%2Fotf"
)

PACMAN_PKGS=(
  # base system / firmware / boot
  amd-ucode
  base
  base-devel
  efibootmgr
  linux
  linux-firmware
  mkinitcpio
  sbctl
  sudo
  zram-generator

  # hardware / graphics
  intel-media-driver
  lib32-vulkan-radeon
  libva-intel-driver
  mesa
  vulkan-intel
  vulkan-nouveau
  vulkan-radeon
  xf86-video-amdgpu
  xf86-video-ati
  xf86-video-nouveau
  xorg-server
  xorg-xinit

  # networking
  bind
  bluez-utils
  iwd
  network-manager-applet
  networkmanager
  nmap
  openssh
  wireless_tools
  wpa_supplicant

  # sway session — swayfx itself is in AUR_PKGS
  autotiling
  awww
  brightnessctl
  cliphist
  grim
  hypridle
  hyprlock
  playerctl
  polkit-kde-agent
  rofi
  slurp
  swaybg
  swayidle
  swaylock
  swaync
  waybar
  wl-clipboard
  wmenu
  xdg-desktop-portal-gtk
  xdg-desktop-portal-wlr
  xdg-utils

  # audio
  pavucontrol
  pipewire
  pipewire-alsa
  pipewire-pulse
  wireplumber

  # media codecs
  gst-plugins-bad
  gst-plugins-good
  gst-plugins-ugly

  # theming / fonts / toolkit config
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji
  papirus-icon-theme
  qt5ct
  qt6ct
  qt6-wayland
  ttf-jetbrains-mono-nerd
  xsettingsd

  # terminal, shell tooling, TUI apps
  bash-completion
  bottom
  btop
  cava
  fastfetch
  foot
  htop
  hyfetch
  jq
  kitty
  lazygit
  python
  python-pip
  ripgrep
  sassc
  yazi
  zenith
  zsh
  zsh-completions

  # editors / files / archives
  7zip
  ark
  dolphin
  exfatprogs
  gptfdisk
  kate
  nano
  poppler
  smartmontools
  testdisk
  unzip
  vim
  wget
  zip

  # desktop apps
  chromium
  firefox
  git
  github-cli
  ibus
  inkscape
  librewolf
  libreoffice-fresh
  obs-studio
  prismlauncher
  steam
  vlc

  # plasma / display manager, kept alongside sway
  plasma-desktop
  plasma-login-manager
  plasma-meta
  sddm
)

# yay is missing on purpose — installYay builds it from source
AUR_PKGS=(
  archy-screenshot
  discord-canary
  docker-desktop
  equicord-installer-bin
  eww
  oh-my-posh-bin
  spotify
  swayfx
  vscodium-bin
  waypaper
  zen-browser-bin
)

# First, so every later sudo call runs unattended.
# Trade-off: anything running as you can become root with no prompt.
configureSudo() {
  log "Enabling passwordless sudo for the wheel group"

  local tmpSudoers
  tmpSudoers="$(mktemp)"
  sudo cat /etc/sudoers > "$tmpSudoers"

  sed -i 's/^#\s*%wheel\s\+ALL=(ALL:ALL)\s\+NOPASSWD:\s\+ALL.*/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' "$tmpSudoers"

  if ! grep -qE '^\s*%wheel\s+ALL=\(ALL:ALL\)\s+NOPASSWD:\s+ALL' "$tmpSudoers"; then
    printf '\n%%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n' >> "$tmpSudoers"
  fi

  # Validate before installing — a malformed sudoers locks you out
  if ! sudo visudo -cf "$tmpSudoers" >/dev/null; then
    warn "sudoers validation FAILED — original left untouched, aborting"
    rm -f "$tmpSudoers"
    return 1
  fi

  sudo install -m 0440 -o root -g root "$tmpSudoers" /etc/sudoers
  rm -f "$tmpSudoers"
  log "sudoers updated and validated"

  # Drops package-provided rules too
  log "Clearing /etc/sudoers.d/"
  sudo find /etc/sudoers.d/ -mindepth 1 -delete
}

# Before setupDotfiles, so sway/config has its background on first start
setupWallpaper() {
  log "Installing wallpapers to ~/Pictures"

  local destinationDir="$HOME/Pictures"
  mkdir -p "$destinationDir"

  local entry name destination backupDestination
  for entry in "$SCRIPT_DIR"/wallpapers/*; do
    [[ -f "$entry" ]] || continue

    name="$(basename "$entry")"
    destination="$destinationDir/$name"

    if [[ -e "$destination" ]]; then
      if cmp -s "$entry" "$destination"; then
        log "$name already up to date — skipping"
        continue
      fi

      backupDestination="$destination.bak-$(date +%Y%m%d-%H%M%S)"
      warn "backing up existing $destination -> $backupDestination"
      mv "$destination" "$backupDestination"
    fi

    cp "$entry" "$destination"
  done
}

setupDotfiles() {
  log "Copying dotfiles"

  local backupDir="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

  # Move an existing path aside instead of clobbering it
  backup() {
    local target="$1"
    [[ -e "$target" || -L "$target" ]] || return 0

    mkdir -p "$backupDir"
    local relativePath="${target#"$HOME"/}"
    mkdir -p "$backupDir/$(dirname "$relativePath")"
    mv "$target" "$backupDir/$relativePath"
    warn "backed up $target -> $backupDir/$relativePath"
  }

  local file
  for file in .bashrc .zshrc; do
    backup "$HOME/$file"
    cp "$SCRIPT_DIR/shells/$file" "$HOME/$file"
  done

  # home/* maps 1:1 into ~/. dotglob because every file there starts with a dot
  log "Installing ~ dotfiles from home/"
  local entry name
  shopt -s dotglob
  for entry in "$SCRIPT_DIR"/home/*; do
    [[ -f "$entry" ]] || continue

    name="$(basename "$entry")"
    backup "$HOME/$name"
    cp "$entry" "$HOME/$name"
  done
  shopt -u dotglob

  # sway-config-files/* maps 1:1 into ~/.config/
  log "Installing ~/.config from sway-config-files/"
  mkdir -p "$HOME/.config"

  for entry in "$SCRIPT_DIR"/sway-config-files/*; do
    [[ -e "$entry" ]] || continue

    name="$(basename "$entry")"
    backup "$HOME/.config/$name"
    cp -r "$entry" "$HOME/.config/$name"
  done

  # GTK bookmarks take absolute paths only, so retarget them at this user
  local bookmarksFile="$HOME/.config/gtk-3.0/bookmarks"
  if [[ -f "$bookmarksFile" ]]; then
    sed -i "s|file:///home/[^/]*/|file://$HOME/|" "$bookmarksFile"
  fi

  # Repo keeps it as .jsonc; VSCodium reads settings.json
  log "Installing VSCodium settings"
  mkdir -p "$HOME/.config/VSCodium/User"
  backup "$HOME/.config/VSCodium/User/settings.json"
  cp "$SCRIPT_DIR/vscode/settings.jsonc" "$HOME/.config/VSCodium/User/settings.json"

  # sway keybinds call these by path, e.g. $ss = ~/.local/bin/screenshot
  log "Installing ~/.local/bin from local-binaries/"
  mkdir -p "$HOME/.local/bin"

  for entry in "$SCRIPT_DIR"/local-binaries/*; do
    [[ -f "$entry" ]] || continue

    name="$(basename "$entry")"
    backup "$HOME/.local/bin/$name"
    install -Dm755 "$entry" "$HOME/.local/bin/$name"
  done

  chmod +x "$HOME/.config/waybar/scripts/"* 2>/dev/null || true

  unset -f backup
}

# Takes effect on next login, or `sudo systemctl restart sddm` — which kills
# the current session, so it is left to you
setupSddmTheme() {
  local themeName="pixel-night-city"
  local destination="/usr/share/sddm/themes/$themeName"

  log "Installing SDDM theme ($themeName)"

  if [[ -e "$destination" ]]; then
    local backupDestination="/usr/share/sddm/themes/${themeName}.bak-$(date +%Y%m%d-%H%M%S)"
    warn "backing up existing $destination -> $backupDestination"
    sudo mv "$destination" "$backupDestination"
  fi

  sudo cp -r "$SCRIPT_DIR/sddm-theme" "$destination"
  sudo chown -R root:root "$destination"

  log "Pointing sddm at $themeName"
  sudo mkdir -p /etc/sddm.conf.d
  printf '[Theme]\nCurrent=%s\n' "$themeName" | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
}

# waybar/hyprlock/sddm format their own clocks, so they read 12-hour regardless
# of this. This is what makes `date`, GTK and Qt apps agree with them — LC_TIME
# points at a forked en_GB that is 12-hour but still DD/MM and £.
# See system/locale/README.md. Takes effect on next login.
setupLocale() {
  local localeName="en_GB@12h"
  local sourceDir="$SCRIPT_DIR/system/locale"

  log "Installing $localeName locale"
  sudo install -Dm644 "$sourceDir/$localeName" "/usr/share/i18n/locales/$localeName"

  # locale.gen takes "<name> <charmap>". Note locale-gen then emits it as
  # en_GB.UTF-8@12h, which is the name /etc/locale.conf has to use.
  # Stock locale.gen lines carry trailing whitespace, so compare trimmed rather
  # than with grep -qxF, which would miss them and append a duplicate.
  local entry
  for entry in 'en_GB.UTF-8 UTF-8' "$localeName UTF-8"; do
    if awk -v want="$entry" '
         { line = $0; gsub(/^[ \t]+|[ \t]+$/, "", line); if (line == want) found = 1 }
         END { exit !found }
       ' /etc/locale.gen; then
      log "'$entry' already in /etc/locale.gen — skipping"
    else
      printf '%s\n' "$entry" | sudo tee -a /etc/locale.gen > /dev/null
    fi
  done

  log "Generating locales"
  sudo locale-gen

  if [[ -e /etc/locale.conf ]] && ! cmp -s "$sourceDir/locale.conf" /etc/locale.conf; then
    local backupDestination="/etc/locale.conf.bak-$(date +%Y%m%d-%H%M%S)"
    warn "backing up existing /etc/locale.conf -> $backupDestination"
    sudo cp /etc/locale.conf "$backupDestination"
  fi

  sudo install -Dm644 "$sourceDir/locale.conf" /etc/locale.conf

  # Same formats again, for KDE apps launched from the sway session
  cp "$sourceDir/plasma-localerc" "$HOME/.config/plasma-localerc"
}

# Needed for steam's 32-bit deps
enableMultilib() {
  if grep -q '^\[multilib\]' /etc/pacman.conf; then
    log "multilib already enabled — skipping"
    return
  fi

  log "Enabling multilib repository"

  # DBs get synced by the -Syu in installPackages
  sudo sed -i '/^#\s*\[multilib\]/,/^#\s*Include/ s/^#\s*//' /etc/pacman.conf
}

installYay() {
  if command -v yay &>/dev/null; then
    log "yay already installed — skipping"
    return
  fi

  log "Installing build prerequisites"
  sudo pacman -S --needed --noconfirm base-devel git

  log "Building yay-bin from the AUR"

  local buildDir="$HOME/yay-bin"
  if [[ -d "$buildDir/.git" ]]; then
    git -C "$buildDir" pull --ff-only
  else
    rm -rf "$buildDir"
    git clone https://aur.archlinux.org/yay-bin.git "$buildDir"
  fi

  ( cd "$buildDir" && makepkg -si --noconfirm )
}

setupNode() {
  log "Installing nvm + Node"

  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh | bash
  fi

  # nvm.sh reads unset variables, which trips `set -u`
  set +u
  \. "$NVM_DIR/nvm.sh"

  # Active LTS
  nvm install 24

  # "Current" until it promotes to LTS in Oct 2026
  nvm install 26
  set -u

  # Globals are per Node version, so these land on 26. corepack is no longer
  # bundled with Node 25+.
  npm install -g corepack @dotenvx/dotenvx
  corepack enable pnpm
  corepack enable yarn
}

# Installs to ~/.bun; both shell rc files already put ~/.bun/bin on PATH
setupBun() {
  if [[ -x "$HOME/.bun/bin/bun" ]]; then
    log "bun already installed — upgrading"
    "$HOME/.bun/bin/bun" upgrade
    return
  fi

  log "Installing bun"
  curl -fsSL https://bun.com/install | bash
}

# Arch's Python is externally managed (PEP 668), so pip outside a venv is
# refused. Activate with: source ~/.venv/bin/activate
setupPython() {
  local venvDir="$HOME/.venv"

  if [[ -d "$venvDir" ]]; then
    log "venv already exists at $venvDir — skipping"
  else
    log "Creating Python venv at $venvDir"
    python -m venv "$venvDir"
  fi

  "$venvDir/bin/python" -m pip install --upgrade pip setuptools wheel
}

# FONT_ZIPS entries are "destDirName|url". The URLs serve a zip via
# Content-Disposition despite not ending in .zip. Fonts are flattened into
# ~/.local/share/fonts/<destDirName>/ however deep the zip nests them.
setupFonts() {
  ((${#FONT_ZIPS[@]})) || return 0

  log "Installing fonts"

  local fontsDir="$HOME/.local/share/fonts"
  mkdir -p "$fontsDir"

  local entry name url destination workDir zipFile
  for entry in "${FONT_ZIPS[@]}"; do
    name="${entry%%|*}"
    url="${entry#*|}"
    destination="$fontsDir/$name"

    if [[ -d "$destination" && -n "$(ls -A "$destination" 2>/dev/null)" ]]; then
      log "Font '$name' already installed — skipping"
      continue
    fi

    log "Downloading font: $name"
    workDir="$(mktemp -d)"
    zipFile="$workDir/$name.zip"

    if ! curl -fsSL "$url" -o "$zipFile"; then
      warn "failed to download '$name' from $url — skipping"
      rm -rf "$workDir"
      continue
    fi

    mkdir -p "$destination"
    unzip -qo "$zipFile" -d "$workDir/extracted"
    find "$workDir/extracted" -type f \( -iname '*.otf' -o -iname '*.ttf' \) -exec cp {} "$destination/" \;
    rm -rf "$workDir"
  done

  log "Refreshing font cache"
  fc-cache -f "$fontsDir" > /dev/null
}

installPackages() {
  if ((${#PACMAN_PKGS[@]})); then
    log "Refreshing, upgrading, and installing pacman packages"
    sudo pacman -Syu --needed --noconfirm "${PACMAN_PKGS[@]}"
  fi

  if ((${#AUR_PKGS[@]})); then
    log "Installing AUR packages"
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
  fi
}

main() {
  if [[ ${EUID} -eq 0 ]]; then
    warn "Run this as your normal user, not root. Aborting."
    exit 1
  fi

  configureSudo
  setupWallpaper
  setupDotfiles
  setupSddmTheme
  setupLocale
  enableMultilib
  installYay
  setupNode
  installPackages
  setupBun
  setupPython
  setupFonts

  log "Done."
}

main "$@"
