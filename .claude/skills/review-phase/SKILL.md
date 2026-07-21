---
name: review-phase
description: Review a completed phase against its objective and record a pass / changes_requested / blocked verdict.
allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write, Glob, Grep, Bash
disable-model-invocation: true
---

# review-phase

The phase review is executed by `slice-executor-high` — the top executor tier; reviews never run on a lower tier — dispatched by the orchestrator at the `REVIEW` slice; this is its checklist. It is where the phase's slices are **validated together** — the orchestrator trusted each executor's `done` and did not re-run per-slice validation, so re-run it here across the whole phase — and where the phase's durable-doc changes are **consolidated into new versions on a passing review** (from the "Doc impact" notes in `phase.md`). Write only docs here, never source code; do not implement fixes — those are done by fix slices.

Read:

- `AGENTS.md` (or `CLAUDE.md`)
- `docs/current/*.md` relevant to the phase, and `docs/index.json`
- `works/state.json`, `works/backlog.md`
- the phase folder under `works/phases/active/<P>/` and each completed slice's `slice.json` + `result.md`

Check:

- Did the phase objective actually ship?
- Did each slice meet its brief and plan? Are deviations explained in `result.md`?
- **Validate all slices together** (the orchestrator no longer re-runs per-slice validation): re-run each slice's validation commands from its `plan.md` / `result.md`, plus `python3 scripts/workflow.py validate`. Do they pass across the finished phase?
- Were the phase's durable-truth changes (product, architecture, API, …) consolidated into new doc versions **at this review** — not per-slice, not in-place edits?
- Do `docs/current/*.md` match the latest versions in `docs/index.json` after consolidation? (`python3 scripts/workflow.py validate` checks this.)
- Are any issues serious enough to require fix slices?

On a **passing** review, before recording `pass`, consolidate docs: for each durable-truth area changed across the phase (per the "Doc impact" notes in `phase.md`), run `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source <P>.REVIEW`, edit only the returned `edit_path`, then `python3 scripts/workflow.py rebuild-docs` — one version per affected doc, capturing the whole phase. On `changes_requested` / `blocked`, version nothing — fixes land first and the eventual passing re-review consolidates them.

On a **passing** review, after consolidating docs, also **auto-explain the phase** — produce a phase explainer via the knowledge plugin's installed explain skill. This is best-effort: like doc versions it fires **only on a passing review** (on `changes_requested` / `blocked` there is no explainer), and its outcome **NEVER** changes the `review_verdict`. **Locate the installed explain skill** (first hit wins): project `.claude/skills/explain/SKILL.md` → user `~/.claude/skills/explain/SKILL.md` → plugin installs (a bounded search, e.g. `find ~/.claude/plugins -maxdepth 8 -path '*/skills/explain/SKILL.md'`, covering `cache/` and `marketplaces/`). None found → skip and report `explain: skipped (skill not installed)`. Found → **read that `SKILL.md` and follow its instructions as written** (never duplicate its procedure here — it would drift from the plugin), in **change mode with this phase as the change-ref**. The skill's own steps govern: its KB config probe (`KB_STATUS=unconfigured` / `error` → skip with a note), its research judgment gate (degrades to `skipped-offline` when web tools are unavailable or erroring — never blocks the save), its API save, and its API-unreachable local fallback. **Scoped commit exception:** the skill's offline fallback commits the explainer in the KB repo with `git -C <KB_ROOT> …` — allowed **only** there (a separate git root), **never** in this workspace's repo and **never** any push; where the environment cannot write outside the workspace (e.g. a Codex `workspace-write` sandbox), treat the fallback as an automatic skip and report it. Report one **`explain:` outcome line** in `result.md` and the structured return — `saved <url-or-path>` | `skipped (skill not installed)` | `skipped (KB unconfigured)` | `skipped-offline` | `failed (<short reason>)` — even `failed` never flips the verdict.

The orchestrator records exactly one verdict (the executor returns it; the executor never runs `review-phase` itself):

```sh
python3 scripts/workflow.py review-phase <P> --verdict pass --reviewer slice-executor-high --note "short justification"
# or
python3 scripts/workflow.py review-phase <P> --verdict changes_requested --reviewer slice-executor-high --note "numbered issues + proposed fix slices like P1.F1"
# or
python3 scripts/workflow.py review-phase <P> --verdict blocked --reviewer slice-executor-high --note "the blocker and needed input"
```

`pass` also marks the phase `done` **and closes the `REVIEW` slice** — the phase stays in `active/`; archiving is a separate, manual step (`archive-all`, `rotate-backlog`, or `archive-phase`). `changes_requested` returns the phase to `in_progress` and sets the `REVIEW` slice to `changes_requested` (reopened for re-review). `blocked` sets **both the phase and the `REVIEW` slice** `blocked`.
