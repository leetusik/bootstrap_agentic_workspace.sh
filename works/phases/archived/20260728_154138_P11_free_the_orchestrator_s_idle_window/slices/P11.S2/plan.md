# P11.S2 — Refresh the stale README tier facts

## Context

Both READMEs still describe the executor tiers as they were before `b26d622` re-cut the presets.
`economy` is now the shipped default (low = sonnet@medium, mid = sonnet@high, high = opus@high), but
the READMEs still call `slice-executor-mid` **Opus** — and the English one additionally calls `mid`
"the default", which was never right: `high` is the catch-all for any slice not rated exactly `low`
or `medium`.

This is the second half of `P11`'s intent — targeted repair of known-stale content, not an accuracy
audit. `P11.DECOMP` verified by grep that neither README mentions the prefetch, the idle window, or
`slice-planner`, so `P11.S1`'s deletion falsified nothing here and the English agent inventory
(`README.en.md:172-173`) is already correct.

**READMEs are not embedded machinery** — they are absent from `FIXED_LIVE_FILES`, so this slice
does **no rebuild**, **no `WORKSPACE_VERSION` bump**, and **no CHANGELOG entry** (`P11.S1`
deliberately dropped a drafted v20 bullet about these fixes for that reason: the CHANGELOG is what
adopting workspaces read on `--update`, and they never receive the READMEs).

Dispatch: **`slice-executor-low`** (`risk: low`). The tier is a literal plan-follower, so every edit
below is given as an exact string replacement. Anything that does not match verbatim is an
`escalate`, not an improvisation.

## Work — three exact replacements

### 1. `README.md` (Korean) line 154 — one table cell

OLD:
```
| `slice-executor-mid` | Opus | 중간 위험 slice |
```
NEW:
```
| `slice-executor-mid` | Sonnet | 중간 위험 slice |
```

Leave the `low` and `high` rows alone — both are already correct — and leave lines 166-167 alone,
which already state the `economy`/`flex` presets accurately.

### 2. `README.en.md` line 295 — wrong model and a wrong claim

OLD:
```
for mechanical low-risk slices), `slice-executor-mid` (opus — medium-risk, the default), and
```
NEW:
```
for mechanical low-risk slices), `slice-executor-mid` (sonnet — medium-risk), and
```

### 3. `README.en.md` line 296 — put the catch-all where it belongs

OLD:
```
`slice-executor-high` (opus — decomposition, high-risk slices, and the phase review, which it runs in
```
NEW:
```
`slice-executor-high` (opus — decomposition, high-risk slices, anything not rated `low` or `medium`, and the phase review, which it runs in
```

This third edit is English-only on purpose: the English prose actively asserted that `mid` is "the
default", so removing that leaves a gap worth filling. The Korean table makes no such claim — it
just lists what each tier handles — so correcting one cell is the whole fix there.

## Validation

| Check | Expectation |
|---|---|
| `grep -n 'slice-executor-mid' README.md README.en.md` | Korean row reads `Sonnet`; English reads `(sonnet — medium-risk)`; **no** `Opus`/`opus` next to `mid` in either |
| `grep -c 'the default), and' README.en.md` | 0 |
| `grep -n "anything not rated" README.en.md` | one hit, on the `slice-executor-high` line |
| `git diff --stat` | exactly two files changed — `README.md`, `README.en.md`. **Nothing else**: no `bootstrap_agentic_workspace.sh`, no `installer/`, no `CHANGELOG.md`, no `.claude/`, no `docs/` |
| `python3 installer/build.py --check` | still in sync — and it must be **unchanged**, i.e. you did not run `python3 installer/build.py`. READMEs are not shipped machinery; rebuilding here would be wrong |
| `python3 scripts/workflow.py validate` | passes |
| Consistency read | Re-read `README.md:148-167` and `README.en.md:293-305` and confirm the tier facts now agree with `executors.toml`'s documented `economy` default and with each other |

## Record

- `result.md` — the three replacements as applied, the validation table with real outcomes, and an
  explicit note that no rebuild/bump/CHANGELOG entry was made and why.
- `phase.md` — a short cross-slice note. **No Doc impact line**: the READMEs are not durable docs,
  and this changes no durable truth — `P11.S1` already recorded the `operations.md` and
  `decisions.md` impacts for `REVIEW` to consolidate.
- No `doc-new-version`, no edits under `docs/`, no commits, no status transitions.

## Non-goals

- No other README changes — no idle-window or prefetch prose (`P11.DECOMP` decided against it: the
  READMEs document the operator-facing surface, and P11's whole point is to demote that practice
  from a named procedure to an optional judgment; `operations.md` is its home).
- No rebuild, no version bump, no CHANGELOG entry.
- No machinery, contract, skill, or `docs/` edits of any kind.
