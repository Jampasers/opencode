---
name: deploy-to-vercel
description: Use when the user requests deployment or management actions on Vercel — "deploy my app", "deploy and give me the link", "push this live", "create a preview deployment", "set up vercel", "add environment variables to vercel" — including token-based non-interactive setups with VERCEL_TOKEN instead of interactive login, and CLI auth or deployment troubleshooting.
origin: merged from deploy-to-vercel, vercel-cli-with-tokens
---

# Deploy to Vercel

Deploy any project to Vercel. **Always deploy as preview** (not production) unless the user explicitly asks for production. The goal is the best long-term setup: the project linked to Vercel with git-push deploys.

## Working Agreement

- **Never pass `VERCEL_TOKEN` as a `--token` flag.** Export it as an environment variable; the CLI reads it natively. Flags expose secrets in shell history and process listings.
- **Check the environment for a token before asking the user** — current env and `.env` files first.
- **Ask before pushing to git.** Never push commits without explicit approval.
- **Default to preview deployments.** Production only when explicitly requested.
- **Do not modify `.vercel/` files directly.** The CLI manages the directory; reading them (e.g. to verify `orgId`) is fine.
- **Do not curl/fetch deployed URLs to verify.** Just return the link.
- **Use `-y`** on commands that prompt for confirmation, to avoid interactive blocking.
- **Use `--format json`** when structured output helps follow-up steps.

## Step 1: Gather Project State

Run all four checks before deciding which method to use:

```bash
# 1. Check for a git remote
git remote get-url origin 2>/dev/null

# 2. Check if locally linked to a Vercel project (either file means linked)
cat .vercel/project.json 2>/dev/null || cat .vercel/repo.json 2>/dev/null

# 3. Check if the Vercel CLI is installed and authenticated
vercel whoami 2>/dev/null

# 4. List available teams (if authenticated)
vercel teams list --format json 2>/dev/null
```

**About `.vercel/`:** a linked project has either:

- `.vercel/project.json` — from `vercel link`; contains `projectId` and `orgId`.
- `.vercel/repo.json` — from `vercel link --repo`; contains `orgId`, `remoteName`, and a `projects` map from directories to Vercel project IDs.

Either file means linked. The directory is not needed when `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` are both set.

**Do NOT** use `vercel project inspect`, `vercel ls`, or `vercel link` to detect state in an unlinked directory — without `.vercel/` config they interactively prompt or silently link as a side effect. `vercel whoami` is safe anywhere; `vercel ls` in an unlinked directory defaults to showing all deployments for the scope.

### Team selection

If the user belongs to multiple teams, present all available team slugs as a bulleted list and ask which one to deploy to; once picked, proceed immediately — no additional confirmation. Pass the slug via `--scope` on all subsequent CLI commands (`vercel deploy`, `vercel link`, `vercel inspect`, etc.). If the project is already linked, `orgId` in `.vercel/` determines the team — no need to ask again. If there is only one team (or a personal account), skip the prompt and use it directly.

## Step 2: Locate a Token (token-based auth)

Work through these scenarios in order:

**A) `VERCEL_TOKEN` already set in the environment:**

```bash
printenv VERCEL_TOKEN
```

If it returns a value, proceed. **Do not pass it as `--token`:**

```bash
# Bad — token visible in shell history and process listings
vercel deploy --token "vca_abc123"

# Good — CLI reads VERCEL_TOKEN from the environment
export VERCEL_TOKEN="vca_abc123"
vercel deploy
```

**B) Token in `.env` under `VERCEL_TOKEN`:**

```bash
grep '^VERCEL_TOKEN=' .env 2>/dev/null
export VERCEL_TOKEN=$(grep '^VERCEL_TOKEN=' .env | cut -d= -f2-)
```

**C) Token in `.env` under another name** (Vercel tokens typically start with `vca_`):

```bash
grep -i 'vercel' .env 2>/dev/null
# identify the variable, then:
export VERCEL_TOKEN=$(grep '^<VARIABLE_NAME>=' .env | cut -d= -f2-)
```

**D) No token found** — ask the user; they can create an access token at vercel.com/account/tokens.

**Project and team from the environment:** if `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` are both set, the CLI targets that project without `vercel link` or a `.vercel/` directory. They must be set together — setting only one causes an error. To extract a team slug from a project URL (`https://vercel.com/my-team/my-project`):

```bash
echo "$PROJECT_URL" | sed 's|https://vercel.com/||' | cut -d/ -f1
```

On Windows PowerShell, `printenv`/`export` become `$env:VAR` (`$env:VERCEL_TOKEN = "..."`).

**CLI setup:**

```bash
npm install -g vercel
vercel --version
```

## Step 3: Choose a Deploy Method

