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

# Single font files, dropped straight into ~/.local/share/fonts
FONT_FILES=(
  "https://m.doughmination.gay/f/PixelifySans/PixelifySans-Bold.ttf"
)

# Defaults; promptIdentity offers these at startup. Env vars override.
GIT_USER_NAME="${GIT_USER_NAME:-Clove Twilight}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-admin@doughmination.win}"

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
  xorg-xwayland

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

  # audio — pipewire alone ships no SPA backends, so no sinks at all
  alsa-utils
  pavucontrol
  pipewire
  pipewire-alsa
  pipewire-audio
  pipewire-pulse
  wireplumber

  # media codecs
  gst-plugins-bad
  gst-plugins-base
  gst-plugins-good
  gst-plugins-ugly

  # credentials — GCM's secretservice store needs a keyring daemon
  gnome-keyring

  # theming / fonts / toolkit config
  adw-gtk-theme
  dart-sass
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji
  papirus-icon-theme
  qt5ct
  qt6ct
  qt6-wayland

  # the families the configs name — without these everything falls back
  ttf-cascadia-code-nerd
  ttf-daddytime-mono-nerd
  ttf-jetbrains-mono-nerd

  # terminal, shell tooling, TUI apps
  bash-completion
  bottom
  btop
  cava
  fastfetch
  foot
  htop
  hyfetch
  kitty
  lazygit
  python
  yazi
  zenith

  # editors / files / archives
  7zip
  exfatprogs
  gptfdisk
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
  ibus
  inkscape
  librewolf
  libreoffice-fresh
  obs-studio
  prismlauncher
  steam
  vlc

  # display manager — the qt deps back the theme's BackgroundVideo.qml
  qt5-graphicaleffects
  qt5-quickcontrols2
  qt6-5compat
  qt6-multimedia
  qt6-multimedia-ffmpeg
  sddm
)

# yay and oh-my-posh are absent on purpose — installYay and setupOhMyPosh
AUR_PKGS=(
  archy-screenshot
  discord-canary
  docker-desktop
  equicord-installer-bin
  eww
  git-credential-manager
  git-credential-manager-extras
  swayfx
  vscodium-bin
  wlogout
  zen-browser-bin
)

# Only these need enabling; everything else is preset-enabled by its package.
SYSTEM_UNITS=(
  NetworkManager.service
  fstrim.timer
  iwd.service
  sddm.service
  sshd.service
)

# Reads from /dev/tty so a piped `curl … | bash` run still reaches the keyboard.
promptWithDefault() {
  local promptText="$1"
  local defaultValue="$2"
  local reply=""

  if [[ -r /dev/tty ]]; then
    read -r -p "$promptText [$defaultValue]: " reply < /dev/tty || reply=""
  fi

  printf '%s' "${reply:-$defaultValue}"
}

# Up front, so the long unattended stretch is never interrupted by a question.
promptIdentity() {
  log "Git identity — press Enter to accept the default"

  GIT_USER_NAME="$(promptWithDefault 'Name ' "$GIT_USER_NAME")"
  GIT_USER_EMAIL="$(promptWithDefault 'Email' "$GIT_USER_EMAIL")"
}

# Trade-off: anything running as you can now become root with no prompt.
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
  for file in .bashrc; do
    backup "$HOME/$file"
    cp "$SCRIPT_DIR/shells/bashrc" "$HOME/$file"
  done

  # dotglob because every file in home/ starts with a dot
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

# Takes effect on next login; restarting sddm here would kill your session.
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

# A forked en_GB that is 12-hour but still DD/MM and £. See system/locale/README.md.
setupLocale() {
  local localeName="en_GB@12h"
  local sourceDir="$SCRIPT_DIR/system/locale"

  log "Installing $localeName locale"
  sudo install -Dm644 "$sourceDir/$localeName" "/usr/share/i18n/locales/$localeName"

  # Stock lines carry trailing whitespace, so compare trimmed or we duplicate.
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

  # Globals are per version, so these land on 26. corepack is unbundled in 25+.
  npm install -g corepack @dotenvx/dotenvx
  corepack enable pnpm
  corepack enable yarn
}

