# Result — P27.F2 (fix / low: steer legacy design roots to design-migrate)

- **status:** done
- **tier:** mid
- **summary:** A pre-v47 design root is now steered to `design-migrate` on every path an orchestrator walks. `design-check`, `design-open` and `design-register` name it ahead of `design-init`, and `design-init` refuses (nothing written) on such a root, which closes the silent `tokens.css` path. `design-migrate` lists a kept root `tokens.css` and its `claude-design/rounds already exists` refusal carries the remedy. `design-cowork` says to migrate before `design-init` or the first `claude-design/rounds/` folder. What `design-migrate` moves is unchanged.
- **validation:**
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: OK.
  - `bash tests/retrofit_smoke.sh` (alone, foreground): **203 PASS / 0 FAIL**, exit 0. The baseline was 202, plus the one Test 13 steer probe. No `Non-UTF-8` line.
  - `python3 scripts/workflow.py validate`: passed (three pre-existing warnings: P26 consolidation owed, stale docs, oversized doc sections).
  - The review's three cases plus two edge cases, live on scratch copies (below).
- **deviations:** small, all inside the plan's intent (listed at the end).
- **doc_impact:** appended to `phase.md`: `operations.md: a pre-v47 design root is steered to design-migrate first (design-init refuses; check/open/register hints name it) (P27.F2)`.

## What changed

- **`scripts/workflow.py`**
  - `design_legacy_record(root)` is the detector. It returns `rounds/<name>/` folders without `round.json`, the root `SIGNOFF.md` and `grounding/`.
    - `design_migrate`'s `design.json` branch now takes its moves from this helper, so there is one rule, not two copies.
    - It returns `[]` for a root with no `design.json` whose `rounds/` holds a schema-1 round. Without that carve-out the new `design-init` refusal would deadlock against `design-migrate`'s own "restore it with design-init first" refusal.
  - `design_legacy_hint(root)` builds the one-line steer: `pre-v47 record: run python3 scripts/workflow.py design-migrate (dry run first)`. It adds `, then design-init if this repo will use the drafter` when there is no `design.json`.
  - `design_scan`:
    - The hint replaces the `design-init` hint on `design.json missing` when a legacy record exists.
    - With a manifest, it rides on the first `round.json missing` line. It is said once, not once per round.
    - A root with no legacy record keeps the old text.
  - `design-open` and `design-register`: the "no valid design.json" refusals carry the hint instead of "run design-init". `design-open`'s "no well-formed round.json" refusal carries it too.
  - `design-init`: with no `design.json` and a legacy record it exits non-zero with the hint. This is a refusal only. Nothing moves and nothing is written, and there is no override.
  - `design-migrate`:
    - With `design.json` present and legacy parts moving, a root `tokens.css` is listed as `left in place … (kept as schema 1's tokens.css; if it belongs to the old record, move it into claude-design/ by hand)`. It is listed only, never moved.
    - The `claude-design/rounds already exists` refusal appends: `a claude-design round was started first -- move each legacy round into claude-design/rounds/ by hand, renumbering after the existing ones, remove the emptied rounds/, then re-run`. Behaviour is unchanged.
- **`.claude/skills/design-cowork/SKILL.md`**
  - The drafter's handoff bullet (the `design-init` one) and the claude-design handoff bullet each gained one sentence: run `design-migrate` (dry run, `--apply`, commit the renames) before `design-init` / before creating any `claude-design/rounds/` folder, so numbering continues from the old rounds.
  - The record section's "Migrating a pre-v47 repo" paragraph gained a clause: run it before the first `claude-design/rounds/` folder exists. It also says `design-init` refuses on such a root and that the three commands name `design-migrate`.
- **`tests/retrofit_smoke.sh`, Test 13:** one probe on the legacy fixture (`$MG`, before its migration).
  - `design-init` exits non-zero and names `design-migrate`, and no `design.json` is written.
  - `design-check` exits non-zero and carries `design.json missing; pre-v47 record: run python3 scripts/workflow.py design-migrate`.
  - The tree is byte-identical afterwards.
  - The file's header comment was reworded to mention it.
- **`CHANGELOG.md` (v48 entry):**
  - The `design-migrate` bullet says the three commands name it, `design-init` refuses, and it runs before the first `claude-design/rounds/` folder exists.
  - Migration note (3) says `design-init` comes only after the migration.
- **`bootstrap_agentic_workspace.sh`:** rebuilt (641,550 B), `--check` OK.

