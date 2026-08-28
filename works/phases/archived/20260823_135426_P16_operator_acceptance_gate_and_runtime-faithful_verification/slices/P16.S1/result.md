# Result — P16.S1 (Acceptance-gate engine: `phase.json` block + `accept-gate`)

**Status: done.** F2's machine-enforced operator acceptance gate is live in `scripts/workflow.py`,
exactly per `phase.md` decisions 1–4, 7 and 8. Engine only — no contract, skill or agent prose was
touched. `bootstrap_agentic_workspace.sh` is rebuilt and in sync.

## What landed (`scripts/workflow.py`, +227 lines, one file)

1. **`new_acceptance()` / `phase_acceptance(data)` / `acceptance_gate_is_open(data)`**, beside
   `phase_execution()` and documented the same way. `phase_acceptance` returns the block only when
   it is a dict whose `required` is `None`/`True`/`False`; anything else (or an absent key) returns
   `None` = "legacy, not gated". Every caller reads through it. `acceptance_gate_is_open` is the
   one predicate for "waiting on the operator to walk the product" (used by `next`).
   *Note:* the type test is `required is None or isinstance(required, bool)` — a literal
   `required in {None, True, False}` would have accepted `1`/`0`, since `1 == True` in Python.

2. **`new_phase` stamps the five-field block** — placed immediately after `review`, so `phase.json`
   reads `… review, acceptance, paths, archive`. Also flows through
   `promote-deferred --create-phase`, which calls `new_phase`.

3. **`phase.md` scaffold** gains `## Operator Questions` between `## Findings & Notes` and
   `## Constraints`, with one guidance line: *"Questions only the operator can answer; every entry
   is routed at the review — folded into the acceptance walkthrough (`accept-gate --open`) or filed
   with `defer-job`. An unrouted entry is a review finding."* Nothing else in the scaffold moved.

4. **`accept-gate <P>`** — one command, one argparse mutually-exclusive group
   (`--require | --waive | --open | --clear`), plus `--walkthrough` and `--note`. Shipped help:

   ```
   accept-gate   Operator acceptance gate for a phase: declare (--require/--waive), open it at the
                 review (--open), clear it (--clear), or show it (bare). Orchestrator/operator
                 command -- executors never run it
     --require        declare the phase operator-visible: review-phase --verdict pass refuses until
                      the gate is opened and cleared (creates the gate block on a legacy phase).
                      No status change
     --waive          declare the phase NOT operator-visible; --note is mandatory and records why
     --open           open the gate at the review: record --walkthrough, set the phase pending,
                      print the operator instructions (needs --require first)
     --clear          the operator walked the product: stamp cleared_at, return the phase to
                      in_progress
     --walkthrough    the concrete script the operator runs (URLs to open, actions to try, in the
                      operator runtime); use with --open
     --note           mandatory reason with --waive; optional record of what the operator reported
                      with --clear
   ```

   - Bare invocation prints `phase=`, `required=` (JSON vocabulary: `true`/`false`/`null`),
     `requested_at=`, `cleared_at=`, `note=`, then either `walkthrough=none` or a `walkthrough:`
     header followed by the raw text. Writes nothing — no event, no rebuild.
   - `--require` / `--waive` create the block on demand on a legacy phase (`_ensure_acceptance`
     re-orders the dict so the new key still lands right after `review`; a malformed block is
     replaced by a fresh one). Neither changes phase status. `--require` leaves the other four
     fields untouched, so a re-declaration after a waive keeps the old note until the next
     `--clear --note` overwrites it.
   - `--open` requires `required is True` and a non-blank `--walkthrough`; it stamps
     `requested_at`, nulls `cleared_at`, sets the phase `pending` via `_set_phase_status`, and
     prints the walkthrough plus the clear command.
   - `--clear` requires `requested_at`; it stamps `cleared_at`, records `--note` when given, and
     returns the phase to `in_progress`.
   - Mutating branches write `phase.json` first, then transition status, then
     `append_event("acceptance_required" | "acceptance_waived" | "acceptance_opened" |
     "acceptance_cleared", phase=<P>)` (plus the usual `phase_status_changed` for `--open`/
     `--clear`), then `rebuild_index_and_state()`.

