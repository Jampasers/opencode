#Requires -Version 5.1
# Pull live configuration edits back into this repository.
#
# Direction: live -> repo (setup.ps1 goes the other way). Edits made directly
# in %USERPROFILE%\.config\opencode and %USERPROFILE%\.agents\skills are copied
# into the repo, so `git status` shows exactly what needs committing.
#
#   .\scripts\sync.ps1           copy new/changed live files into the repo
#   .\scripts\sync.ps1 -DryRun   report differences only, change nothing
#
# New and modified files are copied. Files that exist only in the repo are
# never deleted - remove those manually if they were intentionally dropped.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$ConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$SkillsDir = Join-Path $env:USERPROFILE '.agents\skills'

function Say([string]$Msg, [string]$Color = 'Gray') { Write-Host $Msg -ForegroundColor $Color }

function Get-CompareHash([string]$Path) {
    # Text files compare line-ending-insensitively: with git's core.autocrlf=true
    # the checked-out repo copy is CRLF while tools write LF into the live dirs,
    # which would otherwise report every file as changed forever. Binary files
    # (any NUL byte) compare byte-exact.
    $bytes = [IO.File]::ReadAllBytes($Path)
    if (-not ($bytes -contains 0)) {
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
        $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    }
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { return ([BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '') }
    finally { $md5.Dispose() }
}

$pairs = @(
    @{ From = $SkillsDir;                  To = (Join-Path $RepoRoot 'skills') },
    @{ From = (Join-Path $ConfigDir 'agents');  To = (Join-Path $RepoRoot 'agents') },
    @{ From = (Join-Path $ConfigDir 'plugins'); To = (Join-Path $RepoRoot 'plugins') }
)
$singleFiles = @('opencode.jsonc', 'AGENTS.md', 'tui.json')

if (-not (Test-Path -LiteralPath $SkillsDir))  { throw "live skills dir not found: $SkillsDir (run setup first)" }
if (-not (Test-Path -LiteralPath $ConfigDir)) { throw "live config dir not found: $ConfigDir (run setup first)" }

Say "Sync live -> repo" Cyan
Say "  live : $ConfigDir"
Say "  live : $SkillsDir"
Say "  repo : $RepoRoot"
if ($DryRun) { Say "  (dry run: differences only, nothing is copied)" Magenta }
Say ""

$added   = New-Object System.Collections.ArrayList
$updated = New-Object System.Collections.ArrayList
$skipped = New-Object System.Collections.ArrayList

foreach ($pair in $pairs) {
    if (-not (Test-Path -LiteralPath $pair.From)) { continue }
    Get-ChildItem -LiteralPath $pair.From -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($pair.From.Length + 1)
        if ($rel -match '(^|\\)(node_modules|\.playwright-mcp|\.git)(\\|$)') { return }
        $target = Join-Path $pair.To $rel
        if (-not (Test-Path -LiteralPath $target)) {
            [void]$added.Add($rel)
            if (-not $DryRun) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
                Copy-Item -LiteralPath $_.FullName -Destination $target -Force
            }
        }
        elseif ((Get-CompareHash $_.FullName) -ne (Get-CompareHash $target)) {
            [void]$updated.Add($rel)
            if (-not $DryRun) { Copy-Item -LiteralPath $_.FullName -Destination $target -Force }
        }
    }
}

foreach ($f in $singleFiles) {
    $src = Join-Path $ConfigDir $f
    $dst = Join-Path $RepoRoot $f
    if (-not (Test-Path -LiteralPath $src)) { continue }
    if (-not (Test-Path -LiteralPath $dst)) {
        [void]$added.Add($f)
        if (-not $DryRun) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    }
    elseif ((Get-CompareHash $src) -ne (Get-CompareHash $dst)) {
        [void]$updated.Add($f)
        if (-not $DryRun) { Copy-Item -LiteralPath $src -Destination $dst -Force }
    }
}

if ($added.Count)   { Say "New in live (copied to repo):" Green;     $added   | ForEach-Object { Say "  + $_" Green } }
if ($updated.Count) { Say "Changed in live (updated in repo):" Yellow; $updated | ForEach-Object { Say "  ~ $_" Yellow } }
if (-not $added.Count -and -not $updated.Count) { Say "Nothing to sync - repo already matches live." Green }

Say ""
if ($DryRun) {
    Say "Dry run only. Re-run without -DryRun to copy." Magenta
}
else {
    Say "Review the result, then commit:" Cyan
    Say "  git status --short"
    Say "  git add -A; git commit -m `"...`"; git push"
}

exit 0
