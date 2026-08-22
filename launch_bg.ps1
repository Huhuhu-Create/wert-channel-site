# launch_bg.ps1 - wert channel realtime backend 24h daemon
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

function Start-Backend {
  $portAlive = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
  if ($portAlive) { return $null }
  $p = Start-Process -FilePath $py -ArgumentList "$root\api_server.py" -PassThru
  Write-Host ("[$(Get-Date -Format HH:mm:ss)] api_server started pid=$($p.Id)")
  return $p
}
function Start-Tunnel {
  $p = Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList "/c","npx","lt","--port","8000","--subdomain",$sub,">","lt.log","2>&1" -PassThru
  Write-Host ("[$(Get-Date -Format HH:mm:ss)] localtunnel started pid=$($p.Id)")
  return $p
}

$bp = Start-Backend
$tp = Start-Tunnel
Start-Sleep -Seconds 12

while ($true) {
  $portAlive = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
  if (-not $portAlive) {
    Write-Host ("[$(Get-Date -Format HH:mm:ss)] backend port 8000 down, restarting")
    $bp = Start-Backend
    Start-Sleep -Seconds 8
  }
  if ($tp.HasExited) {
    Write-Host ("[$(Get-Date -Format HH:mm:ss)] tunnel exited, restarting")
    $tp = Start-Tunnel
    Start-Sleep -Seconds 10
  }
  $url = $null
  if (Test-Path "lt.log") {
    $line = (Get-Content "lt.log" -Tail 3 | Select-String "your url is:").ToString()
    if ($line -match "https://\S+") { $url = $matches[0].TrimEnd('/') }
  }
  if ($url) {
    $api = "$url/api/feeds"
    $needUpdate = $true
    if (Test-Path "api-config.json") {
      try { $cur = (Get-Content "api-config.json" -Raw | ConvertFrom-Json).public_api; if ($cur -eq $api) { $needUpdate = $false } } catch {}
    }
    if ($needUpdate) {
      Set-Content -Path "api-config.json" -Value (@{ public_api = $api } | ConvertTo-Json -Compress) -Encoding utf8
      Write-Host ("[$(Get-Date -Format HH:mm:ss)] api-config updated -> $api")
    }
  }
  Start-Sleep -Seconds 15
}
