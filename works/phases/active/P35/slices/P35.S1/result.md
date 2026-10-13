## Verdict

- status: done
- tier: mid
- model: haiku
- effort: high
- summary: Tightened do-whole-phase's idle-window prep to slice N+1 alone, never N+2 or later, in the two places that state the rule (the dispatch bullet and the "While executor N runs" bullet with its limits list) plus CLAUDE.md's "Idle-window prep" sentence. Rebuilt bootstrap_agentic_workspace.sh; `installer/build.py --check` reports no drift. No version bump, no docs edits, no commit.
- validation: `python3 installer/build.py` (wrote bootstrap_agentic_workspace.sh) PASS; `python3 installer/build.py --check` PASS (in sync); `grep -c "only N+1" .claude/skills/do-whole-phase/SKILL.md` = 1 PASS; `grep -c "one slice ahead, never two" .claude/skills/do-whole-phase/SKILL.md` = 1 PASS; `grep -c "N+1 alone" CLAUDE.md` = 1 PASS; `python3 scripts/workflow.py validate` PASS (exit 0; warnings are pre-existing consolidation-debt and stale-doc notices for P32-P34, not from this slice). `tests/retrofit_smoke.sh` deliberately not run (plan: wording only, the phase review runs the suite).
- deviations: none
- files_changed: .claude/skills/do-whole-phase/SKILL.md, CLAUDE.md, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P35/phase.md, works/phases/active/P35/slices/P35.S1/result.md
- doc_impact: operations.md: the idle-window preparation section (l.1597-1670) says slice N+1 only, never N+2 or later, even when a later slice looks independent (P35.S1) — appended to phase.md `## Doc impact`

## Log

### Edits made (exact, per plan.md's Edits 1-5)

1. `.claude/skills/do-whole-phase/SKILL.md` dispatch bullet (l.19): the bolded phrase now reads `**except the optional read-only preparation for slice N+1 — the next slice only — described in the next bullet**`. Nothing else on the line changed.
2. Same file, l.40: the lead bullet now reads `… prepare for slice N+1 — **and only N+1**, never N+2 or any slice after it (`do-whole-phase` only; `do-next-slice` never prefetches).`
3. Same file, l.41, "Limits on whatever you choose": the new limit `**one slice ahead, never two** — prepare slice N+1 alone, never N+2 or any later slice, even when a later slice looks independent of N and N+1: …` is inserted first, joined with `; ` to the existing "stay strictly **read-only**" clause. The later "nothing is carried on into the slice after next" wording was left in place as instructed.
4. `CLAUDE.md:15`, last sentence of "Orchestrator and executor": `Idle-window prep (`do-whole-phase` only) covers slice N+1 alone, never N+2 or later, and stays read-only.`
5. Rebuild: `python3 installer/build.py` wrote the bootstrap; `--check` reported in sync.

Each replacement was applied by a script that asserted its old string occurred exactly once before replacing (all four passed the count check). The script was a throwaway in /tmp and was deleted after use.

### Scope check

`git diff --stat` shows the two wording files and the rebuilt bootstrap, plus the P35 folder. The P35 folder entries (`works/backlog.md`, `works/events.jsonl`, `works/index.json`, `works/state.json`, `phase.md`, `P35.S1/slice.json`) were already modified before this slice started (the orchestrator's state writes); this slice did not touch those state files beyond `phase.md`.

### phase.md edits

- `## Doc impact`: appended the operations.md idle-window line (after the existing decisions.md line).
- `## Notes for later slices`: removed the `(from P35.DECOMP, for P35.S1)` note, which this slice consumed. The S2 and S3 notes and the DECOMP2 note are untouched.
- `## Now`: rewritten (under 15 lines): S1 landed; next is P35.S2; then S3 and DECOMP2; gate required; no operator questions.
- `## Operator Questions`: none raised, nothing appended.
- The generated `## Slices` block was not edited.

### Not done (by design)

No version bump (`WORKSPACE_VERSION`, `CHANGELOG.md` untouched). No `docs/` edits. No commit. No workflow state transition. No `defer-job`. No Agent delegation (this slice ran on the cheap `haiku` route, so nothing was delegated).
