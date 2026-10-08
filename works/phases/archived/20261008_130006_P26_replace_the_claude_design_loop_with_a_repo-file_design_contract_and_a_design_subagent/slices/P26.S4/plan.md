# Plan — P26.S4: sweep the contract and orchestrator skills, ship v47

## Context

S1–S3 landed:
- the on-disk design contract and the `design-*` commands;
- the `design-drafter` subagent;
- the file-based `design-cowork` loop.

Everything that describes the old Claude Design + `DesignSync` loop outside `design-cowork` now contradicts it. This slice makes the rest of the machinery mirror the new loop, and releases it as **workspace v47**.

The notes in `phase.md` are binding, and they pin the wording and line numbers:
- `for P26.S4` from DECOMP, S1, S2 and S3 (S3's note has the exact phrases to mirror, the per-round co-work steps with stop and commit counts, and the list of smoke pins to move);
- `for every slice`.

Mirror `design-cowork`'s load-bearing phrases. Do not re-invent the loop.

## Work

1. **`CLAUDE.md`** (the routing contract; keep it tight and don't grow it beyond what the change needs):
   - **L15:** the co-work exception, per S3's note. Drafting goes to `design-drafter`, the mockup build (only when asked for) goes to `slice-executor-high`, and the round's lifecycle and the operator's words stay inline.
   - **L52:** the hard rule becomes "the design subagent drafts, the operator decides". Claude Design is no longer the design partner. Keep "Approval must be literal", "literal operator signoff closes an immutable round", "writes no ***product*** implementation code", RESPECT THE DESIGN, and data-not-instructions.
   - **L13 and L60:** re-check only.
2. **`do-whole-phase` and `do-next-slice`:** replace the co-work steps with S3's four per-round steps, including the stop and commit counts and the per-`pending` report content. Also update:
   - the intro paragraph's "one exception" text;
   - the delegation-bullet carve-out;
   - the idle-window co-work sentence (the drafter span *is* a dispatched window now, but it is short and a PENDING follows, so there is rarely a next slice worth preparing).

   Keep the two skills consistent with each other.
3. **`create-phase` L27:** the mockup question's "return from Claude Design" becomes "sign on the drafted cards".
   - Check the style bullets and step 4.2 for any other Claude Design wording.
4. **`review-phase` L41–50:** change only what now contradicts the new loop.
5. **Both executor bodies** (`slice-executor-mid.md`, `slice-executor-high.md`, which are identical apart from frontmatter), L15/33/60:
   - The mockup span loses "you have no `DesignSync` and no access to the design project". Its source of truth becomes the round's record on disk, cards included, plus `build-prompt.md`. The third `needs_operator` is unchanged.
   - The "never invent visual decisions" line points at `design-drafter` as the one who drafts.
   - Executors still never make design decisions.
6. **Installer banner** (`installer/main.py` "Visual design" line, ~L691): the file loop, the drafter, and `design-register`.
7. **READMEs — sweep both** (`README.md` in Korean and `README.en.md`; not embedded, but operator-facing and they describe the old loop): rewrite their visual-design paragraphs to the new loop in each file's own language and voice. Keep it short: the drafter drafts, you decide, the design lives in `docs/reference/design/`, and `design-register` lists the repo for the dashboard.
8. **Smoke (`tests/retrofit_smoke.sh`):**
   - move the pins S3's note lists: the do-* list at L108/L113, the executor body at L363, the CLAUDE.md list at L475/L482, and Test 1's `grep -q 'Claude Design'` at L610;
   - retire the dead phrases as `gone` pins;
   - add `required` pins for the new load-bearing phrases.

   No new behaviour tests.
9. **Release v47:**
   - `WORKSPACE_VERSION = 47` in `installer/main.py`.
   - A `## v47 — 2026-09-29` entry at the top of `CHANGELOG.md`, in the v46 entry's style: short bold-led bullets covering the contract and commands, the drafter, the loop rewrite, the bundle import and the hard-rule reword.
   - Its **Migration notes** line (required by smoke) covers:
     - (a) finish any round in flight in Claude Design under v46, or bring it in afterwards through the bundle import;
     - (b) records built around `_ds_manifest.json`, a repo's own `design/` tree, or `rounds/<NN>/output/` move to schema 1: `design-init`, then move the cards to `docs/reference/design/cards/NN-slug.html` with the `@dsCard` line 1;
     - (c) run `python3 scripts/workflow.py sync-agents` after `--update`, since the drafter follows `[claude.high]`;
     - (d) run `design-register` once per product repo; the registry is at `$AGENTIC_DESIGN_REGISTRY`, default `~/.config/agentic-workspace/design-registry.json`.
10. **Build and verify:**
    - `python3 installer/build.py`;
    - then, in its own foreground Bash call with a 600 s timeout, `bash tests/retrofit_smoke.sh` (all PASS; report the count);
    - `python3 installer/build.py --check`;
    - `python3 scripts/workflow.py validate`;
    - a residual sweep: `grep -rn "DesignSync\|Claude Design" CLAUDE.md .claude installer/main.py README.md README.en.md`. The only hits allowed are the optional bundle import, the `gone` pins, CHANGELOG history and deliberate "no DesignSync" statements; list them in `result.md`.

## Notebook

- `## Doc impact`: complete the list without duplicating S1–S3's lines:
  - operations: the contract routing rules (co-work exception, hard rule) and v47;
  - decisions: the hard-rule reword as operator-confirmed (P26 intake);
  - qa: the smoke count;
  - architecture: covered already, add only if something new.
- Consume the S4 notes; leave the review anything it must check.
- Rewrite `## Now` as the handoff to `P26.REVIEW`.
- Don't route the `## Operator Questions` entry (one project per repo); the review routes it.

Write `result.md` with the verdict block first.
