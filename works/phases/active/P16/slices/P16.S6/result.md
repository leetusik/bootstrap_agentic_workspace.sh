# Result — P16.S6 (Release: ship S1–S5 as workspace v32)

Status: **done**. S1–S5 are now a release an adopter can pick up: `WORKSPACE_VERSION = 32`, a
`## v32 — 2026-08-23` CHANGELOG entry with **Migration notes**, the `update-workspace` pre-v32
sentence, README / retrofit-guide prose, the new safety-critical Test 0 invariants plus three engine
probes in `tests/retrofit_smoke.sh`, and the rebuilt artifact. **D4 is fixed** (see below), so the
orchestrator can close it.

## Files changed

| File | Change |
|---|---|
| `installer/main.py` | `WORKSPACE_VERSION = 31` → `32` (line 38 — the **only** version stamp in the tree) |
| `CHANGELOG.md` | new `## v32 — 2026-08-23` entry, 8 bullets, above v31 |
| `.claude/skills/update-workspace/SKILL.md` | step 8 gains the "**Coming from a pre-v32 workspace:**" sentence |
| `README.en.md` | `accept-gate` row in the CLI command table; +1 sentence in *Contributing* step 3 |
| `README.md` (Korean) | +1 sentence each in the "검증을 통과해야 끝납니다" bullet and habit 3 |
| `docs/retrofit-guide.md` | new "**Coming from a pre-v32 workspace.**" paragraph in § *Updating after adoption*; **D4** row in § *Troubleshooting* |
| `tests/retrofit_smoke.sh` | Test 0 v32 invariants + the tier-parity check + 3 engine probes in Test 5 (+45 / −9 lines) |
| `bootstrap_agentic_workspace.sh` | rebuilt (372376 bytes) |

`installer/README.md` was **not** touched: its release rule is version-agnostic and it states no
behaviour v32 changes.

## The CHANGELOG entry as shipped (`## v32 — 2026-08-23`, 74 body lines)

Bold-lead bullets, v31's house style, **Migration notes** last:

1. **Why this release: every gate the machinery had sat between agents.** — the incident in one
   bullet: two build phases, 30 slices, a scripted fidelity pass each, both reviews passed, and the
   product owner met the running product only afterwards and filed 11 failures, led by the login
   link that never rendered because of a dev-only double-effect the production-build verification
   could not see. "Verification's only yardsticks were the signed design record and the executor's
   most convenient runtime."
2. **The operator acceptance gate, machine-enforced.** — the five-field `acceptance` block, the four
   `accept-gate` flags with their moments (`--require`/`--waive --note` at the `DECOMP` boundary,
   never by omission; `--open --walkthrough`; `--clear [--note]`; bare = show), the
   `review-phase --verdict pass` refusal, `changes_requested`/`blocked` never refused +
   `changes_requested` resets the gate, `next`'s walkthrough output, `validate`'s done-but-uncleared
   error, and "no `acceptance` block at all = legacy = passes exactly as before".
3. **The operator runtime manifest.** — the `## Operator Runtime` fields, "verified in a real
   browser" means *that* runtime and access path plus the production build when they differ, and
   the `- Status: UNFILLED — …` marker with absent == unfilled → `needs_operator` → `pending`.
4. **"Works as a product" is a named verification dimension beside "matches the record."** —
   `design-cowork`'s new `## Verifying — RESPECT THE DESIGN, and does it work` section, the record as
   floor not ceiling, the four-item sweep, both runtime modes; plus the review's fresh-eyes
   walkthrough (**not** judged against the design record) and its independent spot-check.
5. **Questions get asked, not archived.** — the `## Operator Questions` list (now in the `new-phase`
   scaffold), routing into the walkthrough or a deferred job, unrouted = a finding that blocks the
   pass, "signing the cards is not accepting the product".
6. **A cumulative product smoke list.** — `## Regression Checklist` reuse, the
   `- [ ] <surface>: <one observable behaviour> (P<N>)` shape, re-run **whole**, terse on purpose.
