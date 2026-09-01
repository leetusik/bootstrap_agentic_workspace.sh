# Result — P21.REVIEW (phase review)

- **status:** `done`
- **review_verdict:** `pass`
- **summary:** Re-validated all seven slices together (smoke **152 PASS / 0 FAIL**, `installer/build.py --check`, `sync-agents --check`, `validate` exit 0) and exercised the v38 deferral end to end **myself** in a scratch copy rather than trusting the slice reports — a passing review with notes stamps the debt, `next`/`validate`/`docs-debt` name it, archiving is refused, `doc-new-version` → `rebuild-docs` → `docs-consolidated` clears it and archiving unblocks, a placeholder list stamps nothing, and the legacy `execution.consolidation` shape behaves identically. One finding (S1 §5's heads-first answer never reached `## Decisions`), repaired inside the review; the phase meets its objective and every part of `intent.md`.
- **files_changed:**
  - `works/phases/active/P21/phase.md` (Objective compressed for budget, one restored decision, seven decisions tightened in place, two `## Doc impact` lines appended, the two REVIEW-tagged notes consumed and one left for the docs phase, `## Now` rewritten)
  - `works/phases/active/P21/slices/P21.REVIEW/result.md` (this file)
  - no source, no docs, no state transition, no commit
- **validation:**
  | command | outcome |
  |---|---|
  | `bash tests/retrofit_smoke.sh` | **PASS** — 152 PASS / 0 FAIL (the S5 baseline; counted with `grep -c`) |
  | `python3 installer/build.py --check` | **PASS** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
  | `python3 scripts/workflow.py validate` | **PASS** — exit 0, one advisory warning (`oversized_doc_sections=5`); no notebook-budget warning |
  | `python3 scripts/workflow.py docs-debt` | **PASS** — `docs_debt=none` (nothing owes until this pass is recorded) |
  | `python3 scripts/workflow.py next` | **PASS** — `current_slice=P21.REVIEW`, `next_slice=none`, no `consolidation_owed=` line |
  | `python3 scripts/workflow.py sync-agents --check` | **PASS** — agent files in sync (mid `sonnet@xhigh`, high `opus@xhigh`, mode flex) |
  | scratch-copy v38 lifecycle, 4 probes (§2) | **PASS** — every hinge behaved as documented |
  | `git -C <adopter> status --porcelain` ×4 | **PASS** — scope boundary held (§4) |
- **deviations:** none from `plan.md`. (Notebook side effect worth naming: to land the review's edits under the 16 KB budget I compressed the notebook's `## Objective` prose to a summary plus a pointer — the verbatim objective is in `phase.json` and `intent.md`, and the pre-edit notebook is in git.)
- **doc_impact:** two lines appended to `phase.md` — the review's verification statement (no version created anywhere in P21), and a `decisions.md` line saying the v38 decision entry must also carry S3–S5's decisions, which the six slice lines named only in passing.
- **doc_versions:** `none — deferred to a docs phase`. P21 owing consolidation after this pass is the rule this phase shipped working, not a defect.
- **explain:** `not written — run /explain for this phase`
- **walkthrough:** `none` — `acceptance.required: false` (waived: "machinery and doctrine only; no operator-visible running product"), so no gate stage ran: no product walk, no regression-checklist append, no carve-out write.

---

## 1. Validating the slices together

Every middle slice's validation reduces to the same three commands, so the phase's cumulative
validation is cheap and was re-run in full, not sampled. All green, at the tree as committed
(`522a68a`), with only the review slice's own start showing in `git status`.

The two numbers the phase pinned itself to both hold: **`WORKSPACE_VERSION = 38`** in
`installer/main.py`, bumped exactly once (by S2) with a single open `## v38` CHANGELOG section that
S3, S4 and S5 appended bullets to, and the smoke suite at **152 PASS** (140 → 144 → 146 → 149 → 152
across S2–S5, each increment asserted against a throwaway fresh install rather than a fixture).
`## v38` carries the mandatory **Migration notes** line the suite asserts, and it describes all four
remedies, not just the headline one.

`validate` exits 0 with exactly one warning here (`oversized_doc_sections=5`, S5's own output about
this repo's docs). The notebook's handoff predicted two; the second (`consolidation_owed=`) is
silent because nothing owes **yet** — it appears the moment this pass is recorded, which is the
behaviour S3 built. Both are correct output.

## 2. Spot-checking the headline claims myself

The plan forbids passing on the slices' reports alone, so the v38 lifecycle was exercised in a
throwaway copy of this repo (`shutil.copytree` minus `.git`, session scratchpad, never committed,
deleted-by-abandonment). Four probes, every step observed:

**(a) The new path.** A phase with two `## Doc impact` notes → `review-phase --verdict pass` printed
the deferral, named `docs-consolidated P90`, and created **no** doc version; `phase.json` gained
`consolidation: "pending"`; `next` printed `consolidation_owed=P90 (1 phase owes …)` and `validate`
printed the identical text as a **warning with exit 0**; `docs-debt` printed the worklist (both notes
verbatim, the per-doc rollup `architecture, operations, qa`, the paying command) and left the
`works/` + `docs/` tree **byte-identical** (sha256 before/after) — read-only as claimed;
`archive-phase P90` refused with *"docs not consolidated"*.

**(b) Paying it.** Three `doc-new-version` runs → edits in the returned `edit_path` → `rebuild-docs`
→ `docs-consolidated P90` → `docs-debt` went quiet → `archive-phase P90` succeeded. A second
`docs-consolidated P90` refused (`already marked consolidated`). Two of the three `doc-new-version`
runs also printed **S5's oversized-section note beside `edit_path`** with the "split it in this
version file" sentence — the second site, confirmed at the moment it is useful.

**(c) Nothing owed.** A phase whose `## Doc impact` list holds only a `- (none …)` placeholder passed
review with **no `consolidation` field written at all** and archived immediately. A placeholder is
not a debt, as S2 claimed.

**(d) The legacy shape.** A phase carrying only the v24–v37 `execution.consolidation: "pending"`
inside a `mode: parallel` block was named identically by `next`, `validate` and `docs-debt`, with the
trailing clause routing it to **`parallel-consolidated`**; archiving was refused naming that command;
after payment both the top-level and the mirrored `execution` field read `done` and the phase
archived. No migration needed, exactly as designed.

One benign observation, not a finding: `docs-consolidated <P>` will also pay a *merged parallel*
phase when run on the default stream (its refusal is stream-scoped, not phase-scoped, which is what
S2 documented), while `docs-debt` and the archiving guard both name `parallel-consolidated` for such
a phase. The two commands converge on the same state through the same mirror, so the redundancy is
harmless; it is worth knowing only if someone later tries to make the distinction load-bearing.

## 3. Notebook cross-checked against every `result.md`

Read: `DECOMP`, `S1` (44 KB, in full — the measurement is the phase's substance), `DECOMP2`, `S2`,
`S3`, `S4`, `S5`.

**Finding 1 (the one finding; repaired in this review, non-blocking).** S1 answered all five of
`intent.md`'s open questions, but the answer to *"what may the review read instead of every
`result.md`?"* (S1 §5, restated as Q6 in §10) never reached `phase.md`'s `## Decisions` — and
`P21.DECOMP2/result.md` §5 asserts it was settled there ("a heads-only review read … All are settled
in `## Decisions`"). That is precisely the dropped-decision class the review exists to catch. Impact
is low: the answer is *"heads first, bodies where the head or the notebook points"*, which is already
what the executor contract says, so nothing had to ship and no slice was misled. The corrective is a
notebook edit, which is the review's own duty, so it was made here rather than turned into a fix
slice: the decision is restored in `## Decisions`, tagged `(P21.S1 §5, restored P21.REVIEW)`.

Everything else reconciles. Each of S1's other findings has a `## Decisions` line (dominant leak;
defers *when* not *what*; generalisation of parallel mode; the two batching savings; both couplings;
no third file; compaction not lossy; validation is wall-clock; the budget's shape; keep-tests-small
at changple5 only; the contract-growth leak). Each remedy slice's decision is there too (self-hosting
consequence, the docs-phase entry point and its one-slice-per-doc default, R5-as-visibility, the
four-slice cut with R1+R2 merged). No `## Operator Questions` entry was deleted; the list still holds
OQ1–OQ4 and is routed in §5. Both notes tagged for `P21.REVIEW` were consumed here (the upstream
installer rule — honoured by S2–S5 and re-verified above; and the `intent.md` "65 active" correction
— acknowledged: the real split is 9 active + 56 archived = 65 total, no conclusion depends on it, and
it is *not* a dropped finding).

Every recorded deviation was checked in the tree, not just read: S2's three extra skills, its
deliberate non-relaxation of `new_doc_version`'s stream refusal (verified in the source: the refusal
is still there and still stream-scoped) and its +809 B of `CLAUDE.md`; S3's `parallel-merge-finish`
message and +101 B; S4's two extra files — `installer/main.py`'s seeded `docs/README.md` and this
repo's live copy now read *"Doc updates happen in a docs phase the operator creates — never per
slice"* with a `docs-consolidated` bullet, so the correction reaches adopters on update; S5's choice
to add **no** `CLAUDE.md` clause, which is right — the read-order rule does not become false, and the
one place an agent acts on the warning already carries the sentence.

## 4. Judged against the objective and `intent.md`

- **The confirmed leak is closed the way the operator proposed**, and closed as a *generalisation*:
  the deferred path parallel mode has run since v24 now serves every phase, with the debt as real
  state, a guard that keeps an owing phase (and therefore its notes) in `active/`, and the carve-out
  that stops the gate's `## Regression Checklist` from silently lagging. R1+R2 merged into one slice
  so the incoherent intermediate never existed in a repo that reads its own doctrine.
- **All five open questions are answered by measurement, not opinion**, and the three that turn into
  operator calls became OQ1/OQ3/OQ4 rather than silent decisions. Finding 1 is the one that slipped
  from the notebook.
- **The retracted suspects were not re-litigated** — no slice touched archiving semantics (the new
  guard is additive) or the budget constant.
- **Scope boundary held.** `git status --porcelain` on all four adopters: changple5, Mijual and
  arb_upbit_1 clean; changple_web shows the same two generated files S1 recorded as pre-existing —
  the diff is a `last_rebuilt_at`/`updated_at` bump to `03:26:25` with matching mtimes, hours before
  P21's first slice ran. Nothing from this phase reached an adopter repo.
- **Doctrine hangs together with consolidation out of the review.** A sweep for the retired sentence
  patterns (`at the review slice`, `once per phase, at the review`, `consolidates the docs`,
  `the review consolidates`) across `CLAUDE.md`, `.claude/`, `works/templates/`, `scripts/workflow.py`,
  `docs/README.md` and `installer/main.py` returns **nothing**; `CLAUDE.md`'s hard rule, both agent
  files' step 5 and `review-phase/SKILL.md` lines 10/12/30/51/65/79 now describe one consistent
  rule with the carve-out and the parallel exception each stated once. `docs-debt` and the
  `create-phase` docs-phase route are present and route through the unchanged step-3 gate.
- **No doc version was created anywhere in P21**: `git diff 59fe587..HEAD -- docs/versions/` is empty
  and the only `docs/index.json` change across the phase's commits is a `last_rebuilt_at` timestamp.
  The phase practised its own rule from the slice that shipped it.

**`## Doc impact` completeness (this review's doc duty).** The six slice lines cover every
durable-truth change at doc granularity: `architecture` (the `consolidation` state shape and
`docs-consolidated`), `operations` ×4 (consolidation left the review; the debt line; `docs-debt` +
the docs-phase route; the oversized-section warning), `qa` (smoke 140 → 152), `decisions` (why
consolidation left the review and why the carve-out survives). Checked against what actually
changed: `architecture.md` carries no command inventory, so `docs-debt` belongs to `operations`,
where it is; `docs/README.md`, `CHANGELOG.md`, the agent files and the skills are machinery, not
versioned docs. The list is **complete**, with one thinness worth naming rather than failing the
phase for: only S2's line names `decisions.md`, so a docs phase working from the list alone could
write a v38 decision entry covering the deferral and omitting S3–S5's three decisions. Appended as a
review line rather than left implicit.

## 5. Routing `## Operator Questions` (waived gate — no walkthrough to fold them into)

| OQ | routing | detail for the orchestrator |
|---|---|---|
| **OQ1** — docs-phase cadence | **`defer-job`** | title: *State a docs-phase cadence and tune `CONSOLIDATION_DEBT_MIN_PHASES` to it*; reason: *v38 makes `docs/current` staleness operator-paced; batching every ~5 phases is worth 3.3x fewer doc versions (changple5: 368 → 111) and every ~10 is 5.9x, but ten phases of unconsolidated `## Doc impact` notes ride in 16 KB notebooks. S3 shipped the knob (default 1 = always warn) so an answer is a one-token edit, not a re-cut*; trigger: *after the first two or three real docs phases have run, or the first time the `consolidation_owed=` line is felt as noise* |
| **OQ2** — contract size (~16.3 k tok/dispatch, 5x in two months) | **already filed — do not duplicate** | Open job **`D8` — Slim `CLAUDE.md` to ≤ 12 KB** (source P18) is the same job. Its reason is stale (it cites 33 KB / 115 lines; `CLAUDE.md` is now **41,205 B** in 120 lines, and with the executor agent file the dispatch prefix is ~16.3 k tokens, up 5x in two months (21,711 B -> 65,233 B at v37)). Recommend the orchestrator refresh D8's reason with P21's measurement and cite `P21.S1/result.md` §6 as evidence. P21 itself added **+1,409 B** to `CLAUDE.md` (39,796 -> 41,205: S2 +809, S3 +101, S4 the remainder in two extended sentences with the line count held at 120, S5 none) — recorded, and consistent with "act or accept" still being the operator's call |
| **OQ3** — notebook budget: bytes-only, and raise it? | **`defer-job`** | title: *Decide the phase-notebook budget's shape: bytes-only, raised, or with the generated block excluded*; reason: *lines never bind (69 % occupancy vs 92 % of bytes) and 37 % of the ceiling is content a slice may not compress — the generated `## Slices` block (18.9 %) plus the append-only `## Doc impact` (18.1 %), a share deferral now grows. Live evidence from this phase: `P21.DECOMP2`, `S2`, `S3` and this review all had to compress settled prose to land, and this review compressed the notebook's `## Objective` to a pointer to fit*; trigger: *the next time a slice has to compress unrelated content to fit, or when `PHASE_MD_BUDGET` is next touched* |
| **OQ4** — changple5 test sprawl | **`defer-job`** | title: *Decide whether keep-tests-small grows teeth for changple5, and in what shape*; reason: *measured teeth are needed in exactly one adopter (test:source **0.42** vs 0.11–0.13 in the other three; 40 post-rule files > 20 KB, but 218 files / 2.86 MB predate the workspace, so half is inherited culture and it is only weakly a context leak). This repo may not edit adopters, so the options are a documented procedure changple5 runs itself, an advisory `validate` warning on the `test:source` ratio, or accepting 0.42 as that repo's baseline*; trigger: *when the operator next works in changple5, or the next time the keep-tests-small rule is edited* |

No entry is left unrouted.

## 6. Notes for the orchestrator

- Recording `review-phase P21 --verdict pass` will stamp `P21 consolidation: pending` and print the
  paying command; from then on `next` and `validate` will carry the `consolidation_owed=P21` line
  until a docs phase runs and `docs-consolidated P21` is recorded. **Expected**, not a regression —
  and P21 will not archive before then, which is the guard doing its job.
- `phase.json` still reads `status: "planned"` although seven slices are done. The engine never
  promotes a phase on `start-slice` (P12–P19 all went `planned` → `done`; only P20 carries a
  `started_at`), and `review-phase --verdict pass` sets `done` regardless, so nothing is blocked.
  Mentioned only so the inconsistency is a choice rather than an oversight.
- The notebook is at **16,052 B / 89 lines** — ~330 B under the ceiling *before* the generated
  `## Slices` row for this slice is filled in, so **keep `finish-slice --outcome` short**.
- Three `defer-job` specs and the D8 refresh are in §5. The review filed none of them, as required.
