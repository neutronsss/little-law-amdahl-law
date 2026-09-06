param(
    [ValidateSet('A','B','C')]
    [string]$Scenario = '',
    [switch]$SkipPause,
    [switch]$SaveTxt
)

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$DataDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Helper = Join-Path $DataDir 'start-servers.ps1'
$ContainerName = 'nginx-amdahl'

# ---- k6 binary ----
$K6 = 'C:\Program Files\k6\k6.exe'
if (-not (Test-Path $K6)) { $K6 = 'k6' }

# ---- scenario definitions ----
$Scenarios = @{
    A = @{ nodes = 'node1';                          conf = 'nginx-scenario-A.conf'; dir = 'results\skenario-1node' }
    B = @{ nodes = @('node1','node2');               conf = 'nginx-scenario-B.conf'; dir = 'results\skenario-2node' }
    C = @{ nodes = @('node1','node2','node3');       conf = 'nginx-scenario-C.conf'; dir = 'results\skenario-3node' }
}

if (-not $Scenario) {
    Write-Host 'Pilih skenario (A/B/C):' -NoNewline -ForegroundColor Cyan
    $Scenario = (Read-Host).ToUpper()
    if (-not ($Scenarios.ContainsKey($Scenario))) { throw "Scenario '$Scenario' tidak valid" }
}

$cfg = $Scenarios[$Scenario]
New-Item -ItemType Directory -Force -Path (Join-Path $DataDir $cfg.dir) | Out-Null

Write-Host ""
Write-Host "========== SKENARIO $Scenario : $($cfg.conf) ==========" -ForegroundColor Magenta

# ---- (1) atur node aktif sesuai skenario ----
Write-Host "`n[1/4] Mengatur node server..." -ForegroundColor Cyan
foreach ($node in 'node1','node2','node3') {
    $port = switch ($node) { 'node1' { 3001 } 'node2' { 3002 } 'node3' { 3003 } }
    $lis = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($cfg.nodes -contains $node) {
        if ($lis) { Write-Host "  $node aktif  (port $port)" -ForegroundColor Green }
        else      { & $Helper -Node $node }
    } else {
        if ($lis) { & $Helper -Stop -Node $node }
        else      { Write-Host "  $node off    (port $port)" -ForegroundColor DarkGray }
    }
}

# ---- (2) rebuild container nginx dengan config skenario ----
Write-Host "[2/4] Menyiapkan Nginx load balancer -> config $($cfg.conf)..." -ForegroundColor Cyan
docker rm -f $ContainerName 2>$null | Out-Null
$confMount  = "$DataDir\nginx\$($cfg.conf):/etc/nginx/nginx.conf:ro"
$logMount   = "$DataDir\nginx\logs:/var/log/nginx"
$runOut = docker run -d --name $ContainerName -p 8080:8080 -v $confMount -v $logMount nginx:alpine 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "  Gagal jalankan nginx:" -ForegroundColor Red; Write-Host $runOut; exit 1 }
Start-Sleep -Seconds 2
docker exec $ContainerName sh -c ": > /var/log/nginx/access.log"
if (-not (Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)) {
    Write-Host "  nginx TIDAK listening di :8080 - cek docker logs $ContainerName" -ForegroundColor Red
    exit 1
}
Write-Host "  nginx listening di :8080" -ForegroundColor Green

# ---- (3) jalankan k6 load test ----
Write-Host "[3/4] Menjalankan k6 (50 VUs, 20s, file-10mb.bin)... tunggu ~35 detik" -ForegroundColor Cyan
$jsonOut = Join-Path $DataDir "$($cfg.dir)\k6-summary.json"
$txtOut  = Join-Path $DataDir "$($cfg.dir)\k6-output.txt"
$runCmd  = { & $K6 run --summary-export=$jsonOut (Join-Path $DataDir 'test_amdahl.js') }
if ($SaveTxt) {
    & $runCmd 2>&1 | Tee-Object -FilePath $txtOut
} else {
    & $runCmd
}
if ($LASTEXITCODE -ne 0) { Write-Host "k6 gagal." -ForegroundColor Red }

# ---- (4) simpan access log nginx + ringkasan ----
Write-Host "[4/4] Menyimpan nginx access log..." -ForegroundColor Cyan
$fwd = $DataDir -replace '\\','/'
docker cp "$ContainerName`:/var/log/nginx/access.log" "$fwd/$($cfg.dir)/nginx-access.log" 2>&1 | Out-Null
$lines = (Get-Content (Join-Path $DataDir "$($cfg.dir)\nginx-access.log") | Measure-Object -Line).Lines
Write-Host "  Tersimpan di: $($cfg.dir)\" -ForegroundColor Green
Write-Host "    - k6-summary.json, nginx-access.log ($lines baris)" -ForegroundColor Green
if ($SaveTxt) { Write-Host "    - k6-output.txt (opsi -SaveTxt)" -ForegroundColor Green }

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Yellow
Write-Host "  SKENARIO $Scenario SELESAI." -ForegroundColor Yellow
Write-Host "  AMBIL SCREENSHOT SEKARANG (Win+Shift+S) pada window ini," -ForegroundColor Yellow
Write-Host "  simpan ke: $($cfg.dir)\screenshot.png" -ForegroundColor Yellow
Write-Host "  ============================================================" -ForegroundColor Yellow
if (-not $SkipPause) { Read-Host "`n  Tekan Enter untuk menutup script..." }
Write-Host "Selesai." -ForegroundColor Cyan