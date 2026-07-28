# P10.S2 — Copy-based verbatim plan capture — result

`do-next-slice` step 2's plan-persistence rule (and every other site an approved plan is written)
now says: in Claude Code, **copy the harness plan file** into the slice's `plan.md` instead of
retyping it through `Write`. `Write` remains the fallback wherever no plan file exists — Codex (no
plan mode) and `auto` (plan mode never entered).

## What changed

**1. `.claude/skills/do-next-slice/SKILL.md` (line 19) and `.agents/skills/do-next-slice/SKILL.md`
(line 17)** — step 2's persistence clause, in both its default branch and its `plan only` branch
(same paragraph). New wording: after approval, copy the harness plan file — the exact path the
harness named for *this* planning session, never a `~/.claude/plans/` glob and never picked by
modification time — into the slice's own `plan.md`, after **confirming its opening lines match the
plan just approved** (guards against the harness's one-plan-file-per-session reuse leaving a stale
entry). Copy **immediately after approval, before the next `EnterPlanMode`**, which overwrites the
file. Any slice-local addition (an `## Escalation` section, for example) is **appended after** the
copy, never a rewrite of the copied body. `Write` is the explicit fallback for Codex and `auto`.
The two files' bodies stayed byte-identical below their frontmatter (verified).

**2. `.claude/skills/do-whole-phase/SKILL.md`** — three sites:
- The default-loop bullet (persistence clause rewritten the same way as `do-next-slice`'s primary
  site).
- The `auto` bullet — added an explicit clause: since plan mode is never entered in `auto`, there
  is no harness plan file to copy, so `auto` stays on `Write` (verbatim, in full) — the one
  persistence path that does not switch to `cp`.
- The `plan only` bullet — same confirm-then-copy rule as the default loop, referenced rather than
  fully re-spelled to keep the bullet from ballooning.

**3. `CLAUDE.md` + `AGENTS.md`** (bodies kept byte-equal):
- *Driving This Workspace* (line 19): "writes its **native plan** to `plan.md`" → "persists its
  **native plan** to `plan.md` … — in Claude Code by copying the operator-approved harness plan
  file byte-exact, `Write` only where no plan file exists (Codex, `auto`)". Kept to a clause, as
  the plan asked (this file is a routing contract).
- Hard Rules bullet (line 59, "Each slice owns exactly two context files…"): `plan.md`'s
  description now says it is persisted by copying the harness plan file in Claude Code (byte-exact,
  confirmed to be this slice's plan, immediately after approval and before the next
  `EnterPlanMode`) or by `Write`ing it verbatim where no plan file exists (Codex, `auto`).
- Confirmed `CLAUDE.md:42` and `:57` (the "verbatim" references to the operator's original request
  in `intent.md`) were **not** touched — unrelated to plan capture, as the plan flagged.

**4. `.claude/settings.json`** — added `"Bash(cp:*)"` to `permissions.allow`, beside the existing
`"Bash(python3 scripts/workflow.py:*)"`. Already in `installer/build.py::FIXED_LIVE_FILES` and
`installer/main.py`'s explicit `write_text` + merge-on-update path (`_merge_settings_json`), so no
installer wiring was needed beyond the rebuild — confirmed by grepping `installer/main.py` before
editing.

**5. Release plumbing** — appended three new bullets to the **existing** `## v19 — 2026-07-28`
CHANGELOG section (no new section, no version bump — `WORKSPACE_VERSION` stays 19, opened by
`P10.S1`): the copy-based persistence rule (naming every site it covers), the new `Bash(cp:*)`
allow entry and why, and an extended **Migration notes** line noting `do-next-slice` now changes
too (previously claimed untouched under S1) and that `.claude/settings.json` gains the merged
allow entry on `--update`. Rebuilt `bootstrap_agentic_workspace.sh` via `python3 installer/build.py`
(300,076 bytes) and left it in the working tree.

