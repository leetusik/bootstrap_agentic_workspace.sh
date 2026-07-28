# P10.S2 — Copy-based verbatim plan capture

## Context

`do-next-slice` step 2 requires the operator-approved plan to be persisted "verbatim … not a
paraphrase or summary" into the slice's `plan.md`. Today the orchestrator re-emits it through
`Write` — retyping a document it just wrote, which is the one step in the loop where a paraphrase
can silently creep in and where a long plan can be quietly truncated.

In Claude Code the harness already holds that exact plan on disk and names the file in the
plan-mode message. Copying it is byte-exact and removes the failure mode entirely. `Write` stays
the fallback wherever no plan file exists: Codex (no plan mode) and `auto` (plan mode never
entered).

This is item 2 of `works/phases/active/P10/intent.md` — independent of `P10.S1`, which is already
landed. Scope, constraints, and the exact site list live in `works/phases/active/P10/phase.md`;
read both first.

**Verified while planning this slice (matters for the rule's wording):** the harness reuses **one
plan file per session** — this session's DECOMP, S1, and S2 plans were all written to
`/Users/sugang/.claude/plans/inherited-puzzling-tarjan.md`, each overwriting the last. So the copy
is only safe if it happens *immediately after approval, before the next `EnterPlanMode`*, and only
after confirming the file holds *this* slice's plan. That is not a theoretical guard.

Dispatch tier: **`slice-executor-mid`** (`risk: medium`).

## Work

### 1. The rule (what every site must say)

In Claude Code, after the operator approves the plan, persist it by **copying the harness plan file
to the slice's `plan.md`** — e.g.
`cp "<the plan file the harness named>" works/phases/active/<P>/slices/<slice_id>/plan.md`.
Attached conditions, all load-bearing:

- **Use the path the harness surfaced for *this* planning session.** Never glob `~/.claude/plans/`
  and never pick by modification time.
- **Confirm it is this slice's plan before copying** — the opening lines must match the plan just
  approved. The harness reuses one plan file per session, so the path can still hold an earlier
  slice's plan if a step was skipped.
- **Copy immediately after approval, before the next `EnterPlanMode`**, which overwrites the file.
- **Slice-local additions are appended after the copy** (an `## Escalation <n>` section, for
  example) — never a rewrite or re-flow of the copied body.
- **Fall back to `Write`** where no plan file exists — Codex (no plan mode) and `auto` (plan mode
  never entered) — persisting the plan verbatim and in full, exactly as today.

### 2. Sites to edit (the complete list — verified against current text)

- `.claude/skills/do-next-slice/SKILL.md:19` **and** `.agents/skills/do-next-slice/SKILL.md:17` —
  step 2's "write the **operator-approved plan verbatim** to this slice's own `plan.md`", plus the
  **`plan only`** branch later in that same paragraph ("write the approved plan verbatim to the
  slice's `plan.md`"). `plan only` uses plan mode, so it copies too — only `auto` and Codex fall
  back to `Write`. The two files must stay **byte-identical from `# do-next-slice` onward**
  (frontmatter differs; the bodies must not).
- `.claude/skills/do-whole-phase/SKILL.md` — the default-loop bullet (`:18`, "write the approved
  **native plan** to that slice's **own** `plan.md`"), the `auto` bullet (`:19`, the `Write`
  fallback — say so explicitly), and the `plan only` bullet (`:20`). S1's new prefetch bullet sits
  below these and is untouched by this slice.
- `CLAUDE.md` **and** `AGENTS.md` — the *Driving This Workspace* sentence at `:19` ("writes its
  **native plan** to `plan.md`") and the Hard Rules bullet at `:59` ("Each slice owns exactly two
  context files…"). Keep it to a clause or short sentence each; this file is a routing contract.
  **Bodies must stay byte-equal** (`installer/build.py::collect_contract_body` hard-fails
  otherwise).
- **Do not touch `CLAUDE.md:42` / `:57`** — their "verbatim" refers to the operator's original
  request in `intent.md`, not to plan capture.

### 3. Permission entry (operator-approved during planning)

`.claude/settings.json` — add `"Bash(cp:*)"` to `permissions.allow`, beside the existing
`Bash(python3 scripts/workflow.py:*)`. Without it every slice raises a permission prompt
immediately after the approval gate. It grants nothing beyond the already-allowed `Write` tool
(overwrite files; no deletion). `.claude/settings.json` is already in `FIXED_LIVE_FILES` and
`MANAGED_FILES`, so no installer wiring is needed — only the rebuild.

### 4. Release plumbing — append, do **not** bump

`P10.S1` opened `## v19 — 2026-07-28` and set `WORKSPACE_VERSION = 19`. P10 ships as one release:

- Append this slice's bullets to the **existing** `## v19` section (including the settings-allowlist
  addition, which adopting workspaces should know about) and extend its **Migration notes** line if
  the `cp` allow entry needs a word there. **No new section, no version bump.**
- Rebuild: `python3 installer/build.py`, leaving the regenerated `bootstrap_agentic_workspace.sh`
  in the working tree.

## Validation

| Check | Expectation |
|---|---|
| `python3 installer/build.py` then `--check` | rebuild succeeds; `--check` reports in sync |
| `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | empty |
| `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` | empty — the two copies stayed in lockstep |
| `grep -c 'WORKSPACE_VERSION = 19' bootstrap_agentic_workspace.sh` | 1, and `grep -c '^## v20' CHANGELOG.md` → 0 (appended, not bumped) |
| `grep -c 'Bash(cp:\*)' bootstrap_agentic_workspace.sh` | ≥ 1 — the settings change actually shipped |
| `git diff -- .claude/agents/ scripts/workflow.py` | empty — S1's agent and the engine are untouched |
| `python3 scripts/workflow.py validate` | passes |
| Install probe | `sh bootstrap_agentic_workspace.sh <scratchpad>/probe2 --name probe2` into a fresh empty dir; confirm the probe's `.claude/settings.json` contains `Bash(cp:*)` and its `do-next-slice/SKILL.md` carries the copy rule. Report the real outcome; if the probe cannot run, say so rather than skipping silently. |
| Read-through | Re-read the four edited rule sites end-to-end and confirm nothing adjacent was weakened: the approval gate's position, `auto`'s safety halts, the escalation ladder, `plan only` / `ready`, "each slice owns exactly two context files", and S1's prefetch bullet. |

## Record

- `result.md` — free-form: what changed, the validation table with real outcomes, and any wording
  judgement the review should check.
- `phase.md` — append cross-slice notes and a **Doc impact** line (expected targets: `operations.md`
  for the loop mechanics, `decisions.md` for the copy-over-retype decision and the `Bash(cp:*)`
  allowlist rationale).
- No `doc-new-version`, no edits under `docs/`, no commits, no status transitions.

## Non-goals

- No prefetch changes (S1 is landed and final here); no edits to `.claude/agents/slice-planner.md`.
- No change to `scripts/workflow.py`, the state model, the gate's position, `auto`'s safety halts,
  the escalation ladder, or `plan only` / `ready` semantics beyond how the approved plan is written.
- No new doc versions, no archiving, no `WORKSPACE_VERSION` bump.
