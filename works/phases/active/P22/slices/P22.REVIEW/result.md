# Result — P22.REVIEW (phase review)

- **status:** done
- **review_verdict:** **pass**
- **summary:** P22 delivered all three operator decisions as confirmed in `intent.md` — D14 (a last-updated marker recorded at write time in both `docs/index.json` and the version frontmatter, surfaced as a per-doc marker + **STALE** flag in `docs` and one shared `stale_docs=` warning in `validate`, with the "stale evidence, never current truth" doctrine in `CLAUDE.md` and both executor tiers, and no cadence knob), D15 (`PHASE_MD_BUDGET` is one soft 400 KB byte cap, warning-only, line ceiling dropped, size print kept, all six prose restatements updated), and D16 (keep-tests-small is core-only, at its single machinery site). Every validation passes, the scope boundary held (no `doc-new-version` anywhere in the phase, P21's debt untouched), the notebook carries no dropped decision and no unrouted operator question, and the seven-note `## Doc impact` list covers every durable-truth change the phase made.
- **validation:**
  - `python3 scripts/workflow.py validate` — **PASS** (exit 0; three advisory warnings, all expected and none a defect: `consolidation_owed=P21`, `stale_docs=architecture, decisions, operations, qa`, `oversized_doc_sections=5`)
  - `bash tests/retrofit_smoke.sh` — **PASS** (exit 0, **158 PASS / 0 FAIL**, `ALL RETROFIT SMOKE TESTS PASSED`) — matches S2's claimed baseline exactly
  - `python3 installer/build.py --check` — **PASS** (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`)
  - `python3 scripts/workflow.py sync-agents --check` — **PASS** (`agent files in sync`; mode `flex`, 0 overrides)
  - `python3 scripts/workflow.py docs` — **PASS** (live; marker under all eleven docs, STALE on exactly the four P21-outrun ones)
  - `python3 scripts/workflow.py docs-debt` / `next` — **PASS** (live; both still correct after S2's refactor of the rollup onto the shared helper)
  - Source inspection: `PHASE_MD_BUDGET = 400 * 1024` (`scripts/workflow.py:63`), byte-only judgment at `:1152`, lines+bytes printed / bytes judged at `:1439-1440`, `CONSOLIDATION_DEBT_MIN_PHASES = 1` (`:76`)
  - `diff` of the two executor agent bodies — **identical** (frontmatter differs only in `name` / `description` / `tools` / `model`, as designed)
- **deviations:** none.
- **doc_versions:** **none — deferred to a docs phase.** The phase's `## Doc impact` list was verified complete (below). The review's two-section carve-out did not apply: the acceptance gate is **waived**, so there was no `## Regression Checklist` append and no `## Operator Runtime` change.
- **doc_impact:** one append-only verification line added to `phase.md`'s `## Doc impact` (the P21.REVIEW precedent), recording that the review checked the list rather than adding a new durable-truth change of its own.
- **walkthrough:** none — `acceptance.required` is `false` (`phase.json` note: "machinery and doctrine only; no operator-visible running product"). No gate stages, no browser verification, no routed questions.
- **explain:** not written — run `/explain` for this phase.
- **files_changed:**
  - `works/phases/active/P22/slices/P22.REVIEW/result.md` (this file)
  - `works/phases/active/P22/phase.md` (`## Decisions` + `## Doc impact` verification line, `## Notes for later slices` cleared, `## Now` rewritten as the phase's closing state)

---

## 1. Objective coverage

Judged against `phase.json`'s objective and `intent.md`'s three confirmed decisions. All three landed, and each was checked in the running machinery rather than only in the slices' reports.

### D14 — doc staleness explicit, no cadence (`P22.S2`)

| Intent clause | Where it landed | How I checked it |
|---|---|---|
| Marker = source commit + date + consolidating phase, in the docs management json | `new_doc_version()` writes `commit` beside `created_at` / `source` in `docs/index.json` **and** in the version frontmatter | live `docs` run; smoke probe asserting all three sinks agree with `git rev-parse HEAD` |
| Surfaced where agents read docs | `cmd_docs()` prints an indented `updated= source= commit=` line under every doc; `rebuild_docs()` copies the frontmatter verbatim so post-v39 versions carry it into `docs/current` | live `docs` run over all eleven docs; smoke probe asserting the sha reaches `docs/current/security.md` |
| STALE = outrun by an owed `## Doc impact` note | per-doc `-- STALE: n unconsolidated note(s) from P21 ...` plus the shared `stale_docs=` line in both `docs` and `validate` | live: exactly `architecture, decisions, operations, qa` flagged, matching `docs-debt`'s doc set |
| Doctrine: stale = evidence to check against the notes, never truth | `CLAUDE.md` read-order item 3 + the durable-docs Hard Rules bullet; input item 5 of **both** executor agent files | grepped all four sites; agent bodies still byte-identical |
| **No cadence, no threshold tuning** | `CONSOLIDATION_DEBT_MIN_PHASES` still `1`, with its comment rewritten to record that v39 *declined* the cadence question | read at `scripts/workflow.py:69-76` |
| Never fatal | `head_commit()` is timeout-bounded, swallows every exception, and validates the sha shape; missing key → `unknown (pre-v39)`, null → `unknown (no git at write time)` | smoke probe runs `doc-new-version` with `PATH=/var/empty` and the version still writes |

The live `docs` output is the strongest evidence that this is real and not a self-report: eleven docs each carrying a marker, four flagged STALE against P21's genuinely unconsolidated notes, `stale_docs=` closing the listing, exit 0.

### D15 — soft ~100k-token notebook cap (`P22.S1`)

`PHASE_MD_BUDGET = 400 * 1024` — a bare int, so the line ceiling is genuinely gone rather than set to a large number. `validate` compares bytes alone (`:1152`) and still exits 0 over budget and still skips `done` phases; `finish-slice` still prints `phase.md: <lines> lines / <bytes> bytes (budget 409600 bytes)` and appends ` — OVER BUDGET` on the byte comparison only (`:1439-1440`) — so both numbers stay visible and only one judges, exactly as the intent asked. The smoke suite still proves the *behaviour* (a generated >400 KB fixture trips the warning) rather than downgrading to a string check, which matters now that bytes are the only ceiling.

All six prose restatements carry one shared literal, `a soft ~100k-token cap (400 KB)`: `CLAUDE.md` Canonical State, both `.claude/agents/slice-executor-*.md` step 4, and two sites in `design-cowork/SKILL.md`. `works/templates/phase.md` states no budget and was correctly left alone. I re-grepped the live machinery for the old numbers: the only survivors are `scripts/workflow.py:56` (a comment deliberately citing the superseded pair as the *reason* for the reshape), `CHANGELOG.md`'s v39 migration note and its historical v35 section, and the two `docs/current` sites that S1's own `## Doc impact` notes already name as superseded. No stale restatement anywhere it would mislead an agent.

This phase's own notebook is the closing evidence for D15: **88 lines / 15,710 bytes — 3.8 % of the new cap**, against 89 % of the old one while P21's slices were compressing unrelated notes to land.

### D16 — tests for core behavior only (`P22.S1`)

`CLAUDE.md:55` now reads *"Write test files **only for very core behavior** — the logic the product cannot afford to break — and **never** for style, cosmetic, or trivial surface, which is verified **live** instead"*, keeping the terseness and grow-on-demand tail. Grepped: this is still the rule's single machinery site — neither executor agent file restates it, matching the DECOMP finding, so the edit did not fan out. `docs/current/qa.md:14` still carries the old "tests are welcome" posture and is covered by S1's qa `## Doc impact` note.

Worth naming: S1 applied D16 to D16's own slice — three existing probes reshaped, **zero probes added** — and S2's six new probes are all core behaviour (marker reaches all three sinks; the flag fires; the flag clears when the debt is paid; the git-less path never raises). That is the rule being followed the same day it shipped, not just written down.

### Scope boundary

Held. No `doc-new-version` was run anywhere in the phase (`grep '"source": "P22' docs/index.json` is empty and `git status docs/` is clean), and P21's debt is untouched — `docs-debt` still reports exactly `P21 (1 phase(s), 9 note(s), 4 doc(s))`. The phase is not the docs phase, which is D14 working as intended.

## 2. Notebook cross-check against every `result.md`

- **No dropped decision.** I read all three `result.md` files against `## Decisions` line by line. DECOMP's six (the two-slice cut, S1-before-S2, the D14 shape, no cadence knob, the D15/D16 shapes, drop-not-promote, the v39 CHANGELOG convention, the waive read) are all present; S1's two (the bare-int landing, the generated-never-committed fixture) are present; S2's three (one marker plus one shared line, no sha backfill, `stale_docs=` as its own ungated line) are present, and the "staleness tracks *stamped* debt" finding is recorded as a decision-grade line too. Nothing a slice settled is missing from the notebook.
- **No unrouted operator question.** `## Operator Questions` records `(none from P22.DECOMP …)`, and I verified that against the logs rather than trusting the section: DECOMP explicitly classified the one open implementation choice (backfill or not) as *inside S2's scope, deliberately not escalated*; S1 states outright that it raised none; S2 raised none and decided its three delegated calls itself. The three decisions arrived resolved in `intent.md`, so there was genuinely nothing for an operator to answer. Nothing to route, nothing to `defer-job` from that list.
- **Notes consumed.** All three `for P22.REVIEW` notes were written for this slice, were used (they are what §1's checks are drawn from), and are removed in this edit; the notebook ends with an empty notes section, which is correct for a phase with no later slice.

## 3. `## Doc impact` verification (pass-only duty)

The list carries seven notes — three from S1 (`operations.md`, `qa.md`, `decisions.md`), four from S2 (`architecture.md`, `operations.md`, `decisions.md`, `qa.md`). I checked them against the phase's actual diff (`git diff --stat 2b48590..HEAD`) rather than against the slices' claims:

| Changed surface | Covered by |
|---|---|
| `PHASE_MD_BUDGET` reshape + `validate` / `finish-slice` wording | `operations.md` (S1) — supersedes the v35 runbook bullets at `operations.md:516`; `decisions.md` (S1) — supersedes the v35 decision clause at `decisions.md:321` |
| keep-tests-small → core-only | `qa.md` (S1) — supersedes the "tests are welcome" posture at `qa.md:14` |
| `docs/index.json` gains `commit`; frontmatter gains `commit:`; `rebuild_docs` carries it | `architecture.md` (S2) |
| `docs` marker + STALE flag; `validate`'s shared `stale_docs=` line | `operations.md` (S2) |
| The cadence declined, the knob left at 1, no backfill, the staleness doctrine | `decisions.md` (S2) |
| Smoke baseline 152 → 158 | `qa.md` (S2) |

Nothing durable is uncovered. The four prose-only sites (`CLAUDE.md`, both executor agents, `design-cowork/SKILL.md`) are workspace machinery whose durable-truth consequences are already named by the operations/decisions/qa notes; `CHANGELOG.md` and the `WORKSPACE_VERSION` bump are their own durable record and take no note, matching P21's precedent. The list is **complete**; `doc_versions: none — deferred to a docs phase`.

Consequence the operator should expect and not mistake for a regression: the moment this pass is recorded, P22 stamps `consolidation: pending` and its own four docs join the `stale_docs=` line. That is D14 describing this very phase.

## 4. The three delegated judgment calls — judged on the reasoning

The plan sanctioned the delegation, so what follows judges the calls, not the fact that S2 made them. All three are **sound**.

1. **No sha backfill for pre-v39 entries.** The decisive argument is the one S2 leads with: a backfilled `git log -1 -- <path>` sha means *"the commit that last touched this file"*, which is a different fact wearing the same field name — and a marker whose meaning varies by row is worse than one that admits it does not know. Two supporting reasons hold up independently: `docs` would have had to become a writer (it is the one command that advertises "read-only: this command wrote nothing"), and the `unknown` rendering must exist anyway for a git-less checkout. The accepted cost — the third marker field is inert for ~100 existing versions until each doc's next consolidation — is real but small, because the staleness signal a reader actually acts on is `created_at` + `source` + the STALE flag, none of which depend on the sha. The two-way rendering (`unknown (pre-v39)` vs `unknown (no git at write time)`) is the right amount of honesty: it distinguishes "never recorded" from "could not be recorded".
2. **A separate `validate` line rather than folding doc names into `consolidation_owed=`.** Correct, and for the reason S2 gives: the two lines answer different questions (which *phases* owe and what pays, versus which *docs* must not be trusted), and folding would have lengthened the debt line while still leaving `docs` needing its own wording — reintroducing exactly the divergence the shared-line pattern exists to prevent. The sharper half of the call is **not** gating the line on `CONSOLIDATION_DEBT_MIN_PHASES`, and I agree with it without reservation: the knob tunes how loud a *debt* is and a debt may legitimately wait for a batch, but staleness is a property of the document in the reader's hand, and a cadence setting that could silence it would defeat the trade the operator made in D14. Leaving `next` alone is consistent — it already carries the debt line, and the agent about to read a doc runs `docs`.
3. **The verbatim frontmatter is the generated header.** The leanest correct reading of the plan's step 4: `rebuild_docs()` already copies version files whole, so the marker reaches `docs/current/<doc>.md` with no second format invented, no rewriting of existing snapshots, and one place to change if it ever moves. The known gap — existing `docs/current` files show no `commit:` until their next consolidation — is precisely what the `docs` listing covers in the meantime, so the two surfaces compose instead of overlapping.

## 5. Observation (non-blocking, not a finding against any slice)

`stale_docs=` reports its aggregate note count as the **sum of per-doc counts**, so a note naming two docs is counted twice and the `(unassigned)` note is excluded: the live line reads *"4 doc(s) named by 11 unconsolidated note(s) from P21"* while `docs-debt` reports *"9 note(s)"* for the same debt. Both numbers are defensible (11 doc-note references across 9 notes) and the **doc sets agree everywhere**, which is the invariant S2's shared-helper refactor was for. The per-doc STALE flags are exact (`architecture: 1`, `decisions: 2`, `operations: 4`, `qa: 4`). This is loose phrasing in an advisory line that gates nothing, so it does not touch the verdict — recorded here, and offered to the orchestrator as a one-line deferred nit rather than a fix slice.

## 6. Verdict

**pass.** All three decisions shipped as confirmed in `intent.md`, verified in the running machinery and not only in the slices' reports; validation is green on every command; the scope boundary held; the notebook is faithful to the logs; and the `## Doc impact` list is complete.

Chores that follow this verdict, all the **orchestrator's** (executors run none of them): the acceptance gate is already waived in `phase.json`, so no `accept-gate` step is needed; and D14/D15/D16 close by **dropping**, per the phase decision —

```
python3 scripts/workflow.py drop-deferred D14 --reason "resolved by P22"
python3 scripts/workflow.py drop-deferred D15 --reason "resolved by P22"
python3 scripts/workflow.py drop-deferred D16 --reason "resolved by P22"
```

`explain: not written — run /explain for this phase.`
