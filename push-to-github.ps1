# push-to-github.ps1
# 用法：在 PowerShell 里运行  .\push-to-github.ps1  -User <你的GitHub用户名>
param(
  [Parameter(Mandatory=$true)][string]$User,
  [string]$Repo = "wert-channel-site"
)

$remote = "https://github.com/$User/$Repo.git"
Write-Host "目标仓库: $remote" -ForegroundColor Cyan

# 若已存在 remote 则更新，否则添加
$r = git remote -v 2>$null
if($r -match "origin"){
  git remote set-url origin $remote
}else{
  git remote add origin $remote
}

git branch -M main
Write-Host "正在推送（首次会要求输入 GitHub 账号 + PAT 令牌）..." -ForegroundColor Yellow
git push -u origin main

if($LASTEXITCODE -eq 0){
  Write-Host "`n✅ 推送成功！" -ForegroundColor Green
  Write-Host "下一步：GitHub 仓库 → Settings → Pages → Source 选 main 分支 /root → Save" -ForegroundColor White
  Write-Host "约 1~2 分钟后访问：https://$User.github.io/$Repo/" -ForegroundColor White
}else{
  Write-Host "`n❌ 推送失败。常见原因：" -ForegroundColor Red
  Write-Host "  1) 仓库未创建 → 先去 https://github.com/new 建 $Repo" -ForegroundColor White
  Write-Host "  2) 密码错误 → GitHub 密码处要填 PAT（Personal Access Token），非登录密码" -ForegroundColor White
  Write-Host "     PAT 申请：Settings → Developer settings → Personal access tokens → 勾 repo" -ForegroundColor White
}