7. **Executor prompts carry the gate duties, with one new return field.** — the
   `acceptance.required` switch, the manifest as a named input, the six gate stages, the
   `## Operator Questions` habit, `walkthrough` as the one new return field, `accept-gate` +
   `defer-job` prohibited, **doc consolidation does not move** (pass path, before the gate; parallel
   still deferred — S3's binding decision, stated the same way), and byte-identical tier bodies
   (D2 closed) pinned by the smoke test.
8. **Migration notes:** `--update --dry-run` first; `--update` preserves `works/` and `docs/`, which
   is why (a) existing phases carry no block, stay legacy, and pass as before — opt a **live** phase
   in with `accept-gate <P> --require`, never a `done` one (S1's finding: `validate` would then
   correctly fail it); (b) `## Operator Runtime` and the rewritten `## Regression Checklist` reach
   **fresh installs only** — add them with `doc-new-version` from
   `installer/payloads/doc_bodies/`, never by hand-editing `docs/current/*.md`, and until the
   manifest is real the first real-browser slice stops `pending` asking for it; (c) `sync-agents`
   after the update, as always.

## Test 0 additions (and the three engine probes)

Every string was quoted from the file as it stands, not from memory. Net +36 lines, one suite, no
new test file.

- **`CLAUDE.md`** — four entries appended to the existing contract tuple: `accept-gate`,
  `## Operator Runtime`, `## Operator Questions`, `never by omission`.
- **`.claude/skills/review-phase/SKILL.md`** (newly read by Test 0) — `## Gate stages`,
  `` `walkthrough` ``, `` `## Operator Runtime` ``, `` `## Regression Checklist` ``, plus the
  never-run pair asserted **on one line**: the single line containing `you never run on a review
  slice` must name both `` `accept-gate` `` and `` `defer-job` ``.
- **`do-next-slice` / `do-whole-phase`** — `accept-gate <P> --clear` added to the existing per-skill
  `required` tuple (covers both "accept-gate" and "--clear" in one exact string).
- **Both executor tiers** — the old "the design gate is spelled out in the high tier" comment and
  its high-only assertions are replaced by a **both-tiers loop** asserting, per tier: the co-work
  refusal (`` never dispatched, because you have no `DesignSync` ``), `` return `needs_operator` ``,
  the gate-stage opener `` On a gated phase (`acceptance.required` is `true` — and only then) also
  run the gate stages ``, the return field `` - `walkthrough`: ``, and the Never bullet (the one
  line containing `run workflow state-transition commands` must name `` `accept-gate` `` and
  `` `defer-job` ``). Then the **parity invariant**, one line: bodies below the frontmatter
  (`split("---\n", 2)[2]`) are byte-equal between mid and high.
- **`design-cowork`** — five sentences appended to the existing tuple:
  `## Verifying — RESPECT THE DESIGN, and does it work`, `### When the record never drew it`,
  `matching it is not acceptance`, `Questions get asked, not archived.`,
  `signing the cards is not accepting the product`.
- **Seed doc bodies** (read straight from `installer/payloads/doc_bodies/`, so the invariant is on
  what ships): `## Operator Runtime` + `UNFILLED` in `operations.md`; `## Regression Checklist` +
  `- [ ] <surface>: <one observable behaviour> (P<N>)` in `qa.md`.
- **Engine probes, in Test 5's existing throwaway fresh install** (`$F`, after the `sync-agents`
  check): `new-phase` stamps an `acceptance` block; `review-phase P1 --verdict pass` on the
  undeclared phase prints `accept-gate P1 --require` (the refusal, not merely a non-zero exit);
  `accept-gate P1 --waive` without `--note` exits non-zero. The probe phase is left in `$F` and does
  not disturb the later `--update` assertions (verified: the whole suite passes).

## D4 — fixed here (folded in, not grown)

`docs/retrofit-guide.md` § *Troubleshooting*, the "`git status` shows a modified file you had" row,
now reads **"The only intended modifications are the additive `.claude/settings.json` merge, the
marked `CLAUDE.md` section, and the `.gitattributes` line-merge (the `works/events.jsonl
merge=union` rule appended below a comment — your existing rules are left untouched, and re-running
adds nothing); report anything else as a bug."**

Behaviour confirmed against source before wording it: `installer/main.py`'s `_gitattributes_action`
returns `create` / `merge` / `unchanged` and `_apply_gitattributes` appends
`GITATTRIBUTES_APPEND_NOTE` + the rule, never rewriting existing content; `tests/retrofit_smoke.sh`
pins the same three-file modification set (`.claude/settings.json,.gitattributes,CLAUDE.md`), the
preserved original rule, and one-union-rule idempotence. Nothing else in D4's scope was touched.
**The orchestrator can now close it:**
`python3 scripts/workflow.py drop-deferred D4 --reason "fixed in P16.S6 — the retrofit guide's Troubleshooting row now lists the .gitattributes line-merge"`
(not run here: executors run no state-transition command). **D3 did not fire** — `installer/build.py`
is untouched.

