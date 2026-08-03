# P12.DECOMP — decompose "Opt-in parallel phase execution: branch-per-phase with PR + CI"

## Context

`P12` is created but not decomposed: only `P12.DECOMP` and `P12.REVIEW` exist. The confirmed intent
(`works/phases/active/P12/intent.md`) keeps the default single-stream flow on main byte-compatible
and adds an **opt-in per-phase parallel mode** with eight requirements: (1) phase-scoped next-slice
selection instead of the single global pointer, (2) branch-per-phase (`phase/P<N>-<slug>`) in a git
worktree, (3) durable-doc consolidation deferred to a serialized post-merge step on main for
parallel phases, (4) merge-safe generated files, (5) a full PR + CI layer, (6) a quiet-point merge
gate (branch phase `done` + main between phases), (7) worktree-not-clone on one machine, and
(8) a cross-stream status view from the main checkout. **Backward compatibility is a hard
requirement** — no opt-in, no behavioral change.

**Intent amendment (operator, at DECOMP planning, 2026-08-03):** parallel stays opt-in, but the
workspace must **proactively suggest** the parallel workflow at **both** moments where it becomes
relevant: (a) when a new phase is created while an existing phase is `in_progress`
(`/create-phase` / `new-phase`), and (b) when the operator tries to start executing a second phase
while the current one is mid-flight (`do-next-slice` / `do-whole-phase` / `next`). A suggestion,
never a default — the operator still opts in explicitly.

**Intent amendment 2 (operator, same session):** the PR and merge are **basically done by the
coding agent**, after the branch's review slice: once a parallel phase's review passes on its
branch, the orchestrator itself runs the integration — push the branch, open the PR (`gh`), check
the quiet-point gate + CI, merge, then the post-merge step on main (rebuild + serialized doc
consolidation + worktree teardown) — not manual operator clicks. The quiet-point gate still rules:
if main has a phase in progress, the agent stops and reports instead of merging.

The orchestrator appends both amendments to `works/phases/active/P12/intent.md` right after plan
approval, before dispatching the executor.

This slice does **only** the decomposition: create the middle slices as bare folders (`new-slice`)
and record the breakdown, findings, and constraints in `phase.md`. No implementation, no pre-filled
`plan.md`, no doc versions. The phase touches no product visual design → **single-pass
decomposition** (no `co-work` slices, no `DECOMP2`).

Dispatch: `slice-executor-high` (decomposition always).

## What the executor must do

### 1. Read before deciding

- `works/phases/active/P12/intent.md` — the eight requirements, the resolved clarifications
  (opt-in amendment, quiet-point merge gate), and the Notes section locating the single-writer
  assumptions.
- `scripts/workflow.py` (1146 lines, the whole engine): especially `resolve_current` (:449),
  `operator_wait_target` (:463), `rebuild_index_and_state` (:479), `cmd_next` (:796),
  `next_doc_version_id` (:278), `new_doc_version` (:288), `review_phase` (:765), `new_phase` (:665),
  `validate` (:539), the archive trio (:912-1023).
- `installer/build.py` `FIXED_LIVE_FILES` (:42) and skill auto-discovery (:71-85);
  `installer/main.py` `MANAGED_FILES` (:71) and the `CLAUDE_SKILLS`/`CODEX_SKILLS` registration
  (used at :84-93).
- `.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md`,
  `.claude/skills/create-phase/SKILL.md`, `.claude/skills/review-phase/SKILL.md` — the surfaces
  that consume selection and record reviews (plus their `.agents/` twins).
- `CLAUDE.md` / `AGENTS.md` — the contract text that will need a parallel-mode section and a
  commit-convention carve-out.

### 2. Findings the orchestrator verified while planning (carry into `phase.md`)

- **The global pointer is exactly one function.** `resolve_current` (workflow.py:449) walks active
  phases by `order` and returns the first non-done phase; a `pending`/`blocked` phase yields no
  slice and `cmd_next` (:796) prints `WAITING ON OPERATOR` — repo-wide. `next` takes **no
  arguments** today. Phase-scoping means: selection must skip phases opted out to a branch (on
  main) and select **only** the checkout's own phase (in a phase worktree), with `pending` halting
  only its own stream.
