# 20-aliases: the subset of dotfiles' aliases that translate cleanly to PS.
# Skipping macOS-specific ones (pbcopy, open) and ones that depend on POSIX
# shell features.

# eza for directory listings (matches the zsh aliases).
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function l { eza --icons --git @args }
    function ls { eza --icons --git @args }
    function ll { eza -l --icons --git @args }
    function la { eza -la --icons --git @args }
    function lt { eza --tree --icons --git @args }
}

# bat replaces cat when present.
if (Get-Command bat -ErrorAction SilentlyContinue) {
    function cat { bat @args }
}

# Common shortcuts.
function g { git @args }
function lg { lazygit @args }
function .. { Set-Location .. }
function ... { Set-Location ..\.. }

# Reload profile in-place (handy after editing dotfiles configs).
function reload-profile { . $PROFILE }
