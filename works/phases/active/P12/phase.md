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

### S4 — the cross-stream view's name and read model (binding for S5–S7)

**1. Command name: `parallel-status`** (no arguments) — the intent's `status --all` was an
illustrative "e.g."; there is no existing `status` command to extend, and the `parallel-*` prefix is
how the operator discovers the whole family. Quote it verbatim in skills and README.

**2. It is the one command that writes nothing.** Every other command funnels through
`rebuild_index_and_state()`; `parallel-status` deliberately does not, because it is meant to be run
from a parallel worktree, where a rebuild would rewrite that checkout's dashboards as a side
effect. It recomputes the pointer in memory with the same helpers the rebuild uses
(`current_stream` → `stream_phases` → `resolve_current` / `operator_wait_target`) and prints. The
smoke hashes `works/` + `docs/` around every invocation to keep it that way.

**3. Where each phase's truth is read from**, in order — reported on a `source=` line so the output
always says what it read:

- the phase's branch is *this* checkout's stream → the **working tree** (fresher than its own last
  commit);
- otherwise `git show <branch>:…`, falling back to `origin/<branch>` (a teammate's clone that
  fetched but has no local branch);
- otherwise the **local folder copy** plus a `note: (local copy; branch not found: <branch>)` line —
  the torn-down case, where the merged copy in this checkout *is* the truth.

**4. Verdict ladder** (one line per phase, each naming the next command): in flight `n/m slices
done` → review not `pass` → ready to merge (`parallel-gate <P>`) → merged, docs awaiting
consolidation (`parallel-merge-finish` → `parallel-consolidated <P>`) → merged + consolidated
(`parallel-teardown <P>`) → merged, consolidated and torn down (archivable). "Merged" is
`git merge-base --is-ancestor <branch> HEAD`, computed only when the checkout is *not* the phase's
own stream (there HEAD trivially contains the branch), plus the deleted-branch case: teardown
refuses an unmerged branch, so a missing branch implies the merge already happened.

**5. Helper added for S5:** `_slices_at_ref(ref, phase_id)` — the slice-level twin of
`_phases_at_ref`, ordered by `order`, `None` when the ref is unreadable.

**6. Edge cases:** no parallel phases anywhere → header + `no parallel phases` + the
`parallel-start <P>` pointer, exit 0 (never an error, git or no git — an untouched workspace still
never shells out); a stamped parallel phase with no usable git work tree → a clear
`not inside a git work tree` error, since the command is inherently git-backed.

### S5 — the CI layer and the PR route (binding for S6–S7)

**1. Skill-guided `gh`, no engine wrapper.** The orchestrator runs `gh` directly per S6's skill text;
`scripts/workflow.py` gained **no** `gh` subcommand and was not touched at all by S5. Rationale:
`gh` auth/output/error handling is agent territory, the engine stays offline-testable, and
`parallel-gate` is already the shared engine-side check that both CI and the agent run before
merging. S6 writes the sequence from S3's §5 verbatim: `parallel-gate` → `gh pr create` / push →
merge → `parallel-merge-finish` → consolidate → `parallel-consolidated <P>` → `parallel-teardown <P>`.

**2. One generic CI workflow, `.github/workflows/workspace-ci.yml`, embedded seed-once.** Job
`validate` runs `python3 scripts/workflow.py validate` on every push and PR; `installer/build.py
--check` and `bash tests/retrofit_smoke.sh` are **shell-guarded** on the presence of those files, so
an adopting workspace (no `installer/`, no `tests/`) skips them. Job `parallel-gate` runs only on a
`pull_request` whose `github.head_ref` starts with `phase/`: it checks out the **PR head sha**
(`fetch-depth: 0`) — never the default PR *merge* commit, whose `works/` is a blend of both sides —
derives `<P>` from `phase/P<N>-<slug>` with `sed -n 's|^phase/\(P[0-9][0-9]*\)-.*$|\1|p'`, and runs
`parallel-gate <P> --branch-ref HEAD --main-ref origin/<base>`. `GATE CLOSED` → exit 1 → red check;
whether that blocks the merge is branch protection's business, and the agent-side flow treats red as
stop-and-report. No external actions beyond `actions/checkout@v4`, ASCII, no secrets.

