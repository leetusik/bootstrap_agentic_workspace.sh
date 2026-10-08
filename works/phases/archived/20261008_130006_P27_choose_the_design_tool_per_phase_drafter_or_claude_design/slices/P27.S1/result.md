# Result — P27.S1 (implementation / high)

- **status:** done
- **tier:** high
- **summary:** The engine now skips `docs/reference/design/claude-design/` in `design_scan`. A new `design-migrate` command moves a pre-v47 design record there, unchanged. It is a dry run by default, `--apply` moves, and it is all-or-nothing: every check runs before the first move, with a rollback on an OS error. `design-register` ends with a design-deck hint (the URL from `$AGENTIC_DESIGN_DECK_URL`, plus a warning for a repo outside `$DECK_PROJECTS_DIR`/`~/projects`). Six Test 13 probes were added (smoke 201 PASS / 0 FAIL), and a live migration of a scratch copy of changple5 leaves `design-check` with only "design.json missing".
- **files_changed:** `scripts/workflow.py`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P27/phase.md`, `works/phases/active/P27/slices/P27.S1/result.md`
- **validation:**
  - `python3 installer/build.py` — wrote 604,255 B; `python3 installer/build.py --check` — OK (pass)
  - `bash tests/retrofit_smoke.sh`, alone and in the foreground: **201 PASS, 0 FAIL** (baseline 195 + 6 new), `ALL RETROFIT SMOKE TESTS PASSED` (pass; re-run after the last comment-only edit)
  - `python3 scripts/workflow.py validate` — `Workflow validation passed.` (pass; the three warnings are pre-existing: P26 consolidation owed, stale docs, oversized sections)
  - live check on scratch copies of changple5, changple_web, navercafecollector, vocky, Mijual and arb_upbit_1 (pass; see below)
- **deviations:**
  1. The closing line on `--apply` adds `; run design-init only if this repo will use the drafter` only when there is **no** `design.json`. With one present, the repo already uses the drafter.
  2. With `design.json` present, a non-folder entry inside `rounds/` (for example `rounds/stray.txt`) is listed as `left in place (…)`, not moved. The plan named only top-level entries.
  3. The apply step is hardened beyond the pre-checks. If a move fails mid-way (`OSError`), it moves the finished entries back in reverse, removes only the folders it created, and exits non-zero. It says `rolled back, nothing moved`, or names each entry that could not be put back. A `claude-design` (or `claude-design/rounds`) that exists as a file is a named refusal.
  4. The smoke has six probes, not four. The plan's (a) to (d) are there, plus one probe for the `design.json`-present mode, and (b) is split into dry-run and `--apply` lines. The mixed refusal is folded into (c). Besides the URL, (d) also asserts the outside-folder warning, with `DECK_PROJECTS_DIR` pinned to a scratch path.
  5. The `left in place` lines also print on `--apply` and before `nothing to migrate`. Every line the command prints starts with `design-migrate: `, including the dry-run closing line.
  6. The smoke's top comment was edited **in place** (two lines stay two lines), so every line reference S2 and S3 hold for `tests/retrofit_smoke.sh` (L97–99, 153–154, 176, 257–273, 278, 314–320, 410, 579–586, 754–757, Test 13 at L1297) is still valid.
- **doc_impact:** `- operations.md: design-migrate (legacy → claude-design/) and the design-register deck hint with $AGENTIC_DESIGN_DECK_URL (P27.S1)`

## What changed in `scripts/workflow.py`

- **Constants** (beside `DESIGN_ROOT_REL`, each with its comment on the line **above**, so the smoke's `^CONST = "…"$` pin pattern at L278 can read them):
  - `DESIGN_LEGACY_DIR = "claude-design"` (L3026);
  - `DESIGN_DECK_URL_ENV = "AGENTIC_DESIGN_DECK_URL"` (L3031, next to `DESIGN_REGISTRY_ENV`).

  The design-block header comment gains a three-line v48 paragraph.
- **`design_scan`** (L3219): the stray-HTML `rglob` skips any path whose first part is `DESIGN_LEGACY_DIR`. I audited every other walk of the root in the design block. `cards/` and `rounds/` are read with `iterdir()` at the root only, and `design_round_problems` reads only inside `rounds/<id>/`. Nothing else in `workflow.py` walks `docs/reference/`, so the `rglob` was the only walk that needed the skip.
- **`design_deck_hint()`** (L3608): called on both success exits of `design_register` (the `already registered … (nothing written)` return and after the write) and on no refusal. It prints:
  - `design-deck reads this registry: <url>` when `$AGENTIC_DESIGN_DECK_URL` is set (stripped, non-empty); otherwise `… (set $AGENTIC_DESIGN_DECK_URL to print its URL here)`;
  - `design-deck only sees repos under its mounted projects folder (<dir>)`, where `<dir>` is `$DECK_PROJECTS_DIR`, else `~/projects`, expanded and resolved. That is design-deck's own `deck.sh` variable and default (`deck.sh:103`), read-only-checked in `~/projects/personal/design-deck`;
  - `warning: this repo is outside <dir>, so design-deck will show it as unavailable` when `ROOT.resolve().relative_to(<dir>)` raises. It uses `relative_to` + `ValueError` (it works on Python 3.8; the host runs 3.9.6).

  No URL is ever guessed.
- **`design_migrate`** (L3623) + argparse `design-migrate [--apply]` next to `design-register`. The rule is in `phase.md` `## Decisions`. The output is `would move <rel> -> <rel>` / `moved …` per entry, then any `left in place <rel> (<why>)` lines, then `dry run -- nothing moved; re-run with --apply`, or the commit hint on `--apply`. A refusal prints `design-migrate: refused -- nothing moved:` plus one `- …` line per problem, and exits 1. That covers every existing destination, a non-folder `claude-design`, and a `design.json`-less root whose `rounds/` holds a `round.json`. With no design root, it prints `refused -- no design root at docs/reference/design/; nothing to migrate` and exits 1. With nothing to move, it prints `nothing to migrate` and exits 0. After moving rounds out of a `design.json` root it runs `rmdir` on an emptied `rounds/`, and on nothing else.
- **argparse help:** `design-register`'s help and description gain one clause each for the hint and `$AGENTIC_DESIGN_DECK_URL` (and `$DECK_PROJECTS_DIR`). No other help string was touched (D21 stays deferred).

