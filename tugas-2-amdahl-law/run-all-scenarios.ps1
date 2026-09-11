param(
    [int]$VUs = 100,
    [string]$Duration = '600s',
    [switch]$SkipPause
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$DataDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerScript = Join-Path $DataDir 'server.js'
$TestScript = Join-Path $DataDir 'test_amdahl.js'
$ContainerName = 'nginx-amdahl'

$K6 = 'C:\Program Files\k6\k6.exe'
if (-not (Test-Path $K6)) { $K6 = 'k6' }

$dockerOk = $false
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerOk = $true }
} catch {
    $dockerOk = $false
}

if (-not $dockerOk) {
    Write-Host "Docker Desktop belum aktif. Silakan buka/jalankan Docker Desktop terlebih dahulu." -ForegroundColor Red
    if (-not $SkipPause) { Read-Host "`nTekan Enter untuk keluar..." }
    exit 1
}

$fPath = Join-Path $DataDir 'file-10mb.bin'
if (-not (Test-Path $fPath)) {
    $bytes = New-Object Byte[] 10485760
    (New-Object Random).NextBytes($bytes)
    [IO.File]::WriteAllBytes($fPath, $bytes)
}

function Get-ListenerPid($port) {
    return Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty OwningProcess
}

function Set-NodeServer($name, [switch]$Start) {
    $ports = @{ node1 = 3001; node2 = 3002; node3 = 3003 }
    $port = $ports[$name]
    $pidPort = Get-ListenerPid $port

    if ($Start) {
        if (-not $pidPort) {
            $env:PORT = [string]$port
            Start-Process -FilePath 'node' -ArgumentList "`"$ServerScript`"" `
                -WorkingDirectory $DataDir `
                -WindowStyle Hidden
            Start-Sleep -Milliseconds 600
        }
    } else {
        if ($pidPort) {
            Stop-Process -Id $pidPort -Force -ErrorAction SilentlyContinue
        }
    }
}

$Scenarios = @(
    @{ Name = 'A'; Nodes = @('node1');                  Conf = 'nginx-scenario-A.conf'; Dir = 'results\skenario-1node' }
    @{ Name = 'B'; Nodes = @('node1','node2');          Conf = 'nginx-scenario-B.conf'; Dir = 'results\skenario-2node' }
    @{ Name = 'C'; Nodes = @('node1','node2','node3');  Conf = 'nginx-scenario-C.conf'; Dir = 'results\skenario-3node' }
)

for ($i = 0; $i -lt $Scenarios.Count; $i++) {
    $sc = $Scenarios[$i]
    $resDir = Join-Path $DataDir $sc.Dir
    New-Item -ItemType Directory -Force -Path $resDir | Out-Null

    foreach ($n in 'node1','node2','node3') {
        if ($sc.Nodes -contains $n) { Set-NodeServer $n -Start }
        else { Set-NodeServer $n }
    }

    $null = docker rm -f $ContainerName 2>&1
    $confMount = "$DataDir\nginx\$($sc.Conf):/etc/nginx/nginx.conf:ro"
    $logMount  = "$DataDir\nginx\logs:/var/log/nginx"
    $null = docker run -d --name $ContainerName -p 8080:8080 -v $confMount -v $logMount nginx:alpine 2>&1
    Start-Sleep -Seconds 2
    $null = docker exec $ContainerName sh -c ": > /var/log/nginx/access.log" 2>&1

    $jsonOut = Join-Path $resDir 'k6-summary.json'
    & $K6 run -e "VUS=$VUs" -e "DURATION=$Duration" --summary-export=$jsonOut $TestScript

    $fwd = $DataDir -replace '\\','/'
    $null = docker cp "$ContainerName`:/var/log/nginx/access.log" "$fwd/$($sc.Dir)/nginx-access.log" 2>&1

    if ($i -lt ($Scenarios.Count - 1)) {
        Start-Sleep -Seconds 1
    }
}

'node1','node2','node3' | ForEach-Object { Set-NodeServer $_ }
$null = docker rm -f $ContainerName 2>&1

if (-not $SkipPause) {
    Read-Host "`nTekan Enter untuk keluar..."
}
