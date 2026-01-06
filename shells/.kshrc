# ~/.kshrc: executed by ksh for interactive shells.

# History settings
HISTFILE=~/.ksh_history
HISTSIZE=1000

# Custom prompt colors
PINK=$'\033[38;5;205m'
PURPLE=$'\033[38;5;135m'
BLUE=$'\033[38;5;39m'
BLACK=$'\033[38;5;240m'
WHITE=$'\033[00m'
RESET=$'\033[00m'

# Git function
git_prompt() {
    git rev-parse --is-inside-work-tree &>/dev/null || return
    typeset branch dirty
    branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    git diff --quiet || dirty="*"
    printf " [%s%s]" "$branch" "$dirty"
}

# SSH connection with animated spinner
ssh_connect() {
    typeset delay=0.1
    typeset spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    printf "Connecting... "
    
    # Start SSH in background
    "$@" &
    typeset pid=$!
    
    # Animate while connecting
    while kill -0 $pid 2>/dev/null; do
        typeset temp=${spinstr#?}
        printf "[%c]" "${spinstr%${temp}}"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    
    # Clear animation
    printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b               \r"
    wait $pid
}

# Custom prompt with command substitution
PS1='
'"${WHITE}"'↱'"${PINK}"'${USER}'"${WHITE}"'@'"${PURPLE}"'${HOSTNAME%%.*} '"${BLACK}"'[${PWD}]'"${WHITE}"'$(git_prompt)
'"${WHITE}"'↳'"${BLUE}"'£ '"${RESET}"

# Terminal title
case "$TERM" in
xterm*|rxvt*)
    PS1=$'\033]0;${USER}@${HOSTNAME%%.*}: ${PWD}\007'"$PS1"
    ;;
esac

# Enable color support for ls
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd

# Aliases
alias ls='ls --color=auto 2>/dev/null || ls -G'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Custom Aliases
alias sch='ssh_connect ssh clove@clovetwilight3.co.uk -p 2525'
alias sgh='ssh_connect ssh clove@girlsnetwork.dev -p 420'
alias soh='ssh_connect ssh clovid@play.somc.club -p 2022'
alias webtest='rm -rf ~/weblocal/* ~/weblocal/.[!.]* ~/weblocal/..?* && cp -a ~/girlsnetwork.dev/src/. ~/weblocal/ && echo "Synced!"'
alias clreload='git pull && docker compose build --no-cache && docker compose down && docker compose up -d && docker compose logs -f'
alias webreload='git pull && docker compose pull && docker compose up -d'
alias cdd='cd'
alias bashedit='nano ~/.kshrc'
alias bashreload='. ~/.kshrc'

# Run hyfetch on terminal start
if command -v hyfetch >/dev/null 2>&1; then
    hyfetch
fi
