# Portable Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `setup.ps1` di laptop Windows baru: tolak jalan kalau node/npm tidak ada, lalu pasang opencode CLI + codebase-memory-mcp + playwright dan wire config dengan path laptop baru.

**Architecture:** Satu script `setup.ps1` yang idempotent (cek-dulu-baru-instal), plus wrapper `setup.cmd` untuk menembus ExecutionPolicy. Portabilitas path cbm dicapai dengan literal string replace `C:/Users/andri` → `$env:USERPROFILE` (slash) pada salinan file yang baru dicopy.

**Tech Stack:** PowerShell 5.1, npm global, installer resmi GitHub `DeusData/codebase-memory-mcp`.

**Spec:** `docs/superpowers/specs/2026-11-04-portable-setup-design.md`

## Global Constraints

- PowerShell 5.1 (tanpa `&&`, tanpa operator ternary), Windows.
- Script idempotent: aman dijalankan berulang.
- Jangan pernah jalankan `winget`/installer Node — node/npm tidak ada = berhenti (`exit 1`).
- Semua pesan/komentar mengikuti gaya file sekarang (Inggris, `Write-Host ... -ForegroundColor`).
- Jangan commit apa pun; user yang memutuskan commit.
- Nilai persis yang tidak boleh diarang: `C:/Users/andri`, `$env:LOCALAPPDATA\Programs\codebase-memory-mcp\codebase-memory-mcp.exe`, `https://github.com/DeusData/codebase-memory-mcp/releases/latest/download/install.ps1`, `opencode-ai@latest`.

## Review Focus

- Username mengandung `\` atau karakter aneh → replace memakai literal `.Replace` (bukan regex), aman.
- `%LOCALAPPDATA%` tidak di bawah `%USERPROFILE%\AppData\Local` (redirected profile) → path config tidak match; diketahui, di luar scope.
- Script dijalankan ulang → tidak boleh duplikat/error; semua langkah cek dulu.
- `ROUTER_API_KEY` belum di-set → peringatan saja, setup tetap sukses.
- `node` ada tapi `npm.cmd` tidak ketemu di PATH → gate juga cek npm, bukan hanya node.
- File yang dipatch tidak ada (mis. user hapus plugin) → `Test-Path` guard, lanjut tanpa error.

---

### Task 1: Rewrite `setup.ps1`

**Files:**
- Modify: `setup.ps1` (seluruh isi)

**Interfaces:**
- Produces: script idempotent yang dipanggil oleh `setup.cmd` (Task 2) via `-File`; keluar dengan `exit 1` kalau node/npm absen.

- [ ] **Step 1: Tulis ulang `setup.ps1`**

Isi lengkap file (urutan blok: gate node → folder → copy config → patch path → copy skills/agents/plugins → EDITOR → opencode → cbm → playwright → warning key → done):

```powershell
# Opencode Setup Script
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
} else {
    Write-Host "playwright-cli already installed" -ForegroundColor Green
}
Write-Host "Installing playwright browsers..." -ForegroundColor Yellow
& npm.cmd exec --yes playwright install

# ROUTER_API_KEY is needed by opencode.jsonc; setup does not set it
if (-not [Environment]::GetEnvironmentVariable("ROUTER_API_KEY", "User")) {
    Write-Host "`nROUTER_API_KEY is not set. Run: setx ROUTER_API_KEY `"your-key`" then open a NEW terminal." -ForegroundColor Yellow
}

Write-Host "`nDone! Open a NEW terminal, then run opencode." -ForegroundColor Cyan
```

- [ ] **Step 2: Self-check logika replace (tanpa mengubah file asli)**

Run:
```powershell
$StalePath = 'C:/Users/andri'; $FreshPath = 'C:/Users/budi'; ('x=' + 'C:/Users/andri/AppData/Local/p.exe'.Replace($StalePath,$FreshPath))
```
Expected: `x=C:/Users/budi/AppData/Local/p.exe`

- [ ] **Step 3: Jalankan ulang setup di laptop ini (idempotens + no error)**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1`
Expected: selesai dengan `Done! ...`; semua langkah install mencetak `already installed`; tidak ada error merah.

- [ ] **Step 4: Verifikasi salinan terinstal utuh**

Run:
```powershell
Select-String "$env:USERPROFILE\.config\opencode\opencode.jsonc","$env:USERPROFILE\.config\opencode\plugins\cbm-augment.ts" -Pattern "codebase-memory-mcp.exe"
```
Expected: dua baris path; di laptop ini tetap `C:/Users/andri/...` (replace no-op karena USERPROFILE sama).

---

### Task 2: Tambah `setup.cmd` + uji end-to-end

**Files:**
- Create: `setup.cmd`

**Interfaces:**
- Consumes: `setup.ps1` dari Task 1.
- Produces: entry point sekali-klik untuk laptop baru.

- [ ] **Step 1: Buat `setup.cmd`**

Isi persis (2 baris):
```bat
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
```

- [ ] **Step 2: Uji end-to-end lewat `setup.cmd`**

Run: `cmd /c setup.cmd`
Expected: output sama seperti Task 1 Step 3, exit code 0.

- [ ] **Step 3: Simulasi laptop lain (dry)**

Run (hanya mensimulasikan patcher terhadap salinan sementara; tidak menyentuh config asli):
```powershell
$f = Join-Path $env:TEMP "cbm-augment.test.ts"; 'const BIN = ''C:/Users/andri/AppData/Local/Programs/codebase-memory-mcp/codebase-memory-mcp.exe'';' | Set-Content $f
$StalePath='C:/Users/andri'; $FreshPath='C:/Users/budi'
[IO.File]::WriteAllText($f, ([IO.File]::ReadAllText($f)).Replace($StalePath,$FreshPath))
Get-Content $f
Remove-Item $f
```
Expected: baris berisi `C:/Users/budi/AppData/...`.
