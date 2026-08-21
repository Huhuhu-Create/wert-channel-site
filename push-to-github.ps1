# push-to-github.ps1  (ASCII-only, safe on Chinese Windows)
# Usage in PowerShell:
#   cd wert-channel-site
#   .\push-to-github.ps1 -User <your-github-username>
param(
  [Parameter(Mandatory=$true)][string]$User,
  [string]$Repo = "wert-channel-site"
)

# ---- locate git.exe (auto-detect, since git may not be in PATH) ----
$candidates = @(
  "git",
  "C:\Program Files\Git\cmd\git.exe",
  "C:\Program Files (x86)\Git\cmd\git.exe",
  "$env:ProgramFiles\Git\cmd\git.exe",
  "D:\QClaw\v0.2.36.629\resources\openclaw\config\bin\git\git.cmd",
  "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
)
$git = $null
foreach($c in $candidates){
  if(Test-Path $c){ $git = $c; break }
}
# also try where.exe if PATH has it
if(-not $git){
  try{ $w = (where.exe git 2>$null); if($w){ $git = $w.Split([Environment]::NewLine)[0] } }catch{}
}
if(-not $git){
  Write-Host "ERROR: git not found. Install Git for Windows or ensure the QClaw git path exists." -ForegroundColor Red
  Write-Host "Expected one of:" -ForegroundColor White
  $candidates | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
  exit 1
}
Write-Host "Using git: $git" -ForegroundColor Cyan

$remote = "https://github.com/$User/$Repo.git"
Write-Host "Target repo: $remote" -ForegroundColor Cyan

# Add or update remote 'origin'
$r = & $git remote -v 2>$null
if($r -match "origin"){
  & $git remote set-url origin $remote
}else{
  & $git remote add origin $remote
}

& $git branch -M main
Write-Host "Pushing (first time will ask for GitHub username + PAT token)..." -ForegroundColor Yellow
& $git push -u origin main

if($LASTEXITCODE -eq 0){
  Write-Host ""
  Write-Host "SUCCESS: pushed to GitHub." -ForegroundColor Green
  Write-Host "Next: GitHub repo -> Settings -> Pages -> Source: main branch / root -> Save" -ForegroundColor White
  Write-Host "Wait 1-2 min, then visit: https://$User.github.io/$Repo/" -ForegroundColor White
}else{
  Write-Host ""
  Write-Host "FAILED. Common reasons:" -ForegroundColor Red
  Write-Host "  1) Repo not created yet -> go to https://github.com/new and create '$Repo'" -ForegroundColor White
  Write-Host "  2) Wrong password -> at the password prompt, paste your PAT (Personal Access Token), NOT login password" -ForegroundColor White
  Write-Host "     PAT: GitHub -> Settings -> Developer settings -> Personal access tokens -> check 'repo'" -ForegroundColor White
}
