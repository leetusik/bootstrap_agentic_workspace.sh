# P11.DECOMP — result

Decomposed "Free the orchestrator's idle window" into **two** middle slices, exactly the breakdown
the plan recommended. Seeded `works/phases/active/P11/phase.md` with the context, the breakdown, the
verified findings, and the constraints both slices inherit. No implementation, no pre-filled plans,
no doc versions.

## Slices created

| Slice | Kind | Risk | Order | Depends on | Name |
|---|---|---|---|---|---|
| `P11.S1` | `implementation` | `high` | 1 | — | Drop slice-planner; make idle-window preparation optional |
| `P11.S2` | `implementation` | `low` | 2 | `P11.S1` | Refresh the stale README tier facts |

Both are **bare folders** — `slice.json` only, no `plan.md`. `P11.REVIEW` was left untouched
(`order` 9999).

Commands run:

```
python3 scripts/workflow.py new-slice --phase P11 --slice P11.S1 \
  --name "Drop slice-planner; make idle-window preparation optional" \
  --kind implementation --risk high --order 1
python3 scripts/workflow.py new-slice --phase P11 --slice P11.S2 \
  --name "Refresh the stale README tier facts" \
  --kind implementation --risk low --order 2 --depends-on P11.S1
```

## Decisions this slice had to make

**1. `P11.S2` is rated `low`, not `medium`.** The plan made this conditional: `low` only if the
slice's plan can name the exact lines and replacements, `medium` if the wording needs bilingual
judgment. I verified by grep that the `slice-planner` deletion makes **no** README line false —
neither README mentions the prefetch, the idle window, `slice-planner`, or anything else P11 removes;
the single `.claude/agents/` mention (`README.en.md:172-173`) counts only the three
`slice-executor` tiers and is already correct. That closes the open-ended "unless S1's deletion made
a specific line false" clause *at decomposition time*, so nothing discovery-shaped is left. What
remains is two literal string replacements:

- `README.md:154` — Korean tier table cell `| slice-executor-mid | Opus |` → **Sonnet**
- `README.en.md:295` — ``slice-executor-mid` (opus — medium-risk, the default)` → **sonnet**, and
  drop "the default" too (it is independently wrong: `high`, not `mid`, is the catch-all tier)

The Korean side carries zero prose — it is one table cell — so there is no bilingual wording
judgment to make. Caveat for the `P11.S2` planner, recorded in `phase.md`: the `low` tier is a
literal plan-follower, so its `plan.md` **must** spell out both exact strings and their replacements
and tell the executor to *report*, not fix, anything else it notices.

**2. No README sentence about the idle window.** The plan explicitly left this judgment call to
`DECOMP`. The call is **no**, recorded in `phase.md` with the reasoning: the READMEs document the
operator-facing surface, the idle-window practice is internal orchestrator behaviour with no
operator knob, and adding it would re-elevate to a headline feature exactly the thing this phase
demotes from procedure to option. `operations.md` (consolidated at `REVIEW`) stays its home.

No other deviation from the recommended breakdown.

## Findings carried into `phase.md`

All of the plan's §2 findings were re-verified against the tree, and two were sharpened:

- **The four installer edits are confirmed**, with exact sites: remove
  `installer/build.py:49` (`FIXED_LIVE_FILES`), `installer/main.py:80` (`MANAGED_FILES`),
  `installer/main.py:484-488` (the explicit `write_text` **plus** its three-line explanatory comment,
  which sits outside the tier loop on purpose) — and **add** `.claude/agents/slice-planner.md` to
  `OBSOLETE_MACHINERY` (`installer/main.py:517-523`, `# retired in vNN — <why>` comment style).
  Sharpening: `flag_stale_skills()` cannot cover this — it walks only `.claude/skills/` and
  `.agents/skills/` **dirs**, never `.claude/agents/` — so `OBSOLETE_MACHINERY` +
  `flag_obsolete_machinery()` is genuinely the only channel telling a v19 workspace to delete the
  file by hand. Without it every adopting workspace silently keeps a dead agent.
- **The English README's stale spot is a double error, not a single one**: `README.en.md:295` calls
  `slice-executor-mid` "opus — medium-risk, **the default**"; the model is wrong *and* `mid` is not
  the default tier (`high` is the catch-all for anything not exactly `low`/`medium`).
- **The `EXECUTOR_TIERS` gap needs no code change at all** — `scripts/workflow.py` contains no
  `slice-planner` reference whatsoever (`EXECUTOR_TIERS = ("low", "mid", "high")` at `:30`), so the
  anomaly dissolves purely by deleting the agent.
- **Nothing to remove on the Codex side** — `do-whole-phase` is Claude Code only (no
  `.agents/skills/do-whole-phase/`, no `.codex/agents/slice-planner.toml`), so `P11.S1` edits exactly
  one `SKILL.md`.
- A **full reference inventory** for `slice-planner` is in `phase.md`, marking which hits are
  `P11.S1`'s, which are `REVIEW`'s (`docs/current/operations.md`, `docs/current/decisions.md`,
  `docs/index.json`, the two v19 doc versions), and which are history to leave alone (the v19
  `CHANGELOG.md` section, P10's slice folders, generated `works/` state).
- **Baseline was green before this slice**: `validate` clean and `installer/build.py --check` in
  sync, so any drift a later slice encounters is its own.

`REVIEW`'s two doc targets are named in `phase.md`: `operations.md` (recast the whole *Pipelined
slice planning* section as an optional idle-window practice) and `decisions.md` (supersede v0024's
"read-only by tool allowlist, not prose" claim — with no bespoke agent, `Explore` has `Bash` and
inline research is bounded only by the orchestrator's discipline).

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py validate` | PASS — `Workflow validation passed.` |
| `python3 scripts/workflow.py next` | PASS — `current_slice=P11.DECOMP`, `next_slice=P11.S1` |
| `python3 installer/build.py --check` | PASS — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| `works/backlog.md` ordering | PASS — `P11.DECOMP`, `P11.S1`, `P11.S2`, `P11.REVIEW` in order (lines 63-66) |

## Deviations from `plan.md`

None. The recommended two-slice breakdown was adopted as-is; both conditional judgments the plan
delegated (`P11.S2`'s risk rating, the README idle-window sentence) were decided and recorded above
and in `phase.md`.

## Doc impact

None from this slice — decomposition changed no durable truth. The `## Doc impact` list in
`phase.md` is seeded empty for `P11.S1`/`P11.S2` to append to.

## For the next planner

- `P11.S1` is the whole risk of the phase; its plan should quote the exact sentences being replaced
  in `SKILL.md:21`, `SKILL.md:22-29`, `CLAUDE.md:19`, `CLAUDE.md:62` (and the `AGENTS.md` twins) so
  the relaxation stays inside the prefetch clause and does not bleed into the delegation rule, the
  approval gate, `auto`'s safety halts, or the escalation ladder that share those paragraphs.
- The v20 CHANGELOG **Migration notes** line is a required deliverable of `P11.S1`, not a nicety —
  it is the human-readable half of the `OBSOLETE_MACHINERY` flag.
- `P11.S2` must be told, in its plan, **not** to rebuild and **not** to bump `WORKSPACE_VERSION`.
