# 60-util: misc unix-shaped helpers that don't fit anywhere else.

# Quick HTTP server (mirrors `python -m http.server`).
function serve {
    param([int]$Port = 8000)
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Error "serve: python not found on PATH"; return
    }
    Write-Host "Serving current directory on http://localhost:$Port — Ctrl-C to stop"
    python -m http.server $Port
}

# Open a path with its default associated application (mac `open` analogue).
function open { param([string]$Path = '.') Start-Process $Path }

# Edit with whatever 00-init.ps1 picked as $env:EDITOR.
function e { param([string]$Path = '.') & $env:EDITOR $Path }

# du -sh * for the current directory.
function duh {
    Get-ChildItem -Directory | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{
            Size = if     ($size -gt 1GB) { "{0:N1} GB" -f ($size / 1GB) }
                   elseif ($size -gt 1MB) { "{0:N1} MB" -f ($size / 1MB) }
                   elseif ($size -gt 1KB) { "{0:N1} KB" -f ($size / 1KB) }
                   else                   { "$size B" }
            Name = $_.Name
        }
    } | Format-Table -AutoSize
}

function myip { (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json').ip }

# Mac-style killall: kill every process whose name matches.
function killall {
    param([string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

function extract {
    param([string]$Path)
    if (-not (Test-Path $Path)) { Write-Error "File not found: $Path"; return }
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    switch ($ext) {
        '.zip' { Expand-Archive -Path $Path -DestinationPath (Split-Path $Path) -Force }
        '.gz'  { tar -xzf $Path }
        '.tar' { tar -xf $Path }
        '.tgz' { tar -xzf $Path }
        '.bz2' { tar -xjf $Path }
        default { Write-Error "Unknown archive format: $ext" }
    }
}
