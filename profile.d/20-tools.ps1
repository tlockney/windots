# 20-tools: shell integrations for tools installed by bootstrap.
# Each block guards with Get-Command (or Get-Module) so a partial install
# doesn't break the whole profile.

# --- PowerShell modules from PSGallery (see packages/psgallery.json) -------

if (Get-Module -ListAvailable -Name posh-git)        { Import-Module posh-git }
if (Get-Module -ListAvailable -Name Terminal-Icons)  { Import-Module Terminal-Icons }

# --- Native tool integrations --------------------------------------------

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

if (Get-Command atuin -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (atuin init powershell | Out-String) })
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (mise activate pwsh | Out-String) })
}

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

if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh completion -s powershell | Out-String | Invoke-Expression
}

if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl completion powershell | Out-String | Invoke-Expression
}

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
