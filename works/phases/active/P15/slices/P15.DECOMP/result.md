# Result — P15.DECOMP

Decomposed `P15` into six ordered middle slices and seeded `phase.md`. Single pass, as the plan
directed: no `co-work` slice, no `P15.DECOMP2` (this phase builds nothing user-facing and makes no
visual design decisions).

## Slices created (bare folders — no `plan.md` written for any of them)

| ID | Order | Kind | Risk | Name |
| --- | --- | --- | --- | --- |
| `P15.S1` | 1 | implementation | high | Strip Codex from the workflow engine and `executors.toml` |
| `P15.S2` | 2 | implementation | high | Strip Codex from the installer and delete the Codex trees |
| `P15.S3` | 3 | implementation | high | Strip Codex from the contract and Claude skill prose |
| `P15.S4` | 4 | implementation | high | Rewrite the retrofit smoke test Codex-free |
| `P15.S5` | 5 | implementation | high | Strip Codex from READMEs, guides, and shipped doc bodies |
| `P15.S6` | 6 | implementation | high | Ship the removal as workspace v31 with a CHANGELOG entry |

Each chains `--depends-on` to its predecessor (`S1` depends on `P15.DECOMP`). All six are
`--risk high` per the plan: every one writes real code or spans several files, and none is a
one-line edit.

The breakdown, per-slice rationale, atomicity requirements, verified line numbers, constraints, and
open questions are all in `works/phases/active/P15/phase.md`.

## Deviations from `plan.md`

The plan's suggested shape was five slices; I cut six, and reordered. All deviations are recorded
in `phase.md` with reasoning:

1. **Added `P15.S6` (release).** The plan and `intent.md` both missed that
   `tests/retrofit_smoke.sh` (~L232) asserts
   `WORKSPACE_VERSION == top CHANGELOG heading == installed marker == 30`, and that
   `installer/main.py` documents the version as bumped "whenever a machinery change ships to
   targets". Dropping Codex is exactly such a change, and the `OBSOLETE_MACHINERY` flagging the
   operator asked for only reaches adopters through an update. So v31 + a `## v31` CHANGELOG
   section with Migration notes is required. This is an *append* to `CHANGELOG.md`, consistent
   with `intent.md`'s "append-only history stays as it is" — no existing section is touched.
2. **Moved the release slice last and the tests slice before the prose slice.** Ordering
   tests (`S4`) → prose (`S5`) → release (`S6`), with `S6` moving the smoke test's version pin in
   the same commit as the bump, means the smoke test is green at the end of *every* slice from `S4`
   on. Any other placement leaves a one- or two-slice window where CI would go red on push.
3. **Assigned two `installer/` constants to the prose slice `S3`.** New finding, not in the survey:
   `CLAUDE.md` line 3 (`> Equivalent to \`AGENTS.md\`…`) is pinned byte-exact in
   `installer/build.py` `CLAUDE_HDR` (guarded by
   `die("CLAUDE.md header changed — update CLAUDE_HDR in build.py")`) and again in
   `installer/main.py`'s contract `write_text`. A prose-only edit to that line would break the
   build and be rejected by the pre-commit hook, so the three must land together.

The plan's other suggestions were verified and kept unchanged: engine first, installer + tree
deletion atomic, `flag_obsolete_machinery()`'s `is_file()` gotcha real (confirmed at
`installer/main.py` L611), `EXPECTED_SKILL_COUNT = 17`, the three `.codex` entries in
`FIXED_LIVE_FILES`, and the pre-commit path alternation — all recorded verbatim in `phase.md` so
later slices need not re-derive them.

## Validation

| Command | Outcome |
| --- | --- |
| `python3 scripts/workflow.py validate` | PASS — `Workflow validation passed.` |
| `python3 installer/build.py --check` | PASS — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| `find works/phases/active/P15/slices -type f` | PASS — each of `P15.S1`…`P15.S6` holds exactly `slice.json` and no `plan.md` |

No machinery was touched, so no rebuild was needed and none was run.

## Doc impact

No doc versions created (correct for a non-review slice). Four "Doc impact" lines were appended to
`phase.md` for `P15.REVIEW` to consolidate — `architecture`, `operations`, `decisions`, and an
explicit note that no other `docs/current/*.md` mentions Codex.

## Notes for the orchestrator

- Two open questions are parked in `phase.md` for `P15.S2`/`P15.S4` to decide in flight (the
  stranded `AGENTS.workspace.md` sidecar for already-retrofitted adopters, and whether to keep the
  literal release-version pin in the smoke test). Neither blocks decomposition.
- Nothing was implemented and no Codex file was deleted, per the plan's boundaries.
