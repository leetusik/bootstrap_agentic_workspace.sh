# Plan — P22.REVIEW: phase review of P22

## Job

Review phase P22 ("make doc staleness explicit and right-size the notebook and test guardrails") as a whole against its objective and `works/phases/active/P22/intent.md`, and return a verdict. The phase's acceptance gate is **waived** (`phase.json`: machinery and doctrine only, no operator-visible running product), so no walkthrough and no browser stages — this is a machinery/doctrine review.

Read first: `works/phases/active/P22/phase.md` (its three REVIEW-addressed notes were written for you), `intent.md`, and each slice's `result.md` (`P22.DECOMP`, `P22.S1`, `P22.S2`).

## Validate all slices together

Run and record outcomes:
- `python3 scripts/workflow.py validate` — must exit 0; expected advisory warnings, none of them defects: `consolidation_owed=P21`, `stale_docs=architecture, decisions, operations, qa` (P21's debt, visible by design), `oversized_doc_sections=5`.
- `bash tests/retrofit_smoke.sh` — expect 158 PASS, exit 0.
- `python3 installer/build.py --check` — artifact in sync.
- `python3 scripts/workflow.py sync-agents --check` — clean.
- Live spot-checks of the phase's headline claims, not just the slices' reports: `python3 scripts/workflow.py docs` shows the last-updated marker under every doc and STALE flags on the four P21-outrun docs; the budget behavior — `finish-slice`-style size print / `validate` byte-only judgment — is verifiable by inspection of `scripts/workflow.py` (`PHASE_MD_BUDGET = 400 * 1024`) and the smoke suite's probes; `CLAUDE.md` carries the core-only keep-tests-small rule, the ~100k-token budget wording, and the staleness doctrine; the two `.claude/agents/slice-executor-*.md` bodies are byte-identical where required.

## Judge

- Objective coverage: D14 (marker recorded at write time + surfaced in `docs`/`validate` + doctrine; no cadence knob, `CONSOLIDATION_DEBT_MIN_PHASES` still 1), D15 (soft 400 KB byte-only warning-only cap, size printout kept, all prose restatements updated), D16 (core-only rule at its single machinery site). Scope boundary respected: no `doc-new-version` run by any slice, P21's debt untouched.
- Cross-check the notebook against every `result.md`: no dropped decision, no unrouted operator question (the section currently records "none" — verify no result.md raised one that the notebook missed).
- **Verify the `## Doc impact` list is complete** (pass-only duty): S1's three notes + S2's four notes must cover every durable-truth change the phase made; an incomplete list is a finding. Return `doc_versions: none — deferred to a docs phase`.
- Review the three delegated judgment calls S2 recorded (no sha backfill; separate `validate` line; verbatim frontmatter as the header) for soundness — they were sanctioned by the plan, so judge the reasoning, not the delegation.

## Return

Complete validation and judgment fully before returning — on a non-pass, stop before pass-only steps and return the whole picture at once: numbered findings + proposed fix slices. Write `works/phases/active/P22/slices/P22.REVIEW/result.md` verdict-block-first, edit `phase.md` (rewrite `## Now` as the phase's closing state). Return:
- review_verdict: pass | changes_requested | blocked
- explain: not written — run /explain for this phase
- summary, files_changed, validation, findings (if any), and any deferred jobs I should file.

You never commit and never run state transitions (`review-phase`, `accept-gate`, `drop-deferred` are the orchestrator's). This is the upstream repo: if you edit any machinery file (you should not need to), the installer rebuild rule applies.
