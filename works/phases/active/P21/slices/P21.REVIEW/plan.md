# Plan — P21.REVIEW (phase review)

## Context

Read `works/phases/active/P21/phase.md` whole, `intent.md` whole, and the current `.claude/skills/review-phase/SKILL.md` — **as edited by this phase**: S2 moved doc consolidation out of the review, so this review runs under the rule this very phase shipped (the self-hosting decision is in `## Decisions`). The acceptance gate is **waived** (`required: false`), so the gated-phase stages (product walk, walkthrough, regression-checklist append) do not apply. P21 changed no operator-visible running product; its surfaces are `workflow.py` output, doctrine text, and the installer.

## What to review

1. **Validate all slices together.** Re-run the phase's cheap cumulative validation: `bash tests/retrofit_smoke.sh` (152 PASS expected), `python3 installer/build.py --check`, `python3 scripts/workflow.py validate` (expect exit 0 with exactly two known advisory warnings: none for consolidation yet, `oversized_doc_sections=5`), `python3 scripts/workflow.py docs-debt` (nothing owed yet), `python3 scripts/workflow.py next`. Spot-check the headline claims yourself, never on reports alone: in a scratch copy of the repo (session scratchpad), exercise the v38 deferral end-to-end once — a phase with doc-impact notes passes review → `consolidation: pending` stamped, no versions created, `next`/`validate` name it, archiving refused, `docs-debt` prints the worklist, `doc-new-version` → `rebuild-docs` → `docs-consolidated` clears it, archiving unblocks; and the legacy `execution.consolidation` shape behaves identically.
2. **Cross-check the notebook against every slice's `result.md`** (DECOMP, S1, DECOMP2, S2–S5): dropped decisions, unrouted questions, doc-impact lines missing from `phase.md` relative to what the slices actually changed. The `## Doc impact` list's **completeness** is this review's doc duty — verify it covers the real durable-truth changes (architecture, operations, decisions, qa at minimum); create **no doc versions** (the new rule; P21 owing consolidation after this review is expected, not a defect).
3. **Judge against the objective and `intent.md`:** the confirmed leak closed by deferral + carve-out; the five open questions answered by measurement or routed; retracted suspects not re-litigated; scope boundary held (adopter repos untouched — verify with git status on each if cheap, or via S1's recorded check); the intent.md "65 active" discrepancy note acknowledged.
4. **Route every `## Operator Questions` entry (OQ1–OQ4).** The gate is waived so there is no walkthrough to fold them into: for each, either (a) mark it answered/mooted by what landed, with the evidence, or (b) specify a concrete `defer-job --title/--reason/--trigger` for the orchestrator to file. An unrouted entry means the review may not pass.
5. **Consistency of the shipped v38:** CHANGELOG `## v38` covers S2–S5; `WORKSPACE_VERSION = 38`; doctrine sentences consistent across CLAUDE.md / agents / skills (spot-grep for leftovers of the old "review consolidates docs" rule).

## Verdict

Complete ALL validation and judgment before returning, whatever the verdict. Return: `review_verdict: pass|changes_requested|blocked` with numbered findings and proposed fix slices on a non-pass; `doc_versions: none — deferred (v38 rule); P21 owes consolidation after pass`; the OQ routing table (answered vs defer-job specs); `explain: not written — run /explain for this phase`; a one-line summary. On a non-pass, stop before any pass-only work.

## Boundaries

Executor runs no `review-phase`, no `accept-gate`, no `doc-new-version`, no `docs-consolidated`, no commits, no status transitions. Scratch-copy work stays in the session scratchpad. Write `result.md` verdict-block-first; edit `phase.md` under budget (consume the notes tagged for P21.REVIEW, rewrite `## Now` as the phase's closing state).
