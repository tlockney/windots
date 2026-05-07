# 10-tools: shell integrations for tools installed by bootstrap.
# Each block guards with Get-Command so a partial install doesn't break the
# whole profile.

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

# fzf PSReadLine integration if PSFzf is present.
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
