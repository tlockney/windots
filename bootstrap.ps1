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

function Sync-ScoopPackages {
    $manifestPath = Join-Path $WindotsRoot 'packages\scoop.json'
    if (-not (Test-Path $manifestPath)) {
        Write-Warn2 "No scoop manifest at $manifestPath — skipping"
        return
    }
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

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
        $name = ($app -split '/')[-1]
        if ($installed -and ($installed -contains $name)) {
            Write-Skip "$name already installed"
        } else {
            scoop install $app
        }
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
        Fail "Target exists and isn't our symlink: $TargetPath" `
             "Move/remove it, then re-run. (Existing: $($existing.LinkType ?? 'file/dir'))"
    }

    New-Item -ItemType SymbolicLink -Path $TargetPath -Target $SourcePath | Out-Null
    Write-Ok "linked: $TargetPath -> $SourcePath"
}

if ($SkipSymlinks) {
    Write-Skip 'Skipping symlink creation (-SkipSymlinks)'
} else {
    Write-Step 'Creating config symlinks'
    foreach ($entry in $symlinkPlan) {
        $src = Join-Path $dotfilesHome $entry.Source
        New-ConfigSymlink -SourcePath $src -TargetPath $entry.Target
    }

    Write-Step 'Linking PowerShell profile'
    # $PROFILE points at the current host's profile path. We want our canonical
    # profile to be the one PowerShell loads on startup.
    $profileSource = Join-Path $WindotsRoot 'Microsoft.PowerShell_profile.ps1'
    New-ConfigSymlink -SourcePath $profileSource -TargetPath $PROFILE
}

Write-Host ""
Write-Host "Done. Restart pwsh (or run '. `$PROFILE') to pick up the new profile." -ForegroundColor Green
