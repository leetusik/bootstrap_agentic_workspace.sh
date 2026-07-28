# Result — P7.DECOMP: decompose "Retire embedded /explain"

## What I did

Decomposed phase P7 into a single middle slice and seeded `phase.md` (Decomposition, Findings & Notes, Constraints, Doc impact). Verified the plan's researched removal footprint against the live repo, decided the `--update`/stale behavior, and pulled the exact knowledge-plugin install pointer from the knowledge repo. No source/installer/README/CHANGELOG files were modified — this slice only decomposes.

## Slice created

- **`P7.S1` — "Remove explain from the distribution"** — kind `implementation`, risk `medium`, order `10` (bare folder: `slice.json` only, no `plan.md` pre-filled). Slots between `P7.DECOMP` (order 0) and `P7.REVIEW` (order 9999).

Rationale (full version in `phase.md` › Decomposition): the removal is atomic — skill deletions + installer optional-skill-mechanism removal + `WORKSPACE_VERSION` 14→15 + CHANGELOG v15 + README.en.md + smoke-test edit + the rebuilt `bootstrap_agentic_workspace.sh` must all land in one commit (the same-commit rebuild rule can't be split, and any split leaves a lying intermediate state). Risk `medium` because the installer surgery is judgment work (rule out `low`, a literal plan-follower) but fully researched with decisions pre-made (rule out `high`).

## Footprint verification (vs. plan)

Confirmed all sites the plan listed. Corrections/clarifications recorded in `phase.md`:
- `installer/wrapper.sh`: lines 16, 52, 65, 90 — exact.
- `installer/main.py`: `WORKSPACE_VERSION = 14` at line 38; the full optional-skill mechanism at lines 60–68. `flag_stale_skills` (538–563) and `OBSOLETE_MACHINERY` (523–529) need NO edits.
- `tests/retrofit_smoke.sh`: keep 173–174; Test 8 to be replaced runs **209–222** (includes the dual-apply diff loop), not 209–218 as the plan hinted.
- `README.en.md`: the prose mention is at **171–172** (not just 172); skill *counts* ("14 core Agent Skills", "15 Agent Skills" @ line 253) drop by one and need recounting.
- Root `README.md` (Korean): no explain-feature mention (line 134 is just the prose word "explains"); leave it.

## `--update` / stale decision (recorded in phase.md)

Rely on the generic `flag_stale_skills`: on `--update`, an installed `.agents/skills/explain` (has the `openai.yaml` marker) is flagged stale; `.claude/skills/explain` (no `disable-model-invocation: true` marker) is treated as operator-owned and left untouched. Never deletes. CHANGELOG Migration notes must instruct manual removal + plugin install.

## Knowledge-plugin install pointer (verified, not invented)

From `~/projects/personal/knowledge` (`.claude-plugin/marketplace.json`, `plugin/.claude-plugin/plugin.json` v0.2.1, `README.md` 16–20):

    /plugin marketplace add leetusik/knowledge
    /plugin install knowledge@knowledge

Then `/knowledge:setup` once; use via `/knowledge:explain <topic>`. Namespace changed from bare `/explain` to `/knowledge:explain`.

## Deferred D1

Resolved by the deletion. The **orchestrator** runs `drop-deferred D1` after S1 lands — noted in `phase.md`; this slice ran no deferred commands.

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | **passed** ("Workflow validation passed.") |

Verified `P7.S1` is a bare folder (only `slice.json`, no `plan.md`).

## Doc impact

None from this slice (decomposition changes no durable truth). A `## Doc impact` running list was seeded in `phase.md` for S1 to append to and REVIEW to consolidate (expected: supersede operations v0010/v0011; new decisions entry retiring embedded explain for the knowledge plugin).

## Deviations from plan.md

None. Followed the plan's suggested single-slice breakdown; recorded the line-hint corrections above as findings rather than deviations.