# Not the AUR build, so upgrades are `oh-my-posh upgrade` rather than a rebuild.
setupOhMyPosh() {
  local installDir="$HOME/.local/bin"

  if [[ -x "$installDir/oh-my-posh" ]]; then
    log "oh-my-posh already installed — upgrading"
    "$installDir/oh-my-posh" upgrade || warn "oh-my-posh upgrade failed — leaving the current build in place"
    return
  fi

  log "Installing oh-my-posh"
  mkdir -p "$installDir"
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$installDir"
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

# PEP 668 refuses pip outside a venv. Path must match bashrc's activate line.
setupPython() {
  local venvDir="$HOME/venv"

  if [[ -d "$venvDir" ]]; then
    log "venv already exists at $venvDir — skipping"
  else
    log "Creating Python venv at $venvDir"
    python -m venv "$venvDir"
  fi

  "$venvDir/bin/python" -m pip install --upgrade pip setuptools wheel
}

# FONT_ZIPS entries are "destDirName|url", flattened however deep the zip nests.
setupFonts() {
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

  local fileUrl fileName
  for fileUrl in "${FONT_FILES[@]}"; do
    fileName="$(basename "${fileUrl%%\?*}")"

    if [[ -s "$fontsDir/$fileName" ]]; then
      log "Font '$fileName' already installed — skipping"
      continue
    fi

    log "Downloading font: $fileName"
    if ! curl -fsSL "$fileUrl" -o "$fontsDir/$fileName"; then
      warn "failed to download '$fileName' from $fileUrl — skipping"
      rm -f "$fontsDir/$fileName"
    fi
  done

  log "Installing fonts bundled in the repo"
  find "$SCRIPT_DIR/sddm-theme/font" -type f \( -iname '*.otf' -o -iname '*.ttf' \) \
    -exec cp {} "$fontsDir/" \; 2>/dev/null || true

  log "Refreshing font cache"
  fc-cache -f "$fontsDir" > /dev/null
}

# Unpackaged and not in the AUR, so the repo carries them for gtk to resolve.
setupCursors() {
  log "Installing cursor themes to ~/.icons"

  local destinationDir="$HOME/.icons"
  mkdir -p "$destinationDir"

  local entry name destination
  for entry in "$SCRIPT_DIR"/icons/*/; do
    [[ -d "$entry" ]] || continue

    name="$(basename "$entry")"
    destination="$destinationDir/$name"

    if [[ -d "$destination" ]]; then
      log "Cursor theme '$name' already installed — skipping"
      continue
    fi

    cp -r "$entry" "$destination"
  done
}

# No secrets here — GCM keeps those in secretservice. Only which helper answers.
setupGit() {
  log "Configuring git"

  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
  git config --global core.pager cat

  # Clear first or re-runs stack. Unsetting github strips any stale gh helper.
  local key
  for key in \
    credential.helper \
    credential.https://github.com.helper \
    credential.https://gist.github.com.helper
  do
    git config --global --unset-all "$key" || true
  done

  # The empty value is load-bearing: it drops whatever /etc/gitconfig set.
  git config --global --add credential.helper ''
  git config --global --add credential.helper /usr/bin/git-credential-manager
  git config --global credential.credentialStore secretservice

  git config --global credential.https://dev.azure.com.useHttpPath true

  # Hosts GCM cannot auto-detect — 'generic' means plain basic/bearer auth
  local genericHost
  for genericHost in \
    https://backup.doughmination.gay \
    http://127.0.0.1:4099 \
    http://127.0.0.1:4199
  do
    git config --global "credential.$genericHost.provider" generic
  done
}

# zram-generator ships no /etc config, so without this the package is inert.
setupZram() {
  local sourceFile="$SCRIPT_DIR/system/zram-generator.conf"
  local destination="/etc/systemd/zram-generator.conf"

  log "Configuring zram swap"

  if [[ -e "$destination" ]] && ! cmp -s "$sourceFile" "$destination"; then
    local backupDestination="$destination.bak-$(date +%Y%m%d-%H%M%S)"
    warn "backing up existing $destination -> $backupDestination"
    sudo cp "$destination" "$backupDestination"
  fi

  sudo install -Dm644 "$sourceFile" "$destination"
}

# Enable only — starting sddm here would kill the session running this.
enableServices() {
  ((${#SYSTEM_UNITS[@]})) || return 0

  log "Enabling system services"
  sudo systemctl enable "${SYSTEM_UNITS[@]}"
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

  promptIdentity
  configureSudo
  setupWallpaper
  setupDotfiles
  setupSddmTheme
  setupLocale
  setupZram
  enableMultilib
  installYay
  setupNode
  installPackages
  enableServices
  setupGit
  setupOhMyPosh
  setupBun
  setupPython
  setupFonts
  setupCursors

  log "Done. Reboot to pick up the new services, locale and prompt."
}

main "$@"
