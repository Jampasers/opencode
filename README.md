# OpenCode — portable Windows environment

This repository is the **single source of truth** for a portable OpenCode
environment on Windows. Clone it on a fresh machine, run one setup command, and
you get the same agents, skills, plugins, MCP servers, provider configuration,
permissions and keybinds as the reference setup.

## Quick start (fresh Windows machine)

```powershell
git clone https://github.com/Jampasers/opencode.git
cd opencode
.\scripts\setup.ps1

setx ROUTER_API_KEY "YOUR_ROUTER_API_KEY"
# open a NEW PowerShell window — setx only affects new processes

opencode
```

Setup is idempotent: re-run it any time to refresh. To check without changing
anything:

```powershell
.\scripts\setup.ps1 -DryRun
```

## Prerequisites

- Windows 10/11 with PowerShell 5.1 (preinstalled).
- **Git only** — needed to clone this repository.
- **Node.js is optional**: setup installs a user-local Node.js LTS
  (`22.23.4`) to `%LOCALAPPDATA%\Programs\nodejs` when Node is missing or does
  not satisfy the required engines (`^22.22.2 || ^24.15.0 || >=26`, required by
  `@opencode-ai/plugin`). An existing Node installation is **never replaced**.
- Internet access for npm installs and the first OpenCode launch.

No admin rights are required. Everything installs per-user.

## What setup does

1. Detects Windows, Git, Node.js and npm (bootstraps Node user-local when
   missing/incompatible, with SHA-256 verification of the official archive).
2. Installs pinned tooling globally via npm:
   `opencode-ai@1.19.5`, `codebase-memory-mcp@0.12.1`,
   `@playwright/cli@0.1.22`, `playwright@1.64.1` (+ browser binaries).
3. Copies this repository's configuration into `%USERPROFILE%\.config\opencode`
   (`opencode.jsonc`, `tui.json`, `AGENTS.md`, `agents/`, `plugins/`,
   `package.json`, `package-lock.json`) and all skills into
   `%USERPROFILE%\.agents\skills`.
4. Runs `npm ci --omit=dev` in the config directory so the local plugin tooling
   matches `package-lock.json` (`@opencode-ai/plugin@1.19.5`).
5. Sets `EDITOR=notepad` (user scope).
6. Validates: required files, JSON/JSONC parse, agents present, plugin present,
   and no machine-specific absolute paths.
7. Checks `ROUTER_API_KEY` and prints next steps.

The repository root mirrors OpenCode's native global config directory
(`~/.config/opencode`), so setup is a 1:1 sync and OpenCode works from **any**
folder, not just inside the clone.

## API key (never stored in Git)

The 9Router provider reads its key from the environment:

```jsonc
"apiKey": "{env:ROUTER_API_KEY}"
```

```powershell
setx ROUTER_API_KEY "YOUR_ROUTER_API_KEY"
```

Open a **new** terminal afterwards. No secret is ever written to a tracked
file.

## 9Router provider

`opencode.jsonc` defines provider `9router-local`:

| Setting | Value |
| ------- | ----- |
| npm | `@ai-sdk/openai-compatible` |
| name | `DankaStur 9Router` |
| baseURL | `https://ai.dankastur.com/v1` |
| apiKey | `{env:ROUTER_API_KEY}` |
| model | `9router-local/guwehj` |

## MCP servers

| Server | Type | Configuration |
| ------ | ---- | ------------- |
| `playwright` | local | `cmd /c npx -y @playwright/mcp@0.0.83 --headless` |
| `codebase-memory-mcp` | local | `cmd /c codebase-memory-mcp` (npm-installed CLI, pinned `0.12.1` by setup — fully portable, no absolute paths) |
| `firecrawl` | remote | `https://mcp.firecrawl.dev/v2/mcp` |

## Plugins (pinned for reproducibility)

- `@vheins/opencode-9router@0.9.1`
- `@upstash/context7-opencode@0.2.1`
- `@plannotator/opencode@0.28.30`
- `superpowers` — git, pinned to commit `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b`

npm plugins are downloaded by OpenCode on first launch (network required).
The local plugin `plugins/cbm-augment.ts` is copied to the config directory by
setup and resolves the `codebase-memory-mcp` CLI from `PATH`.

## Repository layout

```
opencode.jsonc        main OpenCode config (provider, plugins, MCP, permissions)
tui.json              TUI keybinds, mouse off
AGENTS.md             global agent instructions
agents/               academic-researcher/-reviewer/-writer, codebase-memory*
plugins/              cbm-augment.ts (local plugin)
skills/               shared skill library (installed to ~/.agents/skills)
scripts/setup.ps1     the bootstrap script
setup.ps1 / setup.cmd backward-compatible entry points (setup.cmd is double-click friendly)
package.json          @opencode-ai/plugin 1.19.5 (+ @playwright/test for repo CI)
package-lock.json     deterministic dependency lock
docs/superpowers/     design notes for this setup
```

## Updating

```powershell
git pull
.\scripts\setup.ps1
```

Restart OpenCode if it was running. Config is loaded at startup only.

## Troubleshooting

- **ExecutionPolicy blocks the script** — use
  `.\setup.cmd -DryRun`, or
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup.ps1`.
- **`opencode` not found after setup** — open a NEW terminal (the user PATH was
  updated). If it is still missing, check that your npm global bin directory is
  on `PATH`.
- **Node too old** — setup explains the requirement and installs a user-local
  Node.js; the existing installation is untouched.
- **First launch looks slow** — OpenCode downloads npm plugins and the
  codebase-memory native runtime on first use; keep the network on.
- **Playwright browser missing** — run `playwright install` (setup does this
  already; already-present browsers are skipped).
- **Antivirus flags codebase-memory-mcp** — known upstream false positive
  (61/62 engines clean, per its README).

## Uninstall / reset

```powershell
# config + skills (this deletes local state — inspect before running)
Remove-Item "$env:USERPROFILE\.config\opencode" -Recurse -Force
Remove-Item "$env:USERPROFILE\.agents\skills" -Recurse -Force

# global tooling
npm uninstall -g opencode-ai codebase-memory-mcp @playwright/cli playwright
```

Graph indexes kept by codebase-memory-mcp live in
`%USERPROFILE%\.cache\codebase-memory-mcp` (delete manually if not needed).
The user-local Node.js, if installed by setup, lives in
`%LOCALAPPDATA%\Programs\nodejs` (remove the directory and the matching user
`PATH` entry).

## Repository development

```powershell
npm ci                      # @opencode-ai/plugin + @playwright/test
npx playwright test         # example browser tests
python scripts/validate-skills   # skills/agents contract checks
```

## Secrets policy

API keys are intentionally **not** stored in Git. The only key this environment
needs is `ROUTER_API_KEY`, supplied by the user through the environment.
