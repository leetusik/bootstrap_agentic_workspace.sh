# P11.S1 — result

Dropped the bespoke `slice-planner` agent and rewrote the `do-whole-phase` prefetch from a mandated
procedure into an optional use of the executor's idle window. Shipped as workspace **v20**.

## What changed

**Agent deleted**

- `.claude/agents/slice-planner.md` — removed.

**Installer rewired (the four edits `DECOMP` flagged, all four applied)**

- `installer/build.py` — entry removed from `FIXED_LIVE_FILES` (no longer embedded).
- `installer/main.py` — entry removed from `MANAGED_FILES`.
- `installer/main.py` — the explicit `write_text(".claude/agents/slice-planner.md", …)` **and** its
  three-line explanatory comment removed (it sat outside the tier loop on purpose; both go).
- `installer/main.py` — `.claude/agents/slice-planner.md` **added** to `OBSOLETE_MACHINERY` with the
  house comment style: `# retired in v20 — idle-window research uses plain Claude Code behaviour
  (Explore or inline)`. This is the only channel that tells a v19 workspace to delete the file;
  proven to work by the obsolete-flag probe below.

**Rule rewritten — `.claude/skills/do-whole-phase/SKILL.md`**

- Dispatch bullet (`:21`): the carve-out no longer names the agent — "except the optional read-only
  preparation for the next slice described in the next bullet", and the one-executor-at-a-time
  parenthetical now reads "read-only research is not an executor". Everything that clause exists to
  enforce is intact (never inline/synchronous, never write to the repo or move state while an
  executor runs, one executor at a time).
