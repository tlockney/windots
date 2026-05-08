# 20-tools: shell integrations for tools installed by bootstrap.
# Each block guards with Get-Command (or Get-Module) so a partial install
# doesn't break the whole profile.

# --- Tool-init cache --------------------------------------------------
# Every `& tool init powershell` is a fresh process spawn (50–200ms on
# Windows). Inside tmux a new pane = a full profile load, so this adds
# up fast. The init scripts these tools emit are deterministic given
# the binary version: a stub that calls back into the binary at prompt
# / chpwd / completion time, not inline state. Cache the output to disk
# and dot-source the cache, regenerating only when the binary mtime is
# newer than the cache.
#
# Manual invalidation: delete files in $env:LOCALAPPDATA\windots\init-cache.

$script:WindotsInitCacheDir = Join-Path $env:LOCALAPPDATA 'windots\init-cache'
if (-not (Test-Path $script:WindotsInitCacheDir)) {
    New-Item -ItemType Directory -Path $script:WindotsInitCacheDir -Force | Out-Null
}

function Use-CachedToolInit {
    param(
        [Parameter(Mandatory)] [string]   $Name,
        [Parameter(Mandatory)] [string]   $Command,
        [Parameter(Mandatory)] [string[]] $InitArgs
    )
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) { return }

    $cacheFile = Join-Path $script:WindotsInitCacheDir "$Name.ps1"
    $regen = $true
    if (Test-Path $cacheFile) {
        $cacheTime = (Get-Item $cacheFile).LastWriteTime
        $binTime   = (Get-Item $cmd.Source).LastWriteTime
        if ($cacheTime -gt $binTime) { $regen = $false }
    }
    if ($regen) {
        & $Command @InitArgs | Set-Content -Path $cacheFile -Encoding utf8
    }
    . $cacheFile
}

# --- PowerShell modules from PSGallery (see packages/psgallery.json) ----

if (Get-Module -ListAvailable -Name posh-git)        { Import-Module posh-git }
if (Get-Module -ListAvailable -Name Terminal-Icons)  { Import-Module Terminal-Icons }

# --- Native tool integrations (cached) ----------------------------------

Use-CachedToolInit -Name 'starship' -Command 'starship' -InitArgs @('init','powershell')
Use-CachedToolInit -Name 'zoxide'   -Command 'zoxide'   -InitArgs @('init','powershell')
Use-CachedToolInit -Name 'atuin'    -Command 'atuin'    -InitArgs @('init','powershell')

# mise activate pwsh installs a CommandNotFound hook that calls
# [PSConsoleReadLine]::GetHistoryItems() inside its handler. When the
# hook fires during profile parse — before PSReadLine's input loop
# has primed its singleton state — the call NREs internally (not the
# [-1] indexer; the method itself throws), producing several errors
# per session. The hook block is gated by
# `if (-not $__mise_pwsh_command_not_found)`, so pre-setting that
# variable to $true skips the entire block — no event handler is
# registered, no NREs. The gate is checked at execution time, so it
# works just as well against the cached script as the live output.
# Cost: lose mise's install-on-not-found feature (typing a tool name
# that mise.toml declares but isn't installed yet won't auto-install).
# Drop this when mise fixes the hook upstream.
$Global:__mise_pwsh_command_not_found = $true
Use-CachedToolInit -Name 'mise' -Command 'mise' -InitArgs @('activate','pwsh')

# fzf PSReadLine integration. Loaded after 10-keybindings.ps1 so PSFzf can
# override Ctrl+R with its fuzzy-history picker.
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# --- ssh-agent: start the Windows service if it's installed but stopped ---

$sshAgent = Get-Service ssh-agent -ErrorAction SilentlyContinue
if ($sshAgent -and $sshAgent.Status -ne 'Running') {
    Start-Service ssh-agent -ErrorAction SilentlyContinue
}

# --- Native completions --------------------------------------------------

Use-CachedToolInit -Name 'gh-completion' -Command 'gh' -InitArgs @('completion','-s','powershell')

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Utf8Encoding]::new()
        $word = $wordToComplete.Replace('"', '""')
        $ast  = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$word" --commandline "$ast" --position $cursorPosition |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
    }
}
