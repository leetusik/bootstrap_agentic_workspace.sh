# P11.DECOMP — decompose "Free the orchestrator's idle window"

## Context

`P11` is created but not decomposed: only `P11.DECOMP` and `P11.REVIEW` exist. The operator's
confirmed intent (`works/phases/active/P11/intent.md`) asks for two changes on top of P10 (v19):

1. **Drop the bespoke `slice-planner` agent and recast the prefetch as an option, not a procedure.**
   P10 shipped a workspace-generated agent plus a rule that reads as a mandated sequence. The
   operator wants plain Claude Code behaviour (the built-in `Explore` agent when a delegated
   read-only search is the right tool) and, more importantly, a rule that *permits* using the
   executor's idle window rather than prescribing how. Hard invariants stay; P10's five skip
   conditions become guidance.
2. **Fix the two known-stale README spots** — targeted repair, not an accuracy audit.

This slice does **only** the decomposition: create the middle slices as bare folders and record the
breakdown, findings, and constraints in `phase.md`. No implementation, no pre-filled `plan.md`, no
doc versions.

Dispatch: `slice-executor-high` (decomposition always).

## What the executor must do

### 1. Read before deciding

- `works/phases/active/P11/intent.md` — scope, the invariants that stay hard, the skip conditions
  that become guidance, and the honesty requirement for the docs.
- The current rule text it will be replacing: `.claude/skills/do-whole-phase/SKILL.md` (the
  dispatch bullet's carve-outs at `:21` and the whole prefetch bullet at `:22`+) and the contract's
  Hard Rules bullet at `CLAUDE.md:62` / `AGENTS.md:62`, plus the *Driving This Workspace* clause at
  `:19`.
- `.claude/agents/slice-planner.md` — the file being deleted; its body is the prompt contract worth
  preserving in condensed form.
- `works/phases/active/P10/slices/P10.S1/result.md` § *Dispatch-prompt shape* — the same contract,
  already written out.

### 2. Findings the orchestrator verified while planning (carry them into `phase.md`)

- **Removing the agent is FOUR installer edits, not three.** The three that P10 added come out —
  `FIXED_LIVE_FILES` (`installer/build.py:49`), the explicit `write_text` (`installer/main.py:488`),
  and `MANAGED_FILES` (`installer/main.py:80`) — **and one is added**:
  `.claude/agents/slice-planner.md` must go into **`OBSOLETE_MACHINERY`** (`installer/main.py:517`,
  with the existing one-line "retired in vNN" comment style). `--update` never deletes; that list is
  how a workspace already on v19 is told to remove the file by hand. Without it, every adopting
  workspace silently keeps a dead agent.
- **The English README's agent inventory self-heals.** `README.en.md:173` says "the three
  risk-routed `slice-executor` tier subagents" and never mentioned `slice-planner` — the
  "under-count" P10's review flagged disappears the moment the agent is deleted. What is *actually*
  stale is the tier model in prose: `README.en.md:294-296` still calls `slice-executor-mid` "opus —
  medium-risk, the default". `README.en.md:173` and `:303-304` already carry the correct `economy`
  defaults.
- **The Korean README's table is stale in one cell:** `README.md:154` — `slice-executor-mid` = Opus,
  should be Sonnet. `README.md:166-167` already states the correct presets. So the README work is
  two factual corrections, one per file — not a rewrite.
- **Neither README mentions the prefetch at all**, so item 1 forces no README change. Whether to add
  a sentence about the idle window is a judgement call, not an obligation — decide it and record
  the decision.
- **READMEs are not embedded machinery** (not in `FIXED_LIVE_FILES`), so a README-only slice needs
  **no rebuild and no version bump**. Only the machinery slice does.
- `docs/current/operations.md` has a whole section titled *Pipelined slice planning — the
  `slice-planner` prefetch (since v19)*, and `decisions.md` carries the v0024 decision whose
  enforcement claim ("read-only by tool allowlist, not prose") this phase invalidates. Both are
  **`REVIEW`'s** job to supersede — middle slices only append "Doc impact" notes.

### 3. Create the middle slices

Recommended breakdown — **two** slices. Adjust only with a recorded reason, but keep the two intent
items separate: one is contract surgery, the other is a two-line factual fix.

- **`P11.S1` — Drop `slice-planner`; make idle-window preparation optional**
  (`--kind implementation`, `--risk high`, `--order 1`)
  - Delete `.claude/agents/slice-planner.md`; apply all four installer edits above.
  - Rewrite the `do-whole-phase` prefetch bullet as a **permission**: the executor's run is idle
    time on the main thread and the orchestrator **may** use it to prepare the next slice — by
    dispatching the built-in `Explore` agent, by reading inline itself, by thinking the slice
    through, or by simply waiting. No named required mechanism, no mandated sequence. State when it
    tends to pay off and when it does not, and leave the call to the orchestrator per slice.
  - Keep as **hard** rules only what protects the loop: read-only; never block (the executor's
    notification always wins); discard on any verdict other than `done`; drafts live in the session
    scratchpad and never become or are read as an approved plan; no second executor; the approval
    gate does not move.
  - Demote P10's five skip conditions (`DECOMP`, `REVIEW`, already-`ready`, `pending`,
    blast-radius overlap) to guidance — "cases where preparing ahead is usually pointless or
    unsafe".
  - Preserve the *useful* part of the deleted agent's prompt: fold a condensed version of the brief
    contract (bounded advisory brief; blast-radius staleness labelling; never a plan, never a file
    dump) into the skill itself, so the value survives the file's deletion without a new managed
    surface. Keep it short — it is guidance for an optional path.
  - Amend the dispatch bullet's carve-outs at `:21` so they no longer name `slice-planner`, and
    mirror the whole change into `CLAUDE.md` **and** `AGENTS.md` (`:19` clause and the `:62` Hard
    Rules bullet), bodies byte-equal.
  - `WORKSPACE_VERSION` 19 → 20, a new `## v20` CHANGELOG section whose **Migration notes must tell
    v19 workspaces to delete `.claude/agents/slice-planner.md`** (the `OBSOLETE_MACHINERY` flag
    surfaces it on `--update`, but it never deletes), and `python3 installer/build.py` with the
    rebuilt artifact.
  - Append a "Doc impact" note for `operations.md` (rewrite the v19 prefetch section as an optional
    idle-window practice) and one for `decisions.md` (supersede v0024's enforcement claim: with no
    bespoke agent, read-only is a discipline, not an allowlist guarantee).
  - `risk: high` — same reason as P10.S1: the wording sits inside the paragraphs carrying the
    delegation rule, the gate, `auto`'s safety halts, and the escalation ladder, and this time it is
    *relaxing* a rule, which is exactly where an over-broad edit does damage.

