#Requires -Version 5.1
# OpenCode portable setup for Windows (PowerShell 5.1).
# Reproduces the environment defined by this repository:
#   .\scripts\setup.ps1           install / refresh (idempotent, safe to re-run)
#   .\scripts\setup.ps1 -DryRun   checks + planned actions only, changes nothing
# The repository is the single source of truth. No secrets, no machine-specific
# paths: the API key comes from the ROUTER_API_KEY environment variable.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# --- Pinned versions (single source of truth for setup) ----------------------
$NodePinned          = '22.23.4'   # Node.js LTS "Jod". @opencode-ai/plugin needs ^22.22.2 / ^24.15.0 / >=26
$OpencodePinned      = '1.19.5'
$CbmPinned           = '0.12.1'
$PlaywrightCliPinned = '0.1.22'
$PlaywrightPinned    = '1.64.1'

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$SkillsDir = Join-Path $env:USERPROFILE '.agents\skills'
$NodeDir   = Join-Path $env:LOCALAPPDATA 'Programs\nodejs'

$Summary = [ordered]@{
    Verified = New-Object System.Collections.ArrayList
    Warnings = New-Object System.Collections.ArrayList
    Next     = New-Object System.Collections.ArrayList
}

function Say  ([string]$Msg, [string]$Color = 'Gray') { Write-Host $Msg -ForegroundColor $Color }
function Step ([string]$Msg) { Say ""; Say "==> $Msg" Cyan }
function Ok   ([string]$Msg) { Say "    [ok]   $Msg" Green;  [void]$Summary.Verified.Add($Msg) }
function Warn ([string]$Msg) { Say "    [warn] $Msg" Yellow; [void]$Summary.Warnings.Add($Msg) }
function Plan ([string]$Msg) { Say "    [plan] $Msg" Magenta }

trap {
    Say ""
    Say "SETUP FAILED: $($_.Exception.Message)" Red
    if (-not [Console]::IsInputRedirected) { Read-Host "Press Enter to close" | Out-Null }
    exit 1
}

function Get-CmdPath([string]$Name) {
    $c = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Source }
    return $null
}

function Get-NodeVersion {
    $node = Get-CmdPath 'node'
    if (-not $node) { return $null }
    $raw = & $node --version 2>$null
    if (-not $raw) { return $null }
    return ([version](($raw -replace '^v', '').Trim()))
}

function Test-NodeCompatible($V) {
    if ($null -eq $V) { return $false }
    if ($V.Major -ge 26) { return $true }
    if ($V.Major -eq 24) { return ($V -ge [version]'24.15.0') }
    if ($V.Major -eq 22) { return ($V -ge [version]'22.22.2') }
    return $false
}

function Install-NodeLocal {
    param([string]$Version, [string]$TargetDir)

    $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        'ARM64' { 'arm64' }
        'x86'   { 'x86' }
        default { 'x64' }
    }
    $name = "node-v$Version-win-$arch"
    $zip  = Join-Path $env:TEMP "$name.zip"
    $url  = "https://nodejs.org/dist/v$Version/$name.zip"

    Say "    downloading $url" DarkGray
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

    Say "    verifying SHA-256 checksum" DarkGray
    $sums = (Invoke-WebRequest -Uri "https://nodejs.org/dist/v$Version/SHASUMS256.txt" -UseBasicParsing).Content
    $expected = $null
    foreach ($line in ($sums -split "`n")) {
        if ($line -match ("\s" + [regex]::Escape("$name.zip") + "\s*$")) {
            $expected = ($line -split '\s+')[0].ToLower()
            break
        }
    }
    if (-not $expected) { throw "checksum for $name.zip not found in SHASUMS256.txt" }
    $actual = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) { throw "checksum mismatch for $name.zip (expected $expected, got $actual)" }

    $tmp = Join-Path $env:TEMP "$name-extract"
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    Copy-Item -Path (Join-Path $tmp "$name\*") -Destination $TargetDir -Recurse -Force
    Remove-Item -LiteralPath $zip -Force
    Remove-Item -LiteralPath $tmp -Recurse -Force

    $env:Path = "$TargetDir;$env:Path"
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath -notlike "*$TargetDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$TargetDir;$userPath", 'User')
    }
}

Say "OpenCode portable setup" Cyan
if ($DryRun) { Say "(dry run: checks and planned actions only)" Magenta }
Say "Repository: $RepoRoot"

# --- Platform ---------------------------------------------------------------
Step "Checking platform"
if ($env:OS -ne 'Windows_NT') { throw "this setup script targets Windows." }
Ok "Windows detected"

