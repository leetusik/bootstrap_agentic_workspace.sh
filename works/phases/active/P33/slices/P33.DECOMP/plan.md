# Plan — P33.DECOMP (decompose "One-shot /rotate-backlog: consolidate the doc debt, then archive")

## Context

P33 turns `/rotate-backlog` from a three-step habit (archive → propose → operator runs `/do-whole-phase` and `/rotate-backlog` again) into one command that checks the debt first, creates and runs the docs phase, then archives everything done. The operator's confirmed intent, clarifications and the orchestrator's read of the machinery are in `works/phases/active/P33/intent.md` — read it whole before cutting. P33 runs in its own worktree on branch `phase/P33-one-shot_rotate-backlog_consolidate_the` (operator's word: "parallely"); P32 (v53) runs on the default stream at the same time and edits `do-whole-phase`, the executor files and the contract's executor section. The branch review later writes no doc versions (parallel mode).

This slice is the decomposition: it cuts the middle slices as bare folders with `new-slice`, records the breakdown and the cross-slice decisions in `phase.md`, and writes nothing else. Executor: `slice-executor-high` (by kind).

## What the orchestrator read (verified against the tree, 2026-10-12)

Engine (`scripts/workflow.py`, 4614 lines):
- `rotate_backlog` (~l.3601): archives every clean phase first (`_phase_blockers` empty), rebuilds, then `_print_docs_phase_proposal()` unless `--archive-only`. The proposal (~l.3560) prints `docs_phase=none` / `docs_phase_covered=<P> (pays …)` / the `docs_phase_proposal=` block with `phase=`, `name=`, `objective=`, the exact `create:` line (`new-phase --phase <P> --name … --objective … --consolidates …`) and `scope:`.
- `_debt_only` (~l.3466): every slice done + review pass + `consolidation: pending`, and a parallel branch already merged. `consolidation_cover` maps debt phases to the live docs phase that pays them.
- Selection: `phase_dirs()` sorts active phases by `order`; `stream_phases` scopes to the current stream; `resolve_current` (~l.1275) picks the first non-`done` phase and its first non-`done` slice. `new_phase` (~l.1809) takes `--order` (fractional allowed via `_clean_order`), default `max(order)+1` — so a freshly created docs phase queues **behind** every planned phase today.
- `docs_debt` (~l.2625), `docs_consolidated` (~l.2680), `parallel_consolidated` — default-stream only; `next_phase_id` (~l.1073).
- `new-phase` prints a parallel `hint:` when another phase is busy; the skill relays, never acts.

Skills and texts: `.claude/skills/rotate-backlog/SKILL.md` (propose-then-confirm, STOPs after `new-phase`), `.claude/skills/create-phase/SKILL.md` l.11 ("Invocation is not the gate; confirmation is") and *The docs-phase route* l.74–93, `.claude/skills/archive-phase/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md` l.53 and `.claude/skills/do-next-slice/SKILL.md` l.45 (the "do not archive here" lines), `.claude/skills/review-phase/SKILL.md` l.85 (mentions rotate as a manual step), `CLAUDE.md` (create-phase "when instructed" exception; "Archiving is manual and takes whole phases only").

Release plumbing: `installer/main.py` l.44 `WORKSPACE_VERSION = 52`; `python3 installer/build.py` / `--check`; `tests/retrofit_smoke.sh` l.888–913 (v51 rotate assertions on a copy `$ROT`: default run proposes, create line works, covered on re-run, `--consolidates` refusal, `--archive-only` prints no docs line); `CHANGELOG.md` (`## v52 — 2026-10-08` is the top entry; each entry ends with a **Migration notes** line).

Precedent: P30 (archived, v51) cut the same subject into S1 engine / S2 skills+texts+version, both `implementation / low`, and declared `accept-gate --require` with a throwaway-copy walkthrough.

## The shape to pin (DECOMP settles it; record the final form in `## Decisions`)

The orchestrator recommends the following engine shape — the executor verifies it against the code and may adjust, writing any departure as a Decision with its reason:

1. **`rotate-backlog` (default) becomes the one resumable step, re-runnable at any point of the chain.** It prints a machine-readable first line the skill branches on, in this order of precedence:
   - `rotate=refused` on a parallel stream (`current_stream` non-None): consolidation and archiving are default-stream only.
   - `rotate=stop_midflight midflight=<P.Sn:status, …>` when any slice on this stream (`stream_phases`) is `in_progress` or `pending`, or any phase is `pending` — **excluding the live docs phase itself** (the one `consolidation_cover` names), since resuming it is exactly what the next run does. Archives nothing.
   - `rotate=resume docs_phase=<P>` when a live docs phase covers debt (keeps today's `docs_phase_covered=` lines). Archives nothing.
   - `rotate=create` plus today's proposal block, with the `create:` line now carrying `--order <jump>` so the docs phase sorts **ahead of every non-done phase on the stream** (e.g. `min(order of non-done phases) - 1`, or a fraction when the minimum is 1 — `_clean_order` allows fractions). Archives nothing.
   - `rotate=archive` when nothing owes (no debt-only phase, no live docs phase): runs today's archive sweep (whole phases, no `--force`) and reports, ending in `docs_phase=none`.
   `--archive-only` keeps today's archive-and-report behaviour unchanged (no decision line beyond what it prints today, no docs line). The archive gate, the manifest, `archive-all` and `archive-phase` are untouched.
2. **The queue jump is an order, not a new state.** No new phase status; `next`, `resolve_current` and `stream_phases` are unchanged — the docs phase simply has the lowest order among non-done phases, so `next` points at it until it is `done`, then falls back to the planned work. Verify `validate` accepts two `in_progress` phases on one stream (a docs phase running ahead of an `in_progress` phase whose slices are all at a boundary) and that `new-phase --order` with a fraction round-trips through `rebuild`.
3. **The skill does the chain, the engine prints the decisions.** `/rotate-backlog`: run `rotate-backlog` → on `create`, run the printed `create:` line as is (the invocation is the yes; the proposal is still shown to the operator in the report), fill `intent.md` per `create-phase`'s docs-phase route (origin `operator`, the invocation verbatim, the `docs-debt` scope, the per-doc cut) and commit → on `create` or `resume`, run the docs phase end to end **per the `do-whole-phase` skill in `auto`** (`gate` in the invocation args restores the approval loop; the docs phase's `DECOMP` plans inline under `auto`, its gate is `--waive`d at that boundary), its normal stops ending the run → when it is `done`, run `rotate-backlog` again, which now takes the `archive` branch and sweeps every done phase, the docs phase included → report. `archive-only` → `rotate-backlog --archive-only`, relay, STOP. A `stop_midflight` / `refused` line → relay and STOP.
4. **Texts that move with it:** `create-phase` l.11 and the docs-phase route (the `/rotate-backlog` invocation is the confirmation for this route only; the route no longer says "after it archives the clean phases"); `archive-phase` (rotate's description: debt first, docs phase, archive at the end); `do-whole-phase` l.53 and `do-next-slice` l.45 (archiving is `/rotate-backlog`'s job, never the loop's; a run embedded in `/rotate-backlog` archives through that command, after the phase); `review-phase` l.85 wording; `CLAUDE.md` (the create-phase exception gains "and `/rotate-backlog`'s docs-phase route, where the invocation is the yes"; "Archiving is manual" → "Archiving is explicit — `/rotate-backlog`, `archive-all`, `archive-phase <P>` — and takes whole phases only"). Keep every edit minimal and in the files' own voice.
5. **Release:** `WORKSPACE_VERSION = 54` in `installer/main.py`, a `## v54 — <date>` CHANGELOG entry placed directly under the header (P32's v53 entry slots between v54 and v52 at merge — note that in `## Notes for later slices` for the review and the merge), `python3 installer/build.py` and the rebuilt `bootstrap_agentic_workspace.sh` in the same commit, `--check` passing; the smoke test's v51 block updated to the new default (no archive while debt stands; `rotate=` lines; the `--order` jump; `stop_midflight`; archive on the second run after `docs-consolidated`) with the pre-v51 archive-only assertions kept.

## The cut to make (recommended; the executor rates with named triggers)

Create as bare folders with `python3 scripts/workflow.py new-slice --phase P33 --slice P33.S<n> --name "…" --kind implementation --risk <r>` (never pre-fill `plan.md`):

- **S1 — Engine: rotate-backlog decides, archives last** (`implementation`, **`high`**, trigger: **core invariant** — it moves the archive sweep's conditions (folder moves out of `active/`) and the docs phase's position in stream selection). Scope: item 1–2 above plus the engine-level smoke assertions for them (the v51 block in `tests/retrofit_smoke.sh`), `validate` clean.
- **S2 — Skills and contract: the one-shot chain** (`implementation`, `low`): items 3–4 — `rotate-backlog`, `create-phase`, `archive-phase`, `do-whole-phase`, `do-next-slice`, `review-phase` line, `CLAUDE.md`. Depends on S1's printed lines (S1 records them in `## Decisions`).
- **S3 — Release v54** (`implementation`, `low`): item 5 — version bump, CHANGELOG v54 with its Migration notes line, installer rebuild, full smoke run (`bash tests/retrofit_smoke.sh` alone in its Bash call), `build.py --check`.

Fewer slices (S2+S3 merged, as P30 did) is acceptable if the executor judges the texts and release small enough; more than three needs a reason in the breakdown. No research slice is expected: the machinery is read and the open questions above are verifiable in-slice. No design slice (nothing visual).

## What `phase.md` must carry after this slice

- `## Decisions`: the engine shape (the `rotate=` lines and their precedence, the `--order` jump rule, the mid-flight rule and its docs-phase exclusion, `--archive-only` unchanged), the v54 placement rule, and the P32 overlap rule (the second phase to merge rebases on the other's text in `do-whole-phase` and `CLAUDE.md`).
- `## Notes for later slices`: per-slice gotchas tagged `**(from P33.DECOMP, for P33.Sn)**` — the smoke test must be the only command in its Bash call; `installer/build.py` after every machinery edit; the worktree review writes no doc versions and tags its two gate sections `(gate section — written at merge)`; the durable-doc notes to leave (`operations.md` *Durable-doc consolidation* paragraphs and the v51 note, `decisions.md` v0043) belong in `## Doc impact`, written by the slices that change the behaviour, not now.
- `## Now`: ≤ 15 lines, the next slice's starting point.
- The acceptance gate is the orchestrator's call after `finish-slice`: **`accept-gate P33 --require`** — the operator sees the new `/rotate-backlog` chain; the review's walkthrough runs it in a throwaway copy, as P30's did.

## Validation (the executor's)

`python3 scripts/workflow.py validate`; the new slice folders exist with `slice.json` only (no `plan.md`); `phase.md` under budget with the generated `## Slices` block regenerated (`rebuild`).

## Not in this slice

No engine, skill, test or contract edits; no `plan.md` for any middle slice; no `accept-gate`, no commit (the orchestrator commits after `finish-slice`).
