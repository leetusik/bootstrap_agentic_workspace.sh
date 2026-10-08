# Plan — P27.F2 (fix / low: wire the legacy migration into the paths an orchestrator walks)

## Finding (P27.REVIEW #2)

The review reproduced three ways a pre-v47 repo is never steered to `design-migrate`, all on scratch copies:
1. **Wrong hint.** On a pre-v47 root, `design-check` and `design-open` point at `design-init` and report `round.json missing`. Neither names `design-migrate`.
2. **Silent `tokens.css`.** Following that hint first (the changple_web copy) leaves the legacy root `tokens.css` silently in place as the drafter's `tokens.css`. It is not even listed as left in place.
3. **Numbering restart.** A claude-design round started before migrating restarts numbering at `01`. `design-migrate` then refuses with `claude-design/rounds already exists` (the vocky copy).

## Fix (does not change what `design-migrate` moves; stays low)

1. **Engine: a detector.** Add a helper `design_legacy_record(root)`. It returns the pre-v47 entries of a design root:
   - `rounds/*` entries without `round.json`;
   - a root `SIGNOFF.md`;
   - `grounding/`.

   Reuse `design_migrate`'s own classification rather than a second copy of the rule.
2. **Engine: the hints.** When the detector finds anything:
   - `design_scan`'s `design.json missing` / `no design root` problem, and the `round.json missing` problems, add or replace the hint with: `pre-v47 record: run python3 scripts/workflow.py design-migrate (dry run first), then design-init`.
   - `design-open` and `design-register` refusals name `design-migrate` ahead of `design-init`.
   - Keep each message one line.
3. **Engine: `design-init` refuses on a pre-v47 root that has no `design.json`.** It names `design-migrate` (dry run first) and exits non-zero. This is a refusal only; nothing moves. It closes the silent `tokens.css` path.
4. **Engine: `design-migrate`, `design.json` present.** When it moves legacy rounds and a root `tokens.css` exists, list it: `left in place: tokens.css (kept as schema 1's tokens.css; if it belongs to the old record, move it into claude-design/ by hand)`. It is listed only, never moved.
5. **Engine: the `claude-design/rounds already exists` refusal** adds the remedy in one clause: move each legacy round into `claude-design/rounds/` by hand, renumbering after the existing ones. Behaviour is unchanged.
6. **Skill (`design-cowork`).**
   - The claude-design handoff bullet, before the first round in a repo: if the root holds a pre-v47 record, run `design-migrate` (dry run, then `--apply`, then commit the renames) **before** creating any `claude-design/rounds/` folder, so numbering continues from the old rounds.
   - The drafter's `design-init` bullet gets the same "migrate first" line.
   - One sentence each.
7. **Smoke (Test 13).** One probe covers two refusals on a legacy fixture:
   - `design-init` refuses and names `design-migrate`;
   - `design-check` names `design-migrate`.

   Expect the prior baseline plus 1, 0 FAIL.

## Ship and validate

- Run `python3 installer/build.py`, then `--check`.
- Run `bash tests/retrofit_smoke.sh`, alone in its Bash call, in the foreground.
- Run `python3 scripts/workflow.py validate`.
- Re-run the review's three cases live on scratch copies: changple_web init-first, vocky claude-design-round-first, and one plain legacy root. Never touch real repos.

## Notebook

- Add to `## Decisions`: the detector, `design-init` refusing, and the migrate-first rule.
- Add to `## Doc impact`: `- operations.md: a pre-v47 design root is steered to design-migrate first (design-init refuses; check/open/register hints name it) (P27.F2)`.
- Rewrite `## Now` for the re-review.

Baseline after F1: smoke 202 PASS (F1's ordering pins added no PASS line); expect 203 after F2's probe.
