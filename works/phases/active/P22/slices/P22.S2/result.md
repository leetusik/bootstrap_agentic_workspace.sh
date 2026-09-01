# Result — P22.S2: make doc staleness explicit in docs/index.json and where docs are read (D14)

- **status:** done
- **summary:** D14 shipped: every doc version now records a last-updated marker (date, consolidating slice, and the HEAD sha it was written at) in both `docs/index.json` and its frontmatter, and `workflow.py docs` / `validate` flag every doc an unconsolidated `## Doc impact` note has outrun as **STALE** through one shared `stale_docs=` line, with the "stale evidence, never current truth" doctrine landed in `CLAUDE.md` and both executor tiers.
- **files_changed:**
  - `scripts/workflow.py` (`head_commit()`, `doc_marker()`, `stale_docs()`, `stale_docs_line()`; marker written in `new_doc_version()`; marker + staleness printed by `cmd_docs()`; warning in `validate()`; `docs_debt()` rollup now reads the shared helper; `CONSOLIDATION_DEBT_MIN_PHASES` comment)
  - `CLAUDE.md` (read-order item 3, durable-docs Hard Rules bullet)
  - `.claude/agents/slice-executor-mid.md`, `.claude/agents/slice-executor-high.md` (input item 5, bodies still byte-identical)
  - `tests/retrofit_smoke.sh` (six D14 probes + one injected fixture note + header inventory)
  - `CHANGELOG.md` (`## v39` lead "Why this release" bullet + two D14 bullets; the single Migration notes bullet extended)
  - `bootstrap_agentic_workspace.sh` (rebuilt by `installer/build.py`)
  - `works/phases/active/P22/phase.md` (notebook edit), this `result.md`