`scripts/workflow.py` and `.claude/agents/` are untouched (verified via `git diff --stat`), as are
the escalation ladder, `auto`'s safety halts, the approval gate's position, `plan only` / `ready`
semantics, and S1's `slice-planner` prefetch bullet (read through end-to-end, see Validation).

## Validation (real outcomes)

| Check | Command | Outcome |
|---|---|---|
| Rebuild | `python3 installer/build.py` | **PASS** — `wrote bootstrap_agentic_workspace.sh (300076 bytes)` |
| No drift | `python3 installer/build.py --check` | **PASS** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| Contract byte-equality | `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | **PASS** — empty |
| `do-next-slice` copies equal | `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` | **PASS** — empty |
| Version stamp / no bump | `grep -c 'WORKSPACE_VERSION = 19' bootstrap_agentic_workspace.sh` → `1`; `grep -c '^## v20' CHANGELOG.md` → `0` | **PASS** — appended to v19, not bumped |
| Settings payload shipped | `grep -c 'Bash(cp:\*)' bootstrap_agentic_workspace.sh` | **PASS** — `1` |
| S1 agent/engine untouched | `git diff -- .claude/agents/ scripts/workflow.py` | **PASS** — empty |
| Workflow state | `python3 scripts/workflow.py validate` | **PASS** — `Workflow validation passed.` |
| **Install probe** | `sh bootstrap_agentic_workspace.sh <scratchpad>/probe2 --name probe2` | **PASS** — install completed cleanly; probe's `.claude/settings.json` contains `"Bash(cp:*)"` in `permissions.allow`; both `do-next-slice` copies (`.claude/skills/` and `.agents/skills/`) contain the phrase "copy the harness plan file" (grep count 1 each); `works/.workspace-version.json` shows `"workspace_version": 19` |
| Read-through | Re-read all four edited sites end-to-end | **PASS** — approval gate position, `auto`'s safety halts, escalation ladder, `plan only` / `ready` semantics, "each slice owns exactly two context files", and S1's prefetch bullet are all intact and unweakened |

Probe directory:
`/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/a91b7b90-28ed-40ac-90ed-5be6ff99160a/scratchpad/probe2`.

## Deviations from `plan.md`

None of substance. Two small judgment calls within the plan's intent:

1. The `do-whole-phase` `plan only` bullet references "the same confirm-then-copy rule as the
   default loop above" rather than fully re-spelling the confirm/immediate-copy/append-after
   conditions a third time in the same file — the default-loop bullet directly above it already
   carries the full rule, and do-next-slice's plan-only branch (a different file) does spell it
   out in full since it is that file's only other site. Repeating three near-identical multi-clause
   sentences within one skill file felt like padding rather than diligence; keeping the plan-only
   bullet short also keeps it from crowding the already-large prefetch bullet block just below it.
   Flagging this for `REVIEW` in case the terser form is judged insufficiently explicit.
2. Added one clarifying clause not explicitly dictated by the plan: the `auto` bullet in
   `do-whole-phase` now explains *why* it stays on `Write` ("no harness plan file exists to copy,
   since plan mode is never entered"), matching the same clarity added to `do-next-slice`'s `auto`
   sentence. This is additive explanation, not a behavior change.

No `doc-new-version`, no edits under `docs/`, no commits, no status transitions.

## Notes for `P10.REVIEW`

- `## v19` now carries both slices' bullets and one Migration notes paragraph — confirm it reads as
  one coherent release, not two glued halves.
- The plan-only "same confirm-then-copy rule as the default loop above" reference (deviation 1
  above) is worth a sanity check: is a same-file forward/back reference clear enough, or should
  REVIEW ask for it to be spelled out again?
- Consider whether `CHANGELOG.md`'s v19 Migration-notes line correcting the earlier (S1) claim that
  "`do-next-slice`... [is] untouched" reads clearly as a correction rather than a contradiction —
  it is intentional: S1's claim was true only for the prefetch change; S2 is the one that touches
  `do-next-slice`.
