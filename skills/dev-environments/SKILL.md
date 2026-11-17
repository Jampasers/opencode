---
name: dev-environments
description: Use when choosing or setting up a reproducible development environment — devcontainers for Docker/VS Code isolation and sandboxed Claude Code workspaces, or Flox for declarative Nix-based environments with system packages, pinned versions, local services, and macOS/Linux parity. Covers devcontainer.json/Dockerfile options, persistent volumes, language features, Flox manifest.toml, activation, and FloxHub sharing, plus fixes for "works on my machine" setups.
origin: merged from devcontainer-setup, flox-environments
---

# Dev Environments

Two routes to a reproducible setup. **Devcontainers** give full OS-level isolation inside Docker with VS Code integration and a sandboxed Claude Code workspace. **Flox** gives declarative, cross-platform environments (macOS + Linux) without containers or VMs, built on Nix with 150,000+ packages. Pick isolation when you need it; pick Flox when you need system packages and identical toolchains with less overhead.

## When to Use

- Setting up a project with system-level dependencies (compilers, databases, native libraries like openssl, libvips, BLAS, LAPACK)
- Configuring reproducible toolchains for Python, Node.js, Rust, Go, C/C++, Java, Ruby, Elixir, PHP
- Managing environments that must work identically across macOS and Linux, or on a teammate's machine and in CI
- Pinning exact package versions for a team
- Running local services (PostgreSQL, Redis, Kafka) alongside development tools
- Adding devcontainer support to a project, or building a sandboxed Claude Code workspace
- Solving "works on my machine" problems

## Choosing: Devcontainer vs Flox

| Need | Choose |
|------|--------|
| Full OS-level isolation, production-parity container | Devcontainer |
| VS Code "Reopen in Container" workflow, language features | Devcontainer |
| Sandboxed agent workspace with network isolation tooling | Devcontainer |
| Declarative environment without container overhead | Flox |
| System packages + language runtime in one pinned environment | Flox |
| Identical setup on macOS and Linux from one config | Flox |
| AI agent installs tools without sudo or system pollution | Flox |
| Just a single language runtime, no system deps | Standard tooling (nvm, pyenv, rustup) may suffice |

**Do not** use the devcontainer workflow when the user already has a devcontainer config and just needs modifications, for general Docker questions, or to deploy production containers (development only).

## Part 1: Devcontainers

Creates a pre-configured devcontainer with Claude Code and language-specific tooling.

### Phase 1: Project Reconnaissance

Infer the project name (first match):

1. `package.json` → `name`
2. `pyproject.toml` → `project.name`
3. `Cargo.toml` → `package.name`
4. `go.mod` → module path (last segment after `/`)
5. Directory name as fallback

Slugify: lowercase, replace spaces/underscores with hyphens.

Detect the language stack:

| Language | Detection files |
|----------|-----------------|
| Python | `pyproject.toml`, `requirements.txt`, `setup.py`, `*.py` |
| Node/TypeScript | `package.json`, `tsconfig.json` |
| Rust | `Cargo.toml` |
| Go | `go.mod`, `go.sum` |

Multi-language projects: configure all detected languages in priority order — Python (primary, via Dockerfile), then Node/TypeScript, Rust, Go (devcontainer features). Chain setup commands in `postCreateCommand`, e.g. `uv run /opt/post_install.py && uv sync && npm ci`. Merge extensions and settings from every detected language.

### Phase 2: Generate Configuration

Start from the base templates in `resources/` (`Dockerfile`, `devcontainer.json`, `post_install.py`, `.zshrc`, `install.sh`). Substitute:

- `{{PROJECT_NAME}}` → human-readable name ("My Project")
- `{{PROJECT_SLUG}}` → slug for volumes ("my-project")

Base template features:

- **Claude Code** with marketplace plugins (anthropics/skills, trailofbits/skills, trailofbits/skills-curated)
- **Sandboxing** via bubblewrap and socat
- **Python 3.13** via uv, **Node 22** via fnm
- **ast-grep** for AST-based code search
- **Network isolation tools** (iptables, ipset) with `NET_ADMIN` capability
- **Security mount**: `.devcontainer/` mounted read-only to prevent container escape
- **Token forwarding**: `CLAUDE_CODE_OAUTH_TOKEN` and `ANTHROPIC_API_KEY` via `remoteEnv`
- **CLI tools**: ripgrep, fd, fzf, tmux, git-delta

### Language-Specific Sections

**Python** — base Dockerfile already installs Python 3.13 via uv; for another version:

