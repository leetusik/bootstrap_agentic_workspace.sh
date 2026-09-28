# Plan — P21.S5 (oversized doc sections; R5, secondary)

## Context

Read `works/phases/active/P21/phase.md` whole (notes for S3–S5 and the upstream-repo rule bind you), then `slices/P21.S1/result.md` **§2.8** (the data: ~10% of H2 sections exceed 10 KB; the worst is 112,619 B ≈ 28k tokens, quietly defeating "read only the sections the work touches") and **§2.4** (the boundary: sectioning helps changple5 but *hurts* the three small-doc repos — so this is a remedy for oversized sections only, never a general prescription and never a substitute for deferral).

## What to change

Small and advisory, in this shape (deviate with reasons if the code argues otherwise):

1. **`scripts/workflow.py`**: an advisory **warning** (never an error) when a durable doc carries an oversized H2 section. Site it where docs are already touched — `validate` and/or the `doc-new-version` write path — whichever reads naturally; measure section size at the byte level on `docs/current/*.md`. One module constant for the threshold (e.g. `DOC_SECTION_WARN_BYTES = 10_000`-ish; pick from §2.8's data and say why). The warning names the doc, the section heading, its size, and the one-line advice (split at the next consolidation — a docs phase is where splitting happens naturally now).
2. **Guidance where doc-writing happens**: a sentence in the `doc-new-version` skill (and `docs/README.md` if it is the natural home) — when consolidating, split any section the warning names; splitting is per-doc judgment, not a sweep, and small docs are explicitly fine as they are (§2.4).
3. **Nothing else.** No auto-splitting machinery, no per-repo config, no CLAUDE.md paragraph — at most a clause if an existing sentence is now incomplete.

## Constraints

- Advisory only; exit codes unchanged everywhere.
- Installer: `python3 installer/build.py`, `--check` passes, rebuilt artifact in tree. One `## v38` CHANGELOG bullet; do **not** bump the version.
- Tests terse: a couple of `retrofit_smoke.sh` assertions (149 baseline — warning fires on a scratch oversized section, silent on the live repo if it is clean; if the live repo itself has an oversized section, the warning firing here is correct — note it, don't silence it).

## Validation

- Scratch copy with an artificially oversized section → warning names doc/section/size; clean copy silent; exit 0 both.
- Live repo: `python3 scripts/workflow.py validate` — report (don't fix) any real oversized section it flags.
- `bash tests/retrofit_smoke.sh` green; `python3 installer/build.py --check` passes.

## phase.md duties

One short `## Doc impact` line (operations.md or wherever the warning is durable truth; qa.md smoke count). Consume the S3–S5 notes that are now spent (the §11 pointer and the notebook-ceiling note die with you — S_REVIEW keeps its own). Keep the upstream-repo note, retagged for P21.REVIEW only. Rewrite `## Now` as the handoff to the REVIEW slice: what the review must validate per slice, that P21 will owe consolidation after its own pass, and the OQ1–OQ4 routing duty. Notebook at 16,221/16,384 — your consumptions free room; leave headroom.

## Boundaries

No commits, no status transitions, no accept-gate, no doc-new-version. Never edit `docs/current/*.md` by hand (generated); the warning is advice for the next docs phase, not a fix to apply now.
