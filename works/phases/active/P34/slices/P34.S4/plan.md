# Plan — P34.S4 (Release v55)

## Context

S1–S3 landed the boundary-gated compaction: the two engine commands, the hooks shipped in project settings with the installer's additive hooks merge, the contract's `## Compact Instructions`, and the execution skills' reorder. This slice ships it as **workspace v55**: the version constant, the CHANGELOG entry, the retrofit guide's settings-merge passages, the rebuilt installer and a full smoke run. Read `works/phases/active/P34/phase.md` first: `## Decisions` (v55 and why; every fact the entry must name), the tagged note `(from P34.S3, for P34.S4)` under `## Notes for later slices`, `## Doc impact` (the durable facts, already written) and `## Now`.

Risk `low`: a version bump, a changelog entry and three guide sentences, all pinned below.

## What the orchestrator read (2026-10-12)

- `installer/main.py:44` — `WORKSPACE_VERSION = 54`, the only definition; it is stamped into the installed marker, and `tests/retrofit_smoke.sh` ~l.824–828 derives its version check from that constant and the top CHANGELOG heading ("release version agrees across installer, top changelog heading, and fresh marker"), so no test pin to edit. The suite also asserts every `## v<N>` section carries a **Migration notes** line.
- `CHANGELOG.md`: header, then `## v54 — 2026-10-12` at l.12, newest first; each entry is a list of `- **Bold lead.** …` bullets ending with `- **Migration notes.** …`. Match that shape and voice; the v54 entry is the model.
- `docs/retrofit-guide.md` describes the `.claude/settings.json` merge as permission entries in three places: the bullet "**`.claude/settings.json`** — the workspace's permission entries" (~l.136), the "(plus the additive merge into `.claude/settings.json`, where your …" line (~l.209), and the troubleshooting table row "The only intended modifications are the additive `.claude/settings.json` merge …" (~l.332); the "Union the staged `.claude/settings.json` permissions into yours by hand" step (~l.308) also now covers hooks. `installer/README.md` l.23 names the bump procedure. `README.md` is the Korean adopter README; it mentions versions only in passing (v53 executor routing) — touch it only if it has a line that is now wrong (a quick grep for `settings.json`), otherwise leave it.
- Facts for the entry (all in `phase.md`): hooks `PreCompact`/`auto` → `cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py compact-gate || true` and `SessionStart`/`compact` → `… compact-resume || true`, timeout 15, on for everyone; the gate's rules in order and its fail-safes (manual → allow; a subagent's own compaction → allow; fill ≥ ceiling 850,000 for the Claude 5 family / 170,000 otherwise → allow; 8 consecutive blocks → allow; slice `in_progress`/`in_review` → block; dirty tree (generated dashboards and `docs/index.json` excluded) → block; else allow; any error → allow; never exit 2; allow = silent stdout, block = `{"decision":"block","reason":…}`; the stderr trace line); env overrides `AGENTIC_COMPACT_CEILING` / `AGENTIC_COMPACT_BLOCK_CAP`; `compact-resume` prints `compaction=done source=compact`, the `next` output and the resume line; the installer's additive hooks merge (by exact `command`, foreign handlers kept first, idempotent) on `--update`, retrofit and nested `settings.local.json`, sidecar at root / refuse nested on a malformed shape; `## Compact Instructions` in the contract (12,274 B, under the 12,288 B cap); `do-whole-phase` / `do-next-slice` reordered so the loop invariants and a post-compaction resume line sit in the first 16 KB; the recommended auto-compact window ≈ 300k (`/autocompact 300k`, the operator's setting); smoke 266 → 289 PASS (14 + 9 asserts). Claude Code loads new project hooks on the next launch.

## Do

1. `installer/main.py`: `WORKSPACE_VERSION = 55`.
2. `CHANGELOG.md`: a `## v55 — 2026-10-12` section directly above `## v54`, in the v54 entry's shape: bullets for (a) the boundary veto and what "mid-process" means (slice in progress or dirty tree; commit → compact → plan the next slice), (b) the gate's order, fail-safes and fail-open rule with the env overrides, (c) the resume hook, (d) the contract's `## Compact Instructions` and the skills' reorder (what survives the 5,000-token re-injection), (e) the installer's hooks merge on each path, (f) the window guidance (~300k, the operator's setting; never written by the workspace), (g) the smoke count, and the closing `- **Migration notes.**` line: `/update-workspace` adds the two hooks to project `.claude/settings.json` (nested installs: `settings.local.json`; an adopter's own hooks are kept, ours added once); relaunch Claude Code (or review `/hooks`) to load them; optionally `/autocompact 300k`; the env names for tuning; nothing else to run.
3. `docs/retrofit-guide.md`: the three (four) passages above now say permissions **and hooks** (one clause each, in the guide's voice; keep the troubleshooting row's shape). Keep edits minimal.
4. `python3 installer/build.py`, then `--check`.
5. **`phase.md`**: consume the S4 note; add a one-line Decision for the release (v55, the date, the entry's placement); append `## Doc impact` lines only if a new durable-truth change arises here (the retrofit-guide edits are direct, not versioned docs — note that in `result.md`, not as doc impact); rewrite `## Now` for the review (gate required; what it must verify live: the hooks after a relaunch, the fabricated-JSON checks, the in-scope checklist lines, the operator question).

## Validate

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh` — alone in its Bash call; `ALL RETROFIT SMOKE TESTS PASSED` (289 PASS; the version assertions now read 55).
- `grep -n "^## v55" CHANGELOG.md` is line 12; `grep -c "Migration notes" CHANGELOG.md` rose by one.

## Not in this slice

No engine, settings, installer-logic, skill or contract changes; no `doc-new-version` (durable docs wait for the docs phase); no commit; no change to the operator's `~/.claude/settings.json`.

## Dispatch

slice=P34.S4
phase=P34
kind=implementation
risk=low
attempt=1
route=mid
reason=kind implementation rated low
tier=mid
subagent_type=slice-executor-mid
model=sonnet
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Sonnet 5.5
explore_model=haiku
explore_effort=high
