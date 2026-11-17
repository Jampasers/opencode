---
name: social-publisher
description: Use when one idea must go out across multiple social platforms — adapt the copy per platform without posting identical text, preserve the author's voice, then publish, schedule, upload media, validate schedules, or monitor delivery via SocialClaw across 13 providers.
origin: merged from social-publisher, crosspost
---

# Social Publisher

Distribute one idea across platforms without turning it into the same fake post in four costumes: adapt per platform constraint, preserve the author's voice, then publish or schedule through SocialClaw.

## When to Use

- Publish the same underlying idea across multiple platforms.
- A launch, update, release, or essay needs platform-specific versions.
- The user says "crosspost", "post this everywhere", or "adapt this for X and LinkedIn".
- Publish to X, LinkedIn, Instagram, Facebook Pages, TikTok, Discord, Telegram, YouTube, Reddit, WordPress, or Pinterest.
- Schedule a campaign across platforms, upload media, validate a schedule before going live, or monitor run status and delivery analytics.

## Core Rules

1. Do not publish identical copy across platforms.
2. Preserve the author's voice across platforms.
3. Adapt for constraints, not stereotypes.
4. One post should still be about one thing.
5. Do not invent a CTA, question, or moral if the source did not earn one.

## Workflow

### 1. Pick the primary version

Choose the strongest source version first: the original X post, the original article, the launch note, the thread, or the memo/changelog. Use `content-engine` first if the source still needs voice shaping.

### 2. Capture the voice fingerprint

Run `brand-voice` first if the source voice is not already captured in the session, then reuse the resulting `VOICE PROFILE` directly. Do not build a second ad hoc voice checklist unless the user explicitly wants a fresh override for this campaign.

### 3. Adapt by platform constraint

**X**
- Keep it compressed.
- Lead with the sharpest claim or artifact.
- Use a thread only when a single post would collapse the argument.
- Avoid hashtags and generic filler.

**LinkedIn**
- Add only the context needed for people outside the niche.
- Do not turn it into a fake founder-reflection post.
- Do not add a closing question just because it is LinkedIn.
- Do not force a polished "professional tone" if the author is naturally sharper.

**Threads**
- Keep it readable and direct.
- Do not write fake hyper-casual creator copy.
- Do not paste the LinkedIn version and shorten it.

**Bluesky**
- Keep it concise.
- Preserve the author's cadence.
- Do not rely on hashtags or feed-gaming language.

For any other provider, the same five core rules apply: adapt to that platform's constraint instead of copying another platform's version.

### 4. Choose the posting order

Default: post the strongest native version first, adapt for the secondary platforms, and stagger timing only if the user wants sequencing help. Do not add cross-platform references unless they are useful — most of the time each post should stand on its own.

### 5. Publish or schedule via SocialClaw

Setup:

```bash
# Required: workspace API key from https://getsocialclaw.com/dashboard
export SC_API_KEY="<workspace-key>"

# Verify access
printf 'header = "Authorization: Bearer %s"\n' "$SC_API_KEY" |
  curl -sS -K - https://getsocialclaw.com/v1/keys/validate

# Install CLI (optional but recommended)
npm install -g socialclaw@0.1.12
socialclaw login --api-key <workspace-key>
```

Then:

```bash
# 1. List connected accounts
socialclaw accounts list --json
# connect if needed
socialclaw accounts connect --provider x --open
socialclaw accounts connect --provider linkedin --open

# 2. Upload media (optional)
socialclaw assets upload --file ./image.png --json   # -> { "asset_id": "..." }
```

```json
// 3. Build schedule.json — one entry per platform-specific variant
{
  "posts": [
    {
      "provider": "x",
      "account_id": "<account-id>",
      "text": "Post text here",
      "scheduled_at": "2026-06-01T10:00:00Z"
    }
  ]
}
```

```bash
# 4. Validate before publishing
socialclaw validate -f schedule.json --json

# 5. Publish
socialclaw apply -f schedule.json --json             # -> { "run_id": "..." }

# 6. Monitor
socialclaw status --run-id <run-id> --json
socialclaw posts list --json
```

## Banned Patterns

Delete and rewrite any of these:

- "Excited to share"
- "Here's what I learned"
- "What do you think?"
- "link in bio" unless that is literally true
- generic "professional takeaway" paragraphs that were not in the source

## Output Format

Return:

- the primary platform version
- adapted variants for each requested platform
- a short note on what changed and why
- any publishing constraint the user still needs to resolve

## Quality Gate

Before delivering:

- each version reads like the same author under different constraints
- no platform version feels padded or sanitized
- no copy is duplicated verbatim across platforms
- any extra context added for LinkedIn or newsletter use is actually necessary

## Supported Providers

| Provider | Key |
| --- | --- |
| X (Twitter) | `x` |
| LinkedIn profile | `linkedin` |
| LinkedIn page | `linkedin_page` |
| Instagram Business | `instagram_business` |
| Instagram standalone | `instagram` |
| Facebook Page | `facebook` |
| TikTok | `tiktok` |
| YouTube | `youtube` |
| Reddit | `reddit` |
| WordPress | `wordpress` |
| Discord | `discord` |
| Telegram | `telegram` |
| Pinterest | `pinterest` |

## Security

- Outbound requests go to `getsocialclaw.com` only.
- Provider OAuth lives in the SocialClaw dashboard — no per-provider secrets are exposed to the agent.
- `SC_API_KEY` is a workspace-scoped key.

## Related Skills

- `brand-voice` — reusable source-derived voice capture.
- `content-engine` — voice capture and source shaping.
- `x-api` — direct X/Twitter API operations.
- `social-graph-ranker` — network analysis for outreach targeting.
