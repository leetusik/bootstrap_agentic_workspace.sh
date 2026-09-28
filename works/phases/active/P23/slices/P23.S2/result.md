# Result — P23.S2 (implementation/high): cut the derived and duplicated contract text and open v44

## Verdict

- **status:** done
- **summary:** Cut all of `## Workflow Commands` and the 32 other CUT/MOVE units outside HR-23/25/26 from `CLAUDE.md` (50,048 B → 36,712 B / 36,418 chars, under the 40k-char warning), after checking each unit's carrier. The closed `--kind` set moved to *IDs and Status*. Both executor bodies gained the OQ1 docs-slice carve-out and the fractional `--order` / advisory `depends_on` facts (+727 B each, still identical). Also fixed D-4 and D-6, re-pointed the READMEs to `--help`, moved the pins, and opened workspace v44. Smoke counted 180 PASS / 0 FAIL.
- **files_changed:** `CLAUDE.md`, `.claude/agents/slice-executor-high.md`, `.claude/agents/slice-executor-mid.md`, `.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md`, `scripts/workflow.py`, `works/templates/phase.md`, `README.en.md`, `README.md`, `tests/retrofit_smoke.sh`, `installer/main.py`, `CHANGELOG.md`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P23/phase.md`, this `result.md`
- **validation:**
  - `wc -c CLAUDE.md` → **36,712 B** (was 50,048). `len(open("CLAUDE.md").read())` → **36,418 chars** (< 40,000).
  - Per-dispatch prefix, `wc -c CLAUDE.md .claude/agents/slice-executor-high.md` → 36,712 + 28,461 = **65,173 B** (was 77,782).
  - Executor bodies: high 27,734 → 28,461 B, mid 27,717 → 28,444 B. A frontmatter-stripped compare gives `BODIES_IDENTICAL`.
  - `python3 installer/build.py` → `wrote bootstrap_agentic_workspace.sh (540228 bytes)`. `python3 installer/build.py --check` (separate call) → `OK: … in sync`.
  - `python3 scripts/workflow.py validate` → `Workflow validation passed.`, with the three pre-existing advisories (`consolidation_owed=P21, P22`, `stale_docs`, `oversized_doc_sections`).
  - `bash tests/retrofit_smoke.sh > <scratchpad>/p23-s2-smoke.log 2>&1`, run as the only command in its call, in the foreground, with a 600000 ms timeout → **180 PASS / 0 FAIL** (counted with `grep -c` in a separate call). The last line reads `ALL RETROFIT SMOKE TESTS PASSED`. This confirms S1's static 180. No `ok` line was added (the new asserts sit inside Test 0's existing Python block), so there is no difference to account for.
  - Test 0's Python block, run standalone against the edited tree before the full run → OK.
  - Never-rule floor: grepped the surviving contract phrase of every N-rule whose source units this slice touched (N10, N21, N25, N26, N29, N37), plus N1–N6, N8, N9, N11–N28, N31–N40, N45–N47, N57 and N58. **All present.**
  - `git status --porcelain` shows the files above, plus the `works/` files the orchestrator had already modified before dispatch (`backlog.md`, `events.jsonl`, `index.json`, `state.json`, `P23.S2/slice.json`, `P23.S2/plan.md`).
- **deviations:** (details in §3)
  1. HR-7b: only the 29 B connective was cut. The 66 B sentence "It writes **no product code**" is N29's only contract statement, so it stays.
  2. HR-12b: a 62 B noun phrase stayed so the two-file list still parses.
  3. Contract carve-out lists (DR-7a, HR-14d): `decomposition/review` → `decomposition/review/docs`. This was not in the plan. Without it, the contract would contradict the carve-out just added to the executors.
  4. Executor growth is +727 B per body, against S1's ≈ +400 B estimate.
  5. `workflow.py`: added `--order` help to all three parsers (all fit), plus `--depends-on` help, which the plan did not ask for.
  6. The CHANGELOG Migration notes line leaves out "later P23 slices extend this section". I read that as an instruction to me, not text for adopters.
  7. The smoke log is in the session scratchpad, not `/tmp`.
  8. Grammar-only residues: "`DECOMP` sets …" replaces "It sets …", a colon became a period, and a bullet now opens with "Archiving is …".
- **doc_impact:** six lines appended to `phase.md` `## Doc impact`: architecture.md ×2, operations.md ×2, qa.md, decisions.md. They are quoted in §5.

## 1. The cut, unit by unit, with the carrier checked before each cut

Every carrier below was grepped present before its unit was removed (S1 `result.md` §3 names the `file:line`). The byte counts come from the edit script and match the notebook's rule map, except where §3 notes otherwise.

