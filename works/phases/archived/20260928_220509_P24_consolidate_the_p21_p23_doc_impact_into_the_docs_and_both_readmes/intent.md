# Intent — P24

- Captured at: 2026-09-28T16:57:32+09:00
- Origin: operator

## Original Input (verbatim)

> /create-phase for the doc consolidation include readme.md.

## Confirmed Intent (refined + clarified)

Run the docs phase for the consolidation debt and include the READMEs in it:

1. **Pay the recorded debt.** Turn every `## Doc impact` note from P21, P22 and P23 into
   new versions of the four durable docs they touch: `architecture`, `decisions`,
   `operations` and `qa`. When all notes for a phase are in, record
   `docs-consolidated <P>` for that phase (P21, P22 and P23).
2. **Bring both READMEs up to date.** `README.md` (Korean) and `README.en.md` (English) get
   the same user-facing changes, so they stay in step. Neither is a versioned doc (there is
   nothing under `docs/versions/` for them), so they're edited directly and never go
   through `doc-new-version`.

Scope at confirmation, from `python3 scripts/workflow.py docs-debt` (2026-09-28):
`docs_debt=P21, P22, P23 (3 phase(s), 29 note(s), 4 doc(s))`

- architecture: 6 notes from P21, P22, P23
- decisions: 7 notes from P21, P22, P23
- operations: 8 notes from P21, P22, P23
- qa: 9 notes from P21, P22, P23
- (unassigned): 2 notes, from P21.REVIEW and P22.REVIEW. Each is the review's line
  "Verified at `P<N>.REVIEW`; no version created anywhere in P<N>". They have no doc
  content to consolidate; `DECOMP` confirms that when it reads them in the notebooks.

README drift seen at intake (a starting point only; the README slice checks both files
against all 29 notes):

- `README.en.md` lines 44–45 (*Review gates*) and 317–318 (the high-tier executor
  paragraph) still say the phase review *consolidates* the docs. Since P21 (v38) the review
  only checks the `## Doc impact` list and stamps the debt; the docs themselves are
  consolidated in a docs phase the operator creates.
- Neither README describes the docs-phase route beyond the worktree section: the
  `consolidation_owed=` line, `docs-debt`, the per-doc last-updated marker and the
  **STALE** flag (P22), or the 12 KB routing contract with `workflow.py --help` as the
  command reference (P23).

**What `DECOMP` will cut** (recorded here, not cut here): one `--kind docs` slice per doc,
since `doc-new-version` works per doc and each doc collects notes from several phases, so
each doc ends up with a single new version. That gives `architecture`, `decisions`,
`operations`, `qa`, plus one more `--kind docs` slice that edits `README.md` and
`README.en.md` together. Risk follows the normal rule. The README slice depends on the
doc slices, so the READMEs describe what the new versions say. Each doc slice runs
`doc-new-version --doc <doc> --summary "..." --source <P>.REVIEW`, edits only the
returned `edit_path`, then runs `rebuild-docs`. After the notes of P21, P22 and P23 are
all in, the orchestrator runs `docs-consolidated P21`, `docs-consolidated P22` and
`docs-consolidated P23`.

Everything runs on the **default stream**. Never ask for a worktree on this phase:
`doc-new-version` and `docs-consolidated` only work there. The phase adds **no
`## Doc impact` notes of its own**, since it pays other phases' notes and creates no new
durable truth. It changes no operator-visible product surface, so its acceptance gate is
normally waived (`accept-gate P24 --waive`) at the `DECOMP` boundary.

## Clarifications Resolved

- Q: `README.md` is the Korean README and `README.en.md` is its English twin. Should the
  phase update both, or only `README.md`? — A: Both READMEs (the recommended option). The
  operator's choice also confirmed the name and objective.

## Notes

- `docs/retrofit-guide.md` is not in the versioned doc set, and `docs-debt` names no note
  for it. It is out of scope unless the operator adds it.