### Quick deploy — project ID in environment (no linking)

```bash
vercel deploy -y --no-wait
vercel deploy --scope <team-slug> -y --no-wait
vercel deploy --prod --scope <team-slug> -y --no-wait   # production only on explicit request
vercel inspect <deployment-url>                          # check status
```

### Linked + git remote → Git Push (ideal state)

1. **Ask the user before pushing.** Never push without explicit approval:
   ```
   This project is connected to Vercel via git. I can commit and push to
   trigger a deployment. Want me to proceed?
   ```
2. Commit and push:
   ```bash
   git add .
   git commit -m "deploy: <description of changes>"
   git push
   ```
   Vercel builds automatically: non-production branches get preview deployments, the production branch (usually `main`) gets a production deployment.
3. **Retrieve the preview URL** (if the CLI is authenticated):
   ```bash
   sleep 5
   vercel ls --format json
   ```
   Find the latest entry in the `deployments` array — its `url` field is the preview URL. If the CLI is not authenticated, tell the user to check the Vercel dashboard or the commit status checks on their git provider.

### Linked + no git remote → `vercel deploy`

```bash
vercel deploy [path] -y --no-wait
vercel inspect <deployment-url>
```

`--no-wait` returns immediately with the deployment URL instead of blocking until the build finishes (builds can take a while). Production (only if explicitly requested):

```bash
vercel deploy [path] --prod -y --no-wait
```

### Not linked + CLI authenticated → Link first, then deploy

1. **Ask which team to deploy to** — present team slugs from Step 1 as a bulleted list (skip if only one team / personal account).
2. **Once selected, proceed directly to linking.** Tell the user what will happen but do not ask for separate confirmation:
   ```
   Linking this project to <team name> on Vercel. This will create a Vercel
   project to deploy to and enable automatic deployments on future git pushes.
   ```
3. **Link** — with a git remote, use repo-based linking (matches the remote URL to existing Vercel projects; much more reliable than plain `vercel link`, which matches by directory name and often fails when names differ; creates `.vercel/repo.json`). Without a git remote, plain link creates `.vercel/project.json`:
   ```bash
   vercel link --repo --scope <team-slug>                        # git remote exists
   vercel link --scope <team-slug>                               # no git remote
   vercel link --project <project-name> --scope <team-slug> -y   # specific project by name
   ```
4. **Deploy with the best available method:** if a git remote exists, commit and push (see above); otherwise `vercel deploy [path] -y --no-wait --scope <team-slug>`, then `vercel inspect <url>`.

### Not linked + CLI not authenticated → Install, auth, link, deploy

1. Install the CLI (if not already installed): `npm install -g vercel`
2. Authenticate: `vercel login` (the user completes auth in their browser; skip to a no-auth fallback if the environment is non-interactive).
3. Ask which team (skip if only one), then link as above (`--repo` if a git remote exists, plain `vercel link` otherwise).
4. Deploy with the best available method (git push if a remote exists, otherwise `vercel deploy -y --no-wait --scope <team-slug>` + `vercel inspect <url>`).

### Deploying from a remote repository (code not cloned locally)

```bash
git clone <repo-url>
cd <repo-name>
vercel link --repo --scope <team-slug> -y
# then git push (if you have push access) or the CLI deploy above
```

## No-Auth Fallback — claude.ai sandbox

Last resort when the CLI can't be installed or authenticated. Requires no authentication; returns a **Preview URL** (live site) and a **Claim URL** (transfer to your Vercel account):

```bash
bash /mnt/skills/user/deploy-to-vercel/resources/deploy.sh [path]
```

`path` is a directory or `.tgz` file (defaults to the current directory). The script auto-detects the framework from `package.json`, packages the project (excluding `node_modules`, `.git`, `.env`), uploads it, and waits for the build. Example: `bash /mnt/skills/user/deploy-to-vercel/resources/deploy.sh /path/to/project`.

## No-Auth Fallback — Codex sandbox

Codex runs sandboxed by default — try the CLI first, fall back if auth fails:

1. Check whether the CLI is installed (no escalation needed): `command -v vercel`
2. If installed, try `vercel deploy [path] -y --no-wait`
3. If missing, or the CLI fails with "No existing credentials found", use the fallback script:
   ```bash
   skill_dir="<path-to-skill>"
   bash "$skill_dir/resources/deploy-codex.sh"            # current directory
   bash "$skill_dir/resources/deploy-codex.sh" /path/to/project
   bash "$skill_dir/resources/deploy-codex.sh" /path/to/project.tgz
   ```

The script handles framework detection, packaging, and deployment, waits for the build, and returns JSON with `previewUrl` and `claimUrl`.

