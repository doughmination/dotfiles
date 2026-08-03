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
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd () {
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

# Custom Aliases
alias sgh='echo "Connecting..." && ssh clove@shell.doughmination.win -p 421'
alias bashedit='nano ~/.zshrc'
alias bashreload='source ~/.zshrc'
doughclone() {
  git clone "https://github.com/doughmination/$1"
}

# Load custom aliases if they exist
if [ -f ~/.zsh_aliases ]; then
    . ~/.zsh_aliases
fi

# Enable zsh completion system
autoload -Uz compinit
compinit -C


export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# bun completions
[ -s "/Users/clovetwilight/.bun/_bun" ] && source "/Users/clovetwilight/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH=$PATH:~/.android-sdk-macosx/platform-tools/

# Run hyfetch on terminal start
if [[ -o interactive ]] && [[ -z "$TMUX" ]] && command -v hyfetch >/dev/null 2>&1; then
    hyfetch
fi
