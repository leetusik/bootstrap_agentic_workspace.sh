# CLAUDE.md

> Equivalent to `AGENTS.md`. If you change workflow rules, update both.

## Agent Contract

This file is a compact routing contract. Operational detail lives in `scripts/workflow.py`, the Agent Skills under `.claude/skills/` and `.agents/skills/`, and the active slice folder.

Core rule: **Backlog routes. Slice folder explains. Result summarizes. Docs are versioned durable truth.**

## Driving This Workspace

Everything runs through one manager: `python3 scripts/workflow.py <command>`. The same operations are also packaged as Agent Skills so they work natively in either tool:

- **Claude Code:** slash commands like `/do-next-slice`, `/do-whole-phase`, `/review-phase` (from `.claude/skills/`), plus the read-only `phase-reviewer` subagent. `.claude/settings.json` pre-approves the workflow script so it runs without prompts.
- **Codex:** the same skills under `.agents/skills/` via `$skill` or `/skills`. Codex reads this file as `AGENTS.md`.
- **Any agent / CI:** call `python3 scripts/workflow.py ...` directly. This always works, even where skills are unavailable.

Workflow command-skills are explicit-invocation only; agents should not fire them autonomously.

**Making a phase ≠ executing it.** When the operator asks you to make, create, suggest, or plan a phase, the job is to run `new-phase` — which creates only `P<N>.DECOMP` and `P<N>.REVIEW` — and then STOP and report. Do **not** decompose the phase into middle slices, do **not** write slice plans, and do **not** implement any code. Decomposition is the `DECOMP` slice's own job and happens later, when the operator executes the phase (`/do-next-slice`, `/do-whole-phase`) or explicitly tells you to. Creating several phases at once is fine; decomposing or executing any of them is a separate, explicit step.

## Read Order

1. `docs/current/*.md` for the fullstack doc set
2. `docs/index.json`
3. `works/state.json`, `works/backlog.md`, and `works/deferred.md`
4. The active phase folder and active slice folder only

Do not read every historical slice or old doc version by default. Archived phases and old doc versions are history.

## Canonical State

- Current pointer: `works/state.json`
- Generated dashboards/index: `works/backlog.md`, `works/deferred.md`, `works/index.json`
- Phase state: `works/phases/active/<phase_id>/phase.json`
- Phase notebook: `works/phases/active/<phase_id>/phase.md` — objective plus the accumulating decomposition, findings, and cross-slice notes; the shared context across a phase's slices
- Slice state: `works/phases/active/<phase_id>/slices/<slice_id>/slice.json`
- Slice context: `plan.md` (filled at slice start, incl. verbatim operator notes) and `result.md` (written at slice end), beside `slice.json`
- Deferred state: `works/deferred/open/<DID>/deferred.json`
- Doc index: `docs/index.json`; latest docs: `docs/current/*.md` generated from `docs/versions/<doc>/vNNNN_*.md`

## Hard Rules

- Keep `works/backlog.md` and `works/deferred.md` lean: IDs, names, statuses, pointers, paths only. Detail goes in the folders.
- Never patch old files under `docs/versions/`; create a new version with `doc-new-version`.
- Treat `docs/current/*.md` as generated snapshots; never hand-edit them.
- New phases start with only `P<N>.DECOMP` and `P<N>.REVIEW`. Decomposition (the `DECOMP` slice) creates the middle slices **only** — bare folders — and records the slice breakdown, findings, and notes in `phase.md`; it does **not** pre-fill the new slices' `plan.md`.
- "Make/create/suggest a phase" = run `new-phase` (creates `DECOMP` + `REVIEW` only), then stop — do not decompose, write slice plans, or implement until the operator executes the phase or says to. See *Driving This Workspace*.
- Each slice owns exactly two context files: `plan.md` (the slice fills its **own** plan when it runs, before implementing; record any operator note passed with `do-next-slice`/`do-whole-phase` verbatim under `## Operator Input (verbatim)`) and `result.md` (write when done). A slice never pre-fills another slice's `plan.md`. There are no per-slice brief or review files.
- `phase.md` is the phase notebook: the `DECOMP` slice seeds it (breakdown, findings, notes), and every slice reads it for accumulated context at start and appends durable cross-slice notes back to it when it finishes — so later slices build on what earlier ones learned.
- Slice selection is by `order`; `depends_on` is advisory and only checked for existence by `validate`.
- Operator co-work (`pending`, shown `[~]`): when a slice or phase needs the operator — to validate something, or to run an action only the operator can perform — set it `pending` (`set-slice-status <id> pending` or `set-phase-status <P> pending`), report exactly what you need, and STOP. A `pending` item halts selection: `next` prints `WAITING ON OPERATOR`, and neither `do-next-slice` nor `do-whole-phase` may start, finish, or advance past it. Work resumes only after the operator approves — they (or you, on their explicit say-so) clear it with `set-slice-status <id> in_progress` (or `set-phase-status <P> in_progress`). `pending` means "waiting on the operator" and is distinct from `blocked` (an impediment or unmet dependency you cannot resolve yourself).
- Deferred jobs never affect next-slice selection until promoted.
- Record the phase review with `review-phase`. A passing review marks a phase `done` but does **not** archive it — the phase stays in `active/`. Archiving is a separate, manual step: `archive-all` once every active phase is done (the last review slice complete), `rotate-backlog` to archive just the done phases while others continue, or `archive-phase <P>` for a single review-passed phase. Archive whole phases only, never individual slices.

## IDs and Status

- Phase IDs: `P1`, `P2`, ... with status `planned | in_progress | in_review | pending | blocked | done`
- Slice IDs: `P1.DECOMP`, `P1.S1`, `P1.F1`, `P1.REVIEW`, ... with status `todo | in_progress | in_review | changes_requested | pending | blocked | done`
- Deferred IDs: `D1`, `D2`, ... with status `deferred | ready | promoted | done | dropped`
- Doc versions: `v0001_bootstrap.md`, `v0002_<slug>.md`, ...
- Phase review verdicts: `pass | changes_requested | blocked`

## Workflow Commands

Use `python3 scripts/workflow.py <command>`:

- `next` — show current/next active slice
- `new-phase --phase P2 --name "..." --objective "..."`
- `new-slice --phase P1 --slice P1.S1 --name "..."` (`--kind`, `--risk`, `--order`, `--depends-on`)
- `start-slice P1.S1` / `finish-slice P1.S1` / `set-slice-status P1.S1 <status>`
- `set-phase-status P1 <status>`
- `set-slice-status P1.S1 pending` / `set-phase-status P1 pending` — hand off for operator co-work (validation or operator-run action); clear with `... in_progress` after approval
- `review-phase P1 --verdict pass|changes_requested|blocked [--reviewer NAME] [--note "..."]`
- `doc-new-version --doc frontend --summary "..." --source P1.S1` / `docs` / `rebuild-docs`
- `deferred` / `defer-job --title "..." --reason "..." --trigger "..." --source P1.S1`
- `promote-deferred D1 --phase P1 --slice P1.S2 --name "..."` / `drop-deferred D1 --reason "..."`
- `archive-all` (batch-archive every active phase once all are done) / `rotate-backlog` (archive just the done phases, leave the rest) / `archive-phase P1` (archive a single review-passed phase)
- `rebuild` / `validate`

## Commit Convention

Use `type(scope): summary`, imperative voice, no trailing period. Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `perf`, `revert`.

By default, commit after each completed slice — at the end of `do-next-slice`, and at every clean slice boundary inside `do-whole-phase`. Outside the slice workflow, commit only when asked. Do not create branches unless the operator asks — work on the current branch, including `main`. Never push without being asked.
