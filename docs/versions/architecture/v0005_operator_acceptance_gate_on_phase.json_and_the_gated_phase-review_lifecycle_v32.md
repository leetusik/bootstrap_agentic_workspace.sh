---
doc_id: architecture
version: v0005
created_at: 2026-08-23T07:48:23+09:00
source: P16.REVIEW
summary: Operator acceptance gate on phase.json and the gated phase-review lifecycle (v32)
previous: v0004_single-harness_repo_shape_claude.md_is_the_only_contract_.claude_the_only_entry_points_and_the_artifact_embeds_claude_machinery_alone_v31
---

# Architecture

## Status

The workspace-cornerstone repo is self-hosting: it runs the workflow on itself and
ships its own machinery as a single-file installer. This document describes stable
system-level truth — most notably that the installer is a **build product**
assembled from an `installer/` source tree, that the workspace is **single-harness**
as of v31 (Claude Code only — one contract, one set of entry points, one embedded
machinery tree), that phase execution is **stream-scoped** (by default a single
stream on the default branch, optionally one extra stream per phase on its own branch
+ git worktree), and that since v32 a phase may carry an **operator acceptance gate** —
a second optional `phase.json` block that puts the product owner between the review
executor's judgment and a recorded `pass`.

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
+ review `pass`" already implies. Only doc consolidation is deferred, exactly as before.

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
