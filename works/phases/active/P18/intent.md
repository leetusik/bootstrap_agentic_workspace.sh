# Intent — P18

- Captured at: 2026-08-29T10:57:12+09:00
- Origin: operator

## Original Input (verbatim)

> well, let's say if there is more then 20 slices in one phase, would phase.md and current workflow fine?

> you suggest. research changple5 implementations. give me best phase.md and result.md handling strategy. I mean,
> 1. I don't want to waste tokens.
> 2. I want a doc that can grasp the whole phase though.
> 3. maybe using cache? not only for the phase and result but also claude.md and stuff.

## Confirmed Intent (refined + clarified)

Rework how the workspace handles the phase notebook and the per-slice result so a phase stays cheap and legible at any slice count, guided by what the field has settled on (Anthropic's context-engineering guidance, Manus's KV-cache/recitation rules, Cognition's single-thread compression argument, and the persistent-notes patterns in Ralph/beads/spec-kit). Four parts:

1. **`phase.md` becomes a bounded, rewritten state doc** — the one document that grasps the whole phase and doubles as the orchestrator's handoff. Fixed seed, moved from the inline string in `scripts/workflow.py` into `works/templates/phase.md` (embedded in the installer): `## Objective`, `## Slices` (an engine-generated block between `<!-- slices:begin -->` / `<!-- slices:end -->` markers, rendered by `rebuild` from `slice.json`: id, name, kind/risk, status, one-line outcome, `result.md` link), `## Decisions` (superseded lines replaced, never stacked), `## Doc impact` (append-only; seeded so the heading no longer drifts), `## Operator Questions` (append-only), `## Notes for later slices` (each tagged with its source slice; a slice that consumes a note removes it), and `## Now` (≤ 15 lines, rewritten by every slice, last on purpose — the recitation block). `## Context`, `## Findings & Notes`, `## Constraints`, and `## Open Questions` leave the seed. Executors *edit* the file under budget; prose findings, dead ends, and command output go to their own `result.md`. Compression is restorable: the pre-edit file is in git (every slice commits) and the detail is in `result.md` by path.

2. **`result.md` stays the per-slice log**, free-form, but with the structured verdict block **first** so the orchestrator and the review can `head` it. The review still reads every `result.md`, and additionally cross-checks `phase.md` against them for a dropped decision or an unrouted question, since the notebook is now rewritten.

3. **Engine support in `scripts/workflow.py`**: `finish-slice <id> --outcome "one line"` stored in `slice.json` (warn, never error, when omitted); the generated `## Slices` block regenerated on every `rebuild_index_and_state` and left untouched when the markers are absent (legacy phases, adopters who removed it); `new-phase` seeds from the template with an embedded fallback; `validate` warns (never errors) when `phase.md` exceeds `PHASE_MD_BUDGET = (200 lines, 16 KB)` and on a `## Doc Impact` case-drifted heading (and the literal at the `parallel-merge-finish` hint is fixed); `finish-slice` prints the current notebook size; the `- Rebuilt at:` line leaves `works/backlog.md` and `works/deferred.md` (`index.json` / `state.json` keep their machine-read timestamps), ending the timestamp-only tree churn on every `next`.

4. **Reads become just-in-time.** The executor agents (both tiers, byte-identical below frontmatter) read `plan.md` → `phase.md` → `intent.md` only if unsure → the `docs/current/` *sections* the plan names, never the whole doc set. The orchestrator skills (`do-next-slice`, `do-whole-phase`, `review-phase`, `create-phase`) re-read the bounded `phase.md` and the verdict after each slice, drop the per-slice re-read of `works/backlog.md`, and read `result.md` head-first. The contract's Read Order becomes: `works/state.json` + `next` → the active phase and slice folders → the `docs/current/` sections the work touches (`workflow.py docs` for the list), never all eleven docs up front and never `docs/index.json` (version history). `design-cowork`'s build inventory and landed spec still live in `phase.md` and count against the budget.

Ships as workspace **v35**: version bump, CHANGELOG entry, installer file lists gain `works/templates/phase.md`, and every slice that touches an embedded file rebuilds `bootstrap_agentic_workspace.sh` in its commit. Durable docs are consolidated at the review.

## Clarifications Resolved

- Q: How wide should the phase be — notebook only, notebook + docs read-order, or also a CLAUDE.md slimming slice? — A: **Notebook + docs read-order.** CLAUDE.md slimming (33 KB → ≤ 12 KB) is filed as deferred job **D8**, triggered after P18 lands.
- Q: Should any prompt-cache setting change (`subagentPromptCacheTtl`, executor `experimental.cacheTtl: 1h`)? — A (agent's recommendation, accepted in the approved plan): **No.** Claude Code already caches automatically (system → CLAUDE.md → conversation; the main thread is on the 1-hour TTL). Moving executors to 1 h doubles the write cost across a whole ~150K-token run to save ~13K tokens on the next dispatch's first request — a net loss. File reads land as messages, not prefix, so churn never invalidated a cache; size is the lever. Revisit only with `/usage` numbers.
- Q: Who rewrites `phase.md` — orchestrator or executor? — A: **The executor**, which already owns step 4 and holds the slice's result fresh; the review's cross-check is the safety net.
- Q: Hard cap or warning on the budget? — A: **Warn, never error** — a hard cap invites truncating exactly the notes that matter; the review sees the warning.
- Q: A third append-only journal file beside `phase.md` and `result.md`? — A: **No.** `result.md`, sharded by slice and linked from the `## Slices` table, is the journal.

## Notes

- Measured basis: recent phases accumulate 68–91 `phase.md` lines per slice; P15 reached 819 lines with `## Findings & Notes` at 673 (82 %) and eight total deletions across the phase; every dispatch (orchestrator and executor) re-reads the whole file, so the cost is ~40·N² lines per phase. The largest phase this repo has run is 10 slices; the `paired` design style shipped in P17 raises slice counts by construction.
- Per-dispatch fixed prefix today: `CLAUDE.md` 33 KB + executor body 18 KB; `docs/current/*.md` totals 330 KB (`decisions.md` 1074 lines, `operations.md` 988 — 73 % of the set); `docs/index.json` 54 KB.
- Approved plan (session record): `~/.claude/plans/the-design-cowork-pattern-wiggly-brook.md` — includes the expected slice shape (S1 engine, S2 agents + skills, S3 contract, S4 release) as guidance for `DECOMP`, not binding. Gate expectation: `accept-gate P18 --waive` (workspace machinery, nothing operator-visible in a product).
- Dependency: nothing. P17 is `done` and unarchived; `new-phase` printed no parallel hint.