# --- Git (informational) ----------------------------------------------------
Step "Checking Git"
$git = Get-CmdPath 'git'
if ($git) { Ok "git $(((& $git --version) -replace '^git version ', '').Trim())" }
else { Warn "Git not found. It is needed to clone/update this repository: https://git-scm.com/download/win" }

# --- Node.js / npm ----------------------------------------------------------
Step "Checking Node.js and npm"
$nodeVersion = Get-NodeVersion
if ($nodeVersion) { Say "    found Node.js $nodeVersion" DarkGray }
# A user-local Node from a previous run may not be on this process's stale PATH yet.
if ((-not (Test-NodeCompatible $nodeVersion)) -and (Test-Path -LiteralPath (Join-Path $NodeDir 'node.exe'))) {
    $env:Path = "$NodeDir;$env:Path"
    $nodeVersion = Get-NodeVersion
    if ($nodeVersion) { Say "    using previously bootstrapped user-local Node.js $nodeVersion" DarkGray }
}
if (Test-NodeCompatible $nodeVersion) {
    Ok "Node.js $nodeVersion is compatible"
}
else {
    if ($nodeVersion) {
        Warn "Node.js $nodeVersion does not satisfy the required engines (^22.22.2 / ^24.15.0 / >=26). Installing user-local Node.js $NodePinned; the existing install is left untouched."
    }
    else {
        Warn "Node.js not found. Installing user-local Node.js $NodePinned."
    }
    if ($DryRun) {
        Plan "install Node.js $NodePinned to $NodeDir and prepend it to the user PATH"
    }
    else {
        Install-NodeLocal -Version $NodePinned -TargetDir $NodeDir
        $nodeVersion = Get-NodeVersion
        Ok "Node.js $nodeVersion installed at $NodeDir (user PATH updated; existing install untouched)"
    }
}
$npm = Get-CmdPath 'npm.cmd'
if (-not $npm) { throw "npm.cmd was not found even after Node setup. Install Node.js LTS from https://nodejs.org, open a NEW terminal, then re-run setup." }
Ok "npm $((& $npm --version).Trim())"

# --- Config preparation -----------------------------------------------------
Step "Preparing OpenCode config in $ConfigDir"
$requiredFiles  = @('opencode.jsonc', 'tui.json', 'AGENTS.md', 'package.json', 'package-lock.json')
$requiredAgents = @(
    'academic-researcher.md', 'academic-reviewer.md', 'academic-writer.md',
    'codebase-memory-auditor.md', 'codebase-memory-scout.md', 'codebase-memory.md'
)
foreach ($f in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $f))) { throw "missing required file in repository: $f" }
}
foreach ($a in $requiredAgents) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot "agents\$a"))) { throw "missing required agent in repository: agents\$a" }
}
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'plugins\cbm-augment.ts'))) {
    throw "missing required plugin in repository: plugins\cbm-augment.ts"
}

$skillCount = @(Get-ChildItem -Path (Join-Path $RepoRoot 'skills') -Directory -ErrorAction SilentlyContinue).Count
if ($DryRun) {
    Plan "copy config files to $ConfigDir (opencode.jsonc, tui.json, AGENTS.md, package.json, package-lock.json)"
    Plan "copy agents/ and plugins/ to $ConfigDir, $skillCount skills to $SkillsDir"
}
else {
    New-Item -ItemType Directory -Force -Path $ConfigDir, $SkillsDir | Out-Null
    foreach ($f in $requiredFiles) {
        Copy-Item -LiteralPath (Join-Path $RepoRoot $f) -Destination $ConfigDir -Force
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $ConfigDir 'agents'), (Join-Path $ConfigDir 'plugins') | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot 'agents\*')  -Destination (Join-Path $ConfigDir 'agents')  -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot 'plugins\*') -Destination (Join-Path $ConfigDir 'plugins') -Recurse -Force
    Copy-Item -Path (Join-Path $RepoRoot 'skills\*')  -Destination $SkillsDir -Recurse -Force
    Ok "config, agents, plugins and $skillCount skills copied"
}

# --- Default editor ---------------------------------------------------------
Step "Setting default editor"
if ($DryRun) { Plan "set user environment variable EDITOR=notepad" }
else {
    [Environment]::SetEnvironmentVariable('EDITOR', 'notepad', 'User')
    $env:EDITOR = 'notepad'
    Ok "EDITOR=notepad (user scope)"
}

