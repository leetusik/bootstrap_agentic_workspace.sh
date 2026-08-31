# Result — P18.S4: contract — `CLAUDE.md` Read Order, notebook rules, READMEs

## Verdict

- **status:** done
- **summary:** The contract now states the protocol S1–S3 shipped, in their words: a just-in-time three-step Read Order (pointer → phase/slice folder → only the `docs/current/` sections the work touches, never the whole set and never `docs/index.json`), `phase.md` as bounded state rewritten under `PHASE_MD_BUDGET` with its generated `## Slices` block off-limits, `result.md` as the per-slice log with the verdict block first, and `finish-slice --outcome` in the command list. Both READMEs mirror it. Prose only; installer rebuilt; 137 PASS.
- **files_changed:** `CLAUDE.md`, `README.en.md`, `README.md`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P18/phase.md`, `works/phases/active/P18/slices/P18.S4/result.md`
- **validation:** `validate` clean · `installer/build.py` → `--check` in sync · `bash tests/retrofit_smoke.sh` **137 PASS / 0 FAIL** · stale-wording grep clean · **`wc -c CLAUDE.md` = 34419, over the plan's 33383 cap by 1036 bytes (deviation 1)**
- **deviations:** two — the byte cap could not be met without deleting rules the plan froze (see below), and the v35 contract invariants were pinned in Test 0 (a fifth file the plan did not list)
- **doc_impact:** two lines appended to `phase.md` → `operations.md` (the contract's Read Order and notebook rule as now stated) and `decisions.md` (the ADR the review should write)

Cross-slice state — the consumed S4 notes, the new decisions, the doc-impact lines, the S5/REVIEW notes and the rewritten `## Now` — is in `works/phases/active/P18/phase.md`, not repeated here.

## What shipped

### `CLAUDE.md` — the five touch points, nothing else

1. **`## Read Order`** — four steps → three, prefixed by *"Just in time, and only what the work in front of you needs:"*. (1) `works/state.json` + `python3 scripts/workflow.py next` (the stream-scoped pointer, `parallel-status` clause kept), (2) the active phase folder — `intent.md` and the bounded `phase.md` — and the active slice folder only, (3) the `docs/current/` **sections** the work touches (`workflow.py docs` lists the set), never the whole doc set up front and never `docs/index.json` (version history). The closing "Do not read every historical slice…" sentence is untouched. `works/backlog.md` / `works/deferred.md` leave the list — `next` prints the pointer — while both remain in *Canonical State* and in the keep-them-lean rule.
2. **`## Canonical State`** — the *Phase notebook* line is now the shape: bounded state, seeded from `works/templates/phase.md`, rewritten under `PHASE_MD_BUDGET` (200 lines / 16 KB; `finish-slice` prints the size, `validate` warns and never errors), with the `## Slices` table generated between the two markers by `rebuild` and never hand-edited. The *Slice context* line became a pointer to the slice-files rule (it had duplicated it) and gained `slice.json`'s one-line `outcome`.
3. **`## Hard Rules`, the two notebook bullets** — bullet 1 keeps every rule it had and adds `result.md`'s **verdict block first** ("so it can be read with `head`") plus findings prose / dead ends / command output to the "what this slice did" list; the audience-split sentence is kept verbatim, since it is still the reason. Bullet 2 is rewritten from "appends notes" to **edits under budget**, section by section: superseded `## Decisions` replaced rather than stacked, `## Doc impact` and `## Operator Questions` append-only, consumed `## Notes for later slices` dropped and new ones tagged `**(from <slice>, for <slice>)**`, `## Now` (≤ 15 lines) rewritten last, the generated `## Slices` block never touched — closing with the restorability argument (git + `result.md` by path) and the review's notebook ↔ `result.md` cross-check.
4. **`## Workflow Commands`** — `finish-slice P1.S1 --outcome "one line"` (stored in `slice.json`, fills the `## Slices` table; omitted = a warning), and `validate` annotated with the over-budget warning. No new command line was added, per the plan.
5. **Verb-only elsewhere** — *Driving This Workspace* ("writes `result.md` verdict-block-first, edits the phase notebook and appends its doc impact") and the executor/orchestrator hard rule ("`result.md`, and the phase notebook"). Every gate, design, parallel and executor **rule** is byte-identical to before.

### READMEs

