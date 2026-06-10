# Plan

- Phase ID: P3
- Slice ID: P3.S3
- Slice: retrofit skill dual-applied
- Created at: 2026-06-10T14:04:40+09:00

## Goal

Deliver the `retrofit` Agent Skill, mirrored for Claude Code and Codex,
explicit-invocation only, that drives an agent through the `--into-existing`
adoption — and keep the live files in sync with the bootstrap-embedded
`COMMAND_SKILLS` (dual-apply).

## Scope

- Add a `retrofit` entry to `COMMAND_SKILLS` in `bootstrap_agentic_workspace.sh`
  (name, desc, tools, body). Membership in `MANAGED_DIRS`/`MANAGED_FILES` is
  auto-derived from `COMMAND_SKILLS` (the emit loop), so no manual `MANAGED_*` edit.
- Generate the 3 live files by running a fresh bootstrap into a temp dir and
  copying its `retrofit` outputs — guarantees byte-identical dual-apply:
  `.claude/skills/retrofit/SKILL.md`, `.agents/skills/retrofit/SKILL.md`,
  `.agents/skills/retrofit/agents/openai.yaml`.
- Skill body: preflight (git repo? clean tree? already a workspace? locate the
  installer; synthesize phase name/objective from project state) → run installer
  `--into-existing` → reconcile contract sidecar → validate/next → report
  (no auto-commit).
- README: correct the skill count (stale "10" → 12) and add `rotate-backlog`
  (pre-existing omission) + `retrofit` rows.
- Out of scope: the committed smoke test (S4). No `scripts/workflow.py` change.
  No `.claude/settings.json` change (general Bash/git intentionally prompt, as
  for the `commit` skill).

## Milestones

1. `retrofit` `COMMAND_SKILLS` entry; bootstrap still produces a valid workspace.
2. Generate + copy the 3 live files; explicit-invocation flags present.
3. Dual-apply check: live retrofit files == generated; existing skills unchanged.
4. README skill inventory corrected.

## Validation

- Fresh bootstrap (with the new entry) into a temp dir → exit 0 (its internal
  rebuild+validate passes), and emits `.claude/.agents` retrofit skill files.
- `diff` live retrofit files vs generated → MATCH (all 3).
- All other live skill `SKILL.md` files still match generated (no accidental drift).
- `python3 scripts/workflow.py validate` → passes.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None (decisions v0003 from S1 already records the skill as a deliverable).
