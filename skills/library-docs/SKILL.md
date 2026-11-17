---
name: library-docs
description: Use when a task involves a specific library, framework, SDK, CLI tool, or cloud service and needs current API syntax, configuration, setup steps, migration notes, or code examples — even for well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot — or when the user mentions Context7, asks for docs, or when training data may be outdated and must be verified against current documentation.
origin: merged from documentation-lookup, find-docs, context7-mcp
---

# Library Docs

Never answer library, framework, or API questions from training data alone — fetch current documentation via Context7 first, using the MCP tools when available and the `ctx7` CLI otherwise. Training data is frequently outdated on API details, signatures, and configuration options.

## When to Use

- Setup or configuration questions ("How do I configure Next.js middleware?")
- Code that depends on a library ("Write a Prisma query for...")
- API or reference questions ("What are the Supabase auth methods?")
- Mentions of specific frameworks or libraries (React, Vue, Svelte, Express, Tailwind, Prisma, Supabase, etc.)
- Version migration questions, or debugging that involves library-specific behavior
- CLI tool usage questions for a third-party tool

Use even when you think you know the answer. Applies across harnesses with Context7 configured (Claude Code, Cursor, Codex, opencode).

## Fetch via Context7 MCP

### Step 1: Resolve the Library ID

Call `resolve-library-id` with:

- `libraryName` — the library or product name from the user's question (e.g. `Next.js`, `Prisma`, `Supabase`)
- `query` — the user's full question; this improves relevance ranking

You must obtain a Context7-compatible library ID (format `/org/project` or `/org/project/version`) before querying docs. Do not call `query-docs` without one. Tool names may carry a harness prefix (e.g. `context7_resolve-library-id`).

### Step 2: Select the Best Match

Choose one result using:

- **Name match** — exact or closest match to what the user asked for
- **Benchmark score** — higher is better (100 is highest)
- **Source reputation** — prefer High or Medium
- **Code snippet count** — more examples generally means better coverage
- **Version** — if the user named a version ("React 19", "Next.js 15"), prefer a version-specific ID when one is listed

If multiple good matches exist, proceed with the most relevant one and acknowledge the ambiguity. If none match, say so and suggest query refinements.

### Step 3: Query the Documentation

Call `query-docs` with:

- `libraryId` — the selected Context7 library ID (e.g. `/vercel/next.js`)
- `query` — the user's specific question; be specific to get relevant snippets

### Step 4: Retry with researchMode if Unsatisfied

If the default answer is not sufficient, call `query-docs` again for the same library with `researchMode: true`. That retry uses sandboxed agents that git-pull the actual source repos plus a live web search, then synthesizes a fresh answer. Do this before giving up or answering from training data — it is more costly, so use it as a targeted retry.

### Step 5: Use the Documentation

Answer with the fetched, current information; include relevant code examples from the docs; cite the library or version when it matters ("In Next.js 15...").

## Fetch via Context7 CLI

Keep the CLI up to date before running commands:

```bash
npm install -g ctx7@latest
# or run directly without installing:
npx ctx7@latest <command>
```

Two-step process: resolve the library name to an ID, then query docs with that ID.

```bash
# Step 1: Resolve library ID
ctx7 library <name> <query>

# Step 2: Query documentation
ctx7 docs <libraryId> <query>
```

- Always pass a `query` argument — it is required and directly affects result ranking; use the user's intent or full question.
- You MUST call `ctx7 library` first unless the user explicitly provides a library ID in `/org/project` or `/org/project/version` format.
- Library IDs require a `/` prefix: `/facebook/react`, not `facebook/react`.

```bash
ctx7 library react "How to clean up useEffect with async operations"
ctx7 library nextjs "How to set up app router with middleware"
ctx7 docs /vercel/next.js "How to add authentication middleware to app router"
ctx7 docs /prisma/prisma "How to define one-to-many relations with cascade delete"
```

Version-specific IDs (available versions are listed in the library output):

```bash
ctx7 docs /vercel/next.js "How to set up app router"
ctx7 docs /vercel/next.js/v14.3.0-canary.87 "How to set up app router"
```

The output contains **code snippets** (titled, language-tagged blocks) and **info snippets** (prose explanations with breadcrumb context).

### Authentication

Works without authentication. For higher rate limits:

```bash
# Option A: environment variable
export CONTEXT7_API_KEY=your_key

# Option B: OAuth login
ctx7 login
```

## Write Good Queries

The query directly affects result quality. Be specific and include relevant details. Redact API keys, passwords, tokens, credentials, personal data, and proprietary code before sending anything to Context7.

| Quality | Example |
|---------|---------|
| Good | `"How to set up authentication with JWT in Express.js"` |
| Good | `"React useEffect cleanup function with async operations"` |
| Bad | `"auth"` |
| Bad | `"hooks"` |

## Limits and Fallbacks

- Do not call `resolve-library-id`/`query-docs` (or run CLI commands) more than 3 times per question. If unclear after 3 calls, state the uncertainty and use the best information you have rather than guessing.
- Quota error ("Monthly quota reached" / "quota exceeded"): tell the user the Context7 quota is exhausted, suggest `ctx7 login` for higher limits, then answer from the best available knowledge with an explicit note that it may be outdated.
- Never silently fall back to training data — always tell the user why Context7 was not used.
- Sandboxed environments (e.g. Codex): if a CLI command fails with DNS or network errors (ENOTFOUND, host resolution failures, fetch failed), rerun it outside the sandbox instead of retrying inside it.
- If Context7 yields nothing usable, fall back to the official project documentation site (or a web search for it) and say which source you used.

## Common Mistakes

- Calling `query-docs` before `resolve-library-id` — `ctx7 docs react "hooks"` fails without a valid ID
- Library IDs without the `/` prefix (`facebook/react` instead of `/facebook/react`)
- One-word queries like `"hooks"` or `"auth"` — use the user's full question
- Ignoring a version the user mentioned — use version-specific IDs when listed
- Picking a community fork over an official source when both match
- Including secrets in queries sent to Context7