**3. Installer policy for the two repo-level files (`emit_policy_files()` in `installer/main.py`).**
Both are in `FIXED_LIVE_FILES` but in **neither** `MANAGED_FILES` nor `_is_machinery` — a repo that
already has CI or attribute rules must not trip the fresh-install conflict guard (both names are
already in `EMPTY_OK_ALLOWLIST`). They bypass `write_text` and are emitted by one helper, so a single
policy definition covers fresh install, `--into-existing` and `--update` alike:

- `.github/workflows/workspace-ci.yml` — **seed-once** (created when absent, never overwritten;
  `executors.toml` precedent).
- `.gitattributes` — **line-merged** (`works/events.jsonl merge=union` appended only when that exact
  line is absent, existing content never rewritten). A skipped file would silently lose the union
  rule exactly on the repos where a phase-branch merge conflicts. This closes S3's open question.

`WORKSPACE_VERSION` is now **24**, with the matching `CHANGELOG.md` entry; `.githooks/pre-commit`
also matches `^\.github/` and `^\.gitattributes$` (both are embedded payloads, so editing either
must force the artifact-parity check).

**4. The shipped `.claude/settings.json` deny is now `Bash(git push --force:*)`, not
`Bash(git push:*)`.** Amendment 2 has the orchestrator push phase branches and drive `gh`; a blanket
deny blocked that outright, with no prompt. Pushes now go through the normal interactive permission
prompt (nothing is pre-allowed — the operator still approves each one) while force-pushes stay
denied. **Existing adopters keep the old deny** (settings merge is additive; a deny can never be
removed downstream) and must delete the `Bash(git push:*)` line by hand — stated in the v24 migration
notes, and S6/S7 should repeat it wherever they describe the parallel merge flow.

**5. Not verifiable in this slice:** CI has never actually run — pushing is outside a slice's
boundaries. The workflow was validated locally only (PyYAML + `ruby -ryaml` parse, ASCII check,
branch-name derivation against S2's real format, and the commands it invokes run locally). The first
real run happens on the operator's next push.

### S6 — the documentation surface (binding for S7 and the REVIEW)

**1. `WORKSPACE_VERSION` stays 24 — the v24 CHANGELOG entry was extended, not superseded.** S5 bumped
to 24 in this same unreleased change set, so S6's skill + contract work is part of that release: two
bullets were appended to the v24 section (the new `parallel-phase` skill; the contract/skill/agent
carve-outs). **S7 must extend v24 too, not bump to 25.**

**2. The new skill is `parallel-phase`** (`.claude/skills/`, `.agents/skills/` + `openai.yaml`), and it
is **explicit-invocation only** (`disable-model-invocation: true`, `allow_implicit_invocation: false`)
like every other command skill — `design-cowork` remains the sole model-invocable guide. It is the
single source for the parallel lifecycle: when to suggest, `parallel-start`, worktree work, the branch
review's deferral, and the 10-step integration sequence. README text (S7) should point at it rather
than restate it.

**3. Division of labour: the contract routes, the skill explains.** `CLAUDE.md`/`AGENTS.md` gained only
rules — the commit-convention carve-out, the deferral condition on the durable-doc/delegation/archive
bullets, one new compact parallel bullet, the stream-scoped pointer note, and the six `parallel-*`
command lines. Every lifecycle detail lives in the skill. Keep it that way.

**4. The commit-convention carve-out's exact shape** (quote it if S7 restates it): opting a phase in
*is* the operator's ask, and it authorizes the engine's one fixed-message stamp commit, the phase
branch, slice commits on that branch, and the pushes that open/merge the PR — **each push still goes
through the permission prompt** (nothing is pre-allowed), and existing adopters must first delete the
old blanket `Bash(git push:*)` deny by hand (keep `Bash(git push --force:*)`). Outside that flow the
old rule stands verbatim.

**5. The review-side wording every surface now shares:** a parallel phase's passing review creates no
doc versions, **verifies** that `phase.md`'s "Doc impact" list covers every durable-truth change (an
incomplete list is a review finding), and returns
`doc_versions: none — deferred to post-merge consolidation (parallel mode)`. The `docs/current` vs.
`docs/index.json` parity check applies at consolidation time on the default stream, not at the branch
review.

