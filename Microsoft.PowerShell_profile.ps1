# Canonical PowerShell profile for windots.
# Symlinked into $PROFILE by bootstrap.ps1 — edits here apply live.
#
# Mirrors the modular shape of dotfiles' ~/.config/zsh/: each profile.d
# module owns one concern. Keep this entry-point minimal.

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning 'windots profile targets PowerShell 7+. Skipping.'
    return
}

$WindotsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Resolve through the symlink so $WindotsRoot points at the repo,
# not at $PROFILE's directory.
$resolvedProfile = (Get-Item $MyInvocation.MyCommand.Path).Target
if ($resolvedProfile) {
    $WindotsRoot = Split-Path -Parent $resolvedProfile
}

$profileD = Join-Path $WindotsRoot 'profile.d'
if (Test-Path $profileD) {
    Get-ChildItem -Path $profileD -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

# Optional machine-local override, ignored by git.
$localProfile = Join-Path $WindotsRoot 'local.ps1'
if (Test-Path $localProfile) {
    . $localProfile
}
