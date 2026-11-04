# Portable Setup — design

**Intent:** repo ini jadi self-bootstrap di laptop Windows baru: `git clone` → `setx ROUTER_API_KEY` → jalankan setup → lingkungan opencode identik dengan laptop sekarang.

## Goals
- `setup.ps1` cek `node` + `npm` dulu; kalau tidak ada → **stop** dengan pesan cara install Node LTS. Tidak lanjut separah apapun.
- Instal `opencode-ai` global via npm kalau belum ada.
- Instal `codebase-memory-mcp.exe` via installer resmi GitHub (`install.ps1 --skip-config`), skip kalau exe sudah ada di `%LOCALAPPDATA%\Programs\codebase-memory-mcp`.
- Bikin path cbm portabel: setelah copy, ganti `C:/Users/andri` → `$env:USERPROFILE` (format `/`) di salinan terinstal `opencode.jsonc` dan `plugins/cbm-augment.ts`.
- Playwright: tetap pasang `@playwright/cli` + `playwright install`; hapus baris `npm i -g playwright` (laptop ini tidak punya global `playwright`, CLI + browser cukup).
- Di akhir setup: kalau `ROUTER_API_KEY` belum ter-set di user env → print perintah `setx` + ingatkan buka terminal baru. Tidak prompt, tidak auto-set.
- Tambah `setup.cmd` (2 baris): `powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"` supaya tidak lawan ExecutionPolicy di laptop baru.

## Non-goals
- Tidak bootstrap Node via winget (putusan user: stop kalau node/npm tidak ada).
- Tidak membawa/instal `9router` global (server-side), `better-sqlite3`, `sql.js`, `porto`.
- Tidak mengubah isi config lain (provider, permissions, MCP firecrawl/playwright).

## Approaches
1. **Patch saat install (dipilih, rekomendasi + disetujui user):** satu loop `-replace` di setup.ps1 atas 2 file yang hanya punya 2 kemunculan `C:/Users/andri`. Pasti jalan, repo tetap satu sumber kebenaran.
2. Env substitution (`{env:USERPROFILE}` di jsonc + `process.env.LOCALAPPDATA` di plugin): ditolak — ekspansi `{env:}` di array `command` MCP belum terdokumentasi eksplisit, risiko gagal senyap.
3. Biarkan installer cbm regenerate config (tanpa `--skip-config`): ditolak — menulis `opencode.json` kedua yang berebut precedence dengan `.jsonc`, dan path di repo tetap harus dipatch.

## Constraints & calls
- PowerShell 5.1, Windows; script harus idempotent (aman dijalankan ulang).
- `setx ROUTER_API_KEY` tetap manual oleh user (permintaan user); setup hanya mengecek dan memberi tahu kalau belum ada.
- Catatan keterbatasan: patch mengasumsikan `%LOCALAPPDATA%` berada di bawah `%USERPROFILE%\AppData\Local` (default Windows).
