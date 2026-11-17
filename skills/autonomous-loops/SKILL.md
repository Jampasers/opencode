---
name: autonomous-loops
description: Use when setting up autonomous or continuous agent operation — scheduled crons, persistent task queues, event dispatch, unattended `claude -p` pipelines, parallel sub-agent generation, PR loops with CI gates, or spec/RFC-driven DAG orchestration. Covers loop selection, quality gates, evals, recovery controls, context persistence, and safety boundaries.
origin: merged from autonomous-loops, autonomous-agent-harness, continuous-agent-loop
---

# Autonomous Loops

Patterns and reference implementations for running coding agents autonomously — from a single `claude -p` call to scheduled harnesses, CI-driven PR loops, and RFC-driven multi-agent DAG orchestration. Pick the simplest pattern that survives the task. Every loop needs an exit condition, a context bridge between iterations, and a quality gate.

## When to Use

- Setting up autonomous development workflows that run without human intervention
- Choosing the right loop architecture for the problem (simple vs complex)
- Building CI/CD-style continuous development pipelines
- Running parallel agents with merge coordination
- Scheduling recurring operations (review PRs, monitor deploys, morning briefings)
- Implementing context persistence across loop iterations
- Adding quality gates, evals, and cleanup passes to autonomous workflows

## Consent and Safety Boundaries

Autonomous operation must be explicitly requested and scoped by the user. Do not create schedules, dispatch remote agents, write persistent memory, use computer control, post externally, modify third-party resources, or act on private communications unless the user has approved that capability and the target workspace.

Prefer dry-run plans and local queue files before enabling recurring or event-driven actions. Keep credentials, private workspace exports, personal datasets, and account-specific automations out of reusable artifacts.

## Loop Selection Flow

```text
Start
  |
  +-- Need strict CI/PR control? -- yes --> continuous-pr
  |
  +-- Need RFC decomposition? -- yes --> rfc-dag
  |
  +-- Need exploratory parallel generation? -- yes --> infinite
  |
  +-- Need recurring/scheduled operation? -- yes --> scheduled harness
  |
  +-- default --> sequential
```

## Loop Pattern Spectrum

