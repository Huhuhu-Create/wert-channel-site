# launch_bg.ps1 (ASCII) - wert频道实时后端 本机24h常驻启动器
# 功能: 拉起 api_server.py(8000) + localtunnel 隧道 + 双向保活 + 自动写 api-config.json
# 用法: 直接运行, 或放进 Startup 文件夹实现登录自启

$ErrorActionPreference = "Continue"
$root = "D:\QClaw\rrr"
Set-Location $root
$env:PYTHONIOENCODING = "utf-8"
$env:PORT = "8000"
$py = "C:\Users\15838\AppData\Local\Python\pythoncore-3.14-64\python.exe"
$nodeDir = "D:\QClaw\v0.2.36.629\resources\openclaw\config\bin\node"
$env:PATH = $nodeDir + ";" + $env:PATH
$sub = "wert-channel"
$logDir = Join-Path $root "logs"; if(-not (Test-Path $logDir)){ New-Item -ItemType Directory -Path $logDir | Out-Null }

function Start-Backend {
  # 先看端口是否在监听, 在就不用拉
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

# 主保活循环: 每15秒检测, 进程/端口掉了就重启; 隧道地址变了就更新 api-config.json
while ($true) {
  # 后端存活检测 (看端口, 掉了就拉起)
  $portAlive = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
  if (-not $portAlive) {
    Write-Host ("[$(Get-Date -Format HH:mm:ss)] backend port 8000 down, restarting")
    $bp = Start-Backend
    Start-Sleep -Seconds 8
  }
  # 隧道存活检测
  if ($tp.HasExited) {
    Write-Host ("[$(Get-Date -Format HH:mm:ss)] tunnel exited, restarting")
    $tp = Start-Tunnel
    Start-Sleep -Seconds 10
  }
  # 读取隧道真实地址
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
