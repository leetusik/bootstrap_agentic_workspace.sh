# Plan — P22.S2: make doc staleness explicit in docs/index.json and where docs are read (D14)

## Job

Implement D14: every durable doc carries an explicit last-updated marker (source commit sha, date, consolidating phase/slice) recorded in `docs/index.json` and surfaced where agents read docs, plus doctrine that a doc older than the owed `## Doc impact` notes is stale evidence, never current truth. No cadence knob — `CONSOLIDATION_DEBT_MIN_PHASES` stays 1 (if the work contradicts that, say so in `result.md`; do not tune silently).

Read `works/phases/active/P22/phase.md` first — the S2-addressed notes carry the verified `docs/index.json` shape, the helper inventory, and two load-bearing S1 constraints (v39 already open; the notebook no longer squeezes). Consume those notes.

## Machinery (scripts/workflow.py)

1. **Record the marker at write time.** In `new_doc_version()` (~line 322): add a `commit` field to both the frontmatter block and the appended index `versions` entry — the current HEAD sha (e.g. `git rev-parse HEAD`), best-effort and **never fatal**: in a checkout without git (or any error), record `null`/absent and carry on. Note the honest semantics: the sha is the commit the version was *created at* (the version file itself lands in a later commit); that is fine — date + source phase are the primary staleness keys, the sha is provenance.
2. **Surface it where docs are read.** `cmd_docs()` (~line 377) grows per-doc marker output: last-updated date, consolidating source, commit (or `unknown (pre-v39)` when the entry predates the field). Then the staleness cross-check: compose the existing helpers — `phases_owing_consolidation()` over active phases, `doc_impact_notes()` + `doc_impact_docs()` — to mark each doc that owed notes name as **STALE** (its durable truth trails the code; the notes are the newer evidence). A note naming no doc is surfaced as unassigned (the existing best-effort behavior), not guessed.
3. **One shared advisory line.** Follow the `consolidation_debt_line()` / `oversized_sections_line()` pattern: one helper builds a single `stale_docs=...` advisory line (naming the stale docs and pointing at the owed notes / `docs-debt`); `docs` prints it, and — judgment call, keep it lean — `validate` may print it as a warning only if it does not merely duplicate the adjacent `consolidation_owed=` line; if it would be redundant noise, fold the doc names into the existing surface instead and say so in `result.md`. Warning-only everywhere; exit codes unchanged.
4. **Generated header on `docs/current/*.md`.** `rebuild_docs()` copies version files verbatim, frontmatter included — so the `commit` frontmatter field from (1) already reaches `docs/current` for new versions. Decide whether that verbatim frontmatter suffices as "the generated header" (lean: yes — do not invent a second header format). Existing `docs/current` files keep their old frontmatter until the next consolidation; that is acceptable and is what the `docs` listing covers.
5. **Backfill choice (deliberately yours, per DECOMP):** backfill shas for existing entries via `git log -1 --format=%H -- <version path>` or render `unknown (pre-v39)`. Lean best-effort, never fatal; whichever you pick, record the reasoning in `result.md`.

## Doctrine

- `CLAUDE.md`: at the docs read-order item and/or the durable-docs Hard Rules bullet, one tight addition: a doc whose last update predates the owed `## Doc impact` notes is **stale evidence to check against those notes, never current truth** — the `docs` listing shows each doc's last-updated marker and staleness. Keep it to a sentence or two; this contract is a routing document.
- Check whether the executor agent files (`.claude/agents/slice-executor-*.md`) tell executors to read `docs/current` sections; if they do, one short clause pointing at the staleness rule — only if it earns its place, and keep the two tiers' bodies byte-identical where they are today.

## Smoke (core-only — D16 now binds you)

- Extend `tests/retrofit_smoke.sh` minimally: the marker lands in index + frontmatter on a new version, the missing-git path never raises, and the stale flag appears when an owed note names a doc. Terse probes, reuse the existing throwaway-workspace harness; no new fixture files.

## Release + installer

- Append D14 bullets to the **existing** `## v39 — 2026-09-02` CHANGELOG section; write its lead **"Why this release"** bullet (D14 is the headline); **extend** the single existing `Migration notes` bullet (never add a second — the smoke suite asserts exactly one per section); do **not** bump `WORKSPACE_VERSION` again.
- `python3 installer/build.py`; `--check` must pass; rebuilt `bootstrap_agentic_workspace.sh` in this slice's changed files.

## Bookkeeping

- Append `## Doc impact` one-liners (expect `architecture.md`, `operations.md`, `qa.md`, `decisions.md` per DECOMP's forecast — write what is actually true). Never run `doc-new-version` — P21's and P22's owed consolidation is D14 working as intended.
- Edit `phase.md` per contract (consume S2 notes, rewrite `## Now` last — note the acceptance gate is already declared waived in `phase.json`, so drop that stale "open for the orchestrator" line). Write `result.md` verdict-block-first; the notebook no longer squeezes, so record findings in full.
- Validate: `python3 scripts/workflow.py validate`, `bash tests/retrofit_smoke.sh`, `python3 installer/build.py --check`, plus a live `python3 scripts/workflow.py docs` run showing the marker and the P21-owed staleness in the output (paste it in `result.md`).
