---
doc_id: architecture
version: v0004
created_at: 2026-08-14T06:45:17+09:00
source: P15.REVIEW
summary: Single-harness repo shape: CLAUDE.md is the only contract, .claude/ the only entry points, and the artifact embeds Claude machinery alone (v31)
previous: v0003_opt-in_parallel_phase_execution_the_phase.json_execution_block_and_stream-scoped_selection
---

# Architecture

## Status

The workspace-cornerstone repo is self-hosting: it runs the workflow on itself and
ships its own machinery as a single-file installer. This document describes stable
system-level truth — most notably that the installer is a **build product**
assembled from an `installer/` source tree, that the workspace is **single-harness**
as of v31 (Claude Code only — one contract, one set of entry points, one embedded
machinery tree), and that phase execution is **stream-scoped**: by default a single
stream on the default branch, optionally one extra stream per phase on its own branch
+ git worktree.

## Current Repo Shape

- `CLAUDE.md`: the compact routing contract — **the only one**. There is no `AGENTS.md` twin (dropped in v31 with Codex support); an `AGENTS.md` an adopting repo keeps for other tools is that repo's own file and the workspace never reads or writes it
- `docs/current/`: generated latest doc snapshots
- `docs/versions/`: immutable durable doc versions by category
- `docs/index.json`: latest-version map
- `works/state.json`: current/next pointer
- `works/index.json`: generated machine index
- `works/backlog.md`: generated human dashboard
- `works/phases/active/`: active phase folders
- `works/phases/archived/`: archived phase folders
- `works/deferred/`: deferred job folders
- `works/.workspace-version.json`: per-workspace marker — `upstream_url`, integer `workspace_version`, `synced_commit`, `synced_at`
- `scripts/workflow.py`: workflow and docs version manager
- `.claude/`: the tool entry points — `skills/` (17 skill packages), `agents/slice-executor-{mid,high}.md`, `settings.json`. **The only such tree**: the `.agents/` skill mirror and the `.codex/` config + executor agents were deleted in v31
- `installer/`: source tree for the distributable (see below)
- `bootstrap_agentic_workspace.sh`: the **generated** single-file distributable (build product — never hand-edited)
- `CHANGELOG.md`: repo-only changelog, one `## v<N>` section per workspace version (not emitted to targets)
- `.github/workflows/workspace-ci.yml`: workspace CI (`validate` everywhere, plus the parallel merge gate on `phase/*` PRs) — seeded once by the installer, then owned by the adopting repo
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

## Execution Streams (opt-in parallel phases)

A workspace runs one **stream** by default: every active phase lives on the default branch and
one global pointer (`works/state.json`) names the next slice. A phase may optionally be opted
onto its own stream — its own branch and its own git worktree, driven by its own orchestrator
session — while the default stream keeps working on everything else.

**The schema.** `phase.json` may carry one optional top-level `execution` block; **its absence
means the phase is on the default stream and every behavior is exactly as before** (proven
byte-identical against the pre-parallel engine):

```json
"execution": {
  "mode": "parallel",
  "branch": "phase/P13-some-slug",
  "worktree": "/abs/path/to/worktree",
  "consolidation": "pending"
}
```

- `mode` — `"parallel"` is the only recognized value; anything else means default-stream behavior
  at runtime *and* is a `validate` error, so a typo fails loudly rather than silently disabling.
- `branch` — required when parallel, and *the* stream key: selection, the cross-stream view and
  the PR layer all key off the branch name, never off `order` or the worktree path. A duplicate
  `branch` across active phases is a `validate` error.
- `worktree` — informational only (a path, or `null` on a plain clone / after teardown). Nothing
  in the engine keys off it.
- `consolidation` — `"pending"` from opt-in until the post-merge step records `"done"`. A phase
  that is `done` + review `pass` + `consolidation: "pending"` (merged, docs not yet consolidated)
  validates cleanly, but cannot be archived.

The block is read **only** through `phase_execution(data)`, which returns `None` for anything
that is not a well-formed parallel block — that single accessor is what keeps "parallel" one
definition across the engine.

**Stream detection is the current git branch, not a marker file.** `current_stream(phases)`
collects the stamped `execution.branch` of every active phase and — only if at least one exists —
asks git for the current branch, returning it when it matches one and `None` otherwise. Detached
HEAD, a missing git, or a non-repo all resolve silently to the default stream, and an untouched
workspace never shells out to git at all. Because membership is derived from where the work
actually is, a `git worktree` and a teammate's plain clone of the same branch behave identically
and the stamp can never drift from reality.

**Scoping happens once, upstream.** The selection primitives are unchanged; `rebuild_index_and_state`
filters the phase list through `stream_phases(phases, stream)` before resolving. Consequences:

- the `works/state.json` pointer is stream-scoped — the default stream skips opted-in phases, and
  a phase worktree sees only its own phase (`state.json` gains a `"stream"` key only there);
- a `pending` slice or phase halts **only its own stream**, instead of stopping the whole repo;
- the dashboards still list **every** active phase, so nothing becomes invisible: `works/index.json`
  entries carry the `execution` block and `works/backlog.md` marks the row `· parallel: <branch>`.

**Generated state is regenerated, not merged.** `works/{state.json,index.json,backlog.md,deferred.md}`
and `docs/current/*.md` are derived files; a phase-branch merge resolves any conflict in them by
taking either side and re-deriving from the merged folders, which hold the real truth. Only the
append-only `works/events.jsonl` carries a merge attribute (`merge=union`, a git built-in).

**Doc versioning stays serial by construction.** `docs/index.json` is authoritative, hand-merged
truth (deliberately not a regenerated file), and version ids are allocated `max+1` per doc — so two
streams consolidating at once would pick the same `vNNNN`. Durable-doc consolidation for a parallel
phase is therefore deferred to a serialized post-merge step on the default stream, and that is
**engine-enforced**: `doc-new-version` refuses to run on a parallel stream before allocating
anything, and `validate` rejects two version entries claiming the same number within one doc.

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
