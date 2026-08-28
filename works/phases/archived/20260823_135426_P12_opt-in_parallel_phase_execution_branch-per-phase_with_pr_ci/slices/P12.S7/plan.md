# P12.S7 — README documentation for parallel mode

_Auto-mode plan. Docs-only slice (risk `low`, `slice-executor-mid`). Context: `phase.md`
§Settled Decisions S1–S6 (command names below are binding), §Doc Impact. The orchestrator
pre-researched both READMEs with a read-only agent; the insertion points and line refs below come
from that pass — re-verify before editing (line numbers may have drifted slightly). READMEs are
NOT embedded machinery: no installer rebuild, no version bump._

## Goal

Document the opt-in parallel-phase mode for humans in both READMEs, matching each file's existing
role: `README.en.md` is the full reference, `README.md` (Korean) the abridged tutorial that defers
detail to English. If any of this turns out to require code changes or touches files beyond the
two READMEs, return `escalate` instead of improvising.

## Binding facts to quote (do not re-derive; verify against `phase.md` §Settled Decisions)

- Commands: `parallel-start <P> [--worktree PATH] [--slug S]`, `parallel-status`,
  `parallel-gate <P> [--branch-ref R] [--main-ref R]`, `parallel-merge-finish`,
  `parallel-consolidated <P>`, `parallel-teardown <P>`. Branch format `phase/P<N>-<slug>`;
  worktree, never a clone (teammates: clone + checkout the branch).
- Concept: opt-in per phase; the phase is the unit of parallelism (slices stay sequential); its own
  branch + git worktree + its own orchestrator session; selection and `pending` are stream-scoped
  (main's pointer skips opted-in phases; the worktree sees only its phase); `parallel-status` shows
  every stream from any checkout; a parallel phase's review defers doc consolidation to a
  serialized post-merge step on main; integration is agent-run after the review passes (gate →
  push → PR → CI → merge → merge-finish → consolidate → teardown) behind the quiet-point gate
  (branch phase done + main between phases); the workspace *suggests* parallel when a phase is
  created or waiting behind an in-progress one — never a default. CI: `.github/workflows/
  workspace-ci.yml` (validate on every push/PR; `parallel-gate` job on `phase/*` PRs).
- Detail pointers: the `parallel-phase` skill (`.claude/skills/parallel-phase/SKILL.md`) and
  `CLAUDE.md`.

## Edits — `README.en.md`

1. **New `###` subsection inside `## How it works`,** after `### Read order` (ends ~L321), before
   `## Project structure` (~L323). Suggested title: `### Parallel phases (opt-in)`. Content: the
   concept block above as tight tutorial prose (~25-40 lines) using the file's bold-lead-in
   pattern (`**Opting in.**`, `**Working in two streams.**`, `**Integrating back.**` or similar),
   ending with the skill + CLAUDE.md pointers. H3 ⇒ **no TOC change** (the L17-25 TOC lists H2s
   only).
2. **CLI table (~L237-248):** add one or two rows for the family — e.g. a `parallel-start … -teardown`
   grouped row pointing at the skill — consistent with the table's one-line "What it does" style;
   L249 already defers the full list to CLAUDE.md, so do not enumerate all six as separate rows
   unless it reads better.
3. **Skills table (~L258-272):** add the `parallel-phase` row (description consistent with the
   skill's frontmatter).
4. **Skill counts:** "15 Agent Skills" style counts at ~L171, ~L253, ~L343 → 16 (grep for stale
   counts; S6 added the skill, update every occurrence).
5. **Project-structure tree (~L325-350):** add `.github/workflows/workspace-ci.yml` with a short
   comment; update the `settings.json` comment (~L345) from "denies push & rm -rf" to reflect the
   S5 change (denies force-push & rm -rf).
6. **Wording collision (~L392):** change "parallel cross-tool `.claude/` + `.agents/` skills" to
   "mirrored cross-tool …" — the file's own established word (L171, L254, L346) — so "parallel"
   now means only the execution mode.

## Edits — `README.md` (Korean)

1. **New `##` section** between the end of `## 자주 쓰는 명령` (~L186) and `## ⭐ …` (~L188), e.g.
   `## 병렬 phase (옵트인)`: a short Korean narrative (~15-25 lines) of the concept block —
   합니다체, keep domain nouns in English (phase, slice, branch, worktree, PR) per the file's
   habit, no CLI table (the file defers command detail to the English README — keep that division),
   closing with links to the EN section and the `parallel-phase` skill.
2. **Skill table (~L176-183):** add a `parallel-phase` row (the table is abridged, but this is a
   headline capability).
3. **Count (~L185):** "스킬은 모두 15개입니다" → 16개.

## Style rules (from the research pass — follow the file, not your habits)

ATX headings, sentence case, no new emoji; inline backticks for every command; slash commands
paired as `/parallel-phase` + `$parallel-phase` where the file pairs them; real ellipsis `…` not
`...`; pipe tables with "What it does" / "하는 일" headers; `>` blockquotes only for callouts;
hard-wrap prose ~100 cols; relative repo links.

## Validation (lean)

1. `git status --porcelain` shows exactly `README.md` and `README.en.md` modified — nothing else.
2. Greps: no remaining "15" skill count in either file (and the new count matches
   `ls .claude/skills | wc -l`); `parallel` at old L392 now reads "mirrored"; every quoted command
   name matches `python3 scripts/workflow.py --help` output.
3. `python3 scripts/workflow.py validate` passes; `next` unchanged.
4. Read both new sections once end-to-end for coherence with the neighboring sections.

## Boundaries

Executor: READMEs only. No code, no installer rebuild, no commits, no status transitions, no
`doc-new-version`, no other slice's `plan.md`. Write `result.md`; append a one-line note to
`phase.md` §Doc Impact only if you judge the READMEs changed durable truth (they usually don't —
they mirror it; a "none" is fine). Escalate rather than stretch scope.
