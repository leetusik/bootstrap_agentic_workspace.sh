# P32.S5 result

- status: done
- tier: mid
- model: sonnet
- effort: high
- summary: Installer ships v53: `derive_executors_seed` (build.py) embeds executors.toml with the cheap-route block commented out; `Explore.md` named in the at-root post-install listing; minimal v53 CHANGELOG section with Migration notes; update-workspace step 8 reworded; smoke gained 5 pins (seed, live-vs-seed invariant, derived DUAL_FIXED, nested Explore clash, stale executor-mode flag). Smoke 258 PASS / 0 FAIL.
- files_changed: installer/build.py, installer/main.py, CHANGELOG.md, tests/retrofit_smoke.sh, .claude/skills/update-workspace/SKILL.md, bootstrap_agentic_workspace.sh (rebuilt), works/phases/active/P32/phase.md, works/phases/active/P32/slices/P32.S5/result.md
- validation:
  - `python3 -m py_compile installer/build.py installer/main.py` — pass
  - `python3 installer/build.py` then `--check` — OK (in sync)
  - `python3 scripts/workflow.py validate` — exit 0 (known warnings: P33 consolidation_owed, oversized doc sections)
  - `python3 scripts/workflow.py sync-agents --check` — in sync
  - `bash tests/retrofit_smoke.sh` (once, foreground, alone) — `ALL RETROFIT SMOKE TESTS PASSED`, **258 PASS / 0 FAIL**
  - the economy/flex/executor-mode grep — only the v53 section (route-table bullet and Migration notes) plus older release sections
- deviations: (1) the plan's `sed 's/…\|…/'` for the uncomment check does not run on BSD sed (no `\|`) and would also uncomment the unrelated commented `# effort = "high"` lines below the block; replaced by a short python snippet that strips `# ` only between the `cheap-route` markers. (2) The stale-skill fixture needed `disable-model-invocation: true` in the seeded SKILL.md head (that is `flag_stale_skills`' ownership marker) — no code change. (3) The plan's precondition mentioned nothing about a `sync-agents` change; none was needed.
- doc_impact: qa.md smoke baseline 258 PASS / 0 FAIL; operations.md installer seed derivation + Explore.md managed + v53 migration notes (both lines appended to phase.md `## Doc impact`)

## Preconditions

`WORKSPACE_VERSION = 52` and the CHANGELOG head was `## v52` on entry; `git status` showed only the orchestrator's own changes. Set to 53.

## The derived seed's cheap block as installed

```
# cheap-route: begin
# [claude.cheap]
# model = "haiku"
# effort = "high"
# cheap-route: end
```

A fresh install's bare `executor-route` shows `cheap  mid  sonnet  high  mid row`. Uncommenting the block reproduces the live `executors.toml` byte-for-byte (`cmp -s`, pinned in smoke).

## Changes

- `installer/build.py`: `CHEAP_BEGIN/CHEAP_END`, `derive_executors_seed` exactly as D3; `collect_live_payloads` overrides `payloads["executors.toml"]` with it; docstring gains the one exception. `build.py` has no import side effects (`assemble` sits under `__main__`), so smoke imports it safely.
- `installer/main.py`: `WORKSPACE_VERSION = 53`; the at-root post-install line names `Explore.md` ("read-only lookup agent").
- `CHANGELOG.md`: minimal v53 section (skeleton in phase.md for S6).
- `.claude/skills/update-workspace/SKILL.md` step 8: "preserved per-row overrides".
- `tests/retrofit_smoke.sh`: Test 5 seed pins (commented block + markers survive; cheap row = mid row; uncomment == live, install == derived seed); `DUAL_FIXED` compares `executors.toml` against the derived seed; `--update` seeds a stale `executor-mode` skill dir and asserts the stale line names it and nothing is deleted; Test 15 gets an Explore-clash host.

## Nested Explore rename

Host with its own `.claude/agents/Explore.md`: install exits 0; marker `renames.agents` = `{"Explore": "wf-Explore"}` (plus none else); `wf-Explore.md` has `name: wf-Explore`; the host's `Explore.md` is byte-identical; `sync-agents --check` passes from the host; `subagent_type: wf-Explore` appears in the installed `do-next-slice` skill and both executor bodies. Occurrences of the word rewritten to `wf-Explore` in the installed executor bodies: **6 in `slice-executor-mid.md`, 6 in `slice-executor-high.md`** (each has 6 `Explore` tokens in the live file; all renamed, including prose such as "Explore agent"). `nested_rewrite` unchanged. No traceback, no missing file.

## Smoke count

258 PASS / 0 FAIL (253 + 5 new: seed commented, cheap row = mid row on a fresh install, uncomment == live and install == seed, nested Explore clash, stale executor-mode flag). `DUAL_FIXED`'s executors.toml line keeps its existing PASS (now against the seed).