- **Every state command rebuilds global dashboards.** `rebuild_index_and_state` (:479) rewrites
  `works/state.json`, `works/index.json`, `works/backlog.md`, `works/deferred.md` on every
  transition — these files will conflict on every phase-branch merge unless treated as
  regenerate-not-merge (post-merge `rebuild` + `.gitattributes`; `works/events.jsonl` is
  append-only → `merge=union`). Neither `.gitattributes` nor `.github/` exists yet. Remote:
  `github.com/leetusik/bootstrap_agentic_workspace.sh` (so `gh` is usable for the PR layer).
- **Doc consolidation is inherently serial.** `next_doc_version_id` (:278) allocates max+1 per doc
  and `docs/index.json` is a single hand-merge-hostile JSON; two branches consolidating in parallel
  collide on `vNNNN` and on the index — confirming intent item 3: a parallel phase's review stops
  before `doc-new-version`, and a post-merge step on main consolidates one phase at a time from the
  merged `phase.md` "Doc impact" list.
- **`phase.json` has no stream fields today** (`new_phase` :665). An optional block (e.g.
  `execution: {mode, branch, worktree, consolidation}`) is backward-compatible if absence means
  today's behavior. A phase-branch checkout contains *all* phases (forked from main) and main
  contains the parallel phase's folder — so stream membership must come from `phase.json` +
  current git branch, never from `order` alone. `validate` (:539) and the archive commands must
  tolerate a merged parallel phase that is `done` but awaiting consolidation.
- **Machinery edits ripple into the installer.** Any change to `scripts/workflow.py`, skills, or
  the contract requires `python3 installer/build.py` + committing the rebuilt
  `bootstrap_agentic_workspace.sh` in the same commit (pre-commit hook enforces `--check`). Any
  **new** embedded file (CI workflow, `.gitattributes`) must be added to `FIXED_LIVE_FILES`
  (build.py:42) and `MANAGED_FILES` (main.py:71); a **new skill** must be registered in
  `CLAUDE_SKILLS`/`CODEX_SKILLS` in main.py (skill payloads themselves are auto-discovered from
  disk, build.py:77-82).
- **The contract's commit convention forbids branching/pushing unasked** — parallel mode needs an
  explicit carve-out (phase branches push to open their PR; default flow unchanged).
- **The suggestion surfaces are `new_phase` (:665) and `cmd_next` (:796)** — both already print to
  the operator, so the proactive parallel-mode suggestion (amendment above) is a hint line in each
  (creation while another phase is `in_progress`; execution attempt on a second phase), plus
  matching skill text. Engine hints must name the opt-in command, so they land after it exists.
- Doc types available for "Doc impact" notes: `architecture`, `operations`, `decisions` are the
  likely targets. Durable-doc versions are the REVIEW slice's job (deferred post-merge only for
  *parallel* phases — P12 itself runs in today's default mode, so its own review consolidates as
  usual).

### 3. Create the middle slices

Recommended breakdown — **seven** slices, sequential by `order`. Adjust only with a recorded
reason in `phase.md`. `--kind implementation` throughout; risk is the cost lever: everything
below writes real cross-file code → `high`, except S7 (docs only → `low`, mid tier).

- **`P12.S1` — Parallel-mode schema + phase-scoped selection** (`--risk high`, `--order 10`)
  Optional stream fields in `phase.json` + an opt-in stamp path; make `resolve_current`,
  `operator_wait_target`, `rebuild_index_and_state`, `cmd_next`, and `validate` stream-aware:
  main skips parallel-mode phases, a phase-branch worktree selects only its own phase, `pending`
  halts only its own stream. Absent fields ⇒ today's behavior unchanged.
- **`P12.S2` — Opt-in lifecycle: branch + worktree cut and teardown** (`--risk high`, `--order 20`)
  Command(s) to opt a phase in: cut `phase/P<N>-<slug>`, `git worktree add`, stamp the phase on
  both sides; guards (clean tree, phase not started); worktree/branch removal after merge. Plus
  the engine-side proactive suggestion: `new-phase` hints at parallel mode when another active
  phase is `in_progress`, and `next` hints when a second planned phase is waiting behind an
  in-progress one — both naming the opt-in command, suggestion only, never a default.
