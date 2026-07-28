# P11.REVIEW — phase review

**Verdict: `pass`.** All four middle slices landed the phase objective, `intent.md`'s three items are
satisfied, and the two durable-doc areas are consolidated into `operations` **v0019** and `decisions`
**v0025**.

This review is the first to run under the rules `P11.S3` shipped — no phase explainer, and a
non-passing verdict stops before the pass-only work. Both rules were followed as written in
`.claude/skills/review-phase/SKILL.md`: validation and judgment were completed across every slice
before the verdict was formed, and consolidation ran only after the verdict settled on `pass`.

---

## 1. Validation — all four slices together, real outcomes

| # | Check | Outcome |
|---|---|---|
| 1 | `python3 scripts/workflow.py validate` | **PASS** — "Workflow validation passed." (re-run after consolidation, still clean) |
| 2 | `python3 installer/build.py --check` | **PASS** — "OK: bootstrap_agentic_workspace.sh is in sync with installer/ source" |
| 3 | `python3 scripts/workflow.py sync-agents --check` | **PASS** — "agent files in sync with executors.toml/defaults" (mode `economy` (default), 0 overrides; low sonnet@medium / mid sonnet@high / high opus@high) |
| 4 | `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | **PASS** — empty |
| 5 | `review-phase` copies identical below frontmatter (`tail -n +7` vs `tail -n +5`) | **PASS** — empty diff |
| 6 | `do-next-slice` copies identical below frontmatter | **PASS** — empty diff (untouched by this phase, as required) |
| 7 | `grep -c 'WORKSPACE_VERSION = 21' bootstrap_agentic_workspace.sh` | **PASS** — `1` |
| 8 | `CHANGELOG.md` has `## v21` **and** still `## v20` | **PASS** — `:12` `## v21 — 2026-07-28`, `:56` `## v20 — 2026-07-28`, `:98` `## v19` intact below them |
| 9 | No live `slice-planner` reference (`grep -rn`, excluding `.git/`, `works/`, `docs/`) | **PASS** — exactly the three expected hits: `installer/main.py:519` (`OBSOLETE_MACHINERY`), its mirror at `bootstrap_agentic_workspace.sh:679`, and the historical `## v19`/`## v20` CHANGELOG sections. `scripts/workflow.py` → 0. |
| 10 | No live `auto-explain` / `auto-save` reference (same scope) | **PASS** — only `CHANGELOG.md` (two historical v16 lines + the v21 lines *describing* the reversal). Nothing in `.claude/`, `.agents/`, `.codex/`, `installer/`, `scripts/`, or the contracts. |
| 11 | Third-phrasing sweep: `grep -rni 'phase explainer\|explainer'` over `installer/`, `.claude`, `.agents`, `.codex`, `scripts`, both contracts | **PASS** — every hit is pointer-style or operator-run `/explain`; no surface claims a review produces one. `grep -rn KB_ROOT` over live machinery → **0** (carve-out gone). |
| 12 | `WebSearch`/`WebFetch` retained | **PASS** — `.claude/agents/slice-executor-high.md:4` `tools: Read, Edit, Write, Glob, Grep, Bash, WebSearch, WebFetch` |
| 13 | Neighbouring invariants intact in both contracts | **PASS** — "as a background task", "plan → operator approves the readied plan → executor", `auto` "strictly opt-in" + its halts, "at most 2 escalations per slice", `plan only` / `ready` (×3), "exactly two context files", and P10's copy-based capture ("copying the operator-approved harness plan file byte-exact") all present, once each, in `CLAUDE.md` and `AGENTS.md`. |
| 14 | **Fresh end-to-end install probe** | **PASS** — see below |
| 15 | README consistency (`README.en.md` ↔ `README.md` ↔ v21) | **PASS** — see §2 item 2 |

### Row 14 — the fresh install probe (the row that mattered most)

