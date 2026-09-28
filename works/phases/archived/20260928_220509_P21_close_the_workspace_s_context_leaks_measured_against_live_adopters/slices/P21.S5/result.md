# Result — P21.S5 (oversized doc sections; R5, secondary)

- **status:** done
- **summary:** Oversized `docs/current` H2 sections are no longer invisible: one threshold constant plus a shared advisory line that `validate` warns with and `doc-new-version` repeats beside `edit_path`, with splitting guidance in the skill and `docs/README.md`. Advisory only — warning at both sites, exit codes unchanged. Smoke 149 → 152 PASS; installer rebuilt.
- **files_changed:** `scripts/workflow.py`, `.claude/skills/doc-new-version/SKILL.md`, `docs/README.md`, `tests/retrofit_smoke.sh`, `CHANGELOG.md`, `bootstrap_agentic_workspace.sh`, `works/phases/active/P21/phase.md`, `works/phases/active/P21/slices/P21.S5/result.md`
- **validation:**
  - `python3 scripts/workflow.py validate` → **pass** (exit 0; prints the new `oversized_doc_sections=5` warning for this repo — see §4, reported not fixed)
  - `bash tests/retrofit_smoke.sh` → **pass** (152 PASS, 0 FAIL; baseline was 149)
  - `python3 installer/build.py` then `python3 installer/build.py --check` → **pass** (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`)
  - scratch oversized section (inside the smoke's throwaway fresh install): warning names doc/heading/size, exit 0; clean copy silent, exit 0 → **pass**
- **deviations:** one, small — no `CLAUDE.md` clause (§3). Otherwise as planned.
- **doc_impact:** `- operations.md: validate + doc-new-version warn (advisory, exit 0) when a docs/current H2 section exceeds DOC_SECTION_WARN_BYTES (10 KB), naming doc/section/size; split at the next consolidation, per-doc judgment; qa.md: smoke 149 -> 152 PASS (P21.S5)`
- **doc_versions:** n/a (not a review slice; deferred to a docs phase per v38)

---

## 1. What landed

**`scripts/workflow.py`** (+79 lines, three helpers + two call sites + one constant):

- `DOC_SECTION_WARN_BYTES = 10 * 1024` — one module constant, sited beside `DOC_TYPES`. Chosen
  straight from `P21.S1/result.md` §2.8: 10 KB is that measurement's own cut line, where **10.0 %
  of all H2 sections across the four adopters sit above it** and the worst single section is
  112,619 B (~28 k tokens). Above the line the read-order rule is defeated; below it the rule still
  works, so the check stays quiet on the other 90 %.
- `h2_sections(text)` — `(heading, bytes)` per `## ` section, heading to next `## ` (deeper headings
  are body, which is what a reader actually reads), fenced blocks skipped so a `## ` inside a shell
  example is not counted as a heading, size in bytes.
- `oversized_doc_sections(doc_ids=None, threshold=...)` — biggest first, measured on
  `docs/current/*.md` because that is what a slice reads. Best effort: a missing current file is
  skipped, never reported, so a partial or foreign workspace still validates.
- `oversized_sections_line(sections, limit=3)` — the single advisory line, `""` when nothing is
  over. Deliberately modelled on `consolidation_debt_line` (S3): **one helper, two sites, so the
  warning and the write-time hint can never word it differently.** Biggest three named
  (`<doc>.md '<heading>' <n> B`), headings truncated at 60 chars, then `+N more` — a bounded line,
  because an adopter like changple5 has ~27 sections over the line and 27 warning lines is noise
  nobody reads.

Two sites, both advisory:

1. **`validate()`** — appended to `warnings`, right beside the consolidation-debt warning; exit code
   untouched (0 with warnings, as before).
2. **`new_doc_version()`** — the same line, scoped to the doc just versioned, printed after
   `edit_path=` plus one sentence: *"you are writing that doc now — if you split, split it in this
   version file, never in docs/current"*. This is the load-bearing site: `validate` tells you the
   section is too big while you are nowhere near an editable file; `doc-new-version` hands you the
   file where the split can actually land, and a docs phase runs it per note.

