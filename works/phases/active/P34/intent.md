# Intent — P34

- Captured at: 2026-10-12T16:29:49+09:00
- Origin: operator

## Original Input (verbatim)

> and currently autocompact on 500k. resaerch if compaction can be executed by orchestrator intendedly(like compact when slice executor dispatched, then compact and prep for next slice..) or just as is with 500k autocompaction. you suggest.

After the orchestrator's research and first recommendation (2026-10-12), the operator sharpened the goal:

> What I want to avoid is compaction in the middle of process. like receiving the message, do validation and stuff -> compact -> commit -> kind of work.

Then, after the boundary-veto proposal:

> /create-phase for the task.

and, correcting the phase id during creation:

> it's p34

## Confirmed Intent (refined + clarified)

**Compaction must not fire in the middle of a slice step.** The sequence the operator named — the executor's return arrives, the orchestrator validates, **compaction fires**, then the commit — must become impossible; compaction lands at the **slice boundary** instead: after the commit, before the next slice is planned, so the order is *commit → compact → plan the next slice*. The orchestrator cannot start a compaction (Claude Code has three triggers only: the operator's `/compact`, summarize in `/rewind`, and the auto-compact window), so the phase builds the **veto** that steers the automatic one:

1. **Boundary veto.** A `PreCompact` hook (matcher `auto`) calls a small **engine command** that decides from state the engine already keeps: **block** while the current slice is `in_progress` (from `start-slice` through `finish-slice`) or `git status --porcelain` is non-empty; **allow** at a clean boundary — the slice is `done`, `pending` or the review is recorded, and the tree is clean. Two **fail-safes** so the veto can never cause a context-limit error: allow above a **hard fill ceiling** (about 850k on a 1M model) computed from the latest assistant `usage` in the transcript the hook receives (`input_tokens` + `cache_read_input_tokens` + `cache_creation_input_tokens`), and allow after a **cap of consecutive blocks**. The hook **fails open** (a crash allows compaction). Manual `/compact` (matcher `manual`) is never blocked.
2. **Post-compaction resume.** A `SessionStart` hook with the `compact` matcher prints `python3 scripts/workflow.py next` plus one resume line: re-read the running skill's `SKILL.md` from disk (compaction re-injects only its first 5,000 tokens), the active slice folder and `phase.md`'s `## Now`; background executors still running are listed by the harness itself.
3. **Compact instructions.** A short `# Compact instructions` section in `CLAUDE.md` (Claude Code honours it when summarizing): keep the operator's literal words and open gates, the running skill and its mode word, dispatched executor task ids with their slice ids, and decisions not yet on disk; drop tool output that already lives in `plan.md`, `result.md` or `phase.md`.
4. **Skill ordering.** Reorder `do-whole-phase` and `do-next-slice` so the loop invariants and the resume line sit within the first 5,000 tokens (today they are ~9,700 and ~8,000 tokens; truncation keeps the start).

