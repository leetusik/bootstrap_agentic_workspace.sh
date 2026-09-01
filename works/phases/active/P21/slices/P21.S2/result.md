# Result — P21.S2 (defer doc consolidation out of the review + the gate carve-out; R1+R2)

- **status:** `done`
- **summary:** Generalised parallel mode's deferred doc consolidation to every phase — a passing review now verifies the `## Doc impact` list, stamps a `consolidation` debt that blocks archiving, and creates no versions; a docs phase pays it with `docs-consolidated <P>`. The review keeps a narrow carve-out for `## Regression Checklist` + `## Operator Runtime`. Shipped as workspace v38.
- **files_changed:**
  - `scripts/workflow.py`
  - `CLAUDE.md`
  - `.claude/agents/slice-executor-mid.md`, `.claude/agents/slice-executor-high.md`
  - `.claude/skills/review-phase/SKILL.md`, `.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md`, `.claude/skills/parallel-phase/SKILL.md`, `.claude/skills/archive-phase/SKILL.md`, `.claude/skills/design-cowork/SKILL.md`, `.claude/skills/doc-new-version/SKILL.md`
  - `works/templates/phase.md`
  - `CHANGELOG.md`, `installer/main.py`, `bootstrap_agentic_workspace.sh` (rebuilt)
  - `tests/retrofit_smoke.sh`
  - `works/phases/active/P21/phase.md`, `works/phases/active/P21/slices/P21.S2/result.md`
  - regenerated: `works/index.json`, `works/state.json`, `works/backlog.md`, `docs/index.json`
- **validation:**
  - `python3 scripts/workflow.py validate` — PASS (live repo, mixed legacy/new `phase.json` population)
  - `python3 scripts/workflow.py rebuild` — PASS
  - scratch-copy smoke of the state-mutating flows (24 checks, §4) — **ALL PASS**
  - scratch-copy git-enabled parallel lifecycle probe (`parallel-start` → `parallel-status` → `parallel-gate` → `parallel-merge-finish` → `parallel-teardown`) — PASS, output unchanged in shape (§4)
  - `python3 installer/build.py` then `python3 installer/build.py --check` — PASS
  - `bash tests/retrofit_smoke.sh` — **144 PASS / 0 FAIL** (was 140; +4 new v38 assertions)
  - `python3 scripts/workflow.py sync-agents --check` — PASS (agent bodies byte-identical past frontmatter)