- **validation:**
  - `python3 scripts/workflow.py validate` — PASS (exit 0; the new `stale_docs=` warning plus the inherited `consolidation_owed=P21` and `oversized_doc_sections=5`)
  - `bash tests/retrofit_smoke.sh` — PASS (exit 0, **158 PASS** lines, up from S1's 152; `ALL RETROFIT SMOKE TESTS PASSED`, re-run clean)
  - `python3 installer/build.py` then `python3 installer/build.py --check` — PASS (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`)
  - `python3 scripts/workflow.py docs` — live run pasted below: the marker under every doc and four docs flagged STALE from P21's owed notes
  - `python3 scripts/workflow.py sync-agents --check` — PASS (agent files still in sync; body edits touch no frontmatter)
- **deviations:** none in substance. The three judgment calls the plan delegated were decided as: **no sha backfill** (step 5), **a separate `validate` warning line rather than folding the doc names into `consolidation_owed=`** (step 3), and **the verbatim frontmatter is the generated header** (step 4). Reasoning for each below. `CONSOLIDATION_DEBT_MIN_PHASES` stays `1`; nothing in the work contradicted it.
- **doc_impact:** four one-line notes appended to `phase.md` (`architecture.md`, `operations.md`, `qa.md`, `decisions.md`). No `doc-new-version` was run — P21's and now P22's owed consolidation is exactly the state D14 makes visible.

## What landed

### 1. The marker, recorded at write time

`new_doc_version()` now calls `head_commit()` and writes the result to **both** sinks:

- the version's frontmatter — `commit: <sha>` (or `commit: unknown`), which `rebuild_docs()` copies **verbatim** into `docs/current/<doc>.md`, so the marker reaches the file a reader actually opens;
- the `docs/index.json` entry — `"commit": "<sha>"` or `"commit": null`.

`head_commit()` is best-effort and can never be fatal: `git rev-parse HEAD` with a timeout, every exception swallowed, and the output accepted only if it matches `[0-9a-f]{7,40}`. A missing binary, a directory outside any repo, and a repo with no commit yet all return `""` and the version still writes. The docstring states the honest semantics the plan asked for: **the sha is the commit the version was created at** (the version file itself lands in a later commit), so it is provenance — `created_at` and `source` are the staleness keys a reader judges by.

### 2. Surfaced where docs are read

`cmd_docs()` keeps its original first line per doc byte-for-byte (nothing that greps it breaks) and adds an indented marker line underneath:

```
architecture: latest=v0005_operator_acceptance_gate_on_phase.json_and_the_gated_phase-review_lifecycle_v32 current=docs/current/architecture.md latest_path=docs/versions/architecture/v0005_...md
  updated=2026-08-23 source=P16.REVIEW commit=unknown (pre-v39) -- STALE: 1 unconsolidated '## Doc impact' note(s) from P21 are newer than this version; read them (docs-debt) before trusting this doc
```

and closes with the one shared advisory line:

```
stale_docs=architecture, decisions, operations, qa (4 doc(s) named by 11 unconsolidated '## Doc impact' note(s) from P21; docs/current is older than those notes, so for those subjects it is stale evidence to check against them, never current truth -- read them with docs-debt)
```

The cross-check is a **composition of the helpers that already existed**, as the notebook instructed: `stale_docs()` runs `phases_owing_consolidation()` → `phase_doc_impact_notes()` → `doc_impact_docs()` and returns `{doc: {phase_id: note_count}}`. A note naming no known doc stays `(unassigned)` — surfaced, never guessed at — and is excluded from the stale line (an unassigned note names no doc to flag).

`docs_debt()` now *reads that same helper* instead of building the identical mapping inline (its per-doc rollup was byte-identical logic). One implementation, so `docs`, `validate` and `docs-debt` cannot drift into naming different doc sets. `docs-debt`'s output is unchanged.

### 3. One shared line, in `docs` and in `validate`

`stale_docs_line()` follows the `consolidation_debt_line()` / `oversized_sections_line()` pattern: one helper, `""` when nothing is stale, so a clean workspace stays silent.

**Judgment call (plan step 3): it is a separate `validate` warning, not folded into `consolidation_owed=`.** The two lines answer different questions and a reader needs both: `consolidation_owed=` names the **phases** that owe and the command that pays; `stale_docs=` names the **docs** that must not be read as current truth. Folding the doc names into the debt line would have made the one line longer *and* would have kept `docs` — the place docs are actually chosen — needing its own wording, which is the divergence the shared-line pattern exists to prevent. `validate` now prints three advisory warnings in a row (debt, stale docs, oversized sections), each on its own axis; exit codes are unchanged and every one of them is warning-only.

`next` was deliberately **not** given the line: it already carries `consolidation_owed=`, and the loop's most-read output does not need the doc-level detail — the agent that is about to read a doc runs `docs`.

**Related deliberate non-gate:** `stale_docs_line()` does **not** honour `CONSOLIDATION_DEBT_MIN_PHASES`. That knob tunes how loud the *debt* is (a debt may reasonably wait for a batch); staleness is a fact about the doc a reader is holding right now, and no cadence setting may quiet it. The knob's own comment was updated to record that v39 settled the cadence question by declining it — it stays `1`, and explicit staleness is what was taken instead of a cadence.

### 4. The generated header (plan step 4)

Taken as the lean reading: **the verbatim frontmatter is the header**. `rebuild_docs()` already copies version files whole, so from the first post-v39 consolidation `docs/current/<doc>.md` opens with `commit:` beside `created_at:` and `source:`. No second header format was invented, nothing rewrites existing `docs/current` files, and the smoke suite asserts the sha reaches `docs/current/security.md`. Existing snapshots keep their old frontmatter until their next consolidation; the `docs` listing covers them in the meantime.

### 5. Backfill: declined, deliberately (plan step 5)

Existing entries render `unknown (pre-v39)`; **no sha was backfilled** for the ~100 pre-v39 versions. Four reasons:

1. **It would be a different fact wearing the same name.** `git log -1 --format=%H -- <path>` yields "the commit that last touched this file"; the field written at v39 means "HEAD when this version was created". Mixing both under `commit` makes the marker unreadable exactly when it matters.
2. **`docs` must stay read-only.** A lazy backfill would turn a listing command into a writer of `docs/index.json`; a one-shot migration would touch ~100 entries in this repo and give adopters nothing, since their own history would still be pre-v39.
3. **The `unknown` rendering has to exist anyway** (a checkout without git writes `null`), so the code path is exercised either way.
4. **The sha is not the staleness key.** `created_at` + `source` already answer "how old is this and who wrote it"; the sha is provenance.

`doc_marker()` therefore distinguishes the two absences honestly: **key missing** → `unknown (pre-v39)`; **key present but null** → `unknown (no git at write time)`.

### 6. Doctrine

- `CLAUDE.md` read-order item 3 now reads the listing as marker-bearing: *"(`workflow.py docs` lists the set, each with its last-updated marker and a **STALE** flag where an owed `## Doc impact` note is newer — read a stale doc as evidence to check against those notes, never as current truth)"*.
- The durable-docs Hard Rules bullet gained one sentence before the review carve-out: *"**Consolidation is operator-paced, so staleness is explicit:** every version records its last update — date, consolidating slice, and the commit it was written at — in `docs/index.json` and its own frontmatter, and `docs` / `validate` name (`stale_docs=`) each doc an unconsolidated note has outrun; that doc is **stale evidence to check against those notes, never current truth**."*
- Both executor agent files **do** tell executors to read `docs/current` sections (input item 5), so the clause earned its place there: one sentence appended to that item, identical in both files. The two bodies remain byte-identical (`diff` shows only the frontmatter `name` / `description` / `tools` / `model` lines, as before), and `sync-agents --check` passes.

### 7. Smoke (six probes, core-only per D16)

Added to `tests/retrofit_smoke.sh`, all reusing the existing throwaway fixture — no new fixture files:

| Probe | What it pins |
|---|---|
| `docs prints a last-updated marker (date, source, commit) under each doc` | the marker reaches the listing |
| `docs flags the doc an owed note names as STALE` | per-doc flag **and** the shared `stale_docs=` line |
| `validate names the stale docs (warning, exit 0)` | the same line, advisory, exit-code-neutral |
| `paying the consolidation debt clears the STALE flag` | staleness is the debt, not a sticky label |
| `doc-new-version records the HEAD sha in the frontmatter, docs/current and the index entry` | all three sinks agree with `git rev-parse HEAD` |
| `doc-new-version survives a checkout without git (commit unknown/null, never fatal)` | run with `PATH=/var/empty`: `commit: unknown` + `"commit": null`, version still written |

Two supporting fixture edits: the injected `## Doc impact` block now carries a **second** note naming a real durable doc (`architecture.md: ...`) so there is something to flag — the original note naming no known doc stays, keeping the `(unassigned)` path covered — and the fixture is `git init`-ed with one commit just before the sha probe (the later dashboard test re-inits it harmlessly). Baseline **152 → 158 PASS**, suite re-runnable and self-cleaning.

## Findings worth carrying forward

- **Staleness tracks *stamped* debt, not in-flight notes.** `phases_owing_consolidation()` only sees phases whose review has passed (`consolidation: "pending"`), so a phase's own `## Doc impact` notes do not mark docs stale while that phase is still running. This is deliberate: "owed" then means the same thing in `docs`, `validate`, `docs-debt` and the archiving guard, and an in-flight phase's slices read the notes directly out of the notebook anyway. Consequence to expect: **P22's own four notes will only start flagging docs once `P22.REVIEW` passes.**
- **`stale` is now overloaded by one word in the engine.** `validate` has long errored with `current doc is stale; run rebuild-docs` — a different fact (the generated snapshot does not match its version file). The two messages are self-describing and never appear together, so no rename was made; noted so the next reader is not surprised.
- **P21's debt is what the live run demonstrates**: 11 owed notes across `architecture`, `decisions`, `operations`, `qa`, plus one unassigned. That is the D14 story working end to end on real data — the docs phase for P21 will clear it.
- **No contradiction with "no cadence knob" surfaced.** `CONSOLIDATION_DEBT_MIN_PHASES` remains `1` and was not tuned.

## Live evidence

```
$ python3 scripts/workflow.py validate
warning: consolidation_owed=P21 (1 phase owes durable-doc consolidation; docs/current trails the code until a docs phase runs doc-new-version over each '## Doc impact' list, then: docs-consolidated <P>)
warning: stale_docs=architecture, decisions, operations, qa (4 doc(s) named by 11 unconsolidated '## Doc impact' note(s) from P21; docs/current is older than those notes, so for those subjects it is stale evidence to check against them, never current truth -- read them with docs-debt)
warning: oversized_doc_sections=5 (...)
Workflow validation passed.        # exit 0

$ python3 scripts/workflow.py docs        # trimmed to four docs
api: latest=v0001_bootstrap current=docs/current/api.md latest_path=docs/versions/api/v0001_bootstrap.md
  updated=2026-06-09 source=bootstrap commit=unknown (pre-v39)
architecture: latest=v0005_operator_acceptance_gate_on_phase.json_and_the_gated_phase-review_lifecycle_v32 ...
  updated=2026-08-23 source=P16.REVIEW commit=unknown (pre-v39) -- STALE: 1 unconsolidated '## Doc impact' note(s) from P21 are newer than this version; read them (docs-debt) before trusting this doc
operations: latest=v0031_the_v37_aside_correction_reaches_operations_... 
  updated=2026-09-01 source=P20.REVIEW commit=unknown (pre-v39) -- STALE: 4 unconsolidated '## Doc impact' note(s) from P21 are newer than this version; read them (docs-debt) before trusting this doc
qa: latest=v0007_aside_s_two_real_surfaces_...
  updated=2026-09-01 source=P20.REVIEW commit=unknown (pre-v39) -- STALE: 4 unconsolidated '## Doc impact' note(s) from P21 are newer than this version; read them (docs-debt) before trusting this doc
security: latest=v0001_bootstrap current=docs/current/security.md latest_path=docs/versions/security/v0001_bootstrap.md
  updated=2026-06-09 source=bootstrap commit=unknown (pre-v39)
stale_docs=architecture, decisions, operations, qa (4 doc(s) named by 11 unconsolidated '## Doc impact' note(s) from P21; ...)

$ bash tests/retrofit_smoke.sh | grep -E "marker|STALE|stale docs|without git"
PASS: docs prints a last-updated marker (date, source, commit) under each doc
PASS: docs flags the doc an owed note names as STALE
PASS: validate names the stale docs (warning, exit 0)
PASS: paying the consolidation debt clears the STALE flag
PASS: doc-new-version records the HEAD sha in the frontmatter, docs/current and the index entry
PASS: doc-new-version survives a checkout without git (commit unknown/null, never fatal)
...
ALL RETROFIT SMOKE TESTS PASSED        # 158 PASS, 0 FAIL

$ python3 installer/build.py --check
OK: bootstrap_agentic_workspace.sh is in sync with installer/ source
```

The phase-level state (decisions, doc impact, what the review needs) is in `works/phases/active/P22/phase.md`, not restated here.
