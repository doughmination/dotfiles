# ~/.zshrc: executed by zsh for interactive shells.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000

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

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Custom
alias bashedit='nano ~/.zshrc'
alias bashreload='source ~/.zshrc'
alias archeon='sudo pacman'
alias sgh='ssh clove@shell.doughmination.win -p 421'

# Clone a doughmination repo by name
doughclone() {
  git clone "https://github.com/doughmination/$1"
}

# Enable zsh completion system
autoload -Uz compinit
compinit -C

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"  # bun completions

# local bin
export PATH="$HOME/.local/bin:$PATH"