- **deviations:** three, all small and listed in §5 (two files edited beyond the plan's named set, one plan item deliberately not done, one size target only partly met)
- **doc_impact:** 4 lines appended to `phase.md` (architecture, operations, decisions, qa — §6)

---

## 1. What this slice did

The operator-confirmed remedy from `intent.md`, in one coherent change: **durable-doc consolidation
left the phase review.** It landed exactly as `P21.S1` §11c argued it should — by generalising the
deferred path parallel mode has been running since v24, not by inventing machinery — and it carries
R2 (the review's narrow named write) inside it, so the workspace never exists in a state where
deferral has shipped but the `## Regression Checklist` has quietly stopped being appended.

The new shape, end to end:

1. Any slice that changes durable truth appends a one-line `## Doc impact` note to `phase.md`. (Unchanged.)
2. A **passing review verifies** that list covers every durable-truth change and creates no doc
   versions, reporting `doc_versions: none — deferred to a docs phase`.
3. `review-phase --verdict pass` then **stamps the phase's consolidation debt** when that list is
   non-empty, and prints the exact commands that pay it.
4. The debt **holds the phase out of archiving** — which is the point: archiving is precisely what
   would move the notes out of `active/` and make them unfindable (S1 §11b).
5. An operator-created **docs phase** runs `doc-new-version` per note → `rebuild-docs`, and
   `docs-consolidated <P>` records the payment, unblocking archiving.
6. The review's **carve-out**: it may still write two named sections itself —
   `## Regression Checklist` (qa) and `## Operator Runtime` (operations) — each via
   `doc-new-version` on that doc, editing only that section. **In parallel mode not even those**,
   because doc versions come from one shared index.

## 2. Machinery (`scripts/workflow.py`)

| piece | what changed |
|---|---|
| `phase_consolidation(data)` | **new.** The one reader. Prefers the top-level `consolidation`; falls back to `execution.consolidation` (the v24–v37 shape) so nothing needs migrating; absent or malformed = no debt. |
| `set_phase_consolidation(data, state)` | **new.** Writes the top-level field and mirrors it into a parallel `execution` block, so `parallel-status` / `parallel-teardown` / `parallel-consolidated` keep reading the field they know. |
| `phase_doc_impact_notes(pdir)` | **new.** Parses `## Doc impact` bullets out of the notebook. Skips blanks, the italic seed line, and an explicit `- (none …)` placeholder — a placeholder is not a debt. |
| `phases_owing_consolidation(phases)` | **new.** The debt set, in one place. `parallel-merge-finish` now filters this instead of scanning `execution` itself; it is the seam `S3` surfaces from. |
| `review_phase` | on `pass` with non-empty notes: stamps `consolidation: "pending"`, emits `phase_consolidation_owed`, rebuilds, and prints the deferral + the completion command (`docs-consolidated` / `parallel-consolidated`). Empty list ⇒ **no field written at all**. |
| `docs_consolidated` (`docs-consolidated <P>`) | **new command.** The general twin of `parallel-consolidated`: refuses on a parallel stream, refuses when there is no `pending` debt or it is already `done`, otherwise flips it and rebuilds. |
| `parallel_consolidated` | unchanged behaviour; now reads/writes through the helpers, and its "not a parallel phase" refusal points at `docs-consolidated` instead of teaching the retired review-time rule. |
| `_phase_blockers` | generalised from "a parallel phase owing docs" to "**any** phase owing docs", naming the right command per phase. `archive-phase` / `archive-all` / `rotate-backlog` inherit it unchanged. |
| `validate` | new check: a top-level `consolidation` must be `pending`/`done`. Absent = legacy = silent. |
| `rebuild_index_and_state` | active-phase entries carry `consolidation` when a debt exists — queryable state for `S3`, no surfacing built. |
| `new_doc_version` | **no functional relaxation** (see §5). Only the refusal message changed: it no longer frames the default stream as a parallel-mode detail. |
| `parallel_status` / `parallel_teardown` / `parallel_gate` | read the debt through the helper. (A latent bug was avoided in `parallel_status`: the print sits in a loop over `phase`, not the comprehension variable.) |

Not built, deliberately: `next` / `validate` surfacing of the debt (**S3**) and the docs-phase entry
point (**S4**). Both have clean seams — `phases_owing_consolidation()` and the index field for S3,
`docs-consolidated` plus the doctrine sentences naming "a docs phase the operator creates" for S4.

## 3. Doctrine

`CLAUDE.md` (7 passages), both agent files (6 passages each, bodies kept byte-identical), and seven
skills. Beyond the four skills the plan named I also corrected `archive-phase` (its "a parallel-mode
phase has one more gate" was now simply false), `design-cowork` (line 494: "the review consolidates
the docs"), and `doc-new-version` (added *where* the command belongs). Leaving those three saying
the retired rule would have been a defect, not restraint.

The retired sentence pattern is gone: a grep for `at the review slice` / `at the phase review` /
`consolidates the docs` / `once per phase, at the review` across `CLAUDE.md`, `.claude/`,
`works/templates/` and the engine returns nothing.

`works/templates/phase.md`'s `## Doc impact` seed line was rewritten, and the byte-identical
fallback copy inside `workflow.py` with it (the smoke suite asserts that equality — it passes). This
phase's own notebook seed line was updated to match.

**Release:** `WORKSPACE_VERSION = 37 → 38` and a `## v38` CHANGELOG section (with the mandatory
Migration notes line — the smoke suite asserts every section has one). The section is written to be
appended to by `S3`–`S5`; **the number must not be bumped again in this phase.** The three-way
version equality (installer / top changelog heading / fresh-install marker) is asserted and passes.

**Self-hosting:** stated as a `## Decisions` line in `phase.md`. `P21.REVIEW` follows the new rule —
it verifies the list, writes no versions (not even the carve-out sections: P21's gate is waived, so
no gate stage runs), and the engine will stamp `P21 consolidation: pending`. P21 then stays in
`active/` until the operator runs a docs phase and records `docs-consolidated P21`. That is the
intended behaviour of the thing this phase shipped, not a snag.

## 4. Validation detail

**Live repo.** `validate` and `rebuild` are clean. This repo's own population is the backward-compat
test the plan asked for: `P20` is `done` with a passing review and no `consolidation` field, and it
stays archivable exactly as before.

**Scratch copy** (`shutil.copytree` of the repo minus `.git` into the session scratchpad; the script
is throwaway and is not added to the repo, per keep-tests-small). 24 checks, all PASS:

- **A (the new path, 10 checks):** phase with a doc-impact note → review pass reports the deferral
  and names `docs-consolidated P90` → `phase.json` stamped `pending` → `validate` clean → the debt
  is in `works/index.json` → `archive-phase` refuses with "docs not consolidated" → `rotate-backlog`
  leaves it active → `docs-consolidated` pays it → refuses a second time → archivable.
- **B (nothing owed, 3):** a `- (none …)` placeholder is not a note; no field written; archivable at once.
- **C (legacy shapes, 9):** a `done`+`pass` phase with **no** `consolidation` field validates and
  archives as before; a `phase.json` carrying the v24–v37 `execution.consolidation: pending`
  validates, still blocks archiving (naming `parallel-consolidated`), is still listed by
  `parallel-merge-finish`, is still paid by `parallel-consolidated`, and ends with **both** the
  general field and the mirrored `execution` field reading `done`.
- **D/E (2):** `docs-consolidated` refuses a phase with no debt; final `validate` clean.

**Git-enabled scratch copy** for the paths the state-only smoke cannot reach: `parallel-start`
(stamp + commit + worktree) → `parallel-status` (prints `consolidation=pending` through the new
helper) → `parallel-gate` (GATE CLOSED with both reasons intact) → `parallel-merge-finish` →
`parallel-teardown` (prints the consolidation history line and still warns that the debt is pending).

**Suite.** `tests/retrofit_smoke.sh` 140 → **144 PASS / 0 FAIL**. The four added assertions probe the
v38 invariant against a real engine in the throwaway fresh install, in the style of the existing v32
gate probe: a passing review defers and names `docs-consolidated`; the debt is stamped; archiving is
blocked; `docs-consolidated` unblocks it.

## 5. Deviations from `plan.md`

1. **Three extra files edited** (`archive-phase`, `design-cowork`, `doc-new-version` skills). The
   plan's blast radius came from S1 §11's table, which lists four skills; these three carried
   sentences that the change makes false. Corrections are one line each.
2. **`new_doc_version`'s stream refusal was not relaxed.** The plan said "relax … only as far as §11
   says is needed", and §11 says nothing is needed: doc versions are still allocated from one shared
   index, so consolidation still belongs on the default stream — a docs phase run on a parallel
   branch would collide exactly as a branch review would. Only the message's framing changed. If a
   future slice wants docs phases to run in parallel, that is a real design question, not a relaxation.
3. **Net contract size.** OQ2 asked for a contract no larger than today's; `CLAUDE.md` grew **+809 B**
   (39,796 → 40,605). The new rule must state the debt, the carve-out and a new command, and I cut
   the rationale sentence and compressed the parallel clause to hold it there. Cutting the remaining
   ~800 B would mean deciding OQ2, which is the operator's call — left as a recorded number.
4. **One test file touched** rather than none: 4 assertions in the existing suite (no new file), which
   the keep-tests-small rule invites for exactly this kind of invariant.

## 6. Doc impact appended to `phase.md`

- `architecture.md`: `phase.json` carries a top-level `consolidation` debt (pending/done; absent = none); the parallel deferred path is now every phase's path; new `docs-consolidated <P>`
- `operations.md`: durable docs are consolidated in an operator-created docs phase (`doc-new-version` per note → `rebuild-docs` → `docs-consolidated <P>`), never at the review; an owing phase stays in `active/`
- `decisions.md`: why consolidation left the review (90–97 % of its read budget) and why the review keeps a two-section carve-out
- `qa.md`: retrofit smoke baseline 140 → 144 PASS (v38 deferral probes)

## 7. Notebook

`phase.md` is at **16,023 B / 88 lines** (budget 16,384 / 200) — it was 14,819 B before this slice
and had to absorb 4 doc-impact lines, 3 new notes and a decision, so eleven settled `## Decisions`
and notes were compressed in place (no decision or question dropped; the pre-edit text is in git and
every number is in `P21.S1/result.md`). ~360 B of headroom is left for the `finish-slice --outcome`
row, so **keep the outcome line short**. Consumed: the DECOMP2 self-hosting note (now a decision) and
the DECOMP upstream-rule note (folded into the new note that also carries the v38 coordination).
Added: notes for `S3`, `S4` and `S3`–`S5`/`REVIEW`.

## 8. Dead ends / notes for whoever reads this next

- **A per-note debt was considered and rejected.** The flag is one mechanical bit per phase: "the
  list is non-empty at the passing review". A consequence worth knowing: if a phase's only durable
  change was a section the review itself wrote (the carve-out), the engine still stamps the debt —
  the doctrine tells the reviewer to say so and the orchestrator records `docs-consolidated <P>`
  immediately. Making the engine judge which notes a review had already consolidated would have
  meant tracking notes individually, for a case one command settles.
- **Mirroring the debt into `execution` beats migrating it.** Writing only the top-level field would
  have left `parallel-status` and `parallel-teardown` printing a stale `pending`; migrating old files
  would have touched adopter state on update. Mirror on write, fall back on read, migrate nothing.
- **The archiving guard is the answer to S1 §11b** ("where do the notes live between phases?"): they
  live where they were written, and the guard is what keeps the phase — and therefore the notes — in
  `active/` until they are consolidated.
