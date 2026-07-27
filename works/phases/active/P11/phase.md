# Phase P11: Free the orchestrator's idle window

_Intent: see [intent.md](intent.md)._

## Objective

Drop the bespoke slice-planner agent, recast the do-whole-phase prefetch from a mandated procedure into an optional use of the executor's idle window that the orchestrator sizes per slice, and refresh the stale README sections.

## Context

P10 (workspace **v19**) shipped two things: a bespoke `.claude/agents/slice-planner.md` agent and a
`do-whole-phase` rule that reads as a mandated sequence — dispatch executor N, then *immediately*
dispatch the planner for N+1, with five hard skip conditions. The operator's judgment (see
`intent.md`) is that the mechanism should not be prescribed at all: the orchestrator should be
*free* — dispatch the built-in `Explore` agent, read inline itself, think, or simply wait — and the
rule's job is to **permit and encourage** use of the idle window, not to script it.

P11 therefore does two independent things on top of v19, shipping as workspace **v20**:

1. Delete the agent and rewrite the rule as a permission (keeping only the invariants that protect
   the loop's correctness; demoting the five skip conditions to guidance).
2. Repair the two known-stale README facts — targeted repair, **not** an accuracy audit.

Out of scope for the whole phase: P10's copy-based plan-capture path (harness plan file → `plan.md`)
stays exactly as it is.

## Decomposition

Two middle slices — the split follows the two intent items, which share no files and have very
different risk profiles (contract surgery vs. two literal string replacements). Keeping them
separate keeps the cheap slice cheap and the dangerous one narrowly reviewable.

| Slice | Kind | Risk | Order | Depends on | Scope |
|---|---|---|---|---|---|
| `P11.S1` | implementation | **high** | 1 | — | Delete `slice-planner`, rewrite the prefetch rule as an optional idle-window practice, mirror into both contracts, ship v20 (CHANGELOG + rebuild) |
| `P11.S2` | implementation | **low** | 2 | `P11.S1` | Two factual README corrections (`slice-executor-mid` is Sonnet, not Opus) |

`P11.DECOMP` (order 0) and `P11.REVIEW` (order 9999) already existed; `REVIEW`'s `order` untouched.

### `P11.S1` — Drop `slice-planner`; make idle-window preparation optional (`risk: high`)

Surfaces it owns:

- **Delete** `.claude/agents/slice-planner.md`.
- **Four installer edits** (see *Findings* — this is the trap): remove from `FIXED_LIVE_FILES`
  (`installer/build.py:49`), remove the explicit `write_text` + its 3-line comment
  (`installer/main.py:484-488`), remove from `MANAGED_FILES` (`installer/main.py:80`), **and add** to
  `OBSOLETE_MACHINERY` (`installer/main.py:517-523`).
- **Rewrite** the `do-whole-phase` prefetch bullet (`.claude/skills/do-whole-phase/SKILL.md:22-29`)
  as a **permission**: the executor's run is idle time on the main thread and the orchestrator
  **may** use it to prepare the next slice — by dispatching the built-in `Explore` agent, by reading
  inline, by thinking it through, or by simply waiting. No named required mechanism, no mandated
  sequence. Say when it tends to pay off and when it does not; leave the call to the orchestrator
  per slice.
- **Keep hard** only what protects the loop: read-only; never block (the executor's completion
  notification always wins); discard on any verdict other than `done`; drafts live in the session
  scratchpad and never become — or are read as — an approved plan; no second executor; the operator's
  approval gate does not move.
- **Demote to guidance** P10's five skip conditions (`DECOMP`, `REVIEW`, already-`ready`, `pending`,
  blast-radius overlap) — "cases where preparing ahead is usually pointless or unsafe".
- **Preserve the useful part of the deleted agent's prompt** by folding a condensed version of its
  brief contract into the skill itself — bounded advisory brief; blast-radius staleness labelling;
  never a plan, never a file dump — so the value survives the file's deletion without creating a new
  managed surface. Keep it short: it is guidance for an optional path.
