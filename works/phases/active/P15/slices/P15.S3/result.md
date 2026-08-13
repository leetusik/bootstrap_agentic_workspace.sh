# Result — P15.S3: Strip Codex from the contract and Claude skill prose

**Status: done.** `CLAUDE.md`, the 11 `.claude/**` files, and the two pinned installer header
literals changed together, and the artifact was rebuilt and **executed** (fresh install, retrofit,
`--update`) rather than only compiled. **No commit was made.**

The goal was prose, not deletion: the contract had to come out reading as a document written for one
harness, with no holes where the Codex half used to be. Four passages were rewritten rather than
cut, and one rule was deliberately **generalized** rather than deleted — see *Judgment calls*.

## What changed

### The atomic three (header coupling)

| File | Change |
| --- | --- |
| `CLAUDE.md` | Deleted line 3 (`> Equivalent to \`AGENTS.md\`. …`) and its blank line. |
| `installer/build.py:59` | `CLAUDE_HDR` → `"# CLAUDE.md\n\n"`. |
| `installer/main.py:460` | `write_text("CLAUDE.md", f"# CLAUDE.md\n\n{CONTRACT_BODY}")`. |

The extracted body still starts exactly at `## Agent Contract` — proved below by three independent
install paths each producing a `CLAUDE.md` byte-identical to this repo's. A repo-wide
`grep -rn 'Equivalent to'` (including `tests/`, `README*`, `docs/retrofit-guide.md`, and the
artifact) returns zero, so nothing else pinned that line.

### `CLAUDE.md` — the rewrites

- **Driving This Workspace.** Lead-in "so they work natively in either tool" → "so there are two
  ways in", which is what the (now two-entry) list actually enumerates: Claude Code, and any agent /
  CI. The Codex bullet is gone; the Claude Code bullet is unchanged and now reads as the primary
  path rather than one of two.
- **Orchestrator and executor.** "Both tools ship …" → "`do-next-slice` and `do-whole-phase` are an
  orchestrator/worker split". "retains opt-in" → "supports opt-in" (`retains` only made sense as a
  contrast with Codex's rejection); "its gated modes" → "the gated modes". The Codex automatic-only
  sentence is deleted. The `ready`-slice sentence keeps its upgrade justification without "either
  tool"/"cross-tool": "A `ready` slice — whether `plan only` wrote it or a workspace upgraded from an
  older version carried it in — stays executable as-is".
- **Tier paths + preset matrix.** `(.claude/agents/slice-executor-{mid,high}.md)`; the `Claude:` /
  `Codex:` qualifiers dropped **entirely**, so `economy` is `sonnet@high` / `opus@high` and `flex` is
  `sonnet@xhigh` / `opus@xhigh` — checked against `EXECUTOR_PRESETS` in post-S1 `scripts/workflow.py`.
- Executor dispatch: kept "Claude Code dispatches it as a background Agent task", dropped the Codex
  clause. `design-cowork` path → `` (`.claude/skills/design-cowork/`) ``.
- Slice-context rule: "Codex and either tool's automatic path write it inline, while Claude Code's
  gated modes copy…" → "the automatic path writes it inline, while the gated modes copy…".
- Idle-window rule: "Claude's gate still does not move; Codex remains automatic-only." → "The gate
  still does not move."
