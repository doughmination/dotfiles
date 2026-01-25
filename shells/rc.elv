# Elvish Config
# Location: ~/.config/elvish/rc.elv
# Elvish is a modern, expressive shell

# Import modules
use builtin
use str
use path
use readline-binding

# Custom colors using ANSI escape codes
var pink = "\e[38;5;205m"
var purple = "\e[38;5;135m"
var blue = "\e[38;5;39m"
var black = "\e[38;5;240m"
var white = "\e[0m"
var reset = "\e[0m"

# Git prompt function
fn git-prompt {
    # Check if we're in a git repository
    try {
        var is-git = (git rev-parse --is-inside-work-tree 2>/dev/null | slurp)
        if (eq $is-git "true\n") {
            # Get branch name
            var branch = (git symbolic-ref --short HEAD 2>/dev/null | slurp | str:trim-space (one))
            
            # Check if dirty
            var dirty = ""
            try {
                git diff --quiet 2>/dev/null
            } catch {
                set dirty = "*"
            }
            
            put " ["$branch$dirty"]"
        } else {
            put ""
        }
    } catch {
        put ""
    }
}

# SSH connect with animation
fn ssh-connect {|@args|
    var spinstr = ['⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏']
    print "Connecting... "
    
    # Start SSH in background
    var ssh-pid = (e:ssh $@args &)
    
    # Animate while connecting
    while (kill -0 $ssh-pid 2>/dev/null) {
        for spin $spinstr {
            print "["$spin"]"
            sleep 0.1s
            print "\b\b\b"
        }
    }
    
    # Clear animation
    print "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b               \r"
}

# Custom prompt
set edit:prompt = {
    var user = (whoami | slurp | str:trim-space (one))
    var host = (hostname | slurp | str:trim-space (one))
    var dir = (tilde-abbr $pwd)
    var git = (git-prompt)
    
    # First line
    put "\n"$white"↱"$pink$user$white"@"$purple$host" "$black"["$dir"]"$white$git"\n"
    # Second line
    put $white"↳"$blue"£ "$reset
}

# Right prompt (empty)
set edit:rprompt = {
    put ""
}

# Aliases
fn ll {|@a| e:ls -alF $@a }
fn la {|@a| e:ls -A $@a }
fn l {|@a| e:ls -CF $@a }

# Custom aliases
fn sch {
    ssh-connect clove@clovetwilight3.co.uk -p 420
}

fn sgh {
    ssh-connect clove@girlsnetwork.dev -p 420
}

fn soh {
    ssh-connect clovid@play.somc.club -p 2022
}

fn webtest {
    echo "Syncing files..."
    e:rm -rf ~/weblocal/*
    e:rm -rf ~/weblocal/.[!.]*
    e:rm -rf ~/weblocal/..?*
    e:cp -a ~/girlsnetwork.dev/src/. ~/weblocal/
    echo "Synced!"
}

fn clreload {
    e:git pull
    e:docker compose build --no-cache
    e:docker compose down
    e:docker compose up -d
    e:docker compose logs -f
}

fn webreload {
    e:git pull
    e:docker compose pull
    e:docker compose up -d
}

# Typo-friendly cd
fn cdd {|@a| cd $@a }

# Config management
fn bashedit {
    e:nano ~/.config/elvish/rc.elv
}

fn bashreload {
    eval (slurp < ~/.config/elvish/rc.elv)
    echo "Config reloaded!"
}

# Enable color for ls (if dircolors is available)
try {
    var dircolors-output = (e:dircolors -b | slurp)
    # Parse and set LS_COLORS
    # Elvish doesn't directly support eval, so we'll set a basic LS_COLORS
    set E:LS_COLORS = "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32"
} catch {
    # Fallback if dircolors is not available
    set E:LS_COLORS = "di=34:ln=36:ex=32"
}

# Enable color for grep
set E:GREP_COLOR = "1;32"
set E:GREP_OPTIONS = "--color=auto"

# History settings
set edit:max-history = 1000

# Completion settings
set edit:completion:matcher[''] = {|seed| edit:match-prefix $seed &ignore-case }

# Key bindings (readline-like)
set edit:insert:binding[Ctrl-A] = $edit:move-dot-sol~
set edit:insert:binding[Ctrl-E] = $edit:move-dot-eol~
set edit:insert:binding[Ctrl-U] = $edit:kill-line-left~
set edit:insert:binding[Ctrl-K] = $edit:kill-line-right~
set edit:insert:binding[Ctrl-W] = $edit:kill-word-left~

# Run hyfetch on startup
try {
    if ?(e:which hyfetch >/dev/null 2>&1) {
        e:hyfetch
    }
} catch {
    # hyfetch not available, skip
}