**Guidance where doc-writing happens** (one sentence each, no new sections):

- `.claude/skills/doc-new-version/SKILL.md` — split the named section *in this version file*, and
  the boundary in the same breath: per-doc judgment while already editing that doc, **never a sweep**
  across the doc set, and a small doc whose few sections are its whole content is better left alone.
- `docs/README.md` — one bullet under `## Rules`, same content compressed to a line.

**`CHANGELOG.md`** — one `## v38` bullet (version **not** bumped; v38 was already open).
**`tests/retrofit_smoke.sh`** — three assertions, 149 → 152 (§2).
**`bootstrap_agentic_workspace.sh`** — rebuilt (`installer/build.py`, `--check` clean).

## 2. Validation detail

The scratch/clean pair the plan asks for is run inside the smoke's existing throwaway fresh
install (`$F`), so it costs no new harness and is re-run forever:

| assertion | what it proves |
|---|---|
| `validate is silent about doc sections on a clean fresh install` | seed docs are small; no false positives, ever, on a new workspace |
| `validate names an oversized doc section (doc, heading, size) and still exits 0` | greps `warning: oversized_doc_sections=1` **and** `data.md '## Oversized probe section'` **and** `rc == 0` — the advisory-only contract asserted on the exit code, not just the text |
| `doc-new-version repeats the oversized-section note where the split can land` | the second site is wired, and to the same helper |

The probe takes the doctrinal path rather than poking `docs/current`: `doc-new-version --doc data`
→ append a >10 KB `## Oversized probe section` to the returned `edit_path` → `rebuild-docs` →
`validate`. So it also proves the generated snapshot is what gets measured.

Helper edge cases checked directly (throwaway, not committed as tests): a `## ` line inside a
fenced block is not counted as a heading; the threshold is strict `>`; an empty list yields `""`
(no line at all, not an empty warning); a 122-char qa.md heading truncates at 60.

## 3. Deviation

**No `CLAUDE.md` clause.** The plan allowed one "if an existing sentence is now incomplete". I read
the two candidate sentences — the read-order rule (*"the `docs/current/` **sections** the work
touches"*) and the docs-phase hard rule — and neither becomes false or incomplete: the warning
changes nothing an agent must do, and the one place an agent acts on it (`doc-new-version`) already
carries the sentence in its skill. Adding a paragraph to a contract measured at ~16.3 k tokens per
dispatch (S1 §6, OQ2) to describe an advisory warning would have been the exact cost this phase
exists to reduce. Nothing else deviates.

## 4. This repo's own oversized sections — reported, not fixed

`validate` now warns here, which is correct and expected (plan: *"the warning firing here is
correct — note it, don't silence it"*). The full list, for the next docs phase to judge per doc:

| bytes | doc | section |
|---|---|---|
| 216,523 | `decisions.md` | `## Decision Log` |
| 17,569 | `operations.md` | `## Visual-design runbook (Claude Design + DesignSync; single-harness …)` |
| 16,903 | `decisions.md` | `## Superseded Decisions` |
| 14,010 | `decisions.md` | `## Status` |
| 11,667 | `qa.md` | `## Verification doctrine — matches the record, works as a product, …` |

`decisions.md` is 248 KB in **4** H2 sections — the exact shape S1 §2.8 named as worst
("read the section" = "read the doc"). This is a docs-phase job, not a fix to apply from an
implementation slice, and `docs/current/*.md` is generated in any case.

## 5. Notebook

Phase notes are in `works/phases/active/P21/phase.md`: one `## Doc impact` line, one `## Decisions`
line for the shape of the remedy, the S3–S5 notes consumed, the upstream-repo note retagged for
`P21.REVIEW`, and `## Now` rewritten as the handoff to the review. Not restated here.
