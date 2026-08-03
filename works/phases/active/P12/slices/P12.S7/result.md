# P12.S7 — Result

## What was done

Documented the opt-in parallel-phase mode in both READMEs, per `plan.md`.

**`README.en.md`:**
1. New `### Parallel phases (opt-in)` subsection inside `## How it works`, after `### Read order`
   and before `## Project structure` — bold-lead-in tutorial prose (`**The workspace suggests it,
   never assumes it.**`, `**Opting in.**`, `**Working in two streams.**`, `**Integrating back.**`),
   closing with pointers to the `parallel-phase` skill and `CLAUDE.md`. H3, so the L15-25 TOC
   (H2-only) needed no change — confirmed by reading it back.
2. CLI table: added one grouped row — `` `parallel-start <P>` … `parallel-teardown <P>` `` — pointing
   at the `parallel-phase` skill, matching the table's one-line style (did not enumerate all six
   commands as separate rows).
3. Skills table: added the `parallel-phase` row, description taken from the skill's own frontmatter
   `description:` field.
4. Skill counts: fixed all three stale occurrences — L171 "14 core Agent Skills" → "15 core Agent
   Skills" (core count excludes the model-invocable `design-cowork` guide, which isn't in the
   workflow-skills table), L253 "15 Agent Skills" → "16 Agent Skills", and the tree comment "15 Agent
   Skills (Claude Code)" → "16 Agent Skills (Claude Code)". Verified against `ls .claude/skills | wc
   -l` = 16.
5. Project-structure tree: added a `.github/workflows/workspace-ci.yml` entry with a short comment
   (both the file and its parent dirs exist on disk, confirmed before editing); updated the
   `settings.json` comment from "denies push & rm -rf" to "denies force-push & rm -rf" (confirmed
   against the live `.claude/settings.json`, which now denies `Bash(git push --force:*)` not
   `Bash(git push:*)`).
6. Wording collision at the "Related / inspired by" section: "parallel cross-tool `.claude/` +
   `.agents/` skills" → "mirrored cross-tool …", freeing "parallel" to mean only the execution mode.

**`README.md` (Korean):**
1. New `## 병렬 phase (옵트인)` H2 section between the end of `## 자주 쓰는 명령` and `## ⭐ …` —
   short 합니다체 narrative (concept, proactive suggestion, opting in, cross-stream status, deferred
   consolidation + integration sequence), domain nouns kept in English (`phase`, `slice`, `branch`,
   `worktree`, `PR`), no CLI table, closing with links to the `parallel-phase` skill and the new EN
   anchor `README.en.md#parallel-phases-opt-in`.
2. Skill table: added the `parallel-phase` row.
3. Count fix at "스킬은 모두 15개입니다" → "16개입니다".

## Deviation from `plan.md`

Found and fixed **one additional stale count** the plan's edit list didn't name explicitly: the "더
알아보기" (learn-more) section at the end of `README.md` also said "스킬 15종" — this is exactly the
kind of occurrence the plan's own validation step ("no remaining '15' skill count in either file")
requires to be caught, so I fixed it as part of the same in-scope README edit rather than leaving it
stale. No other files touched.

## Validation

1. `git status --porcelain -- README.en.md README.md` → exactly those two files modified. (The
   broader `git status --porcelain` also shows `works/backlog.md`, `works/deferred.md`,
   `works/events.jsonl`, `works/index.json`, `works/state.json`, `works/phases/active/P12/slices/
   P12.S7/slice.json` modified and `plan.md` untracked — all pre-existing orchestrator state from
   before this slice started (start-slice transition + this slice's plan), not touched by this
   executor.)
2. Greps: `grep -n "15개\|15종\|15 Agent Skills\|14 core" README.en.md README.md` → no matches (all
   stale counts fixed); `grep -n "mirrored cross-tool" README.en.md` → present; `grep -n "parallel
   cross-tool" README.en.md` → no matches. Every quoted command (`parallel-start`, `parallel-status`,
   `parallel-gate`, `parallel-merge-finish`, `parallel-consolidated`, `parallel-teardown`, `new-phase`,
   `next`) checked against `python3 scripts/workflow.py --help` / per-command `--help` output — all
   match, including flag shapes (`--worktree`, `--slug`, `--branch-ref`, `--main-ref`).
3. `python3 scripts/workflow.py validate` → "Workflow validation passed." `python3 scripts/workflow.py
   next` → unchanged (`current_phase=P12`, `current_slice=P12.S7`, `next_slice=P12.REVIEW`).
4. Read both new sections end-to-end after writing them; coherent with the neighboring prose and
   existing terminology (`quiet-point`, `stream-scoped`, bold-lead-in pattern, 합니다체).

## Doc impact

None. Both READMEs mirror durable truth already recorded by S1–S6's "Doc impact" notes (architecture,
operations, decisions); this slice added no new durable-truth claim of its own.
