# ~/.zshrc: executed by zsh for interactive shells.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Enable extended globbing
setopt EXTENDED_GLOB

# Git function
git_prompt() {
    git rev-parse --is-inside-work-tree &>/dev/null || return
    local branch dirty
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    git diff --quiet || dirty="*"
    printf " [%s%s]" "$branch" "$dirty"
}

# Custom prompt colors
PINK='%F{205}'
PURPLE='%F{135}'
BLUE='%F{39}'
BLACK='%F{240}'
WHITE='%F{white}'
RESET='%f'

# Set prompt with colors and git info
setopt PROMPT_SUBST
PROMPT=$'\n'"${WHITE}"'↱'"${PINK}"'%n'"${WHITE}"'@'"${PURPLE}"'%m '"${BLACK}"'[%~]'"${WHITE}"'$(git_prompt)'$'\n'"${WHITE}"'↳'"${BLUE}"'£ '"${RESET}"

# Terminal title
case "$TERM" in
xterm*|rxvt*)
    precmd() {
        print -Pn "\e]0;%n@%m: %~\a"
    }
    ;;
esac

# Enable color support for ls (macOS uses different flags)
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Color support for grep
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ls aliases (macOS uses BSD ls, not GNU ls)
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# SSH connection with animated spinner
ssh_connect() {
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    printf "Connecting... "
    
    # Start SSH in background
    "$@" &
    local pid=$!
    
    # Animate while connecting
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr:0:1}
        printf "[%s]" "$temp"
        spinstr="${spinstr:1}$temp"
        sleep $delay
        printf "\b\b\b"
    done
    
    # Clear animation
    printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b               \r"
    wait $pid
}

# Custom Aliases
alias sch='ssh_connect ssh clove@ssh.doughmination.win -p 420'
alias sgh='ssh_connect ssh clove@girlsnetwork.dev -p 420'
alias soh='ssh_connect ssh clovid@play.somc.club -p 2022'
alias webtest='rm -rf ~/weblocal/* ~/weblocal/.[!.]* ~/weblocal/..?* && cp -a ~/girlsnetwork.dev/src/. ~/weblocal/ && echo "Synced!"'
alias clreload='git pull && docker compose build --no-cache && docker compose down && docker compose up -d && docker compose logs -f'
alias webreload='git pull && docker compose pull && docker compose up -d'
alias cdd='cd'
alias bashedit='nano ~/.zshrc'
alias bashreload='source ~/.zshrc'

# Alert alias (macOS uses different notification system)
# Note: requires terminal-notifier or similar tool
# Install with: brew install terminal-notifier
if command -v terminal-notifier >/dev/null 2>&1; then
    alias alert='terminal-notifier -title "Terminal" -message "Command finished" -sound default'
fi

# Load custom aliases if they exist
if [ -f ~/.zsh_aliases ]; then
    . ~/.zsh_aliases
fi

# Enable zsh completion system
autoload -Uz compinit
compinit

# Run hyfetch on terminal start
if command -v hyfetch >/dev/null 2>&1; then
    hyfetch
fi


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
