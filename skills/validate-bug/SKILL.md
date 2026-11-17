---
name: validate-bug
description: Use when a suspected bug must be independently verified before patching — rerun a bug PoC package on the unchanged baseline, reproduce a named runtime or compiler bug, or decide whether a security finding is a true or false positive. Covers receipts, independent rerun, data-flow and exploitability analysis, gate reviews, and a documented verdict.
origin: merged from validate-bug, reproduce-bug, fp-check
---

# Validate Bug

Never trust a claim, a summary, or a reproducer's narrative. Either run it yourself on the unchanged baseline and keep receipts, or trace the full data flow and pass every gate before calling it real. Every verdict needs evidence; unreliable observations return `inconclusive`, never a guess.

## When to Use

- A bug PoC package needs an independent rerun and judgment before patching.
- A named runtime or compiler bug in a local repository needs independent reproduction.
- "Is this bug real?" / "is this a true positive?" / "is this a false positive?" / "verify this finding" / "is this vulnerability exploitable?"

## When NOT to Use

- Finding or hunting bugs, security analysis, or auditing code at large.
- General code review for style, performance, or maintainability.
- Patching or developing a fix — use `patching-bugs`. Repairing a PoC is also out of scope.
- A claim the build or environment cannot exercise: report a blocker instead.
- A quick scan without verification, when the user explicitly asks only for that.

## Record Discipline

Keep the run directory outside the tracked target tree. Save raw stdout, stderr, exit status, and timing for every observation, including valid controls. Manifest the whole step directory and check the record before each handoff. Transcribe results from receipts; never infer a passing check from an agent summary.

## Phase 0: Restate the Claim (every bug)

Restate the bug in your own words. If you cannot do this clearly, ask the user — half of false positives collapse at this step because the claim stops making sense when stated precisely.

Document:

- **Exact claim** — e.g. "heap buffer overflow in `parse_header()` when `content_length` exceeds 4096".
- **Alleged root cause** — e.g. missing bounds check before `memcpy` at line 142.
- **Supposed trigger** — e.g. an HTTP request with an oversized Content-Length header.
- **Claimed impact** — e.g. remote code execution via controlled heap corruption.
- **Threat model** — what privilege level the code runs at, whether it is sandboxed, and what the attacker can already do (unauthenticated remote vs privileged local user; renderer sandbox vs root).
- **Bug class** — classify it, then consult `references/bug-class-verification.md` for class-specific requirements (memory corruption, logic, race, integer, crypto, injection, info disclosure, DoS, deserialization).
- **Execution context** — when and how the path is reached in normal execution.
- **Caller analysis** — which functions call this code and what input constraints they impose.
- **Architectural context** — whether this sits inside a larger security system with multiple protection layers.
- **Historical context** — recent changes, known issues, previous reviews of this area.

## Phase 1: Reproduce on the Unchanged Baseline (repository mode)

Select `failure_type` from the record contract. Build the current baseline with the project's own command, and exercise the planned scoped inputs before any edit.

- **Runtime** — exercise the built `target_artifact` with a PoC that records `PATCH_LOADED`, then prints `PATCH_REACHED` immediately before the assertion. Exit nonzero for the bug, zero otherwise; a setup crash is inconclusive.
- **Compile** — record the target `expected_diagnostic` from the failed compiler invocation; use empty `poc_argv` and null `target_artifact`.

Outcomes:

- `reproduced` — the diagnostic or marker-plus-assertion demonstrates the claim. Set `finding.status` to `reproduced`.
- `not_reproduced` — the behavior is absent with trustworthy evidence. Set `finding.status` to `not_reproduced` and make no patch.
- `blocked` — setup or observations are unreliable, or the build cannot exercise the claim. State the actual failure and leave `finding.status` as `hypothesis`.

Save unchanged PoC source under `reproduce/poc/`, receipts under `reproduce/receipts/`, and write `reproduce.json`.

```json
// reproduce.json
{
  "schema_version": 1,
  "failure_type": "runtime",
  "outcome": "reproduced",
  "baseline_commit": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "build_argv": ["python", "build.py"],
  "poc_argv": ["python", "poc.py"],
  "target_artifact": "dist/app.py",
  "observed": "The PoC wrote outside uploads after PATCH_REACHED.",
  "blocker": null,
  "agent": "reproducer-1"
}
```

Manifest the complete `reproduce/` directory, including the PoC and record, then check it before handoff.

## Phase 2: Independent Rerun and Judgment (repository mode)

Give a different fresh agent only the finding, the complete `reproduce/` directory, and project guidance. Do not send the reproducer's transcript.