| unit | B removed | carrier verified (grep hit) |
|---|---|---|
| DR-5b | 241 | `do-next-slice:22` "Skip planning for an existing `ready` … dispatch directly"; `do-whole-phase:18-19` |
| DR-6b | 289 | `workflow.py:105` + `executors.toml:7`; `do-next-slice:26` "Tier models/efforts come from `executors.toml` + `sync-agents` (economy …; flex …)" |
| DR-7b | 377 | `do-next-slice:26` "as a background task"; `:28` "Trust the verdict"; executor `:62` "trusts your `done` verdict" |
| DR-7d | 229 | executor `:36` ("before you branch on the verdict", `explain: not written`); `review-phase:73` |
| HR-1 | 128 | the engine renders `backlog.md` / `deferred.md` (`workflow.py` rebuild; `STAMP_WORKS_FILES`) |
| HR-5b | 316 | `review-phase:35,:57` (verify the list); `archive-phase:18,:32` (consolidation gate); executor `:49`; the docs-slice permission MOVEd to the executors (§2) |
| HR-5d | 386 | executor `:25` (STALE = evidence); RO-4 keeps "never as current truth" (N10) |
| HR-6a | 129 | `create-phase` frontmatter "intent.md + DECOMP/REVIEW only"; `workflow.py new-phase` |
| HR-6b | 266 | executor `:35` "bare folders only — never pre-fill their `plan.md`"; `do-next-slice:37`, `do-whole-phase:35`; HR-12d keeps the never-rule (N26) |
| HR-7b | 29 of 95 | connective only (see §3) |
| HR-7d | 295 | executor `:34` "in `phase.md`, where the next slice will actually read them" (pinned at smoke `:304`) |
| HR-7e | 215 | executor `:34-35` ("A `<P>.DECOMP2` usually follows a research slice") |
| HR-9 | 310 | `create-phase:68` "STOP and report"; DR-10 keeps "Do **not** decompose …" (N15) |
| HR-12b | 261 of 323 | `do-next-slice:23-25` (inline `Write`; gated copy of the harness plan file); `do-whole-phase:18-19` |
| HR-12e | 46 | `workflow.py:1446` (new-slice writes only `slice.json`) |
| HR-13b | 425 | executor `:40-44` (per-section notebook rules); template intros (tag form now fixed, D-6) |
| HR-14b | 292 | `do-next-slice:26` "an implementation/`fix` with `risk` exactly `low` uses `slice-executor-mid` only …"; `do-whole-phase:28` |
| HR-14c | 143 | `do-next-slice:26` (`executors.toml` + `sync-agents`) |
| HR-14e | 182 | `do-next-slice:28`, `do-whole-phase:28`, executor `:62` |
| HR-15b | 51 | `do-whole-phase:33` "reconciling whatever you gathered against what N actually changed" |
| HR-15c | 337 | `do-whole-phase:31` "It usually does not when the current slice is `DECOMP` …" |
| HR-16 | 251 | MOVE: executor decomposition bullet (§2), plus `workflow.py --order` / `--depends-on` help |
| HR-17e | 659 | `design-cowork:21,:43-67` (PENDING #1/#2); `do-next-slice:14,:26`; `do-whole-phase:16,:21-27`; line 79 (HR-26e) still carries "PENDING #2 exists only when a mockup was requested" |
| HR-18 | 279 | `do-next-slice:22,:25`; `do-whole-phase:18-20`; `workflow.py:1204` (ready without `plan.md` errors) |
| HR-20a | 294 | `review-phase:85`; `do-next-slice:44-47`; `workflow.py:1545-1560` |
| HR-20b | 100 | `do-whole-phase:45` "do **not** archive it here"; `do-next-slice:45` |
| HR-20e | 404 | `archive-phase:18,:32`; `workflow.py:2805-2812` |
| HR-21b | 93 | `workflow.py:1607` ("declare one with: … --require \| --waive"); `_require_acceptance_cleared` |
| HR-21c | 648 | `do-next-slice:39`, `do-whole-phase:35`, `design-cowork:353` (fixed waive note; pinned on do-* `:116` and dc `:178`) |
| HR-21d | 766 | `do-next-slice:43`, `review-phase:60-69`, executor `:36` |
| HR-21f | 93 | `workflow.py:844-856` (no block = legacy); executor `:24` |
| WC-0..23 (WC-3 moved) | 4,653 | `python3 scripts/workflow.py --help` lists all 32 subcommands; `new-slice -h` carries the closed kind set; `accept-gate`'s help says "executors never run it"; `new-phase -h` carries the `--on-main` no-op. WC-3's closed-set fact is now a `Slice kinds:` line in *IDs and Status*, with both pins on that one line |
| CC-2b | 497 | `parallel-phase:10-32,:202-253`; `do-whole-phase:44` (branch integration, `git merge --no-ff`) |

**Additions (the only new contract prose):** DR-1 gains ", and `python3 scripts/workflow.py --help` is the command reference" (+67 B). The IDs `Slice kinds:` line is +261 B.

**Net:** 13,336 B removed. The edits were made with a throwaway script in the session scratchpad that asserted each old string occurs exactly once; `git diff e08bd7a -- CLAUDE.md` is the durable record.

## 2. Executor bodies (both files, byte-identical below the frontmatter)

- `:10`: "Two carve-outs" became "Three carve-outs", adding: "while executing a **`docs`** slice in a docs phase you may version the docs its plan names".
- `:35`, decomposition bullet (HR-16 MOVE): "Slices run by `order`; a fractional `--order` (e.g. `4.5`) inserts a slice between two neighbors without renumbering, and `depends_on` is advisory — `validate` checks only that it exists."
- Step 5 heading: "… never per slice, and not at the review** — except by that phase's own `docs` slices:".
- A new step-5 bullet after "Any slice that changes durable truth": "**The `docs` slice's carve-out:**". It carries the operator-approved OQ1 wording word for word.
- `:55`, the may-run list: "(review slice, two named gate sections only; `docs` slice, the notes its plan names)".
- `:56`, the Never list: "version docs outside the review and `docs`-slice carve-outs".

## 3. Deviations from `plan.md`, with reasons

1. **HR-7b kept 66 of its 95 B.** S1's byte split puts "It writes **no product code**: what was learned *is* its product." inside HR-7b, next to the connective "Four things define the kind." S1's never-rule table, however, attributes N29 (a research slice writes no product code) to HR-7a. HR-7a is only the heading plus the "Cut a `research` slice" sentence. So cutting all of HR-7b would have left N29 with no contract statement. The plan says no never-rule may lose its only statement, so only the 29 B connective went. S4's Driving stub takes N29 over (probe phrase `never writes product code on a `research` slice`), and the notebook has a `(from P23.S2, for P23.S4)` note saying so.
2. **HR-12b kept a 62 B noun phrase**, "`plan.md`, the orchestrator's complete free-form native plan,". The sentence opens "Each slice owns exactly two context files …:" and needs both names to stay grammatical. What left is the persistence detail (inline vs byte-exact copy) and the operator-note clause, which `do-*` carry.
3. **The contract's two carve-out lists now name docs.** DR-7a's "(except the decomposition/review command carve-outs)" and HR-14d's "with only the decomposition/review workflow-command carve-outs" both became `decomposition/review/docs` (+5 B each). Both units are STAY, and the plan said to touch them only for grammar. But HR-5b was the contract's only hint of the docs exception. With HR-5b cut and the executors given a third carve-out, "only decomposition/review" would have contradicted the approved OQ1 carve-out in the file every dispatch loads. The edit is 5 B and changes no pinned phrase. The OQ1 Decisions line records it for S4.
4. **Executor growth is +727 B per body, not ≈ +400 B.** The operator-approved OQ1 sentence alone is ~300 B, and the HR-16 facts ~200 B. The four OQ1 touch points the plan names add the rest. I trimmed one draft pass (+813 → +727). The scope rule still holds by a wide margin: the executors grew 0.7 KB while the contract shrank 13.3 KB in this slice.
5. **`workflow.py` help text.** The plan's `:2951` is actually `new-phase`'s `--order`; `new-slice`'s is `:2962` and `promote-deferred`'s is `:3062`. The same help fits all three: `new-slice` and `promote-deferred` share `_auto_order`, and `new-phase` gets a phase-ordered variant without the slice default. I also gave `--depends-on` (on `new-slice` and `promote-deferred`) the help text "advisory: validate checks only that the named slice exists; selection still follows --order", so HR-16's second fact can be found in `--help` too, not only in the executor. Confirmed against `workflow.py:1206-1208`: validate errors only on a missing id.
6. **CHANGELOG Migration notes.** The line says "nothing to run", that `/update-workspace` refreshes the contract or its `CLAUDE.workspace.md` sidecar, and to use `--help` where the Workflow Commands list was read. I did not add "later P23 slices extend this section" to the changelog. The file is read by adopters, so I took that clause in the plan as an instruction for S3/S4. They append to the same `## v44` section; the notebook's Release decision already says so.
7. **The smoke log path** is the session scratchpad (`…/scratchpad/p23-s2-smoke.log`), not `/tmp/p23-s2-smoke.log`, because this environment prescribes the scratchpad for temp files. The run discipline was unchanged: the only command in its call, foreground, 600000 ms.
8. **Grammar-only residues**, the ones the plan allows:
   - HR-6a/6b removal: "It sets each middle slice's `--risk`" → "`DECOMP` sets each middle slice's `--risk`" (+8 B).
   - HR-13b removal: "never merely appends:" → "never merely appends." The pinned phrase `every slice **edits** it under budget` is untouched.
   - HR-20a/20b removal: the bullet now opens "- Archiving is a separate, manual step: …".

## 4. Other edits

- **D-4:** `research` added to the delegated kinds at `do-next-slice:12` ("The execution of every slice — decomposition, `research`, implementation, `fix`, and the phase **review** —") and `do-whole-phase:12`.
- **D-6:** `works/templates/phase.md:29` and `PHASE_MD_TEMPLATE_FALLBACK` (`workflow.py:1329`) now both say "each tagged `**(from <slice>, for <slice>)**`". Smoke's byte-identity check passes.
- **D-2:** gone with WC-23 (`grep -c "four \`slice-executor" CLAUDE.md` → 0). **D-5:** no edit; `do-next-slice:26` now holds the only preset statement, and it is correct.
- **READMEs:**
  - `README.en.md:266` → "The full command list is `python3 scripts/workflow.py --help` (and `<command> -h` for one command's flags)."
  - `README.en.md:389` → "… and `python3 scripts/workflow.py --help` for the command reference."
  - `README.md:216-217` (Korean, two wrapped lines) → "전체 목록과 설치 옵션은 [English README](README.en.md)에 있고, CLI 명령 전체는 `python3 scripts/workflow.py --help`로 확인할 수 있습니다."
- **Smoke pins** (`tests/retrofit_smoke.sh`):
  - Four contract positives removed, each grepped first on its destination list:
    - `design-only, no mockup: …`: do-* `:116`, dc `:178`.
    - `finish-slice P1.S1 --outcome`: do-* `finish-slice <slice_id> --outcome` `:124`, plus the Test 9 functional check.
    - `**findings land in `phase.md`**`: executor `:304`, equivalent phrase.
    - `` `phase-scope P1 [--base REF] [--head REF] [--json]` ``: dc `:155`, rp `:239` and executor `:357` (`phase-scope <P>`), plus the Test 11 functional check.
  - The two `--kind` pins stay on the contract list and are satisfied by the IDs line.
  - Added to the executor-body list: `**The `docs` slice's carve-out:**` and `a fractional `--order` (e.g. `4.5`) inserts a slice between two neighbors`.
  - Comments updated to v44, including a block explaining where the four went. Every negative is in place.
- **Release:** `installer/main.py:38` `WORKSPACE_VERSION = 44`. `CHANGELOG.md` gets a new `## v44 — 2026-09-28` section on top, in the v43 style: a *Why this release* bullet, one bullet each for Workflow Commands → `--help`, procedure moved to its owners, the docs-slice carve-out, and `--order`/`depends_on`, then a smaller-fixes bullet and a **Migration notes.** line. Installer rebuilt.

## 5. Notebook edits (`phase.md`), referenced rather than restated

- **Decisions:** two lines corrected in place.
  - OQ1 now records where the carve-out landed and the contract's `decomposition/review/docs` lists.
  - The executor-growth line now carries the measured +727 B and the 65,173 B prefix.
- **Doc impact:** six lines appended.
  - architecture.md: the contract lists no commands; `--help` is the reference; the `--kind` set is in IDs.
  - architecture.md: the template tag form.
  - operations.md: v44 opened, plus the new `--order`/`--depends-on` help.
  - operations.md: the executor's docs-slice carve-out.
  - qa.md: the four pins moved, two executor pins added, baseline counted at 180.
  - decisions.md: why the contract slimmed and where the cut text lives.
- **Notes for later slices:**
  - The rule map lost the rows for the 55 units cut here. HR-7b's row now records the 66 B kept.
  - The Slice breakdown's S2 entry is removed. Its shared rules now carry the counted baseline and the 65,173 B prefix.
  - D-1, D-2, D-4 and D-6 are removed from the drift note.
  - The README item is removed from the inbound-references note.
  - The audiences of S1's notes are now S3–S4.
  - The Machinery note carries the counted baseline.
  - One new note, `(from P23.S2, for P23.S4)`, lists the S2 edits the rewrite must keep: the `--help` pointer, the three carve-outs, the `Slice kinds:` line, and N29's sentence.
- **`## Now`:** rewritten for S3.
