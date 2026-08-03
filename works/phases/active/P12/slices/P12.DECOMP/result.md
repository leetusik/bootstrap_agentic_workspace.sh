# P12.DECOMP — result

Decomposed P12 into **seven** middle slices exactly as `plan.md` recommended, after verifying every
finding in the plan against the live code. One plan finding turned out to be wrong; it is corrected
below and in `phase.md`.

## What was done

1. **Read and verified** `intent.md` (all eight requirements plus both 2026-08-03 amendments — the
   proactive suggestion at both moments, and the agent-driven PR/merge after the branch's review),
   the named `scripts/workflow.py` functions, `installer/build.py` `FIXED_LIVE_FILES` + skill
   auto-discovery, `installer/main.py` `MANAGED_FILES` + `CLAUDE_SKILLS`/`CODEX_SKILLS`, the four
   skills (`do-next-slice`, `do-whole-phase`, `create-phase`, `review-phase`), and the
   `CLAUDE.md`/`AGENTS.md` commit convention.
2. **Created seven bare slice folders** (`slice.json` only — no `plan.md` pre-filled anywhere).
3. **Filled `phase.md`**: Context (both amendments + the single-pass note), Decomposition (table +
   per-slice rationale and dependency chain), Findings & Notes (verified findings, with the
   correction), Constraints (backward compatibility, installer rebuild, lean tests, P12 runs in
   default mode, no slice-level parallelism), Open Questions (four design decisions assigned to
   their owning slices).

## Slices created

| Slice | Order | Kind | Risk | Name |
|---|---|---|---|---|
| `P12.S1` | 10 | implementation | high | Parallel-mode schema + phase-scoped selection |
| `P12.S2` | 20 | implementation | high | Opt-in lifecycle: branch + worktree cut, teardown, proactive suggestion |
| `P12.S3` | 30 | implementation | high | Merge machinery: quiet-point gate, merge-finish rebuild, deferred consolidation |
| `P12.S4` | 40 | implementation | high | Cross-stream status view |
| `P12.S5` | 50 | implementation | high | PR + CI layer, agent-driven integration |
| `P12.S6` | 60 | implementation | high | Skills + contract for parallel mode |
| `P12.S7` | 70 | implementation | low | README documentation for parallel mode |

No slice count, order, kind, or risk was changed from the plan's recommendation. Two slice *names*
were lengthened slightly for the backlog's benefit (S2 gained ", teardown, proactive suggestion";
S7 gained " for parallel mode") — scope is identical to the plan.

Intent coverage: item 1 → S1; items 2 & 7 → S2; items 3, 4, 6 → S3; item 8 → S4; item 5 → S5;
amendment 1 (proactive suggestion) → S2 (engine) + S6 (skills); amendment 2 (agent-driven PR/merge)
→ S5 (sequence) + S3 (post-merge step) + S6 (documented flow).

## Verification of the plan's findings

Every line number in the plan's "Findings" section is current at commit `6f9e3c7`, and every claim
held except one:

- `resolve_current` :449 — confirmed; single global walk, `pending`/`blocked` yields no slice.
  `cmd_next` :796 prints `WAITING ON OPERATOR` repo-wide. `next` subparser (:1051) takes **no
  arguments** — confirmed.
- `rebuild_index_and_state` :479 — confirmed; rewrites all four generated files on every transition.
- `next_doc_version_id` :278 / `new_doc_version` :288 / `rebuild_docs` :265 — confirmed serial;
  `max+1` id allocation plus a single `docs/index.json`.
- `new_phase` :665 — confirmed; the written `phase.json` has no stream fields.
- `validate` :539 and `_phase_blockers` :912 — confirmed; both would trip on a merged-but-
  unconsolidated `done` phase, so S1/S3 must accommodate that state.
- `installer/build.py` `FIXED_LIVE_FILES` :42, `installer/main.py` `MANAGED_FILES` :71 — confirmed
  as hand-maintained lists that a new embedded non-skill file must join.
- Commit convention (`CLAUDE.md`/`AGENTS.md` line 101) — confirmed verbatim; needs the S6 carve-out.
- No `.gitattributes` and no `.github/` in the repo; remote is
  `github.com/leetusik/bootstrap_agentic_workspace.sh`; `gh` 2.96.0 and git 2.45.2 available.

**Discrepancy (one).** The plan stated that "a **new skill** must be registered in
`CLAUDE_SKILLS`/`CODEX_SKILLS` in main.py". That is not true: `installer/main.py:57-58` *derives*
both lists from the generated `PAYLOADS` manifest, and `build.py:77-82` auto-discovers skill
payloads from disk — so a new skill needs no registration at all, only its folder(s) and a rebuild.
Hand-registration in `FIXED_LIVE_FILES` + `MANAGED_FILES` is still required for **non-skill**
embedded files (the CI workflow and `.gitattributes` in S3/S5). Recorded as a correction in
`phase.md` so S5/S6 do not chase a nonexistent registration step.

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | **passed** — `Workflow validation passed.` (exit 0) |
| `grep -n "P12" works/backlog.md` | **passed** — S1..S7 listed in order between `P12.DECOMP` and `P12.REVIEW`; pointer shows next slice `P12.S1` |
| `ls works/phases/active/P12/slices/P12.S{1..7}` | **passed** — each folder holds `slice.json` only; no `plan.md` pre-filled |
| slice metadata dump (`kind`/`risk`/`order`) | **passed** — all `implementation`; S1–S6 `high`, S7 `low`; orders 10..70 |

## Deviations from plan.md

- One factual correction to the plan's findings (skill registration is automatic) — recorded above
  and in `phase.md` rather than propagated as-is.
- Two slice names lengthened for backlog readability; scope unchanged.
- Nothing else: same seven slices, same orders, same kinds, same risks.

## Doc impact

None. Decomposition changed no durable truth — `phase.md` and the new slice folders only.

## Boundaries observed

Ran `new-slice` seven times (permitted on a decomposition slice) and `validate`. No commit, no
status transition, no `doc-new-version`, no other slice's `plan.md` touched.
