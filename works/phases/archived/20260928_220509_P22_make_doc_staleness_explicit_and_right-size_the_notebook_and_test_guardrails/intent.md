# Intent — P22

- Captured at: 2026-09-02T00:00:00+09:00
- Origin: operator

## Original Input (verbatim)

> d14: no fixed cadence. just when user wants it. should explicit last updated commit on docs or docs management json. so that orchestrator or executor not to just believe stale docs.
> d15: relaxed note book budget. just make it not to tremendus. well, maybe gives soft token limit. maybe 100k would enough.
> d16: test very very small. do test only for no function no service features.

(Clarification answers, verbatim: D15 budget = "100k tokens soft cap"; D16 = "I meant only test for very core stuff. not like style stuff"; routing = "One phase now".)

## Confirmed Intent (refined + clarified)

One phase implementing the three operator decisions that P21's review routed as deferred jobs D14/D15/D16:

1. **D14 — doc staleness made explicit; no cadence.** Docs phases run only when the operator wants one — no target cadence, no threshold tuning. In exchange, staleness must be visible where docs are read: every durable doc carries an explicit last-updated marker — source commit, date, and the consolidating phase — recorded in `docs/index.json` (the docs management json) and surfaced wherever agents read docs (the `workflow.py docs` listing; and/or a generated header on `docs/current/*.md`). Doctrine: an orchestrator or executor must treat a doc whose last update predates the owed `## Doc impact` notes as stale evidence to be checked against the notes, never as current truth.
2. **D15 — notebook budget relaxed to a soft ~100k-token cap.** Replace the 16 KB / 200-line ceiling with a generous warning-only sanity cap of about 100k tokens (~400 KB of text); the point is to stop the squeeze (four P21 slices had to compress unrelated content to land) while still catching runaway growth. Keep the `finish-slice` size printout so growth stays visible. Warning-only, never an error — unchanged.
3. **D16 — keep-tests-small sharpened to core-only.** Test files are written only for very core behavior (the logic the product cannot afford to break); never for style/cosmetic/trivial surface — those are verified live (running the product, smoke checks, the real-browser sweep). Tests stay very small.

**Scope boundary:** machinery and doctrine in this repo only; adopters inherit via the bootstrap upgrade. This phase is NOT the docs phase — P21's `consolidation_owed` debt stays open until the operator asks for one (that is D14 working as intended). On a passing review, D14/D15/D16 are closed (dropped with reason "resolved by P22" or promoted into its slices — DECOMP's call).

## Clarifications Resolved

- Q: D15's "100k" — tokens or bytes, and how hard? — A: **100k tokens, soft cap** (warning-only).
- Q: D16's meaning? — A: **Only test very core stuff, not style stuff** (tests for core behavior only; style/cosmetic/trivial verified live).
- Q: One phase or record-only? — A: **One phase now.**

## Notes

- Source material: `works/deferred/open/D14/`, `D15/`, `D16/` (filed by P21.REVIEW) and `works/phases/active/P21/slices/P21.S1/result.md` (§3.2 notebook budget, §7 tests) for the measured evidence behind each decision.
- D15 interacts with P21's S3/S5 advisory-warning pattern: reuse the shared-line style; `PHASE_MD_BUDGET` is the constant to change.
- Workspace version: v38 shipped by P21; this phase opens v39 (or appends, per the CHANGELOG convention at its time of execution).
