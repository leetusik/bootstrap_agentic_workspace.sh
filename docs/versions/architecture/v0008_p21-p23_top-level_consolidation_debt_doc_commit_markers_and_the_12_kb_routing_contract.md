---
doc_id: architecture
version: v0008
created_at: 2026-09-28T21:00:02+09:00
commit: 86c404b1ef0c1985c248d24789c8309b6771c02e
source: P21.REVIEW, P22.REVIEW, P23.REVIEW
summary: P21-P23: top-level consolidation debt, doc commit markers, and the 12 KB routing contract
previous: v0007_v43_the_phase_worktree_is_opt-in_again_the_pin_is_a_legacy_block_not_a_live_route
---

# Architecture

## Status

The workspace-cornerstone repo is self-hosting: it runs the workflow on itself and
ships its own machinery as a single-file installer. This document describes stable
system-level truth — most notably that the installer is a **build product**
assembled from an `installer/` source tree, that the workspace is **single-harness**
as of v31 (Claude Code only — one contract, one set of entry points, one embedded
machinery tree), that phase execution is **stream-scoped** (a phase can run on its own
branch + git worktree under `.claude/worktrees/` when the operator asks for one —
the default branch carries every phase nobody asked away from it), that since v32 a
phase may carry an **operator acceptance gate** — a second optional `phase.json` block
that puts the product owner between the review executor's judgment and a recorded
`pass` — that since v38 every phase defers its durable-doc consolidation to an
operator-created docs phase, tracked as a top-level `phase.json` **consolidation**
debt, and that v44 slimmed `CLAUDE.md` to a 12 KB routing contract.

## Current Repo Shape

- `CLAUDE.md`: the compact routing contract — **the only one**. There is no `AGENTS.md` twin (dropped in v31 with Codex support); an `AGENTS.md` an adopting repo keeps for other tools is that repo's own file and the workspace never reads or writes it. As of v44 it is a 12,259 B routing contract in seven sections of short stubs, one statement per rule (Agent Contract, Driving This Workspace, Read Order, Canonical State, Hard Rules, IDs and Status, Commit Convention) — the intent rules sit in *Driving This Workspace*, the slice-file/notebook rules in *Canonical State*. It carries **no** `## Workflow Commands` list: `python3 scripts/workflow.py --help` (and `<command> -h`) is the command reference, and the closed `--kind` set sits in *IDs and Status*. Procedure otherwise reads from the owning skills and the executor bodies, which is also where its Aside, worktree and design Hard Rules are never-stubs: `parallel-phase` is the only full statement of the eight worktree rules; `design-cowork` is the only full statement of the Aside surfaces, the MCP cost/escape hatch, the instrument/runtime axis, the three design styles and the design slice's stops; both executor bodies carry the decomposition's **build inventory** rule
- `docs/current/`: generated latest doc snapshots
- `docs/versions/`: immutable durable doc versions by category
- `docs/index.json`: latest-version map; each version entry carries a `commit` field (the HEAD sha at write time, `null` where git cannot answer, **absent** on pre-v39 entries) — the version frontmatter carries the matching `commit:` line, which `rebuild_docs` copies verbatim into `docs/current`
- `works/state.json`: current/next pointer
- `works/index.json`: generated machine index
- `works/backlog.md`: generated human dashboard
- `works/phases/active/`: active phase folders
- `works/phases/archived/`: archived phase folders
- `works/templates/`: `phase.md`, the phase-notebook template (with its in-engine fallback `PHASE_MD_TEMPLATE_FALLBACK`), tags each `## Notes for later slices` entry `**(from <slice>, for <slice>)**`, the executor's form
- `works/deferred/`: deferred job folders
- `works/.workspace-version.json`: per-workspace marker — `upstream_url`, integer `workspace_version`, `synced_commit`, `synced_at`
- `scripts/workflow.py`: workflow and docs version manager
- `.claude/`: the tool entry points — `skills/` (17 skill packages), `agents/slice-executor-{mid,high}.md`, `settings.json`. **The only such tree**: the `.agents/` skill mirror and the `.codex/` config + executor agents were deleted in v31
- `installer/`: source tree for the distributable (see below)
- `bootstrap_agentic_workspace.sh`: the **generated** single-file distributable (build product — never hand-edited)
- `CHANGELOG.md`: repo-only changelog, one `## v<N>` section per workspace version (not emitted to targets)
- `.github/workflows/workspace-ci.yml`: workspace CI (`validate` everywhere, plus the parallel merge gate on `phase/*` PRs — the remote variant of the merge) — seeded once by the installer, then owned by the adopting repo
- `.gitattributes`: merge policy for generated state (`works/events.jsonl merge=union`; everything else regenerate-not-merge) — line-merged by the installer, never rewritten

