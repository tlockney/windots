# 50-docker: shortcuts for Docker / docker compose. Whole file is a no-op
# when docker isn't installed.

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    return
}

function d      { docker @args }
function dc     { docker compose @args }
function dps    { docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" @args }
function dimg   { docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" @args }
function dex    { param([string]$Container) docker exec -it $Container /bin/sh }
function dlogs  { param([string]$Container) docker logs -f $Container }
function dprune { docker system prune -af --volumes }
