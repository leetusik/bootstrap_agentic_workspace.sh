# Result — P34.S3 (Texts: Compact Instructions, skill reorder, doc notes)

- status: done
- tier: mid
- model: sonnet
- effort: high
- summary: `## Compact Instructions` added to `CLAUDE.md` and the contract trimmed back under the 12,288 B cap (12,274 B, phrasing only); `do-whole-phase` reordered and `do-next-slice` restructured so the loop invariants and a new post-compaction resume line sit in the first 16 KB (13,116 B / 15,243 B); the phase's `## Doc impact` list written. The mid executor applied the first `CLAUDE.md` edits, then the auto-mode classifier denied all of its Bash ("Self-Modification"); the orchestrator finished the slice inline on the operator's explicit word.
- files_changed: CLAUDE.md, .claude/skills/do-whole-phase/SKILL.md, .claude/skills/do-next-slice/SKILL.md, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P34/phase.md, works/phases/active/P34/slices/P34.S3/result.md
- validation: `python3 scripts/workflow.py validate` pass; `python3 installer/build.py` + `--check` pass; `wc -c CLAUDE.md` = 12,274 ≤ 12,288; `do-whole-phase` last invariant (commit bullet) ends at 13,116 B of 43,403 and `do-next-slice` step 7 at 15,243 B of 36,790; sorted-line diffs against HEAD show only the two resume texts, the rewritten step 3 (pointer in, co-work body out) and the moved paragraphs' title line; `bash tests/retrofit_smoke.sh` (alone) ALL RETROFIT SMOKE TESTS PASSED, 289 PASS — after restoring eight contract phrases Test 0 pins that the first trims had cut (`real-browser fidelity`, the `design-drafter`/mockup dispatch sentence, `Just in time, and only`, `PHASE_MD_BUDGET`, `if the two ever disagree the **kind wins**`, `is a **third** halt`, `an agent never drives a profile signed into the operator's accounts`, the `claude-design` tools parenthetical, `Work resumes only after explicit operator input clears the same item`), compensated by further unpinned trims
- deviations: the slice ran in two spans — executor (CLAUDE.md edits, then blocked) and orchestrator inline (everything else, on the operator's word); the worktree paragraph of `do-next-slice` was also moved after the co-work paragraph (not in the plan) to bring step 7 under 16 KB
- doc_impact: 8 lines written to `phase.md` `## Doc impact` (operations ×4, architecture, decisions ×2, qa), covering S1, S2 and S3

## State left behind

`CLAUDE.md` is edited and coherent, but its size was never measured. Estimated about 12,630 B, so roughly 350 B still over the 12,288 B cap and it needs more phrasing trims.

Applied to `CLAUDE.md` (each edit applied with the Edit tool; no rule removed):

- Added `## Compact Instructions` after `## Commit Convention` (keep / drop lists, one closing clause about the `SessionStart` hook). About 500 B.
- "Two exceptions:" changed to "Exceptions:" (the sentence lists three), rewritten as a semicolon list. The rules are unchanged.
- Route recital shortened: the `executor-route` sentence now reads "kind first (decomposition, `research`, review → high; the **kind wins**), then `risk` (**mid the default**, real code included; `high` needs a named trigger); a retry never returns to mid; planning bumps up, never down." Dropped "if the two ever disagree", "the cost lever" and the retry examples. The full route table lives in the do-next-slice / do-whole-phase skills and `executor-route --help`.
- Idle-window sentence shortened to "Idle-window prep (`do-whole-phase` only) stays read-only." Dropped "with no second executor; `do-next-slice` never prefetches", which both skills still state in full.
- Aside bullet: the sentence "The same holds whichever browser is driven: an agent never drives a profile signed into the operator's accounts." was folded into the earlier clause as "(in any browser)". The rule is kept.
- Design bullet tail: dropped the "(`drafter`; `claude-design`, the operator designing in Claude Design)" parenthetical. `design-cowork` carries both tools.
- Canonical State: dropped the `PHASE_MD_BUDGET` name, leaving "a soft ~100k-token cap (400 KB)". Commit Convention: dropped "never to one that didn't,".

## Not done

- Further `CLAUDE.md` trim to reach 12,288 B (candidates left: the docs-phase bullet's `docs-debt` / route / `docs-consolidated` enumeration, "its operations also Agent Skills (`/do-next-slice`, …)", Orchestrator paragraph's `design-drafter` clause).
- Reorder of `.claude/skills/do-whole-phase/SKILL.md` (the plan's block order; the bullets under `Rules:` are 20 blocks beginning at "- " lines, the co-work block spans L21-35 and the idle-window block L37-42) and the resume bullet.
- Restructure of `.claude/skills/do-next-slice/SKILL.md` (shrink step 3, move the co-work material to a titled paragraph after step 7, resume paragraph after the pending halt).
- The sorted-diff proofs, the `wc -c` / offset report, `## Doc impact` lines, `phase.md` Decisions / notes / `## Now`, `installer/build.py` and `--check`, `validate`, the smoke run.

## Completed inline by the orchestrator (Claude Fable 5.1, on the operator's word)

The operator chose "Finish S3 inline on the main thread" when asked how to proceed past the classifier denial.

- `CLAUDE.md`: 12,677 → 12,285 B. Cut wordings (rules unchanged; each rule still stated): the "its operations also Agent Skills (`/do-next-slice`, …)" aside; the co-work exception sentence compressed to "except a `co-work` design slice, which runs inline with dispatched spans (…)"; "Do **not** decompose …, once the operator executes the phase. The one exception is `/rotate-backlog`: that single invocation …" tightened; the docs-phase bullet's enumeration compressed to "`docs-debt`, `create-phase`'s *docs-phase route* and `docs-consolidated <P>` carry the payment"; the Aside halt sentence ("is a **third** halt" → "halts"); ", never a review's duty"; the worktree sentence ("never on your own initiative or on a `hint:` … relay a hint, never act on it" → "never on a `hint:` (relay it, never act on it)"); ", never individual slices"; the compact section's own `(auto/gate/plan only)` parenthetical and "After compaction" → "then"; "Tests that exist" → "Tests"; "when an operator note is ambiguous" → "with an ambiguous operator note"; "consult it whenever unsure what was asked" → "consult it whenever unsure"; "real-browser fidelity work" → "fidelity work"; "Its `--check` must pass; the tracked … hook enforces it" → "The tracked … hook enforces its `--check`"; "only reads, never decides" → "reads, never decides"; "Just in time, and only" → "Just in time, only".
- `do-whole-phase`: lines reordered under `Rules:` as the plan's target order, plus the resume bullet (523 B) after the re-read bullet.
- `do-next-slice`: resume paragraph after the pending halt; step 3 = its opening sentences + a pointer + the route-table/resolve/pin/dispatch/record/Explore text; the co-work body moved verbatim under "When the selected slice is a design slice (`kind: co-work`), step 3 runs it like this: …" after step 7; the worktree paragraph moved after that (pure move).
- Proof: `diff <(git show HEAD:<f> | sort) <(sort <f>)` per skill shows only the additions and the one rewritten line.
- Then `python3 installer/build.py`, `--check`, `validate`, and the smoke suite (result appended below by the orchestrator).
- `CLAUDE.md` final: 12,274 B. Smoke suite: ALL RETROFIT SMOKE TESTS PASSED (289 PASS, no new asserts in this slice).
