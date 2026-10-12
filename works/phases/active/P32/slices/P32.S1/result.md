# Result — P32.S1: Engine — route table, executors.toml rows, sync-agents, executor-route; presets and executor-mode retired

- status: done
- tier: high
- model: opus
- effort: xhigh
- summary: The engine now owns one five-row route table (`EXECUTOR_ROUTES`: high, research, mid, cheap, explore). `executors.toml` takes per-row `[claude.<row>]` overrides, and a leftover `mode =` line is refused with the v53 migration message. `sync-agents` writes four managed agent files, `Explore.md` (new, minimal) among them. The new `executor-route` prints the routing decision one `key=value` per line. The presets and the `executor-mode` command are gone from the engine. The live agent files are synced (`xhigh` → `high`), the installer artifact is rebuilt with `Explore.md`, and the smoke suite passes 245/0.
- files_changed: scripts/workflow.py; executors.toml; .claude/agents/Explore.md (new); .claude/agents/slice-executor-mid.md, .claude/agents/slice-executor-high.md, .claude/agents/design-drafter.md (frontmatter `effort:` only, via sync-agents); installer/build.py; installer/main.py; bootstrap_agentic_workspace.sh (rebuilt); tests/retrofit_smoke.sh; works/events.jsonl (one `agents_synced` event from the live sync); works/phases/active/P32/phase.md; this result.md
- validation:
  - `python3 -m py_compile scripts/workflow.py`: pass
  - `python3 scripts/workflow.py sync-agents`: pass (updated mid/high/drafter `xhigh` → `high`; Explore.md already in sync); `sync-agents --check`: pass, exit 0
  - `executor-route` bare, `P32.DECOMP` (high), `P32.REVIEW` (high), `P32.S2` (mid), `P32.S6` (cheap, haiku), `P32.S6 --retry` (high, attempt=2), `--drafter`, `--explore`: pass
  - `ANTHROPIC_BASE_URL=http://127.0.0.1:10100 … executor-route P32.S6`: pass (`model=sonnet` plus `fallback=`); `CLAUDE_CODE_EFFORT_LEVEL=high … executor-route P32.S2`: pass (`warning=` line)
  - executors.toml rejection probes in a throwaway copy (scratchpad `probe1/`, never the live file): pass. Covered: `mode` at the top level, after a section and unquoted; `[claude.low]`; `[codex.*]`; a full id or `inherit` on cheap/research; a bad effort; an unknown route; an empty model; an unquoted value; a key outside a section; a duplicate key; an unknown key
  - `python3 scripts/workflow.py validate`: pass, exit 0 (the two warnings are the existing `consolidation_owed=P33` and `oversized_doc_sections=8`)
  - `python3 installer/build.py` then `--check`: pass
  - `bash tests/retrofit_smoke.sh` (run once, foreground, alone): **245 PASS, 0 FAIL** ("ALL RETROFIT SMOKE TESTS PASSED")
  - `grep -rn 'economy\|flex\|executor-mode' scripts/workflow.py executors.toml installer/main.py installer/build.py`: only the v53 migration text (workflow.py 396–397, executors.toml 32)
- deviations: (1) Installer entries pulled forward from S5, as planned. (2) One installer line beyond the plan's list: the at-root write of `Explore.md`. (3) `DUAL_FIXED` gained `Explore.md`. (4) The nested-engine smoke fixture copies `Explore.md`. (5) `warning=` lines explain themselves and do not use the plan's "(H1)/(H2)" tags. (6) The bare form behind a proxy prints `proxy=<url> (loopback)` and a `fallback=` line for both cheap and explore; `fallback=` prints only when the model actually changes. (7) In `Explore.md`'s frontmatter, `omitClaudeMd:` comes before `model:`/`effort:`. (8) The `--risk` help names `co-work` among the kinds routed by kind. (9) Misuse errors for `executor-route`. Each is detailed below.
- doc_impact: three `## Doc impact` lines appended to phase.md (operations, decisions, architecture), quoted below

## The bare `executor-route` table (live repo)

```
route     tier  model   effort  source
high      high  opus    high    default
research  high  opus    medium  default
mid       mid   sonnet  high    default
cheap     mid   haiku   high    executors.toml
explore   -     haiku   high    default
agent files: in sync
proxy=none
```

## One slice printout — `executor-route P32.S6`

```
slice=P32.S6
phase=P32
kind=docs
risk=low
attempt=1
route=cheap
reason=kind docs rated low
tier=mid
subagent_type=slice-executor-mid
model=haiku
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Haiku 5.5
```

Under `ANTHROPIC_BASE_URL=http://127.0.0.1:10100` the same call prints `model=sonnet`, `attribution=Claude Sonnet 5.5`, then `fallback=cheap model haiku -> sonnet (loopback ANTHROPIC_BASE_URL http://127.0.0.1:10100: ocx/Kiro serves no Haiku 5.5)`. `--retry` prints `attempt=2`, `route=high`, `reason=second attempt`, `tier=high`, `subagent_type=slice-executor-high`, `model=opus`. `--drafter` prints `agent=design-drafter`, `route=high`, `tier=high`, `subagent_type=design-drafter`, …; `--explore` prints `agent=Explore`, `route=explore`, `tier=-`, `subagent_type=Explore`, `model=haiku`, ….

