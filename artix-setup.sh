#!/usr/bin/env bash
# artix-setup.sh
#
# Ported from arch-setup.sh. Artix has no systemd, so everything that leaned on
# systemd (service enabling, zram-generator, systemd-boot/UKI, the systemd user
# session) has been reworked for runit + elogind + GRUB. See PORTING-NOTES.md.

set -euo pipefail

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }

# Repo root, so copies work from any cwd
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Where runit expects enabled services. current -> default on a stock Artix box.
RUNIT_ENABLED_DIR="/etc/runit/runsvdir/default"
# Where service definitions live
RUNIT_SV_DIR="/etc/runit/sv"

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
  # init system — the whole reason this is a separate script. runit supervises,
  # elogind gives seats/sessions (sway, sddm, polkit, brightnessctl all need it),
  # dbus-runit provides the system bus service.
  runit
  elogind
  elogind-runit
  dbus-runit

  # base system / firmware / boot
  amd-ucode
  base
  base-devel
  efibootmgr
  grub                # replaces systemd-boot: Artix has no bootctl
  linux
  linux-firmware
  mkinitcpio
  plymouth
  sbctl
  sudo

  # periodic maintenance — replaces the systemd fstrim.timer
  cronie
  cronie-runit

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

  # networking — bluez is the daemon; bluez-utils is only the CLI tools.
  # The *-runit packages carry the runit service definitions Artix splits out.
  bind
  blueman
  bluez
  bluez-runit
  bluez-utils
  iwd
  network-manager-applet
  networkmanager
  networkmanager-runit
  nmap
  openssh
  openssh-runit
  wireless_tools
  wpa_supplicant

  # sway session — swayfx itself is in AUR_PKGS
  autotiling
  brightnessctl
  cliphist
  grim
  libnotify
  hypridle
  mpv
  playerctl
  polkit-kde-agent
  rofi
  slurp
  swaybg
  swayidle
  swaylock
  wf-recorder
  wl-clipboard
  wmenu
  xdg-desktop-portal-gtk
  xdg-desktop-portal-wlr
  xdg-utils

  # audio — pipewire alone ships no SPA backends, so no sinks at all.
  # Without a systemd user session these are launched from the sway config.
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

  # fingerprint — libfprint arrives as a dependency
  fprintd

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
  jq
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
  firefox
  flatpak
  git
  git-lfs
  ibus
  inkscape
  libreoffice-fresh
  obs-studio
  prismlauncher
  steam
  vlc

  # display manager — the qt deps back the theme's BackgroundVideo.qml.
  # sddm-runit carries the runit service; sddm alone would never start.
  qt5-graphicaleffects
  qt5-quickcontrols2
  qt6-5compat
  qt6-multimedia
  qt6-multimedia-ffmpeg
  sddm
  sddm-runit
)

# yay and oh-my-posh are absent on purpose — installYay and setupOhMyPosh.
# swayfx is absent on purpose too — its AUR PKGBUILD hardcodes libsystemd, so it
# gets its own elogind-patched build in installSwayfx.
AUR_PKGS=(
  archy-screenshot
  caelestia-cli
  caelestia-shell
  discord-canary
  docker-desktop
  equicord-installer-bin
  git-credential-manager
  git-credential-manager-extras
  vscodium-bin
  zen-browser-bin
)

