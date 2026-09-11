param(
    [int]$VUs = 100,
    [string]$Duration = '600s',
    [switch]$SkipPause
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$DataDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ServerScript = Join-Path $DataDir 'server.js'
$TestScript = Join-Path $DataDir 'test_little.js'
$ResultsDir = Join-Path $DataDir 'results'

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

$K6 = 'C:\Program Files\k6\k6.exe'
if (-not (Test-Path $K6)) { $K6 = 'k6' }

$Files = @(
    @{ Name = 'file-1kb.bin';   Size = 1024 }
    @{ Name = 'file-100kb.bin'; Size = 102400 }
    @{ Name = 'file-1mb.bin';   Size = 1048576 }
    @{ Name = 'file-10mb.bin';  Size = 10485760 }
)

foreach ($f in $Files) {
    $fPath = Join-Path $DataDir $f.Name
    if (-not (Test-Path $fPath)) {
        $bytes = New-Object Byte[] $f.Size
        (New-Object Random).NextBytes($bytes)
        [IO.File]::WriteAllBytes($fPath, $bytes)
    }
}

function Get-ListenerPid($port) {
    return Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty OwningProcess
}

$serverStartedByUs = $false
$pid3001 = Get-ListenerPid 3001
if (-not $pid3001) {
    $proc = Start-Process -FilePath 'node' -ArgumentList "`"$ServerScript`"" `
        -WorkingDirectory $DataDir `
        -PassThru `
        -WindowStyle Hidden
    $serverStartedByUs = $true
    Start-Sleep -Seconds 2
    $pid3001 = Get-ListenerPid 3001
    if (-not $pid3001) {
        Write-Host "Server gagal listening di port 3001." -ForegroundColor Red
        exit 1
    }
}

for ($i = 0; $i -lt $Files.Count; $i++) {
    $item = $Files[$i]
    $fName = $item.Name
    $jsonOut = Join-Path $ResultsDir "$($item.Name)-summary.json"

    & $K6 run -e "FILE=$fName" -e "VUS=$VUs" -e "DURATION=$Duration" --summary-export=$jsonOut $TestScript

    if ($i -lt ($Files.Count - 1)) {
        Start-Sleep -Seconds 1
    }
}

# Bersihkan server Node.js di port 3001 setelah pengujian selesai
$currentPid3001 = Get-ListenerPid 3001
if ($currentPid3001) {
    Stop-Process -Id $currentPid3001 -Force -ErrorAction SilentlyContinue
}

if (-not $SkipPause) {
    Read-Host "`nTekan Enter untuk keluar..."
}
