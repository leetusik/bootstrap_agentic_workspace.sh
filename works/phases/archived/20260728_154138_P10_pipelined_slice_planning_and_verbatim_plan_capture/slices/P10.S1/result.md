# P10.S1 — Pipelined prefetch in `do-whole-phase` — result

`do-whole-phase` no longer idles for the whole executor run: it dispatches a new read-only
`slice-planner` agent for slice N+1 right after dispatching executor N, and plans N+1 by
**reconciling** that brief instead of re-researching. The operator's approval gate is untouched.

## What changed

**1. New agent — `.claude/agents/slice-planner.md`** (new file, 5,485 bytes)

Frontmatter exactly as the DECOMP decision fixed it: `tools: Read, Glob, Grep`, `model: sonnet`,
`effort: xhigh`, `permissionMode: bypassPermissions`. The body establishes: what it is (read-only
research for a not-yet-planned slice, dispatched while another executor runs; its brief is
**advisory input**, discardable without notice); inputs arrive by path because it has no `Bash`
(slice id + folder, phase folder, the questions, the blast-radius exclusions — it reads
`slice.json` / `phase.md` / `intent.md` / docs / code itself); the blast-radius rule (prefer not
to read excluded paths, and label anything read there as **possibly stale**); a bounded output
shape (relevant files, patterns to reuse, constraints/risks, open questions, and an explicit
"not read / possibly stale" list — no file dumps, no step-by-step plan, no recommendation phrased
as a decision, shallow beats exhaustive); and the hard rules (never writes — especially never into
a slice folder, never runs commands, never dispatches another agent, never touches workflow state
or commits, never blocks the loop).

**2. Installer wiring — all three edits** (a file with only one of them ships as dead payload)

- `installer/build.py` → `.claude/agents/slice-planner.md` added to `FIXED_LIVE_FILES` (embeds it
  into `PAYLOADS`; `.claude/agents/` is not globbed, unlike skills).
- `installer/main.py` → explicit `write_text(".claude/agents/slice-planner.md", …)` placed
  **outside** the `for tier in ("low", "mid", "high")` loop, with a comment saying why (it is not
  an executor tier: no `executors.toml` knob, no Codex counterpart, so that loop would never emit it).
- `installer/main.py` → the path added to `MANAGED_FILES` beside the three executor agents
  (fresh-install conflict guard + managed-file bookkeeping).

The `--update` path needed no change: `_is_machinery()` already matches the `.claude/agents/`
prefix, so adopting workspaces receive the file as an **added** machinery file (verified — see
the probe below).

**3. `.claude/skills/do-whole-phase/SKILL.md`** — the dispatch bullet gained two scoped carve-outs
and a new bullet follows it:

- "doing nothing else in the meantime **except the read-only `slice-planner` prefetch described in
  the next bullet**" — still: never inline synchronous execution, and now explicitly *never write to
  the repo or move workflow state while the executor runs*.
- "one **executor** at a time … (the read-only planner is not an executor and does not count against
  that limit)".
- New bullet **"Prefetch the next slice's research while executor N runs (`do-whole-phase` only —
  `do-next-slice` never prefetches)"** with sub-bullets for: skip conditions (+ the blast-radius
  definition), per-slice sizing (subagent-only for easy/mechanical; orchestrator may *also* read
  inline for a heavy one, still strictly read-only), never-block (one prefetch in flight, never delay
  `finish-slice` / `validate` / commit), discard-on-non-`done`, scratchpad-only + "the operator's
  approval gate does not move", the post-return **reconcile-don't-re-research** step, and mode
  coverage (default loop **and** `auto`; **not** `plan only` — no executor, no idle window).

**4. `CLAUDE.md` + `AGENTS.md`** (bodies byte-equal):

- *Driving This Workspace*: "…doing nothing else in the meantime — with one exception, scoped to
  `do-whole-phase` by name: the read-only `slice-planner` prefetch of the *next* slice's research
  (see Hard Rules; `do-next-slice` never prefetches)…".
