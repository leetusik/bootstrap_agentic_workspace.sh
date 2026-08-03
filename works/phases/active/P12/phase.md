# Phase P12: Opt-in parallel phase execution: branch-per-phase with PR + CI

_Intent: see [intent.md](intent.md)._

## Objective

Keep the default single-stream flow on main unchanged, and add an opt-in per-phase parallel mode: an opted-in phase runs on its own branch in its own git worktree with its own orchestrator session, with phase-scoped next-slice selection, durable-doc consolidation deferred to a serialized post-merge step on main, merge-safe generated dashboards, and a PR + CI layer (pushed phase branches, PRs mapped to review verdicts, CI running validate).

## Context

Two operator amendments landed at `DECOMP` planning time (both recorded in `intent.md`):

1. **Proactive suggestion at both moments.** Parallel stays opt-in, but the workspace must *suggest*
   it (a) when a new phase is created while another phase is `in_progress`, and (b) when the
   operator tries to start executing a second phase while the current one is mid-flight. Suggestion
   only — never a default.
2. **Agent-driven PR/merge.** After a parallel phase's review passes on its branch, the
   orchestrator itself runs the integration: push → PR (`gh`) → quiet-point + CI check → merge →
   post-merge step on main (rebuild + serialized doc consolidation + worktree teardown). Not manual
   operator clicks. The quiet-point gate still rules: if main has a phase in progress, the agent
   stops and reports instead of merging.

The phase touches no product visual design → **single-pass decomposition** (no `co-work` slices, no
`DECOMP2`).

## Decomposition

Seven middle slices, strictly sequential by `order`. `--kind implementation` throughout. Risk is
the cost lever: S1–S6 all write real cross-file engine/skill code → `high` (`slice-executor-high`);
S7 is docs only → `low` (`slice-executor-mid`).

The ordering follows the dependency chain: **schema before lifecycle before merge before
visibility before CI before contract before README**. Nothing downstream can name a field or a
command that S1/S2 have not defined yet, so the two design decisions that everything else quotes
(field names, command names) are settled first.

| Slice | Order | Risk | Scope |
|---|---|---|---|
| `P12.S1` | 10 | high | Parallel-mode schema + phase-scoped selection |
| `P12.S2` | 20 | high | Opt-in lifecycle: branch + worktree cut, teardown, proactive suggestion |
| `P12.S3` | 30 | high | Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation |
| `P12.S4` | 40 | high | Cross-stream status view |
| `P12.S5` | 50 | high | PR + CI layer, agent-driven integration |
| `P12.S6` | 60 | high | Skills + contract for parallel mode |
| `P12.S7` | 70 | low | README documentation |