- **`P11.S2` — Refresh the stale README tier facts** (`--kind implementation`, `--risk low`,
  `--order 2`, `--depends-on P11.S1`)
  - `README.md:154` → `slice-executor-mid` = Sonnet. `README.en.md:294-296` → `slice-executor-mid`
    is sonnet, not opus. Nothing else unless S1's deletion made a specific line false.
  - No rebuild, no version bump, no CHANGELOG entry (READMEs are not shipped machinery) — state
    this in the slice's scope so its executor does not "helpfully" rebuild.
  - `risk: low` **only if** the slice's plan can name the exact lines and replacements; the low tier
    is a literal plan-follower. If `DECOMP` judges the wording needs bilingual judgement, rate it
    `medium` instead and say why.
  - `--depends-on P11.S1` for ordering only, so the READMEs are corrected against the final state.

`P11.REVIEW` already exists; do not create it and do not touch its `order`.

### 4. Seed `phase.md`

Fill *Context*, *Decomposition*, *Findings & Notes*, and *Constraints* with the breakdown above, the
verified findings from §2 (especially the four-edit installer rule and the `OBSOLETE_MACHINERY`
requirement), and the constraints both slices inherit: `CLAUDE.md`/`AGENTS.md` bodies byte-equal;
the two `do-next-slice` copies byte-identical apart from frontmatter and **untouched** by this phase;
the rebuild obligation for the machinery slice only; durable docs version at `REVIEW` only.

Do **not** pre-fill either middle slice's `plan.md`.

### 5. Write `result.md`, and stop

Which slices were created with what `kind`/`risk`/`order`, any breakdown decision that differs from
the recommendation and why, and anything the next planner needs. No commits, no status transitions
beyond the `new-slice` calls.

## Validation for this slice

- `python3 scripts/workflow.py validate` — clean.
- `python3 scripts/workflow.py next` — shows `P11.S1`.
- `python3 installer/build.py --check` — still in sync (this slice changes no machinery; a failure
  here is pre-existing and gets reported, not fixed).
- `works/backlog.md` lists `P11.DECOMP`, `P11.S1`, `P11.S2`, `P11.REVIEW` in order.

## Explicit non-goals for this slice

- No edits to `CLAUDE.md`, `AGENTS.md`, any `SKILL.md`, `.claude/agents/`, `installer/`, the
  READMEs, or `bootstrap_agentic_workspace.sh`.
- No `doc-new-version` and no edits under `docs/`.
- No change to P10's copy-based plan capture — explicitly out of scope for the whole phase.
- No commits.
