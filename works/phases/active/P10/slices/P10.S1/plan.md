# P10.S1 — Pipelined prefetch in `do-whole-phase`

## Context

`do-whole-phase` is strictly serial today: plan N → dispatch executor N → **idle for the whole run**
→ N returns → research + plan N+1 → gate → dispatch N+1. The idling is mandated by the sentence
"wait for its completion notification, doing nothing else in the meantime" (`CLAUDE.md:19`,
`do-whole-phase/SKILL.md:21`, and both `do-next-slice` copies), which exists to forbid *inline
synchronous execution* — not to forbid read-only research.

Research for slice N+1 does not depend on slice N finishing; only the reconciliation does. This
slice moves that research into the idle window via a new **read-only prefetch subagent**, and
changes the orchestrator's post-executor step from "research and plan" to "reconcile and plan".
**The operator's approval gate does not move** — the operator still approves plan N+1 after seeing
slice N's `result.md`, verdict, and updated `phase.md`.

Scope is fixed by `works/phases/active/P10/intent.md` (item 1) and the decomposition in
`works/phases/active/P10/phase.md` — read both first; the design decision on the subagent is
already **settled** there and must not be re-litigated. `P10.S2` handles the unrelated `cp` plan
capture; this slice does not touch it.

Dispatch tier: **`slice-executor-high`** (`risk: high` — the new wording sits inside the paragraphs
carrying the delegation rule, the approval gate, `auto`'s safety halts, and the escalation ladder).

## Work

### 1. New agent file — `.claude/agents/slice-planner.md`

Model it on `.claude/agents/slice-executor-high.md`. Frontmatter is fixed by the DECOMP decision:

```
name: slice-planner
description: <read-only research for an upcoming slice; returns a compact brief — never a plan,
             never a file dump, never an implementation>
tools: Read, Glob, Grep
model: sonnet
effort: xhigh
permissionMode: bypassPermissions
```

Body must establish:

- **What it is.** Read-only research for a slice that has *not* been planned yet, dispatched while
  another slice's executor is still running. Its brief is **advisory input** to the orchestrator's
  own plan — never an approved plan, and it may be discarded without notice.
- **Inputs arrive by path in the dispatch prompt** — the next slice's id and folder, the phase
  folder (`phase.md`, `intent.md`), what to investigate, and the blast-radius exclusions. It has
  **no `Bash`**, so it cannot run `python3 scripts/workflow.py next` or read `git` state; it reads
  `slice.json`, `phase.md`, `intent.md`, docs, and code from disk itself.
- **Blast radius.** The prompt names paths that the running executor is mutating *right now*.
  Anything read there is stale: prefer not to read it, and when it must, label the finding
  explicitly as possibly-stale.
- **Output shape — a compact brief, bounded.** Roughly: relevant files with a one-line note each;
  existing patterns/utilities to reuse (with paths); constraints and risks; open questions worth
  putting to the operator; and an explicit "not read / possibly stale" list. No file dumps, no
  step-by-step plan, no recommendation phrased as a decision. Prefer a fast, correct, shallow brief
  over an exhaustive one — a late brief gets dropped.
- **Hard rules.** Never writes, never runs commands, never dispatches another agent, never touches
  workflow state or commits (the tool allowlist already enforces this — say it anyway), and never
  writes into a slice folder.

### 2. Installer wiring — three edits, not one

Verified in `phase.md`; all three are required or the file ships as dead payload:

1. `installer/build.py` → add `".claude/agents/slice-planner.md"` to `FIXED_LIVE_FILES`
   (lines 42-55). Skills are globbed from disk; `.claude/agents/` is not.
2. `installer/main.py` → an explicit
   `write_text(".claude/agents/slice-planner.md", PAYLOADS[".claude/agents/slice-planner.md"])`
   near the tier loop at main.py:480-482 (that loop iterates only `low/mid/high` and will never
   emit a fourth file). Put it **outside** the loop with a one-line comment saying why.
3. `installer/main.py` → add the same path to `MANAGED_FILES` (main.py:79), beside the three
   executor agents — it feeds the fresh-install conflict guard and update bookkeeping.

### 3. Rewrite the `do-whole-phase` loop

In `.claude/skills/do-whole-phase/SKILL.md`:

- **Amend the dispatch bullet (line 21).** Two sentences there currently forbid the prefetch and
  must gain scoped carve-outs, without weakening what they exist to enforce:
  - "…doing nothing else in the meantime" → carve out the read-only `slice-planner` prefetch
    (still: never inline synchronous execution, never a repo write).
  - "…one at a time: wait for it to return before dispatching the next" → the constraint is one
    **executor** at a time; the read-only planner is not an executor and does not count.
- **Add a new bullet** (right after the dispatch bullet) stating the prefetch rule:
  - **When.** Immediately after dispatching executor N as a background task, dispatch
    `slice-planner` — also via the Agent tool, also background — to research slice N+1, then wait
    for executor N's notification as before.
  - **Skip it entirely** when the current slice is `DECOMP` (the middle slices do not exist yet),
    when the next slice is `REVIEW` (never pre-planned), when the next slice is already `ready`
    (`[r]` — an approved `plan.md` exists), when the phase or any slice is `pending`, or when the
    next slice's expected files sit inside slice N's blast radius. Blast radius = the files/dirs
    slice N's `plan.md` says it will touch; prefetch only what lies outside it, and skip altogether
    when little of substance lies outside.
  - **Sizing** (the operator's clarification): for an easy/mechanical next slice, the planner
    subagent alone; for a heavy/hard one the orchestrator may *also* read key files inline while
    waiting, so it forms its own view rather than trusting a digest for a decision-heavy plan.
  - **Never block on it.** Executor N's completion notification always wins. If the brief has not
    arrived, drop it and plan normally — never delay `finish-slice`, `validate`, or the commit for
    it, and never leave a second prefetch running into the next slice.
  - **Discard** the draft on any verdict other than `done` (`escalate`, `blocked`,
    `needs_operator`, failed/empty return) — the world the brief assumed did not happen.
  - **The brief lives in the session scratchpad**, never in a slice folder: a slice owns exactly
    two context files, and a stale draft must never be readable as an approved plan.
  - **After N returns:** `finish-slice` / `validate` / commit are unchanged; then `EnterPlanMode`
    for N+1 and **reconcile, don't re-research** — start from the brief, then read only what N
    actually changed (its `files_changed`) plus the new `phase.md` notes. Full research only when
    the brief was dropped or the state visibly drifted.
- **Mode coverage.** The prefetch applies in the default loop **and** in `auto` (the cleanest win —
  there the reconciliation feeds the inline plan instead of a plan-mode pass). It does **not** apply
  in `plan only`: no executor runs there, so there is no idle window. Say this explicitly rather
  than leaving it inferred.

### 4. Mirror into `CLAUDE.md` **and** `AGENTS.md`

Byte-equal bodies (`installer/build.py::collect_contract_body` hard-fails otherwise). Keep it
compact — this file is a routing contract, not a manual:

- In the *Driving This Workspace* paragraph, amend the "always dispatches the executor as a
  background task … doing nothing else in the meantime" sentence so the prefetch is a stated
  exception **scoped to `do-whole-phase` by name** — `do-next-slice` gets no prefetch (explicit
  non-goal), and its two `SKILL.md` copies keep their sentence **unchanged**.
- Add one Hard Rules bullet covering the prefetch in a few lines: read-only `slice-planner`, the
  skip conditions, discard-on-non-`done`, never-block, scratchpad-only, advisory-not-authoritative.

Do **not** touch `CLAUDE.md:42` / `:57` — their "verbatim" is about `intent.md`, not plan capture.

### 5. Release plumbing

Per the DECOMP recommendation, P10 ships as **one** release:

- `installer/main.py` → `WORKSPACE_VERSION = 17` → `18`.
- `CHANGELOG.md` → open a `## v18 — 2026-07-28` section at the top with this slice's bullets and a
  **Migration notes** line (adopting workspaces get the new agent + rules on `--update`; no manual
  action beyond the usual `sync-agents` note — state it accurately for what actually changed).
  `P10.S2` appends to this same section without a second bump.
- Rebuild: `python3 installer/build.py`, and commit the regenerated
  `bootstrap_agentic_workspace.sh` as part of this slice's changes.

## Validation

| Check | Expectation |
|---|---|
| `python3 installer/build.py` then `--check` | rebuild succeeds; `--check` reports in sync |
| `grep -c 'slice-planner' bootstrap_agentic_workspace.sh` | ≥ 3 (payload key, `write_text`, `MANAGED_FILES`) |
| `grep -n 'write_text(".claude/agents/slice-planner.md"' bootstrap_agentic_workspace.sh` | one hit — proves it is written, not just embedded |
| `grep -c 'WORKSPACE_VERSION = 18' bootstrap_agentic_workspace.sh` | 1 |
| `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | empty (build.py also enforces it) |
| `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` | empty, and `git diff --stat` shows **neither** `do-next-slice` copy changed |
| `python3 scripts/workflow.py validate` | passes |
| End-to-end install probe | `sh bootstrap_agentic_workspace.sh <scratchpad>/probe --name probe` into an empty scratch dir, then confirm `.claude/agents/slice-planner.md` exists there with the expected frontmatter. This is the check that catches dead payload. If the probe cannot run for environment reasons, say so in `result.md` and fall back to the greps above — do not skip it silently. |

## Record

- `result.md` — free-form: what changed, the validation table with real outcomes, and the exact
  dispatch-prompt shape the orchestrator should use for `slice-planner` (the next planner needs it).
- `phase.md` — append cross-slice notes plus a **Doc impact** line under the existing section
  (expected targets: `operations.md`, `decisions.md`; the review consolidates them).
- No `doc-new-version`, no edits under `docs/`, no commits, no status transitions.

## Non-goals

- No prefetch in `do-next-slice` (either copy) — and no other edit to those files; `P10.S2` owns
  them next.
- No `executors.toml` / `sync-agents` fourth tier for `slice-planner` (model stays pinned in-file);
  the follow-up is recorded in `phase.md` for a later deferred job.
- No Codex counterpart (`do-whole-phase` is Claude Code only).
- No change to `scripts/workflow.py`, the state model, the gate's position, `plan only`, `auto`'s
  safety halts, or the escalation ladder.
- No `cp`-based plan capture (that is `P10.S2`).
