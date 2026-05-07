# 40-git: oh-my-zsh-style git shortcuts. `g` itself lives in 30-aliases.ps1.
# Names mirror the oh-my-zsh `git` plugin.

function gs    { git status --short --branch @args }
function ga    { git add @args }
function gaa   { git add --all @args }
function gc    { git commit @args }
function gcm   { git commit -m @args }
function gco   { git checkout @args }
function gcb   { git checkout -b @args }
function gd    { git diff @args }
function gds   { git diff --staged @args }
function gl    { git log --oneline --graph --decorate -20 @args }
function gla   { git log --oneline --graph --decorate --all @args }
function gp    { git push @args }
function gpu   { git pull @args }
function gst   { git stash @args }
function gstp  { git stash pop @args }
function gb    { git branch @args }
function gf    { git fetch --all --prune @args }