**Tell the user:** "Your deployment is ready at [previewUrl]. Claim it at [claimUrl] to manage your deployment."

**Escalated network access:** only escalate the actual deploy command if sandboxing blocks the network call (`sandbox_permissions=require_escalated`). Do **not** escalate the `command -v vercel` check.

### Agent-specific notes

- **Claude Code / terminal-based agents:** full shell access; use the CLI directly and the fallback script from the skill's installed location (`bash ~/.claude/skills/deploy-to-vercel/resources/deploy.sh [path]`), not the `/mnt/skills/` path.
- **claude.ai (sandboxed):** likely cannot run `vercel login` or `git push` — go straight to the claude.ai no-auth fallback.
- **Codex:** check if the CLI is available first, then fall back to `deploy-codex.sh`.

## Managing Projects

### Environment variables

```bash
echo "value" | vercel env add VAR_NAME --scope <team-slug>              # all environments
echo "value" | vercel env add VAR_NAME production --scope <team-slug>   # one environment
vercel env ls --scope <team-slug>
vercel env pull --scope <team-slug>          # pull to local .env.local
vercel env rm VAR_NAME --scope <team-slug> -y
```

### Inspecting deployments

```bash
vercel ls --format json --scope <team-slug>
vercel inspect <deployment-url>
vercel inspect <deployment-url> --logs       # build logs (requires CLI v35+)
vercel logs <deployment-url>                 # runtime logs (follows live; --no-follow for one-shot)
```

### Domains

```bash
vercel domains ls --scope <team-slug>
vercel domains add <domain> --scope <team-slug>              # linked (or env-linked) directory
vercel domains add <domain> <project> --scope <team-slug>    # unlinked directory
```

### Stripe Projects plan changes

If the project is managed by Stripe Projects, **ask the user before any paid or destructive plan change** — upgrades bill a real card, downgrades remove seats. First confirm the Vercel resource's local name with `stripe projects status --json`; the examples below assume the default `vercel-plan`:

- Upgrade to Pro: `stripe projects add vercel/pro` (or `stripe projects upgrade vercel-plan pro`)
- Downgrade to Hobby: `stripe projects downgrade vercel-plan hobby`

Pro includes a $20/month platform fee with $20/month usage credit, Turbo build machines by default for new projects, 1 deploying seat plus unlimited free Viewer seats, higher included allocations (1 TB Fast Data Transfer, 10M Edge Requests/month), and paid add-ons (SAML SSO, HIPAA BAA, Flags Explorer, Observability Plus, Speed Insights, Web Analytics Plus). Details: https://vercel.com/docs/plans/pro-plan

## Output

Always show the user the deployment URL.

- **Git push:** find the preview URL via `vercel ls --format json`; if the CLI isn't authenticated, point to the Vercel dashboard or commit status checks.
- **CLI deploy:** show the URL returned by `vercel deploy --no-wait`; use `vercel inspect <url>` to check build status and report it.
- **No-auth fallback:** show both URLs:
  ```
  Deployment successful!

  Preview URL: https://my-app-abc123.vercel.app
  Claim URL:   https://vercel.com/claim-deployment?code=...

  View your site at the Preview URL.
  To transfer this deployment to your Vercel account, visit the Claim URL.
  ```

Do not curl or fetch the deployed URL to verify it works. Just return the link.

## Troubleshooting

### Token not found

```bash
printenv | grep -i vercel
grep -i vercel .env 2>/dev/null
```

### Authentication error

If the CLI fails with `Authentication required`, the token may be expired or invalid. Verify with `vercel whoami` (uses `VERCEL_TOKEN` from the environment), then ask the user for a fresh token. If `vercel login` or `vercel deploy` fails with auth errors, fall back to the no-auth deploy script for the environment.

### Wrong team

```bash
vercel whoami --scope <team-slug>
```

### Build failure

```bash
vercel inspect <deployment-url> --logs
```

Common causes:

- Missing dependencies — ensure `package.json` is complete and committed.
- Missing environment variables — add with `vercel env add`.
- Framework misconfiguration — check `vercel.json`; Vercel auto-detects frameworks (Next.js, Remix, Vite, etc.) from `package.json`.

### Network egress error (claude.ai)

If deployment fails due to network restrictions on claude.ai, tell the user:

```
Deployment failed due to network restrictions. To fix this:

1. Go to https://claude.ai/settings/capabilities
2. Add *.vercel.com to the allowed domains
3. Try deploying again
```

### Escalated network access (Codex / sandboxed environments)

If the deploy fails on timeouts, DNS errors, or connection resets in a sandboxed environment, rerun with escalated permissions (`sandbox_permissions=require_escalated`) — only for the deploy command, not the CLI availability check.

### CLI not installed

```bash
npm install -g vercel
```