- Prefetch bullet (`:22`+): replaced with an optional-practice bullet. It opens as a permission —
  *while executor N runs you are idle on the main thread, and you **may** use that window to prepare
  for slice N+1: dispatch a read-only research subagent (built-in `Explore`), read inline, think it
  through, or just wait* — states that nothing is required and no mechanism is prescribed, and says
  to prefer waiting when there is nothing useful to learn yet. Sub-bullets: the hard limits (framed
  as constraining *how*, never *whether*: read-only, no second executor, never block, discard on any
  non-`done` verdict, scratchpad-only, gate unmoved); judgment (where it pays off / where it does
  not — P10's five skip conditions demoted verbatim in substance to "weigh these; do not tick them
  off"); a short "if you delegate, keep the ask small" carrying the useful half of the deleted
  agent's prompt (by path, sharp questions, compact advisory brief with a "not read / possibly
  stale" list, never a plan or a file dump); reconcile-don't-re-research after N returns; and modes
  (default + `auto`; `plan only` has no idle window).

**Contracts mirrored — `CLAUDE.md` and `AGENTS.md` (bodies byte-equal)**

- `:19` — the "doing nothing else in the meantime" exception keeps its `do-whole-phase` scoping but
  stops naming the agent: "optional read-only preparation for the *next* slice, which it may do or
  skip as it judges best".
- `:62` — "Pipelined planning" → **"Idle-window preparation (`do-whole-phase` only, optional)"**,
  compressed to routing-contract length: may/`Explore`/inline/think/wait, nothing mandatory, the five
  conditions as "pays off least when…" rather than "skip when…", then the invariants (read-only, no
  second executor, never blocks, discarded on any non-`done` verdict, scratchpad-only, advisory, gate
  unmoved), reconcile-don't-re-research, `do-next-slice` never prefetches, `plan only` has no window.

**Release**

- `installer/main.py` — `WORKSPACE_VERSION` 19 → 20.
- `CHANGELOG.md` — new `## v20 — 2026-07-28` section on top; v19 untouched. Migration notes lead with
  **delete `.claude/agents/slice-planner.md` by hand after `--update`** (the updater flags it stale,
  never deletes). The section also states the honest enforcement change (read-only was a tool
  allowlist in v19; it is now discipline) and lists what is unchanged (copy-based plan capture,
  `auto`'s halts, the escalation ladder, `plan only` / `ready`, the tiers, both `do-next-slice`
  copies).
- `bootstrap_agentic_workspace.sh` rebuilt (294934 bytes), left in the working tree.

Untouched, as required: both `do-next-slice` copies, `scripts/workflow.py`, the v19 CHANGELOG
section, `docs/**`, and the READMEs (`P11.S2`).

## Validation — real outcomes

| Check | Expected | Outcome |
|---|---|---|
| `python3 installer/build.py` then `--check` | rebuild + in sync | **PASS** — "wrote bootstrap_agentic_workspace.sh (294934 bytes)"; "OK: … in sync with installer/ source" |
| `grep -c 'slice-planner' bootstrap_agentic_workspace.sh` | plan said 0 | **1** — see *Deviation* below; the single hit is the `OBSOLETE_MACHINERY` line the same plan requires |
| `grep -c 'WORKSPACE_VERSION = 20' bootstrap_agentic_workspace.sh` | 1 | **PASS** — 1; `CHANGELOG.md` has one `## v20` and still one `## v19` |
| `grep -n 'slice-planner' installer/main.py` | exactly 1 (the `OBSOLETE_MACHINERY` entry) | **PASS** — only `:519`, the retired-in-v20 entry; `installer/build.py` has 0 |
| `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | empty | **PASS** — empty |
| `git diff --stat -- .claude/skills/do-next-slice .agents/skills/do-next-slice scripts/workflow.py` | empty | **PASS** — empty; the two `do-next-slice` copies still differ only by the two frontmatter lines |
| `python3 scripts/workflow.py validate` | pass | **PASS** — "Workflow validation passed." |
| `python3 scripts/workflow.py sync-agents --check` | pass | **PASS** — "agent files in sync with executors.toml/defaults" (economy default, 0 overrides) |
| **Fresh-install probe** | three executor agents only, v20, new wording, no `slice-planner` | **PASS** — `sh bootstrap_agentic_workspace.sh <scratchpad>/probe-p11 --name probe-p11` succeeded; `.claude/agents/` = `slice-executor-{low,mid,high}.md` only; `works/.workspace-version.json` → `"workspace_version": 20`; the optional-practice sentence and `Explore` present in `do-whole-phase/SKILL.md`; "Idle-window preparation" present in both `CLAUDE.md` and `AGENTS.md`; `grep -rl 'slice-planner' <probe>` returned **nothing** |
| **Obsolete-flag probe** | reported stale, not deleted | **PASS** — hand-created `<probe>/.claude/agents/slice-planner.md`, ran `--update --dry-run`: output line `stale workspace skills/machinery dropped upstream (remove manually?): .claude/agents/slice-planner.md`, and the file was still present afterwards |
| Read-through | nothing adjacent weakened | **PASS** — re-read `SKILL.md:18-28` and the two contract paragraphs: the delegation rule, the approval gate's position (`plan → approve → executor`), `auto`'s safety halts, the escalation ladder, `plan only` / `ready`, "a slice owns exactly two context files", and P10's copy-based plan capture all read exactly as before |

Probe location: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/a91b7b90-28ed-40ac-90ed-5be6ff99160a/scratchpad/probe-p11` (left in place for `REVIEW`).

## Deviation from `plan.md`

**One, and it is in the plan's expectation, not in the work.** The validation table expects
`grep -c 'slice-planner' bootstrap_agentic_workspace.sh` = **0**, reasoning that "the artifact embeds
no CHANGELOG, so the only hits would be live machinery". But the artifact *is* `installer/main.py`
plus the embedded payloads — so the `OBSOLETE_MACHINERY` entry the same plan mandates in §1
necessarily appears in it. **0 and the `OBSOLETE_MACHINERY` requirement are mutually exclusive.**

The real count is **1**, at artifact line 679, and it is exactly that entry:

```
    ".claude/agents/slice-planner.md",    # retired in v20 — idle-window research uses plain Claude Code behaviour (Explore or inline)
```

The check's *intent* — no live machinery reference survives — holds strictly: one grep over the whole
294 KB artifact returns that single line, which proves no payload (skills, contracts, agents,
settings) mentions the agent, and the fresh-install probe confirms it end to end (zero files in a
bootstrapped workspace contain the string). The correct expectation for `REVIEW` is **exactly 1, the
`OBSOLETE_MACHINERY` line**.

## Wording judgements `REVIEW` should weigh

1. **Voice.** The skill bullet is written in second person as a permission ("you **may** use that
   window"), the contract bullet in third person about the orchestrator, matching each file's
   surrounding voice. Both open on the permission and put the limits *after* it, deliberately: the
   operator's correction was that the rule should read "you may, and here is how to judge it", not
   "do this unless…".
2. **The five conditions.** Kept in full but restated as "it usually does not pay off when…" +
   "Weigh these; do not tick them off". Nothing was deleted — only demoted, per `intent.md`.
3. **`Explore` is named as a suggestion, not a requirement** ("the natural fit"). Naming no
   mechanism at all read as vague; naming one as required would repeat P10's mistake.
4. **CHANGELOG scope.** I dropped a drafted bullet about the README tier fixes: those are `P11.S2`'s
   work, the READMEs are not embedded machinery, and the CHANGELOG is what adopting workspaces read
   on `--update` — where an upstream README fix is not a change they receive. If `REVIEW` disagrees,
   it is a one-line addition.
5. **Migration notes are blunt on purpose** — "delete … by hand" leads the paragraph, because the
   `OBSOLETE_MACHINERY` flag only *reports*; a reader who skims will otherwise keep dead machinery.

No `doc-new-version`, no `docs/` edits, no commits, no status transitions.
