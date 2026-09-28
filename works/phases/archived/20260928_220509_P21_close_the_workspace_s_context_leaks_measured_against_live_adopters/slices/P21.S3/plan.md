# Plan — P21.S3 (surface consolidation debt in next/validate; R3)

## Context

Read `works/phases/active/P21/phase.md` whole first — the notes tagged for P21.S3 are binding — then `slices/P21.S1/result.md` §11d (why the debt must be visible) and `slices/P21.S2/result.md` for the landed state shape. S2 made the debt *exist* and left `next`/`validate` deliberately untouched; this slice makes it *visible* so operator-paced consolidation is never silent staleness.

## What to change

**`scripts/workflow.py` only** (plus doctrine touch-ups if a sentence becomes false):

1. **`next`**: when any phase owes consolidation, print one advisory line naming the owing phases and the paying command — e.g. `consolidation_owed=P21 (run a docs phase, then docs-consolidated <P>)`. Read the state only through `phase_consolidation(data)` / `phases_owing_consolidation(phases)` — never a raw field — so both the top-level key and legacy `execution.consolidation` surface. Keep the line stable/greppable in the `key=value` style `next` already uses; zero lines when nothing owes.
2. **`validate`**: an advisory **warning** (never an error) when phases owe consolidation, worded to name the phases and the command. Debt is expected operator-paced state, so it must not fail CI or block the loop.
3. **Cadence-independence** (the OQ1 note): no thresholds hardwired into behavior differences. If you add any "how loud" knob (e.g. warn only above N owing phases), default it to "always show one line" and make the knob a single constant an OQ1 answer can tune later — do not invent config plumbing.
4. Check `parallel-merge-finish`'s existing listing still reads consistently with the new line; align wording only if needed.

**Doctrine:** only where an existing sentence is now false or incomplete (e.g. a skill or CLAUDE.md line that says the debt is visible nowhere / only in parallel mode). One-line edits; the notebook's OQ2 pressure means no new paragraphs.

**Installer:** after machinery edits, `python3 installer/build.py` and `--check` must pass; leave the rebuilt artifact in the tree. **Do not bump the version** — v38 is open; append a bullet to `CHANGELOG.md`'s `## v38` section.

## Validation

- `python3 scripts/workflow.py next` on the live repo (nothing owes yet — the line must be absent) and in a scratch copy where a phase owes (line present, correct phases named).
- `python3 scripts/workflow.py validate` both states: clean here, one warning in the scratch copy, exit 0 in both.
- Legacy shape: a scratch phase with `execution.consolidation: "pending"` shows up identically.
- `bash tests/retrofit_smoke.sh` — 144 PASS baseline; add at most a couple of terse assertions for the new lines if the suite's style invites it.
- `python3 installer/build.py --check` passes.

## phase.md duties

Append a one-line `## Doc impact` note (operations.md and/or architecture.md: debt now visible in next/validate). Consume the notes tagged for P21.S3. Rewrite `## Now` for S4. Notebook is at 16,176/16,384 — consuming your two notes frees room; leave a few hundred bytes headroom.

## Boundaries

- No commits, no status transitions, no accept-gate, no doc-new-version.
- Do not build S4's entry point; do not touch the review path.
