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

- ~~**Exact `phase.json` stream field names**~~ — **SETTLED by S1**, see *Settled Decisions* below.
  The opt-in command's **name** remains open, owned by **S2**.
- ~~**How a worktree session detects which stream it is in**~~ — **SETTLED by S1** (current git
  branch vs. the stamped `execution.branch`), see *Settled Decisions* below.
- **`gh`-helper vs. skill-guided PR steps** — owned by **S5**: does the engine wrap `gh` in a
  workflow.py subcommand, or does the skill instruct the orchestrator to run `gh` directly? Affects
  how much of the integration sequence is testable and what happens where `gh` is absent.
- **Installer embedding of the CI workflow and `.gitattributes`** — owned by **S5** (recommendation:
  yes, in generic form, added to `FIXED_LIVE_FILES` + `MANAGED_FILES`). An adopting workspace has no
  `installer/`, so the embedded CI must not assume `installer/build.py --check` unconditionally.

## Settled Decisions

### S1 — the `execution` block and stream detection (binding for S2–S7)

**1. Schema.** `phase.json` may carry one optional top-level `execution` object; **absence means the
phase is on the default stream and every behavior is exactly as before** (proven byte-identical, see
S1's `result.md`). The field names below are now binding — quote them verbatim:

```json
"execution": {
  "mode": "parallel",
  "branch": "phase/P13-some-slug",
  "worktree": "/abs/path/to/worktree",
  "consolidation": "pending"
}
```

- `mode` — the only recognized value is `"parallel"`; any other value (or a missing `mode`) means
  default-stream behavior at runtime **and** is a `validate` error, so a typo fails loudly.
- `branch` — **required** when parallel. This is *the* stream key: everything (selection, S4's
  cross-stream read, S5's PR) keys off the branch name, never off `order` or the worktree path.
  Duplicate `branch` across active phases is a `validate` error.
- `worktree` — informational only; a path string, or `null` on a plain clone / after teardown.
  Nothing in the engine keys off it.
- `consolidation` — `"pending"` from opt-in until S3's post-merge step sets it `"done"`; may also be
  absent/`null`. Only `"pending"`/`"done"`/absent validate. A phase that is `done` + review `pass` +
  `consolidation: "pending"` (merged, awaiting consolidation) **passes `validate` cleanly** — verified
  in the S1 smoke; the archive-side gating on that state is still S3's.
- Read the block **only** through `phase_execution(data) -> dict | None`
  (`scripts/workflow.py`), which returns `None` for anything that is not a well-formed parallel
  block. Never test `data.get("execution")` directly — that is what keeps "parallel" one definition.
- Constants: `EXECUTION_MODES = {"parallel"}`, `CONSOLIDATION_STATES = {"pending", "done"}`.

**2. Stream detection = current git branch vs. stamped `execution.branch`.** `current_stream(phases)`
collects every active phase's `execution.branch`, and — **only if at least one exists** — calls
`git_current_branch()` and returns the branch if it matches one, else `None`. No marker file, so a
`git worktree` and a teammate's plain clone behave identically. `git_current_branch()` tries
`git symbolic-ref --short -q HEAD` first and falls back to `git rev-parse --abbrev-ref HEAD`
(symbolic-ref is correct on a branch with no commit yet, where rev-parse exits 128); detached HEAD,
missing git, or a non-repo all return `None` **silently** → default stream. An untouched workspace
never shells out to git at all.

**3. Scoping shape.** `resolve_current` / `operator_wait_target` were left untouched; the filtering
happens once upstream in `rebuild_index_and_state` via `stream_phases(phases, stream)` — default
stream sees every non-parallel phase, a parallel stream sees only its own phase. Consequences S2–S7
can rely on: the `works/state.json` pointer is stream-scoped, and a `pending` slice/phase halts only
its own stream. Dashboards still list **every** active phase (`index.json` entries carry the
`execution` block; `backlog.md` marks the row `· parallel: <branch>`), and `state.json` gains a
`"stream": "<branch>"` key **only** when the checkout is on a parallel stream. `cmd_next` prints a
`stream=` line on a parallel stream and a `parallel_phases_elsewhere=<P>:<branch>` line when
opted-in phases exist outside the current stream — informational only; the **proactive opt-in hint
naming the command is still S2's** to add.

**4. Not done here (deliberately):** `new_phase` still writes no `execution` block — creation stays
default; the stamping command is S2's, archive/consolidation gating is S3's.

### S2 — the opt-in command names and the engine commit (binding for S3–S7)

**1. Command names: `parallel-start <P>` and `parallel-teardown <P>`** (`scripts/workflow.py`
subcommands). Symmetric and self-describing; every hint, skill, and README line quotes these names
verbatim. Options: `parallel-start [--worktree <path>] [--slug <slug>]` (defaults: worktree
`../<repo-dirname>-<P>` absolute, slug `slugify(phase name)` capped at 40 chars → branch
`phase/P<N>-<slug>`); `parallel-teardown` takes only the phase id.

**2. `parallel-start` makes one engine commit — the single, narrow exception to "the engine never
commits".** The stamp has to exist on **both** the default branch (so its pointer skips the phase)
and the phase branch (so the worktree claims the stream), and the branch must be cut from a commit
already containing it. One fixed-message commit — `chore(works): opt <P> into parallel execution`,
plain, **no trailers** (trailers are the orchestrator's business) — made only after a clean-tree
guard, so it can contain nothing but the stamp plus the regenerated `works/` files, followed by
`git worktree add -b <branch> <path> HEAD`. **`parallel-teardown` commits nothing**: it leaves
`phase.json` dirty (worktree nulled) for the orchestrator to commit with the merge cleanup.

**3. Guard contract S3–S5 can lean on.** `parallel-start` refuses unless: phase status is `planned`,
no existing `execution` block, inside a git work tree, the checkout is on the **default** stream,
the tree is clean, the branch name is free (in `refs/heads/` and unstamped), and the worktree path is
free with an existing parent — all checked before any mutation, so a refusal leaves zero partial
state. `parallel-teardown` refuses unless the phase has a parallel block, the checkout is **not** the
phase's own branch, and the branch is merged into HEAD (`git merge-base --is-ancestor`) — merging
itself is S5's; teardown only cleans up after it. It **warns but does not block** on
`consolidation: "pending"` — tightening that is S3's call. Nothing sets `consolidation` to `"done"`
yet.

**4. Reusable helpers** added alongside: `_git(cmd, cwd, check)` (SystemExit carrying git's own
message), `_require_git_repo()`, `_branch_exists(branch)`, `_phase_branch(phase_id, name, slug)`.
S4's `git show <branch>:works/...` reads and S5's push/PR steps should go through `_git`.

**5. Proactive suggestion, engine half (amendment 1)** — stdout only, generated files untouched:
`new_phase` prints a hint when another **default-stream** phase is `in_progress`; `cmd_next` prints
one (via `parallel_start_hint(state, index)`) on the default stream when the current phase is
`in_progress` and a later default-stream phase is still `planned`, naming the first such phase. Both
name `parallel-start`, run nothing, and are silent otherwise. The matching **skill text is S6's**.

### S3 — the merge-machinery command names and the no-merge-driver rule (binding for S4–S7)

**1. Command names (final): `parallel-gate <P>`, `parallel-merge-finish`, `parallel-consolidated
<P>`** — the `parallel-*` family from S2, kept exactly as the plan recommended. Quote them verbatim.

- `parallel-gate <P> [--branch-ref REF] [--main-ref REF]` — the quiet-point gate. Read-only, prints
  `GATE OPEN` (exit 0) or `GATE CLOSED` + numbered reasons (exit 1), so CI can call it directly.
  Branch side: `git show <branch-ref>:works/phases/active/<P>/phase.json` must be `done` + review
  `pass` (**never** main's pre-merge copy, which is stale by construction). Main side: every
  *default-stream* active phase must be `planned` or `done` — `in_progress`/`in_review`/`pending`/
  `blocked` close the gate (`BUSY_PHASE_STATUSES`); other parallel phases never make main busy.
  `--branch-ref` defaults to the stamped `execution.branch`; `--main-ref` defaults to the working
  tree, and the source is echoed as `main_state_source=`. The working tree is **refused** as a
  stand-in for main when the checkout *is* the phase branch (by name, or detached at its tip — the
  CI shape); sharing a tip with main, normal right after `parallel-start`, does not count.
- `parallel-merge-finish` — run on the default stream right after the merge. Refuses while
  `MERGE_HEAD` exists, then `rebuild_docs()` + `rebuild_index_and_state()`, then lists every
  merged-but-unconsolidated phase (parallel block, `consolidation: "pending"`, phase `done`, branch
  merged or already deleted) with its `phase.md` §Doc Impact location, the per-note
  `doc-new-version → edit edit_path → rebuild-docs` sequence, `parallel-consolidated <P>`, and the
  `parallel-teardown <P>` reminder — explicitly ONE PHASE AT A TIME. Makes **no commit**.
- `parallel-consolidated <P>` — flips `execution.consolidation` to `"done"` (+ `phase_consolidated`
  event). Guards: parallel block, not on a parallel stream, phase `done`, review `pass`,
  `consolidation == "pending"`.

**2. No custom git merge driver — regenerate, don't merge.** A driver (`merge=ours` and friends)
only works where `git config merge.<driver>.driver` has been set in that clone, so it does **not**
travel with the repo and silently degrades to a normal merge for everyone else — worst exactly where
correctness matters. Instead `works/{state.json,index.json,backlog.md,deferred.md}` and
`docs/current/*.md` are resolved by taking **either** side and then regenerated by
`parallel-merge-finish` (or `rebuild`) from the merged folders, which hold the real truth. The only
attributes-level rule is `works/events.jsonl merge=union` — `union` is built into git, so it needs
no per-clone config. Both are documented in the new repo-root **`.gitattributes`**, which is
deliberately **not** registered in `installer/build.py:FIXED_LIVE_FILES` /
`installer/main.py:MANAGED_FILES`: embedding it for adopting workspaces stays S5's open question.

**3. Archive gating.** `_phase_blockers` now blocks a phase whose `execution.consolidation` is still
`"pending"` (so `archive-phase` refuses, `archive-all` lists it, `rotate-backlog` leaves it active).
`parallel-teardown`'s pending-consolidation message stays a **warning**: teardown removes a worktree
(reversible), archiving does not.

**4. Cross-ref read helpers S4/S5 should reuse:** `_json_at_ref(ref, rel)`,
`_phase_json_at_ref(ref, P)`, `_phases_at_ref(ref)` (via `git show` / `git ls-tree`, prefixed by
`_repo_prefix()` so a workspace nested under the repo root works), and `_git_available()` — the soft
probe that never raises, as opposed to `_require_git_repo()`.

**5. The full integration sequence S5 orchestrates:** `parallel-gate` → `git merge` → resolve any
generated-file conflict by taking either side → `parallel-merge-finish` → commit → consolidate docs
one phase at a time → `parallel-consolidated <P>` → `parallel-teardown <P>` → commit.

## Doc Impact

_Running list for the `REVIEW` slice to consolidate into doc versions (one version per doc, per
phase). Do not run `doc-new-version` in a middle slice._

- **`architecture`** (S1) — `phase.json` gains an optional `execution: {mode, branch, worktree,
  consolidation}` block, and workspace selection becomes stream-scoped: the `works/state.json`
  pointer and the `pending` halt cover only the current git branch's stream (default stream skips
  opted-in phases), while dashboards keep listing every active phase.
- **`operations`** (S2) — two new operator commands, `parallel-start <P>` (opt a `planned` phase onto
  `phase/P<N>-<slug>` in its own git worktree; makes one fixed-message engine commit so the stamp
  lands on both branches) and `parallel-teardown <P>` (retire the merged branch + worktree, warn if
  doc consolidation is still pending), plus proactive `parallel-start` hints in `new-phase` and
  `next`.
- **`architecture`** (S2) — the opt-in stamp must exist on both the default branch and the phase
  branch, so `parallel-start` is the one deliberate engine-made git commit (fixed message, clean-tree
  guard, nothing but the stamp + regenerated `works/` files) and the phase branch is cut from it.
- **`operations`** (S3) — three more commands close the parallel loop: `parallel-gate <P>`
  (quiet-point check before merging — branch phase `done` + review `pass` read from the branch,
  default stream quiet; `GATE OPEN`/`GATE CLOSED` with exit codes, `--branch-ref`/`--main-ref` for
  CI), `parallel-merge-finish` (run on the default stream right after the merge: refuses mid-merge,
  regenerates every generated file, lists the phases still owing doc consolidation, commits
  nothing), and `parallel-consolidated <P>` (records that the deferred consolidation is done);
  archiving a parallel phase is now blocked while its `execution.consolidation` is `"pending"`.
- **`decisions`** (S3) — generated workspace files are **regenerated, not merged**: no custom git
  merge driver, because a driver needs per-clone `git config` and therefore does not travel with the
  repo. A merge conflict in `works/{state.json,index.json,backlog.md,deferred.md}` or
  `docs/current/*.md` is resolved by taking either side and re-running `parallel-merge-finish`; only
  the append-only `works/events.jsonl` gets an attributes rule (`merge=union`, a built-in driver) in
  the new repo-root `.gitattributes`.