- `ready` rule: "Claude Code's `plan only` writes…; Codex cannot create `ready` slices…" → "`plan
  only` writes an operator-approved `plan.md` and sets the slice `ready`."
- Embedded-machinery list: dropped `.agents/*`, `.codex/*`.
- Commit convention: dropped "in either tool"; deleted the "in another tool … `<noreply@openai.com>`"
  clause; "carry over another tool's trailer" → "carry over a trailer from another session".
- **The design hard rule** — collapsed from `shared invariants → Claude Code branch → Codex branch →
  neither branch` to a single rule. "harness-native" dropped; "Shared invariants come first:" →
  "The invariants:" (nothing left to be shared against); the "**Claude Code branch:**" label removed
  and its content inlined as the rule body; the Codex branch deleted **except** its stranded
  harness-independent sentence, which was rescued verbatim into the invariants: *"Approval must be
  literal; revisions create new immutable superseding rounds; later slices verify the running product
  in a real browser."* Closing "Neither branch may invent…" → "**Never** invent…". `DesignSync` still
  appears (once) for `P15.S4`'s assertion.

### The 11 `.claude/**` files

- **7 one-line `AGENTS.md` co-mentions dropped**: `slice-executor-{mid,high}.md` (2 each),
  `create-phase`, `do-next-slice`, `do-whole-phase`, `parallel-phase`, `review-phase` SKILLs.
  `do-whole-phase` L10 "Read `AGENTS.md` and the phase's `phase.md`" and `do-next-slice` L10 "read
  `AGENTS.md` (or `CLAUDE.md`)" became plain `CLAUDE.md` reads — they were the two that would have
  told an agent to read a file that no longer ships.
- **`design-cowork/SKILL.md`** — the "**Claude Code only.** In Codex, DesignSync does not exist…"
  bullet deleted whole. The preceding "DesignSync is main-thread only" bullet already carries the
  rule; nothing else restructured.
- **`explain/SKILL.md`** (vendored) — deleted the step-2a "**On Codex**, `workspace-write` blocks
  outbound network…" paragraph (the surrounding flow still reads: the hosted-vs-self-hosted
  paragraph now runs straight into numbered step 1) and the `<noreply@openai.com>` attribution
  parenthetical. **The divergence from upstream is recorded in the file's own re-vendor comment**,
  which already enumerated the two pre-existing de-plugin-ification divergences — the only place a
  future re-vendor will actually look.
- **`retrofit/SKILL.md`** — rewritten against the installer **S2 landed**, not the old text. Step 4
  now says it "additively merges `.claude/settings.json` and `CLAUDE.md` (marked section +
  `CLAUDE.workspace.md` sidecar) — the only contract file it writes"; step 5 drops the
  `AGENTS.workspace.md` sidecar entirely. Verified against a real retrofit (below), not just against
  `main.py`.
- **`update-workspace/SKILL.md`** — L12's OVERWRITE list now matches `_is_machinery()` exactly
  (`scripts/workflow.py`, `.claude/agents/`, `.claude/skills/`, `works/templates/*`) and refreshes
  "the `CLAUDE.md` contract". L61 was **actively wrong** and was rewritten: the pre-v23 note keeps
  only its `.claude` half, and a new pre-v31 note quotes `S1`'s real error string verbatim
  (`executors.toml line <n>: Codex support was removed in workspace v31 — this workspace ships Claude
  Code only, so drop this section`) and states that `--update` flags `.agents`, `.codex`, `AGENTS.md`
  and `AGENTS.workspace.md` and never deletes.

`.claude/settings.json` and `settings.local.json` were clean, as the plan said.

## Validation

Every command was actually run. **The artifact was executed, not just built** — S2's standing rule,
which applies here because this slice changes what `main.py` writes.

| # | Command | Outcome |
| --- | --- | --- |
| 1 | `python3 installer/build.py` | **pass** — `wrote bootstrap_agentic_workspace.sh (323142 bytes)` |
| 2 | `python3 installer/build.py --check` | **pass** — `OK: … in sync with installer/ source` |
| 3 | `python3 scripts/workflow.py validate` (this repo) | **pass** |
| 4 | Fresh install of the built artifact into `<scratch>/s3fresh2` | **pass**, exit 0, no import-time `RuntimeError`/`KeyError` |
| 5 | Installed `CLAUDE.md` header | **pass** — `# CLAUDE.md` `\n\n` `## Agent Contract`, no blockquote (od-verified); **byte-identical to the repo's `CLAUDE.md`** |
| 6 | `validate` + `sync-agents --check` in the fresh workspace | **pass** — `mid   sonnet @ xhigh` / `high  opus @ xhigh`, exit 0 |
| 7 | Retrofit into a repo seeded with its own `CLAUDE.md`, `AGENTS.md`, `src/app.py` | **pass**, exit 0, `merged (additive): CLAUDE.md`, 52 created |
| 8 | `CLAUDE.workspace.md` sidecar | **pass** — byte-identical to the repo's `CLAUDE.md` (new header); **no `AGENTS.workspace.md` written**; seeded `AGENTS.md` md5 unchanged |
| 9 | `--update` of a **pre-S3** install with the new artifact | **pass** — `CLAUDE.md (+13/-16)` refreshed to the new header, byte-identical to the repo's; `validate` passes afterwards |
| 10 | `--update` change-list as a scope oracle | **pass** — exactly **12** machinery files: `CLAUDE.md` + the 11 `.claude/**` files, nothing else |
| 11 | `grep -rn '\.agents/\|\.codex/\|AGENTS\.md' CLAUDE.md .claude/` | **1 deliberate hit** — see *Deviations* |
| 12 | `grep -rni 'codex\|openai\|gpt-' CLAUDE.md .claude/` | **2 deliberate hits** — see *Deviations* |
| 13 | `grep -rn 'both tools\|either tool\|cross-tool\|each tool\|another tool' CLAUDE.md .claude/` | **pass — zero** |
| 14 | `grep -c DesignSync CLAUDE.md` | **pass — 1** |
| 15 | `grep -rn 'Equivalent to'` repo-wide | **pass — zero** |

### 4-9 — why three install paths, not one

The plan asked for a fresh install. `CLAUDE.md` is written on **three** paths, all reading the same
changed literal, so all three were exercised: fresh (`write_text`), retrofit (`_merge_contract` →
`CLAUDE.workspace.md`), and `--update` (contract refresh). Each produced a file byte-identical to
this repo's `CLAUDE.md` — the strongest available evidence that `collect_contract_body()`'s
`claude[len(CLAUDE_HDR):]` slice still lands exactly on `## Agent Contract` rather than one line off.
An off-by-one there compiles fine and would have shipped a contract missing its first heading.

Test 10 doubles as an independent scope check: the update change-list named precisely the 12 files
this slice intended to touch.

### Artifact residue

`Codex` occurrences in `bootstrap_agentic_workspace.sh`: **28 → 19**. `S2` predicted 2; the
difference is fully accounted for and none of it is unfinished `S3` work — 5 are in
`installer/payloads/doc_bodies/*` (**`S5`**), 8 are `installer/main.py`'s own `OBSOLETE_MACHINERY`
migration comments (`S2`, embedded because `main.py` *is* the artifact), 2 are `workflow.py`'s
rejection strings (`S1`), and 4 are the two deliberate prose hits below. The realistic floor after
`S5` is 14, not 2. Recorded in `phase.md` so `S5`/`REVIEW` do not chase a phantom.

## Deviations from `plan.md`

**One, and it is the same gate-wording conflict `S2` hit — the plan's greps contradict the plan's own
body.**

The plan asks for zero hits on `codex|openai|gpt-` and on `.agents/|.codex/|AGENTS.md`, while its
§"The 11 `.claude/**` files" explicitly requires `update-workspace/SKILL.md` to "mention that
`--update` now flags `.agents`, `.codex`, `AGENTS.md`, and `AGENTS.workspace.md` as stale" and to be
rewritten "against S1's actual error string" — a string containing the word *Codex*. Two hits remain:

1. `.claude/skills/update-workspace/SKILL.md:61` — the mandated pre-v31 migration paragraph.
   Deleting it would delete the user-facing half of this phase's migration promise; an adopter has to
   be told which `[codex.*]` table to remove and which trees to delete by hand.
2. `.claude/skills/explain/SKILL.md:14-15` — the re-vendor comment recording the upstream divergence.
   Discretionary (the plan only required recording it in `phase.md`), kept because `phase.md` gets
   archived and the next person to re-vendor this file will read the comment, not the phase notebook.

Interpreted gate, matching `S2`'s precedent for its `OBSOLETE_MACHINERY` comments: **no Codex hits
except text that documents the removal.** Neither hit instructs an agent to do anything Codex-shaped.
Verified clean under that reading. Flagged in `phase.md` for `P15.REVIEW` to overrule if it disagrees
— hit 2 is trivially removable, hit 1 is not without losing the migration path.

An earlier draft of `retrofit/SKILL.md` did add an adopter-facing "your own `AGENTS.md` comes out
byte-identical" sentence; it was **removed** to keep that file at zero hits, since the general "it
skips files you already have" already covers it and `docs/retrofit-guide.md` (`S5`) is the better
home for adopter detail.

Nothing else deviated. `tests/**`, `README*`, `docs/**`, `installer/README.md`,
`installer/payloads/**`, `WORKSPACE_VERSION` and `CHANGELOG.md` were not touched;
`installer/build.py` and `installer/main.py` changed by exactly one line each.
`tests/retrofit_smoke.sh` remains red (it asserts `"Codex branch:"` and reads `AGENTS.md`) — expected,
and `S4`'s job; it was not run as a gate.

## Doc impact

Two lines appended to the running "Doc impact" list in `phase.md` (`architecture` — the shipped
contract has no `AGENTS.md` equivalence header; `operations` — the design exception is now
harness-general and `update-workspace` carries a pre-v31 migration step). **No `doc-new-version` was
run** — `P15.REVIEW` consolidates.

## Notes recorded in `phase.md`

A new *From `P15.S3`* section with nine items: the verified header coupling, the **design-exception
generalization and its rationale (explicitly flagged for `P15.REVIEW` to challenge)**, the final
wording of the design hard rule, confirmation that the rescued "approval must be literal…" sentence
survived verbatim, the `explain` skill's divergence from its vendored upstream, the interpreted
Codex-residue gate, the 28→19 artifact accounting, four concrete new `S4` findings (including that
the smoke test's `split("\n\n", 2)[2]` header-skip is now off by one paragraph and passes only by
luck), and confirmation that no `.claude/**` file outside the 11 needed an edit.