## Validation

| Command | Outcome |
|---|---|
| `python3 installer/build.py` | wrote `bootstrap_agentic_workspace.sh` (**372376 bytes**) |
| `python3 installer/build.py --check` | **OK** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py validate` | **Workflow validation passed.** |
| `python3 scripts/workflow.py sync-agents --check` | **agent files in sync** (`mid sonnet @ xhigh`, `high opus @ xhigh`, mode flex) |
| `bash tests/retrofit_smoke.sh` | **ALL RETROFIT SMOKE TESTS PASSED** — including `PASS: 17 Claude skills, invocation metadata, design contract, the v32 acceptance-gate invariants, and the v31 Codex-removal negatives`, `PASS: release version agrees across installer, top changelog heading, and fresh marker`, and the three new gate probes |
| **Deliberate-failure proof** of the new Test 0 block | Test 0's python body was extracted to the scratchpad and run against mutated *copies* of `.claude/`, `CLAUDE.md`, `installer/` (never the real tree): altering mid's body → `AssertionError: slice-executor tier bodies drifted`; removing `Questions get asked, not archived.` → fails; `UNFILLED` → `TBD` in the seed → fails; `accept-gate` off both Never lists → `AssertionError: mid`; `never by omission` out of `CLAUDE.md` → fails; renaming `## Gate stages` → fails; unmutated control → passes. No debug output was left in the suite. |
| Fresh install of the rebuilt artifact | into `…/scratchpad/v32install` with the log written **outside** the target (S2's gotcha): `works/.workspace-version.json` → `"workspace_version": 32`; `docs/current/operations.md` carries `## Operator Runtime` + `UNFILLED`; `docs/current/qa.md` carries the cumulative smoke list; `validate` passed; `new-phase P1` there stamped the five null `acceptance` fields and scaffolded `## Operator Questions`. Directory deleted afterwards. |
| Stray-version grep | `installer/main.py:38` is the only current-version statement in the tree. Every remaining `v31` is history (CHANGELOG, the Codex-removal negatives in the smoke test, `update-workspace`/`explain`/retrofit-guide migration notes, `installer/main.py`'s `OBSOLETE_MACHINERY` comments, generated `docs/current/*`). No `31` needed changing. |
| No new test file | correct — `tests/retrofit_smoke.sh` remains the one suite. |

## Deviations from `plan.md`

1. **Entry length.** The plan set "v31's length is the ceiling" (51 lines). After two trimming
   passes the v32 entry is **74 body lines** across 8 bullets: the plan's own enumerated coverage
   (why + gate + manifest + works-as-a-product + gap channel + smoke list + executor prompts +
   three-part Migration notes) does not compress further without dropping content it requires.
   Line width matches the file (≤100 cols, no code span split across a line break).
2. **No `accept-gate` row in the Korean README's table.** `README.md`'s only table is the
   `/slash`-command **skill** list ("Claude Code에서 `/이름`으로 입력합니다") and `accept-gate` is a
   CLI command, not a skill — a row there would have been wrong. The command name instead appears
   inside the Korean review-flow sentence (`accept-gate <P> --clear`), so it stays discoverable.
   `README.en.md` does have a CLI command table, and got the row next to `review-phase` as planned.
3. **Test 0 also asserts the never-run pair on a single line** (rather than mere presence of the two
   strings), in both the review skill and both agent files. One line each, and it is the assertion
   that actually pins "these two commands are prohibited **together**".
4. Nothing else. No `scripts/workflow.py`, `CLAUDE.md`, review/loop/design skill or executor-agent
   edit; no `installer/README.md` edit; no commit, no state-transition command (`drop-deferred`
   included).

## Notes carried to `phase.md`

Findings: the single version stamp, the fresh-install proof, the Test 0 failure proof, and the fact
that no S1–S5 defect was found. Doc impact: `operations` (the v32 release + its migration notes) and
`architecture` (the tier-parity invariant now pinned by Test 0). No new operator questions.