## Smoke (Test 13, `tests/retrofit_smoke.sh`)

These are the six new `ok` lines:
1. `design-register` prints the deck URL from `$AGENTIC_DESIGN_DECK_URL=http://100.64.0.1:8765/`, plus the outside-folder warning. It runs on the early-return path, placed before the "touched neither ~/.config" check, so that check covers this run too.
2. `design-check` exits 0 and never names `claude-design` with `claude-design/grounding/previews/x.html` and `claude-design/rounds/01-old/handoff.md` present (probe a).
3. `design.json`-present mode in `$F`: `rounds/02-legacy` and the root `SIGNOFF.md` move, `notes.txt` is listed as left in place, `rounds/01-signin` stays, and `design-check` passes afterwards.
4. Probe (b), dry run on a second scratch repo (`$DZ/legacy`, with `workflow.py` copied from `$F`): all four entries named, and the tree hash unchanged.
5. Probe (b), `--apply`: the root holds only `claude-design`, every file is byte-identical under the new prefix, and a second `--apply` prints `nothing to migrate`.
6. Probe (c): a new `SIGNOFF.md` plus `BRIEF.md` plus `rounds/02-b/round.json`, with `claude-design/SIGNOFF.md` already there. The command exits non-zero, names both the existing destination and the schema-1 round, and leaves the tree hash unchanged (the free `BRIEF.md` did not move).

## Live check (scratch copies only; the real repos were only read by `cp -R`)

Scratch: `/private/tmp/claude-502/…/scratchpad/p27s1/live-<repo>/`, built by `live.sh` there. After the run, every real repo's design tree had the same tree hash as before, and `git -C ~/projects/personal/changple5 status --porcelain docs/reference/design` is empty.

- **changple5:**
  - Before: `design-check` finds 49 problems. Among them, `grounding/previews/*.html` are flagged as stray HTML and every round has `round.json missing`.
  - Dry run: `would move` `SIGNOFF.md`, `grounding`, `rounds` → `claude-design/…`, and the tree is unchanged.
  - `--apply`: moved all three, and every file is byte-identical under `claude-design/` (tree hash with the prefix stripped equals the pre-move hash).
  - `design-check` afterwards: **1 problem, `design.json missing`**, as expected with no `design-init`. There are no stray-HTML problems, and the two `08-` rounds are not an issue.
  - A second `--apply`: `nothing to migrate`.
- **changple_web (dry run):** `README.md`, `SIGNOFF.md`, `rounds`, `tokens.css` → `claude-design/`. Exit 0, and the tree is unchanged.
- **navercafecollector (dry run):** `BRIEF.md`, `SIGNOFF.md`, `rounds` (its `rounds/01-foundations/attachments/` moves inside `rounds`). Exit 0, and the tree is unchanged.
- **vocky / arb_upbit_1 (dry run):** `SIGNOFF.md`, `rounds`. **Mijual (dry run):** `README.md`, `SIGNOFF.md`, `grounding`, `rounds`. All exit 0.

## Scratch probes (in the same scratch folder: `probe1.sh`, `probe2.sh`, and an inline rollback run)

- **No-`design.json` mode** (`t1`): no root, then refusal, exit 1. Dry run, then `--apply`: `.DS_Store` is listed as a dot-entry left in place. Second run: nothing to migrate. Conflict plus schema-1 round: refused, naming all three problems (`rounds` holds `02-b`, `claude-design/SIGNOFF.md` exists, `claude-design/rounds` exists), in the dry run and on `--apply` alike, with nothing moved.
- **`design.json`-present mode** (`t2`):
  - A pre-existing `claude-design/grounding` made the first attempt a named refusal.
  - With that removed, the migration moved `rounds/02-legacy`, `SIGNOFF.md` and `grounding`. It listed `notes.txt` and `rounds/stray.txt` as left in place, and `design-check` then passed with `claude-design/rounds/01-old` present.
  - `t3`: an emptied `rounds/` was removed and reported.
- **Register** (`t2`):
  - The write path, with no URL, printed the "set $AGENTIC_DESIGN_DECK_URL" line and the warning (`HOME` scratch, so `~/projects` is outside).
  - The early-return path, with `" http://100.64.0.1:8765/ "` (stripped) and `DECK_PROJECTS_DIR` set to a parent folder, printed the URL and no warning.
  - A broken `design.json` gave a refusal and no hint.
- **Rollback** (`t5`): `chmod a-w rounds` made the last move fail with `EACCES`. `README.md`, `SIGNOFF.md` and `grounding` were moved back, the created `claude-design/` was removed, and the command printed `failed -- [Errno 13] …; rolled back, nothing moved` and exited 1.

## Notebook

`phase.md` changes:
- The three S1 notes are consumed. The upstream-rule note is re-targeted to S2/S3, with the new 201 baseline.
- `## Decisions` gains the migrate rule and the `DECK_PROJECTS_DIR` reuse.
- New notes for S2 (constants, command, pin) and S3 (the exact command lines for the CHANGELOG).
- `## Doc impact` gains its line, and `## Now` is rewritten.