# --- Config dependencies ----------------------------------------------------
Step "Installing config dependencies"
$installedPkg = Join-Path $ConfigDir 'node_modules\@opencode-ai\plugin\package.json'
$installedVer = $null
if (Test-Path -LiteralPath $installedPkg) {
    $installedVer = ((Get-Content -LiteralPath $installedPkg -Raw | ConvertFrom-Json).version)
}
$wantedVer = ((Get-Content -LiteralPath (Join-Path $RepoRoot 'package.json') -Raw | ConvertFrom-Json).dependencies.'@opencode-ai/plugin')
if ($installedVer -eq $wantedVer) {
    Ok "@opencode-ai/plugin $installedVer already installed in $ConfigDir"
}
elseif ($DryRun) { Plan "npm ci --omit=dev in $ConfigDir" }
else {
    Push-Location $ConfigDir
    try {
        if (Test-Path -LiteralPath (Join-Path $ConfigDir 'package-lock.json')) {
            & $npm ci --omit=dev --no-audit --no-fund
        }
        else {
            & $npm install --omit=dev --no-audit --no-fund
        }
        if ($LASTEXITCODE -ne 0) { throw "npm dependency install failed in $ConfigDir (exit $LASTEXITCODE)" }
    }
    finally { Pop-Location }
    Ok "@opencode-ai/plugin installed in $ConfigDir"
}

# --- opencode CLI -----------------------------------------------------------
Step "Checking opencode CLI ($OpencodePinned)"
$opencodeCmd = Get-CmdPath 'opencode.cmd'
$currentOpencode = ''
if ($opencodeCmd) { $currentOpencode = (& $opencodeCmd --version | Select-Object -First 1).Trim() }
if ($currentOpencode -eq $OpencodePinned) {
    Ok "opencode $currentOpencode already installed"
}
else {
    if ($currentOpencode) { Warn "opencode $currentOpencode found; installing pinned $OpencodePinned" }
    else { Warn "opencode not found; installing pinned $OpencodePinned" }
    if ($DryRun) { Plan "npm install -g opencode-ai@$OpencodePinned" }
    else {
        & $npm install -g "opencode-ai@$OpencodePinned" --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "opencode-ai install failed (exit $LASTEXITCODE)" }
        Ok "opencode-ai $OpencodePinned installed"
    }
}

# --- codebase-memory-mcp (MCP server, installed portably via npm) -----------
Step "Checking codebase-memory-mcp ($CbmPinned)"
$cbmCmd = Get-CmdPath 'codebase-memory-mcp.cmd'
$currentCbm = ''
if ($cbmCmd) { $currentCbm = ((& $cbmCmd --version | Select-Object -First 1) -split '\s+')[-1] }
if ($currentCbm -eq $CbmPinned) {
    if ($DryRun) { Plan "verify native runtime of codebase-memory-mcp $CbmPinned" }
    else {
        & $cbmCmd --version | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "codebase-memory-mcp runtime check failed (exit $LASTEXITCODE)" }
    }
    Ok "codebase-memory-mcp $currentCbm already installed"
}
else {
    if ($currentCbm) { Warn "codebase-memory-mcp $currentCbm found; installing pinned $CbmPinned" }
    else { Warn "codebase-memory-mcp not found; installing pinned $CbmPinned" }
    if ($DryRun) { Plan "npm install -g codebase-memory-mcp@$CbmPinned + one-time native runtime download" }
    else {
        & $npm install -g "codebase-memory-mcp@$CbmPinned" --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "codebase-memory-mcp install failed (exit $LASTEXITCODE)" }
        $cbmCmd = Get-CmdPath 'codebase-memory-mcp.cmd'
        if (-not $cbmCmd) { throw "codebase-memory-mcp installed but not found on PATH; open a NEW terminal and re-run setup." }
        & $cbmCmd --version | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "codebase-memory-mcp first run failed (exit $LASTEXITCODE)" }
        Ok "codebase-memory-mcp $CbmPinned installed (native runtime ready)"
    }
}