5. **`review_phase`**: `_require_acceptance_cleared()` runs *before anything is written*, on
   `--verdict pass` only. Undeclared → `SystemExit` naming `--require` / `--waive --note`;
   `required: true` + no `cleared_at` → `SystemExit` naming `--open --walkthrough` then `--clear`.
   No block → one advisory line, pass allowed. `changes_requested`/`blocked` are never refused, and
   `changes_requested` resets `walkthrough` / `requested_at` / `cleared_at` to `null` while keeping
   `required` and `note`.

6. **`validate`**: shape check when `acceptance` is present (object; `required` true/false/null;
   `walkthrough`/`note`/`requested_at`/`cleared_at` string-or-null) plus the state error
   `phase <P> is done but its operator acceptance gate was never cleared; the operator must walk the
   running product (accept-gate <P> --open/--clear)`. **No warning for an absent block** — the five
   legacy phases in this repo validate silently.

7. **`next`**: in the existing `waiting` branch only. When the waiting target is a *phase* whose
   gate is open, it prints two extra lines plus the walkthrough and swaps the clear command:

   ```
   acceptance_gate=open (requested_at=…) -- the operator must walk the running product before this phase's review can pass.
   WALKTHROUGH:
   <text>
   After the operator approves, clear it: python3 scripts/workflow.py accept-gate P90 --clear
   Add --note "..." to record what the operator reported.
   ```

   A pending *slice*, or a phase pending for any other reason, prints byte-identical output to
   before. No second halt state was added — this is the existing `pending` halt with a script
   attached.

8. **Parallel mode**: nothing added. `_phases_at_ref` parses whole `phase.json` blobs and reads only
   known keys, so `parallel-status` / `parallel-gate` are inert to the new key (`parallel-status`
   exercised in the copy). No gate check was added to `parallel-gate`: a branch `pass` already
   implies the gate was cleared.

9. **Artifact rebuilt**: `python3 installer/build.py` → 336015 bytes; `--check` OK.

## Validation

Throwaway copy at
`/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/fee2369d-edde-464e-8664-97a6e42e35e0/scratchpad/wscopy`
(repo copied with `shutil.copytree`, then every `works/phases/active/*` folder removed so the test
phases are the pointer). Transcripts: `scratchpad/e2e-1.log`, `e2e-2.log`, `e2e-3.log`. Nothing was
created in the real `works/`.

