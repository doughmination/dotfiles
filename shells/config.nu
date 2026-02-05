# Nushell Config
# Location: ~/.config/nushell/config.nu
# Nushell is a modern, structured data shell

# Custom prompt configuration
$env.PROMPT_COMMAND = {||
    # Colors using ANSI codes
    let pink = (ansi { fg: '#ff5faf' })
    let purple = (ansi { fg: '#af5fff' })
    let blue = (ansi { fg: '#00afff' })
    let black = (ansi { fg: '#585858' })
    let white = (ansi white)
    let reset = (ansi reset)
    
    # Get current directory
    let dir = ($env.PWD | str replace $nu.home-path '~')
    
    # Git branch info
    let git_info = (
        do -i {
            let branch = (git symbolic-ref --short HEAD | complete | get stdout | str trim)
            if ($branch | is-empty) {
                ""
            } else {
                let dirty = (git diff --quiet | complete | get exit_code)
                if $dirty != 0 {
                    $" [($branch)*]"
                } else {
                    $" [($branch)]"
                }
            }
        } | default ""
    )
    
    # Build the prompt (first line)
    let prompt = $"($white)↱($pink)(whoami)($white)@($purple)(hostname)($black) [($dir)]($white)($git_info)\n($white)↳($blue)£ ($reset)"
    
    $prompt
}

# Right prompt (optional - shows time)
$env.PROMPT_COMMAND_RIGHT = {||
    ""
}

# Prompt indicator for continuation lines
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""
$env.PROMPT_MULTILINE_INDICATOR = ""

# Environment
$env.EDITOR = "nano"

# Aliases
alias ll = ls -la
alias la = ls -a
alias l = ls

# SSH connect with animation
def ssh_connect [host: string port: string user: string] {
    let spinstr = ['⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏']
    print -n "Connecting... "
    
    # Start SSH in background (Nushell doesn't support true background jobs like bash)
    # So we'll just show a simple message
    print ""
    ssh $"($user)@($host)" -p $port
}

# Custom aliases
alias sch = ssh_connect ssh.doughmination.win 420 clove
alias sgh = ssh_connect girlsnetwork.dev 420 clove
alias soh = ssh_connect play.somc.club 2022 clovid

# Complex aliases as custom commands
def webtest [] {
    echo "Syncing files..."
    rm -rf ~/weblocal/*
    rm -rf ~/weblocal/.[^.]*
    cp -r ~/girlsnetwork.dev/src/* ~/weblocal/
    echo "Synced!"
}

def clreload [] {
    git pull
    docker compose build --no-cache
    docker compose down
    docker compose up -d
    docker compose logs -f
}

def webreload [] {
    git pull
    docker compose pull
    docker compose up -d
}

# Typo-friendly cd
alias cdd = cd

# Config management
def bashedit [] {
    nano ~/.config/nushell/config.nu
}

def bashreload [] {
    source ~/.config/nushell/config.nu
    echo "Config reloaded!"
}

# Color configuration for ls
$env.LS_COLORS = (vivid generate molokai | str trim)

# Nushell-specific configurations
$env.config = {
    show_banner: false
    
    # Table configuration
    table: {
        mode: rounded
        index_mode: auto
        trim: {
            methodology: wrapping
            wrapping_try_keep_words: true
        }
    }
    
    # Completion configuration
    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
    }
    
    # History configuration
    history: {
        max_size: 1000
        sync_on_enter: true
        file_format: "plaintext"
    }
    
    # File size format
    filesize: {
        metric: false
        format: "auto"
    }
    
    # Cursor shape
    cursor_shape: {
        emacs: line
        vi_insert: line
        vi_normal: block
    }
    
    # Color config
    color_config: {
        separator: white
        leading_trailing_space_bg: { attr: n }
        header: green_bold
        empty: blue
        bool: white
        int: white
        filesize: cyan
        duration: white
        date: purple
        range: white
        float: white
        string: white
        nothing: white
        binary: white
        cellpath: white
        row_index: green_bold
        record: white
        list: white
        block: white
        hints: dark_gray
    }
    
    # Use ls_colors for file listings
    use_ls_colors: true
    
    # Editing mode
    edit_mode: emacs
    
    # Shell integration
    shell_integration: true
    
    # Render right prompt on last line
    render_right_prompt_on_last_line: false
}

# Run hyfetch on startup
if (which hyfetch | is-not-empty) {
    hyfetch
}