- **`README.en.md`** — the *Read order* list rewritten to the same three steps ("it reads just in time, in this order"); `finish-slice P1.S1 --outcome …` in the command table; principle 2 now says the notebook is *rewritten under a size budget* on the way out, "so it stays the **state** of the phase rather than its log; the log is each slice's own `result.md`" (paragraph re-wrapped); the tree listing calls `phase.md` the *bounded* notebook. Nothing else moved.
- **`README.md`** (Korean) — the matching three edits, in Korean, and no translation of anything else: the "배운 것이 남습니다" bullet now says the notebook is rewritten to a fixed size as the phase's **현재 상태** with the detail in each slice's `result.md`; the `slice` definition says `result.md` starts with the verdict summary; the executor bullet says it reads only what it needs, then writes `result.md` and updates `phase.md` within the size limit. The Korean README has no read-order list and no command table, so those two touch points have no counterpart there.

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | `Workflow validation passed.` — clean, no warnings |
| `python3 installer/build.py` → `--check` | `wrote bootstrap_agentic_workspace.sh (424709 bytes)` → `OK: in sync` (the printed figure is characters; the artifact is 426880 bytes) |
| `bash tests/retrofit_smoke.sh` | `ALL RETROFIT SMOKE TESTS PASSED` — **137 PASS, 0 FAIL** (count unchanged: the new invariants are asserts inside Test 0's existing python block) |
| `grep -n "docs/current/\*.md for the fullstack\|Findings & Notes\|Open Questions\|appends.*phase.md" CLAUDE.md README.md README.en.md` | no match in any of the three — no stale wording, no intentional residue |
| `wc -c CLAUDE.md` | **34419** — over the plan's `≤ 33383` cap (deviation 1) |
| `wc -c README.en.md` / `README.md` | 28552 (was 28349) / 16399 (was 16077) |

The only `works/backlog.md` mentions left in `CLAUDE.md` are the two intentional ones (the generated-dashboards entry under *Canonical State*, and the keep-them-lean rule).

## Deviations from plan.md

### 1. `CLAUDE.md` grew by 1036 bytes (33383 → 34419, +3.1 %); the cap was not met

The plan's premise was that "the rewritten Read Order is shorter than the old one; spend that on the notebook rule." It is not: the old four lines were four bare pointers, while the new three carry the discipline itself (just-in-time, sections not documents, and the two never-reads), so the section costs **+173** bytes even in its tightest honest form. Measured per touch point, after three compression passes:

| Touch point | Δ bytes |
|---|---|
| `## Read Order` (3 steps + the just-in-time lead) | +173 |
| *Canonical State* — Phase notebook (shape, budget, markers) | +142 |
| *Canonical State* — Slice context (now a pointer; duplication removed) | **−90** |
| Hard rule — slice files (verdict-first + the log's contents) | +112 |
| Hard rule — the notebook edit protocol | +493 |
| `finish-slice --outcome` | +96 |
| `validate` over-budget warning | +48 |
| Two verb-only fixes | +48 |
| **net** | **+1036** |

What was already spent to hold it down: the *Slice context* line was reduced to a pointer (−90), the notebook's section list is stated once rather than in both *Read Order* and *Canonical State*, and the notebook rule states the budget numbers only in *Canonical State*. Closing the remaining ~1 KB would mean deleting prose the plan explicitly froze ("Nothing else moves. Every gate, design, parallel, and executor sentence stays as it is") — the largest true duplication left is the executor/orchestrator division stated twice, once in *Driving This Workspace* and once in *Hard Rules*, worth roughly 700 bytes. That deduplication is **exactly deferred job D8** (`CLAUDE.md` 33 KB → ≤ 12 KB, triggered after P18 lands), so it was left alone rather than half-done here.

Net effect on a dispatch: +1036 bytes of prefix (~260 tokens) against this phase dropping the whole-doc-set read (330 KB) and `docs/index.json` (54 KB) and capping the notebook at 16 KB — strongly negative on balance. Flagged for the review to accept or to send back as a fix slice; no rule was dropped to reach the number.

### 2. Test 0 gained the v35 contract invariants (`tests/retrofit_smoke.sh`, a fifth file)

The plan listed prose only. Following the phase decision that new prose invariants are pinned inside Test 0's existing python block (so the count stays 137), seven positive asserts were added to the existing `claude` tuple — "Just in time, and only what the work in front of you needs", "never the whole doc set up front, and never `docs/index.json`", "**bounded state**", "PHASE_MD_BUDGET", "200 lines / 16 KB", "every slice **edits** it under budget", "structured verdict block first", "finish-slice P1.S1 --outcome" — plus three negatives for the wording this slice supersedes (`for the fullstack doc set`, `appends phase notes/doc impact`, `appends durable cross-slice notes`). No assert pinned old `CLAUDE.md` wording, so nothing had to be replaced. Count still **137 PASS**.

## Notes

- `works/templates/phase.md` is named in the contract for the first time (in the *Phase notebook* line) — correct, since S1 made it an embedded machinery file.
- The Korean README deliberately stays an overview: it has no read-order list and no command table, so the `--outcome` flag and the docs-sections rule appear only in `README.en.md` and `CLAUDE.md`.
