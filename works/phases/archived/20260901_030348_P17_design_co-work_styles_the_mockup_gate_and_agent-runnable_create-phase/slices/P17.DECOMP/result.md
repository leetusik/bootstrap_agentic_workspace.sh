# Result — P17.DECOMP

Decomposed P17 into **exactly three** middle slices as bare folders, and seeded `phase.md` with
the breakdown, findings, doc-impact expectations, and two operator questions.

## What was created

| Slice | Order | Kind | Risk | Depends on |
| --- | --- | --- | --- | --- |
| `P17.S1` — rewrite design-cowork: three styles, the mockup, one gate per round | 10 | implementation | high | — |
| `P17.S2` — propagate: SLICE_KINDS validation, create-phase, drivers, executor agents, contract | 20 | implementation | high | `P17.S1` |
| `P17.S3` — release workspace v34: version bump, CHANGELOG, installer rebuild | 30 | implementation | high | `P17.S2` |

Each folder holds `slice.json` only — **no `plan.md` was pre-filled** for any of them.

**All three rated `high`, deliberately.** The contract reserves `low` for a one-line/few-line code
edit or docs. S1 is a structural rewrite of the 334-line spec every later slice copies from; S2 is
engine code plus seven-plus files that must move together; S3 was the arguable one — its hand edits
are two — but it spans `installer/main.py`, `CHANGELOG.md` and a regenerated artifact, and the
changelog entry is what adopters read. None was rated `low` to save cost.

**Single pass, no `DECOMP2`, no `co-work` slice.** P17 rewrites the *documentation of* design
co-work and touches no product visual surface, so the two-pass design-bearing shape does not apply.
Rejecting that reflex was an explicit instruction in `plan.md` and is honored.

## Findings

Recorded in `works/phases/active/P17/phase.md` under `## Decomposition`, `## Findings & Notes`,
`## Doc impact`, and `## Operator Questions` — not repeated here. Two are worth naming as
**deviations-adjacent additions** the plan did not ask for and later slices need:

1. The `## Never` bans to re-cut are **three, not two** — `intent.md` names two, but
   *"Delegate a DesignSync call, or dispatch the design slice"* (`design-cowork/SKILL.md` L322)
   states the very invariant intent §2 amends, and a fourth (*"Pre-plan past the design gate —
   `DECOMP2` and everything after…"*) needs generalizing for the `paired` style, which has no
   `DECOMP2`. Raised, not designed around.
2. `co-work` appears **zero** times in this repo's slice history, so a `SLICE_KINDS` set built from
   history alone would hard-error the one kind the phase exists to protect.

## Validation

| Command | Outcome |
| --- | --- |
| `python3 scripts/workflow.py validate` | pass — `Workflow validation passed.` |
| `python3 scripts/workflow.py next` | pass — `current_slice=P17.DECOMP`, `next_slice=P17.S1` |

`next` reports `P17.DECOMP` rather than `P17.S1` because this slice is still `in_progress` — the
orchestrator has not run `finish-slice` yet (executors never transition state). Once it does, `next`
selects `P17.S1` with `P17.S2` behind it, as `plan.md` specified.

## Deviations from `plan.md`

None in scope or shape. Two additions inside the plan's own instruction to *"raise anything you find
that contradicts the intent"*: the third and fourth `## Never` bullets needing edits (finding 1
above), and the two operator questions on the `intent.md` template and the installer's stale-skill
heuristic. No implementation code was written; `design-cowork/SKILL.md`, `workflow.py`, `CLAUDE.md`
and every release file are untouched. No `doc-new-version`, no `accept-gate`, no commit, no status
transition.
