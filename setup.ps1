# Opencode Setup Script
Set-Location -LiteralPath $PSScriptRoot
Write-Host "Setting up opencode..." -ForegroundColor Cyan

# Node.js/npm wajib ada - jangan lanjut kalau tidak
if (-not (Get-Command node -ErrorAction SilentlyContinue) -or
    -not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    Write-Host "Node.js/npm not found. Install Node.js LTS from https://nodejs.org, open a NEW terminal, then re-run setup." -ForegroundColor Red
    exit 1
}

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

# Copy agents (e.g. codebase-memory Scout/Verify/Auditor)
if (Test-Path ".\agents") {
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\opencode\agents" | Out-Null
    Copy-Item ".\agents\*" "$env:USERPROFILE\.config\opencode\agents\" -Recurse -Force
    Write-Host "Copied agents to ~/.config/opencode/agents/" -ForegroundColor Green
}

# Copy plugins (e.g. codebase-memory graph augmentation)
if (Test-Path ".\plugins") {
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\opencode\plugins" | Out-Null
    Copy-Item ".\plugins\*" "$env:USERPROFILE\.config\opencode\plugins\" -Recurse -Force
    Write-Host "Copied plugins to ~/.config/opencode/plugins/" -ForegroundColor Green
}

# Rewrite repo author's hardcoded path to this machine's user profile
$StalePath = 'C:/Users/andri'
$FreshPath = $env:USERPROFILE -replace '\\', '/'
foreach ($File in @(
    "$env:USERPROFILE\.config\opencode\opencode.jsonc",
    "$env:USERPROFILE\.config\opencode\plugins\cbm-augment.ts"
)) {
    if (Test-Path $File) {
        [IO.File]::WriteAllText($File, ([IO.File]::ReadAllText($File)).Replace($StalePath, $FreshPath))
    }
}
Write-Host "Patched paths to $FreshPath" -ForegroundColor Green

# Install opencode CLI
if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Write-Host "Installing opencode CLI..." -ForegroundColor Yellow
    & npm.cmd install -g opencode-ai@latest
    if ($LASTEXITCODE -ne 0) {
        Write-Host "opencode install failed (npm exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "opencode already installed" -ForegroundColor Green
}

# Install codebase-memory-mcp (skip-config: opencode wiring comes from this repo)
$CbmExe = "$env:LOCALAPPDATA\Programs\codebase-memory-mcp\codebase-memory-mcp.exe"
if (-not (Test-Path $CbmExe)) {
    Write-Host "Installing codebase-memory-mcp..." -ForegroundColor Yellow
    $TmpInstaller = Join-Path $env:TEMP "cbm-install.ps1"
    Invoke-WebRequest "https://github.com/DeusData/codebase-memory-mcp/releases/latest/download/install.ps1" -OutFile $TmpInstaller -UseBasicParsing
    & powershell -NoProfile -ExecutionPolicy Bypass -File $TmpInstaller --skip-config
    if (-not (Test-Path $CbmExe)) {
        Write-Host "codebase-memory-mcp install failed - get it from https://github.com/DeusData/codebase-memory-mcp" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "codebase-memory-mcp already installed" -ForegroundColor Green
}

# Install browser automation (playwright-cli + browsers) for UI/UX testing
if (-not (Get-Command playwright-cli -ErrorAction SilentlyContinue)) {
    Write-Host "Installing playwright-cli..." -ForegroundColor Yellow
    & npm.cmd install -g @playwright/cli@latest
    if ($LASTEXITCODE -ne 0) {
        Write-Host "playwright-cli install failed (npm exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "playwright-cli already installed" -ForegroundColor Green
}
Write-Host "Installing playwright browsers..." -ForegroundColor Yellow
& npm.cmd exec --yes playwright install
if ($LASTEXITCODE -ne 0) {
    Write-Host "playwright browser install failed (npm exit $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}

# ROUTER_API_KEY is needed by opencode.jsonc; setup does not set it
if (-not [Environment]::GetEnvironmentVariable("ROUTER_API_KEY", "User")) {
    Write-Host "`nROUTER_API_KEY is not set. Run: setx ROUTER_API_KEY `"your-key`" then open a NEW terminal." -ForegroundColor Yellow
}

Write-Host "`nDone! Open a NEW terminal, then run opencode." -ForegroundColor Cyan