- One new Hard Rules bullet after the delegation bullet: the prefetch in a few lines — read-only
  agent + why the tool allowlist is what enforces it, the five skip conditions, never-block,
  discard-on-non-`done`, scratchpad-not-slice-folder, advisory-not-authoritative, gate unmoved, and
  the `do-next-slice` / `plan only` exclusions.

**5. Release plumbing:** `WORKSPACE_VERSION` **18 → 19** (not 17 → 18 — see *Deviations*), a new
`## v19 — 2026-07-28` CHANGELOG section with Migration notes, and the rebuilt
`bootstrap_agentic_workspace.sh` (297,249 bytes) left in the working tree.

Both `do-next-slice` copies are **untouched** (`git diff --stat` over those paths is empty), as are
`scripts/workflow.py`, the state model, `plan only`, `auto`'s safety halts, and the escalation ladder.

## Dispatch-prompt shape for `slice-planner` (what the orchestrator should send)

The planner has no `Bash`: it cannot run `workflow.py`, cannot read `git`, and nothing is pasted for
it. Everything must be a path or an explicit statement. Recommended shape:

```
Read-only research prefetch for slice <P>.S<n+1> — "<slice name>" (kind: <kind>, risk: <risk>)
of phase <P>. It has NOT been planned yet; I am planning it after the running slice returns.

Read these yourself (absolute paths):
- works/phases/active/<P>/slices/<P>.S<n+1>/slice.json  — the slice's own record
- works/phases/active/<P>/phase.md   — decomposition, findings, constraints, Doc impact list
- works/phases/active/<P>/intent.md  — the operator's confirmed intent (item <k> is this slice)
- CLAUDE.md / AGENTS.md, and docs/current/<doc>.md as the subject warrants

Investigate (answer these, nothing else):
1. <question — e.g. every site that must change for rule X, with paths and line numbers>
2. <question — e.g. what constrains the change: mirrors, byte-equality, rebuild obligations>
3. <question — e.g. what precedent exists nearby that should be followed>

Blast radius — slice <P>.S<n> is mutating these RIGHT NOW; do not rely on them:
- <path>, <path>, <dir>/…   (and works/phases/active/<P>/slices/<P>.S<n>/, plus phase.md's tail)
Prefer not to read them at all; if you must, label the finding possibly-stale.

Return a compact brief: relevant files (path + one line), patterns/utilities to reuse,
constraints and risks, open questions for the operator, and an explicit "not read / possibly
stale" list. No file dumps, no step-by-step plan, no recommendations phrased as decisions.
Shallow and fast beats exhaustive — I drop the brief if it arrives after the executor returns.
```

Dispatch it via the Agent tool **as a background task**, immediately after executor N, and never
wait on it. Practical notes for the next orchestrator:

- `phase.md` is itself inside the blast radius of every running slice (each executor appends notes
  at the end). Naming it as readable-but-stale is fine — its *earlier* sections are stable, only
  the tail moves.
- Do not ask the planner to "draft the plan" or "recommend an approach"; ask questions. A brief that
  answers three sharp questions is worth more than a survey.
- Keep the questions to what the idle window can actually cover — the brief is dead if it is late.

## Validation (real outcomes)

