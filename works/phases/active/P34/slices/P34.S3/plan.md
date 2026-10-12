# Plan — P34.S3 (Texts: Compact Instructions, skill reorder, doc notes)

## Context

S1 put the veto and the resume command in the engine, S2 shipped the hooks. This slice makes the texts survive compaction: a `## Compact Instructions` section in `CLAUDE.md` (Claude Code honours it when it summarizes), the contract back under its 12,288 B cap, the two execution skills reordered so their loop invariants and a new resume line sit in the first 16 KB (Claude Code re-injects an invoked skill capped at 5,000 tokens, truncation keeping the start), and the phase's `## Doc impact` lines for the docs phase that will version operations, architecture, decisions and qa. Read `works/phases/active/P34/phase.md` first: `## Decisions` (the *Texts* decision and every engine/installer fact), the three tagged notes for S3 under `## Notes for later slices`, `## Now`. S4 releases v55 after this. This slice touches `CLAUDE.md`, `.claude/skills/do-whole-phase/SKILL.md`, `.claude/skills/do-next-slice/SKILL.md`, the rebuilt artifact and `phase.md` only.

Risk `low`: a mechanical reorder plus short new text; every existing sentence survives and the measurements are mechanical.

## What the orchestrator read (2026-10-12; byte offsets from `grep -b`)

