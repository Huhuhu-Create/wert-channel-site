# launch_bg.ps1 (ASCII) - wert频道实时后端 本机24h常驻启动器
# 功能: api_server.py 后台常驻 + localtunnel 隧道 + 保活守护 + 自动写 api-config.json
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
$ts = Get-Date -Format "yyyyMMdd-HHmmss"

function Start-Backend {
  $p = Start-Process -NoNewWindow -FilePath $py -ArgumentList "$root\api_server.py" -PassThru
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
Start-Sleep -Seconds 10

# 主保活循环: 每30秒检测, 进程掉了就重启; 隧道地址变了就更新 api-config.json
while ($true) {
  # 后端存活检测
  if ($bp.HasExited) { Write-Host ("[$(Get-Date -Format HH:mm:ss)] backend exited, restarting"); $bp = Start-Backend; Start-Sleep -Seconds 3 }
  # 隧道存活检测 (查 lt.log 最近地址)
  if ($tp.HasExited) { Write-Host ("[$(Get-Date -Format HH:mm:ss)] tunnel exited, restarting"); $tp = Start-Tunnel; Start-Sleep -Seconds 8 }
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
      # 推送地址变更到 GitHub (无凭据则静默失败)
      & git -C $root add api-config.json 2>&1 | Out-Null
      & git -C $root commit -q -m "chore: sync tunnel public_api" 2>&1
      & git -C $root push origin main 2>&1 | ForEach-Object { $_.ToString() -replace "ghp_\w+","***" }
    }
  }
  Start-Sleep -Seconds 30
}