```dockerfile
RUN uv python install <version> --default
```

Extensions: `ms-python.python`, `ms-python.vscode-pylance`, `charliermarsh.ruff`. Settings: `"python.defaultInterpreterPath": ".venv/bin/python"`, `[python]` default formatter `charliermarsh.ruff`, organize imports on save. `postCreateCommand`: `rm -rf .venv && uv sync && uv run /opt/post_install.py` when `pyproject.toml` exists.

**Node/TypeScript** — no Dockerfile additions (Node 22 via fnm). Extensions: `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`; formatter prettier, `source.fixAll.eslint` on save. `postCreateCommand` chains the base install with the lockfile-appropriate command:

| Lockfile | Install |
|----------|---------|
| `pnpm-lock.yaml` | `pnpm install --frozen-lockfile` |
| `yarn.lock` | `yarn install --frozen-lockfile` |
| `package-lock.json` | `npm ci` |
| none | `npm install` |

**Rust** — feature `"ghcr.io/devcontainers/features/rust:1": {}`. Extensions: `rust-lang.rust-analyzer`, `tamasfe.even-better-toml`; `[rust]` formatter rust-analyzer. `postCreateCommand`: `uv run /opt/post_install.py && cargo build --locked` (or `cargo build` without a lockfile).

**Go** — feature `"ghcr.io/devcontainers/features/go:1": { "version": "latest" }`. Extension: `golang.go`; `[go]` formatter `golang.go`, `"go.useLanguageServer": true`. `postCreateCommand`: `uv run /opt/post_install.py && go mod download`.

### Persistent Volumes

Pattern for new mounts in `devcontainer.json`:

```json
"mounts": [
  "source={{PROJECT_SLUG}}-<purpose>-${devcontainerId},target=<container-path>,type=volume"
]
```

Common additions:

- `source={{PROJECT_SLUG}}-cargo-${devcontainerId},target=/home/vscode/.cargo,type=volume` (Rust)
- `source={{PROJECT_SLUG}}-go-${devcontainerId},target=/home/vscode/go,type=volume` (Go)

### Validation Checklist

1. All `{{PROJECT_NAME}}` placeholders replaced
2. All `{{PROJECT_SLUG}}` placeholders replaced
3. Valid JSON in `devcontainer.json` (no trailing commas, proper nesting)
4. Language extensions added for every detected language
5. `postCreateCommand` includes all setup commands, chained with `&&`

### Start the Container

1. VS Code → "Reopen in Container"
2. Or `devcontainer up --workspace-folder .`
3. Run `.devcontainer/install.sh self-install` to add the `devc` CLI helper to PATH

Deeper guidance: `references/dockerfile-best-practices.md` (layer optimization, multi-stage builds, architecture support) and `references/features-vs-dockerfile.md` (features vs custom Dockerfile).

## Part 2: Flox

Flox environments are defined in `.flox/env/manifest.toml` and activated with `flox activate` — identical packages, tools, and configuration for every developer, without containers or VMs.

**Prerequisite:** install Flox first — https://flox.dev/docs/install-flox/install/ (macOS, Linux, Docker).

### Key Paths

- `.flox/env/manifest.toml` — environment definition (commit this)
- `$FLOX_ENV` — runtime path to installed packages (like `/usr`: `bin/`, `lib/`, `include/`)
- `$FLOX_ENV_CACHE` — persistent local storage for caches, venvs, data (survives rebuilds)
- `$FLOX_ENV_PROJECT` — project root (where `.flox/` lives)

### Essential Commands

```bash
flox init                       # Create environment
flox search <package> [--all]   # Search packages (case-sensitive; --all broadens)
flox show <package>             # Show available versions
flox install <package>          # Add a package
flox list [-c]                  # List installed packages / raw manifest
flox activate                   # Enter environment
flox activate -- <cmd>          # Run one command in the environment
flox edit [-f <file>]           # Edit manifest interactively / from file
```

### Manifest Structure

```toml
# .flox/env/manifest.toml

[install]
ripgrep.pkg-path = "ripgrep"
jq.pkg-path = "jq"

[vars]
DATABASE_URL = "postgres://localhost:5432/myapp"

[hook]
on-activate = """
  echo "Environment ready"
"""

[profile]
common = """
  alias dev="npm run dev"
"""

[options]
systems = ["x86_64-linux", "aarch64-linux", "x86_64-darwin", "aarch64-darwin"]
```

### Package Installation Patterns

