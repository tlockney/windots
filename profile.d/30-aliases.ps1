# 30-aliases: zsh-style aliases for PS. Skips macOS-specific ones (pbcopy)
# and ones that depend on POSIX shell features. Functions shadow built-in
# aliases (ls, cat) — Remove-Item Alias:* makes the override explicit.

# --- ls / eza ----------------------------------------------------------

if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -ErrorAction SilentlyContinue -Force
    function l  { eza --icons --git --group-directories-first @args }
    function ls { eza --icons --git --group-directories-first @args }
    function ll { eza -l --icons --git --group-directories-first @args }
    function la { eza -la --icons --git --group-directories-first @args }
    function lt { eza --tree --icons --git --group-directories-first @args }
}

# --- cat / less / grep / find -----------------------------------------

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -ErrorAction SilentlyContinue -Force
    function cat  { bat --paging=never @args }
    function less { bat @args }
}

if (Get-Command rg -ErrorAction SilentlyContinue) {
    function grep { rg @args }
}

if (Get-Command fd -ErrorAction SilentlyContinue) {
    function find { fd @args }
}

# --- Common shortcuts -------------------------------------------------

function g   { git @args }
function lg  { lazygit @args }
function ..  { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# --- Unix-shaped helpers ----------------------------------------------

function mkcd  { param([string]$Path) New-Item -ItemType Directory -Path $Path -Force | Out-Null; Set-Location $Path }
function touch { param([string]$Path) if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date } else { New-Item -ItemType File -Path $Path -Force | Out-Null } }
function which { param([string]$Name) Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }
function head  { param([int]$n = 10, [Parameter(ValueFromPipeline)]$input) $input | Select-Object -First $n }
function tail  { param([int]$n = 10, [Parameter(ValueFromPipeline)]$input) $input | Select-Object -Last $n }

# --- Environment ------------------------------------------------------

function env  { Get-ChildItem Env: | Sort-Object Name }
function path { $env:PATH -split ';' }
function export {
    param([string]$Assignment)
    $parts = $Assignment -split '=', 2
    if ($parts.Count -eq 2) {
        [Environment]::SetEnvironmentVariable($parts[0], $parts[1], 'Process')
    }
}

# Reload profile in-place (handy after editing dotfiles configs).
function reload-profile { . $PROFILE }