| Check | Command | Outcome |
|---|---|---|
| Rebuild | `python3 installer/build.py` | **PASS** — `wrote bootstrap_agentic_workspace.sh (297249 bytes)` |
| No drift | `python3 installer/build.py --check` | **PASS** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| Payload present | `grep -c 'slice-planner' bootstrap_agentic_workspace.sh` | **PASS** — `5` (≥ 3) |
| Actually written | `grep -n 'write_text(".claude/agents/slice-planner.md"' bootstrap_agentic_workspace.sh` | **PASS** — one hit, line 649 |
| Version stamp | `grep -c 'WORKSPACE_VERSION = 19' bootstrap_agentic_workspace.sh` | **PASS** — `1` (19, not 18 — see *Deviations*) |
| Contract byte-equality | `diff <(tail -n +5 CLAUDE.md) <(tail -n +5 AGENTS.md)` | **PASS** — empty (and `build.py` enforces it) |
| `do-next-slice` copies equal | `diff <(tail -n +8 .claude/skills/do-next-slice/SKILL.md) <(tail -n +6 .agents/skills/do-next-slice/SKILL.md)` | **PASS** — empty |
| `do-next-slice` untouched | `git diff --stat -- .claude/skills/do-next-slice .agents/skills/do-next-slice` | **PASS** — empty |
| Workflow state | `python3 scripts/workflow.py validate` | **PASS** — `Workflow validation passed.` |
| Tier config unaffected | `python3 scripts/workflow.py sync-agents --check` | **PASS** — `agent files in sync with executors.toml/defaults`, exit 0 (the new agent is outside `EXECUTOR_TIERS`, so it is neither synced nor flagged) |
| **End-to-end install probe** | `sh bootstrap_agentic_workspace.sh <scratchpad>/probe --name probe` | **PASS** — install completed; `.claude/agents/slice-planner.md` exists in the probe, **byte-identical** to the source (`diff` empty), frontmatter as expected (`tools: Read, Glob, Grep` / `model: sonnet` / `effort: xhigh` / `permissionMode: bypassPermissions`); `works/.workspace-version.json` shows `"workspace_version": 19`; `slice-planner` appears 3× in the probe's `do-whole-phase/SKILL.md`, 2× in each contract, **0×** in `do-next-slice/SKILL.md` |
| **Update probe** (extra, not in the plan) | delete the file in the probe, then `--update --dry-run` and `--update` | **PASS** — reported `added: 1 file(s) + .claude/agents/slice-planner.md` in both, and the real run restored it. Confirms adopting workspaces get it on `--update` (the `_is_machinery()` `.claude/agents/` prefix handles it) — this is what the CHANGELOG Migration notes claim |

Probe directory: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/a91b7b90-28ed-40ac-90ed-5be6ff99160a/scratchpad/probe`.

## Deviations from `plan.md`

1. **Version bump is 18 → 19, not 17 → 18.** The plan (and `phase.md`'s finding) recorded
   `WORKSPACE_VERSION = 17`, but commit `b26d622` — landed after DECOMP — already shipped **v18**
   (the re-cut executor-tier presets) with its own committed `## v18 — 2026-07-28` CHANGELOG section
   and Migration notes. Folding P10 into v18 would have retro-fitted a released section and muddied
   its migration line, so P10 opens `## v19` instead. The plan's actual constraint — *P10 ships as
   **one** release* — is preserved: **`P10.S2` appends its bullets to the `## v19` section and must
   not bump again.**
2. **Two small strengthenings inside the amended sentences** (additive, nothing weakened):
   the `do-whole-phase` dispatch bullet now also says "never write to the repo or move workflow state
   while it runs", and the sizing sub-bullet spells out that the orchestrator's *optional inline*
   research is read-only too. Without these, "except the prefetch" could be read as licence for any
   concurrent work.
3. **One extra validation** (the `--update` probe above) beyond the plan's table, because the
   CHANGELOG's Migration notes assert an update-path behavior the plan's checks did not cover.

Nothing else deviates. No `doc-new-version`, no edits under `docs/`, no commits, no status
transitions.

## Notes for `P10.S2` and `P10.REVIEW`

- `## v19` is open — **append, do not bump.**
- `.claude/skills/do-whole-phase/SKILL.md` grew 8 lines (one bullet + 7 sub-bullets) after the
  dispatch bullet; the `plan only` bullet above it is unchanged, so S2's `plan only` persistence edit
  has no conflict with this slice's text.
- The `effort: xhigh` on `slice-planner` came from a DECOMP rationale ("matches the `flex` preset's
  low tier") that `b26d622` invalidated — `flex`'s low tier is now sonnet@`high` and `economy`'s is
  sonnet@`medium`. The value was kept as the plan fixed it; it is pinned in-file and deliberately
  independent of the tier presets, so this is a stale rationale, not a defect. Worth a one-line
  sanity check at REVIEW if the operator wants a cheaper prefetch.
