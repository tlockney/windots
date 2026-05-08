# 70-tmux: helpers for working with psmux. Currently just `tc`, ported
# from dotfiles/bin/tc. Kept in its own file so this is the obvious spot
# to drop additional psmux helpers later.

function tc {
    <#
    .SYNOPSIS
        Create or attach to a psmux session.

    .DESCRIPTION
        Defaults the session name to the current directory's leaf name. If
        already inside a tmux session and the requested session is different,
        prompts before switching. Outside tmux, attaches if the session exists
        and creates it otherwise.

    .PARAMETER SessionName
        Name of the session to create/attach to. Defaults to the current
        directory's leaf name. Dots and colons are replaced with `-` because
        tmux disallows them in session names.

    .EXAMPLE
        PS> tc
        Create or attach to a session named after $PWD.

    .EXAMPLE
        PS> tc work
        Create or attach to a session named 'work'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $SessionName
    )

    if (-not (Get-Command psmux -ErrorAction SilentlyContinue)) {
        Write-Host "Error: psmux not found (install: scoop install psmux)" -ForegroundColor Red
        return
    }

    if (-not $SessionName) {
        $SessionName = Split-Path -Leaf (Get-Location).Path
    }
    # tmux disallows '.' and ':' in session names.
    $SessionName = $SessionName -replace '[.:]', '-'
    $cwd = (Get-Location).Path

    # Already inside a tmux session — handle switch instead of attach.
    if ($env:TMUX) {
        $currentSession = (psmux display-message -p '#S').Trim()
        if ($currentSession -eq $SessionName) {
            Write-Host "Already in session '$SessionName'." -ForegroundColor Cyan
            return
        }
        $answer = Read-Host "Switch from session '$currentSession' to '$SessionName'? [y/N]"
        if ($answer -notmatch '^[Yy]$') {
            Write-Host "Staying in session '$currentSession'." -ForegroundColor Cyan
            return
        }
        psmux has-session -t $SessionName 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Creating session '$SessionName'..." -ForegroundColor Cyan
            psmux new-session -d -s $SessionName -c $cwd
        }
        Write-Host "Switching to session '$SessionName'..." -ForegroundColor Cyan
        psmux switch-client -t $SessionName
        return
    }

    # Outside tmux: attach or create.
    psmux has-session -t $SessionName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Attaching to session '$SessionName'..." -ForegroundColor Cyan
        psmux attach-session -t $SessionName
    } else {
        Write-Host "Creating session '$SessionName'..." -ForegroundColor Cyan
        psmux new-session -s $SessionName -c $cwd
    }
}