## Installer Source Tree

The single-file distributable at repo root is not written by hand — it is assembled
deterministically from `installer/`, with the live repo files as the source of truth
for emitted machinery (no more heredoc mirroring inside the artifact).

- `installer/build.py`: deterministic assembler (`--check` = drift guard). It reads
  `wrapper.sh` + `main.py`, embeds a generated payload manifest (`target-path →
  content`) built from the live repo files plus `payloads/`, and writes
  `../bootstrap_agentic_workspace.sh`.
- `installer/wrapper.sh`: the POSIX-sh wrapper that hosts the Python driver in a
  heredoc.
- `installer/main.py`: the Python driver — config/env, the write engine, retrofit +
  update policies, mode guards, docs/P1 seeding, finalizers, and dispatch. Holds the
  `WORKSPACE_VERSION` integer constant and `write_version_marker()`. The emitted skill
  set is derived at runtime from the payload manifest (every `.claude/skills/<name>/SKILL.md`
  key it carries), so adding/removing a skill needs no installer code change — just the
  live files + a rebuild.
- `installer/payloads/`: the only content with no live counterpart — the 11
  fresh-install `doc_bodies/<doc>.md` seeds (the `p1_seed/` scaffolds were deleted in
  v6; nothing seeds a phase any more).
- `installer/README.md`: the edit → build → commit loop and the release rule.

The build product is byte-identical across all three install modes (fresh /
`--into-existing` / `--update`); `installer/build.py --check` and
`tests/retrofit_smoke.sh` Test 7 fail on any drift between the committed artifact and
`installer/` source.

**The distributable is single-harness (v31).** The payload manifest carries `.claude/**`
and nothing else: `FIXED_LIVE_FILES` (the engine, both `slice-executor` tier agents,
`.claude/settings.json`, `executors.toml`, the `works/templates/*`, the seed-once CI
workflow and `.gitattributes`) plus every `.claude/skills/*/SKILL.md` discovered from
disk. There are no `.agents/` or `.codex/` payload keys, no cross-harness parity
assertion, and no `CLAUDE.md`-equals-`AGENTS.md` byte-equality check — the two release
invariants that remain are a Claude-only skill count (`EXPECTED_SKILL_COUNT = 17`, a
truncated payload is a build error) and a `CLAUDE_HDR` prefix test that keeps
`collect_contract_body()`'s slice landing exactly on `## Agent Contract`. A fresh
install therefore produces `CLAUDE.md` + `.claude/` and no `AGENTS.md`.

**The build only `compile()`s the artifact — it never runs it.** `build.py` byte-checks
and syntax-checks (`compile()` on the assembled body, `sh -n` on the wrapper), so a
change that leaves a dangling `PAYLOADS[...]` read or an import-time guard mismatch
passes the build, `--check`, and the pre-commit hook and still dies on the first line of
every install. Executing the built artifact into a scratch dir is the only check that
catches that class of break (tracked as deferred job `D3`).

## Execution Streams (one worktree per phase, on request — v24, default in v42, opt-in again in v43)

A workspace has one **default stream** — the default branch, with one pointer (`works/state.json`)
naming its next slice — and **one extra stream per phase the operator asks into a worktree**: that
phase runs on its own branch and its own git worktree, entered by the orchestrator session that
executes it, while the default stream carries every other phase. v24 introduced the extra stream as
an opt-in the engine only *suggested*; v42 inverted the default, putting every phase on its own
branch at first execution; **v43 inverted it back**, because one phase at a time is the normal shape
of this workspace and a branch per phase made every ordinary run pay for parallelism it never used.
The schema never changed across any of it — only which state is reached without asking.