- **`P12.S1` — Parallel-mode schema + phase-scoped selection.** Add optional stream fields to
  `phase.json` (absence ⇒ today's behavior, byte-for-byte) and make the selection layer
  stream-aware: `resolve_current` (:449), `operator_wait_target` (:463), `rebuild_index_and_state`
  (:479), `cmd_next` (:796), `validate` (:539). On main, selection skips phases opted out to a
  branch; in a phase-branch worktree, selection sees only that phase; `pending` halts only its own
  stream. *Covers intent item 1.* First because every later slice reads or writes these fields.
- **`P12.S2` — Opt-in lifecycle: branch + worktree cut and teardown.** The command(s) that opt a
  phase in: cut `phase/P<N>-<slug>`, `git worktree add`, stamp the phase on both sides, with guards
  (clean tree, phase not yet started); plus worktree/branch removal after merge. Also the
  **engine-side proactive suggestion** (amendment 1): `new_phase` (:665) hints at parallel mode when
  another active phase is `in_progress`, and `cmd_next` (:796) hints when a second planned phase is
  waiting behind an in-progress one. Both hints name the opt-in command — which is why they live
  here, after the command exists, and not in S1. *Covers intent items 2 and 7.*
- **`P12.S3` — Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation.**
  `.gitattributes` (`works/events.jsonl merge=union`; generated dashboards regenerate-not-merge), a
  quiet-point check (branch phase `done` + main between phases), and the post-merge step on main:
  rebuild dashboards, then serialized doc consolidation from the merged phase's "Doc impact" list,
  marking the phase consolidated. *Covers intent items 3, 4, 6.* Needs S1's fields to know which
  phases are parallel and S2's stamps to know what to tear down.
- **`P12.S4` — Cross-stream status view.** A `status --all`-style command (exact naming per S1's
  schema): the main pointer plus each parallel phase's branch, worktree path, and slice statuses,
  read via `git show <branch>:works/...` without switching checkouts. *Covers intent item 8.*
  Read-only, so it lands after the state it reports exists.
- **`P12.S5` — PR + CI layer, agent-driven integration.** A GitHub Actions workflow running
  `validate` on pushes/PRs (plus `installer/build.py --check` where `installer/` exists), with the
  quiet-point gate checkable on `phase/*` PRs; and the **agent-run integration sequence**
  (amendment 2): after a parallel phase's review passes, the orchestrator pushes the branch, opens
  the PR via `gh`, verifies quiet-point + CI, merges, then hands off to S3's post-merge step —
  halting with a report if the gate is closed. Decide and record whether the workflow and
  `.gitattributes` ship embedded in the installer for adopting workspaces (recommendation: yes, in
  generic form). *Covers intent item 5.* Depends on S3's gate function.
- **`P12.S6` — Skills + contract for parallel mode.** `CLAUDE.md`/`AGENTS.md` (a parallel-mode
  section, the commit-convention carve-out, the review-consolidation deferral rule) and the
  `do-next-slice` / `do-whole-phase` / `create-phase` / `review-phase` skills in **both** `.claude/`
  and `.agents/` — including the proactive suggestion in skill text (`/create-phase` surfaces the
  parallel option when a phase is `in_progress`; the execution skills surface it when a second phase
  is waiting), the parallel post-review flow (push → PR → gate → merge → post-merge consolidation,
  run by the orchestrator), and any new skill(s) for the opt-in/merge operations. Documents behavior
  the earlier slices built, so it goes second-to-last.
- **`P12.S7` — README documentation.** The parallel option in `README.md` (Korean) and
  `README.en.md`. Not machinery → no installer rebuild → the only `low`-risk slice in the phase.

## Findings & Notes

Findings below were re-verified against the code at decomposition time (all line numbers confirmed
current at commit `6f9e3c7`).

- **The global pointer is exactly one function.** `resolve_current` (`scripts/workflow.py:449`)
  walks active phases by `order` and returns the first non-`done` phase; a `pending`/`blocked` phase
  yields no slice, and `cmd_next` (:796) then prints `WAITING ON OPERATOR` — repo-wide, halting
  every stream. `next` takes **no arguments** today (subparser at :1051 sets only `func`).
  Phase-scoping therefore means: on main, skip phases opted out to a branch; in a phase worktree,
  select only that checkout's own phase; `pending` halts only its own stream.
- **Every state command rebuilds the global dashboards.** `rebuild_index_and_state` (:479) rewrites
  `works/state.json`, `works/index.json`, `works/backlog.md`, and `works/deferred.md` on *every*
  transition (it is called from `new_slice`, `new_phase`, `review_phase`, the archive commands, and
  `cmd_next` itself). These four files conflict on every phase-branch merge unless treated as
  regenerate-not-merge (post-merge `rebuild` + `.gitattributes`). `works/events.jsonl` is
  append-only → `merge=union`. **Neither `.gitattributes` nor `.github/` exists in the repo yet.**
  Remote is `github.com/leetusik/bootstrap_agentic_workspace.sh`; `gh` 2.96.0 and git 2.45.2 are
  installed locally, so both the PR layer and `git worktree` are usable.
- **Doc consolidation is inherently serial.** `next_doc_version_id` (:278) allocates `max+1` per doc
  and `new_doc_version` (:288) appends to a single `docs/index.json` then rewrites
  `docs/current/*.md` via `rebuild_docs` (:265). Two branches consolidating in parallel collide on
  both the `vNNNN` id and the index — confirming intent item 3: a parallel phase's review stops
  before `doc-new-version`, and a post-merge step on main consolidates one phase at a time from the
  merged `phase.md` "Doc impact" list. Note `new_doc_version` raises if the destination version file
  already exists, so a collision fails loudly rather than silently — but only after the branches
  have already diverged.
- **`phase.json` has no stream fields today.** `new_phase` (:665) writes exactly `id`, `name`,
  `objective`, `status`, `order`, `created_at`, `started_at`, `completed_at`, `review`, `paths`,
  `archive`. An optional block (e.g. `execution: {mode, branch, worktree, consolidation}`) is
  backward-compatible as long as absence means today's behavior. **Stream membership cannot come
  from `order`**: a phase-branch checkout contains *all* phases (forked from main) and main contains
  the parallel phase's folder — it must come from `phase.json` + the current git branch.
- **`validate` and the archive commands must tolerate a merged-but-unconsolidated phase.**
  `validate` (:539) already errors when a phase is `done` with a non-`pass` review or with
  unfinished slices; `_phase_blockers` (:912) blocks archiving unless every slice is `done` and the
  review is `pass`. A parallel phase that merged `done` while its doc consolidation is still pending
  must not trip either check — S1 owns the `validate` side, S3 the consolidation-state side.
- **Machinery edits ripple into the installer.** Any change to `scripts/workflow.py`, a skill, or
  the contract requires `python3 installer/build.py` plus committing the rebuilt
  `bootstrap_agentic_workspace.sh` **in the same commit** (`.githooks/pre-commit` enforces
  `--check`). Any **new** embedded non-skill file (a CI workflow, `.gitattributes`) must be added to
  `FIXED_LIVE_FILES` (`installer/build.py:42`) **and** `MANAGED_FILES` (`installer/main.py:71`).
- **Correction to the plan's finding: new skills need no registration.** The plan stated a new skill
  must be registered in `CLAUDE_SKILLS`/`CODEX_SKILLS` in `installer/main.py`. It does not:
  `build.py` auto-discovers skill payloads from disk (`.claude/skills/*/SKILL.md`,
  `.agents/skills/*/SKILL.md`, `.agents/skills/*/agents/openai.yaml`, :77-82), and `main.py:57-58`
  *derives* `CLAUDE_SKILLS`/`CODEX_SKILLS` from the generated `PAYLOADS` manifest — they are not
  hand-maintained lists, and `MANAGED_DIRS`/`MANAGED_FILES` extend themselves from them (:84-93).
  So a new skill in S6 needs only the folder(s) plus a rebuild. Hand-registration remains required
  for non-skill files (the CI workflow and `.gitattributes` in S3/S5).
- **The commit convention forbids branching/pushing unasked.** `CLAUDE.md`/`AGENTS.md` line 101:
  "Do not create branches unless the operator asks — work on the current branch, including `main`.
  Never push without being asked." Parallel mode needs an explicit carve-out in S6: opting a phase
  in *is* the operator's ask, phase branches push to open their PR, and the default flow is
  unchanged.
- **The suggestion surfaces are `new_phase` (:665) and `cmd_next` (:796)** — both already print to
  the operator (`created phase ...`, the pointer block), so amendment 1 lands as a hint line in each,
  plus matching skill text in S6. Engine hints must name the opt-in command, so they follow S2's
  command, not precede it.
- **Skill surfaces to update in S6** (both `.claude/skills/` and `.agents/skills/`, except
  `do-whole-phase`, which is Claude-only): `create-phase` (step 4 routing prints the phase; step 5
  stops — the suggestion belongs at the confirm/report boundary), `do-next-slice` (step 1 reads
  `next`; the review-slice section at the end owns the consolidation rule that parallel mode
  defers), `do-whole-phase` (same loop, plus the `plan only` / `auto` mode words), `review-phase`
  (its pass-only consolidation step is exactly what a parallel phase must skip in favor of the
  post-merge step).
- **Doc types available for "Doc impact"** (`DOC_TYPES`, :23): the likely targets for this phase are
  `architecture`, `operations`, and `decisions`. P12 itself runs in **today's default mode**, so its
  own `REVIEW` slice consolidates as usual — the deferred post-merge consolidation applies only to
  phases opted into parallel mode.

## Constraints

- **Backward compatibility is a hard requirement.** A workspace or operator that never opts in must
  see zero behavioral change: same commands, same single-stream flow on main, same review-time
  consolidation. Absent `phase.json` stream fields ⇒ today's exact behavior. Every slice that
  touches the engine must prove this (a smoke run of `next` / `validate` on an unmodified phase set).
- **Installer rebuild in the same commit.** Any edit to `scripts/workflow.py`, a skill, `CLAUDE.md`,
  `AGENTS.md`, `works/templates/*`, or the agent files requires `python3 installer/build.py` and the
  rebuilt `bootstrap_agentic_workspace.sh` committed alongside it; `python3 installer/build.py
  --check` must pass (pre-commit hook). This applies to S1–S6.
- **Tests stay lean.** Smoke-level checks inside each slice (run the command, `validate`, a small
  scripted scenario); no new test suite and no fixture sprawl. `tests/` currently holds a single
  `retrofit_smoke.sh`, and that is the right scale.
- **P12 itself executes in default single-stream mode** on `main`. This phase builds parallel mode;
  it does not use it. Its own review consolidates docs the normal way.
- Slice-level parallelism inside one phase is explicitly out of scope (phase-level only).

## Open Questions

Design decisions deliberately **not** made at decomposition — each is owned by the slice that must
settle it, and once settled it is recorded here for the later slices that quote it:

- **Exact `phase.json` stream field names, and the opt-in command's name** — owned by **S1** (schema)
  and **S2** (command). Everything downstream (S3–S7) reads whatever these two decide; the naming in
  this phase.md (`execution: {mode, branch, worktree, consolidation}`, `status --all`) is
  illustrative, not binding.
- **How a worktree session detects which stream it is in** — owned by **S1**. Candidates: current git
  branch vs. the phase's stamped branch, a worktree-local marker file, or `git rev-parse
  --show-toplevel` compared against the stamped worktree path. Must work in a plain clone on a
  teammate's machine too, not only in a worktree.
- **`gh`-helper vs. skill-guided PR steps** — owned by **S5**: does the engine wrap `gh` in a
  workflow.py subcommand, or does the skill instruct the orchestrator to run `gh` directly? Affects
  how much of the integration sequence is testable and what happens where `gh` is absent.
- **Installer embedding of the CI workflow and `.gitattributes`** — owned by **S5** (recommendation:
  yes, in generic form, added to `FIXED_LIVE_FILES` + `MANAGED_FILES`). An adopting workspace has no
  `installer/`, so the embedded CI must not assume `installer/build.py --check` unconditionally.
