# Plan

- Phase ID: P2
- Slice ID: P2.S2
- Slice: Skills: rotate-backlog skill + archive-phase repositioning
- Created at: 2026-06-10T12:51:40+09:00

## Goal

Add a first-class `rotate-backlog` skill, reposition the `archive-phase` skill as one of three first-class archive options, and update the archiving guidance in `do-next-slice`, `do-whole-phase`, and `review-phase` — in BOTH the live `.claude`/`.agents` skill files AND the bootstrap `COMMAND_SKILLS` source they are generated from.

## Scope

Per the embed-site map + canonical strings in `phase.md`:

- New `rotate-backlog` skill: live `.claude/skills/rotate-backlog/SKILL.md`, `.agents/skills/rotate-backlog/SKILL.md`, `.agents/skills/rotate-backlog/agents/openai.yaml`, plus a `COMMAND_SKILLS` entry in the bootstrap (placed with the archive ops).
- Rewrite the `archive-phase` skill body + desc: three first-class options (archive-all / rotate-backlog / archive-phase), drop "escape hatch" framing. Apply to both live files + bootstrap body/desc.
- `do-next-slice`, `do-whole-phase`, `review-phase`: update the archiving lines to note archiving is manual and that `rotate-backlog`/`archive-phase` exist for partial archiving. Apply to both live files + bootstrap bodies.

Out of scope: workflow.py (done in S1), CLAUDE.md/AGENTS.md (S3), decisions doc (S4).

## Milestones

1. Edit bootstrap `COMMAND_SKILLS`: add rotate-backlog entry; update archive-phase (desc+body), do-next-slice, do-whole-phase, review-phase bodies.
2. Apply the identical body changes to the live `.claude` + `.agents` SKILL.md files; create the 3 new live rotate-backlog files.
3. Verify: bootstrap into a temp dir, `diff -rq` live `.claude/skills` and `.agents/skills` against the fresh output → identical; `validate` passes.

## Validation

- `diff -rq .claude/skills <tmp>/.claude/skills` and `.agents/skills` — identical (proves live == bootstrap-generated).
- Fresh bootstrap exit 0 (its internal validate passes).
- `python3 scripts/workflow.py validate` (real repo) — passes.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None in this slice. Decision doc is P2.S4.
