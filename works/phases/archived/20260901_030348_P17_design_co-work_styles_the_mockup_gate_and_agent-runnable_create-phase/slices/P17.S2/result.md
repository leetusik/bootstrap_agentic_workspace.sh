# Result — P17.S2

Propagated S1's landed spec into the seven files that restate its invariants, added the closed
`SLICE_KINDS` set to the engine, made `create-phase` agent-runnable without moving its
confirmation gate, and repaired the smoke suite. Cross-slice findings (including two the next
slice and the review need) are in `phase.md` → `### From P17.S2`; they are not repeated here.

## What changed, by part

| Part | Files |
| --- | --- |
| A — engine | `scripts/workflow.py` |
| B — `create-phase` | `.claude/skills/create-phase/SKILL.md` (`works/templates/intent.md` deliberately **not** touched — see the decision below) |
| C — drivers | `.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md` |
| D — executor agents | `.claude/agents/slice-executor-mid.md`, `.claude/agents/slice-executor-high.md` (byte-identical bodies) |
| E — contract | `CLAUDE.md` |
| F — tests | `tests/retrofit_smoke.sh` |
| G — sweep/rebuild | `.claude/skills/review-phase/SKILL.md`, `installer/main.py` (one summary print line), `README.md`, `bootstrap_agentic_workspace.sh` (rebuilt) |

## Validation

| Command | Outcome |
| --- | --- |
| `python3 scripts/workflow.py validate` | pass — "Workflow validation passed." |
| `bash tests/retrofit_smoke.sh` | pass — "ALL RETROFIT SMOKE TESTS PASSED" (Tests 0–8) |
| `python3 installer/build.py` then `--check` | pass — "artifact matches installer/ source" |
| `diff` the two executor agents | only frontmatter lines 2–5 differ; bodies byte-identical |
| `new-slice --kind cowork` | rejected, `rc=1`, names the whole set; no folder created |
| `new-slice --kind co-work` | accepted (scratch slice `P17.S99`, then deleted) |
| `validate` with an unknown kind on disk | warns on stdout, still exits `0` |
| `promote-deferred --kind cowork --create-phase` (throwaway workspace) | rejected **before** the phase is created |

`works/` was left as found: the scratch `P17.S99` folder was deleted and its single
`slice_created` line removed from `works/events.jsonl` (that log has no deletion event, so
leaving it would have recorded a slice that never existed). `docs/index.json` was touched only
by a `rebuild` timestamp and restored with `git checkout` — **this slice created no doc
versions**, as a non-review slice must not.

## Decisions taken in this slice

1. **`## Design Style` is appended by `create-phase` only when the phase is visual** — the open
   `DECOMP` Operator Question. `works/templates/intent.md` is unchanged, so no heading appears on
   non-visual phases in any adopting repo, and every reader is told to treat the section's absence
   as "not a design phase" rather than as an unanswered question (P17's own `intent.md` has none).
   Both drivers state what to do when it is missing: `DECOMP` asks the operator and stops `pending`.
2. **`installer/main.py`'s `flag_stale_skills()` heuristic left alone**, per plan. `create-phase`
   is in `CLAUDE_SKILLS` and is skipped before the marker check, so nothing changes today. See the
   Operator Questions note in `phase.md`.
3. **The `--kind` guard is a helper called twice, not once** — the one place the plan's letter and
   its stated intent diverged. Detail in `phase.md`.

## Deviations from `plan.md`

- **Part A, the guard's placement.** The plan said one guard in `create_slice()` before
  `require_phase` covers both call sites and keeps `promote-deferred` from creating a phase it then
  abandons. It does not: `promote_deferred` calls `new_phase()` itself, before `create_slice` is
  ever reached, so the phase existed and *then* the kind was rejected. Verified in a throwaway
  workspace. Extracted `require_slice_kind()` and call it from `create_slice` (still the shared
  chokepoint) **and** at the top of `promote_deferred`, before the `--create-phase` branch. One
  message, one set, plan's intent honoured. A regression test covers it.
- **Part E, "the `new-slice` command line … appears twice; update both."** It appears once in
  `CLAUDE.md` (the Workflow Commands list) and nowhere else in live machinery — checked
  `.claude/**`, `installer/**`, `README.md`, `works/templates/**`. The other matches are in
  `docs/current/*.md` (generated; Doc impact) and `CHANGELOG.md` / `docs/versions/**` (history).
- **Part G, beyond the file list.** Two files the plan did not name carried statements this phase
  falsifies, so both were fixed: `.claude/skills/review-phase/SKILL.md` and `README.md`. Rationale
  in `phase.md`; the review-phase change is the more load-bearing of the two.
- **`installer/main.py`** was edited — one `print()` summary line describing the design loop, not
  `WORKSPACE_VERSION`. The version bump and the `CHANGELOG.md` entry remain S3's, untouched.
- The artifact **was** rebuilt, per `phase.md`'s corrected release rule (the pre-commit hook
  rejects a drifted artifact); no version bump, no changelog entry.

## Doc impact

Two notes appended to `phase.md`'s `## Doc impact` list (`operations.md`, `decisions.md`), plus a
line confirming S1's `qa.md` expectation now has a second source. Nothing versioned here.
