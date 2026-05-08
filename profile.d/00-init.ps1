# 00-init: environment that everything else depends on.
# Numeric prefix is intentional — Sort-Object Name in the loader gives us
# init → tools → aliases ordering without an explicit dependency graph.

# XDG so cross-platform tools find their configs in the same relative paths
# as on macOS/Linux. Tools that respect XDG: starship, lazygit, mise, bat
# (with BAT_CONFIG_DIR set below), eza, zoxide.
if (-not $env:XDG_CONFIG_HOME) {
    $env:XDG_CONFIG_HOME = Join-Path $env:USERPROFILE '.config'
}
if (-not $env:XDG_DATA_HOME) {
    $env:XDG_DATA_HOME = Join-Path $env:LOCALAPPDATA 'xdg-data'
}
if (-not $env:XDG_CACHE_HOME) {
    $env:XDG_CACHE_HOME = Join-Path $env:LOCALAPPDATA 'xdg-cache'
}

# bat reads BAT_CONFIG_DIR for its config root rather than honoring XDG fully.
$env:BAT_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'bat'

# Tag so dotfiles/.tmux.conf's %if guards activate the Windows-shaped bits
# (default-shell pwsh, etc.) instead of $SHELL.
$env:TMUX_PLATFORM = 'windows'

# Editor fallback chain mirrors common-profile.sh on the POSIX side.
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $env:EDITOR = 'nvim'
} elseif (Get-Command code -ErrorAction SilentlyContinue) {
    $env:EDITOR = 'code'
} else {
    $env:EDITOR = 'notepad'
}
