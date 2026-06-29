#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instala WireGuard en Windows, importa configuración y verifica conectividad.
.PARAMETER ConfigPath
    Ruta al archivo .conf del cliente.
.PARAMETER Connect
    Activar túnel tras importar.
.PARAMETER TestConnection
    Verificar IP pública tras conectar.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,
    [switch]$Connect,
    [switch]$TestConnection
)

$ErrorActionPreference = "Stop"
$WireGuardUrl = "https://download.wireguard.com/windows-client/wireguard-installer.exe"
$WireGuardExe = "${env:ProgramFiles}\WireGuard\wireguard.exe"
$TunnelName = [IO.Path]::GetFileNameWithoutExtension($ConfigPath)

function Write-Log($Msg, $Level = "INFO") {
    $c = @{ INFO = "Green"; WARN = "Yellow"; ERROR = "Red" }[$Level]
    Write-Host "[$Level] $Msg" -ForegroundColor $c
}

function Install-WireGuardClient {
    if (Test-Path $WireGuardExe) { return }
    Write-Log "Instalando WireGuard..."
    $tmp = Join-Path $env:TEMP "wireguard-installer.exe"
    Invoke-WebRequest -Uri $WireGuardUrl -OutFile $tmp -UseBasicParsing
    Start-Process $tmp -ArgumentList "/quiet" -Wait
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $WireGuardExe)) { Write-Log "Instalación fallida" "ERROR"; exit 1 }
    Write-Log "WireGuard instalado"
}

function Import-Config {
    if (-not (Test-Path $ConfigPath)) { Write-Log "No encontrado: $ConfigPath" "ERROR"; exit 1 }
    $dir = "$env:USERPROFILE\WireGuard"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
    $dest = Join-Path $dir "$TunnelName.conf"
    Copy-Item $ConfigPath $dest -Force
    Write-Log "Config importada: $dest"
    return $dest
}

function Start-Tunnel {
    $conf = Join-Path "$env:USERPROFILE\WireGuard" "$TunnelName.conf"
    & $WireGuardExe /installtunnelservice $conf
    Start-Sleep -Seconds 3
    Write-Log "Túnel '$TunnelName' activado"
}

function Test-VpnConnection {
    try {
        $ip = (Invoke-WebRequest -Uri "https://ifconfig.me" -UseBasicParsing -TimeoutSec 10).Content.Trim()
        Write-Log "IP pública detectada: $ip"
    } catch {
        Write-Log "No se pudo verificar IP (¿túnel activo?)" "WARN"
    }
}

Write-Log "=== VP´N Cliente Windows ==="
Install-WireGuardClient
Import-Config | Out-Null
if ($Connect) { Start-Tunnel }
if ($TestConnection) { Test-VpnConnection }
if (-not $Connect) {
    Write-Log "Activa '$TunnelName' desde WireGuard o usa -Connect"
}
Write-Log "Completado"
