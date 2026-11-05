# Portable Setup — design

> Revisi 2026-11-05: menggantikan desain lama (patch path absolut penulis repo → `$env:USERPROFILE`
> saat install) dan keputusan "berhenti kalau Node tidak ada". Sekarang: repo = satu-satunya sumber
> kebenaran, tanpa path absolut user mana pun, Node di-bootstrap user-local.

**Intent:** repo ini jadi self-bootstrap di laptop Windows baru:
`git clone` → `.\scripts\setup.ps1` → `setx ROUTER_API_KEY` → buka terminal baru → `opencode`.
Tidak ada langkah copy manual dari `~/.config/opencode` mesin lain.

## Goals
- `scripts/setup.ps1` idempotent; `-DryRun` untuk cek + rencana aksi tanpa mengubah apa pun.
- **Node**: kalau tidak ada atau tidak memenuhi engine `^22.22.2 || ^24.15.0 || >=26`
  (rantai `@opencode-ai/plugin` → `effect@4` → `ini@7`), pasang Node LTS user-local
  (22.23.4) ke `%LOCALAPPDATA%\Programs\nodejs` dengan verifikasi SHA-256 dari nodejs.org.
  Instalasi Node yang sudah ada **tidak pernah ditimpa**.
- Tooling di-pin: `opencode-ai@1.19.5`, `codebase-memory-mcp@0.12.1`,
  `@playwright/cli@0.1.22`, `playwright@1.64.1`.
- Config di-copy 1:1 ke `~/.config/opencode`; skills ke `~/.agents/skills`.
- **codebase-memory-mcp portabel**: dipasang via npm (bukan path absolut).
  `opencode.jsonc` memakai `["cmd","/c","codebase-memory-mcp"]`; plugin `cbm-augment.ts`
  spawn CLI dari PATH (`shell:true` di Windows agar shim `.cmd` ke-resolve).
- `npm ci --omit=dev` di folder config supaya `@opencode-ai/plugin@1.19.5` sesuai lock.
- `ROUTER_API_KEY` tetap manual (`setx`); setup hanya mengecek dan mengingatkan.
  Nilai key tidak pernah ditulis ke file repo.

## Non-goals
- Tidak membawa `9router` server global, `better-sqlite3`, `sql.js`, `porto`.
- Tidak mengubah perilaku provider/permission/MCP selain portabilitas.
- Tidak commit secret atau path absolut user mana pun (dijaga oleh validasi + `-DryRun`).

## Decisions
1. **npm untuk codebase-memory-mcp** (dipilih): README resminya mendukung npm; package
   npm memverifikasi dan meng-cache binari native; subcommand `hook-augment` lewat shim
   npm terbukti jalan. Unduhan runtime dilakukan sekali saat `--version` pertama.
   Alternatif official installer ditolak: URL `main` non-deterministik dan path
   `%LOCALAPPDATA%` tetap harus di-resolve di config.
2. **Repo root = layout `~/.config/opencode`** (dipilih): opencode memuat scope global
   dari `~/.config/opencode`, jadi opencode siap dari folder mana pun. Struktur
   `.opencode/` project-scope ditolak karena environment ini memang global dan akan
   menghasilkan dua sumber kebenaran / plugin ganda.
3. **Validasi JSONC murni PowerShell**: strip komentar baris (`(?m)^\s*//.*$`) lalu
   `ConvertFrom-Json`. PowerShell 5.1 dengan `$ErrorActionPreference='Stop'` tidak
   melempar error untuk stderr native (diuji), jadi warning npm aman.

## Constraints
- PowerShell 5.1, Windows, tanpa admin.
- `setx` manual oleh user (permintaan user); setup hanya memeriksa.
- Verifikasi: `-DryRun`, run nyata idempotent, `git grep` untuk path/secret.
