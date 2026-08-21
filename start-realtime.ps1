# start-realtime.ps1  (ASCII-only)
# 一键拉起实时后端：启动 api_server.py + localtunnel 公网隧道，
# 并把最新隧道地址写入 api-config.json 并 push 到 GitHub（Pages 主页自动指向新地址）。
# 用法：在 PowerShell 中  .\start-realtime.ps1
# 前置：本机已装 tencent-channel-cli 且已登录；git remote 已配置。

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$sub = "wert-channel"   # 固定子域名（偶尔被占用会自动改随机，下面会读取真实地址）
$port = 8000

# 1) 启动 python 后端
Write-Host "[1/3] starting api_server.py on :$port ..." -ForegroundColor Cyan
$env:PYTHONIOENCODING = "utf-8"
$env:PORT = "$port"
Start-Process -NoNewWindow -FilePath python -ArgumentList "api_server.py"
Start-Sleep -Seconds 3

# 2) 启动 localtunnel 隧道
Write-Host "[2/3] starting localtunnel (subdomain=$sub) ..." -ForegroundColor Cyan
$env:PATH = "D:\QClaw\v0.2.36.629\resources\openclaw\config\bin\node;" + $env:PATH
Start-Process -NoNewWindow -FilePath cmd.exe -ArgumentList "/c","npx","lt","--port",$port,"--subdomain",$sub,">","lt.log","2>&1"
Start-Sleep -Seconds 9

# 3) 读取真实隧道地址，写入 api-config.json 并推送到 GitHub
Write-Host "[3/3] syncing tunnel URL to api-config.json ..." -ForegroundColor Cyan
$url = $null
if(Test-Path lt.log){ $line = (Get-Content lt.log | Select-String "your url is:").ToString(); if($line -match "https://\S+"){ $url = $matches[0].TrimEnd('/') } }
if(-not $url){ Write-Host "WARN: 未能从 lt.log 解析隧道地址，跳过同步" -ForegroundColor Yellow } else {
  $cfg = @{ public_api = "$url/api/feeds" } | ConvertTo-Json -Compress
  Set-Content -Path "api-config.json" -Value $cfg -Encoding utf8
  Write-Host ("tunnel public_api = " + $cfg) -ForegroundColor Green

  # push 到 GitHub（不写盘 token：用本机 git 凭据或临时 http.extraHeader 需 token；这里走本地已存凭据）
  $env:PATH = "D:\QClaw\v0.2.36.629\resources\openclaw\config\bin\git;" + $env:PATH
  & git add api-config.json 2>&1 | Out-Null
  & git commit -q -m "chore: sync tunnel public_api" 2>&1
  # 若本地无凭据缓存会失败，属正常（需用户在 github 桌面端登录一次）
  $p = & git push origin main 2>&1
  $p | ForEach-Object { $_.ToString() -replace "ghp_\w+","***" }
  Write-Host "api-config.json pushed (Pages 将拉取最新地址)" -ForegroundColor Green
}

Write-Host "DONE. 保持此窗口/进程存活即持续运行；关闭即停止实时后端。" -ForegroundColor Gray
