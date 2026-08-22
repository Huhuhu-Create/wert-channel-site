# launch_bg.ps1 - wert channel realtime backend 24h daemon (ASCII only)
# start api_server.py(8000) + localtunnel, keepalive both, sync api-config.json
# run directly, or put in Startup folder for login autostart

$ErrorActionPreference = "Continue"
$root = "D:\QClaw\rrr"
Set-Location $root
$env:PYTHONIOENCODING = "utf-8"
$env:PORT = "8000"
$py = "C:\Users\15838\AppData\Local\Python\pythoncore-3.14-64\python.exe"
$nodeDir = "D:\QClaw\v0.2.36.629\resources\openclaw\config\bin\node"
$env:PATH = $nodeDir + ";" + $env:PATH
$sub = "wert-channel"
$ts = { Get-Date -Format "HH:mm:ss" }

function Start-Backend {
  $portAlive = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
  if ($portAlive) { return $null }
  $p = Start-Process -FilePath $py -ArgumentList "$root\api_server.py" -PassThru
  Write-Host ("[$(&$ts)] api_server started pid=$($p.Id)")
  return $p
}
function Start-Tunnel {
  # 用 PowerShell 管日志(Out-File -Append)而非 cmd 的 >, 避免"文件被占用"冲突
  $logFile = Join-Path $root "lt.log"
  $errFile = Join-Path $root "lt.err.log"
  $p = Start-Process -NoNewWindow -FilePath "npx" -ArgumentList @("--yes","lt","--port","8000","--subdomain",$sub) `
        -RedirectStandardOutput $logFile -RedirectStandardError $errFile -PassThru
  Write-Host ("[$(&$ts)] localtunnel started pid=$($p.Id)")
  return $p
}

$bp = Start-Backend
$tp = Start-Tunnel
Start-Sleep -Seconds 12

while ($true) {
  # 后端存活检测
  $portAlive = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
  if (-not $portAlive) {
    Write-Host ("[$(&$ts)] backend port 8000 down, restarting")
    $bp = Start-Backend
    Start-Sleep -Seconds 8
  }
  # 隧道存活检测
  $tunnelUp = $false
  try {
    $r = Invoke-WebRequest -Uri "https://$sub.loca.lt/api/feeds?count=1" -TimeoutSec 6 -UseBasicParsing -ErrorAction Stop
    if ($r.StatusCode -eq 200) { $tunnelUp = $true }
  } catch { $tunnelUp = $false }
  if (-not $tunnelUp) {
    if ($tp -and -not $tp.HasExited) { try { $tp.Kill(); Start-Sleep -Seconds 2 } catch {} }
    Write-Host ("[$(&$ts)] tunnel down, restarting")
    $tp = Start-Tunnel
    Start-Sleep -Seconds 12
  }
  # 同步 api-config.json
  $url = "https://$sub.loca.lt"
  $api = "$url/api/feeds"
  $needUpdate = $true
  if (Test-Path "api-config.json") {
    try { $cur = (Get-Content "api-config.json" -Raw | ConvertFrom-Json).public_api; if ($cur -eq $api) { $needUpdate = $false } } catch {}
  }
  if ($needUpdate) {
    Set-Content -Path "api-config.json" -Value (@{ public_api = $api } | ConvertTo-Json -Compress) -Encoding utf8
    Write-Host ("[$(&$ts)] api-config updated -> $api")
  }
  Start-Sleep -Seconds 30
}
