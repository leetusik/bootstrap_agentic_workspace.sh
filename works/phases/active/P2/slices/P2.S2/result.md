# Result

- Phase ID: P2
- Slice ID: P2.S2
- Slice: Skills: rotate-backlog skill + archive-phase repositioning
- Review status: pending
- Next action: execute P2.S3 (contract)

## Outcome

Added a first-class `rotate-backlog` skill, repositioned `archive-phase` as one of three first-class archive options, and updated the archiving guidance in `do-next-slice`, `do-whole-phase`, and `review-phase` — in both the live `.claude`/`.agents` skill files and the bootstrap `COMMAND_SKILLS` source.

- New `rotate-backlog` skill (3 live files: `.claude/skills/rotate-backlog/SKILL.md`, `.agents/skills/rotate-backlog/SKILL.md`, `.agents/skills/rotate-backlog/agents/openai.yaml`) + a `COMMAND_SKILLS` entry placed with the archive ops. `disable-model-invocation: true` (explicit-invocation only, like the other workflow command-skills).
- `archive-phase` skill rewritten: drops "escape hatch" framing; now presents archive-all (full sweep) / rotate-backlog (partial) / archive-phase (single) as three first-class options gated by the same review-passed rule. Updated its `desc` (SKILL.md frontmatter + `.agents` openai.yaml).
- `do-next-slice`, `do-whole-phase`, `review-phase`: archiving lines now state archiving is a separate manual step and list `rotate-backlog`/`archive-phase` alongside `archive-all`.

## Deviations from Plan

- Implementation method: rather than hand-edit each live file, I edited the bootstrap `COMMAND_SKILLS` (the canonical generator) and regenerated the live skill files by bootstrapping into a temp dir and copying the skills trees over. The resulting git diff is identical to hand-editing (git diffs content, not method) but with zero drift risk. An independent fresh-bootstrap `diff -rq` then confirms live == bootstrap output.

## Validation Run

- Fresh bootstrap into a temp dir — exit 0 (internal `rebuild`+`validate` passed).
- `diff -rq .claude/skills <tmp>/.claude/skills` and `.agents/skills` — both IDENTICAL (live == bootstrap-generated; no drift).
- `diff -q <tmp>/scripts/workflow.py scripts/workflow.py` — IDENTICAL (S1 embed invariant still holds).
- `git status` showed exactly the expected files changed (archive-phase + openai.yaml, do-next-slice, do-whole-phase, review-phase in both trees; new rotate-backlog dirs) — no collateral changes.
- `python3 scripts/workflow.py validate` (real repo) — passed.

## Files Changed

- New: `.claude/skills/rotate-backlog/SKILL.md`, `.agents/skills/rotate-backlog/SKILL.md`, `.agents/skills/rotate-backlog/agents/openai.yaml`.
- Modified live skills: `.claude` + `.agents` SKILL.md for `archive-phase`, `do-next-slice`, `do-whole-phase`, `review-phase`; `.agents/skills/archive-phase/agents/openai.yaml`.
- `bootstrap_agentic_workspace.sh` — `COMMAND_SKILLS`: new rotate-backlog entry; reworded archive-phase/do-next-slice/do-whole-phase/review-phase.
- `works/phases/active/P2/slices/P2.S2/{plan,result}.md`.

## Doc Versions Created

- None (decision doc is P2.S4).

## Roadmap Updates

- None.

## Retrospective

- The "edit the bootstrap generator, then regenerate live artifacts from it" workflow is the cleanest way to keep generated files in sync with their source. The same temp-bootstrap `diff -rq` is the standing invariant check for any skill/contract change — reuse it in S3 for `CLAUDE.md`/`AGENTS.md`.
- `archive-phase` skill name now covers all three archive ops; that's intentional (it is the "archiving" skill). The `rotate-backlog` skill is a thin, focused entry point for the partial sweep.