```toml
[install]
nodejs.pkg-path = "nodejs"
nodejs.version = "^20.0"           # Semver range: latest 20.x

postgres.pkg-path = "postgresql"
postgres.version = "16.2"          # Exact version

# Platform-specific
valgrind.pkg-path = "valgrind"
valgrind.systems = ["x86_64-linux", "aarch64-linux"]

Security.pkg-path = "darwin.apple_sdk.frameworks.Security"
Security.systems = ["x86_64-darwin", "aarch64-darwin"]

coreutils.pkg-path = "coreutils"   # GNU tools where macOS BSD defaults differ
coreutils.systems = ["x86_64-darwin", "aarch64-darwin"]
```

Resolve file conflicts with `priority` (lower wins) and keep related packages versioned together with `pkg-group`:

```toml
[install]
gcc.pkg-path = "gcc12"
gcc.priority = 3                   # wins conflicts against clang
clang.pkg-path = "clang_18"
clang.priority = 5

python.pkg-path = "python311"
python.pkg-group = "python-stack"
pip.pkg-path = "python311Packages.pip"
pip.pkg-group = "python-stack"     # resolves together with python
```

### Language Recipes

**Python with uv** — cache venv inside `$FLOX_ENV_CACHE` and guard installs:

```toml
[install]
python.pkg-path = "python311"
uv.pkg-path = "uv"

[vars]
UV_CACHE_DIR = "$FLOX_ENV_CACHE/uv-cache"
PIP_CACHE_DIR = "$FLOX_ENV_CACHE/pip-cache"

[hook]
on-activate = """
  venv="$FLOX_ENV_CACHE/venv"
  if [ ! -d "$venv" ]; then
    uv venv "$venv" --python python3
  fi
  if [ -f "$venv/bin/activate" ]; then
    source "$venv/bin/activate"
  fi
  if [ -f requirements.txt ] && [ ! -f "$FLOX_ENV_CACHE/.deps_installed" ]; then
    uv pip install --python "$venv/bin/python" -r requirements.txt --quiet
    touch "$FLOX_ENV_CACHE/.deps_installed"
  fi
"""
```

**Node.js:**

```toml
[install]
nodejs.pkg-path = "nodejs"
nodejs.version = "^20.0"

[hook]
on-activate = """
  if [ -f package.json ] && [ ! -d node_modules ]; then
    npm install --silent
  fi
"""
```

**Rust:**

```toml
[install]
rustup.pkg-path = "rustup"
pkg-config.pkg-path = "pkg-config"
openssl.pkg-path = "openssl"

[vars]
RUSTUP_HOME = "$FLOX_ENV_CACHE/rustup"
CARGO_HOME = "$FLOX_ENV_CACHE/cargo"

[profile]
common = """
  export PATH="$CARGO_HOME/bin:$PATH"
"""
```

**Go:**

```toml
[install]
go.pkg-path = "go"
gopls.pkg-path = "gopls"
delve.pkg-path = "delve"

[vars]
GOPATH = "$FLOX_ENV_CACHE/go"
GOBIN = "$FLOX_ENV_CACHE/go/bin"

[profile]
common = """
  export PATH="$GOBIN:$PATH"
"""
```

**C/C++:**

```toml
[install]
gcc.pkg-path = "gcc13"
gcc.pkg-group = "compilers"

# gcc alone does not expose libstdc++ headers — add gcc-unwrapped
gcc-unwrapped.pkg-path = "gcc-unwrapped"
gcc-unwrapped.pkg-group = "libraries"

cmake.pkg-path = "cmake"
gnumake.pkg-path = "gnumake"
gdb.pkg-path = "gdb"
gdb.systems = ["x86_64-linux", "aarch64-linux"]
```

### Hooks and Profile

Rule of thumb: **if it should happen automatically, put it in `[hook]`; if the user should type it, put it in `[profile]`.** Hooks run on every activation — keep them fast and idempotent.

```toml
[hook]
on-activate = """
  if [ ! -d "$FLOX_ENV_CACHE/pgdata" ]; then
    initdb -D "$FLOX_ENV_CACHE/pgdata" --no-locale --encoding=UTF8
  fi
"""

[profile]
common = """
  dev() { npm run dev; }
  test() { npm run test -- "$@"; }
"""
```

### Anti-Patterns

