# Plan — P15.REVIEW: phase re-review (round 2)

The first review returned `changes_requested` with one finding. `P15.F1` has landed and is
committed. This round verifies that fix, re-confirms the phase still holds together, and — on a
pass — consolidates the durable docs.

**Your round-1 `result.md` is still in this folder. Do not discard it — extend it.** Append a
round-2 section rather than rewriting the round-1 record; the earlier finding and the reasoning
behind it are part of the phase's history.

## 1. Verify finding 1 is actually resolved

`P15.F1` deleted the `pending` design exception from `CLAUDE.md` (option A), corrected the v31
CHANGELOG bullet in place, and replaced the smoke assertion that pinned the deleted wording with
a positive assert plus mutation-checked negatives.

Check, don't assume:

- The exception is gone from `CLAUDE.md` and the bullet reads as one continuous rule.
- The contract and both skill bodies now **agree** — `CLAUDE.md`'s `pending` rule versus
  `do-next-slice`/`do-whole-phase`'s *"Resume only after the operator clears `pending`."* That
  agreement was the substance of the finding, not the deletion itself.
- The v31 CHANGELOG section is accurate about what shipped, and was corrected **in place** (same
  version, same date) rather than superseded.
- Run the new smoke assertions' mutation check yourself: reintroducing the exception must fail
  the test.
- Nothing anywhere still asserts the deleted rule.

## 2. Re-run the phase gates

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh` — expected 115 PASS / 0 FAIL
- `python3 scripts/workflow.py sync-agents --check`
- **Execute the artifact again** — the build gate only `compile()`s. A fresh install (confirm
  workspace version 31, Codex-free root, installed `CLAUDE.md` byte-identical to the repo's) is
  the minimum. You verified retrofit and `--update` thoroughly in round 1 against a real pre-v31
  install; re-run them only if anything in `installer/` changed since, which it should not have
  — confirm that with `git diff --stat` over `P15.F1`'s commit rather than assuming.

## 3. Re-confirm the boundary and the judgment calls

- The out-of-scope boundary from `intent.md` must still hold: no P13/P14, no `docs/versions/**`,
  no `docs/current/**`, and `CHANGELOG.md` still append-only **except** F1's in-place correction
  of the unshipped v31 section, which is intended.
- Judgment calls 2 and 3 (`AGENTS.workspace.md` flagging; the vendored `explain/SKILL.md` edit)
  were upheld in round 1 and are unchanged. No need to re-litigate.

## 4. Doc consolidation — on a pass, and only on a pass

**Read the Doc impact list in `phase.md` carefully — it contains a retraction.** `P15.F1`
retracted item (a) of `P15.S3`'s `operations` line: the claim that the `pending` design
exception "is now harness-general" is the **opposite** of shipped truth. Do not consolidate the
withdrawn claim. The `operations` version must instead record that the Codex-only inline-resume
carve-out was removed along with Codex, and that the `pending` gate is uniform — resuming only
after explicit operator input. Item (b) of that line (the `update-workspace` pre-v31 migration
step) stands.

Round 1 also appended two corrections to that list: `docs/current/architecture.md` has a third
stale line at **L58** (`it has no .agents/skills/<name>/ mirror`) beyond the recorded L23/L35,
and an explicit note that the list was still outstanding.

Then, for each of the three affected docs:

```
python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source P15.REVIEW
```

- **`architecture`** — one contract (`CLAUDE.md`, no `AGENTS.md` twin), one set of entry points
  (`.claude/`), and the single-harness distributable (the artifact embeds `.claude/**` only, no
  parity or byte-equality assertions). Fold S2's and S3's lines together; fix all three stale
  lines including L58.
- **`operations`** — the largest: the executor-tier config story, the install/retrofit/update
  contract (a repo's own `AGENTS.md` untouched; the v31 stale-flagging migration that never
  deletes), and the corrected `pending`-gate truth above.
- **`decisions`** — **append one new accepted decision**, "drop Codex support; ship Claude Code
  only", with the rationale (the dual-harness parity tax) and the migration mechanism
  (`OBSOLETE_MACHINERY` flagging, workspace v31). **Do not rewrite the 33 historical entries** —
  P13 and P14 remain accepted history this decision supersedes.

Note that `P15.S5`'s Doc impact line concerns the **shipped seed payload**
(`installer/payloads/doc_bodies/*.md`), not this repo's own `docs/current/` — do not
double-count it.

Never patch an existing file under `docs/versions/`; never hand-edit `docs/current/*.md`. Finish
with `python3 scripts/workflow.py rebuild-docs`, then `validate`, and confirm the regenerated
snapshots carry the new truth.

## 5. Close the open questions

State which of `phase.md`'s open questions are resolved and which carry forward. `D2` (the
`slice-executor-mid` co-work refusal gap) and `D3` (making `build.py` smoke-execute the
artifact) are already filed as deferred jobs — confirm nothing else needs filing.

## Boundaries

- Do **not** commit and do **not** transition slice or phase status — the orchestrator runs
  `review-phase`.
- Do **not** write a phase explainer. Return
  `explain: not written — run /explain for this phase`.
- Return a `review_verdict` of `pass`, `changes_requested`, or `blocked`. If it is not a pass,
  stop before consolidation and return numbered findings with proposed fix slices.
