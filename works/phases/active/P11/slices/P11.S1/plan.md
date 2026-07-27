# P11.S1 — Drop `slice-planner`; make idle-window preparation optional

## Context

P10 (v19) shipped two things this slice partly undoes: a workspace-generated agent
(`.claude/agents/slice-planner.md`) and a `do-whole-phase` rule written as a **procedure** —
"immediately after dispatching executor N, dispatch `slice-planner`", followed by five hard skip
conditions.

The operator's correction (`works/phases/active/P11/intent.md`): *"dispatching explore while
meantime planning is not forced. orchestrator can choose to research by it self, or awaiting for the
slice to end… I just want to give a free to the orchestrator… it's an option not mandatory. the goal
is to make efficient, and high quality work."*

So the rule becomes a **permission**, not a sequence: the executor's run is idle time on the main
thread, and the orchestrator may use it however serves the next plan — a read-only research subagent
(Claude Code's built-in `Explore`), inline reading, thinking it through, or simply waiting. The
bespoke agent goes away in favour of plain Claude Code behaviour.

Scope, the four installer edits, and the full reference inventory are in
`works/phases/active/P11/phase.md` — read it and `intent.md` first. `P11.S2` handles the READMEs;
this slice does not touch them.

Dispatch: **`slice-executor-high`** (`risk: high` — this is *relaxing* rules that sit beside the
delegation rule, the approval gate, `auto`'s safety halts, and the escalation ladder, which is
exactly where an over-broad edit does damage).

## Work

### 1. Delete the agent and rewire the installer (four edits)

- `rm .claude/agents/slice-planner.md`.
- **Remove** the three P10 touchpoints: `installer/build.py:49` (`FIXED_LIVE_FILES`);
  `installer/main.py:484-488` (the explicit `write_text` **and** its explanatory comment block);
  `installer/main.py:80` (`MANAGED_FILES`).
- **Add** `.claude/agents/slice-planner.md` to **`OBSOLETE_MACHINERY`**
  (`installer/main.py:517-523`), following the existing `# retired in vNN — <why>` comment style.
  This is the only channel that tells a workspace already on v19 to delete the file: `--update`
  never deletes, and `flag_stale_skills()` walks only the two `skills/` trees, never
  `.claude/agents/`. Omit it and every adopting workspace silently keeps a dead agent.

### 2. Rewrite the rule in `.claude/skills/do-whole-phase/SKILL.md`

**Amend the dispatch bullet (`:21`)** so its carve-outs no longer name `slice-planner`: the
exception becomes "optional read-only preparation for the next slice (see the next bullet)". Keep
intact what those sentences exist to enforce — never inline synchronous execution, never write to
the repo or move workflow state while an executor runs, and one **executor** at a time (read-only
research is not an executor and does not count).

**Replace the prefetch bullet (`:22`+) with an optional-practice bullet.** Required substance,
wording is yours:

- **The permission, stated plainly.** While executor N runs you are idle on the main thread. You
  **may** use that window to prepare for slice N+1 — dispatch a read-only research subagent (the
  built-in **`Explore`** is the natural fit), read files inline yourself, think the slice through,
  or just wait. Nothing here is required and no mechanism is prescribed; choose per slice on what
  will make the next plan better, and prefer waiting when there is nothing useful to learn yet.
  The goal is efficient, high-quality work — not a procedure to follow.
- **The hard limits** (these constrain whatever you choose, not which you choose): read-only — no
  repo writes, no `workflow.py` state commands, no commits, and never any of slice N+1's actual
  work; no second executor; **never block** — executor N's completion notification always wins, and
  anything not ready by then is dropped rather than waited for; **discard** what you gathered on any
  verdict other than `done`; notes live in the **session scratchpad**, never in a slice folder, and
  are advisory input to your plan, never an approved plan — **the operator's approval gate does not
  move**.
- **Judgment, not a checklist.** Say where it tends to pay off (a next slice whose subject is
  separate from what N is touching; a decision-dense slice where you want your own view before the
  gate; a large unfamiliar area) and where it usually does not — the current slice is `DECOMP` (the
  middle slices do not exist yet), the next is `REVIEW` (never pre-planned) or already `ready`
  (`[r]`), anything is `pending` (the loop stops there anyway), or the next slice's files sit inside
  what N is rewriting (anything read there may be stale by the time N returns). P10's five skip
  conditions become **exactly this guidance** — demoted from hard rules, not deleted.
- **If you delegate, keep the ask small** — the useful half of the deleted agent's prompt, condensed
  and kept short since it is guidance for an optional path: hand the agent everything by path, ask a
  few sharp questions rather than "research this slice", and ask for a **compact advisory brief** —
  relevant files with a one-line note each, patterns/utilities to reuse, constraints and risks, open
  questions, and an explicit "not read / possibly stale" list. Never a plan, never a file dump. A
  shallow brief that arrives in time beats an exhaustive one that does not.
- **After N returns**, `finish-slice` / `validate` / commit are unchanged; then plan N+1,
  reconciling whatever you gathered against what N actually changed (`files_changed`, `result.md`,
  the new `phase.md` notes) instead of re-reading everything. Prepared nothing? Just plan normally.
- **Modes:** applies in the default loop and in `auto`; `plan only` has no executor running, so
  there is no idle window.

### 3. Mirror into `CLAUDE.md` **and** `AGENTS.md` (bodies byte-equal)

- `:19`, *Driving This Workspace* — the "doing nothing else in the meantime" clause keeps its
  exception but stops naming the agent: optional read-only preparation for the next slice, still
  scoped to `do-whole-phase` by name (`do-next-slice` never prefetches).
- `:62`, Hard Rules — rewrite the "Pipelined planning" bullet as the optional practice, compressed
  to routing-contract length: optional, mechanism-free (`Explore`, inline, or nothing), read-only,
  never blocks, discarded on any non-`done` verdict, scratchpad-only and advisory, gate unmoved,
  `do-whole-phase` only. The five conditions appear as guidance, not as "skip when…".

Do **not** touch either `do-next-slice` copy (both must stay byte-identical to each other and
unchanged by this phase), `scripts/workflow.py`, or the v19 CHANGELOG section (history).

### 4. Release plumbing

- `installer/main.py` → `WORKSPACE_VERSION = 19` → `20`.
- `CHANGELOG.md` → a new `## v20 — 2026-07-28` section at the top. Its **Migration notes must tell
  v19 workspaces to delete `.claude/agents/slice-planner.md` by hand** — `--update` flags it as
  stale but never removes it.
- `python3 installer/build.py`, leaving the rebuilt `bootstrap_agentic_workspace.sh` in the tree.

### 5. Doc-impact notes (append to `phase.md`, no `doc-new-version`)

- **`operations.md`** — its v19 section *Pipelined slice planning — the `slice-planner` prefetch* is
  now wrong end to end; `REVIEW` should replace it with the optional idle-window practice and the
  agent's removal.
- **`decisions.md`** — v0024 claims the prefetch is read-only *by tool allowlist, not prose*. With
  the bespoke agent gone that guarantee is gone: `Explore` has `Bash`, and inline research is bounded
  only by the orchestrator's own discipline. The new version must **supersede** that claim and say
  the weaker one plainly, alongside the reasons for preferring plain harness behaviour (no fourth
  managed surface, no `EXECUTOR_TIERS` anomaly, no pinned model drifting from the presets).

## Validation

| Check | Expectation |
|---|---|
| `python3 installer/build.py` then `--check` | rebuild succeeds; `--check` in sync |
| `grep -c 'slice-planner' bootstrap_agentic_workspace.sh` | **0** — the artifact embeds no CHANGELOG, so the only hits would be live machinery |
| `grep -c 'WORKSPACE_VERSION = 20' bootstrap_agentic_workspace.sh` | 1; `CHANGELOG.md` has one `## v20` section and still has `## v19` |
| `grep -n 'slice-planner' installer/main.py` | exactly one hit — the `OBSOLETE_MACHINERY` entry |
| `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | empty |
| `git diff --stat -- .claude/skills/do-next-slice .agents/skills/do-next-slice scripts/workflow.py` | empty — untouched |
| `python3 scripts/workflow.py validate` and `sync-agents --check` | both pass |
| **Fresh install probe** | `sh bootstrap_agentic_workspace.sh <scratchpad>/probe-p11 --name probe-p11`; in the probe: `.claude/agents/` contains **only** the three `slice-executor-*` files, `workspace_version: 20`, the optional-practice wording present in `do-whole-phase/SKILL.md`, and `slice-planner` absent from every file |
| **Obsolete-flag probe** | in that same probe, hand-create `.claude/agents/slice-planner.md` (any content), run `--update --dry-run`, and confirm it is reported **stale** and **not deleted**. This is the check that proves the `OBSOLETE_MACHINERY` entry works; report the real outcome, and if the probe cannot run say so rather than skipping silently |
| Read-through | Re-read the amended bullets end to end and confirm nothing adjacent was weakened: the delegation rule, the approval gate's position, `auto`'s safety halts, the escalation ladder, `plan only` / `ready`, "each slice owns exactly two context files", and P10's copy-based plan capture (untouched) |

## Record

`result.md` — what changed, the validation table with real outcomes, and any wording judgement
`REVIEW` should weigh. Append cross-slice notes and the two Doc-impact lines to `phase.md`. No
`doc-new-version`, no edits under `docs/`, no commits, no status transitions.

## Non-goals

- No README edits (that is `P11.S2`), no `do-next-slice` edits, no `scripts/workflow.py` change.
- No change to P10's copy-based plan capture, the gate's position, `auto`'s safety halts, the
  escalation ladder, or `plan only` / `ready` semantics.
- No new agent file of any kind — the point is to stop maintaining one.
- No edits under `docs/` and no doc versions (that is `P11.REVIEW`).
