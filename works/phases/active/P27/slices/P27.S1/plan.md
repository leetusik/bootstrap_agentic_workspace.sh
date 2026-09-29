# Plan — P27.S1 (implementation / high: core invariant)

## Goal

This slice makes three engine changes in `scripts/workflow.py`, so that a `claude-design` record can live beside the schema-1 contract, and pre-P26 repos can be moved into it:

1. `design_scan` ignores `docs/reference/design/claude-design/`.
2. New `design-migrate` command.
3. `design-register` prints a design-deck hint.

Read `works/phases/active/P27/intent.md`, `phase.md` (`## Decisions`, and the three S1 notes plus the upstream-rule note under `## Notes for later slices`). This plan settles the note's open point on legacy top-level files.

## 1. Scan skips `claude-design/`

- New constant beside `DESIGN_ROOT_REL`: `DESIGN_LEGACY_DIR = "claude-design"`, with a one-line comment: the `claude-design` tool's record home, in the pre-v47 layout, never read by the engine.
- `design_scan` stray-HTML walk (L3268–3274): skip any path whose first part is `DESIGN_LEGACY_DIR`.
- Check every other walk of the root in the design block (`rglob`, `iterdir`, `os.walk`) and make each skip it too. `cards/` and `rounds/` are root-level only, so they need nothing. If any other walk exists, it skips as well.
- `claude-design/` is **not** a problem, whatever it holds.

## 2. `design-migrate` (new command, design block + argparse beside `design-register`)

Moves a pre-P26 design record into `docs/reference/design/claude-design/`, unchanged. It is all-or-nothing, never deletes, never runs git and never writes `design.json`.

**What moves** (the rule, settling the open point):
- **No `design.json` in the design root** (a pure legacy repo: changple5, vocky, Mijual, arb_upbit_1, navercafecollector, changple_web): **every** top-level entry moves into `claude-design/`, except `claude-design` itself and dot-entries (`.DS_Store`, `.gitkeep`). Dot-entries are listed as "left in place". That covers `README.md`, `BRIEF.md` and `tokens.css`, which belong to the old record.
- **`design.json` present** (a repo that has already started using the drafter): only these move:
  - each `rounds/<name>/` that has no `round.json` → `claude-design/rounds/<name>/`;
  - `SIGNOFF.md` at the root;
  - `grounding/`.

  Every other top-level entry that is not schema-1 (anything but `design.json`, `cards`, `tokens.css`, `rounds`, `claude-design` and dot-entries) is listed as `left in place (not part of either contract; move it by hand if it belongs to the old record)` and is not moved.
- Never check legacy numbering: changple5 has two rounds numbered `08-`. Legacy means "no `round.json`", nothing more.

**Refusals.** All checks run before the first move. On a refusal nothing moves and the command exits non-zero, naming every conflict:
- a destination path already exists: `claude-design/<entry>`, or `claude-design/rounds/<name>`;
- no design root at all: refuse with "nothing to migrate".
- A root that has no `design.json` but whose `rounds/` holds any round with a `round.json` (mixed): refuse, and name the rounds.

**Modes:**
- **Default is a dry run.** It prints `design-migrate: would move <rel src> -> <rel dst>` per entry (paths relative to the repo), any `left in place` lines, then `dry run -- nothing moved; re-run with --apply`.
- **`--apply`** performs the moves in that order with `os.replace`/`Path.rename` (same filesystem, inside the repo), creating `claude-design/` and `claude-design/rounds/` as needed. It prints `moved <src> -> <dst>` per entry, then a closing line: `commit the move yourself (git sees it as renames); run design-init only if this repo will use the drafter`.
- Empty `rounds/` left behind after moving every round out: remove it only if it is truly empty (`rmdir`, which never deletes content), otherwise leave it.
- **Nothing to move:** print `design-migrate: nothing to migrate` and exit 0.
- **Help text:** name the rule briefly. Keep argparse help one-line style like its neighbours.

## 3. `design-register` deck hint