**Default posture:** both hooks ship **on for everyone** — the installer merges them into project `.claude/settings.json` on install and update (the merge policy for `hooks` is new ground: additive, never clobbering an adopter's own hooks). The engine command follows the install layout (nested installs run the engine from `workflow/`).

**Out of scope, recorded as guidance:** the auto-compact window is the operator's personal setting (`autoCompactWindow`, or per model via `/autocompact`); the operations doc records the recommendation of about **300k** once the veto exists, because the window then means "the earliest allowed point", not "compact here".

**Ordering:** runs **after P32**, which rewrites the same two execution skills. Ships as **workspace v54** (P32 ships v53). Durable docs (operations: hooks, compaction, the window guidance) are versioned in a later docs phase.

## Clarifications Resolved

- Q: Which parts should the phase include — the boundary veto hook, the post-compaction resume hook, compact instructions in `CLAUDE.md`, reordering the execution skills? — A: **All four.**
- Q: Should the two hooks ship on by default for adopters, or only here? — A: **On for everyone.**
- Q: Create the phase with the stated name and objective? — A: **Yes** — and the id is **P34** (operator's correction; P33 is reserved by the operator).

## Notes

Findings from the orchestrator's 2026-10-12 research (Claude Code 2.1.296 docs: model-config, context-window, hooks, hooks-guide, prompt-caching, costs), for `DECOMP`:

- **Triggers.** Compaction starts only from `/compact [focus]`, `/rewind` → summarize, or the auto-compact window. No tool, skill or hook starts one. `PreCompact` (matchers `manual` | `auto`; input `trigger`, `custom_instructions`, `transcript_path`, `cwd`) can **block** via exit code 2 or `{"decision":"block"}`; its `systemMessage`/`continue` are discarded. **Blocking a proactive auto-compaction skips it and the conversation continues uncompacted; blocking one triggered to recover from a context-limit error makes the request fail** — hence the fill fail-safe and a window well below the limit. `PostCompact` (input `compact_summary`) has no decision control. **Verify at DECOMP:** whether Claude Code re-attempts auto-compaction on the next request after a proactive block (the docs say "skips it", not whether it retries; the fill check is per request, so a retry is expected).
- **Re-injection.** `SessionStart` with `matcher: "compact"` runs after auto and manual compaction; plain stdout (or `hookSpecificOutput.additionalContext`) is added to Claude's context; over 10,000 characters is saved to a file with a 2,000-character preview; phrase it as facts, not commands. `InstructionsLoaded` fires with `load_reason: "compact"` as `CLAUDE.md` is re-read.
- **What survives compaction.** `CLAUDE.md` and auto memory re-injected from disk; the plan-mode plan re-injected; up to five recently touched files re-read (over 5,000 tokens → path reference only); invoked **skill bodies re-injected capped at 5,000 tokens per skill, 25,000 total, oldest dropped first, truncation keeps the start**; **background subagents keep running and Claude is reminded which are still running**; hook-added context is summarized with the rest. The automatic summary keeps "requests and intent, key technical concepts, files examined or modified, errors and fixes, pending tasks, current work". `/compact <focus>` and a `# Compact instructions` section in the root `CLAUDE.md` steer it.
- **Window semantics.** `autoCompactWindow` = how full the context may get before compaction (100K–1M; capped at the model window). Operator's user settings today: top-level `autoCompactWindow: 500000`, `autoCompactEnabled: true`. Since 2.1.288 `/autocompact 300k` saves per model under `modelSettings`, which outranks the top-level key; `--autocompact` per launch; `CLAUDE_CODE_AUTO_COMPACT_WINDOW` outranks all. Default without a window: 1M-native models compact at about **967K**.
- **Cost shape.** The compaction request reads the cached prefix (1-hour TTL on a subscription), so a warm compaction costs a fraction of the fill; the recurring cost is the fill itself — every request re-reads it at the cache-read rate (Fable 5.1 $0.25/MTok, Opus 5.5 $0.20/MTok), average fill ≈ half the window. The docs' own advice: compact at a natural break rather than mid-task; `/clear` is free.
- **Fill measurement.** Transcript lines carry `message.usage` with `input_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`; their sum on the latest assistant message is the live fill (this session measured ~375k by that method on 2026-10-12).
- **Slice-cycle anchors.** In `do-next-slice`, `start-slice` runs at step 2 before planning and dispatch; `finish-slice` runs after the verdict; the commit follows `finish-slice` and `validate`. So "mid-process" = slice `in_progress` or dirty tree, and the first request after the commit is the boundary. During the executor's run the main thread makes no requests, so no compaction can fire there; it fires on the first request after the notification unless vetoed.
- **Sizes.** `do-whole-phase` ≈ 9,700 tokens, `do-next-slice` ≈ 8,000, `review-phase` ≈ 5,300, `CLAUDE.md` ≈ 3,070 (12,280 bytes; the contract is kept near 12 KB — the compact section must be short).
- **Settings surface.** Project `.claude/settings.json` holds the hooks (the installer currently merges `permissions` additively; `hooks` needs the same treatment). The hook must be fast, dependency-free (python3 + git), and exit 0 on any internal error.
