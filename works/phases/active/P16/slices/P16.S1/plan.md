# Plan — P16.S1 (Acceptance-gate engine: phase.json block + accept-gate commands)

## Goal

Implement F2's machine-enforced operator acceptance gate in `scripts/workflow.py`, exactly as
fixed in `phase.md` § *Shared design decisions* 1–4 and 7–8 (read them first — they are
binding, and slices S3–S5 will quote the command names and field names you land here).
Engine only: no skill/contract/agent prose in this slice.

## Read first

- `works/phases/active/P16/phase.md` — decisions 1 (block shape), 2 (command surface),
  3 (what `review-phase` refuses / resets), 4 (legacy default), 7 (`## Operator Questions`
  scaffold heading), 8 (the `walkthrough` return is the *executor's*; `--open` is the
  orchestrator's), plus *Findings & Notes* ("`next`'s pending output is generic today",
  "Parallel mode composes without new work").
- `works/phases/active/P16/intent.md` §3–4 if you need the why (RC2/RC3, F2).
- `scripts/workflow.py`: `phase_execution()` (the helper pattern to mirror), `new_phase()`
  (where the block is stamped and the `phase.md` scaffold is written), `review_phase()`,
  `validate()` (the `execution` shape-check block is the pattern), `cmd_next()` (the
  `waiting` branch), `_set_phase_status()`, `append_event()`, `rebuild_index_and_state()`,
  the argparse wiring near the bottom, and `parallel_start()` as precedent for stamping a
  block on `phase.json`.
- `CLAUDE.md` *Hard Rules* (`pending` semantics — reuse the existing halt, never a second one).

## Changes

1. **`phase_acceptance(data)` helper** beside `phase_execution()`: returns the `acceptance`
   dict when present and well-formed, else `None`. All callers read through it.

2. **Stamp on `new_phase`:** every phase created from now on carries
   `"acceptance": {"required": null, "walkthrough": null, "requested_at": null, "cleared_at": null, "note": null}`
   (five fields, no more). Place it after `review` in the dict so the file reads naturally.
   Also add a `## Operator Questions` section to the `phase.md` scaffold written there
   (one line of guidance under it: routed at the review into the acceptance walkthrough or a
   deferred job). Do not otherwise reshape the scaffold.

3. **`accept-gate <P> [--require | --waive --note TEXT | --open --walkthrough TEXT | --clear [--note TEXT]]`**
   — one command, mutually exclusive flags (argparse mutually-exclusive group; bare invocation
   = show). Behaviour per decision 2:
   - `--require` → `required: true`; no status change. Refuse on a phase with no `acceptance`
     block? **No** — create the block on demand for a legacy phase (that is how an adopter
     opts an existing phase in); document that in the command help.
   - `--waive` → `required: false`, `note` = the mandatory `--note` (error without it).
   - `--open --walkthrough TEXT` → requires `required: true` (error otherwise, naming
     `--require`); writes `walkthrough`, stamps `requested_at = now_iso()`, clears
     `cleared_at`, sets the phase `pending` via `_set_phase_status`, and prints the operator
     instructions: the walkthrough text, then the clear command
     `python3 scripts/workflow.py accept-gate <P> --clear [--note "..."]`. Also accept
     `--walkthrough-file PATH` as an alternative source only if it costs a few lines; otherwise
     skip it (keep the surface small — state what you chose in `result.md`).
   - `--clear` → requires `requested_at` set (error otherwise: nothing is open); stamps
     `cleared_at`, records `--note` when given, returns the phase to `in_progress`.
   - bare → prints `required=`, `requested_at=`, `cleared_at=`, `note=`, and the walkthrough
     (or `none`); writes nothing (no rebuild, no event).
   - Each mutating branch appends one event (`acceptance_required`, `acceptance_waived`,
     `acceptance_opened`, `acceptance_cleared`, via `append_event`) and calls
     `rebuild_index_and_state()`.
   - Help text states: orchestrator/operator command; executors never run it.

