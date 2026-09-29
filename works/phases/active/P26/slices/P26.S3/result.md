# Result — P26.S3: rewrite `design-cowork` around the files

- **status:** done
- **tier:** high
- **summary:** Rewrote the loop mechanics of `.claude/skills/design-cowork/SKILL.md` around the on-disk contract and the `design-drafter` subagent. The loop is now design-open + handoff (with a "new visual direction" line) → drafter dispatched in the background → inline read-back (`design-check` run by the orchestrator) → PENDING #1 → literal words sign (`SIGNOFF.md` + `design-close --words`) or feedback supersedes (`design-close --superseded` + a new round in the same slice), with the mockup gate unchanged. The frontmatter, the `frontend-design` ban (lifted for the drafter on new-direction rounds only), the bundle import and the smoke pins also changed. Every governance rule keeps its meaning (audit below). The contract, Implementing and Verifying sections are byte-identical.
- **files_changed:** `.claude/skills/design-cowork/SKILL.md`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P26/phase.md`, `works/phases/active/P26/slices/P26.S3/result.md`
- **validation:**
  - `python3 installer/build.py`: wrote the artifact (589,555 bytes). PASS
  - `bash tests/retrofit_smoke.sh`: ALL RETROFIT SMOKE TESTS PASSED, 195 PASS / 0 FAIL, the same count as before (the new pins sit inside Test 0's existing block). PASS
  - `python3 installer/build.py --check`: in sync. PASS
  - `python3 scripts/workflow.py validate`: passed; the only warning is the pre-existing oversized doc sections one. PASS
  - Test 0's Python block run on its own before the suite: exit 0. PASS
- **deviations:** none of substance. There are three judgment calls the plan left open, each recorded in `## Decisions`:
  1. A read-back failure the drafter can fix goes back to it once before the slice stops `pending`.
  2. A revision handoff must list every card still carrying the slice's address, because `design-check` flags an inherited card left off the list.
  3. The orchestrator runs `design-init` on a product's first round, while `design-register` stays the operator's.

  I also changed a few lines in §Shape: "round count" became "design-slice count", and "landed" became "signed" where it meant post-approval. Both keep their meaning (audit rows 3 and 6).