- **`P12.S3` — Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation**
  (`--risk high`, `--order 30`) `.gitattributes` (`works/events.jsonl merge=union`; generated
  files regenerate-not-merge), a quiet-point check (branch phase `done` + main between phases), a
  post-merge step on main: rebuild dashboards, then serialized doc consolidation from the merged
  phase's "Doc impact" list, marking the phase consolidated.
- **`P12.S4` — Cross-stream status view** (`--risk high`, `--order 40`)
  `status --all` (naming per S1's schema): main pointer plus each parallel phase's branch,
  worktree path, and slice statuses read via `git show <branch>:works/...` — no checkout switch.
- **`P12.S5` — PR + CI layer, agent-driven integration** (`--risk high`, `--order 50`)
  GitHub Actions workflow running `validate` on pushes/PRs (plus `installer/build.py --check`
  where `installer/` exists), quiet-point gate checkable on `phase/*` PRs; the **agent-run**
  integration sequence per amendment 2 — after a parallel phase's review passes, the orchestrator
  pushes the branch, opens the PR via `gh`, verifies quiet-point + CI, merges, and hands off to
  S3's post-merge step (halting with a report if the gate is closed); decide and record whether
  the workflow + `.gitattributes` are installer-embedded for adopting workspaces (recommended:
  yes, generic form).
- **`P12.S6` — Skills + contract for parallel mode** (`--risk high`, `--order 60`)
  `CLAUDE.md`/`AGENTS.md` (parallel-mode section, commit-convention carve-out, review-consolidation
  deferral rule), `do-next-slice`/`do-whole-phase`/`create-phase`/`review-phase` skill updates in
  both `.claude/` and `.agents/` — including the proactive suggestion in skill text: `/create-phase`
  surfaces the parallel option when a phase is `in_progress`, and the execution skills surface it
  when a second phase is waiting — plus the parallel post-review flow (after the branch review
  passes, the orchestrator runs push → PR → gate check → merge → post-merge consolidation itself,
  per amendment 2) and any new skill(s) for opt-in/merge operations + installer registration.
- **`P12.S7` — README documentation** (`--risk low`, `--order 70`)
  Document the parallel option in `README.md` (Korean) and `README.en.md` — not machinery, no
  installer rebuild.

### 4. Record in `phase.md`

- The slice breakdown + rationale under **Decomposition**; the findings above (verified against
  the code it read) under **Findings & Notes**; under **Constraints**: backward compatibility is a
  hard requirement, installer rebuild in the same commit for machinery edits, tests stay lean
  (smoke-level checks inside slices; no new suite), P12 itself executes in default mode.
- Open design decisions assigned to their slices (not decided here): exact `phase.json` field
  names and command naming (S1/S2), how a worktree session detects its stream (S1), `gh`-helper vs
  skill-guided PR steps (S5), installer embedding of CI/`.gitattributes` (S5).

### 5. Boundaries

Executor may run `new-slice` (this is a decomposition slice) but never commits, never transitions
slice/phase status, never runs `doc-new-version`, and never pre-fills any middle slice's
`plan.md`. It writes `result.md` in the `P12.DECOMP` folder and returns the structured verdict.

## Validation

- `python3 scripts/workflow.py validate` passes; `works/backlog.md` lists the new middle slices
  between `P12.DECOMP` and `P12.REVIEW` in the recommended order.
- `phase.md` Decomposition/Findings/Constraints sections filled; slice folders contain only
  `slice.json`.

## After the executor returns (orchestrator)

Before dispatch: append the suggestion amendment to `intent.md` (Clarifications/Amendments
section). After the executor returns: `finish-slice P12.DECOMP` → `validate` → commit. Note: the
P12 phase-creation files (`works/phases/active/P12/`, dashboard updates) are still uncommitted from
`/create-phase` — commit them (with the amended `intent.md`) first as
`chore(works): create phase P12 with intent`, then the decomposition as
`chore(works): decompose P12 into parallel-execution slices`.