```toml
# BAD — breaks on other machines
[vars]
PROJECT_DIR = "/home/alice/projects/myapp"
# GOOD
[vars]
PROJECT_DIR = "$FLOX_ENV_PROJECT"

# BAD — exit kills the shell
[hook]
on-activate = """ exit 1 """
# GOOD — return from the hook
[hook]
on-activate = """ return 1 """

# BAD — secrets in a committed manifest
[vars]
API_KEY = "<set-at-runtime>"
# GOOD — pass at runtime
# API_KEY="<your-api-key>" flox activate
[vars]
API_KEY = "${API_KEY:-}"

# BAD — reinstalls every activation
[hook]
on-activate = """ pip install -r requirements.txt """
# GOOD — guard with a flag file
[hook]
on-activate = """
  if [ ! -f "$FLOX_ENV_CACHE/.deps_installed" ]; then
    uv pip install -r requirements.txt --quiet
    touch "$FLOX_ENV_CACHE/.deps_installed"
  fi
"""

# BAD — hook functions aren't available in the interactive shell
[hook]
on-activate = """ deploy() { kubectl apply -f k8s/; } """
# GOOD
[profile]
common = """ deploy() { kubectl apply -f k8s/; } """
```

### Full-Stack Example (Python API + PostgreSQL + Redis)

```toml
[install]
python.pkg-path = "python311"
uv.pkg-path = "uv"
postgresql.pkg-path = "postgresql_16"
redis.pkg-path = "redis"
jq.pkg-path = "jq"
curl.pkg-path = "curl"

[vars]
UV_CACHE_DIR = "$FLOX_ENV_CACHE/uv-cache"
DATABASE_URL = "postgres://localhost:5432/myapp"
REDIS_URL = "redis://localhost:6379"

[hook]
on-activate = """
  if [ ! -d "$FLOX_ENV_CACHE/pgdata" ]; then
    initdb -D "$FLOX_ENV_CACHE/pgdata" --no-locale --encoding=UTF8
  fi

  venv="$FLOX_ENV_CACHE/venv"
  if [ ! -d "$venv" ]; then
    uv venv "$venv" --python python3
  fi
  if [ -f "$venv/bin/activate" ]; then
    source "$venv/bin/activate"
  fi

  if [ -f requirements.txt ] && [ ! -f "$FLOX_ENV_CACHE/.deps_installed" ]; then
    uv pip install --python "$venv/bin/python" -r requirements.txt --quiet
    touch "$FLOX_ENV_CACHE/.deps_installed"
  fi
"""

[profile]
common = """
  serve() { uvicorn app.main:app --reload --host 0.0.0.0 --port 8000; }
  migrate() { alembic upgrade head; }
"""

[services]
postgres.command = "postgres -D $FLOX_ENV_CACHE/pgdata -k $FLOX_ENV_CACHE"
redis.command = "redis-server --port 6379 --daemonize no"

[options]
systems = ["x86_64-linux", "aarch64-linux", "x86_64-darwin", "aarch64-darwin"]
```

Run with services: `flox activate --start-services`.

### Environment Sharing

Environments are git-native — commit `.flox/` and teammates run `flox activate` after cloning:

```bash
git add .flox/
git commit -m "Add Flox environment"
```

Reusable base environments go to FloxHub:

```bash
flox push                         # push to FloxHub
flox activate -r owner/env-name   # activate remotely anywhere
```

Compose with `[include]`:

```toml
[include]
base.floxhub = "myorg/python-base"

[install]
fastapi.pkg-path = "python311Packages.fastapi"   # project-specific additions
```

### AI-Assisted Development

When an agent needs a tool that isn't present — compiler, database, linter, CLI — add it to the project manifest instead of sudo/global installs:

- No sudo required (`flox install` works in user space)
- Project-scoped (different projects, different versions)
- Sandbox-friendly (works in restricted environments)
- Reversible (every change lives in `manifest.toml`)
- Reproducible (the exact setup is committed to git)

```bash
flox search jq                    # verify the package exists
flox install jq                   # install into the project environment
flox activate -- jq '.results[]' data.json

# Or edit the manifest programmatically
tmp_manifest="$(mktemp)"
flox list -c > "$tmp_manifest"    # add package to [install], then:
flox edit -f "$tmp_manifest"
```

### Debugging

```bash
flox list -c                      # raw manifest
flox activate -- which python     # which binary resolves
flox activate -- env | grep FLOX  # Flox environment variables
flox search <package> --all       # broader, case-sensitive search
```

Common issues:

- **Package not found:** search is case-sensitive — try `flox search --all`
- **File conflicts between packages:** add `priority` to the package that should win
- **Hook failures:** use `return`, not `exit`; guard with `${FLOX_ENV_CACHE:-}`
- **Stale dependencies:** delete the `$FLOX_ENV_CACHE/.deps_installed` flag file
