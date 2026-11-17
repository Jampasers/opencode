---
name: agent-memory-workflow
description: Use when working across sessions — recalling prior context at session start, saving preferences/architecture/conventions/lessons as they surface, answering "what did we do last time", ending a session with a structured save, or auditing, deduplicating, and consolidating stored memory. Covers the agentmemory MCP tools plus the recall/save protocol that keeps them reliable.
origin: merged from agent-memory-workflow, agentmemory
---

# Agent Memory Workflow

Disciplined cross-session memory protocol backed by the agentmemory MCP server. Treat memory as the agent's external hippocampus: store what the agent should know across sessions, not what it can re-derive from the codebase. The goal is continuity — the user never has to repeat preferences, past decisions, or discovered conventions.

## When to Use

- Starting a new session that builds on previous work
- User asks "remember this", "do you recall", "what did we do last time", or about project history / session timeline
- Before architectural decisions that past context could inform
- Before editing a file with history, to surface past issues or decisions about it
- After discovering a non-obvious bug, making a design decision, or learning a convention
- Ending a session ("done", "bye", or a significant task completed)
- User says "organise memory" or "memory review"

## Memory Categories

Every `memory_save` MUST specify exactly one `type`:

| Category | `type` | What goes in | Retention |
|----------|--------|--------------|-----------|
| User Preferences | `preference` | Style choices (verbose/minimal), framework versions, component lib, naming conventions | Permanent |
| Architecture | `architecture` | Technology decisions, library choices, data flow design, why-X-over-Y | Permanent |
| Project Convention | `convention` | Code patterns, folder structure, naming rules, import style, error handling pattern | Permanent |
| Bug / Lesson | `lesson` | Non-obvious bugs found, debugging strategies, specific pitfalls, workarounds | Permanent |
| Session Log | `session` | What was done this session, files touched, current state | Volatile (overwritten) |

### Example saves per type

```javascript
// preference
memory_save(
  content: "User prefers minimal console output, one-line status per change.",
  concepts: ["preference", "output-style", "verbose-level"],
  files: [],
  type: "preference"
)

// architecture
memory_save(
  content: "Chose Zod over Yup because Zod has better TypeScript inference and edge runtime support.",
  concepts: ["validation", "zod", "typescript", "edge-runtime"],
  files: ["src/lib/validation.ts"],
  type: "architecture"
)

// convention
memory_save(
  content: "All API service files go under src/services/ with singular names (auth.service.ts, market.service.ts).",
  concepts: ["convention", "folder-structure", "services"],
  files: ["src/services/auth.service.ts"],
  type: "convention"
)

// lesson
memory_save(
  content: "Nuxt 4 auto-imports: components in components/ are auto-imported but NOT recursively. Nested dirs need manual export.",
  concepts: ["nuxt4", "auto-import", "components"],
  files: ["nuxt.config.ts"],
  type: "lesson"
)

// session — always overwrite the same concept key so only one session entry exists
memory_save(
  content: "Session 2025-03-21: Implemented market card component, refactored auth middleware. Next: notification system.",
  concepts: ["session-log", "current-state"],
  files: [],
  type: "session"
)
```

## Core Tools

Tools appear in the tool list under the `agentmemory_memory_` prefix; use the exact names as listed.

| Tool | Purpose |
|------|---------|
| `memory_save` | Save insight/decision/fact (`content`, `concepts`, `files`, `type`) |
| `memory_recall` | Exact-keyword search |
| `memory_smart_search` | Hybrid semantic+keyword search — use for fuzzy or conceptual queries |
| `memory_sessions` | List recent sessions with status and observation counts |
| `memory_file_history` | Past observations about specific files; call before editing |
| `memory_lesson_save` / `memory_lesson_recall` | Lessons with confidence scoring, tagged by `domain` |
| `memory_patterns` | Detect recurring patterns across sessions |
| `memory_consolidate` | Run the 4-tier consolidation pipeline |
| `memory_governance_delete` | Delete specific memories — requires explicit user confirmation |

```javascript
// Search past observations
memory_recall(query: "jwt auth setup", limit: 5)
memory_smart_search(query: "how did we handle database performance", limit: 10)

// Save and retrieve a lesson
memory_lesson_save(
  content: "Always validate JWT expiry before decoding payload",
  concepts: ["jwt-validation", "security"],
  domain: "backend"
)
memory_lesson_recall(query: "jwt security", limit: 5)
```