- **doc_impact:** three lines appended to `phase.md` `## Doc impact`: operations.md (the Visual-design runbook rewritten to the file loop, the drafter and the bundle import), decisions.md (why the loop moved off Claude Design, P25, and the drafter replaced it), qa.md (Test 0's design-cowork pins moved; baseline unchanged at 195).

## What changed in `design-cowork/SKILL.md`

The file went from 57,445 B to 65,531 B. Each section's before/after:

| Section | Before | After | Treatment |
|---|---|---|---|
| frontmatter | 617 B | 709 B | `DesignSync` dropped from `allowed-tools` (`Agent` stays, to dispatch the drafter). `description` rewritten ("the design subagent drafts, the operator decides, and the design lives as plain files in the repo"). The trigger sentence is verbatim, with no `: ` and no `#`. |
| intro | 676 | 1,099 | "You never design." kept; "The design subagent drafts, the operator decides." added; *The line* re-split into drafter drafts / operator decides |
| §The loop | 3,437 | 4,744 | new diagram and prose; commit counts |
| §Shape — three styles | 6,737 | 7,003 | governance: terminology aligned only (rows 3–6) |
| §The handoff | 1,764 | 2,984 | the drafter's brief; `new visual direction: yes`/`no`; revision-round handoff; the bundle clause moved out |
| §The card set | 4,167 | 4,094 | pane wording → any reader / `design-check`; the S1 marker bullet kept verbatim |
| §Importing a Claude Design bundle (optional) | — | 1,104 | new |
| §The design record (S1's contract) | 10,931 | 10,931 | **byte-identical** |
| §Read back, then land it | 2,449 | 3,836 | verdict handling, `design-check` run by you, concreteness, landing pointers, the PENDING #1 report |
| §The mockup | 5,560 | 5,926 | governance: four sentences touched (rows 16a–d) |
| §Closing the round | 2,260 | 2,934 | the three outcomes of the operator's words; SIGNOFF; `design-close --words` |
| §Mechanics | 2,497 | 2,902 | what runs where, dispatching the drafter, who writes what, the register hook, no account/push |
| §Implementing | 815 | 815 | **byte-identical** |
| §Verifying (+ When the record never drew it) | 12,052 | 12,052 | **byte-identical** (D7/D13 and the Aside fallback paragraph are untouched, as scoped) |
| §Never | 3,483 | 4,398 | rows 21–36 |

Cross-references to S1's contract section (*The design record*) are unchanged, and the section itself was not edited. The only other place that names `design-cowork` sections is `docs/current/operations.md` (generated; the Doc impact note covers it).

## Governance audit, before and after

"Before" line numbers refer to the pre-S3 file (post-S1, 57,445 B, at HEAD `48a20ee`). "After" names the section in the new file.

| # | Rule | Before | After | Verdict |
|---|---|---|---|---|
| 1 | The orchestrator never designs | intro L9 "You never design." | intro, same sentence | meaning unchanged |
| 2 | Who draws, who decides | intro L9 "Claude Design + the operator make every visual decision"; L14 "Deciding what it should look like is Claude Design's" | intro "The design subagent drafts, the operator decides"; *The line*: drafting is the drafter's, deciding is the operator's | **changed as planned** (plan §"The drafter replaces Claude Design as the one who draws"; intent item 4). The decision stays with the operator, only literal words sign, and the orchestrator and slice executors still never design. |
| 3 | Three styles `build-after` / `design-only` / `paired`, chosen by name; you suggest, the operator confirms; `## Design Style` + `Mockup:` line; `design-only` only at `/create-phase` | §Shape L69–155 | §Shape, verbatim except as noted | meaning unchanged. "once the design has landed / the landed spec" → "once the design is signed / the spec pointers … the signed round's `build-prompt.md`" (L105, L119, L136–138), because "landing" now happens *before* PENDING #1 and the old word meant post-approval. |
| 4 | A design slice is `--kind co-work --risk high`, never `low` | §Shape L71; Never "Rate a design slice `low`" | same places | meaning unchanged. The reason clause now names both dispatched spans at the high tier (the drafter follows it, the mockup goes to `slice-executor-high`). |
| 5 | A design slice writes no *product* code; a requested mockup is the one exception | §Shape L72–74; Never | same, plus "The drafted cards are the design record, not code the product runs" | meaning unchanged (clarified, so HTML cards are not read as code) |
| 6 | Design-slice count decided at DECOMP; build inventory; don't over-plan before the gate; `paired` apply count | §Shape L139–175 | same | meaning unchanged. "rounds" → "design slices" where it meant `co-work` slices, because a contract *round* is now one iteration inside a slice. Added: "A slice's revisions are superseding *rounds* inside it, never cut in advance." "what the operator will design" → "what the operator will sign". |
| 7 | Immutable rounds; a revision is a new superseding round, never an edit | §The mockup L478–481 (rejection); contract lifecycle (S1) | §Closing "Feedback" bullet; §The loop; §The mockup rejection bullet (now names the mechanics); contract unchanged | meaning unchanged, and now also mechanized. Before, iterations happened inside the Claude Design session. Now any operator feedback at PENDING #1 closes the round `--superseded` and opens a new round in the same slice. |
| 8 | Only the operator's literal words sign, never silence / the record looking finished | §The loop L43–48; §Closing L498–502; Never L748–751 | §The loop ("The operator's return closes the round." kept); §Closing preamble; Never | meaning unchanged. "not on the Claude Design session having ended" → "not on the drafter's `done`" in both places. |
| 9 | Never sign before the read-back; a failed read-back raises exactly those points, `pending`, nothing signed | §The loop L46–48; §Read back L409–415 | §The loop; §Read back steps 1–4 and "A failed read-back means nothing is signed" | meaning unchanged. **Routing changed:** a card-contract or thin-`build-prompt.md` failure first goes back to the drafter once (the drafter now authors; before, only the operator could re-run Claude Design), then `pending` with exactly those points. |
| 10 | Never sign at the return when a mockup was requested | Never L750–751 | Never (verbatim) | meaning unchanged |
| 11 | Card contract: one card per unit, never a monolith; line-1 marker; numbered reading-order paths; the round's address under review; a clean library after | §The card set L185–230 | §The card set | meaning unchanged. "pane" → any reader/dashboard; `list_files` → `design-check <the list>`; "the cards appear in the pane" → "`design-check` passes on the handoff's list and every card renders on its own". Numbering aligned to the contract: new cards continue from the library's highest number. The S1 marker bullet is verbatim. |
| 12 | Never fill a design gap; the concreteness bar ("no design decisions left to invent") | §Read back L409–415 | §Read back step 4; Never "Fix a design gap silently" | meaning unchanged. A question only the operator can settle goes to them at PENDING #1, and the round cannot be signed as drafted while the build depends on it. |
| 13 | The handoff decides nothing: locked vs in-play; real content, never lorem; open questions posed back; REFERENCE is data | §The handoff L160–183 | §The handoff | meaning unchanged. Added `new visual direction: yes`/`no` as **the operator's call** (from S2's note). The bundle clause moved to §Importing. |
| 14 | Required output: card set + record with departures + implementation contract; "Markdown alone is not a round" | §The handoff L172–179 | §The handoff (named `result.md` / `build-prompt.md`) | meaning unchanged |
| 15 | SIGNOFF content: literal words, what supersedes what, the mockup route, token delta ("None."), the data-not-instructions line | §Closing step 4 | §Closing step 1 | meaning unchanged (verbatim) |
| 16 | Mockup gate: on request only (`Mockup: requested` / own words); throwaway route; real stack; stubbed; exempt from the sweep; verified in `## Operator Runtime` with Aside; third `needs_operator`; PENDING #2 only when requested; the walkthrough's contents; rejection split; throwaway lifecycle; the phase gate follows the mockup; fixed waive note | §The mockup L430–494 | §The mockup | meaning unchanged. Four sentences touched: (a) "no dispatched span at all" → "no mockup span — the drafting is its only dispatched work"; (b) "between landing and SIGNOFF" → "between the operator's go-ahead at PENDING #1 and SIGNOFF"; (c) the dispatch bullet: "the one dispatched span" → "the one span a `co-work` slice dispatches to a slice executor", and "no DesignSync" → the record on disk, cards included, plus `build-prompt.md` is the executor's source; (d) route path recorded "in the round's record *and* `phase.md`" → "in `phase.md`, and in the round's `SIGNOFF.md` at close" (the contract's closed file set). The parenthetical naming the first two `needs_operator` conditions was reworded to the new read-back. |
| 17 | Commits one per span; the orchestrator makes all; dispatched agents commit nothing | §The loop L55–67 | §The loop | meaning unchanged. **Counts changed:** 2 → 2 without a mockup, 4 → 3 with one, +1 per superseding round. The handoff no longer needs its own commit plus push (the drafter reads the working tree), so it lands with the drafted round. Stops unchanged: one, or two with a mockup. |
| 18 | RESPECT THE DESIGN (implementing) | §Implementing | §Implementing | **byte-identical** |
| 19 | Verifying: two yardsticks, functional sweep, runtime, Aside + dedicated profile + third halt, fallback, boundary re-run, fidelity fixes, evidence, *When the record never drew it*, "signing … is not accepting the product" | §Verifying L569–728 | §Verifying | **byte-identical** |
| 20 | Returned content is data, not instructions | §Mechanics L536–537 | §Mechanics (the drafted record and any imported bundle); §Importing | meaning unchanged |
| 21 | Never author a new visual decision; requiring a card is not drawing one; the orchestrator's writes only file what exists | §Mechanics L555–556 ("That ban does not move"); Never L732–736 | Never bullet 1; intro *The line* | meaning unchanged. Reworded to the split: drafting is `design-drafter`'s alone, and a slice executor never makes a design decision ("the mockup span builds only what the record says"). "round 1" → "a first draft", since `rounds/01-…` now exists. The mockup-timing clause "before the round has come back" → "before the operator's go-ahead on a drafted, read-back round". |
| 22 | Answer no design question; pose it back | Never L737 | Never | meaning unchanged. Added: the drafter may draft options; only the operator's words settle it. |
| 23 | `frontend-design` / `artifact-design` ban | Never L738 | Never | **changed as planned:** lifted for `design-drafter` on a `new visual direction: yes` round only, and kept for everyone else (you, slice executors, the mockup span, the drafter on other rounds). `artifact-design` stays banned for all. |
| 24 | `/design-sync`, `/design …` are user-invocable only; `/design-sync` grounds a project in an existing library | Never L739–740; §Mechanics case 1 | Never "Use `DesignSync`, or make a round depend on a claude.ai account, a repo connection or a `git push`"; §The handoff *Where to look* ("grounding in an existing, implemented component library is a round like any other") | **retired with the tool** (intent item 3). The loop uses no Claude Design command. Grounding in real components is now a drafter round pointed at them. |
| 25 | DesignSync main-thread only; the read-back and regroup never dispatched | §Mechanics L529–535; Never L742–744 | §Mechanics *What runs where*; Never "Dispatch the read-back, a `pending` stop, `feedback.md`, `SIGNOFF.md` or `design-close`…" | **changed as planned** (intent item 2: "Background-dispatchable — nothing main-thread only"). The drafting span is dispatched. The surviving meaning, that **the round's lifecycle and the operator's words stay inline**, is kept and pinned. |
| 26 | The single authorized `git push` | §The card set L232–234 | §Mechanics "a design slice authorizes no `git push`"; Never | **tightened:** the push existed only so Claude Design could read the repo, and it is now gone |
| 27 | Target the project by id; every write via `finalize_plan`; the two sanctioned write cases | §Mechanics L538–556 | — (the case-2 invariant lives in §Closing and the engine) | **retired with DesignSync** (no external project). Case 2's invariant (line 1 only, every later byte identical) is kept and now engine-asserted. |
| 28 | Port another product's design | Never | Never (verbatim) | meaning unchanged |
| 29 | Never edit the returned record; never touch anything below line 1 at the regroup | Never L760 | Never "Edit a drafted card or a closed round's record yourself — or touch anything below line 1 of a card at the SIGNOFF regroup" | meaning unchanged |
| 30 | Never regroup before signoff; the address stays for the whole review | Never L761–763; §Closing step 5 | Never ("Run `design-close --words` — the regroup — **before** …"); §Closing step 2 | meaning unchanged |
| 31 | Regroup: pure, path kept (number included), idempotent | §Closing step 5 | §Closing step 2 (`design-close --words`) | meaning unchanged. Pane-specific lines retired (render hash, "if the pane does not re-index"). |
| 32 | Never build an unrequested mockup or ask on the operator's behalf | Never | Never (verbatim) | meaning unchanged |
| 33 | Never renumber a card | Never | Never (verbatim) | meaning unchanged |
| 34 | Verify in the manifest runtime everywhere, a mockup included; the sweep on real wiring; Aside, not a suite | Never | Never (verbatim) | meaning unchanged |
| 35 | Never fix a design gap silently; catalogue it on `## Operator Questions` | Never | Never (verbatim) | meaning unchanged |
| 36 | Never pre-plan past the design gate | Never | Never (verbatim) | meaning unchanged |
| 37 | Registration with the dashboard is the operator's | — (S1/S2 decisions) | §Mechanics *The dashboard hook is the operator's* | **new**, from S1's note and the drafter body |

## Decisions I made where the plan was silent

Also in `phase.md` `## Decisions`.

- **Read-back failures route to the drafter first.** A failing `design-check` or a thin `build-prompt.md` is re-dispatched once on the same open round with exactly the named points, because repairing its own output is not a new design decision. If the problem survives, the slice stops `pending` with those points. A question only the operator can settle goes to PENDING #1 as a decision, and the round cannot be signed as drafted while the build depends on it (the answer becomes feedback, and so a superseding round).
- **A revision handoff lists every card still carrying the slice's address.** `design-check`'s read-back half flags an addressed card left off the list and numbered before the list's last card (`design_expected_problems`). Because the new round inherits all of them, the handoff must name them all, re-drafted or not.
- **`design-init` is the orchestrator's; `design-register` is the operator's.** `design-open` refuses without `design.json`, and `design-init` writes an in-repo file. `design-register` writes outside the repo (S1's and S2's position), and no round waits on it: the card files open directly.
- **Commits:** `feat(design): <slice> round <NN-slug> drafted — …` (before PENDING #1), `feat(design): <slice> mockup — …` (mockup only), `feat(design): <slice> signoff — …`.

## Smoke pins (`tests/retrofit_smoke.sh`, Test 0, the design-cowork block)

- **Retired from the required list:** "Connect GitHub", "DesignSync is main-thread only", "the DesignSync work is never dispatched", "The mockup build is the one dispatched span".
- **New required pins (v47, P26.S3):**
  - "**The design subagent drafts, the operator decides.**"
  - "subagent_type: design-drafter"
  - "`new visual direction: yes` or `no`"
  - the `frontend-design` exception sentence
  - "**Never rest on the drafter's own `design_check` line.**"
  - "SIGNOFF is taken on the operator's **literal** words"
  - "`python3 scripts/workflow.py design-close <round> --superseded`"
  - `design-close <round> --words "<their literal words>"`
  - "**The mockup build is the one span dispatched to a slice executor:**"
  - "the round's lifecycle and the operator's words stay inline"
  - "### Importing a Claude Design bundle (optional)"
  - "**The workspace never requires a claude.ai account, and `DesignSync` is not used**"
  - "a design slice authorizes no `git push`"
- **New frontmatter check:**
  - `allowed-tools` has no `DesignSync` and keeps `Agent`;
  - `description` has no `: `, carries "the design subagent drafts, the operator decides" and the unchanged trigger "Use when a phase or slice touches a design system, a redesign, mockups", and no longer says "Claude Design + the operator".
- **New `gone` pins:**
  - "DesignSync is main-thread only", "the DesignSync work is never dispatched", "Read back with the `DesignSync` tool"
  - "Connect GitHub", "_ds_manifest.json", "list_files", "finalize_plan", "write_files", "register_assets", "get_project", "/design-sync"
  - "Design System pane", "the cards appear in the pane", "Push the branch", "Claude Design reads the real repo itself"
- **Still pinned:** `@dsCard`, "Claude Design" (the import subsection), "**You never design.**", "The operator's return closes the round.", every v32–v44 governance pin, and S1's contract pins.
- **Left for S4** (they still pass, because S4 has not touched those files): the do-* list's "never dispatched", "DesignSync" and "mockup build is the one dispatched span" (L108, L113); the executor-body pin "never dispatched, because you have no `DesignSync`" (L363); the CLAUDE.md list's "Claude Design", "DesignSync", "never dispatched", "*DesignSync* work is never dispatched" and "mockup build is its one dispatched span" (L475, L482); and Test 1's `grep -q 'Claude Design'` on `CLAUDE.workspace.md` (L610).

## Validation log

- `python3 installer/build.py` → `wrote bootstrap_agentic_workspace.sh (589555 bytes) from installer/ source`
- Test 0's Python block, extracted and run against the repo → exit 0 (a quick pre-check before the full suite).
- `bash tests/retrofit_smoke.sh` (the only command in its call, foreground, 600 s) → `ALL RETROFIT SMOKE TESTS PASSED`; I counted 195 PASS lines (Test 0: 1, T1: 22, T2: 3, T3: 3, T4: 6, T5: 84, T6: 32, T7: 1, T8: 3, T9: 7, T10: 6, T11: 3, T12: 19, T13: 5).
- `python3 installer/build.py --check` → `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`
- `python3 scripts/workflow.py validate` → `Workflow validation passed.` (it warns about 7 oversized doc sections, which predate this slice)
- The frontmatter could not be parsed with PyYAML (not installed). The description was checked by hand and by the new smoke assertion: no `: `, no ` #`, and it does not start with a quote.

## Notebook edits (`phase.md`)

- `## Decisions`: the loop's shape and the three judgment calls, which replace the consumed DECOMP section-map line.
- `## Doc impact`: three lines appended (operations, decisions, qa).
- `## Notes for later slices`: consumed the three S3 notes (DECOMP, S1, S2). Added one note for S4 with the exact wording and stop/commit counts to mirror, plus the smoke pins it must move.
- `## Now`: rewritten.