Rerun the same baseline compiler command, or rebuild and rerun the unchanged runtime PoC and planned scoped inputs. Save stdout, stderr, exit status, and timing in `validate/receipts/`. Decide whether the target diagnostic or runtime assertion demonstrates the exact claim and violates the stated invariant.

Write `validate.json` as `confirmed`, `not_confirmed`, or `inconclusive` with a short reason and agent identity. If an observation is unreliable, return `inconclusive` instead of inferring either presence or absence.

```json
// validate.json
{
  "schema_version": 1,
  "outcome": "confirmed",
  "agent": "validator-1",
  "reason": "The unchanged PoC reached the assertion and demonstrated the claim."
}
```

Manifest the complete `validate/` directory and check the record. Return the package without editing the PoC or finding.

## Phase 3: Route the Verification Path (claim mode)

Choose a path after Phase 0. Default to standard; standard has two built-in escalation checkpoints.

### Standard verification

Use when the claim is clear and specific, a single component is involved, the bug class is well understood, no concurrency is involved, and the data flow is straightforward. Work a linear checklist, documenting findings inline; no task tracking needed.

1. **Data flow** — trace source to the alleged sink. Map trust boundaries (trusted vs untrusted), list every validation and sanitization on the path, check API contracts for built-in bounds protection, and check environmental protections that prevent exploitation entirely. Pitfall: analyzing the vulnerable line in isolation — upstream conditionals may make it mathematically unreachable. Escalate if you find 3+ trust boundaries, callbacks/async control flow, or an ambiguous validation chain.
2. **Exploitability** — prove the attacker controls data reaching the vulnerable operation (internal storage set by trusted components is not attacker-controlled). For integer/bounds issues, write an explicit algebraic proof: IF validation_check_passes THEN bounds_guarantee_holds. For races, prove concurrent access is actually possible (single-threaded init and synchronized contexts cannot race).
3. **Impact** — separate real security impact (RCE, privesc, info disclosure) from operational robustness (crash recovery, cleanup failure), and primary controls from defense-in-depth. A failed defense-in-depth measure is not a vulnerability while primary protections hold.
4. **PoC sketch** — pseudocode `Data Flow: [Source] → [Validation?] → [Transform?] → [Vulnerable Op] → [Impact]`, plus attacker control and trigger. Executable and unit-test PoCs are optional at this depth.
5. **Devil's advocate spot-check** — answer all seven; escalate on genuine uncertainty.
   - Against the vulnerability: (1) am I pattern-matching "looks dangerous" instead of analyzing? (2) am I assuming attacker control over trusted data? (3) have I proven the mathematical condition? (4) am I confusing defense-in-depth failure with a primary vulnerability? (5) am I hallucinating it because LLMs over-report bugs?
   - For the vulnerability: (6) am I dismissing a real bug because the exploit looks complex or unlikely? (7) am I inventing mitigations or validation logic I have not verified in the actual source — re-read the code after concluding.
6. **Gate review** — apply all six gates and all 13 checks before any verdict.

### Deep verification

Use when the claim is ambiguous, the path crosses 3+ modules or services, the trigger involves race/TOCTOU/concurrency, a logic bug has no clear spec, standard verification was inconclusive, or the user asks for full verification. Create one task per phase with explicit dependencies:

```text
Phase 1 Data flow:      1.1 map trust boundaries + trace; then 1.2 API contracts,
                        1.3 environment protections, 1.4 cross-reference
Phase 2 Exploitability: 2.1 attacker control, 2.2 math bounds, 2.3 race feasibility;
                        then 2.4 adversarial analysis
Phase 3 Impact:         3.1 real security impact, 3.2 primary control vs defense-in-depth
Phase 4 PoC:            4.1 pseudocode + data flow; then 4.2 executable, 4.3 unit test,
                        4.4 negative PoC (preconditions and why they do not hold normally);
                        then 4.5 verify the PoC demonstrates the vulnerability
Phase 5:                devil's advocate review (13 questions)
Gate review:            all six gates
```

- Never start a phase until every task it depends on is complete; mark a task complete only with concrete evidence.
- Launch independent sub-phases in parallel; collect all results before the next dependency gate.
- Delegate phases 1, 2, and 4 to analysis subagents when available; handle impact, devil's advocate, and gates yourself — they need cross-phase synthesis.
- When escalating from standard, reuse the evidence already gathered and create tasks only for the remaining phases.
- Phase 1.3 distinction: ASLR and stack canaries raise the exploitation bar but do not eliminate the vulnerability; something like Rust's safe type system prevents exploitation entirely.
- Always create a pseudocode PoC; add executable and unit-test PoCs when feasible.

## Phase 4: Gates and Verdict

Before reporting any bug as a vulnerability, all six gates must pass.