**The schema.** `phase.json` may carry one optional top-level `execution` block. **Its absence means
the phase is on the default stream** — the ordinary case since v43, needing no marker, with runtime
behavior exactly as before v24 (proven byte-identical against the pre-parallel engine). A phase
leaves it only through `parallel-start <P>`, which runs when the operator asks for a worktree. Two
shapes are recognized:

```json
"execution": {
  "mode": "parallel",
  "branch": "phase/P13-some-slug",
  "worktree": "/abs/path/to/repo/.claude/worktrees/P13-some-slug"
}
```

```json
"execution": { "mode": "default" }
```

- `mode` — `"parallel"` (the phase has its own stream, stamped by `parallel-start <P>` when the
  operator asks for a worktree) or `"default"` (**a legacy pin**: the phase stays on the default
  stream for good). Anything else means default-stream behavior at runtime *and* is a `validate`
  error, so a typo fails loudly rather than silently disabling. A pinned block carries no other
  field; `validate` skips the branch/worktree/consolidation checks for it.

  **Since v43 nothing writes `"default"` any more.** It was v42's marker for "run on `main`", needed
  only while the worktree was the default; v43 put the default back on the current checkout, so a
  phase with **no `execution` block at all** is the ordinary case and needs no marker. `parallel-skip`
  and `new-phase --on-main`, which wrote it, are retired no-ops. The block is still read where it
  exists: `phase_execution` returns `None` for it — so a pinned phase *is* a default-stream phase
  everywhere — `validate` still accepts it, and `parallel-start` **refuses** such a phase rather than
  override what was once a deliberate choice. Un-pinning is a hand edit.
- `branch` — required when parallel, and *the* stream key: selection, the cross-stream view and
  the merge all key off the branch name, never off `order` or the worktree path. A duplicate
  `branch` across active phases is a `validate` error.
- `worktree` — informational only (a path, or `null` on a plain clone / after teardown). Nothing
  in the engine keys off it. Since v42 it defaults to `<repo>/.claude/worktrees/<branch tail>` —
  nested inside the repo, so the orchestrator can enter it in the same session (`EnterWorktree`
  accepts that directory) — instead of a sibling directory.

