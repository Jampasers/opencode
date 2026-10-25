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

# Copy TUI config (keybinds + mouse)
if (Test-Path ".\tui.json") {
    Copy-Item ".\tui.json" "$env:USERPROFILE\.config\opencode\" -Force
    Write-Host "Copied tui.json" -ForegroundColor Green
}

# Set default editor for /editor and /export
[Environment]::SetEnvironmentVariable("EDITOR", "notepad", "User")
$env:EDITOR = "notepad"
Write-Host "Set EDITOR=notepad" -ForegroundColor Green

# Copy all skills
if (Test-Path ".\skills") {
    Copy-Item ".\skills\*" "$env:USERPROFILE\.agents\skills\" -Recurse -Force
    Write-Host "Copied all skills to ~/.agents/skills/" -ForegroundColor Green
}

# Install browser automation (playwright-cli + browsers) for UI/UX testing
if (-not (Get-Command playwright-cli -ErrorAction SilentlyContinue)) {
    Write-Host "Installing playwright-cli..." -ForegroundColor Yellow
    & npm.cmd install -g @playwright/cli@latest
    & npm.cmd install -g playwright
} else {
    Write-Host "playwright-cli already installed" -ForegroundColor Green
}
Write-Host "Installing playwright browsers..." -ForegroundColor Yellow
& npm.cmd exec --yes playwright install

Write-Host "`nDone! Just open opencode now." -ForegroundColor Cyan
