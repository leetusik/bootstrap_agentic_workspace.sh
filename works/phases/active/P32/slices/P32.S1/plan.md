# Plan — P32.S1: Engine — the route table, `executors.toml` rows, `sync-agents`, `executor-route`; retire the presets and `executor-mode`

Kind `implementation`, risk `high` (wide blast radius + core invariant; see `phase.md` *Breakdown and ratings*). Read `phase.md` first — D1, D2, D3, D4, D7, D8, D10 and the `## Notes for later slices` tagged for S1 (H1, H2, H3, H4, H6, the engine anchors, the Explore.md sequencing note, the smoke-assertion list) are the contract this plan implements. `intent.md` holds the operator's words and the research behind every row; consult it when a wording choice needs the *why*.

## Goal

After this slice the engine owns one route table (`EXECUTOR_ROUTES`), `executors.toml` is a per-row override file with no `mode` knob, `sync-agents` writes four managed agent files from the rows, and `python3 scripts/workflow.py executor-route` prints the deterministic routing decision the orchestrator will dispatch from (S4 wires the skills to it; S2 adds the record). The economy/flex presets and the `executor-mode` command are gone from the engine. The installer artifact is rebuilt and stays consistent: the fresh install ships the new `Explore.md`.

## Files

- `scripts/workflow.py` — the engine (anchors in the S1 note: constants 272–290, `read_executors_toml` 347, `executor_config` 404, `_patched_agent_md` 417, `DESIGN_DRAFTER_FOLLOWS` 435, `executor_agent_files` 451, `sync_agents` 478, 519–590 to retire, `validate`'s drift loop ~1610, the `SLICE_KINDS` comment ~205–220, parsers ~4403–4409 and the `--kind`/`--risk` help at ~4432–4433 and ~4574–4575).
- `executors.toml` — the live file, rewritten (D2, D3).
- `.claude/agents/Explore.md` — **new**, minimal (D8; S3 finalizes the body).
- `.claude/agents/slice-executor-mid.md`, `slice-executor-high.md`, `design-drafter.md` — **frontmatter only, through `sync-agents`**; never edit their bodies (S3's).
- `installer/build.py` and `installer/main.py` — three list entries and two message lines, pulled forward from S5 (below); nothing else in the installer (no version bump, no seed derivation).
- `tests/retrofit_smoke.sh` — the engine-facing assertions (below).
- `bootstrap_agentic_workspace.sh` — rebuilt by `python3 installer/build.py` (the pre-commit hook refuses a machinery commit without it).

Do **not** touch: the skills (S4), the agent bodies (S3), `WORKSPACE_VERSION` (S5), `CHANGELOG.md` / READMEs (S6), `docs/`.

## Engine design (implement exactly this)

### Constants (replace lines 273–290)

```python
EXECUTOR_TIERS = ("mid", "high")              # unchanged
RETIRED_EXECUTOR_TIERS = ("low",)             # unchanged (v23 message stays)
# One route table (v53). Rows in print order; a row is (model, effort), overridable per row in
# executors.toml. cheap inherits the RESOLVED mid row for any key it does not override. explore is
# the read-only lookup agent, not a slice route. The presets (economy/flex, v29–v52) are gone.
EXECUTOR_ROUTES = ("high", "research", "mid", "cheap", "explore")
ROUTE_DEFAULTS = {
    "high":     {"model": "opus",   "effort": "high"},
    "research": {"model": "opus",   "effort": "medium"},
    "mid":      {"model": "sonnet", "effort": "high"},
    "cheap":    None,                                   # inherits mid
    "explore":  {"model": "haiku",  "effort": "high"},
}
ROUTE_TIER = {"high": "high", "research": "high", "mid": "mid", "cheap": "mid", "explore": None}
# Rows that own an agent file (sync-agents writes their frontmatter). research and cheap dispatch
# to another row's file, so their model must be an Agent-tool alias the dispatch can pass (H6).
ROUTE_AGENT = {"high": "slice-executor-high", "mid": "slice-executor-mid", "explore": "Explore"}
DESIGN_DRAFTER_FOLLOWS = "high"               # unchanged in meaning: the drafter follows the high row
AGENT_MODEL_ALIASES = ("opus", "sonnet", "haiku", "fable")      # the Agent tool's `model` enum
EFFORT_LEVELS = ("low", "medium", "high", "xhigh", "max")        # the Agent tool's `effort` enum
MODEL_ATTRIBUTION = {"opus": "Claude Opus 5.5", "sonnet": "Claude Sonnet 5.5",
                     "haiku": "Claude Haiku 5.5", "fable": "Claude Fable 5.1"}   # else verbatim (D7)
```

Rewrite the comment block above them: what a row is, that `cheap` inherits `mid`, why `research`/`cheap` take aliases only, the effort escape hatch (`effort = ""` → no effort line, no per-dispatch effort), and that haiku's "never an executor tier" (v46) is superseded — the cheap route is a row, not a tier.

### `read_executors_toml()` → `{(row, key): value}`

Same strict line grammar, new acceptance:

- `[claude.<row>]` for any of the five rows. `[claude.low]` keeps the v23 message, `[codex.*]` the v31 message; any other `[claude.X]` → `executors.toml line n: unknown route X (valid: cheap, explore, high, mid, research)`.
- A top-level `mode = "…"` line, anywhere → `executors.toml line n: the economy/flex presets were retired in workspace v53 — delete this line; the route table replaces them (flex was xhigh on both tiers: set effort = "xhigh" under [claude.mid] and [claude.high] to keep it); run: <WORKFLOW_CMD> executor-route`.
- `model` / `effort` keys inside a section, double-quoted, no duplicates (as today). New value checks, line-numbered: `model = ""` → error (as today, reworded for rows); `effort` not in `EFFORT_LEVELS` and not `""` → `effort must be one of low, medium, high, xhigh, max — or "" to write no effort line`; a `model` outside `AGENT_MODEL_ALIASES` under `[claude.research]` or `[claude.cheap]` → `… route <row> dispatches to another row's agent file, so its model must be an Agent-tool alias (opus, sonnet, haiku, fable); a full model id or inherit works only on mid, high and explore, whose agent files carry it`.
- Unknown keys / unquoted values / anything else → the existing errors, reworded to name `[claude.<row>]`.

### `resolve_routes()` (replaces `executor_config()`)

Returns `{row: {"model": m, "effort": e, "model_source": s, "effort_source": s}}` with source ∈ `default` | `executors.toml` | `mid row` (the last only for `cheap`'s inherited keys). `cheap` resolves **after** `mid`, from mid's *resolved* values. Update every caller: `executor_agent_files`, `executor_agent_drift`, `sync_agents`, the `validate` drift loop, and the new command.

### `executor_agent_files(routes)` → four managed files

`(label, path, model, effort)` for: `("mid", slice-executor-mid)` from `mid`; `("high", slice-executor-high)` from `high`; `("design-drafter", design-drafter)` from `high`; `("Explore", Explore)` from `explore`. Every path through `installed_agent_name()` (nested renames), `Explore` included. `_patched_agent_md` is unchanged (it inserts `model:`/`effort:` before `permissionMode:` or at the frontmatter's end, which also covers `Explore.md`, which has no `permissionMode:`).

### `sync-agents`

Same flags and exit codes. Output: one line per **row** — `high      opus @ high      (default)` … `cheap     haiku @ high     (executors.toml)` … (source: `default`, `executors.toml`, `mid row`, or a mixed `model executors.toml / effort mid row`) — then `config source: executors.toml (N override(s))` or `defaults (no executors.toml)`, then the per-file sync verdict exactly as today (`updated:` list / `already in sync; nothing written` / `agent files in sync with executors.toml/defaults` / `out of sync …` + exit 1 on `--check`). The `.env` legacy warning stays. The `agents_synced` event stays.

### `executor-route` (new; retire `executor-mode`)

Delete `_overrides_listing`, `_with_executor_mode`, `show_executor_mode`, `cmd_executor_mode` and the `executor-mode` parser; add `cmd_executor_route` registered as `executor-route` with `slice` (positional, optional), `--retry`, `--drafter`, `--explore` (the three target forms are mutually exclusive). Every printout is **one `key=value` per line** (the `next` convention), never a single packed line.

**Bare** (`executor-route`): the table — a header line `route  tier  model  effort  source` then five aligned rows (`explore`'s tier printed `-`); then `agent files: in sync` or `agent files: out of sync: <paths> (run: <WORKFLOW_CMD> sync-agents)` (missing files listed as `<path> (missing)`); then the environment lines below.

**Slice** (`executor-route <slice_id> [--retry]`): `require_slice(slice_id)`, read `slice.json`; print, in this order:

```
slice=P32.S6
phase=P32
kind=docs
risk=low
attempt=1                       # 2 with --retry
route=cheap
reason=kind docs rated low      # see the rule
tier=mid
subagent_type=slice-executor-mid    # through installed_agent_name()
model=haiku
pass_model=yes                  # no when model is not in AGENT_MODEL_ALIASES (the frontmatter carries it)
effort=high
pass_effort=yes                 # no when effort is ""
attribution=Claude Haiku 5.5
```

The rule, **kind first, then risk, then attempt** (D1/D4): `--retry` → `high`, `reason=second attempt`; else kind `review` / `decomposition` / `co-work` → `high`, `reason=kind <kind>`; kind `research` → `research`, `reason=kind research`; risk not exactly `low` → `high`, `reason=risk <value or unset> (not low)`; kind `implementation` / `fix` → `mid`, `reason=kind <kind> rated low`; kind `docs` / `qa` → `cheap`, `reason=kind <kind> rated low`; any other kind (unreachable: `SLICE_KINDS` is closed, but legacy data may carry one) → `high`, `reason=unknown kind <kind>`.

**`--drafter`**: `agent=design-drafter`, `route=high`, `tier=high`, `subagent_type=<installed design-drafter>`, then `model` … `attribution` as above. **`--explore`**: `agent=Explore`, `route=explore`, `tier=-`, `subagent_type=<installed Explore>`, `model` … `attribution`.

**Environment lines** (every form, after the main lines, each only when it applies):
- `fallback=cheap model <m> -> <mid model> (loopback ANTHROPIC_BASE_URL <url>: ocx/Kiro serves no Haiku 5.5)` when `ANTHROPIC_BASE_URL`'s host is `127.0.0.1`, `localhost` or `::1` and the form resolves to `cheap` (the bare form prints it for the row); the `model=` line already shows the fallen-back model, `attribution` follows it. `--explore` under the proxy → `sonnet`, `fallback=explore model <m> -> sonnet (…)`. Without a proxy the bare form prints `proxy=none`.
- `warning=CLAUDE_CODE_EFFORT_LEVEL=<v> is set and outranks every per-dispatch effort (H1)`.
- `warning=CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 is set and overrides every model (H2)`.

`executor-route` reads the toml (so a malformed file errors here, line-numbered, exit 1) and writes nothing.

### Other engine text

- `validate`'s advisory drift loop iterates `executor_agent_files(resolve_routes())` (same warnings; `Explore.md` now included).
- `SLICE_KINDS` comment (~205–220): `research` routes to the `research` row by kind (never the mid/cheap rows); the rating still says `--risk high`.
- `--kind` / `--risk` help on `new-slice` and `promote-deferred`: `low` → the `mid` row (`implementation`/`fix`) or the `cheap` row (`docs`/`qa`), both on `slice-executor-mid`; `high` → the `high` row on `slice-executor-high`, only for a named trigger or a fix to mid-row work; `decomposition`, `review`, `research` route by kind whatever this says; `executor-route <slice>` prints the decision.
- `grep -n 'economy\|flex\|preset\|executor-mode\|EXECUTOR_PRESETS' scripts/workflow.py` must come back empty except history in comments you deliberately keep (prefer none).

## `executors.toml` (live file, rewritten)

Header (comments) covering, in this order: what the file is (per-row overrides of the engine's route table; apply with `sync-agents`; `executor-route` shows the resolved table and the decision for a slice); the five rows with their defaults and what each serves (D1, one line each; `cheap` inherits `mid` unless overridden); the grammar (`[claude.<row>]`, `model`/`effort` double-quoted, `effort = ""` escape hatch, aliases-only on `research`/`cheap`, full ids on `mid`/`high`/`explore`); the migration line (a `mode = "…"` line is refused since v53 — delete it; flex = `effort = "xhigh"` on `mid` and `high`); the "this file is yours" paragraph (seed-once, never overwritten by updates, safe to delete, no secrets, re-run `sync-agents` after `/update-workspace`); then the cheap-route block **uncommented** (on in this repo):

```toml
# The cheap route: docs and qa slices rated low run on Haiku 5.5 at high. On in this
# repository; the installer seeds it commented out because the `haiku` alias is Haiku 4.5
# on Bedrock, Vertex and Foundry — uncomment to opt in on the Anthropic API. Unset, the
# cheap row inherits the mid row. Under a loopback ANTHROPIC_BASE_URL (ocx/Kiro, no
# Haiku 5.5) executor-route falls back to the mid row's model by itself.
# cheap-route: begin
[claude.cheap]
model = "haiku"
effort = "high"
# cheap-route: end
```

then commented examples for the other rows (`# [claude.mid]` / `# model = "sonnet"` / `# effort = "high"` …). Keep the whole file under ~70 lines. The `# cheap-route: begin` / `end` marker lines are exact (S5's seed derivation keys on them).

## `.claude/agents/Explore.md` (new, minimal)

```
---
name: Explore
description: Read-only lookup agent for this workspace — locates files, excerpts and summaries for the orchestrator's planning and for executors' bulky reads; returns a compact brief with paths. Never judges, recommends, decides or writes. Runs on the explore row (haiku @ high); callers upgrade the model per call for a lookup that needs judgment.
tools: Read, Grep, Glob
model: haiku
effort: high
omitClaudeMd: true
---
```

Body (≤ 15 lines, S3 finalizes): you answer exactly one read-only lookup; locate, excerpt, summarize; return a compact brief — relevant paths with one line each, the facts asked for, and an explicit "not read / possibly stale" list; never recommend, judge, edit or run anything; say when the question needs judgment so the caller can upgrade the model. Then run `sync-agents` so its frontmatter is engine-written (it should be a no-op for this file if you typed it exactly).

## Installer (pulled forward from S5 — keep the artifact consistent at this boundary)

- `installer/build.py` `FIXED_LIVE_FILES`: add `.claude/agents/Explore.md` after `design-drafter.md`. No seed derivation here (S5).
- `installer/main.py`: `MANAGED_FILES` agent list (~188) + `.claude/agents/Explore.md`; `NESTED_AGENTS` (495) + `"Explore"`; reword the post-install message (1511) and the `sync-agents` hint (1490) wherever they name economy/flex or `executor-mode` — name `executor-route` instead. Nothing else.
- `python3 installer/build.py` then `python3 installer/build.py --check`.

Record in `result.md` deviations that these came forward from S5, with the reason (a fresh install's `sync-agents --check` would otherwise fail on the missing `Explore.md` until S5).

## Smoke test (`tests/retrofit_smoke.sh`) — engine-facing assertions only

- **807–809** fresh install: assert `slice-executor-mid.md` `model: sonnet` / `effort: high`, `slice-executor-high.md` `model: opus` / `effort: high`, `design-drafter.md` `model: opus` / `effort: high`, and `.claude/agents/Explore.md` present with `model: haiku` / `effort: high` and `tools: Read, Grep, Glob`; reword the `ok` text ("fresh install follows the route defaults: mid sonnet@high, high opus@high, explore haiku@high").
- **820**: `sync-agents --check` passes on a fresh install (reword: "seeded route config matches live agents").
- **996–1046**: replace the preset / `executor-mode` matrix with the route matrix (keep each probe one `ok`/`bad` pair, same style):
  1. no `executors.toml` (`rm -f`) → `sync-agents` → mid `sonnet`/`high`, high `opus`/`high`, drafter `opus`/`high`, Explore `haiku`/`high`.
  2. `[claude.high]\nmodel = "fable"` → high file `model: fable` and drafter `model: fable`.
  3. `mode = "flex"` → `sync-agents --check` fails and its output contains `retired in workspace v53`.
  4. keep 1009–1012 (`[claude.low]` v23, `[codex.*]` v31) unchanged.
  5. `[claude.cheap]\nmodel = "claude-haiku-5-5"` → rejected (output contains `must be an Agent-tool alias`).
  6. `[claude.research]\neffort = "hgih"` → rejected (`effort must be one of`).
  7. `[claude.nope]\nmodel = "opus"` → rejected (`unknown route`).
  8. `executor-route` bare prints five rows (`grep -c` of `^(high|research|mid|cheap|explore) ` = 5) and `proxy=none`.
  9. with no `executors.toml`: `executor-route P1.DECOMP` → `route=high`, `tier=high`, `subagent_type=slice-executor-high`, `model=opus`, `effort=high`, `attribution=Claude Opus 5.5`; the research slice from line ~849 → `route=research`, `effort=medium`; a `docs` slice rated `low` (create one: `new-slice --phase P1 --slice P1.S9 --name "docs probe" --kind docs --risk low`) → `route=cheap`, `tier=mid`, `subagent_type=slice-executor-mid`, `model=sonnet` (inherited), `pass_model=yes`; the same with `--retry` → `route=high`, `attempt=2`, `reason=second attempt`.
  10. `[claude.cheap]\nmodel = "haiku"\neffort = "high"` → the docs slice resolves `model=haiku`, `attribution=Claude Haiku 5.5`; `ANTHROPIC_BASE_URL=http://127.0.0.1:10100` on the same call → `model=sonnet` and a `fallback=` line; `--explore` under it → `model=sonnet`; `--drafter` → `subagent_type=design-drafter`, `model=opus`.
  11. `CLAUDE_CODE_EFFORT_LEVEL=high` on `executor-route P1.DECOMP` → a `warning=CLAUDE_CODE_EFFORT_LEVEL` line.
  12. `cp "$REPO_ROOT/executors.toml" "$F/executors.toml"` → `sync-agents` → `executor-route` bare shows the `cheap` row `haiku` `high` from `executors.toml` and `agent files: in sync`.
  13. `executor-mode` is gone: `python3 scripts/workflow.py executor-mode 2>&1` fails (argparse `invalid choice`).
- Drop the `executor-mode` probes (1019–1044) and the `cmp -s "$REPO_ROOT/executors.toml"` round trip (S5 adds the derived-seed check). Leave `DUAL_FIXED` (~1137) alone: it still passes while the artifact embeds the live file verbatim. Reword **1094** ("tracked flex selection" → "tracked route selection").
- Leave the agent-body pins (440–560) to S3 and everything about skills to S4.

## Validation (run all; record each in the verdict block)

1. `python3 -m py_compile scripts/workflow.py`
2. `python3 scripts/workflow.py sync-agents` (expect `updated:` for the three tier/drafter files — `xhigh` → `high` — and `Explore.md` in sync), then `python3 scripts/workflow.py sync-agents --check` → in sync, exit 0.
3. `python3 scripts/workflow.py executor-route` (bare); `executor-route P32.DECOMP`, `P32.REVIEW` (both `high`), `P32.S2` (`mid`), `P32.S6` (`cheap`, `haiku`), `P32.S6 --retry` (`high`, `attempt=2`), `--drafter`, `--explore`; `ANTHROPIC_BASE_URL=http://127.0.0.1:10100 python3 scripts/workflow.py executor-route P32.S6` → `model=sonnet` + `fallback=`; `CLAUDE_CODE_EFFORT_LEVEL=high python3 scripts/workflow.py executor-route P32.S2` → the warning line. Paste the bare table and one slice printout into `result.md`.
4. `printf 'mode = "flex"\n' > /tmp/x.toml` is not the way — probe the rejections in a throwaway copy of the repo (`cp -R` to a temp dir, or use the smoke suite's fixture), never by editing the live `executors.toml` to a bad state and leaving it.
5. `python3 scripts/workflow.py validate` → exit 0 (the two pre-existing warnings are fine).
6. `python3 installer/build.py` then `python3 installer/build.py --check` → clean.
7. `bash tests/retrofit_smoke.sh` — **once, in the foreground, as the only command in its Bash call** (a chained prefix stalls it). Every failure is either fixed here (engine, `executors.toml`, `Explore.md`, the installer lines above, your own assertions) or named in `result.md` with its owning slice: S3 (the agent `tools:` line pin at 553 breaks only when S3 adds `Agent` — it should still pass now), S4 (skill text), S5 (seed derivation / `DUAL_FIXED`, nested rename of `Explore`), S6 (CHANGELOG `Migration notes`, READMEs). Expect **zero** failures outside those owners; an unexplained one is yours.
8. `grep -rn 'economy\|flex\|executor-mode' scripts/workflow.py executors.toml installer/main.py installer/build.py` → nothing but, at most, the v53 migration message text.

## `result.md` and `phase.md`

- `result.md`: verdict block first (`status`, `tier: high`, `summary`, `files_changed`, `validation`, `deviations` — the installer pull-forward and anything else — `doc_impact`), then the bare `executor-route` table, one slice printout, the smoke run's PASS/FAIL count and the named leftovers by owning slice.
- `phase.md`: remove the S1-only notes you consumed (engine anchors, the Explore sequencing note, the S1 smoke list); keep H1–H6 where other slices are tagged; add notes **for S2** (the exact event-shape expectations are D5's; tell S2 the row names and that `executor-route`'s `route=`/`model=`/`effort=` lines are what the orchestrator will pass to `record-dispatch`), **for S3** (`Explore.md` exists with D8's frontmatter and a minimal body to finalize; the `tools:` pin at 553), **for S4** (the exact `executor-route` output keys, `pass_model` / `pass_effort` semantics, the `fallback=` and `warning=` lines, that `--drafter` / `--explore` exist, that `executor-mode` is gone from the engine so the skill rename must land before anyone runs `/executor-mode`), **for S5** (the three installer entries already added; what remains: version, seed derivation keyed on the `# cheap-route: begin/end` markers, the full-suite baseline, `DUAL_FIXED`, the nested `Explore` rename check; the smoke leftovers you named). Append `## Doc impact` lines: `operations.md: Executor tiers — the route table replaces the economy/flex presets; executors.toml is per-row; executor-route prints the routing decision; the cheap route and Explore row (P32.S1)`, `decisions.md: one engine-owned route table with dispatch-time model/effort supersedes the v29/v31 presets, v45 executor-mode and v46 "haiku never a tier" (P32.S1)`, `architecture.md: agent set gains Explore.md; model/effort resolved by the engine per route at dispatch time, frontmatter the fallback (P32.S1)`. Rewrite `## Now` (≤ 15 lines) for S2.

## Dispatch

This slice runs by today's rule (D12): `slice-executor-high` from its frontmatter. Record in the verdict block `- tier: high` as usual; `model`/`effort` lines are not yet required of you (S3 introduces them) — add `- model: opus` / `- effort: xhigh` anyway if you know them from this line, since that is what you were dispatched on.