## Live checks (scratch: `…/scratchpad/p27f2/`, scripts `setup.sh` and `cases.sh`)

The real design folders were only read (`cp -R` into the scratchpad); nothing ran inside a real repo. Each scratch copy carried the current `scripts/workflow.py`.

- **A. changple_web, init-first (the review's silent-`tokens.css` case):**
  - `design-check`: 13 problems. The first reads `design.json missing; pre-v47 record: run … design-migrate (dry run first), then design-init if this repo will use the drafter`.
  - `design-init`: refused, exit 1. The folder still holds `README.md rounds SIGNOFF.md tokens.css`, with no `design.json`.
  - `design-open` and `design-register`: both refused, exit 1, with the same steer.
  - `design-migrate` (dry run) then moves `README.md`, `SIGNOFF.md`, `rounds` and `tokens.css`.
- **B. vocky, a claude-design round started before migrating (the review's numbering case):**
  - With `claude-design/rounds/01-new` present, `design-migrate --apply` refuses with the new clause, and nothing moves.
  - Following the clause by hand (the two legacy rounds become `02-…` and `03-…`, remove the emptied `rounds/`) lets a re-run move `SIGNOFF.md`. The result is `claude-design/{rounds,SIGNOFF.md}` with rounds `01-new`, `02-brand-app-landing`, `03-onboarding`.
- **C. vocky, a plain legacy root (drafter path):**
  - `design-check` (3 problems, hint first), `design-init`, `design-open` and `design-register` all steer to `design-migrate`.
  - The dry run moves `SIGNOFF.md` and `rounds`. `--apply` leaves the `claude-design/` tree byte-identical to the pre-move tree (tree hash compared).
  - Afterwards `design-check` reports `design.json missing (run: … design-init)`, the old text, since no legacy record remains. `design-init` writes the manifest and `design-check` is OK.
- **D. changple_web with a hand-written `design.json` (the `tokens.css` listing and the moves invariant):**
  - `design-check`: 12 problems, and the first `round.json missing` line carries the hint (`… design-migrate (dry run first)`, without the `design-init` tail).
  - `design-open` refuses with the hint.
  - The dry run lists `tokens.css` as left in place (with the kept-as-schema-1 explanation).
  - **The same fixture under the pre-F2 engine (`git show HEAD:scripts/workflow.py`) prints the identical dry run except for that one `tokens.css` line** (`diff`: `13a14 > …tokens.css…`). So what `design-migrate` moves did not change.
- **E. Edge: no `design.json` but a schema-1 round `13-new/round.json`:**
  - `design-check` keeps the plain `design.json missing (run: … design-init)`, with no migrate steer.
  - `design-migrate` refuses (restore the manifest with `design-init` first), and `design-init` succeeds. The carve-out works: no deadlock.

## Deviations from the plan (all small)

- **Hint wording.** The plan's text ended `, then design-init`. I added `if this repo will use the drafter`, because the intent (and `design-migrate`'s own closing line) makes `design-init` optional for a claude-design repo. With a `design.json` already present the tail is dropped, since `design-init` is already done.
- **The hint is said once per `design-check`,** on the `design.json missing` line, or with a manifest on the first `round.json missing`. The alternative, a hint on every legacy round, would repeat 12 times on changple_web.
- **The mixed-root carve-out** in `design_legacy_record` (empty for a no-`design.json` root that holds a schema-1 round) is not in the plan. It is required so `design-init` cannot block the manifest restore that `design-migrate` itself asks for (case E).
- **The rounds-exists remedy** also says "remove the emptied `rounds/`", because in a `design.json`-less root `design-migrate` moves the whole `rounds/` folder. A leftover empty one would make the re-run refuse again (case B follows the clause literally and passes).
- **No argparse help edit** (`design-init`'s help does not mention the refusal). It avoids firing D21 ("next `workflow.py` argparse-help edit") for a cosmetic gain; the refusal message is self-explanatory.
- **CHANGELOG amended** in two places, and the smoke's header comment: both are consequences of the behaviour change, and neither is in the plan's list.
- The drivers, `CLAUDE.md` (12,280 B, unchanged) and the executor bodies were not touched.

## Left for the re-run review

- A design root that holds a stray root `SIGNOFF.md` or `grounding/` that is *not* a legacy record (a drafter repo) now has `design-init` refuse until it is migrated. That follows the detector rule the plan asked for: `design-migrate` would move exactly those entries.
- Nothing new for the operator. No `## Operator Questions` entry was raised.
