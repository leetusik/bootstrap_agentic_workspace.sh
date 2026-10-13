# P35.S1 — plan: do-whole-phase prepares slice N+1 only

## Context

On glide-ilab the P15 orchestrator prepared S2 **and** S3 while S1's executor ran. The `do-whole-phase` idle-window rule names "slice N+1" and says "nothing is carried on into the slice after next", but it never forbids preparing N+2 or later outright, and the session read past it. The operator chose "Enforce N+1 only" (`../../intent.md`, Clarifications). This slice changes wording only, in the two places that state the rule, and rebuilds the installer, which embeds both files. No engine code and no test (this is wording, verified by reading it).

## Edits (exactly these; keep each file's voice and density)

1. **`.claude/skills/do-whole-phase/SKILL.md` l.19**, the dispatch bullet. Replace the bolded phrase `**except the optional read-only preparation for the next slice described in the next bullet**` with `**except the optional read-only preparation for slice N+1 — the next slice only — described in the next bullet**`. Nothing else on that line changes.

2. **Same file, l.40**, the bullet that opens "While executor N runs you are idle on the main thread": make its first sentence say N+1 is the *only* slice the window may serve. Change `you *may* use that window to prepare for slice N+1 (`do-whole-phase` only; `do-next-slice` never prefetches).` to `you *may* use that window to prepare for slice N+1 — **and only N+1**, never N+2 or any slice after it (`do-whole-phase` only; `do-next-slice` never prefetches).`

3. **Same file, l.41**, the "**Limits on whatever you choose**" sub-bullet. Insert a new limit **first** in its list, before "stay strictly **read-only**":

   > **one slice ahead, never two** — prepare slice N+1 alone, never N+2 or any later slice, even when a later slice looks independent of N and N+1: plan N+1 reconciles against what N actually changed, and N+2's plan must in turn reconcile against what N+1 changes, which has not happened yet — preparing two ahead compounds that staleness and spends the window on work the next return can void;

   Join it to the existing list with the same punctuation the list already uses (semicolon-separated clauses). Leave the later "nothing is carried on into the slice after next" clause in place (it covers carrying N+1's notes forward, a different point).

4. **`CLAUDE.md:15`**, the last sentence of the "Orchestrator and executor" paragraph. Change `Idle-window prep (`do-whole-phase` only) stays read-only.` to `Idle-window prep (`do-whole-phase` only) covers slice N+1 alone, never N+2 or later, and stays read-only.`

5. **Rebuild:** run `python3 installer/build.py`, then `python3 installer/build.py --check`, which must report no drift. Both edited files are embedded (every `SKILL.md`, and the `CLAUDE.md` body). **No version bump**: P35 ships one release later, in DECOMP2's cut.

## phase.md edits

- Append to `## Doc impact`: `- operations.md: the idle-window preparation section (l.1597-1670) says slice N+1 only, never N+2 or later, even when a later slice looks independent (P35.S1)`
- Rewrite `## Now` (at most 15 lines): S1 landed; next is **P35.S2** (research: paired worktrees for a nested install), whose Note is in `## Notes for later slices`; the gate is required; there are no operator questions.

## Verification

- `grep -n "only N+1" .claude/skills/do-whole-phase/SKILL.md` and `grep -n "one slice ahead, never two" .claude/skills/do-whole-phase/SKILL.md` each hit once; `grep -n "N+1 alone" CLAUDE.md` hits once.
- `git diff --stat` shows only `.claude/skills/do-whole-phase/SKILL.md`, `CLAUDE.md`, `bootstrap_agentic_workspace.sh` and the P35 folder.
- `python3 installer/build.py --check` reports no drift.
- `python3 scripts/workflow.py validate` passes.
- Do **not** run `tests/retrofit_smoke.sh`: this is wording, and the phase review runs the suite.

## Must not

Change any other line of either file, edit `docs/` (a docs phase pays the note), bump `WORKSPACE_VERSION` or `CHANGELOG.md`, commit, or move workflow state.

## Dispatch

route=cheap
reason=kind docs rated low
tier=mid
subagent_type=slice-executor-mid
model=haiku
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Haiku 5.5
explore_model=haiku
explore_effort=high