**`CLAUDE.md` — 12,588 B**, cap **12,288 B** (`docs/current/decisions.md` ~l.373–380: the contract is a routing layer; every never-rule keeps a statement in it; the cap is the operator's pick). Headings: `## Agent Contract`, `## Driving This Workspace`, `## Read Order`, `## Canonical State`, `## Hard Rules`, `## IDs and Status`, `## Commit Convention`. Nothing about compaction yet. Adding ≈ 450 B means cutting ≈ 750 B+ of **phrasing**, never a rule: candidates are restatements the skills already own in full — in the *Orchestrator and executor* paragraph (the route-table recital, the idle-window sentence), the three-exception sentence under *Driving This Workspace* ("Two exceptions:" lists three), the Aside bullet's second half (`design-cowork` carries the sharp edges) and the design bullet's tail. Keep a one-clause statement of each rule you shorten; list every cut in `result.md` with where the rule still lives.

**`.claude/skills/do-whole-phase/SKILL.md` — 42,793 B**, bullets under `Rules:` (@3624): L16 pending halts @3632 (1,178 B); L17 re-read after each slice @4811; L18 `auto` default @5168 (2,042); L19 `gate` @7211 (2,162); L20 `plan only` @9374 (2,302); L21–35 co-work @11677–18684; **L36 Delegated slices @18685 (5,797 B — background dispatch, one executor at a time, the route table, record-dispatch, verdict handling)**; L37–42 idle window @24483–29094; L43 decomposition @29095 (4,935); **L44 finish-slice → validate @34031 (358)**; L45 doc versioning @34390; **L46 commit + attribution @35323 (1,181)**; L47–54 review and tail @36505–42792. Bullets under `Rules:` are an unordered list, so moving them is safe. Target order: L16 → L17 → **the new resume bullet** → L36 → L44 → L46 → L18 → L19 → L20 → L21–35 → L37–42 → L43 → L45 → L47–54. Expected end of L46 ≈ 13 KB.

**`.claude/skills/do-next-slice/SKILL.md` — 36,067 B**: L10 pointer @284; L12 orchestrator @1458; L14 pending halt @2637 (1,071); L16 worktree @3709; `Work exactly one slice:` @5409; step 1 @5434; step 2 (modes) @5623–8460; **step 3 @8461 (10,789 B — the dispatch rules *and* the co-work drafting/mockup spans and the claude-design branch inline)**; step 4 L27–32 @19251–20989; **steps 5–7 @20990–22713 (finish-slice, validate, commit + attribution)**; decomposition L37 @22715; review L41 @28458; tail L43–51. The steps are a numbered sequence, so do not reorder them: **shrink step 3** by moving its co-work material (the `drafter` drafting span, the mockup span, the `claude-design` branch, the per-window reporting) to a new titled paragraph after step 7 and before the decomposition paragraph (e.g. `When the selected slice is a design slice (kind: co-work) …`), leaving in step 3 the dispatch rules (background task, one executor, route table resolve/pin/dispatch/record, Explore) and one pointer sentence to the moved paragraph. Then steps 5–7 end ≈ 14–15 KB. Put the resume paragraph right after L14's pending halt.

**The resume line** (same words in both skills, adapted to each file's voice — the `SessionStart` hook prints `compaction=done source=compact`, the `next` output and a resume sentence, so this is the skill-side half): after a context compaction, re-read this `SKILL.md` from disk (only its first 5,000 tokens were re-injected), then the active slice folder (`plan.md`, `result.md`) and `phase.md`'s `## Now`; an executor dispatched before the compaction is still running and the harness lists it — wait for its completion notification, never re-dispatch; the mode word (`auto`/`gate`/`plan only`) and any open operator gate are in the summary's kept facts.

**Facts for the doc notes:** all in `phase.md` `## Decisions` and the S1/S2 notes (rules in order, fail-safes, allow = silent stdout, the stderr trace line, `AGENTIC_COMPACT_CEILING` / `AGENTIC_COMPACT_BLOCK_CAP`, the counter file, the dirty exclusion list, the retry-after-block reading, `compact-resume`'s output, the hook commands and timeouts, the installer merge on `--update` / retrofit / nested with sidecar-or-refuse on a malformed file, idempotence, the ~300k window guidance set by `/autocompact 300k`, smoke 289 PASS). The `operations.md` sections that will take them: *Executor tiers* or a new *Compaction* section (the docs phase decides), *Updating an adopted workspace*, *Adopting into an existing repo*, *Nested personal install*, *Environment Variables* (the two new env names, read by the engine), *Building and releasing the installer* (the hooks are embedded in settings). Doc notes reference **text**, never line numbers (this slice moves lines).

## Do

1. **`CLAUDE.md`**: append `## Compact Instructions` after `## Commit Convention` — ≤ ~450 B, in the contract's voice: *Keep*: the operator's literal words and every open gate or `pending` item; the running skill and its mode word; each dispatched executor's task id with its slice id and pinned dispatch; decisions not yet on disk. *Drop*: tool output and file contents that already live in `plan.md`, `result.md` or `phase.md`; resolved lookups. One closing clause: after compaction the pointer and resume line come from the `SessionStart` hook. Then trim phrasing elsewhere until `wc -c CLAUDE.md` ≤ 12,288, per the candidates above; no rule disappears.
2. **Reorder `do-whole-phase`** exactly as the target order above, adding the resume bullet; byte-identical bullets otherwise (whitespace included).
3. **Restructure `do-next-slice`** as above: the resume paragraph after the pending halt; step 3 shrunk with its co-work material moved whole into a titled paragraph after step 7, plus the one pointer sentence; nothing else reworded.
4. **Prove the moves**: for each skill, `diff <(sort old) <(sort new)` (old = `git show HEAD:<path>`) must show only the added resume text, the pointer sentence and the moved paragraph's new title line — every other line identical; report the byte offset where the last invariant ends (`do-whole-phase`: the end of the commit bullet; `do-next-slice`: the end of step 7) and `wc -c` of each file in `result.md`. Both offsets < 16,000.
5. **`## Doc impact`** in `phase.md`, one line per durable-truth change, tagged with the slice that made it (S1, S2, S3), covering: `operations.md` (the two hooks, the gate's rules and fail-safes, the trace line, the env overrides, `compact-resume`, the installer hooks merge on the three paths and the sidecar/refuse behaviour, the ~300k window guidance and `/autocompact 300k`, relaunch needed for new project hooks), `architecture.md` (two engine subcommands and what they read; settings carry hooks; `_merge_settings_dict`), `decisions.md` (boundary-gated compaction by veto, the rejected alternative "orchestrator-driven compaction" and why; fail-open; the dirty-tree definition; the contract's new size under the cap; the skills' 16 KB invariant window), `qa.md` (smoke 289 PASS at P34.S2; checklist lines are the review's gate section). Reference text, not line numbers.
6. `python3 installer/build.py`, then `--check`.
7. **`phase.md`**: consume the three S3 notes; add Decisions for the final shapes (the contract's final size, each skill's last-invariant offset, the moved paragraph's title); leave S4 a tagged note listing what the `## v55` CHANGELOG entry must name (hooks on by default, `compact-gate` / `compact-resume`, the env overrides, the installer hooks merge, the contract section, the skill reorder, smoke 289) and its Migration notes line (adopters: `--update` adds the hooks; nested → `settings.local.json`; relaunch Claude Code; optional `/autocompact 300k`); rewrite `## Now` for S4.

## Validate

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh` — alone in its Bash call (the skills and contract are embedded; the suite must still pass, 289 PASS)
- `wc -c CLAUDE.md` ≤ 12,288; the two offsets < 16,000; the sorted diffs show only the additions named above.

## Not in this slice

No engine, settings, installer or test changes (S1/S2 done); no version bump or CHANGELOG (S4); no `doc-new-version` (a docs phase pays the notes; the review writes only its gate sections); no commit; no change to `review-phase` or any other skill.

## Dispatch

slice=P34.S3
phase=P34
kind=implementation
risk=low
attempt=1
route=mid
reason=kind implementation rated low
tier=mid
subagent_type=slice-executor-mid
model=sonnet
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Sonnet 5.5
explore_model=haiku
explore_effort=high
