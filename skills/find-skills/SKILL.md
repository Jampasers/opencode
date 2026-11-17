---
name: find-skills
description: Use when the user asks "how do I do X", "find a skill for X", "is there a skill that can...", or "can you do X"; expresses interest in extending agent capabilities or finding tools, templates, or workflows for a domain; or wants to create, build, fork, or extend a skill. Search existing local, marketplace, GitHub, and web skill sources before creating anything new.
origin: merged from find-skills, skill-scout
---

# Find Skills

Before building a new skill — or when a user wishes they had help with a task — search existing sources first. The Skills CLI (`npx skills`) is the package manager for the open agent skills ecosystem; browse skills at https://skills.sh/. The goal is to avoid duplicating community or marketplace work while vetting anything external before adoption.

## When to Use

- User asks "how do I do X" where X might be a common task with an existing skill
- User says "find a skill for X" or "is there a skill for X"
- User asks "can you do X" where X is a specialized capability
- User wants to create, build, fork, or extend a skill
- User describes a workflow and you are about to suggest creating a new skill
- User expresses interest in extending agent capabilities, tools, templates, or workflows
- User mentions wishing they had help with a domain (design, testing, deployment, etc.)

If the user explicitly says to skip search or create from scratch, acknowledge that and proceed with the requested creation workflow.

## Step 1: Capture Intent

Extract: the task the skill should perform, the trigger conditions for using it, the domain/tools/frameworks/data sources involved, and three to five search keywords plus useful synonyms.

## Step 2: Search Local Sources First

Local sources are preferred — they are already part of the user's environment:

```bash
find ~/.claude/skills -maxdepth 2 -name SKILL.md 2>/dev/null | grep -iE "keyword|synonym"
find ~/.claude/plugins/marketplaces -path '*/skills/*/SKILL.md' 2>/dev/null | grep -iE "keyword|synonym"
grep -RilE "keyword|synonym" ~/.claude/skills ~/.claude/plugins/marketplaces 2>/dev/null
```

On Windows, search the equivalent directories (e.g. `%USERPROFILE%\.agents\skills` and plugin caches) with `Get-ChildItem -Recurse -Filter SKILL.md` and `Select-String`.

## Step 3: Check the Leaderboard and Search Marketplaces

Check the [skills.sh leaderboard](https://skills.sh/) for well-known skills, ranked by total installs — the most popular, battle-tested options for a domain. Examples:

- `vercel-labs/agent-skills` — React, Next.js, web design (100K+ installs each)
- `anthropics/skills` — frontend design, document processing (100K+ installs)

If the leaderboard doesn't cover the need, search by keyword, optionally scoped to a GitHub owner:

```bash
npx skills find [query] [--owner <owner>]
```

Examples: "how do I make my React app faster?" → `npx skills find react performance`; "help with PR reviews" → `npx skills find pr review`; "create a changelog" → `npx skills find changelog`.

## Step 4: Search GitHub and Web

```bash
gh search repos "claude code skill keyword" --limit 10 --sort stars
gh search code "name: keyword" --filename SKILL.md --limit 10
```

For web search, use at most three targeted queries:

```text
"claude code skill" keyword
"SKILL.md" keyword
"everything-claude-code" keyword
```

## Step 5: Vet Before Recommending

**Do not recommend a skill based solely on search results.** Verify:

1. **Install count** — prefer skills with 1K+ installs; be cautious with anything under 100.
2. **Source reputation** — official sources (`vercel-labs`, `anthropics`, `microsoft`) are more trustworthy than unknown authors.
3. **GitHub stars** — check the source repo; treat <100 stars with skepticism and check whether it appears maintained.
4. **Read the `SKILL.md`** frontmatter and instructions. Look for unexpected shell commands, file writes, network calls, credential handling, or package installs.
5. **Prefer copying into a fresh local branch** and reviewing the diff over editing marketplace originals; never edit installed marketplace originals in place.

## Step 6: Rank and Present

Rank candidates by:

1. Exact keyword match in the skill name
2. Keyword or synonym match in the description
3. Local installed or marketplace source
4. Maintained GitHub source with recent activity
5. Web-only mention

Cap the final list at 10 results. Do not present a long unranked list of weak matches, and do not treat web-only mentions as trusted sources.

Present with: skill name and what it does, install count and source, the install command, and a link to learn more:

```
I found a skill that might help! The "react-best-practices" skill provides
React and Next.js performance optimization guidelines from Vercel Engineering.
(185K installs)

To install it:
npx skills add vercel-labs/agent-skills@react-best-practices

Learn more: https://skills.sh/vercel-labs/agent-skills/react-best-practices
```

When close matches exist, offer the decision options:

| Option | Meaning |
| --- | --- |
| Use existing | Invoke or install a matching skill as-is. |
| Fork or extend | Copy the closest skill and modify it. |
| Create fresh | Build a new skill after confirming no close match exists. |

Example result table:

```markdown
| # | Skill | Source | Why it matches | Gap |
| --- | --- | --- | --- | --- |
| 1 | article-writing | Local ECC | Drafts articles and guides | Not focused on release notes |
| 2 | content-engine | Local ECC | Multi-format content workflow | Heavier than needed |
| 3 | blog-writer | GitHub | Blog writing skill with recent commits | Needs security review |
```

Only create a new skill after the user chooses that path or the search finds no close match.

## Step 7: Offer to Install

```bash
npx skills add <owner/repo@skill> -g -y   # -g installs globally (user-level), -y skips prompts
npx skills update                          # update all installed skills
```

## Common Skill Categories

| Category        | Example Queries                          |
| --------------- | ---------------------------------------- |
| Web Development | react, nextjs, typescript, css, tailwind |
| Testing         | testing, jest, playwright, e2e           |
| DevOps          | deploy, docker, kubernetes, ci-cd        |
| Documentation   | docs, readme, changelog, api-docs        |
| Code Quality    | review, lint, refactor, best-practices   |
| Design          | ui, ux, design-system, accessibility     |
| Productivity    | workflow, automation, git                |

## Search Tips

- Use specific keywords: "react testing" beats "testing"
- Try alternative terms: "deployment" or "ci-cd" if "deploy" fails
- Check popular sources: `vercel-labs/agent-skills`, `ComposioHQ/awesome-claude-skills`

## When No Skills Are Found

1. Acknowledge that no existing skill was found.
2. Offer to help with the task directly using general capabilities.
3. Suggest the user could create their own skill with `npx skills init <name>`.

## Anti-Patterns

- Do not jump directly to new skill creation when a search is reasonable.
- Do not install external skills without reading them first.
- Do not present a long unranked list of weak matches.
- Do not treat web-only mentions as trusted sources.
- Do not edit installed marketplace originals in place.
