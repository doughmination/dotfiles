# Private Files

This collection includes custom shell configurations for various shells, all featuring the same color scheme, custom prompt with git branch display, and aliases, and the raw code for the ESAL-1.2

## ESAL-1.2
This can be found in the [LICENCE.md](./LICENCE.md)

## Shells Included

### 1. **Bash** (`.bashrc`)
- **Full name:** Bourne Again Shell
- **Location:** `~/.bashrc`
- **Default on:** Most Linux distributions
- **Installation:** Already provided, just copy to `~/.bashrc`

### 2. **Zsh** (`.zshrc`)
- **Full name:** Z Shell
- **Location:** `~/.zshrc`
- **Default on:** macOS (since Catalina), some Linux distributions
- **Installation:** Copy to `~/.zshrc` and run `source ~/.zshrc`

### 3. **Fish** (`config.fish`)
- **Full name:** Friendly Interactive Shell
- **Location:** `~/.config/fish/config.fish`
- **Default on:** None (must be installed)
- **Installation:**
  ```bash
  # Install fish first
  # On Ubuntu/Debian: sudo apt install fish
  # On macOS: brew install fish
  
  # Create config directory and copy file
  mkdir -p ~/.config/fish
  cp config.fish ~/.config/fish/config.fish
  ```

### 4. **Ksh** (`kshrc`)
- **Full name:** Korn Shell
- **Location:** `~/.kshrc`
- **Default on:** Some Unix systems (AIX, Solaris)
- **Installation:**
  ```bash
  # Install ksh first (if needed)
  # On Ubuntu/Debian: sudo apt install ksh
  # On macOS: brew install ksh
  
  # Copy file and set ENV variable in ~/.profile
  cp kshrc ~/.kshrc
  echo 'export ENV="$HOME/.kshrc"' >> ~/.profile
  ```

### 5. **Tcsh** (`tcshrc`)
- **Full name:** TENEX C Shell (enhanced C shell)
- **Location:** `~/.tcshrc`
- **Default on:** FreeBSD (for root user)
- **Installation:**
  ```bash
  # Install tcsh first (if needed)
  # On Ubuntu/Debian: sudo apt install tcsh
  # On macOS: Already included
  
  # Copy file
  cp tcshrc ~/.tcshrc
  ```

### 6. **Dash/Ash** (`ashrc`)
- **Full name:** Debian Almquist Shell
- **Location:** `~/.ashrc`
- **Default on:** Often used as `/bin/sh` on Debian/Ubuntu
- **Installation:**
  ```bash
  # Usually already installed as /bin/dash
  # Copy file and set ENV variable
  cp ashrc ~/.ashrc
  echo 'export ENV="$HOME/.ashrc"' >> ~/.profile
  ```

## Features Common to All Shells

### Custom Prompt
- **First line:** Username, hostname, current directory, git branch (if in a repo)
- **Second line:** Command input with custom symbol (£)
- **Color scheme:**
  - Pink: username
  - Purple: hostname
  - Black: directory path
  - Blue: command symbol
  - White: git branch info

### Git Integration
- Shows current branch name in prompt
- Displays asterisk (*) when there are uncommitted changes

### Aliases
All shells include these aliases:
- `ll`, `la`, `l` - Various ls options
- `sch` - SSH to clovetwilight3.co.uk
- `sgh` - SSH to girlsnetwork.dev
- `webtest` - Sync web files
- `clreload` - Git pull and Docker compose rebuild
- `webreload` - Git pull and Docker compose update
- `cdd` - Typo-friendly cd
- `bashedit` - Edit shell config (adjusted per shell)
- `bashreload` - Reload shell config

### Startup
- Runs `hyfetch` on terminal start (if installed)

## Changing Your Default Shell

To change your default shell:

```bash
# List available shells
cat /etc/shells

# Change to desired shell (example: zsh)
chsh -s /bin/zsh

# Or for fish
chsh -s /usr/bin/fish
```

Log out and back in for changes to take effect.

## Notes

- **Fish** has a different syntax and doesn't use traditional shell scripting
- **Tcsh** and **Dash** have limited features compared to bash/zsh
- **Ksh** and **Dash** require setting the `ENV` variable in `~/.profile`
- Some prompts may look slightly different depending on shell capabilities
- Color support depends on terminal emulator

## Testing a Shell Without Changing Default

You can test any shell by simply typing its name:
```bash
zsh
fish
ksh
tcsh
dash
```

Type `exit` to return to your previous shell.
