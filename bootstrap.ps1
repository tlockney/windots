# bootstrap.ps1 — set up a Windows machine to use windots + dotfiles.
#
# Idempotent: safe to re-run after a config change, after adding packages,
# or after editing this script. Every step checks current state first.
#
# Usage:
#   .\bootstrap.ps1                     # full run
#   .\bootstrap.ps1 -SkipPackages       # configs + symlinks only
#   .\bootstrap.ps1 -SkipScoop          # winget + symlinks + psgallery
#   .\bootstrap.ps1 -SkipWinget         # scoop  + symlinks + psgallery
#   .\bootstrap.ps1 -SkipPSGallery      # scoop  + winget   + symlinks
#   .\bootstrap.ps1 -SkipSymlinks       # packages only
#
# Override the dotfiles location with $env:DOTFILES_HOME before running.

[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$SkipScoop,
    [switch]$SkipWinget,
    [switch]$SkipPSGallery,
    [switch]$SkipSymlinks
)

$ErrorActionPreference = 'Stop'
$WindotsRoot = $PSScriptRoot

# ---------- helpers ----------------------------------------------------------

function Write-Step  { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "    $m" -ForegroundColor Green }
function Write-Skip  { param($m) Write-Host "    $m" -ForegroundColor DarkGray }
function Write-Warn2 { param($m) Write-Host "    $m" -ForegroundColor Yellow }

function Fail {
    param($Message, $Hint)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    if ($Hint) { Write-Host "  $Hint" -ForegroundColor Yellow }
    exit 1
}

# ---------- preflight --------------------------------------------------------

function Test-DeveloperMode {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    if (-not (Test-Path $key)) { return $false }
    $val = (Get-ItemProperty -Path $key -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    return ($val -eq 1)
}

Write-Step 'Checking Developer Mode'
if (-not (Test-DeveloperMode)) {
    Fail 'Developer Mode is not enabled.' `
         'Enable it: Settings -> System -> For developers -> Developer Mode (or run: start ms-settings:developers). Then re-run bootstrap.'
}
Write-Ok 'Developer Mode is on (non-elevated symlinks allowed).'

Write-Step 'Resolving dotfiles location'
$dotfilesHome = $env:DOTFILES_HOME
if (-not $dotfilesHome) {
    $dotfilesHome = Join-Path $HOME 'src\personal\dotfiles'
}
if (-not (Test-Path $dotfilesHome)) {
    Fail "dotfiles repo not found at: $dotfilesHome" `
         'Clone tlockney/dotfiles to that path, or set $env:DOTFILES_HOME to wherever you keep it, then re-run.'
}
Write-Ok "Using dotfiles at: $dotfilesHome"

# ---------- packages ---------------------------------------------------------

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Skip 'scoop already installed'
        return
    }
    Write-Step 'Installing scoop'
    Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
}

# scoop needs 7zip to extract most package archives, but it isn't present on a
# fresh install. Scoop will auto-install it on demand, but that behavior is
# config-dependent and has bitten us, so install it up front from the main
# bucket. 7zip ships as a plain zip that scoop extracts with .NET's built-in
# support, so there's no chicken-and-egg. (git, scoop's other helper, is
# already a prerequisite — you need it to clone this repo in the first place.)
$ScoopCoreDeps = @('7zip')

function Install-ScoopApp {
    param($App, $Installed)
    $name = ($App -split '/')[-1]
    if ($Installed -and ($Installed -contains $name)) {
        Write-Skip "$name already installed"
    } else {
        scoop install $App
    }
}

function Sync-ScoopPackages {
    $manifestPath = Join-Path $WindotsRoot 'packages\scoop.json'
    if (-not (Test-Path $manifestPath)) {
        Write-Warn2 "No scoop manifest at $manifestPath — skipping"
        return
    }
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    Write-Step 'Installing scoop core dependencies (7zip)'
    $installed = (scoop list 2>$null | ForEach-Object { $_.Name }) -as [string[]]
    foreach ($app in $ScoopCoreDeps) {
        Install-ScoopApp -App $app -Installed $installed
    }

    Write-Step 'Adding scoop buckets'
    $existingBuckets = (scoop bucket list 2>$null | ForEach-Object { $_.Name }) -as [string[]]
    foreach ($bucket in $manifest.buckets) {
        if ($existingBuckets -and ($existingBuckets -contains $bucket)) {
            Write-Skip "bucket '$bucket' already added"
        } else {
            scoop bucket add $bucket
        }
    }

    Write-Step 'Installing scoop apps'
    $installed = (scoop list 2>$null | ForEach-Object { $_.Name }) -as [string[]]
    foreach ($app in $manifest.apps) {
        Install-ScoopApp -App $app -Installed $installed
    }
}