## Session Start Ritual (MANDATORY)

Every new session (or after `/reset`) executes this before any productive work:

```markdown
1. memory_smart_search(query: "user preferences", limit: 5)
2. memory_smart_search(query: "project conventions", limit: 5)
3. memory_smart_search(query: "architecture decisions", limit: 5)
4. memory_smart_search(query: "lessons learned", limit: 10)
5. memory_sessions(limit: 5) — what was done recently
6. memory_recall(query: "current-state") — check session log
```

If the project has been worked on before, also fetch file-level history for files you are about to touch:

```javascript
memory_file_history(files: ["src/middleware/auth.ts", "src/lib/api.ts"])
```

### Synthesise Findings

Produce a one-paragraph context summary after recall:

```
Previous context: 3 sessions found. User prefers minimal output.
Architecture: Zod validation, JWT auth with jose library.
Conventions: services under src/services/, singular names.
Last session: MarketCard component created, auth refactor pending.
```

If nothing is found, report: "No prior memory found — starting fresh."

## Auto-Save Triggers (Mid-Session)

Save immediately, don't wait for session end:

| Trigger | Action | Example |
|---------|--------|---------|
| User states a preference | Save `type: preference` | "I prefer tabs over spaces" |
| Decision with trade-offs | Save `type: architecture` | "We chose X because Y" |
| Non-obvious bug found | Save `type: lesson` | "Remember to validate JWT expiry before payload" |
| Custom convention discovered | Save `type: convention` | "All mutations go through service layer" |
| User corrects your approach | Save `type: preference` + `type: convention` | "Don't use barrel exports" |

Heuristic: **if the user would be annoyed repeating this next session, save it now.**

## Session End Ritual (MANDATORY)

Before the session ends, or after completing a significant task:

```markdown
1. Save session log (overwrite `session-log` + `current-state` concepts)
2. Save any new user preferences discovered
3. Save any new conventions observed
4. Save any lessons/bugs encountered
5. Save any architecture decisions made
6. memory_consolidate() — run the 4-tier consolidation pipeline
```

Use `memory_smart_search` first to check you are not duplicating something already saved.

## Memory Audit & Hygiene

When the user says "organise memory" / "memory review", or periodically:

```javascript
// 1. Find duplicate or stale entries
memory_patterns()

// 2. Delete what's no longer relevant (requires user confirmation)
memory_governance_delete(memory_id: "...")

// 3. Re-consolidate
memory_consolidate()
```

### Duplicate Prevention

Before every `memory_save`, check with `memory_recall` or `memory_smart_search` whether the same information exists. Overwrite if the old version is stale, skip if identical.

## Behavior Rules

1. **Proactive recall** — check memory before implementing new features or fixing bugs.
2. **Auto-save** — save bugs, architectural decisions, and conventions as they happen.
3. **File context** — call `memory_file_history` before editing files to surface past issues or decisions.
4. **Never hallucinate** — only present what the MCP tools return; report "no results found" when appropriate.

## Edge Cases

### No agentmemory server

If the agentmemory MCP tools do not appear in the tool list, fall back to:
- Save JSON files at `.opencode/memory/memory-<type>.json` using the Write tool
- Recall by reading the `.opencode/memory/` directory
- Report: "agentmemory server offline — using file-based fallback"

### First session ever

If `memory_sessions` returns empty, skip the full recall ritual and note: "Fresh project — no prior memory. Starting clean."

### Conflict between memory and codebase

Codebase is always the source of truth. If memory says one thing but the code shows another, trust the code and save a correction.

## Cross-Agent Memory Discipline

When the IT Leader delegates to a subagent, the subagent does NOT have direct agentmemory access. Instead:

1. **IT Leader recalls** relevant memory before delegating
2. **IT Leader includes** the synthesis in the delegation contract (see `agent-delegation-contract` skill)
3. **Subagent reports** any new findings at the end
4. **IT Leader saves** the subagent's findings to agentmemory

This prevents memory pollution from subagents running in shared or unclear contexts.

## Integration Notes

- Server runs on `http://localhost:3111` by default; real-time viewer at `http://localhost:3113`
- Start the server with `npx @agentmemory/agentmemory`
- 53 MCP tools available when the server is running
- 22 auto-capture hooks record session lifecycle automatically via plugin
