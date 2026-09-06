param(
    [ValidateSet('node1','node2','node3','all')]
    [string]$Node = 'all',
    [switch]$Stop,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'

$DataDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerScript = Join-Path $DataDir 'server.js'
$NodePorts = @{ node1 = 3001; node2 = 3002; node3 = 3003 }

function Get-ListenerPid($port) {
    $procId = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty OwningProcess
    return $procId
}

function Start-NodeServer($name) {
    $port = $NodePorts[$name]
    $existing = Get-ListenerPid $port
    if ($existing) {
        Write-Host "[$name] port $port already listening (PID $existing) - skipped" -ForegroundColor Yellow
        return
    }
    $logDir = Join-Path $DataDir 'logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $env:PORT = [string]$port
    Write-Host "Starting $name on port $port..." -ForegroundColor Green
    Start-Process -FilePath 'node' -ArgumentList "`"$ServerScript`"" `
        -WorkingDirectory $DataDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logDir "$name-out.log") `
        -RedirectStandardError  (Join-Path $logDir "$name-err.log")
    Start-Sleep -Milliseconds 800
    $procId = Get-ListenerPid $port
    if ($procId) { Write-Host "  OK -> listening (PID $procId)" -ForegroundColor DarkGreen }
    else { Write-Host "  WARNING: not yet listening, check logs\$name-err.log" -ForegroundColor Red }
}

function Stop-NodeServer($name) {
    $port = $NodePorts[$name]
    $procId = Get-ListenerPid $port
    if ($procId) {
        Write-Host "Stopping $name (port $port, PID $procId)..." -ForegroundColor Yellow
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "[$name] port $port already free" -ForegroundColor DarkGray
    }
}

if ($Status) {
    Write-Host "=== Node server status ===" -ForegroundColor Cyan
    foreach ($n in 'node1','node2','node3') {
        $p = $NodePorts[$n]
        $procId = Get-ListenerPid $p
        $state = if ($procId) { 'LISTENING' } else { 'down' }
        Write-Host ("  {0} :{1}  {2}  {3}" -f $n, $p, $state, $(if ($procId) { "PID=$procId" } else { '' }))
    }
    return
}

if ($Stop) {
    if ($Node -eq 'all') { 'node1','node2','node3' | ForEach-Object { Stop-NodeServer $_ } }
    else { Stop-NodeServer $Node }
    Write-Host 'Done.' -ForegroundColor Cyan
    return
}

if ($Node -eq 'all') { 'node1','node2','node3' | ForEach-Object { Start-NodeServer $_ } }
else { Start-NodeServer $Node }