function Sync-PSGalleryModules {
    $manifestPath = Join-Path $WindotsRoot 'packages\psgallery.json'
    if (-not (Test-Path $manifestPath)) {
        Write-Warn2 "No psgallery manifest at $manifestPath — skipping"
        return
    }
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    Write-Step 'Installing PowerShell modules from PSGallery'
    foreach ($name in $manifest.modules) {
        if (Get-Module -ListAvailable -Name $name) {
            Write-Skip "$name already installed"
        } else {
            Install-Module -Name $name -Scope CurrentUser -Force -AcceptLicense
            Write-Ok "installed: $name"
        }
    }
}

function Sync-WingetPackages {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn2 'winget not found — skipping (install App Installer from the Store)'
        return
    }
    $manifestPath = Join-Path $WindotsRoot 'packages\winget.json'
    if (-not (Test-Path $manifestPath)) {
        Write-Warn2 "No winget manifest at $manifestPath — skipping"
        return
    }
    Write-Step 'Importing winget packages'
    # --accept-* avoids interactive prompts; --ignore-unavailable lets us
    # share one manifest across machines that don't all have every app.
    winget import --import-file $manifestPath --accept-package-agreements --accept-source-agreements --ignore-unavailable --no-upgrade
}

if ($SkipPackages) {
    Write-Skip 'Skipping all package installs (-SkipPackages)'
} else {
    if ($SkipScoop)     { Write-Skip 'Skipping scoop (-SkipScoop)' }         else { Install-Scoop; Sync-ScoopPackages }
    if ($SkipWinget)    { Write-Skip 'Skipping winget (-SkipWinget)' }       else { Sync-WingetPackages }
    if ($SkipPSGallery) { Write-Skip 'Skipping PSGallery (-SkipPSGallery)' } else { Sync-PSGalleryModules }
}

# ---------- symlinks ---------------------------------------------------------

# (source-relative-to-dotfiles, target-absolute-path) pairs.
$symlinkPlan = @(
    @{ Source = '.tmux.conf';            Target = (Join-Path $HOME '.tmux.conf') },
    @{ Source = '.config\starship.toml'; Target = (Join-Path $env:USERPROFILE '.config\starship.toml') },
    @{ Source = '.config\bat';           Target = (Join-Path $env:USERPROFILE '.config\bat') },
    @{ Source = '.config\lazygit';       Target = (Join-Path $env:USERPROFILE '.config\lazygit') },
    @{ Source = '.config\mise';          Target = (Join-Path $env:USERPROFILE '.config\mise') }
)

