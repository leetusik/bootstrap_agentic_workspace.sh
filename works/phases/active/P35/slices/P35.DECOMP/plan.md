# P35.DECOMP — plan

## Context

P35 fixes what the operator saw on glide-ilab, a nested personal install (`ssh node`, `~/projects/glide/glide-ilab`, nested repo `workflow/`), and adds one scope item; `intent.md` is the record:

1. **Nested parallel worktrees.** `parallel-start` refuses in a nested install (`NESTED_PARALLEL_OFF`, `scripts/workflow.py:36`; `_refuse_parallel_when_nested` 2520-2525, called by start/teardown/gate/merge-finish/consolidated; `current_stream` 1479 and `parallel_status` 2992 short-circuit). So when the operator asked for `/do-whole-phase p16 parallely`, the session improvised two phases on one checkout. That left a shared git index, a pointer and compaction resume naming the other phase, a host branch switch by one session under the other, and a shared local DB. Operator, literally: "do-whole-phase phase parallel means the operator wants the phase needed to be ran in another worktreee." **Fix:** make `parallel-start` and the whole lifecycle work in a nested install, opt-in on the operator's word as v43 decided ("parallel" is that word).
2. **One backlog view.** The main stream's `works/backlog.md` shows every in-flight phase, worktree runs and the main run alike. Today `rebuild_backlog` (1649-1685) shows a worktree phase's stale stamp-time copy plus `· parallel: <branch>`. The live data is read only by `parallel_status` (2984-3070, via `_phase_json_at_ref` 2455 / `_slices_at_ref` 2486).
3. **One-slice prep.** The P15 session prepared S2 *and* S3 while S1 ran. `do-whole-phase` SKILL.md l.40-41 says "slice N+1" and "nothing is carried on into the slice after next", but never forbids N+2 outright; `CLAUDE.md:15` says only "stays read-only".
4. **Convert this upstream repo to the nested layout** (the operator: "Yes, as described"). Product source stays tracked here. The workspace state (`works/`, the workspace's `docs/`, `executors.toml`) moves into a private, git-excluded `workflow/` repo installed by the built installer, with its history kept. The workspace is then driven through that installed copy and updated with `--update`. This runs after the worktree work lands, so this repo dogfoods it.

**What the survey found that the DECOMP has to respect:**
- **Why nested parallel was off:** host-side untracked files (`CLAUDE.local.md`, the installed `.claude/` agents, skills and `settings.local.json`, and `workflow/` itself) don't exist in a host worktree.
- **Paired worktrees look workable:**
  - `.agentic-nested.json` is **tracked** in the nested repo (checked on glide), so a nested-repo worktree placed at `<host-worktree>/workflow` resolves `HOST_ROOT` to the host worktree.
  - `info/exclude` lives in the common git dir, so it applies in every worktree.
  - The stream key would be the nested branch, since `git_current_branch` runs in ROOT.
- **Hazards:**
  - `git worktree remove` does not count ignored files as dirty, so excluded scratch inside a worktree is deleted silently. glide's nested repo excludes `temp/`, where P16 writes its outputs.
  - The compaction hooks run `cd "$CLAUDE_PROJECT_DIR" && … compact-resume`, which ignores the hook's stdin `cwd`. If the project dir stays the original root after `EnterWorktree`, a worktree session resumes on the wrong stream; this affects the at-root layout too.
  - `phase-scope`'s host anchors are bare SHAs from whichever checkout ran the command (D35).
- **Host integration:** host branches belong to the team's repo. glide forbids workspace IDs in anything host-visible and squash-merges PRs, so a host branch can't be engine-named `phase/P<N>-…` or merged locally into the host default.
- **The conversion supersedes a recorded decision.** `installer/README.md:90` and `decisions.md:121-132` say "Nothing migrates an at-root install. This upstream repo stays at-root", and a general migration was rejected by the operator. The conversion is for this repo only; no migration command ships, so the v50 decision stands for adopters.
- **The conversion forces a source relocation.** The nested install writes its active copies to `.claude/skills/*` (with per-skill `.gitignore *`), `.claude/agents/*`, `.claude/settings.local.json` and `CLAUDE.local.md`. Here those paths hold the **tracked product sources**: every skill and agent would clash and be renamed `wf-<name>` (`main.py:970-990`), the at-root `CLAUDE.md` contract would load beside the nested one, and the at-root `settings.json` hooks would fire too. So the shipped sources must move to a source tree, so that the live paths serve the install. Those are `.claude/skills`, `.claude/agents`, `.claude/settings.json`, `CLAUDE.md`, `works/templates`, the `executors.toml` seed, `.github/workflows/workspace-ci.yml`, `.gitattributes`, and possibly `scripts/workflow.py`. Upstream `build.py`, `.githooks/pre-commit`, CI, `tests/retrofit_smoke.sh` and the README dev notes then retarget. `docs/retrofit-guide.md` is a product doc and stays tracked.

## What this slice does

`P35.DECOMP` (decomposition, `slice-executor-high`) creates the middle slices with `new-slice` as bare folders (never a `plan.md`), records the Decisions and Notes below in `phase.md`, rewrites `## Now`, and writes `result.md`. It changes no source.

## Proposed breakdown (the executor confirms or amends with reasons)

The engine design and the conversion each have open questions that only an experiment can settle, so the phase researches first and cuts the build in a DECOMP2. The prep wording needs no research and goes first.

| Slice | Name | Kind / risk | Order | Depends on | Why |
|---|---|---|---|---|---|
| `P35.S1` | do-whole-phase prepares slice N+1 only | docs / low | 10 | DECOMP | Pinned wording: SKILL.md l.40-41 and `CLAUDE.md:15` name N+1 and forbid N+2 and later, even when independent; `installer/build.py` rebuild |
| `P35.S2` | research: paired worktrees for a nested install | research / high | 20 | S1 | Open design; findings only, proven in scratch repos |
| `P35.S3` | research: converting this repo to the nested layout | research / high | 30 | S2 | Open design; a dry run on a scratch clone, never this checkout |
| `P35.DECOMP2` | cut the build from the S2/S3 findings | decomposition / high | 40 | S3 | Never pre-planned; its input is S2 and S3 |
| `P35.REVIEW` | (exists) | review | — | — | Gated |

**S2 must answer, each with evidence from a scratch nested install** (the built `bootstrap_agentic_workspace.sh` installed into a `mktemp` host; never glide-ilab, which is read-only reference over `ssh node`):
- (a) **The paired cut:** host worktree home (`<host>/.claude/worktrees/P<N>-<slug>`, with the host's exclude ensured), the nested worktree at `<host-worktree>/workflow`, and the order relative to the stamp commit.
- (b) **Host-side wiring in the worktree:** `CLAUDE.local.md`, `settings.local.json`, the installed agents and skills, and the engine's `CLAUDE_AGENTS` (273). Symlink or copy, and which of them Claude Code actually needs.
- (c) **Claude Code facts:** `EnterWorktree` on a host worktree path; what `$CLAUDE_PROJECT_DIR` and the hook's `cwd` are after it. Does `compact-resume` / `compact-gate` need to read stdin `cwd`? (This applies to at-root too.)
- (d) **Host branch policy:** a name in the host's convention without workspace IDs, or detached until the first host commit; the base ref. Host integration is left to the operator's PR, with no local merge into the host default; a teardown guard covers unbranched host commits.
- (e) **Excluded/ignored paths in worktrees:** the silent-delete hazard at teardown, and shared scratch (e.g. an operator-excluded `temp/`) linked or guarded.
- (f) **Host anchors:** re-stamping `host_anchors.created` at `parallel-start` to the host worktree's base, and `review_pass` from the worktree; whether D35 folds in.
- (g) **The backlog section:** design of a "Streams" view in `rebuild_backlog` built from the branch reads `parallel_status` already does, covering at-root and nested and the nested host branch. Whether D57 (a merged P33 still listed as parallel) folds in.
- (h) **Shared external resources** (docker DBs, ports) that a worktree doesn't isolate: a skill caveat line or nothing.
- (i) **The command and skill surface** that changes: the `parallel-phase` lifecycle steps that need a host counterpart, the `do-whole-phase` / `do-next-slice` worktree paragraphs, `CLAUDE.local.md` text (`main.py:903`), the READMEs and smoke Test 14's "parallel off" assertion.

**S3 must answer, from a dry run on a scratch clone:**
- (a) The source tree for the shipped machinery (name and layout), and every upstream path that retargets: `build.py` `FIXED_LIVE_FILES` 46-62 and the executors seed 82-103, `.githooks/pre-commit` 8/12, `workspace-ci.yml` 24/29/37/73, `retrofit_smoke.sh` 886/1196/1428/1508/1817, `.gitattributes`, README dev notes, `installer/README.md:90`.
- (b) What stays tracked at the root, including a short upstream `CLAUDE.md` with the dev rules: the "Upstream repo only" build rule and the release rule.
- (c) The history-preserving split of `works/`, the workspace `docs/` and `executors.toml` into the nested repo (which tool is available here: `git filter-repo` or `filter-branch`), and the `phase/P33-…` refs.
- (d) Installing the built installer into this repo as the host: preflight refusals (`main.py:670-715`), renames, `--update` afterwards.
- (e) The upstream CI after the conversion: no `works/` at the root.
- (f) The order of operations, so the running session, the open P35 state and the commit hook survive. This includes where P35's own folder lands, and that the session restarts after the switch.
- (g) The rollback.

S3 depends on S2 only to sequence the dispatches; it doesn't need S2's findings.

**DECOMP2's expected shape** (recorded as a Note, not decided here):
- the engine's nested parallel lifecycle (risk high: core invariant, worktrees and state);
- the backlog Streams view;
- the skill, README and doc text;
- small smoke tests for the nested lifecycle (core behavior, so a test is warranted; kept small);
- the v58 release bump and rebuild;
- **the conversion last** (risk high: deletion and history), then the gated REVIEW in the converted layout.

## Decisions the executor records in phase.md

1. **The breakdown above**, with each rating's reason, plus the estimate: one mid dispatch, two research dispatches, DECOMP2, then the build and review.
2. **Opt-in stays (v43).** "parallel" / "parallely" / "in a worktree" on `/do-whole-phase` / `/do-next-slice` is the operator's word, and in a nested install it now runs the phase in its own worktree. Worktrees never start unasked, and never for a docs phase.
3. **The stream key in nested is the nested repo's branch.** The host branch is host-convention-named and carries no workspace IDs; the host side is integrated by the operator's PR, never by a local merge into the host default.
4. **The conversion is for this repo only.** No migration command ships, so the v50 "nothing migrates an at-root install" stands for adopters. The line "this upstream repo stays at-root" (`decisions.md:121-122`, `installer/README.md:90`) is **superseded by the operator on 2026-10-13**, as a `## Doc impact` note.
5. **The conversion moves the shipped sources out of the live paths** (the list above), so the nested install's active copies own `.claude/` and the session contract. The exact tree is S3's.
6. **glide-ilab is reference only:** read-only over `ssh node`, never written; it picks the release up later via `--update`.
7. **Gate: required.** The operator runs a nested phase in a worktree and uses this repo in its new layout. Surface: a scratch nested install driven through a paired-worktree phase from start to teardown, the main backlog's Streams view, and this repo after conversion. The review boundary is `phase-scope P35`.
8. **Doc impact expected:** architecture (Nested Install, parallel mode), operations (the parallel runbook, idle-window prep l.1597-1670, the upstream dev loop), decisions (the superseded at-root line, nested parallel), qa (the smoke tests). Each is a one-line note; a docs phase pays them.

## Notes for later slices the executor leaves

- **(for S1)** The exact lines: SKILL.md l.19 and l.40-45, `CLAUDE.md:15`, and `operations.md` l.1597-1670 as the Doc impact target. Rebuild with `python3 installer/build.py` in the same change. No version bump in S1; the release is one bump in DECOMP2's cut.
- **(for S2/S3)** Every line reference in the Context above. `tests/retrofit_smoke.sh` must be the **only** command in its Bash call (it stalls when chained). Scratch work goes in `mktemp` dirs or the session scratchpad, never this checkout or glide-ilab. Research writes no product code.
- **(for DECOMP2)** The expected shape above. The conversion slice ends with the operator restarting Claude Code at this repo's root, which is a `pending` stop if the REVIEW needs the new session.

## Operator Questions

None expected. If S2/S3 find a choice only the operator can make (a host branch naming rule, the name of the source tree), it goes on `## Operator Questions` and DECOMP2 stops `pending` for it.

## What the executor must not do

Edit any source, run the installer here, touch glide-ilab, pre-fill a slice's `plan.md`, run `accept-gate`, or commit.

## Orchestrator steps

- **Before dispatch:** append the operator's mid-run message ("do-whole-phase phase parallel means … another worktreee") to `intent.md`'s Clarifications, then `start-slice P35.DECOMP`, `executor-route P35.DECOMP` and `--explore`, and append `## Dispatch` to this plan's copy in the slice folder.
- **After:** `record-dispatch` → `finish-slice P35.DECOMP --outcome "…"` → `accept-gate P35 --require` → `validate` → one commit `chore(P35): decompose …` attributed to the executor's model. Then S1 inline (default `auto`).

## Verification

- `python3 scripts/workflow.py validate` passes.
- `## Slices` shows S1 (docs/low, 10), S2 (research/high, 20), S3 (research/high, 30) and DECOMP2 (decomposition/high, 40) as `todo`, each holding only `slice.json`.
- `## Decisions` 1-8 and `## Now` (at most 15 lines) are present, with `phase.md` under budget.
- `result.md` has its verdict block first, and `git status` shows only P35's folder and the generated `works/` files changed.

## Dispatch

route=high
reason=kind decomposition
tier=high
subagent_type=slice-executor-high
model=opus
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Opus 5.5
explore_model=haiku
explore_effort=high
