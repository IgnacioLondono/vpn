#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Agente VP´N para Windows — conecta/desconecta según el panel web.
.DESCRIPTION
    Solo el PC con la VPN encendida desde el panel enruta tráfico.
    Consulta el servidor cada pocos segundos y aplica la configuración.
.PARAMETER ServerUrl
    URL del portal (ej: https://vpn.tudominio.com)
.PARAMETER AgentToken
    Token del dispositivo (se guarda en registro)
.PARAMETER Install
    Instalar como tarea programada
.EXAMPLE
    .\vpn-agent.ps1 -ServerUrl "https://vpn.ejemplo.com" -AgentToken "uuid-aqui"
    .\vpn-agent.ps1 -Install -ServerUrl "https://vpn.ejemplo.com" -AgentToken "uuid"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ServerUrl,
    [string]$AgentToken,
    [switch]$Install,
    [int]$IntervalSeconds = 5
)

$ErrorActionPreference = "Stop"
$ConfigDir = "$env:USERPROFILE\WireGuard"
$StateFile = "$ConfigDir\vpn-agent-state.json"
$WireGuardExe = "${env:ProgramFiles}\WireGuard\wireguard.exe"
$TunnelName = "VPN-Portal"

function Write-Log($Msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $Msg" -ForegroundColor Cyan
}

function Get-State {
    if (Test-Path $StateFile) {
        return Get-Content $StateFile -Raw | ConvertFrom-Json
    }
    return @{ connected = $false; lastConfig = "" }
}

function Set-State($State) {
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory $ConfigDir | Out-Null }
    $State | ConvertTo-Json | Set-Content $StateFile
}

function Ensure-WireGuard {
    if (Test-Path $WireGuardExe) { return }
    Write-Log "Instalando WireGuard..."
    $url = "https://download.wireguard.com/windows-client/wireguard-installer.exe"
    $tmp = "$env:TEMP\wg-install.exe"
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    Start-Process $tmp -ArgumentList "/quiet" -Wait
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

function Get-AgentStatus {
    $headers = @{ "X-Agent-Token" = $AgentToken }
    $uri = "$ServerUrl/api/agent/status"
    return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
}

function Connect-Tunnel($ConfigContent) {
    $confPath = Join-Path $ConfigDir "$TunnelName.conf"
    Set-Content -Path $confPath -Value $ConfigContent -Encoding UTF8

    # Detener túnel previo si existe
    & $WireGuardExe /uninstalltunnelservice $TunnelName 2>$null
    Start-Sleep -Seconds 1
    & $WireGuardExe /installtunnelservice $confPath
    Start-Sleep -Seconds 2
    Write-Log "VPN CONECTADA — tráfico enrutado por VP´N"
}

function Disconnect-Tunnel {
    & $WireGuardExe /uninstalltunnelservice $TunnelName 2>$null
    Start-Sleep -Seconds 1
    Write-Log "VPN DESCONECTADA — sin efecto en este PC"
}

function Start-AgentLoop {
    if (-not $AgentToken) {
        $AgentToken = Read-Host "Agent Token (del panel web)"
    }

    Ensure-WireGuard
    Write-Log "Agente iniciado → $ServerUrl"
    Write-Log "Intervalo: ${IntervalSeconds}s"

    $state = Get-State

    while ($true) {
        try {
            $status = Get-AgentStatus
            $config = $status.config

            if ($status.shouldConnect) {
                if (-not $state.connected -or $state.lastConfig -ne $config) {
                    Connect-Tunnel $config
                    $state.connected = $true
                    $state.lastConfig = $config
                    Set-State $state
                }
            } else {
                if ($state.connected) {
                    Disconnect-Tunnel
                    $state.connected = $false
                    $state.lastConfig = ""
                    Set-State $state
                }
            }
        } catch {
            Write-Log "Error: $($_.Exception.Message)" 
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
}

function Install-ScheduledTask {
    if (-not $AgentToken) { throw "AgentToken requerido para instalar" }
    $scriptPath = $MyInvocation.MyCommand.Path
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ServerUrl `"$ServerUrl`" -AgentToken `"$AgentToken`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName "VPN-Portal-Agent" -Action $action -Trigger $trigger -Settings $settings -Force
    Write-Log "Tarea programada 'VPN-Portal-Agent' instalada (inicio al logon)"
}

if ($Install) {
    Install-ScheduledTask
} else {
    Start-AgentLoop
}
