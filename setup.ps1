# Opencode Setup Script
Write-Host "Setting up opencode..." -ForegroundColor Cyan

# Buat folder yang dibutuhin
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\opencode" | Out-Null
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills" | Out-Null

# Copy config
if (Test-Path ".\opencode.jsonc") {
    Copy-Item ".\opencode.jsonc" "$env:USERPROFILE\.config\opencode\" -Force
    Write-Host "Copied opencode.jsonc" -ForegroundColor Green
}

if (Test-Path ".\AGENTS.md") {
    Copy-Item ".\AGENTS.md" "$env:USERPROFILE\.config\opencode\" -Force
    Write-Host "Copied AGENTS.md" -ForegroundColor Green
}

# Copy all skills
if (Test-Path ".\skills") {
    Copy-Item ".\skills\*" "$env:USERPROFILE\.agents\skills\" -Recurse -Force
    Write-Host "Copied all skills to ~/.agents/skills/" -ForegroundColor Green
}

Write-Host "`nDone! Just open opencode now." -ForegroundColor Cyan