Probe root: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/e928efe8-a4ce-400f-8417-b9be6cb5ed57/scratchpad/probe-p11-review2/ws`
(`sh bootstrap_agentic_workspace.sh <probe>/ws --name probe-p11-review2`, from the committed
artifact).

- `works/.workspace-version.json` → `"workspace_version": 21` ✅
- `.claude/agents/` = exactly `slice-executor-{low,mid,high}.md`; `.codex/agents/` = the three
  `.toml` counterparts. No `slice-planner` ✅
- `grep -rl 'slice-planner\|auto-explain\|auto-save' <probe>` → **nothing, anywhere in the tree** ✅
- **The critical one:** the seeded `docs/versions/operations/v0001_bootstrap.md` `## Knowledge (phase
  explainers)` section now reads *"Explaining is an **operator-run step, separate from the phase
  review**… The review itself writes no explainer — it only reports the pointer"*. A fresh workspace
  carries **no false claim** ✅
- The closing bootstrap banner printed the corrected knowledge line ("an operator-run step; the phase
  review writes none") ✅
- "stop here and hand back" present in **both** probe `review-phase` copies ✅; the pointer line
  present in `.claude`/`.agents` `review-phase` (×1 each), both `slice-executor-high` files (×2 each)
  and `CLAUDE.md`/`AGENTS.md` (×2 each) ✅
- `python3 <probe>/scripts/workflow.py validate` → "Workflow validation passed." ✅

---

## 2. Judgment against the objective, `intent.md`, and the results

**Item 1 — does the idle-window rule read as a permission?** Yes, read cold. The
`do-whole-phase` bullet (`SKILL.md:22`) opens *"While executor N runs you are idle on the main
thread — you **may** use that window to prepare for slice N+1"*, and closes the paragraph with
*"None of it is required and no mechanism is prescribed — choose per slice, and prefer waiting when
there is nothing useful to learn yet. The goal is efficient, high-quality work, not a procedure to
follow."* The limits follow the permission and are explicitly framed as constraining the *how*, never
the *whether*; the five P10 conditions live under a sub-bullet headed **"Judgment, not a checklist"**
ending *"Weigh these; do not tick them off."* The contract's Hard Rules bullet mirrors it in third
person. This is "you may, and here is how to judge it", not "do this, unless…" — it meets the
operator's standard. `Explore` named as "the natural fit" is the right call: a suggestion, not a
requirement.

**Item 2 — the READMEs.** Accurate after S2 + S4. The Korean tier table (`README.md:150-156`) reads
Sonnet / Sonnet / Opus and matches the preset prose ten lines below it; `README.en.md:293-305` reads
`mid` as sonnet with no "the default" claim and names `high` as the catch-all ("anything not rated
`low` or `medium`"), matching the shipped `economy` default that `sync-agents --check` reports. No
explainer claim survives in either file: `README.en.md:46-48`, `:274-281` and `:296-298` now say
explainers are produced on demand via `/explain` and that a verdict short of `pass` "stops there and
hands its findings back"; `README.md` never made an explainer claim. The three files agree with each
other and with v21.

**Item 3 — the review's own contract.** Auto-explain is gone from every live path (rows 10-11) and
replaced by one fixed, verdict-independent pointer. The KB-repo carve-out is deleted, not narrowed —
both `slice-executor-high` files read "no exception anywhere: not in this workspace's repo and not in
any other git root, on any slice kind", and `KB_ROOT` appears nowhere in live machinery.
`WebSearch`/`WebFetch` remain per the operator's call. The fail-fast wording carries the distinction
that matters: every surface states the order — complete validation and judgment across all slices
first, *then* branch — and names what is skipped ("doc consolidation … and no other pass-only step")
rather than saying "stop the review", with *"This is a full stop, not a skipped step you carry on
past."* as the clincher. **Judged from the inside:** this review executed exactly that shape without
ambiguity, which is the strongest evidence the wording works.

**Invariants and neighbours:** intact (row 13). P10's copy-based plan capture is untouched, as scoped.

### Items referred to this review

1. **`P11.S3`'s deviation — the two "auto-save" surfaces — is correct and complete. Ratified.**
   `installer/main.py:633` (the bootstrap banner) and
   `installer/payloads/doc_bodies/operations.md` (the body seeded as every new workspace's
   `operations` v0001) both now state that explaining is operator-run and the review writes none. The
   probe confirms it end to end: the banner printed correctly, and the seeded v0001 in a freshly
   bootstrapped workspace carries no false claim. A wider sweep for `phase explainer|explainer` across
   `installer/`, the skills, the agents and the contracts (row 11) found **no third missed surface**.
   Fixing these inside S3 was right — they are embedded machinery, and leaving them would have shipped
   the removed behaviour as documented truth to every future workspace. The lesson is recorded in the
   new `operations` version and in the `decisions` entry.
2. **`P11.S1`'s deviation — `grep -c 'slice-planner' <artifact>` = 1, not 0 — is correct.** The
   plan's expectation was self-contradictory: the artifact *is* `installer/main.py` plus payloads, so
   the `OBSOLETE_MACHINERY` entry the same plan mandates necessarily rides in it. The single hit
   (`:679`) is exactly that entry, and the check's intent holds strictly — `grep -rl` over the whole
   fresh-install probe returns nothing. Recorded in `operations` v0019 as the standing expectation for
   every future retirement entry.
3. **Both P10-era follow-ups are closed, not carried forward. Agreed, explicitly.**
   - The README refresh is **done** (S2's two tier facts + S4's three explainer passages); nothing
     stale remains that this phase touched.
   - The `slice-planner`-outside-`EXECUTOR_TIERS` gap is **dissolved by deletion** — `EXECUTOR_TIERS`
     is still `("low", "mid", "high")`, `scripts/workflow.py` contains zero references to the agent,
     and the file is gone. There is nothing left to fix or defer.
   - P10's third follow-up (lowering `slice-planner`'s `effort`) was already moot. **No P10 follow-up
     remains open.**

**Nothing rose to a `changes_requested`.** Every deviation in the phase was either an error in a
plan's expectation (S1) or a deliberate, correctly-scoped widening that prevented shipping a false
claim (S3); S2 and S4 had none.

---

## 3. Doc consolidation (pass-only — run because the verdict is `pass`)

`phase.md` carried **four** Doc-impact notes (two from `P11.S1`, two from `P11.S3`), consolidated into
**two** versions, each covering the whole phase. Each was verified against the actual current file,
not the line numbers in the notes.

**`docs/versions/operations/v0019_…md`** (v0018 → v0019) —
`doc-new-version --doc operations --source P11.REVIEW`, edited at the returned `edit_path`, then
`rebuild-docs`:

- *Auto-explain at the phase review (since v16)* → replaced by ***The phase review — validate, then
  branch on the verdict (v21 supersedes the v16 auto-explain)*: validate + judge first, then branch;
  `pass` consolidates, `changes_requested`/`blocked` stops and hands back; no explainer, one fixed
  pointer identical on every verdict; the KB-repo carve-out deleted; `WebSearch`/`WebFetch` retained;
  plus the v21 grep lesson (`auto-save`, the banner, the seeded doc body).
- *Pipelined slice planning — the `slice-planner` prefetch (since v19)* → ***Idle-window preparation —
  optional, `do-whole-phase` only (v19, recast in v20)*: the agent retired (four installer edits, the
  fourth load-bearing), the rule now a permission with no prescribed mechanism, the hard limits kept,
  the five conditions demoted to judgment, the delegation brief folded in, and the **weakened
  enforcement stated plainly** — read-only is discipline now, not a tool-allowlist guarantee.
- The *Status* running paragraph (`:33`), the update **write policy** (`:81`) and the **no-pruning**
  bullet (`:83`) recast off `slice-planner`; the *Knowledge setup (v17)* section's two review-time
  claims recast to operator-run `/explain`; the *Building and releasing* section gained the
  counterpart lesson — **retiring** an agent file takes FOUR edits, and the artifact grep is expected
  to be 1, not 0.

**`docs/versions/decisions/v0025_…md`** (v0024 → v0025) — **supersede, don't erase**:

- Two new decisions at the head of the log: *Retire the bespoke `slice-planner` agent…* (v20) and
  *Take auto-explain out of the phase review, and stop a non-passing review before the pass-only
  work* (v21) — each with context (the operator's verbatim reasoning), the sub-decisions, rejected
  alternatives, and consequences including the accepted trade-off (enforcement → discipline) and the
  two-surfaces lesson.
- P10's and P8's entries **kept as history**, each with its `Status:` line annotated in place
  ("partly superseded by P11" / "**reversed** by P11") pointing at the new entry.
- Two new `## Superseded Decisions` records spelling out exactly what fell and what carried forward —
  including that P8's pass-gating principle survives *generalised* and that `WebSearch`/`WebFetch`
  are explicitly **kept**.
- Status count 22 → 24; the Status paragraph gained P11's summary.

`python3 scripts/workflow.py validate` after `rebuild-docs`: **PASS** (it catches a stale
`docs/current`). `git status` shows only `docs/` plus workflow state — no source, no skills, no
contract, no READMEs touched by this slice.

---

## 4. Explainer

    explain: not written — run /explain for this phase

Per v21 the review writes no phase explainer: no explain skill was located, no KB probe run, no
fallback, no commit anywhere. The pointer is reported identically regardless of verdict.

---

## 5. Deviations from `plan.md`

**One, cosmetic and forced by the engine.** The plan's §3 prescribed `doc-new-version --summary`
verbatim-length summaries; the first `decisions` attempt failed with
`OSError: [Errno 63] File name too long` because `new_doc_version()` slugifies the full summary into
the filename with no truncation (the attempted name was ~310 chars). Re-run with a shorter summary,
which succeeded; no state was mutated by the failed attempt (it raised before any write — verified:
`docs/index.json` was unchanged and no partial file existed). The doc content is unaffected.
**Worth knowing for future reviews:** keep `--summary` under roughly 200 characters, or
`doc-new-version` will crash on the path length. Not a P11 defect — a pre-existing engine sharp edge.

Everything else followed the plan.
