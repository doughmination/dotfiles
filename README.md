# DotFiles

Personal dotfiles for a SwayFX session on Arch Linux.

Any issues please use the GitHub Issue Tracker

## Install

```bash
sudo pacman -S git git-lfs
git clone https://github.com/doughmination/dotfiles
git lfs install
cd dotfiles
./arch-setup.sh
```

Run as your normal user, not root.

Existing files in `~` are backed up to `~/.dotfiles-backup/<timestamp>/`.

## Layout

| Folder | Installs to |
| --- | --- |
| `shells` | `~` |
| `home` | `~` |
| `sway-config-files` | `~/.config` |
| `local-binaries` | `~/.local/bin` |
| `vscode` | `~/.config/VSCodium/User` |
| `sddm-theme` | `/usr/share/sddm/themes` |
| `wallpapers` | `~/Pictures` |

Package lists live at the top of `arch-setup.sh`.

## Licence

[Doughmination Authorised Source Licence 1.0](./LICENCE.md)