# --- Playwright tooling -----------------------------------------------------
Step "Checking Playwright tooling"
$pwCliCmd = Get-CmdPath 'playwright-cli.cmd'
if ($pwCliCmd) { Ok "playwright-cli present" }
else {
    if ($DryRun) { Plan "npm install -g @playwright/cli@$PlaywrightCliPinned" }
    else {
        & $npm install -g "@playwright/cli@$PlaywrightCliPinned" --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "@playwright/cli install failed (exit $LASTEXITCODE)" }
        Ok "@playwright/cli $PlaywrightCliPinned installed"
    }
}
$pwCmd = Get-CmdPath 'playwright.cmd'
if ($pwCmd) { Ok "playwright CLI present" }
else {
    if ($DryRun) { Plan "npm install -g playwright@$PlaywrightPinned" }
    else {
        & $npm install -g "playwright@$PlaywrightPinned" --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "playwright install failed (exit $LASTEXITCODE)" }
        $pwCmd = Get-CmdPath 'playwright.cmd'
        Ok "playwright $PlaywrightPinned installed"
    }
}
if ($DryRun) { Plan "playwright install (chromium, firefox, webkit)" }
else {
    Say "    installing browsers (already-present browsers are skipped)..." DarkGray
    & $pwCmd install
    if ($LASTEXITCODE -ne 0) { throw "playwright browser install failed (exit $LASTEXITCODE)" }
    Ok "Playwright browsers installed"
}

# --- ROUTER_API_KEY ---------------------------------------------------------
Step "Checking ROUTER_API_KEY"
$routerKey = [Environment]::GetEnvironmentVariable('ROUTER_API_KEY', 'User')
if (-not $routerKey) { $routerKey = $env:ROUTER_API_KEY }
if ($routerKey) {
    Ok "ROUTER_API_KEY is set (value never shown or stored)"
}
else {
    Warn "ROUTER_API_KEY is not set; the 9router-local provider will not authenticate."
    [void]$Summary.Next.Add('setx ROUTER_API_KEY "your-key"   then open a NEW terminal')
}

# --- Validation -------------------------------------------------------------
Step "Validating configuration"
$valDir = if ($DryRun) { $RepoRoot } else { $ConfigDir }
$missing = @()
foreach ($f in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $valDir $f))) { $missing += $f }
}
if ($missing.Count) { throw "validation failed, missing files: $($missing -join ', ')" }
Ok "required files present"

$null = Get-Content -LiteralPath (Join-Path $valDir 'tui.json') -Raw | ConvertFrom-Json
Ok "tui.json parses"

$rawJsonc = Get-Content -LiteralPath (Join-Path $valDir 'opencode.jsonc') -Raw
$stripped = [regex]::Replace($rawJsonc, '(?m)^\s*//.*$', '')
$null = $stripped | ConvertFrom-Json
Ok "opencode.jsonc parses (line comments stripped)"

$agentCount = @(Get-ChildItem -Path (Join-Path $valDir 'agents') -Filter '*.md' -ErrorAction SilentlyContinue).Count
if ($agentCount -lt 6) { throw "validation failed: expected at least 6 agents, found $agentCount" }
Ok "$agentCount agents present"
if (-not (Test-Path -LiteralPath (Join-Path $valDir 'plugins\cbm-augment.ts'))) { throw "validation failed: plugins\cbm-augment.ts missing" }
Ok "plugin cbm-augment.ts present"

$stale = Select-String -Path (Join-Path $valDir 'opencode.jsonc'), (Join-Path $valDir 'plugins\cbm-augment.ts') -Pattern 'C:(/|\\)Users' -ErrorAction SilentlyContinue
if ($stale) { Warn "machine-specific user path found in installed config: $($stale.Path -join ', ')" }
else { Ok "no machine-specific user paths in config" }

# --- Summary ----------------------------------------------------------------
Say ""
Say "======================================================================" Cyan
if ($DryRun) { Say "SETUP SUMMARY (dry run - nothing was changed)" Cyan } else { Say "SETUP SUMMARY" Cyan }
Say "======================================================================" Cyan
Say "Repository : $RepoRoot"
Say "Config dir : $ConfigDir"
Say "Skills dir : $SkillsDir"
if ($nodeVersion) { Say "Node.js    : $nodeVersion" }
Say "opencode   : $OpencodePinned (pinned)"

if ($Summary.Verified.Count) {
    Say ""
    Say "Done:" Green
    foreach ($v in $Summary.Verified) { Say "  - $v" Green }
}
if ($Summary.Warnings.Count) {
    Say ""
    Say "Warnings:" Yellow
    foreach ($w in $Summary.Warnings) { Say "  - $w" Yellow }
}
Say ""
Say "Next steps:"
foreach ($n in $Summary.Next) { Say "  - $n" }
Say "  - If opencode is running, quit and restart it."
Say "  - Run: opencode"

Say ""
Say "Not verified by setup: MCP servers start and npm plugins download on the" DarkGray
Say "first opencode launch (network required). ROUTER_API_KEY is user-supplied." DarkGray
if ($DryRun) { Say ""; Say "Dry run only. Re-run without -DryRun to apply." Magenta }

if (-not [Console]::IsInputRedirected) { Read-Host "`nPress Enter to close" | Out-Null }

exit 0