- **Amend the dispatch bullet's carve-out** (`SKILL.md:21`) so it no longer names `slice-planner`.
- **Mirror into `CLAUDE.md` and `AGENTS.md`**, bodies byte-equal: the *Driving This Workspace*
  clause at `:19` (the "with one exception, scoped to `do-whole-phase` by name: the read-only
  `slice-planner` prefetch…" sentence) and the Hard Rules bullet at `:62`.
- **Ship v20:** `WORKSPACE_VERSION` 19 → 20 (`installer/main.py:38`), a new `## v20` CHANGELOG
  section whose **Migration notes must tell v19 workspaces to delete
  `.claude/agents/slice-planner.md` by hand**, then `python3 installer/build.py` and commit the
  rebuilt artifact.
- **Doc impact notes only** (no `doc-new-version`): one for `operations.md`, one for `decisions.md`.

Rated **high** for the same reason as `P10.S1`: the wording being edited sits inside the paragraphs
that carry the delegation rule, the approval gate, `auto`'s safety halts, and the escalation ladder —
and this time the edit *relaxes* a rule, which is precisely where an over-broad edit does damage.

### `P11.S2` — Refresh the stale README tier facts (`risk: low`)

Exactly two factual corrections, one per file:

- `README.md:154` — the Korean tier table cell: `| slice-executor-mid | Opus | …` → **Sonnet**.
- `README.en.md:295` — `slice-executor-mid` (opus — medium-risk, the default)` → **sonnet**; the
  trailing "the default" claim is also wrong (the *fallback* tier is `high`) and should go with it.

Nothing else. No rebuild, no `WORKSPACE_VERSION` bump, no CHANGELOG entry — the READMEs are **not**
embedded machinery (not in `FIXED_LIVE_FILES`), so the S2 plan must say this explicitly so its
executor does not "helpfully" rebuild.

**Rated `low` deliberately, and the plan's `low`-only-if condition is satisfied**: `DECOMP` verified
by grep (see *Findings*) that the `slice-planner` deletion makes **no** README line false, so the
open-ended "unless S1's deletion made a specific line false" clause is already closed — S2 is two
named string replacements with no discovery work left. The `low` tier is a literal plan-follower, so
`P11.S2`'s plan must name both exact strings and their replacements, and instruct the executor to
report (not fix) anything else it notices. `--depends-on P11.S1` is ordering only, so the READMEs are
corrected against the final tree.

## Findings & Notes

### Verified during decomposition

- **Removing the agent is FOUR installer edits, not three.** P10 added three touchpoints, but a
  fourth must be *added*: `.claude/agents/slice-planner.md` has to go into **`OBSOLETE_MACHINERY`**
  (`installer/main.py:517-523`, keeping the existing one-line `# retired in vNN — <why>` comment
  style). `--update` **never deletes**; that list is the only channel by which a workspace already on
  v19 is told to remove the file by hand (`flag_obsolete_machinery()` pushes it into
  `UPDATE_SUMMARY["stale"]`). `flag_stale_skills()` does **not** cover it — that function only walks
  `.claude/skills/` + `.agents/skills/` dirs, not `.claude/agents/`. Without the
  `OBSOLETE_MACHINERY` entry every adopting workspace silently keeps a dead agent file.
  The three removals are: `installer/build.py:49` (`FIXED_LIVE_FILES`), `installer/main.py:484-488`
  (the explicit `write_text` **plus** its three-line explanatory comment — it is written outside the
  tier loop on purpose), and `installer/main.py:80` (`MANAGED_FILES`).
- **The English README's agent inventory self-heals.** `README.en.md:172-173` says "the three
  risk-routed `slice-executor` tier subagents … sonnet / sonnet / opus … (the `economy` mode)" and
  never mentioned `slice-planner` — so the "under-count" P10's review flagged simply disappears when
  the agent is deleted, and those lines are already factually correct. `README.en.md:303-304` also
  already carries the correct `economy`/`flex` presets.
- **What is actually stale is the tier model in prose, in two places:**
  - `README.en.md:295` still calls `slice-executor-mid` "opus — medium-risk, **the default**". Both
    halves are wrong: the model is sonnet under the shipped `economy` default, and `mid` is not "the
    default" — `high` is the catch-all for anything not exactly `low`/`medium`.
  - `README.md:154` (Korean table) still lists `slice-executor-mid` = Opus; should be Sonnet. Stale
    since `b26d622` re-cut the presets. `README.md:166-167` already states the correct presets, so
    the table contradicts the prose two screens below it.
- **Neither README mentions the prefetch, the idle window, or `slice-planner` at all** (verified by
  grep for `prefetch|idle|pipelin|parallel|slice-planner|\.claude/agents` in `README.en.md`, and the
  Korean equivalents in `README.md`). So intent item 1 forces **no** README change, and the only
  `.claude/agents/` mention (`README.en.md:173`) is already correct post-deletion.
- **DECISION — do not add README prose about the idle window.** The plan left this as a judgment
  call for `DECOMP`; the call is **no**. The READMEs document the operator-facing surface (skills,
  tiers, state machine, commands); the idle-window practice is internal orchestrator behaviour with
  no operator knob, and P11's entire point is to *demote* it from a named procedure to an optional
  judgment — documenting it in the README would re-elevate it to a headline feature and work against
  the intent. It also keeps `P11.S2` mechanical enough to stay `low`. `operations.md` (consolidated
  at `REVIEW`) remains its correct home.
