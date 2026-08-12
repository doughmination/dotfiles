# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000


# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

# Custom prompt colors (User)
PINK='\[\033[38;5;205m\]'
PURPLE='\[\033[38;5;135m\]'
BLUE='\[\033[38;5;39m\]'
BLACK='\[\033[38;5;240m\]'
WHITE='\[\033[00m\]'
RESET='\[\033[00m\]'

# Git Function (ChatGPT)
git_prompt() {
    git rev-parse --is-inside-work-tree &>/dev/null || return
    local branch dirty
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    git diff --quiet || dirty="*"
    printf " [%s%s]" "$branch" "$dirty"
}

# User made terminal
if [ "$color_prompt" = yes ]; then
    PS1='\n'"${WHITE}"'↱'"${PINK}"'\u'"${WHITE}"'@'"${PURPLE}"'\h '"${BLACK}"'[\w]'"${WHITE}"'$(git_prompt)'$'\n'"${WHITE}"'↳'"${BLUE}"'£ '"${RESET}"
else
    PS1='\n↱\u@\h [\w]\n↳£ '
fi

unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Custom
alias bashedit='nano ~/.bashrc'
alias bashreload='source ~/.bashrc'
alias archeon='sudo pacman'
alias sgh='ssh clove@shell.doughmination.win -p 421'

# Clone a doughmination repo by name (ported from zsh)
doughclone() {
  git clone "https://github.com/doughmination/$1"
}

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# bun (ported from zsh)
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"  # bun completions

# local bin (ported from zsh)
export PATH="$HOME/.local/bin:$PATH"