**The `consolidation` debt is top-level, not part of this block (since v38).** Every phase — parallel
or default-stream — carries doc-consolidation debt as a top-level `phase.json` field,
`"consolidation": "pending" | "done" | absent`: a passing review stamps `"pending"`,
`docs-consolidated <P>` (or a merged phase's `parallel-consolidated <P>`) records `"done"`, and
absent means nothing is owed. `phase_consolidation()` reads that top-level key first and falls back
to the identically-named field inside a parallel `execution` block only for pre-v38 `phase.json`
files that still carry it there — which is why the JSON example above no longer shows it. A phase
that is `done` + review `pass` + `consolidation: "pending"` (merged, docs not yet consolidated)
validates cleanly, but cannot be archived — true of every phase, not only a merged one.

The block is read through two accessors and nothing else: `phase_execution(data)` returns the
block only when it is a well-formed **parallel** block and `None` otherwise (a pinned block included),
so every stream computation keeps one definition of "parallel"; `phase_pinned(data)` answers the
one question the other cannot — "was this phase deliberately kept here?" — which is what the
first-execution hint, `parallel-start`'s refusal and `parallel-status`'s `pinned_to_default=` line
read. Nothing at runtime distinguishes a pinned phase from an unstamped one except that hint and
that refusal.

**The stamp commit is exact, so the tree need not be clean.** `parallel-start` used to require a
clean working tree because a plain `git commit -a` would sweep the operator's unrelated edits into
the engine's one commit. v42 replaces the guard with exactness: `git add -- <paths>` followed by
`git commit --only -- <paths>`, where the paths are the phase folder and the five regenerated
`works/` files, commits precisely those whatever else is staged or dirty. The default checkout keeps
its uncommitted work, and the worktree is cut from that commit. What still refuses runs before any
mutation: the phase not `planned`, an existing block (parallel or pinned), no git repo, a parallel
stream, a merge or rebase in progress (`MERGE_HEAD` / `rebase-merge` / `rebase-apply` in the git
dir), an existing or already-stamped branch, an existing worktree path, a missing parent for an
overridden path.

**Nested worktrees and the exclude line.** A worktree under `.claude/worktrees/` is inside the
repository's own tree, so without help `git status` on the default checkout would list it as an
untracked directory and an adopter's next `git add .` would try to commit a checkout into a checkout.
The engine therefore appends `.claude/worktrees/` to `.git/info/exclude` — resolved through
`git rev-parse --git-common-dir`, so the line lands in the *shared* git dir even when the command
runs from another worktree — once, idempotently, under a one-line comment naming the release. It is
deliberately **not** `.gitignore`: that file is the adopter's, tracked, and merged; the exclude
file is local, untracked, and exactly the place git provides for a machine's own clutter. Git's own
worktree bookkeeping lives in `.git/worktrees/<name>` as always; `parallel-teardown` removes both.

**Stream detection is the current git branch, not a marker file.** `current_stream(phases)`
collects the stamped `execution.branch` of every active phase and — only if at least one exists —
asks git for the current branch, returning it when it matches one and `None` otherwise. Detached
HEAD, a missing git, or a non-repo all resolve silently to the default stream, and an untouched
workspace never shells out to git at all. Because membership is derived from where the work
actually is, a `git worktree` and a teammate's plain clone of the same branch behave identically
and the stamp can never drift from reality.

**Scoping happens once, upstream.** The selection primitives are unchanged; `rebuild_index_and_state`
filters the phase list through `stream_phases(phases, stream)` before resolving. Consequences:

- the `works/state.json` pointer is stream-scoped — the default stream skips the phases running
  in their own worktree (every other phase has no branch and stays), and a phase worktree sees only
  its own phase (`state.json` gains a `"stream"` key only there);
- a `pending` slice or phase halts **only its own stream**, instead of stopping the whole repo;
- the dashboards still list **every** active phase, so nothing becomes invisible: `works/index.json`
  entries carry the `execution` block (plus `"pinned": true` for a pinned phase) and
  `works/backlog.md` marks the row `· parallel: <branch>` or `· pinned: default stream`.

**Generated state is regenerated, not merged.** `works/{state.json,index.json,backlog.md,deferred.md}`
and `docs/current/*.md` are derived files; a phase-branch merge resolves any conflict in them by
taking either side and re-deriving from the merged folders, which hold the real truth. Only the
append-only `works/events.jsonl` carries a merge attribute (`merge=union`, a git built-in).

**Doc versioning stays serial by construction.** `docs/index.json` is authoritative, hand-merged
truth (deliberately not a regenerated file), and version ids are allocated `max+1` per doc — so two
streams consolidating at once would pick the same `vNNNN`. Every phase defers its durable-doc
consolidation to an operator-created docs phase since v38 (the top-level `phase.json`
**consolidation** debt — see *Execution Streams* above); a parallel phase additionally routes that
deferral through one extra serialized post-merge step on the default stream, and that is
**engine-enforced**: `doc-new-version` refuses to run on a parallel stream before allocating
anything, and `validate` rejects two version entries claiming the same number within one doc. This
is also why **a docs phase must never be asked into a worktree** (before v43 it was pinned with
`new-phase --on-main`; since v43 the default stream is simply where it already runs), and why the
two gate sections a
default-stream review writes itself are, on a branch, **recorded rather than written**: the review
appends them to `phase.md`'s `## Doc impact` as notes tagged `(gate section — written at merge)`,
and the post-merge step on the default stream — after a local `git merge --no-ff`, the default since
v42 — allocates exactly those versions serially, like every other.

## Operator Acceptance Gate (`phase.json` `acceptance`, since v32)

Every gate the machinery had before v32 sat **between agents**: plan gates, executor verdicts,
`validate`, fidelity slices, phase reviews. None sat between the running product and its owner, so a
phase could reach `done` + review `pass` on a product the operator had never opened. The acceptance
gate is that missing seam, and it is machine-enforced rather than remembered.

**The schema.** `phase.json` may carry one optional top-level `acceptance` block, stamped by
`new_phase` on every phase created from v32 on (immediately after `review`, so the file reads
`… review, acceptance, paths, archive`). **No block at all means a legacy phase** — created before
v32, or by an adopter whose `--update` left `works/` untouched — and it behaves exactly as it always
did:

```json
"acceptance": {
  "required": null,
  "walkthrough": null,
  "requested_at": null,
  "cleared_at": null,
  "note": null
}
```

- `required` — `null` = undeclared, `true` = the phase changes operator-visible surfaces, `false` =
  waived (with the reason in `note`). It is the **single conditioning switch**: every runtime-fidelity
  and review duty the gate adds is inert unless it is `true`.
- `walkthrough` / `requested_at` — the concrete script the operator runs, and when the gate opened.
- `cleared_at` / `note` — when the operator accepted, and what they reported (or the waive reason).

Exactly five fields, read **only** through `phase_acceptance(data)` — the same single-accessor
pattern as `phase_execution(data)`, so "gated" has one definition engine-wide, with
`acceptance_gate_is_open(data)` as the one predicate for "waiting on the operator". A block whose
`required` is not `None`/`True`/`False` is not a gate; the accessor returns `None` and `validate` is
the single authority on shape. (The type test is `required is None or isinstance(required, bool)`,
not membership in `{None, True, False}` — `1 == True` in Python.)

**One command drives it: `accept-gate <P>`.** `--require` / `--waive --note "why"` declare the phase
at the `DECOMP` boundary (and create the block on demand, which is how an adopter opts a *live*
legacy phase in); `--open --walkthrough "..."` records the walkthrough at the review and sets the
phase `pending`; `--clear [--note "..."]` returns it to `in_progress`; a bare invocation prints the
gate and writes nothing. Each mutating branch appends one event
(`acceptance_required|waived|opened|cleared`). It is a **phase-state command: executors never run
it** — the review executor returns the walkthrough text, the orchestrator opens the gate.

**The lifecycle is enforced in three places, all in `scripts/workflow.py`:**

1. `review_phase` refuses `--verdict pass` **before writing anything** when the block is present and
   `required` is `null` (undeclared) or `true` with no `cleared_at`, naming the exact flags to run —
   so a refused pass leaves no trace. `changes_requested` and `blocked` are **never** refused (the
   operator's failure report has to be recordable), and `changes_requested` resets
   `walkthrough`/`requested_at`/`cleared_at` to `null` while keeping `required` and `note`: the phase
   changed, so the gate re-opens for the re-review.
2. `validate` checks the block's shape when present and errors on `status: done` + `required: true` +
   `cleared_at: null` — the same shape as the pre-existing "done but the review is not a pass" error.
   An **absent** block produces no warning at all: nagging every legacy phase on every run would
   violate the lean-dashboard rule.
3. `next` reuses the existing `pending` halt rather than adding a second one. When the waiting target
   is a phase whose gate is open it prints `acceptance_gate=open (requested_at=…)`, a `WALKTHROUGH:`
   block, and `accept-gate <P> --clear` as the clear command; every other `pending` prints exactly
   what it printed before.

**Parallel mode composes with no new machinery.** `_phases_at_ref` reads only known keys, so
`parallel-status` / `parallel-gate` are inert to the new block, and `phase.json` is a phase-folder
file rather than a generated one, so the block merges with the phase. The gate opens and clears **on
the branch**, before the branch `pass`, which is what `parallel-gate`'s existing "branch phase `done`
+ review `pass`" already implies. Doc consolidation defers exactly as it does for every phase since
v38 — to an operator-created docs phase — with the one worktree-specific wrinkle being the
serialized post-merge allocation described above.

**The duties live in the prompts, and parity is now a test.** `.claude/agents/slice-executor-{mid,high}.md`
carry the gate stages themselves — the `acceptance.required` switch, `## Operator Runtime` and
`## Regression Checklist` as named inputs, the six review gate stages, the `## Operator Questions`
append habit, `accept-gate` + `defer-job` on the prohibited-command list, and one new structured
return field, `walkthrough`. As of v32 the two tier files differ **only in frontmatter**
(`name`, `description`, `tools`, and the `sync-agents`-owned `model`/`effort`); their bodies are
byte-identical, and `tests/retrofit_smoke.sh` Test 0 pins that with a one-line parity assertion
(`body.split("---\n", 2)[2]` compared between tiers) so future drift fails the suite instead of
accumulating.

## System Shape

- <frontend runtime>
- <backend runtime>
- <database / persistence>
- <background workers / queues>
- <external integrations>

## Boundaries

- Frontend boundary:
- Backend boundary:
- Data boundary:
- External service boundary:

## Cross-Cutting Constraints

- <constraint>

## Open Questions

-