- **READMEs are not embedded machinery** — absent from `FIXED_LIVE_FILES`
  (`installer/build.py:42-56`) — so a README-only slice needs **no rebuild and no version bump**.
  Only `P11.S1` carries the rebuild obligation.
- **The `EXECUTOR_TIERS` gap dissolves rather than needing a fix.** `scripts/workflow.py:30` defines
  `EXECUTOR_TIERS = ("low", "mid", "high")` and `sync-agents` only ever touches those three files;
  `slice-planner` was outside it by construction (no `executors.toml` knob, no drift check). Deleting
  the agent removes the anomaly — no `workflow.py` change is needed, and `workflow.py` contains no
  reference to `slice-planner` at all.
- **There is no Codex counterpart to remove.** `do-whole-phase` is Claude Code only — there is no
  `.agents/skills/do-whole-phase/` and no `.codex/agents/slice-planner.toml` — so `P11.S1` touches
  exactly one `SKILL.md`.
- **Full reference inventory for `slice-planner`** (excluding `.git`, generated `works/` state, and
  P10/P11 slice folders, which are history): `.claude/agents/slice-planner.md`,
  `.claude/skills/do-whole-phase/SKILL.md`, `CLAUDE.md`, `AGENTS.md`, `CHANGELOG.md` (v19 section —
  **history, leave it**), `installer/build.py`, `installer/main.py`,
  `bootstrap_agentic_workspace.sh` (regenerated, never hand-edited), `docs/current/operations.md`,
  `docs/current/decisions.md`, `docs/index.json` and the two v19 doc versions (**`REVIEW`'s job**;
  `docs/versions/` is never patched).
- **Baseline is green** at decomposition time: `validate` passes and
  `python3 installer/build.py --check` reports in sync, so any drift a later slice sees is its own.

### Docs that `REVIEW` must supersede (middle slices only append notes)

- `docs/current/operations.md` — has a whole section *Pipelined slice planning — the `slice-planner`
  prefetch (since v19)* (`:235-262`), plus the v19 sentence in the running-the-workflow paragraph
  (`:33`), the update write-policy mention (`:81`), and the two-vs-three-touchpoint lesson (`:356`).
  The new version should recast this as an **optional idle-window practice** with no named mechanism.
- `docs/current/decisions.md` — the v0024 decision (`:22-36`) whose enforcement claim, "read-only **by
  tool allowlist, not prose**", P11 **invalidates**. The new version must say the weakened guarantee
  plainly: with no bespoke agent, `Explore` has `Bash` and inline research is bounded only by the
  orchestrator's own discipline — read-only is now a discipline, not an allowlist guarantee. Supersede
  the claim, do not carry it forward.

## Constraints

Inherited by both middle slices:

- **Never pre-fill another slice's `plan.md`.** Each slice's plan is written by the orchestrator at
  that slice's own turn.
- **`CLAUDE.md` and `AGENTS.md` bodies must stay byte-equal** — `installer/build.py` asserts it. Any
  rule change lands in both, identically, headers excepted.
- **The two `do-next-slice` skill copies stay byte-identical apart from frontmatter — and are
  untouched by this phase.** `do-next-slice` never prefetches; nothing here changes that.
- **Rebuild obligation is `P11.S1`'s alone:** after editing embedded machinery
  (`.claude/*`, `.agents/*`, `.codex/*`, `scripts/workflow.py`, `works/templates/*`, the contract),
  run `python3 installer/build.py` and commit the rebuilt `bootstrap_agentic_workspace.sh` in the
  same commit; `.githooks/pre-commit` enforces `--check`. `P11.S2` (READMEs only) must **not**
  rebuild or bump the version.
- **Durable docs are versioned once, at `REVIEW`.** Middle slices append one-line "Doc impact" notes
  to the list below and never run `doc-new-version`; `docs/current/*.md` is generated and never
  hand-edited; `docs/versions/` is never patched.
- **Never hand-edit `bootstrap_agentic_workspace.sh`** — it is a build product.
- **CHANGELOG history is append-only:** the v19 section keeps describing what v19 shipped; v20 gets
  its own new section on top.
- **P10's copy-based plan capture is out of scope** and must not be altered by either slice.
- **One release:** this phase ships as workspace **v20**, bumped exactly once, in `P11.S1`.

## Doc impact

_One line per durable-truth change; `REVIEW` consolidates these into doc versions._

-

## Open Questions

- None. (The one judgment call `DECOMP` was asked to settle — whether the READMEs should gain a
  sentence about the idle window — is decided **no**; see *Findings*.)