| Gate | Criterion | Pass | Fail |
| --- | --- | --- | --- |
| 1. Process | All phases completed with documented evidence | Evidence exists for every phase | Phases lack concrete evidence |
| 2. Reachability | Attacker can reach and control data at the vulnerability | Attacker-controlled path plus PoC confirms | Cannot demonstrate control or reachability |
| 3. Real impact | Exploitation leads to RCE, privesc, or info disclosure | Direct impact with concrete scenarios | Only operational robustness issue |
| 4. PoC validation | PoC demonstrates the attack path | Shows attacker control, trigger, impact | PoC fails to show path or impact |
| 5. Math bounds | Analysis confirms the vulnerable condition is possible | Algebraic proof shows it is possible | Math proves validation prevents it |
| 6. Environment | No environmental protection entirely prevents exploitation | Protections do not eliminate the vulnerability | Protections block it entirely |

Verdict format:

- **TRUE POSITIVE** — all gates pass: `BUG #N TRUE POSITIVE — [brief vulnerability description]`
- **FALSE POSITIVE** — any gate fails: `BUG #N FALSE POSITIVE — [brief reason]`

If any phase fails, document the failure with evidence and continue the remaining phases; issue the FALSE POSITIVE verdict only after all phases are complete. In repository mode the verdict is `confirmed` / `not_confirmed` / `inconclusive` from the independent rerun, and receipts decide — a gate failure still forbids promoting a security claim to TRUE POSITIVE.

```text
BUG #3 FALSE POSITIVE — Integer underflow in packet_handler.c:142
  Gate 5 (Math Bounds) FAIL: validation at line 98 ensures packet_size >= 16,
  making (packet_size - header_size) >= 8. Underflow is mathematically impossible.
```

## Batch Triage

1. Run Phase 0 for all bugs first — restating each claim often collapses obvious false positives.
2. Route each bug independently; some may be standard, others deep.
3. Process all standard-routed bugs first, then deep-routed ones.
4. After all verdicts, check for exploit chains — findings that individually failed gate review may combine into a viable attack.

## Final Summary

After processing all suspected bugs, report: counts (X TRUE POSITIVES, Y FALSE POSITIVES), the TRUE POSITIVE list with a brief vulnerability description each, and the FALSE POSITIVE list with a brief rejection reason each.

## 13-Item False-Positive Checklist

Apply every item to every bug, not superficially:

1. Trace the full validation chain, not isolated snippets.
2. Map complete conditional logic flow — upstream conditions may create mathematical guarantees.
3. Identify defensive programming (assertions, checks) as defense, not vulnerability.
4. Confirm exploitable data paths step by step; never assume network data reaches the operation.
5. Understand data source trust levels: API return values, compile-time constants, internal storage.
6. Analyze bounds validation logic for the mathematical relationship between check and operation.
7. Verify TOCTOU: prove the checked value can change between check and use.
8. Understand API contracts and trust boundaries before claiming overflows.
9. Distinguish internal storage from external attacker input.
10. Do not confuse pattern recognition with vulnerability analysis.
11. Verify concurrent access is actually possible before claiming a race.
12. Assess real impact: would this give code execution, privilege escalation, or information disclosure?
13. Distinguish defense-in-depth failure from primary control failure.

## Rationalizations to Reject

| Rationalization | Required action |
| --- | --- |
| "Rapid analysis of remaining bugs" | Every bug gets full verification through all phases. |
| "This pattern looks dangerous, so it's a vulnerability" | Pattern recognition is not analysis; trace data flow first. |
| "Skipping full verification for efficiency" | No partial analysis; execute all steps on the chosen path. |
| "The code looks unsafe, report without tracing" | Trace the complete path from source to sink. |
| "Similar code was vulnerable elsewhere" | Verify this instance independently; validation and callers differ. |
| "This is clearly critical" | Run the devil's advocate review and prove it with evidence. |
| Fix the PoC to make the claim work. | Mark it inconclusive and explain why. |
| Trust the reproducer's conclusion. | Rerun the unchanged package independently. |
| A unit test imitates the bug, so it reproduced. | Exercise the target compiler or built runtime artifact. |
| A nonzero exit proves reproduction. | Require the target diagnostic, or the runtime marker and assertion. |

## References

- `references/standard-verification.md` — linear single-pass checklist with escalation checkpoints.
- `references/deep-verification.md` — full task tree, execution rules, and the 13-question devil's advocate review.
- `references/gate-reviews.md` — six gates and verdict format.
- `references/bug-class-verification.md` — class-specific requirements for memory corruption, logic, race, integer, crypto, injection, info disclosure, DoS, and deserialization.
- `references/false-positive-patterns.md` — 13-item checklist and red-flag catalog.
- `references/evidence-templates.md` — data flow, math proof, attacker control, PoC, and devil's advocate templates.
