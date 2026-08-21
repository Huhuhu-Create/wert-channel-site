# start-realtime.ps1  (ASCII-only)
# 一键拉起实时后端：启动 api_server.py + localtunnel 公网隧道
# 用法：在 PowerShell 中  .\start-realtime.ps1
# 前置：pip/本机已装 tencent-channel-cli 且已登录（login status 显示 valid:true）
# 注意：localtunnel 子域名 wert-channel 偶尔被占用，可改下方 $sub
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$sub = "wert-channel"
$port = 8000

# 1) 启动 python 后端
Write-Host "[1/2] starting api_server.py on :$port ..." -ForegroundColor Cyan
$env:PYTHONIOENCODING = "utf-8"
$env:PORT = "$port"
Start-Process -NoNewWindow -FilePath python -ArgumentList "api_server.py"
Start-Sleep -Seconds 3

# 2) 启动 localtunnel 隧道（npm 全局装的 lt）
Write-Host "[2/2] starting localtunnel (subdomain=$sub) ..." -ForegroundColor Cyan
$env:PATH = "D:\QClaw\v0.2.36.629\resources\openclaw\config\bin\node;" + $env:PATH
Start-Process -NoNewWindow -FilePath cmd.exe -ArgumentList "/c","npx","lt","--port",$port,"--subdomain",$sub,">","lt.log","2>&1"
Start-Sleep -Seconds 8

if(Test-Path lt.log){ Write-Host (Get-Content lt.log -Tail 5) -ForegroundColor Green }
Write-Host "" 
Write-Host "Public API URL: https://$sub.loca.lt/api/feeds" -ForegroundColor Yellow
Write-Host "把 index.html 里的 PUBLIC_API 改成上面地址即可（已在代码里设好）。" -ForegroundColor White
Write-Host "保持此窗口开着即可持续运行；关闭窗口 = 停止实时后端。" -ForegroundColor Gray