- New constant `DESIGN_DECK_URL_ENV = "AGENTIC_DESIGN_DECK_URL"`, next to `DESIGN_REGISTRY_ENV`.
- On **both** success exits (the "already registered … (nothing written)" return near L3588, and after the write near L3591), and on no refusal, print a short hint through one helper (e.g. `design_deck_hint()`):
  - `design-deck reads this registry: <url>` when `$AGENTIC_DESIGN_DECK_URL` is set (stripped, non-empty). Otherwise: `design-deck reads this registry (set $AGENTIC_DESIGN_DECK_URL to print its URL here)`.
  - `design-deck only sees repos under its mounted projects folder (<dir>)`, where `<dir>` is `$DECK_PROJECTS_DIR` if set, else `~/projects`, expanded and resolved.
  - If the resolved `ROOT` is not inside that folder (a `Path.resolve()` prefix check via `relative_to` or `is_relative_to`; Python 3.9+ is fine, but prefer a helper that works on 3.8 if the file targets it — match the file), add: `warning: this repo is outside <dir>, so design-deck will show it as unavailable`.
- The engine never guesses a Tailscale IP.
- Update the `design-register` argparse help/description to mention the hint and the env var in one clause. (D21 stays deferred; don't touch the other help strings it names.)

## 4. Smoke (Test 13, `tests/retrofit_smoke.sh` ~L1297)

Add small probes to the existing Test 13, using its `dw` wrapper, scratch `HOME` and registry env. They cover the core only:
- **(a)** A `claude-design/grounding/previews/x.html` plus a `claude-design/rounds/01-old/handoff.md` in the probe's design root → `design-check` does not name them. Assert that no problem line mentions `claude-design`.
- **(b)** A migrate fixture: a scratch repo copy with a legacy design root and no `design.json`. It holds `rounds/01-a/handoff.md`, `SIGNOFF.md`, `grounding/g.html` and `README.md`.
  - The dry run moves nothing (the tree hash is unchanged) and names each entry.
  - `--apply` moves all four under `claude-design/` with contents byte-identical.
  - A second `--apply` prints nothing to migrate.
- **(c)** A conflict: a pre-existing `claude-design/SIGNOFF.md` → a non-zero exit, and nothing moved.
- **(d)** `design-register` with `AGENTIC_DESIGN_DECK_URL=http://100.64.0.1:8765/` prints that URL.

Use the scratch-repo pattern Test 13 already uses. If the migrate fixture needs a separate repo root, copy the installed `scripts/workflow.py` into a second scratch folder, the way Test 13 sets up its repo. Keep the probes small, a handful of `ok`/`bad` lines. The baseline is 195 PASS, so expect 195 plus your new passes, and 0 FAIL.

## 5. Live check (read-only on real repos)

- Copy `~/projects/personal/changple5/docs/reference/design/` into the scratchpad as `<scratch>/c5/docs/reference/design/`, with `scripts/workflow.py` copied to `<scratch>/c5/scripts/`.
- Run `design-migrate` (dry run), then `--apply`, then `design-check`, **there**.
- Record the output summary in `result.md`: the moves, and that `design-check` afterwards names only "design.json missing" (expected, since no `design-init`), with no stray-HTML problems.
- Also dry-run on scratch copies of changple_web (the `tokens.css`/`README.md` case) and navercafecollector (`BRIEF.md`, `attachments/`).
- **Never** run anything inside the real product repos.

## 6. Ship

- `python3 installer/build.py`, then `python3 installer/build.py --check` (it must pass).
- `bash tests/retrofit_smoke.sh`, **alone in its Bash call**, in the foreground.
- `python3 scripts/workflow.py validate`.
- No version bump (that is S3). Don't edit `design-cowork/SKILL.md`: S2 writes the contract text for `claude-design/`, `design-migrate` and `$AGENTIC_DESIGN_DECK_URL`. Leave S2 a note naming the two new constants and the command.

## Notebook

Update `phase.md`:
- consume the three S1 notes;
- add a `## Decisions` line for the migrate rule (the no-`design.json` vs `design.json`-present split) and `DECK_PROJECTS_DIR` reuse;
- add a note for S2: name `DESIGN_LEGACY_DIR`, `DESIGN_DECK_URL_ENV` and `design-migrate` in the skill's contract text, and add a constants-vs-skill pin if the L278 pattern fits;
- add a note for S3: the CHANGELOG migration notes use the exact command lines;
- `## Doc impact`: `- operations.md: design-migrate (legacy → claude-design/) and the design-register deck hint with $AGENTIC_DESIGN_DECK_URL (P27.S1)`;
- rewrite `## Now`.
