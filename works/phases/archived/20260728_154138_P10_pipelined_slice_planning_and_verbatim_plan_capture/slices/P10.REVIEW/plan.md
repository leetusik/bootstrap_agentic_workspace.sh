# P10.REVIEW — phase review

## Context

Both middle slices are landed and committed:

- **`P10.S1`** (`4089004`) — read-only `.claude/agents/slice-planner.md` + all three installer
  touchpoints; the `do-whole-phase` loop now prefetches slice N+1's research during executor N's
  run and reconciles instead of re-researching; carve-outs mirrored byte-equally into
  `CLAUDE.md`/`AGENTS.md`; shipped as workspace **v19**.
- **`P10.S2`** (`c94f6e4`) — approved plans are now persisted by **copying** the harness plan file
  (all four rule sites), with `Write` kept as the fallback for Codex and `auto`; `Bash(cp:*)` added
  to `.claude/settings.json`; appended to the open `## v19` CHANGELOG section without a bump.

This slice validates the phase as a whole against `intent.md`, decides a verdict, and — **only on a
pass** — consolidates the phase's four "Doc impact" notes into new doc versions and produces the
phase explainer.

Dispatch: **`slice-executor-high`** (review always). It writes **only docs** — never source, never
skills, never the contract. Anything requiring a code or prose fix is `changes_requested` with
proposed fix slices, not an edit.

## 1. Validate all of the phase's slices together

Run and report real outcomes:

- `python3 scripts/workflow.py validate` — state integrity, and it also catches a stale
  `docs/current`.
- `python3 installer/build.py --check` — the artifact matches `installer/` source.
- `python3 scripts/workflow.py sync-agents --check` — still exit 0 (`slice-planner` sits outside
  `EXECUTOR_TIERS` by design).
- `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` — empty.
- `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` — empty.
- `grep -c 'WORKSPACE_VERSION = 19' bootstrap_agentic_workspace.sh` → 1; `grep -c '^## v20' CHANGELOG.md` → 0.
- **One fresh end-to-end install probe covering both slices** — install into an unused scratch dir
  (`<scratchpad>/probe-review`) and confirm in the *probe*: `.claude/agents/slice-planner.md`
  exists byte-identical to source; `.claude/settings.json` contains `Bash(cp:*)`; the prefetch
  bullet is present in `do-whole-phase/SKILL.md` and **absent** from both `do-next-slice` copies;
  the copy rule is present in all four rule sites; `works/.workspace-version.json` shows
  `workspace_version: 19`. This is the check that catches dead payload — do not substitute greps
  of the repo for it. If it genuinely cannot run, say so explicitly rather than skipping silently.

## 2. Review against the objective, `intent.md`, and the results

Judge whether the phase delivered **both** intent items and honoured the non-goals — read
`intent.md`, `phase.md`, and both `result.md` files. Specifically confirm:

- The operator's approval gate did **not** move; `auto`'s safety halts, the escalation ladder,
  `plan only` / `ready`, the delegation rule, and "each slice owns exactly two context files" are
  all intact.
- The prefetch is `do-whole-phase`-only — `do-next-slice` never prefetches (explicit non-goal) —
  and is read-only by tool allowlist, not merely by prose.
- No `executors.toml` / `sync-agents` fourth tier; no Codex counterpart for the planner.
- The two slices read as **one coherent release**: the `## v19` CHANGELOG section and its Migration
  notes should not read as two glued halves. Note that S2's Migration line deliberately corrects
  S1's "`do-next-slice` untouched" claim (true only of the prefetch change) — check it reads as a
  correction, not a contradiction.

**Three items the slices explicitly referred to this review.** Decide each; none is automatically a
blocker:

1. **S2's terser `plan only` bullet** in `do-whole-phase/SKILL.md` — it says "the same
   confirm-then-copy rule as the default loop above" instead of re-spelling the rule a third time
   in one file. Judge whether the same-file back-reference is clear enough for an agent following
   the skill cold. If not → `changes_requested` with a fix slice.
2. **Stale READMEs** (not machinery, not in either slice's scope, so deliberately untouched):
   `README.en.md:170-175` under-counts the `.claude/agents/` inventory now that `slice-planner`
   exists, and `README.md`'s Korean tier table (~lines 153-155) has been stale since `b26d622`
   (still lists `slice-executor-mid` as Opus). **Do not edit them here** — a review slice writes
   only docs. Recommend either a fix slice in this phase or a follow-up, and record the
   recommendation in `result.md`.
3. **`effort: xhigh` on `slice-planner`** — the value the plan fixed, but its DECOMP rationale
   ("matches the `flex` preset's low tier") went stale with `b26d622`. It is pinned in-file and
   deliberately independent of the presets. Sanity-check it and recommend; do not change it.

Also note in `result.md` (for the orchestrator to file after the phase, since executors cannot run
`defer-job`): `slice-planner` sits outside `EXECUTOR_TIERS`, so it has no `executors.toml` knob and
no `validate` drift warning after `/update-workspace`.

## 3. On a pass — consolidate the docs

Only on `pass`. Use `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..."
--source P10.REVIEW`, then write the new version file's body. Never patch `docs/current/*.md` or an
old version.

The four "Doc impact" notes in `phase.md` consolidate into **two** new versions:

- **`operations.md`** (v0017 → next) — the pipelined `do-whole-phase` loop *and* copy-based plan
  capture as they stand at v19: the `slice-planner` agent (tools, pinned model, outside
  `executors.toml`/`sync-agents`), the five skip conditions + blast radius, never-block /
  discard-on-non-`done` / scratchpad-only, per-slice sizing, `do-whole-phase`-only scope with the
  gate unmoved; and the copy rule with its confirm-before-copy guard (load-bearing — the harness
  reuses one plan file per session), the append-after-copy rule, and the `Write` fallback for Codex
  and `auto`.
- **`decisions.md`** (v0023 → next) — the two P10/v19 decisions with alternatives, enforcement
  mechanism, and accepted trade-offs, exactly as the two `decisions.md` notes in `phase.md` spell
  out (including the `Bash(cp:*)` allowlist rationale: it grants nothing beyond the already-allowed
  `Write` tool).

Carry the existing content forward — a new version is the whole doc, not a diff. Then confirm
`python3 scripts/workflow.py validate` is still clean (it flags a stale `docs/current`).

## 4. On a pass — auto-explain (best-effort, verdict-neutral)

After the docs, produce the phase explainer by locating and following the installed knowledge
plugin's explain skill, exactly as `.claude/skills/review-phase/SKILL.md` specifies (P9's review
found it at `~/.claude/skills/explain/SKILL.md` when the project had none). Report the outcome as
`saved <path-or-url>` / `skipped (<reason>)` / `skipped-offline` / `failed (<reason>)`. **It never
changes the verdict.**

## 5. Report

Write `works/phases/active/P10/slices/P10.REVIEW/result.md`: the validation table with real
outcomes, the verdict with its reasoning, the three referred items and how each was decided, the
doc versions created, and the auto-explain outcome. Append any durable cross-slice notes to
`phase.md`.

Return `review_verdict` (`pass` | `changes_requested` | `blocked`), `doc_versions`, and `explain`.
On `changes_requested`, propose numbered fix slices (`P10.F1`, …) with a one-line scope each. You
never commit and never transition slice/phase status — the orchestrator records the verdict with
`review-phase`.
