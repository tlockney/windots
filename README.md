# windots

Native Windows companion to [`dotfiles`](../dotfiles). Brings the
parts of that environment that have native Windows builds (psmux,
starship, bat, lazygit, mise, ripgrep, fd, zoxide, atuin, fzf, eza,
Neovim) into a PowerShell-shaped setup, sharing the *configs* with
`dotfiles` so a single edit applies on both sides.

`dotfiles` remains macOS/Linux-only. This repo handles the Windows
side and reads portable configs out of `dotfiles` via symlinks.

## Layout

```
windots/
├── bootstrap.ps1                       # one-shot installer
├── Microsoft.PowerShell_profile.ps1    # canonical PS profile (linked into $PROFILE)
├── profile.d/                          # numeric prefixes lock load order
│   ├── 00-init.ps1                     # XDG_CONFIG_HOME, TMUX_PLATFORM, EDITOR
│   ├── 10-keybindings.ps1              # PSReadLine: bash/zsh-style editing
│   ├── 20-tools.ps1                    # starship/zoxide/atuin/mise/PSFzf, ssh-agent, completions
│   ├── 30-aliases.ps1                  # ls/cat/grep/find/.. unix-shaped aliases
│   ├── 40-git.ps1                      # oh-my-zsh-style git shortcuts
│   ├── 50-docker.ps1                   # docker / docker compose shortcuts
│   └── 60-util.ps1                     # serve, open, e, duh, myip, killall, extract
└── packages/
    ├── scoop.json                      # CLI toolbox (scoop)
    ├── winget.json                     # GUI apps (winget import format)
    └── psgallery.json                  # PowerShell modules (Install-Module from PSGallery)
```

## How config sharing works

`bootstrap.ps1` resolves `$env:DOTFILES_HOME` (default
`$HOME\src\personal\dotfiles`) and creates Windows symlinks from
that checkout into the locations Windows tools expect:

| Source (in dotfiles)               | Symlink target                                    |
|------------------------------------|---------------------------------------------------|
| `.tmux.conf`                       | `$HOME\.tmux.conf` (psmux)                        |
| `.config/starship.toml`            | `$env:USERPROFILE\.config\starship.toml`          |
| `.config/bat/`                     | `$env:USERPROFILE\.config\bat`                    |
| `.config/lazygit/`                 | `$env:USERPROFILE\.config\lazygit`                |
| `.config/mise/`                    | `$env:USERPROFILE\.config\mise`                   |

`init.ps1` sets `XDG_CONFIG_HOME=$env:USERPROFILE\.config` so
XDG-aware tools look in the same relative paths as Linux.

## Prerequisites

1. **Developer Mode enabled.** Required for non-elevated symlink
   creation. Settings → System → For developers → Developer Mode.
   `bootstrap.ps1` checks for this and stops with a clear error if
   it's off.
2. **PowerShell 7 (`pwsh`).** Install via winget if needed:
   `winget install Microsoft.PowerShell`.
3. **`dotfiles` cloned somewhere.** Default expected location is
   `$HOME\src\personal\dotfiles`. Override with
   `$env:DOTFILES_HOME` before running bootstrap.

## Install

```powershell
git clone https://github.com/tlockney/windots.git $HOME\src\personal\windots
cd $HOME\src\personal\windots
.\bootstrap.ps1
```

The bootstrap will:

1. Verify Developer Mode is on.
2. Verify `$DOTFILES_HOME` exists.
3. Install scoop if missing, add `extras` and `nerd-fonts` buckets,
   install everything in `packages/scoop.json`.
4. Run `winget import packages/winget.json` for GUI apps.
5. `Install-Module` everything in `packages/psgallery.json` (PSReadLine,
   PSFzf, posh-git, Terminal-Icons) from PSGallery, scoped to the
   current user.
6. Create the config symlinks listed above.
7. Symlink `$PROFILE` to `Microsoft.PowerShell_profile.ps1` in this
   repo so profile edits flow live.

Run it again any time — every step is idempotent.

## Editing configs

The portable configs live in `dotfiles`, **not here**. Edit them
there, on `working-branch`, following the dotfiles staging
workflow. Symlinks mean Windows picks up changes immediately —
no re-sync needed.

Windows-specific things (PowerShell profile, package lists,
PowerShell-only aliases) live here.

## tmux on Windows

`dotfiles/.tmux.conf` has three `%if "#{==:#{TMUX_PLATFORM},windows}"`
guards that swap the default shell to `pwsh` and the popup terminal
to `pwsh`. The profile sets `$env:TMUX_PLATFORM = "windows"` so
those guards activate.

## Things deliberately not ported

- **zsh modules and `.zshrc`** — PowerShell has its own profile
  shape; mirroring zsh module-for-module would be more confusing
  than helpful.
- **Ansible `provision` / `bin/`** — the bash scripts assume POSIX
  tools and a Unix layout. PowerShell ports aren't worth
  maintaining unless one specifically becomes load-bearing.
- **`.macos`** — obviously.
- **Hammerspoon, Alfred, WezTerm config** — Mac-specific or have
  separate Windows equivalents (PowerToys, Windows Terminal).