**6. Opting in is a creation-time decision.** `parallel-start` requires status `planned`, so the
`create-phase` skill relays `new-phase`'s hint and may run the opt-in itself (its existing
`allowed-tools` already cover `python3 scripts/workflow.py ...`); once decomposition or execution
starts, the phase can no longer be opted in.

**7. New skills really do auto-register** (S1–S5's DECOMP correction confirmed end to end): folders +
`python3 installer/build.py` were enough — a fresh install from the rebuilt artifact ships
`.claude/skills/parallel-phase/SKILL.md`, `.agents/skills/parallel-phase/SKILL.md` and its
`openai.yaml` byte-identical to the live files. No `installer/main.py` edit.

**8. Two engine gaps found while writing the prose (recorded, not patched — S6 was docs-only):**
(a) the consolidation deferral is **prose-enforced only** — `doc-new-version` does not refuse on a
parallel stream, though `parallel-consolidated` does exactly that check, so a branch review that
ignores the rule collides silently on `vNNNN` later; (b) `parallel-merge-finish` only *warns* on a
parallel stream while `parallel-consolidated` hard-refuses. Both are review-time calls (fix slice or
accept as designed), detailed in S6's `result.md`.

- **`P12.S7`** — README documentation landed in both files: `README.en.md` gained a new `### Parallel
  phases (opt-in)` H3 under "How it works", a grouped CLI-table row, a `parallel-phase` skills-table
  row, three skill-count fixes (14→15 core / 15→16 total, verified against `ls .claude/skills` = 16),
  the `.github/workflows/workspace-ci.yml` tree entry + `settings.json` comment fix (force-push, not
  push), and the "parallel"→"mirrored" wording fix; `README.md` gained a Korean `## 병렬 phase
  (옵트인)` H2, a skills-table row, and two count fixes (L185's table caption *and* an additional
  stale "스킬 15종" the plan didn't name, found in "더 알아보기" and fixed for consistency with the
  plan's own validation grep). No doc-impact note needed — the READMEs mirror durable truth already
  captured by S1–S6.

### REVIEW — verdict `changes_requested`, and what the re-review must carry

Full detail in `slices/P12.REVIEW/result.md`. The phase is functionally complete — all eight intent
requirements and both amendments landed, and backward compatibility is **proven for the phase as a
whole**, not just per slice (see point 2). One engine gap is held open.

1. **The one fix: `doc-new-version` has no parallel-stream guard** (`P12.F1`, `fix`, `high`).
   `new_doc_version` (`scripts/workflow.py:300`) never calls `current_stream()`, while its sibling
   `parallel_consolidated` (`:1294`) hard-refuses that exact condition — so the feature guards its
   bookkeeping command and leaves its *destructive* one open. Traced, not assumed: `dest.exists()`
   (`:313`) compares the full `vNNNN_<slug>.md` path, so two different summaries never collide;
   `docs/index.json` is authoritative and deliberately **not** in `GENERATED_FILES` (`:39`), so it
   is hand-merged; and `validate_docs` has no version-id uniqueness check. Net effect: two files
   claiming the same `vNNNN`, one version's content silently missing from `docs/current`, and
   `validate` still passing. Intent item 3 promised this "can **never** collide" — prose does not
   deliver *never*. The guard belongs right after the `doc_id in DOC_TYPES` check, before any
   allocation, and is backward-compatible for free (`current_stream` returns `None` without touching
   git unless a phase carries a parallel stamp).
2. **Byte-identity must be measured against `6f9e3c7`, not `HEAD`.** S1's and S4's rebuild-diff
   harness compares the working tree to `HEAD` — which now contains all of S1–S7, making the check a
   guaranteed no-diff that proves nothing at review time. Re-pointed at the last pre-P12 commit: 17
   generated artifacts (4 dashboards + 11 `docs/current/*.md` + `next` + `validate`, timestamps
   normalized) `IDENTICAL`. Any future phase-wide backward-compat proof should use the pre-phase
   commit, not `HEAD`.
3. **S6 gap 2 is closed as designed — do not "fix" it.** `parallel-merge-finish` warning (`:1265`)
   where `parallel-consolidated` refuses (`:1307`) is proportionate: merge-finish is idempotent and
   non-destructive, and on a parallel stream its rebuild writes exactly the stream-scoped state that
   checkout should have. Refusing would strand someone mid-cleanup for no safety gain.
4. **The `smoke_s2` flake is a harness bug, never an engine bug — no repo change.** The failing run
   commits a *subset* (4 of 6 files: `state.json`/`deferred.md` unchanged in the same wall-clock
   second), never anything extra. The safety property is an upper bound ("nothing but the stamp and
   the regenerated files"), and `parallel-start`'s fixed `git add` list holds it unconditionally.
   The harness asserts set equality where its own name says "only"; relax `==` to `<=` if reused.
5. **Residual risk: CI has still never executed on GitHub.** Locally verified only (two YAML
   parsers, ASCII, branch derivation, every invoked command). First real run is the operator's next
   push; runner `python3` availability and the `origin/<base>` fetch are the two unknowns.
6. **§Doc Impact below was verified complete and accurate against the shipped code** (11 notes:
   `architecture` ×2, `operations` ×5, `decisions` ×4) and is ready to consolidate verbatim once
   `P12.F1` lands and the re-review passes. Nothing was versioned at this review — the verdict is
   non-pass, and consolidation is pass-only. The `decisions` **supersede-not-append** instruction
   still stands: the stale "*Parallel fan-out across slices* — rejected for now" sentence in
   `docs/current/decisions.md` is confirmed still present and must be **rewritten** (phase-level
   parallelism now ships; slice-level fan-out stays rejected), not shadowed by a newer entry.

### F1 — the consolidation deferral is now engine-enforced (closes REVIEW finding 1)

1. **`new_doc_version` refuses on a parallel stream**, immediately after the `doc_id in DOC_TYPES`
   check and **before `doc_index()`** — so a refusal leaves zero partial state (verified by hashing
   `docs/` and byte-comparing `docs/index.json` + `works/events.jsonl` across a refused run). The
   message mirrors `parallel_consolidated`'s (`this checkout is on parallel stream {stream}; ...`,
   ASCII `--`) and additionally names the three-step post-merge sequence. S6 gap (a) is closed;
   gap (b) (`parallel-merge-finish` warns) stays as designed per REVIEW finding 2.
2. **`validate_docs` rejects duplicate `vNNNN` numbers per doc** (`duplicate doc version number in
   docs/index.json: <doc> vNNNN claimed by both <id-a> and <id-b>`), placed right after the
   index-entry check so it reports even when `latest` is broken. Ids without a `vNNNN` prefix are
   skipped, never errored.
3. **Backward compatibility measured, not argued**: `current_stream` returns `None` without shelling
   out to git unless an active phase carries a parallel stamp, so the guard is unreachable for a
   default workspace — proven by running the whole `doc-new-version` -> `rebuild-docs` -> `validate`
   chain in a workspace with **no git at all**, plus the 17-artifact byte-identity pass against
   pre-P12 `6f9e3c7` (still `IDENTICAL` with F1 applied). `smoke_s3` (49 checks) stays green.
4. **Harness note for anyone extending `smoke_f1.py`**: you cannot test the in-function `DOC_TYPES`
   check through the CLI — argparse `choices` rejects an unknown `--doc` before `new_doc_version`
   runs. Assert the observable property (an invalid doc on a parallel stream reports the doc error,
   not the stream refusal) instead.

### REVIEW cycle 2 — verdict `pass`, docs consolidated (phase complete)

Full detail in `slices/P12.REVIEW/result.md` (cycle 2 section). The re-review verified `P12.F1`
closed the one must-fix finding and re-validated only what F1 could have disturbed; cycle 1's full
matrix, intent walk and judgment stand.

1. **Finding 1 is closed at the engine level.** Verified against the F1 diff and the current source,
   not the report: the guard sits before `doc_index()`, so a refusal leaves zero partial state, and
   `smoke_f1.py` measures that (hashing `docs/`, byte-comparing `docs/index.json`, asserting no
   `doc_version_created` event) rather than asserting it. Section A's no-git-at-all run is the real
   backward-compat proof — the guard cannot be reached on the default path because `current_stream`
   returns `None` without shelling out. Intent item 3's "can **never** collide" is now delivered by
   the engine instead of by prose.
2. **Scoped re-validation, all green:** `py_compile`, `smoke_f1` (23), `smoke_s3` (49), `validate`,
   `next`, `build.py --check`, `sync-agents --check`, and an independently re-run byte-identity pass
   vs pre-P12 `6f9e3c7` (17 artifacts `IDENTICAL`) — the last two re-run **again after** the doc
   consolidation, still clean. `smoke_s2`/`s4`/`s5` and `retrofit_smoke.sh` were deliberately not
   re-run: F1 touched only `new_doc_version` and `validate_docs`, which none of them exercise.
3. **Findings 2 and 3 stay closed** — F1's two hunks are entirely inside those two functions and
   touch neither surface, so no new evidence exists to reopen them.
4. **Docs consolidated — three versions, all 12 Doc Impact notes covered:** `architecture` **v0003**
   (S1+S2 — a new "Execution Streams" section: the `execution` schema, branch-based stream detection,
   scope-once-upstream, regenerate-not-merge, why doc versioning is serial), `operations` **v0021**
   (S2–S6+F1 — a new "Parallel phase execution" section with the six-command table, the integration
   sequence, both CI jobs, installer policy, the by-hand push-deny migration; plus a parallel-mode
   bullet in the phase-review section), `decisions` **v0027** (S3, S5, S6 ×2 — one new entry with
   nine decision points and seven rejected alternatives).
5. **The supersede was executed as a supersede.** `decisions.md`'s "*Parallel fan-out across slices*
   — rejected for now … parallelism is out of scope" bullet was **rewritten in place** (now line 509)
   to scope the rejection to **slice level only**, state that the blanket claim no longer holds, and
   cross-reference the new v24 entry — not shadowed by a newer entry beside it. Anyone re-reading
   that bullet later gets the current truth at the point of the stale claim, which is the whole point
   of the rule.
6. **Residual risk carried forward, unresolved by design:** CI has still never executed on GitHub.
   Locally verified only; the first real run is the operator's next push, where runner `python3`
   availability and the `origin/<base>` fetch depth are the two unknowns.
7. **Reusable lesson for future reviews:** a phase-wide backward-compat proof must compare against
   the **pre-phase commit**, never `HEAD` — the S1/S4 rebuild-diff harness compares to `HEAD`, which
   at review time already contains the whole phase, making it a guaranteed no-diff that proves
   nothing. `<scratchpad>/rebuild_diff_review.py` is the corrected shape.

## Doc Impact

_Running list for the `REVIEW` slice to consolidate into doc versions (one version per doc, per
phase). Do not run `doc-new-version` in a middle slice._

**CONSOLIDATED at REVIEW cycle 2** into `architecture` v0003, `operations` v0021 and `decisions`
v0027. The list below is kept as the record of what each slice contributed.

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
- **`operations`** (S4) — `parallel-status` answers "what is happening on every stream right now?"
  from any checkout: this stream's pointer plus, per parallel phase, its branch/worktree/
  consolidation state, the branch-side slice table read with `git show`/`git ls-tree` (which the
  default stream's `works/backlog.md` cannot show before the merge), and a one-line verdict naming
  the next command; it is the only workflow command that writes nothing (no rebuild), and falls back
  to the local copy with a note once the branch is torn down.
- **`operations`** (S5) — the workspace now ships CI: `.github/workflows/workspace-ci.yml` runs
  `validate` on every push/PR everywhere and shell-guards the upstream-only checks
  (`installer/build.py --check`, `tests/retrofit_smoke.sh`) on the presence of those files, plus a
  `parallel-gate` job that runs the quiet-point gate on `phase/*` pull requests
  (`--branch-ref HEAD --main-ref origin/<base>`, red check when the gate is closed). The installer
  seeds that file once (never overwritten) and line-merges `works/events.jsonl merge=union` into any
  existing `.gitattributes`, on fresh install, retrofit and `--update` alike; `WORKSPACE_VERSION` is
  24. PR creation and merging stay operator/agent-run `gh` commands — the engine has no `gh` wrapper.
- **`decisions`** (S5) — three choices: (a) **no `gh` wrapper in the engine** — PR steps are
  skill-guided so `gh` auth/output/error handling stays agent territory and `workflow.py` stays
  offline-testable, with `parallel-gate` as the one shared check CI and the agent both run; (b) the
  CI workflow ships **seed-once** while `.gitattributes` ships **line-merged**, because an adopter's
  CI is theirs to own but a skipped `.gitattributes` would silently drop the union rule exactly where
  a phase-branch merge conflicts; (c) the shipped Claude deny narrows from `Bash(git push:*)` to
  `Bash(git push --force:*)` so agent-driven integration can prompt for a push instead of being
  blocked outright — and because settings merges are additive, existing adopters must remove the old
  deny by hand.
- **`decisions`** (S3) — generated workspace files are **regenerated, not merged**: no custom git
  merge driver, because a driver needs per-clone `git config` and therefore does not travel with the
  repo. A merge conflict in `works/{state.json,index.json,backlog.md,deferred.md}` or
  `docs/current/*.md` is resolved by taking either side and re-running `parallel-merge-finish`; only
  the append-only `works/events.jsonl` gets an attributes rule (`merge=union`, a built-in driver) in
  the new repo-root `.gitattributes`.
- **`operations`** (S6) — the agent-facing documentation now describes parallel mode end to end: a new
  **`parallel-phase`** skill (Claude Code `/parallel-phase` and Codex alike) carries the whole
  lifecycle — the advisory `parallel-start` hints, opting in while the phase is still `planned`,
  stream-scoped work in the worktree, the branch review's deferred consolidation, and the agent-run
  integration sequence (`parallel-gate <P>` → push → `gh pr create` → `gh pr checks --watch` →
  `gh pr merge --merge` → `parallel-merge-finish` → serialized `doc-new-version` on the default stream
  → `parallel-consolidated <P>` → `parallel-teardown <P>` → commit) — while `create-phase`,
  `do-next-slice`, `do-whole-phase`, `review-phase` and `archive-phase` gained the matching relays and
  gates, and the contract lists the six `parallel-*` commands and documents the `works/state.json`
  pointer as stream-scoped.
- **`decisions`** (S6) — three choices about *how parallel mode is taught*: (a) the **commit-convention
  carve-out** — opting a phase in is the operator's ask, so the engine's stamp commit, the phase
  branch, its slice commits and the pushes that open/merge the PR are authorized inside that
  documented flow (each push still prompts; adopters must delete any old blanket `Bash(git push:*)`
  deny), while outside it "no branching, never push unasked" stands verbatim; (b) **the contract
  routes and the skill explains** — `CLAUDE.md`/`AGENTS.md` take only rules (carve-outs, one compact
  parallel bullet, the command lines) and every lifecycle detail lives in the `parallel-phase` skill;
  (c) the deferral is stated identically on every review surface — a parallel phase's passing review
  *verifies* the "Doc impact" list and reports `doc_versions: none — deferred to post-merge
  consolidation (parallel mode)`, with the `docs/current` parity check moving to consolidation time on
  the default stream.
- **`decisions`** (S6, **for the REVIEW: supersede, do not append**) — `docs/current/decisions.md`
  (currently line 476) ends the orchestrator/executor entry with "*Parallel fan-out across slices
  (worktree isolation)* — rejected for now … parallelism is out of scope unless a decomposition
  explicitly marks slices independent." P12 supersedes that blanket claim **at the phase level**:
  phase-level parallelism now exists — opt-in, on a branch + worktree, with a quiet-point merge gate.
  **Slice-level** fan-out inside a phase remains rejected (slices build on each other through
  `phase.md` and a commit per boundary). The consolidation must **rewrite** that line to say exactly
  that, not merely add a newer entry alongside it.
- **`operations`** (F1) — the deferred doc consolidation is now **engine-enforced, not prose-only**:
  `doc-new-version` hard-refuses on a parallel stream (naming the post-merge sequence
  `parallel-merge-finish` -> `doc-new-version` -> `parallel-consolidated`) before allocating anything,
  and `validate` now fails on two version entries claiming the same `vNNNN` within one doc, so a
  collision that already happened surfaces instead of silently dropping a version from `docs/current`.
