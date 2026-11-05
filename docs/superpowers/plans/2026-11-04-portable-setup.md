# Portable Setup — implementation record (2026-11-05)

Spec: `docs/superpowers/specs/2026-11-04-portable-setup-design.md` (direvisi 2026-11-05).
Status: implemented; `-DryRun` hijau dan run nyata idempotent sudah diuji.

- [x] `scripts/setup.ps1` — gate Node + bootstrap user-local (SHA-256), pin tooling
      (`opencode-ai@1.19.5`, `codebase-memory-mcp@0.12.1`, `@playwright/cli@0.1.22`,
      `playwright@1.64.1`), copy config/agents/plugins/skills, `npm ci --omit=dev`,
      `EDITOR=notepad`, cek `ROUTER_API_KEY`, validasi + ringkasan. Mendukung `-DryRun`.
- [x] Root `setup.ps1` = forwarder kompatibilitas; `setup.cmd` meneruskan argumen (`%*`).
- [x] `opencode.jsonc` — MCP cbm portabel (`cmd /c codebase-memory-mcp`);
      context7 di-pin `0.2.1`; superpowers di-pin ke commit `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b`.
- [x] `plugins/cbm-augment.ts` — resolve CLI dari PATH, override `CBM_BIN`, tanpa path absolut.
- [x] `package.json` / `package-lock.json` — `@opencode-ai/plugin@1.19.5`
      (+ `@playwright/test@1.64.1` sebagai devDependency; memperbaiki CI `npm ci` yang tadinya
      tanpa manifest).
- [x] `.gitignore` diperluas; `.playwright-mcp/` (9 file generated) di-untrack.
- [x] README berisi panduan setup Windows lengkap.

## Known limitation
- `commands/variants.md` dari mesin master tidak ada di repo ini dan tidak dapat
  direkonstruksi: tidak ada di history git, config global mesin ini, maupun cache plugin.
  Setup dan environment tetap aman tanpa command tersebut; tambahkan kembali file-nya bila
  sumbernya tersedia.
