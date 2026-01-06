# ~/.config/fish/config.fish: executed by fish for interactive shells.

# History settings
set -g fish_history_size 1000

# Custom prompt colors
set -g PINK (set_color ff5faf)
set -g PURPLE (set_color af5fff)
set -g BLUE (set_color 00afff)
set -g BLACK (set_color 585858)
set -g WHITE (set_color white)
set -g RESET (set_color normal)

# Git prompt function
function git_prompt
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        return
    end
    set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
    set -l dirty ""
    if not git diff --quiet 2>/dev/null
        set dirty "*"
    end
    printf " [%s%s]" "$branch" "$dirty"
end

# Custom prompt
function fish_prompt
    printf '\n%s↱%s%s%s@%s%s %s[%s]%s%s\n%s↳%s£ %s' \
        $WHITE $PINK (whoami) $WHITE $PURPLE (hostname) $BLACK (prompt_pwd) $WHITE (git_prompt) \
        $WHITE $BLUE $RESET
end

# Terminal title
function fish_title
    echo (whoami)@(hostname): (prompt_pwd)
end

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# SSH connection with animated spinner
function ssh_connect
    set -l spinstr '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'
    printf "Connecting... "
    
    # Start SSH in background
    fish -c "$argv" &
    set -l pid (jobs -l -p)
    
    # Animate while connecting
    while kill -0 $pid 2>/dev/null
        for c in $spinstr
            printf "[$c]"
            sleep 0.1
            printf "\b\b\b"
        end
    end
    
    # Clear animation
    printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b               \r"
end

# Custom Aliases
alias sch='ssh_connect ssh clove@clovetwilight3.co.uk -p 2525'
alias sgh='ssh_connect ssh clove@girlsnetwork.dev -p 420'
alias soh='ssh_connect ssh clovid@play.somc.club -p 2022'
alias webtest='rm -rf ~/weblocal/* ~/weblocal/.[!.]* ~/weblocal/..?* && cp -a ~/girlsnetwork.dev/src/. ~/weblocal/ && echo "Synced!"'
alias clreload='git pull && docker compose build --no-cache && docker compose down && docker compose up -d && docker compose logs -f'
alias webreload='git pull && docker compose pull && docker compose up -d'
alias cdd='cd'
alias bashedit='nano ~/.config/fish/config.fish'
alias bashreload='source ~/.config/fish/config.fish'

# Run hyfetch on terminal start
if command -v hyfetch >/dev/null 2>&1
    hyfetch
end
