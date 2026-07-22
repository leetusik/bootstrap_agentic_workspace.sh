# Plan — P9.REVIEW (phase review: Knowledge-by-default in bootstrapped workspaces)

Operator-approved orchestrator plan (2026-07-22). Executor: `slice-executor-high`. Your checklist is `.claude/skills/review-phase/SKILL.md` — follow it as written; this plan only scopes it to P9.

## Job

Validate P9's slices together, review against the objective/intent, and — only on a passing review — consolidate the phase's Doc-impact notes into new doc versions and auto-explain the phase. Write docs only, never source; do not implement fixes (propose fix slices instead).

1. **Read**: `CLAUDE.md`; `docs/current/operations.md` + `docs/current/decisions.md` + `docs/index.json`; `works/state.json` / `works/backlog.md`; the P9 folder — `phase.md`, `intent.md`, and each slice's `slice.json` + `plan.md` + `result.md` (P9.DECOMP, P9.S1, P9.S2).
2. **Validate all slices together** (the orchestrator trusted each `done` and did not re-run per-slice validation):
   - `python3 installer/build.py --check` — artifact in sync with `installer/` source.
   - Artifact spot-checks from S1's plan: `bootstrap_agentic_workspace.sh` contains `KB_API_TOKEN`, `WORKSPACE_VERSION = 17`, `Knowledge (optional)`, `Knowledge (phase explainers)`.
   - S1 consistency: `installer/main.py` has `WORKSPACE_VERSION = 17`; `CHANGELOG.md` has a `## v17` entry with Migration notes; the seed `installer/payloads/doc_bodies/operations.md` knowledge section matches the canonical framing in `phase.md`.
   - S2: `README.en.md` knowledge callout leads with the env-var/REST default (plugin as alternative, Codex `network_access` caveat, never-a-repo-`.env`); Korean `README.md` and `CLAUDE.md`/`AGENTS.md` untouched by S2.
   - `python3 scripts/workflow.py validate`.
3. **Review against objective/intent** (`intent.md` is the confirmed source of truth): fresh workspaces now receive the env-var/REST knowledge default; the Codex sandbox blocker is documented with the opt-in and tradeoff; the SaaS contract is consumed, never implemented; no engine-logic changes snuck in; deviations explained in each `result.md`.
4. **On a pass, consolidate docs** per the two Doc-impact notes in `phase.md`: `python3 scripts/workflow.py doc-new-version --doc operations --summary "..." --source P9.REVIEW` and `... --doc decisions ...`; edit only each returned `edit_path` (one version per doc, capturing the whole phase); then `python3 scripts/workflow.py rebuild-docs`.
5. **On a pass, auto-explain** exactly per the skill text (best-effort, verdict-neutral): locate the installed explain skill (project `.claude/skills/explain/SKILL.md` → user → plugin installs), follow it in change mode with phase P9 as the change-ref; its own KB config probe / research gate / API save / offline fallback govern; the scoped KB-repo commit exception only — never this repo, never a push. Report one `explain:` outcome line.
6. **Wrap up**: write `result.md` (review findings, validation results, doc versions created, `explain:` outcome); append review notes to `phase.md`; return `review_verdict` (pass | changes_requested with numbered issues + proposed `P9.Fn` fix slices | blocked) + the `explain` outcome.

## Never

Run `review-phase` yourself; commit in this repo (the KB-repo offline-fallback carve-out is the only exception); transition slice/phase status; edit source or machinery; version docs on anything but a pass.

## Verification (orchestrator, after your return)

`review-phase P9 --verdict <verdict>` recorded; `python3 scripts/workflow.py validate` passes; on a pass, `docs/index.json` shows operations v0017 and decisions v0023 with regenerated `docs/current/*.md`.
