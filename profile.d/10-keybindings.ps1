# 10-keybindings: PSReadLine config that makes editing feel like bash/zsh.
# All Set-PSReadLine* calls live here so the keymap is one file to read.

if (-not (Get-Module -ListAvailable -Name PSReadLine)) {
    return
}

# Emacs keybindings: Ctrl-A/E/K/W/U etc. behave like bash.
Set-PSReadLineOption -EditMode Emacs

# Fish/zsh-style inline autosuggestion from history.
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -Colors @{ InlinePrediction = [ConsoleColor]::DarkGray }

# History tuning.
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -MaximumHistoryCount 10000

# Up/Down filter history by what's already typed (zsh-style).
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Ctrl-R reverse search. NOTE: PSFzf in 20-tools.ps1 rebinds this to fzf
# history if PSFzf is installed — that's intentional, fzf wins when present.
Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory

# Tab → menu-complete (zsh-style).
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Ctrl-D exits the shell when the line is empty (bash-style).
Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

# Ctrl-L clears the screen.
Set-PSReadLineKeyHandler -Key Ctrl+l -Function ClearScreen