| Pattern | Complexity | Best For |
|---------|-----------|----------|
| [Sequential Pipeline](#1-sequential-pipeline-claude--p) | Low | Daily dev steps, scripted workflows |
| [NanoClaw REPL](#2-nanoclaw-repl) | Low | Interactive persistent sessions |
| [Scheduled Agent Harness](#3-scheduled-agent-harness) | Medium | Recurring jobs, monitoring, personal assistant |
| [Infinite Agentic Loop](#4-infinite-agentic-loop) | Medium | Parallel content generation, spec-driven work |
| [Continuous PR Loop](#5-continuous-pr-loop) | Medium | Multi-day iterative projects with CI gates |
| [De-Sloppify Pattern](#6-the-de-sloppify-pattern) | Add-on | Quality cleanup after any Implementer step |
| [RFC-Driven DAG](#7-rfc-driven-dag-orchestration) | High | Large features, multi-unit parallel work with merge queue |

---

## 1. Sequential Pipeline (`claude -p`)

**The simplest loop.** Break daily development into a sequence of non-interactive `claude -p` calls. Each call is a focused step with a clear prompt.

> Core insight: if you can't figure out a loop like this, you can't even drive the LLM to fix your code in interactive mode.

The `claude -p` flag runs non-interactively with a prompt and exits when done. Chain calls into a pipeline:

```bash
#!/bin/bash
# daily-dev.sh — Sequential pipeline for a feature branch

set -e

# Step 1: Implement the feature
claude -p "Read the spec in docs/auth-spec.md. Implement OAuth2 login in src/auth/. Write tests first (TDD). Do NOT create any new documentation files."

# Step 2: De-sloppify (cleanup pass)
claude -p "Review all files changed by the previous commit. Remove any unnecessary type tests, overly defensive checks, or testing of language features (e.g., testing that TypeScript generics work). Keep real business logic tests. Run the test suite after cleanup."

# Step 3: Verify
claude -p "Run the full build, lint, type check, and test suite. Fix any failures. Do not add new features."

# Step 4: Commit
claude -p "Create a conventional commit for all staged changes. Use 'feat: add OAuth2 login flow' as the message."
```

### Key Design Principles

1. **Each step is isolated** — a fresh context window per `claude -p` call means no context bleed between steps.
2. **Order matters** — steps execute sequentially, each building on the filesystem state left by the previous.
3. **Negative instructions are dangerous** — don't say "don't test type systems." Add a separate cleanup step instead ([De-Sloppify](#6-the-de-sloppify-pattern)).
4. **Exit codes propagate** — `set -e` stops the pipeline on failure.

### Variations

**Model routing:**

```bash
# Research with Opus (deep reasoning)
claude -p --model opus "Analyze the codebase architecture and write a plan for adding caching..."

# Implement with Sonnet (fast, capable)
claude -p "Implement the caching layer according to the plan in docs/caching-plan.md..."

# Review with Opus (thorough)
claude -p --model opus "Review all changes for security issues, race conditions, and edge cases..."
```

**Environment context — pass context via files, not prompt length:**

```bash
echo "Focus areas: auth module, API rate limiting" > .claude-context.md
claude -p "Read .claude-context.md for priorities. Work through them in order."
rm .claude-context.md
```

**`--allowedTools` restrictions:**

```bash
# Read-only analysis pass
claude -p --allowedTools "Read,Grep,Glob" "Audit this codebase for security vulnerabilities..."

# Write-only implementation pass
claude -p --allowedTools "Read,Write,Edit,Bash" "Implement the fixes from security-audit.md..."
```

---

## 2. NanoClaw REPL

**Persistent loop with session history.** A session-aware REPL that calls `claude -p` synchronously with full conversation history.

```bash
# Start the default session
node scripts/claw.js

# Named session with skill context
CLAW_SESSION=my-project CLAW_SKILLS=tdd-workflow,security-review node scripts/claw.js
```

How it works:

1. Loads conversation history from `~/.claude/claw/{session}.md`
2. Each user message is sent to `claude -p` with full history as context
3. Responses are appended to the session file (Markdown-as-database)
4. Sessions persist across restarts

| Use Case | NanoClaw | Sequential Pipeline |
|----------|----------|-------------------|
| Interactive exploration | Yes | No |
| Scripted automation | No | Yes |
| Session persistence | Built-in | Manual |
| Context accumulation | Grows per turn | Fresh each step |
| CI/CD integration | Poor | Excellent |

---

## 3. Scheduled Agent Harness

Turn the agent into a persistent, self-directing system using native features and MCP servers: **crons** (scheduled tasks), **dispatch** (remote agents), **memory** (persistence), and **computer use** — all driven by skills/commands.

### Persistent Memory Layers

```
# Short-term: current session context
Use TodoWrite for in-session task tracking

# Medium-term: project memory files
Write to ~/.claude/projects/*/memory/ for cross-session recall (markdown + frontmatter, auto-loaded at session start)

# Long-term: MCP knowledge graph
Use mcp__memory__create_entities for permanent structured data
Use mcp__memory__create_relations for relationship mapping
Use mcp__memory__add_observations for new facts about known entities
```

### Scheduled Operations (Crons)

```
# Via MCP tool
mcp__scheduled-tasks__create_scheduled_task({
  name: "daily-pr-review",
  schedule: "0 9 * * 1-5",  # 9 AM weekdays
  prompt: "Review all open PRs in owner/repo. For each: check CI status, review changes, flag issues. Post summary to memory.",
  project_dir: "/path/to/repo"
})

# Via claude -p (programmatic mode)
echo "Review open PRs and summarize" | claude -p --project /path/to/repo
```

Useful cron patterns:

| Pattern | Schedule | Use Case |
|---------|----------|----------|
| Daily standup | `0 9 * * 1-5` | Review PRs, issues, deploy status |
| Weekly review | `0 10 * * 1` | Code quality metrics, test coverage |
| Hourly monitor | `0 * * * *` | Production health, error rate checks |
| Nightly build | `0 2 * * *` | Run full test suite, security scan |
| Pre-meeting | `*/30 * * * *` | Prepare context for upcoming meetings |

### Dispatch / Remote Agents

```bash
# Trigger from CI/CD
curl -X POST "https://api.anthropic.com/dispatch" \
  -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
  -d '{"prompt": "Build failed on main. Diagnose and fix.", "project": "/repo"}'

# Trigger from webhook: GitHub webhook → dispatch → Claude agent → fix → PR

# Trigger from another agent
claude -p "Analyze the output of the security scan and create issues for findings"
```

### Computer Use

Capabilities: browser automation (navigate, click, fill forms, screenshot), desktop control (open apps, type, mouse), and file system operations beyond CLI.

Harness use cases: automated web UI testing, form filling and data entry, screenshot-based monitoring, multi-app workflows.

### Task Queue

Manage a persistent queue of tasks that survives session boundaries via memory files:

```markdown
---
name: task-queue
type: project
description: Persistent task queue for autonomous operation
---

## Active Tasks
- [ ] PR #123: Review and approve if CI green
- [ ] Monitor deploy: check /health every 30 min for 2 hours
- [ ] Research: Find 5 leads in AI tooling space

## Completed
- [x] Daily standup: reviewed 3 PRs, 2 issues
```

### Setup Guide

1. **Configure MCP servers** in `~/.claude.json`:

```json
{
  "mcpServers": {
    "memory": {
      "command": "npx",
      "args": ["-y", "@anthropic/memory-mcp-server"]
    },
    "scheduled-tasks": {
      "command": "npx",
      "args": ["-y", "@anthropic/scheduled-tasks-mcp-server"]
    },
    "computer-use": {
      "command": "npx",
      "args": ["-y", "@anthropic/computer-use-mcp-server"]
    }
  }
}
```

2. **Create base crons:**

```bash
# Daily morning briefing
claude -p "Create a scheduled task: every weekday at 9am, review my GitHub notifications, open PRs, and calendar. Write a morning briefing to memory."

# Continuous learning
claude -p "Create a scheduled task: every Sunday at 8pm, extract patterns from this week's sessions and update the learned skills."
```

3. **Initialize the memory graph:**

```bash
claude -p "Create memory entities for: me (user profile), my projects, my key contacts. Add observations about current priorities."
```

4. **Enable computer use (optional)** — grant the MCP the necessary browser/desktop permissions.

### Example Workflows

**Autonomous PR reviewer** — cron every 30 min during work hours: check new PRs on watched repos → pull branch, run tests, review with code-reviewer agent → post review comments via GitHub MCP → update memory with review status.

**Personal research agent** — cron daily at 6 AM: read saved search queries from memory → run searches → summarize new findings → compare against yesterday → write digest to memory → flag high-priority items for morning review.

**Meeting prep agent** — trigger 30 min before each calendar event: read event details → search memory for attendee context → pull recent email/Slack threads → prepare talking points → write prep doc to memory.

### Constraints

- Cron tasks run in isolated sessions — they share nothing with interactive sessions except memory.
- Computer use requires explicit permission grants; don't assume access.
- Remote dispatch may have rate limits; design cron intervals accordingly.
- Keep memory files concise; archive old data rather than letting files grow unbounded.
- Always verify scheduled tasks completed; add error handling to cron prompts.

### Replacing Standalone Frameworks (Hermes/AutoGPT)

| Framework Component | Native Equivalent |
|---------------------|-------------------|
| Gateway/Router | Dispatch + crons trigger agent sessions |
| Memory System | Built-in memory + MCP memory server |
| Tool Registry | MCP servers (dynamically loaded) |
| Orchestration | Skill + agent definitions |
| Computer Use | computer-use MCP |
| Context Manager | Session management + memory |
| Task Queue | TodoWrite + memory-persisted task list |

---

## 4. Infinite Agentic Loop

**A two-prompt system** that orchestrates parallel sub-agents for specification-driven generation.

```
PROMPT 1 (Orchestrator)              PROMPT 2 (Sub-Agents)
┌─────────────────────┐             ┌──────────────────────┐
│ Parse spec file      │             │ Receive full context  │
│ Scan output dir      │  deploys   │ Read assigned number  │
│ Plan iteration       │────────────│ Follow spec exactly   │
│ Assign creative dirs │  N agents  │ Generate unique output │
│ Manage waves         │             │ Save to output dir    │
└─────────────────────┘             └──────────────────────┘
```

The pattern:

1. **Spec analysis** — orchestrator reads a specification file (Markdown) defining what to generate
2. **Directory recon** — scans existing output to find the highest iteration number
3. **Parallel deployment** — launches N sub-agents, each with the full spec, a unique creative direction, a specific iteration number (no conflicts), and a snapshot of existing iterations (for uniqueness)
4. **Wave management** — in infinite mode, deploy waves of 3-5 agents until context is exhausted

Implementation as a command (`.claude/commands/infinite.md`):

```markdown
Parse the following arguments from $ARGUMENTS:
1. spec_file — path to the specification markdown
2. output_dir — where iterations are saved
3. count — integer 1-N or "infinite"

PHASE 1: Read and deeply understand the specification.
PHASE 2: List output_dir, find highest iteration number. Start at N+1.
PHASE 3: Plan creative directions — each agent gets a DIFFERENT theme/approach.
PHASE 4: Deploy sub-agents in parallel (Task tool). Each receives:
  - Full spec text
  - Current directory snapshot
  - Their assigned iteration number
  - Their unique creative direction
PHASE 5 (infinite mode): Loop in waves of 3-5 until context is low.
```

```bash
/project:infinite specs/component-spec.md src/ 5
/project:infinite specs/component-spec.md src/ infinite
```

Batching strategy:

| Count | Strategy |
|-------|----------|
| 1-5 | All agents simultaneously |
| 6-20 | Batches of 5 |
| infinite | Waves of 3-5, progressive sophistication |

Key insight: **uniqueness via assignment** — don't rely on agents to self-differentiate; the orchestrator assigns each one a specific creative direction and iteration number. This prevents duplicate concepts across parallel agents.

---

## 5. Continuous PR Loop

**A production-grade shell script** (`continuous-claude`) that runs in a continuous loop, creating PRs, waiting for CI, and merging automatically.

```
┌─────────────────────────────────────────────────────┐
│  CONTINUOUS CLAUDE ITERATION                        │
│                                                     │
│  1. Create branch (continuous-claude/iteration-N)   │
│  2. Run claude -p with enhanced prompt              │
│  3. (Optional) Reviewer pass — separate claude -p   │
│  4. Commit changes (claude generates message)       │
│  5. Push + create PR (gh pr create)                 │
│  6. Wait for CI checks (poll gh pr checks)          │
│  7. CI failure? → Auto-fix pass (claude -p)         │
│  8. Merge PR (squash/merge/rebase)                  │
│  9. Return to main → repeat                         │
│                                                     │
│  Limit by: --max-runs N | --max-cost $X             │
│            --max-duration 2h | completion signal    │
└─────────────────────────────────────────────────────┘
```

> Warning: install from its repository after reviewing the code. Do not pipe external scripts directly to bash.

```bash
# Basic: 10 iterations
continuous-claude --prompt "Add unit tests for all untested functions" --max-runs 10

# Cost-limited
continuous-claude --prompt "Fix all linter errors" --max-cost 5.00

# Time-boxed
continuous-claude --prompt "Improve test coverage" --max-duration 8h

# With code review pass
continuous-claude \
  --prompt "Add authentication feature" \
  --max-runs 10 \
  --review-prompt "Run npm test && npm run lint, fix any failures"

# Parallel via worktrees
continuous-claude --prompt "Add tests" --max-runs 5 --worktree tests-worker &
continuous-claude --prompt "Refactor code" --max-runs 5 --worktree refactor-worker &
wait
```

### Cross-Iteration Context: SHARED_TASK_NOTES.md

The critical innovation: a `SHARED_TASK_NOTES.md` file persists across iterations, bridging the context gap between independent `claude -p` invocations. Claude reads it at iteration start and updates it at iteration end.

```markdown
## Progress
- [x] Added tests for auth module (iteration 1)
- [x] Fixed edge case in token refresh (iteration 2)
- [ ] Still need: rate limiting tests, error boundary tests

## Next Steps
- Focus on rate limiting module next
- The mock setup in tests/helpers.ts can be reused
```

### CI Failure Recovery

When PR checks fail, the loop automatically:
1. Fetches the failed run ID via `gh run list`
2. Spawns a new `claude -p` with CI fix context
3. Claude inspects logs via `gh run view`, fixes code, commits, pushes
4. Re-waits for checks (up to `--ci-retry-max` attempts)

### Completion Signal

Claude can signal "I'm done" with a magic phrase:

```bash
continuous-claude \
  --prompt "Fix all bugs in the issue tracker" \
  --completion-signal "CONTINUOUS_CLAUDE_PROJECT_COMPLETE" \
  --completion-threshold 3  # Stops after 3 consecutive signals
```

Three consecutive completion signals stop the loop, preventing wasted runs on finished work.

### Key Configuration

| Flag | Purpose |
|------|---------|
| `--max-runs N` | Stop after N successful iterations |
| `--max-cost $X` | Stop after spending $X |
| `--max-duration 2h` | Stop after time elapsed |
| `--merge-strategy squash` | squash, merge, or rebase |
| `--worktree <name>` | Parallel execution via git worktrees |
| `--disable-commits` | Dry-run mode (no git operations) |
| `--review-prompt "..."` | Add reviewer pass per iteration |
| `--ci-retry-max N` | Auto-fix CI failures (default: 1) |

---

## 6. The De-Sloppify Pattern

**An add-on for any loop.** Add a dedicated cleanup/refactor step after each Implementer step.

### The Problem

Asked to implement with TDD, an LLM takes "write tests" too literally:
- Tests that verify the language/type system works (testing `typeof x === 'string'`)
- Overly defensive runtime checks for things the type system already guarantees
- Tests for framework behavior rather than business logic
- Excessive error handling that obscures the actual code

### Why Not Negative Instructions?

Adding "don't test type systems" / "don't add unnecessary checks" to the Implementer prompt has downstream effects: the model becomes hesitant about ALL testing, skips legitimate edge-case tests, and quality degrades unpredictably.

### The Solution: Separate Pass

Let the Implementer be thorough, then run a focused cleanup agent:

```bash
# Step 1: Implement (let it be thorough)
claude -p "Implement the feature with full TDD. Be thorough with tests."

# Step 2: De-sloppify (separate context, focused cleanup)
claude -p "Review all changes in the working tree. Remove:
- Tests that verify language/framework behavior rather than business logic
- Redundant type checks that the type system already enforces
- Over-defensive error handling for impossible states
- Console.log statements
- Commented-out code

Keep all business logic tests. Run the test suite after cleanup to ensure nothing breaks."
```

In a loop context:

```bash
for feature in "${features[@]}"; do
  claude -p "Implement $feature with TDD."
  claude -p "Cleanup pass: review changes, remove test/code slop, run tests."
  claude -p "Run build + lint + tests. Fix any failures."
  claude -p "Commit with message: feat: add $feature"
done
```

Key insight: two focused agents outperform one constrained agent.

---

## 7. RFC-Driven DAG Orchestration

**The most sophisticated pattern.** An RFC-driven, multi-agent pipeline that decomposes a spec into a dependency DAG, runs each unit through a tiered quality pipeline, and lands them via an agent-driven merge queue.

```
RFC/PRD Document
       │
       ▼
  DECOMPOSITION (AI)
  Break RFC into work units with dependency DAG
       │
       ▼
┌──────────────────────────────────────────────────────┐
│  RALPH LOOP (up to 3 passes)                         │
│                                                      │
│  For each DAG layer (sequential, by dependency):     │
│                                                      │
│  ┌── Quality Pipelines (parallel per unit) ───────┐  │
│  │  Each unit in its own worktree:                │  │
│  │  Research → Plan → Implement → Test → Review   │  │
│  │  (depth varies by complexity tier)             │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌── Merge Queue ─────────────────────────────────┐  │
│  │  Rebase onto main → Run tests → Land or evict │  │
│  │  Evicted units re-enter with conflict context  │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### RFC Decomposition

AI reads the RFC and produces work units:

```typescript
interface WorkUnit {
  id: string;              // kebab-case identifier
  name: string;            // Human-readable name
  rfcSections: string[];   // Which RFC sections this addresses
  description: string;     // Detailed description
  deps: string[];          // Dependencies (other unit IDs)
  acceptance: string[];    // Concrete acceptance criteria
  tier: "trivial" | "small" | "medium" | "large";
}
```

Decomposition rules:
- Prefer fewer, cohesive units (minimize merge risk)
- Minimize cross-unit file overlap (avoid conflicts)
- Keep tests WITH implementation (never separate "implement X" + "test X")
- Dependencies only where a real code dependency exists

The dependency DAG determines execution order:

```
Layer 0: [unit-a, unit-b]     ← no deps, run in parallel
Layer 1: [unit-c]             ← depends on unit-a
Layer 2: [unit-d, unit-e]     ← depend on unit-c
```

### Complexity Tiers

| Tier | Pipeline Stages |
|------|----------------|
| **trivial** | implement → test |
| **small** | implement → test → code-review |
| **medium** | research → plan → implement → test → PRD-review + code-review → review-fix |
| **large** | research → plan → implement → test → PRD-review + code-review → review-fix → final-review |

Expensive operations are skipped for simple changes; architectural changes get thorough scrutiny.

### Separate Context Windows (Author-Bias Elimination)

| Stage | Model | Purpose |
|-------|-------|---------|
| Research | Sonnet | Read codebase + RFC, produce context doc |
| Plan | Opus | Design implementation steps |
| Implement | Codex | Write code following the plan |
| Test | Sonnet | Run build + test suite |
| PRD Review | Sonnet | Spec compliance check |
| Code Review | Opus | Quality + security check |
| Review Fix | Codex | Address review issues |
| Final Review | Opus | Quality gate (large tier only) |

**Critical design:** the reviewer never wrote the code it reviews. This eliminates author bias — the most common source of missed issues in self-review.

### Merge Queue with Eviction

```
Unit branch
    │
    ├─ Rebase onto main
    │   └─ Conflict? → EVICT (capture conflict context)
    │
    ├─ Run build + tests
    │   └─ Fail? → EVICT (capture test output)
    │
    └─ Pass → Fast-forward main, push, delete branch
```

**File overlap intelligence:** non-overlapping units land speculatively in parallel; overlapping units land one-by-one, rebasing each time.

**Eviction recovery:** on eviction, full context is captured (conflicting files, diffs, test output) and fed back to the implementer on the next Ralph pass:

```markdown
## MERGE CONFLICT — RESOLVE BEFORE NEXT LANDING

Your previous implementation conflicted with another unit that landed first.
Restructure your changes to avoid the conflicting files/lines below.

{full eviction context with diffs}
```

### Data Flow Between Stages

```
research.contextFilePath ──────────────────→ plan
plan.implementationSteps ──────────────────→ implement
implement.{filesCreated, whatWasDone} ─────→ test, reviews
test.failingSummary ───────────────────────→ reviews, implement (next pass)
reviews.{feedback, issues} ────────────────→ review-fix → implement (next pass)
final-review.reasoning ────────────────────→ implement (next pass)
evictionContext ───────────────────────────→ implement (after merge conflict)
```

### Worktree Isolation

Every unit runs in an isolated worktree (jj/Jujutsu): `/tmp/workflow-wt-{unit-id}/`. Pipeline stages for the same unit **share** a worktree, preserving state (context files, plan files, code changes) across research → plan → implement → test → review.

### Key Design Principles

1. **Deterministic execution** — upfront decomposition locks in parallelism and ordering
2. **Human review at leverage points** — the work plan is the single highest-leverage intervention point
3. **Separate concerns** — each stage in its own context window with its own agent
4. **Conflict recovery with context** — full eviction context enables intelligent re-runs, not blind retries
5. **Tier-driven depth** — trivial changes skip research/review; large changes get maximum scrutiny
6. **Resumable workflows** — full state persisted to SQLite; resume from any point

### When to Use This vs Simpler Patterns

| Signal | Use RFC-DAG | Use Simpler Pattern |
|--------|-------------|-------------------|
| Multiple interdependent work units | Yes | No |
| Need parallel implementation | Yes | No |
| Merge conflicts likely | Yes | No (sequential is fine) |
| Single-file change | No | Yes (sequential pipeline) |
| Multi-day project | Yes | Maybe (continuous PR loop) |
| Spec/RFC already written | Yes | Maybe |
| Quick iteration on one thing | No | Yes (NanoClaw or pipeline) |

---

## Quality Gates, Evals, and Recovery

Recommended production stack, from decomposition to persistence:

1. RFC decomposition (pattern 7)
2. Quality gates — gate every landing on build + lint + tests (see `eval-harness` for the eval loop)
3. Eval loop (`eval-harness`) — score iterations against acceptance criteria, not just exit codes
4. Session persistence (NanoClaw REPL, pattern 2) — keep context across loop restarts

### Failure Modes

- Loop churn without measurable progress
- Repeated retries with the same root cause
- Merge queue stalls
- Cost drift from unbounded escalation

### Recovery Procedure

1. **Freeze the loop** — stop dispatching new work
2. **Run `/harness-audit`** — inspect what the loop actually did
3. **Reduce scope to the failing unit** — isolate the blocker
4. **Replay with explicit acceptance criteria** — restart with testable success conditions

---

## Choosing the Right Pattern

```
Is the task a single focused change?
├─ Yes → Sequential Pipeline or NanoClaw
└─ No → Is there a written spec/RFC?
         ├─ Yes → Do you need parallel implementation?
         │        ├─ Yes → RFC-Driven DAG
         │        └─ No → Continuous PR Loop
         └─ No → Do you need many variations of the same thing?
                  ├─ Yes → Infinite Agentic Loop
                  └─ No → Sequential Pipeline with de-sloppify
```

### Combining Patterns

1. **Sequential Pipeline + De-Sloppify** — the most common combination; every implement step gets a cleanup pass.
2. **Continuous PR Loop + De-Sloppify** — add `--review-prompt` with a de-sloppify directive to each iteration.
3. **Any loop + verification gate** — run the `/verify` command as a gate before commits.
4. **Tiered model routing in simpler loops** — route simple tasks to Haiku, complex tasks to Opus:

```bash
# Simple formatting fix
claude -p --model haiku "Fix the import ordering in src/utils.ts"

# Complex architectural change
claude -p --model opus "Refactor the auth module to use the strategy pattern"
```

---

## Common Mistakes

1. **Infinite loops without exit conditions** — always set max-runs, max-cost, max-duration, or a completion signal.
2. **No context bridge between iterations** — each `claude -p` call starts fresh; use `SHARED_TASK_NOTES.md`, memory files, or filesystem state.
3. **Retrying the same failure** — capture error context and feed it to the next attempt instead of blind retries.
4. **Negative instructions instead of cleanup passes** — don't say "don't do X"; add a separate pass that removes X.
5. **All agents in one context window** — separate concerns into different agent processes; the reviewer should never be the author.
6. **Ignoring file overlap in parallel work** — if two parallel agents might edit the same file, you need a merge strategy (sequential landing, rebase, or conflict resolution).

## Credits

| Project | Author |
|---------|--------|
| Ralphinho (RFC-driven DAG) | @enitrat |
| Infinite Agentic Loop | @disler |
| Continuous Claude | @AnandChowdhary |
| NanoClaw | `/claw` command in the ECC repo |
