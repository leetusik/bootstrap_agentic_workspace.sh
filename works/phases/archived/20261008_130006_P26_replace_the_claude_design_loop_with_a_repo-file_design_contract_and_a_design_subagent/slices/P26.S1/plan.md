# Plan — P26.S1: define the on-disk design contract and its engine commands

## Context

P26 replaces the Claude Design loop with design files kept in each product repo. A separate web dashboard, in its own repo and served from the operator's Mac over Tailscale, reads those files from disk. See `intent.md`.

This slice fixes the **interface both sides build against**:
- the contract, written as one `design-cowork/SKILL.md` section replacing §The design record;
- the engine commands that enforce it.

Every note in `phase.md` tagged `for P26.S1` or `for every slice` is binding. That covers the open questions, the gotchas, the P25 inputs and the upstream build and smoke rules.

## Orchestrator's leanings (take them unless you find a concrete reason not to; record the reason if you deviate)

1. **Root and projects.**
   - The design root is `docs/reference/design/`.
   - **One project per repo** by default, identified by a small manifest at the root (e.g. `design.json`: id, name, schema version).
   - Registry entries are per project, so several projects per repo can be added later without breaking readers. Don't build multi-project now.
2. **Library.**
   - The cumulative cards live at `docs/reference/design/cards/NN-slug.html`.
   - Line 1 of each card is the `@dsCard` marker: group (carrying the round address while under review), viewport, and anything else the dashboard needs, such as a title.
   - Tokens live at `docs/reference/design/tokens.css`, or a `system/` folder if you need more than one file.
   - A superseding card keeps its path (R2).
3. **Rounds and history.**
   - Each round lives at `docs/reference/design/rounds/<NN-slug>/`, holding `handoff.md`, `feedback.md`, `SIGNOFF.md` and `build-prompt.md`, plus a small machine-readable round manifest: status (open / signed / superseded), the cards it touched, the signoff date and the operator's words.
   - **Snapshot at close:** when a round closes, signed or superseded, its touched cards are copied, as they were at close and with the round address on, into the round folder.
   - That lets the dashboard walk past rounds with plain disk reads and no git. It also answers the gotcha that `regroup` erases the round address from the live cards.
   - The cost is some duplicated small HTML files. Accept it unless you find it breaks something.
4. **Commands** (flat hyphenated names, matching the CLI's style, e.g. `design-check`, `design-regroup`, `design-register`; exact names and whether snapshotting belongs to `regroup` or a separate close command are your call):
   - **`check`:** numbered and contiguous, no unnumbered or monolith card, valid markers, manifest and round manifests well-formed. Exit non-zero with named problems.
   - **`regroup` (or close):** removes the round address from line 1 only. Everything below line 1 must stay byte-identical, which you assert. It is idempotent and takes the round snapshot.
   - **`register`:** writes this repo's project into a registry **outside the repo**:
     - the default path is under `~/.config/…`, overridable by an env var;
     - absolute paths, idempotent, atomic write (temp + rename);
     - it prints what it wrote;
     - every test run points the env var at a scratch path.
   - Stdlib-only Python, inside `scripts/workflow.py`.
5. **Scope limits.**
   - No viewer, no `board.html`, and no dashboard code.
   - Don't touch the rest of `design-cowork` beyond the replaced section and the minimum cross-reference fixes; S3 rewrites the loop.
   - Don't touch `CLAUDE.md`, the other skills or the executors; that is S4.

## Work

1. Read the P25 inputs named in the notes (`P25.S2/result.md` §3.1, §4.1, §7; `P25.S1/result.md` §1). Read `design-cowork/SKILL.md` §The design record and §The card set, so the new section carries today's card contract over.
2. Write the new contract section into `design-cowork/SKILL.md`. It must be precise enough for a separate repo to implement a reader from it alone:
   - paths;
   - the manifest and round-manifest fields;
   - the marker grammar;
   - the round lifecycle;
   - the registry format and location;
   - a schema version.
3. Implement the commands in `scripts/workflow.py` with their `--help` text.
4. Add small smoke probes for the core invariants only:
   - `regroup` is byte-identical below line 1 and idempotent;
   - `check` catches a gap and an unnumbered card;
   - `register` is idempotent and writes only to the env-overridden path.

   Update any smoke pin the replaced section breaks. The `@dsCard` pins should survive.
5. Run `python3 installer/build.py`. In a separate Bash call, run `bash tests/retrofit_smoke.sh` as the only command in that call, in the foreground, with a 600 s timeout. Then run `python3 installer/build.py --check` and `python3 scripts/workflow.py validate`.
6. Edit `phase.md`:
   - `## Decisions`: the contract choices and the command names;
   - `## Doc impact`: operations (runbook: the design record becomes the contract + commands), architecture (the new commands and the registry outside the repo), qa (the smoke count);
   - `## Notes for later slices`: consume the S1 notes, and add notes for S2 and S3 about what the drafter and the loop must call;
   - `## Now`.

   Add an `## Operator Questions` entry only for a choice that `intent.md` doesn't settle and that turns on how the operator will use the dashboard.
7. Write `result.md` with the verdict block first. **End it with a short contract summary the orchestrator can relay verbatim to the operator**, who builds the dashboard against it.

## Validation

- smoke: all PASS;
- `installer/build.py --check`: OK;
- `validate`: exit 0;
- the operator's real registry is untouched: the real `~/.config` path must not be created by any test.
