# Global Rules (all repos)

## Environment — Windows / PowerShell 5.1
- ExecutionPolicy blocks `.ps1` shims: run `opencode`, `npm`, `vercel`, etc. via `cmd /c "<cmd>"` (e.g. `cmd /c "npm --version"`).
- Chain commands with `cmd1; if ($?) { cmd2 }` — `&&` is not supported in PowerShell 5.1.
- Prefer `pnpm` for Node projects. Monorepos use pnpm workspaces + turbo.

## Safety
- Never hardcode secrets; use `{env:VAR}` or environment variables.
- Destructive or irreversible actions (force-push, reset --hard, publish, prod migrations, deleting data) require explicit user confirmation first — even when tooling does not prompt.
- Before committing: run the project's lint/typecheck/test commands from its AGENTS.md or package.json.

## Workflow
- Project-level `AGENTS.md` and README override this file on stack details.
- Start non-trivial work with the `brainstorming` / `writing-plans` skills; run verification before claiming work is done.