4. **`review_phase` refusal + reset (decision 3):** before writing anything, on
   `--verdict pass` with a present `acceptance` block: `required is None` → `SystemExit`
   naming `accept-gate <P> --require` / `--waive`; `required is True and cleared_at is None` →
   `SystemExit` naming `accept-gate <P> --open --walkthrough "..."` then `--clear`. Block
   absent → allow, print one advisory line (`acceptance: legacy phase (no gate block) — pass
   recorded without an operator acceptance gate`). Never refuse `changes_requested` /
   `blocked`. On `changes_requested`, reset `walkthrough`, `requested_at`, `cleared_at` to
   `null` (keep `required` and `note`) so the gate re-opens for the re-review.

5. **`validate` (decision 4):** when `acceptance` is present, check shape — object; `required`
   in `{None, True, False}`; `walkthrough`/`note` str-or-null; timestamps str-or-null —
   and error on `status: done` + `required: true` + `cleared_at: null` (message in the same
   style as the existing "done but review status is …" error). **No warning for an absent
   block.**

6. **`next` (finding):** in the `waiting` branch, when the waiting target is a phase whose
   gate is open (`required` true, `requested_at` set, `cleared_at` null), print the
   walkthrough text and make the clear command `accept-gate <P> --clear` instead of
   `set-phase-status <P> in_progress`. Everything else in that branch unchanged.

7. **Parallel mode:** nothing new; but make sure `parallel-status`/`parallel-gate` code paths do
   not choke on the extra key (they read `phase.json` through `_phases_at_ref`; a new key is
   inert). Do not add gate checks to `parallel-gate` — branch `pass` already implies cleared.

8. **Rebuild the artifact:** `python3 installer/build.py`, then confirm
   `python3 installer/build.py --check` passes.

## Validation

Exercise the engine end-to-end in a **throwaway copy** of the workspace under the session
scratchpad (`/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/fee2369d-edde-464e-8664-97a6e42e35e0/scratchpad/` — e.g. `cp -R` the repo there, or
`git worktree`-free plain copy; never create test phases in the real `works/`). In the copy,
run with `python3 scripts/workflow.py …`:

- `new-phase --phase P90 …` → `phase.json` has the five-field `acceptance` block, `phase.md`
  has `## Operator Questions`.
- `review-phase P90 --verdict pass` → refused (undeclared).
- `accept-gate P90 --require`; `review-phase P90 --verdict pass` → refused (uncleared).
- `accept-gate P90 --open --walkthrough "open /, click login"` → phase `pending`; `next`
  prints `WAITING ON OPERATOR`, the walkthrough, and the `accept-gate P90 --clear` command.
- `accept-gate P90 --clear --note ok` → phase `in_progress`; `review-phase P90 --verdict pass`
  → accepted.
- `review-phase P90 --verdict changes_requested` on another gated phase after a clear →
  `walkthrough`/`requested_at`/`cleared_at` reset to null.
- `accept-gate P91 --waive` without `--note` → error; with `--note` → `pass` accepted.
- A phase with no block (e.g. copy P15's shape, or strip the key) → `pass` accepted with the
  advisory line.
- `validate` green in the copy throughout; `--open` on a `required: null` phase → error.

Then in the real workspace: `python3 scripts/workflow.py validate` and
`python3 installer/build.py --check` must pass. Record the exact commands and outcomes in
`result.md`. **No test file is added** — this is a one-off scripted check; keep the repo lean.

## Record

- `result.md`: what landed, command help as shipped, the validation transcript summary,
  deviations.
- `phase.md`: append a *Findings & Notes* line if anything about the engine surprised you that
  S3–S5 must know (e.g. exact error strings, exact `next` output format), and a one-line
  **Doc impact** note: `architecture` — the `acceptance` block and the review lifecycle;
  `operations` — the `accept-gate` command (S3 will add the rule text; you note the engine
  fact).

## Do not

- Touch `CLAUDE.md`, `.claude/`, `installer/payloads/`, `CHANGELOG.md`, or tests.
- Add a second halt state, a `phase.json` field beyond the five, or a second command.
- Commit, or run any state-transition command in the real workspace.
