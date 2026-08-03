# PowerShell Profile
# Location: $PROFILE (typically ~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
# For Windows PowerShell 5.1: ~\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1

# Custom prompt colors using ANSI escape codes
# Note: `e escape sequence requires PowerShell 6.0+
# For PowerShell 5.1, use $([char]27) instead

# Clear banner
Clear-Host

# Colors
$ESC = [char]27
$PINK = "$ESC[38;5;205m"
$PURPLE = "$ESC[38;5;135m"
$BLUE = "$ESC[38;5;39m"
$BLACK = "$ESC[38;5;240m"
$WHITE = "$ESC[0m"
$RESET = "$ESC[0m"

# Git prompt function
function Get-GitPrompt {
    try {
        $gitStatus = git rev-parse --is-inside-work-tree 2>$null
        if ($LASTEXITCODE -eq 0) {
            $branch = git symbolic-ref --short HEAD 2>$null
            $dirty = ""
            git diff --quiet 2>$null
            if ($LASTEXITCODE -ne 0) {
                $dirty = "*"
            }
            return " [$branch$dirty]"
        }
    }
    catch {
        return ""
    }
    return ""
}

# Custom prompt function
function prompt {
    $currentPath = $PWD.Path
    $userName = $env:USERNAME
    $computerName = $env:COMPUTERNAME
    $gitInfo = Get-GitPrompt
    
    # First line: username@hostname [path] git-info
    Write-Host ""
    Write-Host "$WHITE$([char]0x21B1)$PINK$userName$WHITE@$PURPLE$computerName $BLACK[$currentPath]$WHITE$gitInfo" -NoNewline
    
    # Second line: command symbol
    Write-Host ""
    Write-Host "$WHITE$([char]0x21B3)$BLUE£ $RESET" -NoNewline
    
    # Return space for actual prompt
    return " "
}

# Set window title
$host.ui.RawUI.WindowTitle = "$env:USERNAME@$env:COMPUTERNAME"

# Enable prediction (PowerShell 7.1+)
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
}

# Set PSReadLine options for better command line editing
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Aliases (PowerShell uses Set-Alias or function for complex commands)
Set-Alias -Name ll -Value Get-ChildItem

function la { Get-ChildItem -Force }
function l { Get-ChildItem }

# Grep-like functionality (uses Select-String)
function grep { 
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Pattern,
        [Parameter(ValueFromPipeline=$true)]
        [string]$InputObject
    )
    
    if ($InputObject) {
        $InputObject | Select-String -Pattern $Pattern
    } else {
        Select-String -Pattern $Pattern
    }
}

# Custom Aliases - Simple connecting message
# Note: PowerShell doesn't handle SSH animations well due to terminal I/O conflicts
function sch {
    Write-Host "Connecting..." -ForegroundColor Cyan
    ssh clove@ssh.doughmination.win -p 420
}

function sgh {
    Write-Host "Connecting..." -ForegroundColor Cyan
    ssh clove@girlsnetwork.dev -p 420
}

function soh {
    Write-Host "Connecting..." -ForegroundColor Cyan
    ssh clovid@play.somc.club -p 2022
}

function webtest {
    Write-Host "Syncing files..."
    Remove-Item -Path ~/weblocal/* -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path ~/girlsnetwork.dev/src/* -Destination ~/weblocal/ -Recurse -Force
    Write-Host "Synced!"
}

function clreload {
    git pull
    docker compose build --no-cache
    docker compose down
    docker compose up -d
    docker compose logs -f
}

function webreload {
    git pull
    docker compose pull
    docker compose up -d
}

# Typo-friendly cd
function cdd {
    param([string]$Path)
    Set-Location $Path
}

# Clone a doughmination repo by name (ported from zsh)
function doughclone {
    param([Parameter(Mandatory=$true)][string]$RepoName)
    git clone "https://github.com/doughmination/$RepoName"
}

# Profile management
function bashedit {
    if (Test-Path $PROFILE) {
        notepad $PROFILE
    } else {
        Write-Host "Creating profile at: $PROFILE"
        New-Item -Path $PROFILE -ItemType File -Force
        notepad $PROFILE
    }
}

function bashreload {
    . $PROFILE
    Write-Host "Profile reloaded!"
}

# Enhanced ls with colors (if Get-ChildItemColor module is installed)
if (Get-Module -ListAvailable -Name Get-ChildItemColor) {
    Import-Module Get-ChildItemColor
    Set-Alias -Name ls -Value Get-ChildItemColor -Force
}

# bun (ported from zsh)
$env:BUN_INSTALL = "$HOME\.bun"
$env:PATH = "$env:BUN_INSTALL\bin;$env:PATH"

# local bin equivalent (ported from zsh's ~/.local/bin, only added if present)
if (Test-Path "$HOME\.local\bin") {
    $env:PATH = "$HOME\.local\bin;$env:PATH"
}

# Android SDK platform-tools (ported from zsh, macOS path — adjust for this machine)
# $env:PATH = "$env:PATH;$HOME\AppData\Local\Android\Sdk\platform-tools"

# Run hyfetch on terminal start (if installed and available)
if (Get-Command hyfetch -ErrorAction SilentlyContinue) {
    hyfetch
}

# Welcome message (optional - comment out if not desired)
# Write-Host "$PURPLE`nWelcome to PowerShell!$RESET" -NoNewline