| # | Command (in the copy) | Outcome |
|---|---|---|
| 1 | `new-phase --phase P90 …` | ✅ `phase.json` keys `… review, acceptance, paths, archive`; acceptance = the exact five null fields; `phase.md` headings `Objective, Context, Decomposition, Findings & Notes, Operator Questions, Constraints, Open Questions` |
| 2 | `review-phase P90 --verdict pass` | ✅ refused, exit 1, names `--require` / `--waive --note` |
| 3 | `accept-gate P90` | ✅ `required=null`, `walkthrough=none`, writes nothing |
| 4 | `accept-gate P90 --require` → `review-phase P90 --verdict pass` | ✅ required set (status unchanged); pass refused, exit 1, names `--open` / `--clear` |
| 5 | `accept-gate P90 --open --walkthrough "open http://localhost:3000/ , click login, …"` | ✅ phase → `pending`, walkthrough + clear command printed |
| 6 | `accept-gate P90 --open` (no walkthrough) | ✅ error, exit 1 |
| 7 | `next` | ✅ `WAITING ON OPERATOR`, `acceptance_gate=open (requested_at=…)`, `WALKTHROUGH:` + text, `accept-gate P90 --clear` |
| 8 | `validate` (gate open) | ✅ passed |
| 9 | `accept-gate P90 --clear --note "login visible, search types ahead"` → `review-phase P90 --verdict pass` | ✅ phase → `in_progress`; pass recorded (`status -> done`) |
| 10 | `review-phase P90 --verdict changes_requested` (after the clear) | ✅ `walkthrough`/`requested_at`/`cleared_at` → `null`; `required: true` and `note` survive |
| 11 | `accept-gate P91 --waive` | ✅ error: `--waive requires --note "…"` |
| 12 | `accept-gate P91 --waive --note "machinery-only…"` → `review-phase P91 --verdict pass` | ✅ `required: false` + note; pass accepted with no advisory |
| 13 | P92 with the `acceptance` key stripped by hand: `accept-gate P92`, `review-phase P92 --verdict pass` | ✅ show prints the legacy line; pass accepted printing `acceptance: legacy phase (no gate block) -- pass recorded without an operator acceptance gate`; `validate` green |
| 14 | `accept-gate P92 --require` (legacy) | ✅ block created **after `review`** in key order |
| 15 | `accept-gate P93 --open --walkthrough "open /"` on `required: null` | ✅ error naming `--require`, exit 1 |
| 16 | `accept-gate P93 --clear` with nothing open | ✅ error naming `--open`, exit 1 |
| 17 | `accept-gate P93 --walkthrough "open /"` (no `--open`) | ✅ error, exit 1 |
| 18 | `accept-gate P93 --require --waive --note x` | ✅ argparse: `not allowed with argument --require`, exit 2 |
| 19 | `validate` on `done` + `required: true` + `cleared_at: null` | ✅ errors with the new message |
| 20 | `validate` on `acceptance: "nope"` / `{"required":"yes","walkthrough":3,"requested_at":[]}` | ✅ one error per malformed field |
| 21 | `review-phase --verdict pass` on the malformed block | ✅ advisory `malformed gate block -- treated as legacy (run: … validate)`, pass allowed (validate is the place that complains) |
| 22 | `parallel-status` in the copy | ✅ unaffected by the new key |
| 23 | pending **slice** → `next` | ✅ output byte-identical to before the change |
| 24 | `validate` (copy, end state) | ✅ passed |

Real workspace (nothing mutated in `works/`):

- `python3 scripts/workflow.py validate` → **Workflow validation passed.** (all five active phases
  are legacy-shaped, so the new checks stay silent)
- `python3 installer/build.py` → wrote 336015 bytes; `python3 installer/build.py --check` → **OK**
- `python3 scripts/workflow.py sync-agents --check` → **agent files in sync**
- `bash tests/retrofit_smoke.sh` → **ALL RETROFIT SMOKE TESTS PASSED** (includes
  `scripts/workflow.py == bootstrap-embedded WORKFLOW_PY` and `installer/build.py --check`)

## Deviations from `plan.md`

1. **`--walkthrough-file PATH` was skipped** (the plan made it optional: "only if it costs a few
   lines"). `--walkthrough "…"` takes multi-line shell strings fine, and every extra flag is
   surface S3–S5 must describe. Stated here as the plan asked.
2. **Two error paths the plan did not enumerate** were added because they are one line each and
   prevent silent nonsense: `--walkthrough` without `--open` errors, and `--open` with a blank
   walkthrough errors. Both name the right invocation.
3. **A malformed (not merely absent) `acceptance` block** is treated as legacy by `review-phase`
   with a distinct advisory line, rather than refusing. `validate` is the surface that reports
   shape errors; refusing a review over a typo would strand a phase. Not specified either way in
   the plan.
4. No test file was added, as instructed; the transcripts above are the one-off scripted check.

## Notes for S3–S6 (also appended to `phase.md`)

- The exact strings S3/S4 may quote: command `accept-gate`, flags `--require`, `--waive --note`,
  `--open --walkthrough`, `--clear [--note]`; the `next` line `acceptance_gate=open (requested_at=…)`
  followed by `WALKTHROUGH:`; the phase.md heading `## Operator Questions`.
- `accept-gate <P> --require` on an **already-`done`** phase is accepted and then makes `validate`
  fail with the "done but its operator acceptance gate was never cleared" error. That is the check
  working (the phase was never walked), but S6's migration note should tell adopters to opt **live**
  phases in, not finished ones.
- `--require` after a `--waive` keeps the stale waive reason in `note` until the next `--clear
  --note` overwrites it. Deliberate: fewer moving parts than clearing it.