## What landed

- **Constants** (`scripts/workflow.py` ~274–321): `EXECUTOR_ROUTES`, `ROUTE_DEFAULTS` (cheap `None` = inherits mid), `ROUTE_TIER`, `ROUTE_AGENT`, `DESIGN_DRAFTER_FOLLOWS` (moved here from its old spot), `MANAGED_AGENT_FILES` (label, agent, row for the four files), `AGENT_MODEL_ALIASES`, `EFFORT_LEVELS`, `MODEL_ATTRIBUTION`, `LOOPBACK_HOSTS`, `EXPLORE_PROXY_MODEL = "sonnet"`. The comment block above them was rewritten as the plan asked. `EXECUTOR_PRESETS` and `DEFAULT_EXECUTOR_MODE` are gone. `from urllib.parse import urlparse` was added for the loopback check.
- **`read_executors_toml()`** returns `{(row, key): value}`. It enforces the strict line grammar and gives every error a line number. A `mode` key anywhere (quoted or not) gets the v53 migration message. `[claude.low]` keeps the v23 message, `[codex.*]` the v31 one. Any other `[claude.X]` → `unknown route X (valid: …)`. An empty model is an error (it moved here from the old `executor_config`, now line-numbered). An effort outside `EFFORT_LEVELS` that is not `""` is an error. On research and cheap, a model that is not an alias is an error.
- **`resolve_routes()`** replaces `executor_config()`. It resolves cheap after mid, from mid's resolved values; a key's source is `default`, `executors.toml` or `mid row`. `route_source()` prints one source, or `model X / effort Y` when the two keys differ.
- **`executor_agent_files(routes)`** returns the four files: mid, high, design-drafter (high row) and Explore (explore row). All paths go through `installed_agent_name()`. `_patched_agent_md` is unchanged.
- **`sync-agents`** prints one line per row (`high      opus @ high      (default)`), then `config source: executors.toml (N override(s))` or `defaults (no executors.toml)`. The sync verdict, exit codes, the `.env` warning and the `agents_synced` event are unchanged.
- **`executor-route`** (`cmd_executor_route`, `slice_route`, `_dispatch_lines`, `_route_fallback`, `_loopback_base_url`, `_route_env_warnings`): the bare, slice, `--drafter` and `--explore` forms, exactly the keys the plan names, one `key=value` per line. The rule is kind, then risk, then attempt (`slice_route`). It reads the toml (a malformed file errors here, with its line number) and writes nothing.
- **Retired:** `_overrides_listing`, `_with_executor_mode`, `show_executor_mode`, `cmd_executor_mode` and the `executor-mode` parser. `executor-mode` now fails with argparse's `invalid choice`.
- **Other engine text:** the `validate` drift loop iterates `executor_agent_files(resolve_routes())`, so `Explore.md` is included. The `SLICE_KINDS` comment and the `--kind` / `--risk` help on `new-slice` and `promote-deferred` were reworded for rows. The `sync-agents` help names the four files.
- **`executors.toml`** (64 lines) has a header in the plan's order. The cheap-route block is uncommented between the exact `# cheap-route: begin` / `# cheap-route: end` marker lines, followed by commented examples for high, research, mid and explore.
- **`.claude/agents/Explore.md`** carries D8's frontmatter and a 5-line body for S3 to finalize.
- **Installer:** see deviations 1–2.
- **Smoke:** 807–809 now hold the route defaults for all four files, plus Explore's `tools:`. 820 and 1094 are reworded. The old preset / `executor-mode` matrix (996–1046) is replaced by the plan's 13-probe route matrix (16 ok/bad pairs), each `executor-route` probe run with `env -u` on the three variables it reports on. The `cmp -s` executors.toml round trip is dropped, and the `[claude.low]` / `[codex.*]` probes are kept.

## Deviations, with reasons