function New-ConfigSymlink {
    param($SourcePath, $TargetPath)

    if (-not (Test-Path $SourcePath)) {
        Write-Warn2 "source missing, skipped: $SourcePath"
        return
    }

    $parent = Split-Path -Parent $TargetPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path $TargetPath) {
        $existing = Get-Item $TargetPath -Force
        if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $SourcePath) {
            Write-Skip "already linked: $TargetPath"
            return
        }
        # Refuse to clobber a real file/dir — surface it for the user to handle.
        $existingKind = if ($existing.LinkType) { $existing.LinkType } else { 'file/dir' }
        Fail "Target exists and isn't our symlink: $TargetPath" `
             "Move/remove it, then re-run. (Existing: $existingKind)"
    }

    New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath | Out-Null
    Write-Ok "linked: $TargetPath -> $SourcePath"
}

function Link-TerminalSettings {
    # Windows Terminal is a special case: its settings.json lives under a
    # package-hashed path (not .config / $HOME), and WT *auto-generates* a
    # default settings.json on first launch. So unlike New-ConfigSymlink, we
    # adopt an existing real file (back it up) rather than refusing to clobber.
    $source = Join-Path $WindotsRoot 'terminal\settings.json'
    if (-not (Test-Path $source)) {
        Write-Warn2 "source missing, skipped: $source"
        return
    }

    # Stable (Store) edition. LocalState exists whenever WT is installed.
    $localState = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
    if (-not (Test-Path $localState)) {
        Write-Skip 'Windows Terminal (stable) not installed — skipping settings link'
        return
    }
    $target = Join-Path $localState 'settings.json'

    if (Test-Path $target) {
        $existing = Get-Item $target -Force
        if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $source) {
            Write-Skip "already linked: $target"
            return
        }
        if ($existing.LinkType -eq 'SymbolicLink') {
            # Stale link pointing elsewhere — replace it.
            Remove-Item $target -Force
        } else {
            # Real file (WT default or hand-edited). Back it up, then adopt.
            $backup = "$target.bootstrap-bak"
            if (Test-Path $backup) { Remove-Item $backup -Force }
            Move-Item $target $backup
            Write-Warn2 "backed up existing settings.json -> $backup"
        }
    }

    New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
    Write-Ok "linked: $target -> $source"
}

function Link-PowerShellProfile {
    # $PROFILE is the one target that lives under Documents, which on managed
    # machines is usually redirected into OneDrive. OneDrive's filesystem filter
    # rejects reparse points, so New-Item -SymbolicLink fails there with
    # "Symbolic links are not supported for the specified path". Try the symlink
    # first (keeps parity with the other links where it works); if it's not
    # supported, fall back to a dot-source stub — a real file that loads the
    # canonical profile from this repo, so edits there still flow live.
    $source = Join-Path $WindotsRoot 'Microsoft.PowerShell_profile.ps1'
    if (-not (Test-Path $source)) {
        Write-Warn2 "source missing, skipped: $source"
        return
    }

    $target = $PROFILE
    $parent = Split-Path -Parent $target
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    # Marker on the stub's first line so we can recognize our own stub on re-runs.
    $stubMarker = '# windots-profile-stub'
    $stubBody = @(
        $stubMarker
        '# Loads the canonical profile from the windots repo. Written instead of a'
        "# symlink because this path doesn't support them (e.g. OneDrive-redirected"
        '# Documents). Edits to the repo profile still apply in every new shell.'
        ". `"$source`""
    ) -join "`r`n"

    if (Test-Path $target) {
        $existing = Get-Item $target -Force
        if ($existing.LinkType -eq 'SymbolicLink' -and $existing.Target -eq $source) {
            Write-Skip "already linked: $target"
            return
        }
        $content = Get-Content $target -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Contains($stubMarker) -and $content.Contains($source)) {
            Write-Skip "already stubbed: $target"
            return
        }
        if ($existing.LinkType -eq 'SymbolicLink') {
            Remove-Item $target -Force   # stale link pointing elsewhere — replace it
        } else {
            # Real file (a previous profile). Back it up, then adopt the path.
            $backup = "$target.bootstrap-bak"
            if (Test-Path $backup) { Remove-Item $backup -Force }
            Move-Item $target $backup
            Write-Warn2 "backed up existing profile -> $backup"
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $target -Target $source -ErrorAction Stop | Out-Null
        Write-Ok "linked: $target -> $source"
    } catch {
        # Symlinks unsupported on this path (OneDrive et al.) — use a stub instead.
        Set-Content -Path $target -Value $stubBody -Encoding UTF8
        Write-Ok "wrote dot-source stub (symlink unsupported here): $target"
        Write-Skip $_.Exception.Message
    }
}

if ($SkipSymlinks) {
    Write-Skip 'Skipping symlink creation (-SkipSymlinks)'
} else {
    Write-Step 'Creating config symlinks'
    foreach ($entry in $symlinkPlan) {
        $src = Join-Path $dotfilesHome $entry.Source
        New-ConfigSymlink -SourcePath $src -TargetPath $entry.Target
    }

    Write-Step 'Linking Windows Terminal settings'
    Link-TerminalSettings

    Write-Step 'Linking PowerShell profile'
    # $PROFILE points at the current host's profile path. We want our canonical
    # profile to be the one PowerShell loads on startup — via symlink, or a
    # dot-source stub where symlinks aren't supported (e.g. OneDrive).
    Link-PowerShellProfile
}

Write-Host ""
Write-Host "Done. Restart pwsh (or run '. `$PROFILE') to pick up the new profile." -ForegroundColor Green