# runit service directories to enable (symlink into the runsvdir default dir).
# On Arch most of these were preset-enabled by their package or systemd targets;
# on Artix every one is opt-in. 'zram' is our own service (see setupZram).
RUNIT_SERVICES=(
  dbus            # system bus — pulled in implicitly by systemd on Arch
  elogind         # seats/sessions for sway, sddm, polkit, brightnessctl
  NetworkManager
  iwd
  bluetoothd      # blueman/bluetoothctl need this; was preset-enabled on Arch
  sshd
  cronie          # runs the fstrim cron job below
  sddm
  zram
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

# swayfx does not ship a wayland-session entry on Artix (on Arch the sway package
# provided one), so without this SDDM offers no Sway session and drops you into
# whatever the base install shipped (LXQt). Launching via dbus-run-session also
# gives the session the D-Bus bus the keyring/GCM need — see PORTING-NOTES.
setupSwaySession() {
  log "Installing the Sway wayland-session entry"

  # swayfx installs its binary as `sway`; fall back to `swayfx` just in case.
  local swayBin="sway"
  command -v sway >/dev/null 2>&1 || swayBin="swayfx"
  if ! command -v "$swayBin" >/dev/null 2>&1; then
    warn "no sway/swayfx binary found — is swayfx installed? installing the session entry anyway"
  fi

  sudo install -d /usr/share/wayland-sessions
  sudo install -Dm644 /dev/stdin /usr/share/wayland-sessions/sway.desktop <<EOF
[Desktop Entry]
Name=Sway
Comment=SwayFX Wayland compositor
Exec=dbus-run-session $swayBin
Type=Application
EOF
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

  # theme.conf names the theme, so it has to stay in step with $themeName above
  log "Pointing sddm at $themeName"
  sudo install -Dm644 "$SCRIPT_DIR/sddm-config/sddm.conf.d/theme.conf" /etc/sddm.conf.d/theme.conf

  # Adds pam_fprintd for fingerprint login. The sddm package owns this file, so
  # upgrades will leave a .pacnew to merge by hand rather than updating ours.
  log "Installing sddm PAM config"

  local pamSource="$SCRIPT_DIR/sddm-config/pam.d/sddm"
  local pamDestination="/etc/pam.d/sddm"

  if [[ -e "$pamDestination" ]] && ! cmp -s "$pamSource" "$pamDestination"; then
    local pamBackup="$pamDestination.bak-$(date +%Y%m%d-%H%M%S)"
    warn "backing up existing $pamDestination -> $pamBackup"
    sudo cp "$pamDestination" "$pamBackup"
  fi

  sudo install -Dm644 "$pamSource" "$pamDestination"
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

# Artix ships its own repos and, separately, opt-in access to Arch's. steam's
# 32-bit deps need lib32 (Artix) / multilib (Arch); most AUR builds pull from
# Arch's [extra], so we enable Arch support too. Replaces enableMultilib.
enableRepos() {
  log "Enabling Artix lib32/universe/galaxy repositories"

  # These ship commented in the stock /etc/pacman.conf. Uncomment the [repo]
  # header and its immediate Include line, idempotently.
  local repo
  for repo in lib32 universe galaxy; do
    if grep -qE "^\[$repo\]" /etc/pacman.conf; then
      log "[$repo] already enabled — skipping"
      continue
    fi
    log "Enabling [$repo]"
    sudo sed -i "/^#\s*\[$repo\]/,/^#\s*Include/ s/^#\s*//" /etc/pacman.conf
  done

  # Arch upstream repos: needed by most AUR packages (they build against [extra])
  # and by any package only Arch ships. artix-archlinux-support drops in the
  # keyring + a pacman-conf.d include mechanism.
  if ! pacman -Q artix-archlinux-support &>/dev/null; then
    log "Installing artix-archlinux-support (Arch [extra]/[multilib] access)"
    sudo pacman -Sy --needed --noconfirm artix-archlinux-support
  fi

  # Arch mirrorlist for the upstream repos
  if [[ ! -s /etc/pacman.d/mirrorlist-arch ]]; then
    warn "no /etc/pacman.d/mirrorlist-arch — you may need pacman-mirrorlist-arch"
  fi

  # Append the Arch repo stanzas once, after the Artix ones.
  if ! grep -qE '^\[extra\]' /etc/pacman.conf; then
    log "Adding Arch [extra] and [multilib] repositories"
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'

# --- Arch upstream (added by artix-setup.sh) ---
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF
  else
    log "Arch [extra] already present — skipping"
  fi

  log "Populating the Arch keyring"
  sudo pacman-key --populate archlinux || warn "pacman-key populate archlinux failed"

  # DBs get a full sync here; installPackages does the -Syu
  sudo pacman -Sy
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

# swayfx's AUR PKGBUILD builds with -Dsd-bus-provider=libsystemd, which does not
# exist on Artix, so a plain `yay -S swayfx` dies at meson with
# 'Dependency "libsystemd" not found'. sway/swayfx support elogind's libelogind
# instead (this is how the Artix `sway` package is built), so we fetch the
# PKGBUILD, swap that one flag, and build it ourselves.
installSwayfx() {
  if pacman -Q swayfx &>/dev/null; then
    log "swayfx already installed — skipping"
    return
  fi

  log "Building swayfx against libelogind (Artix has no libsystemd)"

  local buildDir="$HOME/swayfx-build"
  if [[ -d "$buildDir/.git" ]]; then
    git -C "$buildDir" pull --ff-only || true
  else
    rm -rf "$buildDir"
    git clone https://aur.archlinux.org/swayfx.git "$buildDir"
  fi

  # The load-bearing one-line fix.
  sed -i 's/-Dsd-bus-provider=libsystemd/-Dsd-bus-provider=libelogind/' "$buildDir/PKGBUILD"

  if ! ( cd "$buildDir" && makepkg -si --needed --noconfirm ); then
    warn "swayfx build failed — you'll have no Sway compositor until it's fixed"
    warn "inspect the meson error under $buildDir/src/build/meson-logs/"
  fi
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
  # Guarded: under set -e, an unguarded curl|bash here would kill the rest of
  # the script (setupFonts included) on any transient network hiccup.
  if ! curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$installDir"; then
    warn "oh-my-posh install failed — skipping (re-run setupOhMyPosh later)"
  fi
}

# Installs to ~/.bun; both shell rc files already put ~/.bun/bin on PATH
setupBun() {
  if [[ -x "$HOME/.bun/bin/bun" ]]; then
    log "bun already installed — upgrading"
    "$HOME/.bun/bin/bun" upgrade
    return
  fi

  log "Installing bun"
  if ! curl -fsSL https://bun.com/install | bash; then
    warn "bun install failed — skipping (re-run setupBun later)"
  fi
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
# caelestia is built for Hyprland and ships zero sway support. These patches are
# what make it usable here: without them the workspace pill stays empty and every
# drawers IPC call silently no-ops, so the launcher, session menu and dashboard
# keybinds do nothing at all.
setupCaelestia() {
  local shellDir="/etc/xdg/quickshell/caelestia"
  local patchFile="$HOME/.config/caelestia/sway-fixes.patch"

  log "Installing caelestia colour scheme"
  install -Dm644 "$SCRIPT_DIR/caelestia-state/scheme.json" \
    "$HOME/.local/state/caelestia/scheme.json"

  if [[ ! -d "$shellDir" ]]; then
    warn "caelestia-shell is not installed; skipping its sway patches"
    return 0
  fi

  if [[ ! -f "$patchFile" ]]; then
    warn "no sway-fixes.patch in ~/.config/caelestia; skipping"
    return 0
  fi

  # --forward makes a re-run a no-op rather than offering to reverse the patch
  if sudo patch -d "$shellDir" -p0 --forward --dry-run < "$patchFile" >/dev/null 2>&1; then
    log "Applying caelestia sway patches"
    sudo patch -d "$shellDir" -p0 --forward < "$patchFile" >/dev/null
  else
    warn "caelestia sway patches already applied, or no longer apply cleanly"
    warn "if caelestia was just updated, re-diff them against the new version"
  fi
}

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

  # Registers the LFS filters; wallpapers/*.mp4 is stored via LFS
  git lfs install

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

# On Arch this was a systemd-generator config. Artix has no systemd, so we ship a
# small runit service (system/runit/zram) that sets up the device at boot and
# tears it down on stop. Enabled in enableServices via the RUNIT_SERVICES list.
setupZram() {
  local sourceDir="$SCRIPT_DIR/system/runit/zram"
  local destination="$RUNIT_SV_DIR/zram"

  log "Installing zram runit service"

  sudo install -d "$destination"
  sudo install -Dm755 "$sourceDir/run"    "$destination/run"
  sudo install -Dm755 "$sourceDir/finish" "$destination/finish"
}

# Adds a weekly fstrim, replacing the systemd fstrim.timer. cronie runs it.
setupFstrimCron() {
  log "Installing weekly fstrim cron job"
  sudo install -Dm755 /dev/stdin /etc/cron.weekly/fstrim <<'EOF'
#!/bin/sh
# Weekly discard of unused blocks on all mounted, trim-capable filesystems.
exec /usr/bin/fstrim --all --quiet-unsupported
EOF
}

# runit "enable" is a symlink into the runsvdir default dir. Services come up on
# the next boot — which is exactly what we want: sddm can't be started here (it
# would kill this session), and main() ends by telling you to reboot.
enableServices() {
  ((${#RUNIT_SERVICES[@]})) || return 0

  log "Enabling runit services"

  local svc
  for svc in "${RUNIT_SERVICES[@]}"; do
    if [[ ! -d "$RUNIT_SV_DIR/$svc" ]]; then
      warn "no service definition at $RUNIT_SV_DIR/$svc — is its *-runit package installed? skipping"
      continue
    fi

    if [[ -L "$RUNIT_ENABLED_DIR/$svc" ]]; then
      log "$svc already enabled — skipping"
      continue
    fi

    sudo ln -s "$RUNIT_SV_DIR/$svc" "$RUNIT_ENABLED_DIR/$svc"
    log "enabled $svc"
  done
}

# pacman won't auto-remove a conflicting package under --noconfirm (it takes the
# safe default and aborts the whole transaction). Two flavours of clash show up
# on Artix, resolved in opposite directions:
#
# 1. OBSOLETE_PKGS — an installed package is superseded by one we want. Remove
#    the old one (its replacement is in PACMAN_PKGS).
OBSOLETE_PKGS=(
  exfat-utils   # superseded by exfatprogs
)

# 2. PROVIDER_VARIANTS — an installed variant already satisfies a package we
#    list, and is the one to keep. Drop our generic name from the install set so
#    we don't try to replace the better variant. Format "generic:installed-variant".
#    Artix ships enhanced xorg-server/mesa builds that 'provide' the stock names.
PROVIDER_VARIANTS=(
  "xorg-server:xorg-server-tearfree"
)

# Build the effective install list: PACMAN_PKGS minus any generic whose preferred
# variant is already installed. Result lands in EFFECTIVE_PKGS.
filterProviderVariants() {
  local -A drop=()
  local pair generic variant
  for pair in "${PROVIDER_VARIANTS[@]}"; do
    generic="${pair%%:*}"
    variant="${pair#*:}"
    if pacman -Q "$variant" &>/dev/null; then
      drop["$generic"]=1
      log "keeping installed $variant — dropping $generic from the install list"
    fi
  done

  EFFECTIVE_PKGS=()
  local pkg
  for pkg in "${PACMAN_PKGS[@]}"; do
    [[ -n "${drop[$pkg]:-}" ]] && continue
    EFFECTIVE_PKGS+=("$pkg")
  done
}

removeObsoletePackages() {
  local obsolete toRemove=()

  for obsolete in "${OBSOLETE_PKGS[@]}"; do
    if pacman -Q "$obsolete" &>/dev/null; then
      toRemove+=("$obsolete")
    fi
  done

  ((${#toRemove[@]})) || return 0

  log "Removing superseded packages that would block the install: ${toRemove[*]}"
  # -dd: skip dependency checks — these have no reverse deps, and their
  # replacements are about to be installed in the same run.
  sudo pacman -Rdd --noconfirm "${toRemove[@]}"
}

installPackages() {
  removeObsoletePackages
  filterProviderVariants

  if ((${#EFFECTIVE_PKGS[@]})); then
    log "Refreshing, upgrading, and installing pacman packages"
    sudo pacman -Syu --needed --noconfirm "${EFFECTIVE_PKGS[@]}"
  fi

  if ((${#AUR_PKGS[@]})); then
    log "Installing AUR packages"

    # One at a time, and never let a single failed build abort the whole run
    # (which is exactly what a batch `yay -S ...` under `set -e` would do). A bad
    # AUR build should cost you that one package, not the rest of the setup.
    local pkg aurFailed=()
    for pkg in "${AUR_PKGS[@]}"; do
      if ! yay -S --needed --noconfirm "$pkg"; then
        warn "AUR package failed to build/install: $pkg — continuing"
        aurFailed+=("$pkg")
      fi
    done

    if ((${#aurFailed[@]})); then
      warn "these AUR packages did NOT install: ${aurFailed[*]}"
      warn "re-run 'yay -S <pkg>' by hand to see the build error"
    fi
  fi
}

backupIfDiffers() {
  local sourceFile="$1"
  local destination="$2"

  [[ -e "$destination" ]] || return 0
  cmp -s "$sourceFile" "$destination" && return 0

  local backupDestination="$destination.bak-$(date +%Y%m%d-%H%M%S)"
  warn "backing up existing $destination -> $backupDestination"
  sudo cp "$destination" "$backupDestination"
}

# Arch built a signed UKI and let systemd-boot load it. mkinitcpio's UKI mode
# needs the EFI stub shipped by the systemd package, which does not exist on
# Artix — so we boot a plain initramfs through GRUB instead, and reproduce the
# silent graphical boot with a hidden GRUB timeout + plymouth. See PORTING-NOTES.
setupSilentBoot() {
  local sourceDir="$SCRIPT_DIR/system/boot"

  log "Configuring silent graphical boot (GRUB + plymouth)"

  # Where the ESP is mounted. The original repo used /boot as the ESP.
  local espDir="/boot"
  if [[ ! -d "$espDir/EFI" ]]; then
    warn "no EFI dir under $espDir — is the ESP mounted at $espDir? skipping boot config"
    return
  fi

  # Standard initramfs preset (no UKI). Package default is already this shape;
  # we install ours to be explicit and reproducible.
  backupIfDiffers "$sourceDir/linux.preset" /etc/mkinitcpio.d/linux.preset
  sudo install -Dm644 "$sourceDir/linux.preset" /etc/mkinitcpio.d/linux.preset

  backupIfDiffers "$sourceDir/mkinitcpio.conf" /etc/mkinitcpio.conf
  sudo install -Dm644 "$sourceDir/mkinitcpio.conf" /etc/mkinitcpio.conf

  backupIfDiffers "$sourceDir/plymouthd.conf" /etc/plymouth/plymouthd.conf
  sudo install -Dm644 "$sourceDir/plymouthd.conf" /etc/plymouth/plymouthd.conf

  log "Rebuilding the initramfs"
  sudo mkinitcpio -P

  # GRUB reads its kernel params from /etc/default/grub. We keep the silent-boot
  # flags but drop the systemd-only ones (systemd.show_status) and the root=/
  # rootfstype= pins — grub-mkconfig detects the root device itself.
  local cmdline="quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 zswap.enabled=0"

  log "Writing silent-boot flags to /etc/default/grub"
  sudo cp /etc/default/grub "/etc/default/grub.bak-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true

  setGrubKey() {
    local key="$1" value="$2"
    if grep -qE "^#?\s*$key=" /etc/default/grub; then
      sudo sed -i "s|^#\?\s*$key=.*|$key=$value|" /etc/default/grub
    else
      printf '%s=%s\n' "$key" "$value" | sudo tee -a /etc/default/grub > /dev/null
    fi
  }

  setGrubKey GRUB_TIMEOUT 0
  setGrubKey GRUB_TIMEOUT_STYLE hidden
  setGrubKey GRUB_CMDLINE_LINUX_DEFAULT "\"$cmdline\""
  unset -f setGrubKey

  # Install GRUB to the ESP if it is not already there, then generate its config.
  if [[ ! -d "$espDir/grub" ]]; then
    log "Installing GRUB to the ESP"
    sudo grub-install --target=x86_64-efi --efi-directory="$espDir" --bootloader-id=Artix
  fi

  log "Generating GRUB config"
  sudo grub-mkconfig -o "$espDir/grub/grub.cfg"
}

main() {
  if [[ ${EUID} -eq 0 ]]; then
    warn "Run this as your normal user, not root. Aborting."
    exit 1
  fi
  git lfs pull
  promptIdentity
  configureSudo
  enableRepos
  installYay
  installPackages
  installSwayfx

  # System + login-critical first, so a failure in the fragile user-tooling
  # steps below (nvm/bun/omp curl installs, AUR patches) can't leave you at a
  # broken login. These are the pieces that decide whether you boot into Sway.
  setupLocale
  setupZram
  setupFstrimCron
  setupSilentBoot
  enableServices
  setupSwaySession
  setupSddmTheme

  # User environment / dotfiles — nice to have, but non-fatal if one trips.
  setupNode
  setupGit
  setupOhMyPosh
  setupBun
  setupPython
  setupFonts
  setupCursors
  setupWallpaper
  setupDotfiles
  setupCaelestia

  log "Done. Reboot to pick up the new services, locale and prompt."
  log "At the SDDM greeter, pick the 'Sway' session (it is remembered after the first login)."
}

main "$@"
