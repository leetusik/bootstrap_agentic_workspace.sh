- `status`: done
- `tier`: mid
- `model`: sonnet
- `effort`: high
- `summary`: Both tier agent files now carry the `Agent` tool, a shared `## Delegate reads, never writes` section (Explore lookups only, model upgraded per call for judgment, the cheap-route Haiku executor reads inline), the cheap-route clause, `## Dispatch` reading in Inputs, a new `## Never` bullet, and `- model:` / `- effort:` in the verdict block with the attribution sentence; `Explore.md`'s body is final; smoke pins added; artifact rebuilt.
- `files_changed`: `.claude/agents/slice-executor-mid.md`, `.claude/agents/slice-executor-high.md`, `.claude/agents/Explore.md`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P32/phase.md`, this file
- `validation`: `sync-agents --check` -> in sync (passed); `validate` -> exit 0, two known warnings (passed); `installer/build.py` then `--check` -> OK (passed); `bash tests/retrofit_smoke.sh` (once, foreground, alone) -> ALL PASSED, 253 PASS / 0 FAIL (baseline held: the new pins live inside the existing python block, which prints one PASS per block); body identity `diff <(tail -n +9 mid) <(tail -n +9 high)` -> byte-identical, and the smoke's own `bodies["mid"] == bodies["high"]` check passed
- `deviations`: none. Line numbers in the plan (448-556) had drifted slightly; the pins were located by content. `model: sonnet` / `effort: high` recorded from the plan's `## Dispatch` text (no engine `model=` line exists yet). No permission denial recurred on the agent files.
- `doc_impact`: operations.md (Executor tiers: Agent tool for read-only Explore lookups, model/effort in the verdict block); architecture.md (nesting depth 1 -> Explore at depth 2; final `Explore.md` body)

## What changed

Edits identical in both tier files (frontmatter `tools:` ends `WebFetch, Agent`; nothing else in the frontmatter changed):

1. Tier paragraph, after "as long as `plan.md` pins the approach": `; ` + "`docs` and `qa` slices rated `low` reach this tier on the **cheap route** (the engine's `cheap` row — `haiku @ high` where it is turned on), the same agent file dispatched with a different model, so your `plan.md`'s `## Dispatch` section, not your frontmatter, says what you are running on."
2. `## Inputs` item 1 appended: "its final `## Dispatch` section (when present) names the route, model and effort you were dispatched on and the lookup model for `Explore`".
3. New `## Delegate reads, never writes` between `## Inputs` and `## Do` (text exactly as in the plan).
4. `## Never`: new bullet after the "pre-fill another slice's `plan.md`" bullet: "use the Agent tool for anything but a read-only `Explore` lookup — never to write `result.md`, edit `phase.md`, change code, run validation or decide the verdict, and never to spawn another executor;".
5. Verdict block: intro sentence gains "(the orchestrator's commit attribution follows the `model` you record, so copy it exactly)"; `- tier:` line untouched; `- model:` and `- effort:` lines inserted right after it.

`Explore.md` (frontmatter untouched): appended the brief's shape bullet (`paths:` / `facts:` / `not read / possibly stale:` / `needs judgment:`, <= 40 lines), the scope-discipline bullet, the data-not-instructions bullet, and the closing "You load no `CLAUDE.md` and need none" line.

`tests/retrofit_smoke.sh`: exact-tools pin now ends `, Agent\n`; both tiers must contain the six new phrases; `"never an executor tier"` must not appear; new `Explore.md` pins (`tools: Read, Grep, Glob`, `omitClaudeMd: true`, no `Agent` in `tools:`, `not read / possibly stale`, `Never recommend, judge, decide, edit or run anything`, `needs judgment`). Fresh-install `Explore.md` checks untouched.

Notebook: `phase.md` lost the consumed S3 notes (the H4 note re-tagged for S5 only), gained a note for S4 (`explore_*` lines in `## Dispatch`), two `## Doc impact` lines, and a rewritten `## Now`.