1. **Installer entries pulled forward from S5:** `FIXED_LIVE_FILES` + `.claude/agents/Explore.md` (build.py); `MANAGED_FILES` + `Explore.md`; `NESTED_AGENTS` + `"Explore"`; the post-install executor line reworded to name `executor-route`, with no economy/flex (main.py). Reason: without them, a fresh install's `sync-agents --check` fails on the missing `Explore.md` until S5. No version bump, no seed derivation. The `sync-agents` hint at main.py 1490 names neither presets nor `executor-mode`, so it is unchanged.
2. **One installer line beyond the plan's list:** `write_text(".claude/agents/Explore.md", PAYLOADS[...])` beside the design-drafter write in the at-root agent block (main.py ~1347). `MANAGED_FILES` only feeds the fresh-install conflict guard; nothing writes an agent file unless that block names it. Without this line, a fresh or `--update`d at-root install has no `Explore.md`. Nested installs already write every `NESTED_AGENTS` entry.
3. **`DUAL_FIXED` gained `.claude/agents/Explore.md`**, although the plan said to leave `DUAL_FIXED` alone. Reason: the smoke's manifest cross-check ("dual-apply manifest covers every installer FIXED_LIVE_FILES entry") fails as soon as `FIXED_LIVE_FILES` carries `Explore.md`. Its `executors.toml` entry (the verbatim comparison) is untouched; it is S5's.
4. **The nested-engine smoke fixture (~1576) also copies `Explore.md`** into the host's `.claude/agents/`. Without it, `nw sync-agents --check` reports a missing agent file and "sync-agents resolves agents in the host's .claude/agents through the rename map" fails.
5. **`warning=` text explains itself.** It reads `… outranks every per-dispatch effort (and every agent file's effort line); unset it for the route table's efforts to apply` / `… overrides every model (per-dispatch and frontmatter alike); unset it …`. The plan's "(H1)" / "(H2)" tags were dropped: they name phase-notebook notes that mean nothing to an adopter once P32 is archived. Both lines start with the plan's prefixes `warning=CLAUDE_CODE_EFFORT_LEVEL=<v> is set and outranks every per-dispatch effort` and `warning=CLAUDE_CODE_SUBAGENT_MODEL_FORCE=<v> is set and overrides every model`. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` warns unless its value is `0`, `false` or `no`.
6. **Proxy reporting.** Behind a loopback proxy the bare form prints `proxy=<url> (loopback)`, then a `fallback=` line for each affected row (cheap and explore). A non-loopback `ANTHROPIC_BASE_URL` prints `proxy=none`. A `fallback=` line prints only when the model actually changes; an unset cheap row already on the mid model, for example, prints none. The bare table itself shows the configured rows. The fallback is what dispatch uses, and the slice, `--drafter` and `--explore` forms print it in `model=`. A schemeless `ANTHROPIC_BASE_URL` (`127.0.0.1:10100`) counts as loopback too.
7. **`Explore.md` frontmatter order:** `omitClaudeMd: true` comes before `model:` / `effort:`. That is where `_patched_agent_md` writes them (at the frontmatter's end, since there is no `permissionMode:`), so `sync-agents` is a no-op on the file. The plan's listing put them the other way round and also asked for the sync to be a no-op; both cannot hold, and the content is the same.
8. **The `--risk` help names `co-work`** among the kinds routed by kind (D1 routes it to the high row by kind; the plan's help text listed only decomposition, review and research).
9. **Misuse errors** (exit 1): passing two of `<slice_id>` / `--drafter` / `--explore` → `… are mutually exclusive; give at most one`; `--retry` without a slice → `--retry needs a <slice_id>`. An unknown slice gets the existing `slice not found:`.

## Left for later slices (none of these is a smoke failure today)

- **S3:** finalize the `Explore.md` body and add its assertions. The `tools:` pin at smoke ~553 still passes, because no `Agent` has been added yet.
- **S4:** `.claude/skills/executor-mode/SKILL.md` still runs `workflow.py executor-mode`, which now fails with `invalid choice`. The skill rename to `executor-route` must land before anyone runs `/executor-mode`. Skill prose with preset words: do-next-slice 26, do-whole-phase 36, review-phase, design-cowork (see the phase.md note).
- **S5:** `WORKSPACE_VERSION`; deriving the adopter seed by commenting out the `# cheap-route: begin/end` block; `DUAL_FIXED`'s `executors.toml` comparison against the derived seed; the nested `Explore` rename check; optionally main.py ~1512 (the at-root post-install agent listing does not name `Explore.md`); the full-suite baseline (now **245 PASS**, up from v51's 239).
- **S6:** CHANGELOG v53 Migration notes; `README.md` / `README.en.md` (they still name economy/flex and `executor-mode`); `docs/retrofit-guide.md`.

## Doc impact (appended to phase.md)

- `operations.md: Executor tiers — the route table replaces the economy/flex presets; executors.toml is per-row; executor-route prints the routing decision; the cheap route and Explore row (P32.S1)`
- `decisions.md: one engine-owned route table with dispatch-time model/effort supersedes the v29/v31 presets, v45 executor-mode and v46 "haiku never a tier" (P32.S1)`
- `architecture.md: agent set gains Explore.md; model/effort resolved by the engine per route at dispatch time, frontmatter the fallback (P32.S1)`

## Notes

- The live `sync-agents` run appended one `agents_synced` event to `works/events.jsonl`, as designed.
- Throwaway probes ran in the session scratchpad (`probe1/`, a copy of `scripts/`, `.claude/agents/`, `works/` and `executors.toml`); the live `executors.toml` was never put into a bad state.
- This slice touched nothing under `.claude/worktrees/` (P33's worktree).
