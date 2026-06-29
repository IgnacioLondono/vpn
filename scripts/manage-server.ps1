#Requires -RunAsAdministrator
<#
.SYNOPSIS
    CLI de gestión VP´N para Windows.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("init", "start", "stop", "restart", "status", "logs", "build", "health")]
    [string]$Action
)

$ProjectDir = Split-Path $PSScriptRoot -Parent

function Write-Status($Msg, $Color = "Green") { Write-Host "[VPN] $Msg" -ForegroundColor $Color }

Push-Location $ProjectDir
try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Status "Docker Desktop no disponible" "Red"; exit 1
    }

    switch ($Action) {
        "init" {
            if (-not (Test-Path ".env")) { Copy-Item ".env.example" ".env" }
            $jwt = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
            (Get-Content .env) -replace '^JWT_SECRET=$', "JWT_SECRET=$jwt" | Set-Content .env
            Write-Status ".env creado. Edita ADMIN_PASSWORD y WG_HOST"
        }
        "build" { docker compose build }
        "start" {
            New-Item -ItemType Directory -Force -Path "data/wireguard", "data/portal", "backups" | Out-Null
            docker compose up -d --build
            docker compose ps
        }
        "stop"    { docker compose --profile ssl --profile watchtower down }
        "restart" { docker compose restart; docker compose ps }
        "status"  { docker compose ps -a }
        "logs"    { docker compose logs -f --tail=100 vpn-portal }
        "health"  { Invoke-RestMethod "http://localhost:8443/api/health" }
    }
} finally { Pop-Location }
