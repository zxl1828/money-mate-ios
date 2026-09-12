# MoneyMate iOS 26 - one-click: create repo, push, wait Actions, download IPA.
# Usage:
#   cd "MoneyMate_iOS"
#   powershell -ExecutionPolicy Bypass -File deploy.ps1
# First run logs you into GitHub in the browser (once).
param(
    [string]$RepoUrl = "",
    [string]$RepoName = "money-mate-ios",
    [string]$CommitMessage = "MoneyMate iOS 26 Liquid Glass"
)
$root = $PSScriptRoot
Set-Location $root

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $newPath = "$machine;$user"
    $newPath = $newPath -replace ";;", ";"
    $env:PATH = $newPath.Trim(';')
}

function Ensure-Cli([string]$name, [string]$pkg) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Host "==> Installing $pkg ..."
        winget install --id $pkg -e --accept-source-agreements --accept-package-agreements
        Refresh-Path
    }
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Host "$name still not found. Please install '$pkg' manually (e.g. from Microsoft Store / GitHub CLI) and rerun this script."
        exit 1
    }
}

Ensure-Cli "git" "Git.Git"
Ensure-Cli "gh" "GitHub.cli"

Write-Host "==> Checking GitHub login ..."
gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "==> First use, please authorize GitHub in your browser ..."
    gh auth login --web -h github.com
    gh auth status 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Login not finished. Run: gh auth login  then rerun this script."
        exit 1
    }
}

Write-Host "==> Init git repo and commit ..."
if (-not (Test-Path ".git")) { git init }
git config user.name  "MoneyMate"
git config user.email "moneymate@users.noreply.github.com"
git add -A
$changed = git status --porcelain
if ($changed) {
    git commit -m $CommitMessage
}

$hasRemote = git remote
if ($hasRemote) {
    Write-Host "==> Pushing to configured origin ..."
} elseif (-not [string]::IsNullOrEmpty($RepoUrl)) {
    Write-Host "==> Adding and pushing to $RepoUrl ..."
    git remote add origin $RepoUrl
} else {
    Write-Host "==> Creating private repo $RepoName and pushing ..."
    gh repo create $RepoName --private --source . --remote origin --push
}

if ($hasRemote -or (-not [string]::IsNullOrEmpty($RepoUrl))) {
    git branch -M main
    git push -u origin main
}

Write-Host "==> Waiting for Actions build ..."
gh run watch --exit-status

Write-Host "==> Downloading IPA to ./release ..."
New-Item -ItemType Directory -Force -Path "$root\release" | Out-Null
gh run download --name MoneyMate-ipa --dir "$root\release"

Write-Host ""
Write-Host "Done! IPA is in: $root\release"
Get-ChildItem -LiteralPath "$root\release" -File | Select-Object Name, Length
