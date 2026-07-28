# P8.DECOMP plan — Auto-explain at phase review

## Context

`/do-whole-phase` on **P8 "Auto-explain at phase review"** (manual-approval mode). The phase extends the review machinery so a **passing** phase review also produces a phase explainer via the knowledge plugin's explain skill — review = validate + consolidate docs + **explain** — gracefully skipped when the skill/KB is unavailable. This is the plan for the first slice, **P8.DECOMP** (decomposition → dispatched to `slice-executor-high`). Each later slice gets its own plan gate.

**Gate (from `intent.md`) — verified satisfied (orchestrator-verified in `~/projects/personal/knowledge/works/backlog.md` and this repo's backlog):**
- knowledge `P16` (HTML pipeline): `done`, review `pass`
- knowledge `P17` (explain skill v2 + public ingestion): `done`, review `pass`
- bootstrap `P7` (retire embedded /explain): `done`, review `pass`

## Research findings to hand the DECOMP executor

**The explain skill v2 was designed for exactly this.** Canonical copy: `~/projects/personal/knowledge/plugin/skills/explain/SKILL.md` (also installed user-level at `~/.claude/skills/explain/SKILL.md` on this machine; the knowledge plugin is *not* in `~/.claude/plugins` here). The skill is fully procedural — config resolution via an exact `python3 -c` command (`KB_STATUS=unconfigured|error|configured`), save via exact `curl` commands to `<KB_API_BASE_URL>/api/documents`, an API-unreachable local fallback — and its research step says verbatim: *"This skill runs unattended at automated phase reviews — the offline path must always fall through to a successful save."* Change mode explicitly covers "a phase" as change-ref. Everything except WebSearch/WebFetch is runnable with the executor's tools (Read/Write/Glob/Grep/Bash), and the skill self-degrades (`skipped-offline`) when research tools are missing.

**`sync-agents` is safe:** `_patched_agent_md` / `_patched_agent_toml` in `scripts/workflow.py` rewrite only `model:`/`effort:` frontmatter (md) and `model`/`model_reasoning_effort` head keys (toml). Instruction-body edits to the executor agent files survive sync and don't trip `validate`'s drift check.

**Touch surface (verified):**
- `.claude/skills/review-phase/SKILL.md` + mirror `.agents/skills/review-phase/SKILL.md` — the review checklist (main edit)
- `.claude/agents/slice-executor-high.md` + `.codex/agents/slice-executor-high.toml` — review-slice steps in "Do"/verdict fields (and possibly the `tools:` list, see decision 4)
- Review paragraphs of `.claude/skills/do-whole-phase/SKILL.md`, `.claude/skills/do-next-slice/SKILL.md` + mirror `.agents/skills/do-next-slice/SKILL.md` (no `.agents` do-whole-phase — Claude-only)
- `CLAUDE.md` + `AGENTS.md` (byte-equal) — contract's review wording ("behavioral validation is consolidated into the phase review…")
- `README.en.md` review-flow prose (lines ~46, ~281); `CHANGELOG.md` new `## v16` + `WORKSPACE_VERSION` 15→16 in `installer/main.py` (now 15)
- Same-commit rebuild: `python3 installer/build.py`, `--check` green (pre-commit hook enforces). `works/templates/` has no review wording — untouched.

**KB state on this machine:** `~/.config/knowledge-kb/config.json` missing, but the legacy convention (`~/projects/personal/knowledge/mkdocs.yml` exists) resolves → configured. So P8's own review can dogfood the new step.

## Design decisions DECOMP must settle (record in `phase.md`)

1. **Who runs explain** — recommendation: the **review executor** (`slice-executor-high`), as part of the review slice, by locating the installed skill file and following its instructions. Not the orchestrator (authoring a ~500-line HTML explainer inline would bloat the main thread — the opposite of why we delegate). The machinery must **reference** the installed SKILL.md, never duplicate its body (it would drift from the plugin).
2. **Skill detection + graceful skip** — a small ordered search (project `.claude/skills/explain/SKILL.md`, user `~/.claude/skills/explain/SKILL.md`, plugin cache `~/.claude/plugins/cache/*/…/skills/explain/SKILL.md`, marketplace clones); not found → skip with a note; found but `KB_STATUS=unconfigured`/`error` → skip with a note. **The explain outcome never changes the review verdict** — report it as a line in `result.md` + the structured return.
3. **Pass-gated** — explain fires only on a `pass` verdict, alongside doc consolidation, after validation (intent note: operator framing puts it with the pass-gated consolidation step). Change-ref = this phase.
4. **Executor research tools** — decide whether to add `WebSearch`/`WebFetch` to `.claude/agents/slice-executor-high.md` `tools:` so the cited "Best practices" section can run in reviews (Codex mirror can't → `skipped-offline` there, which the skill handles).
5. **KB-repo commit carve-out** — the skill's API-down fallback commits in the *KB* repo (`git -C <KB_ROOT>`). The executor's "never commit" rule needs an explicit resolution: either a scoped carve-out (KB repo only, never this repo) or "skip the fallback commit, save + report". Codex sandbox (`workspace-write`) can't write outside the workspace → fallback fails there → treated as skip.

## What the DECOMP executor does

1. Read `phase.md`, `intent.md`, `AGENTS.md`, relevant `docs/current/*`; verify the findings above against the real files.
2. Settle decisions 1–5; record rationale in `phase.md` (Decomposition + Findings + Constraints sections).
3. Create the middle slice(s) with `new-slice` — **bare folders only, never pre-fill `plan.md`**; set `--risk` deliberately (it picks the executor tier), `--order` between DECOMP (0) and REVIEW (9999). Expected shape (executor's call): **one atomic implementation slice** à la P7.S1 — the edits, version bump, CHANGELOG v16, README prose, and installer rebuild must land in one commit, so a split leaves lying intermediate states.
4. Seed the "Doc impact" expectations in `phase.md` (likely: **operations** — review procedure now includes auto-explain + adopter setup pointer; **decisions** — review = validate + docs + explain, graceful-skip design).
5. Validate with `python3 scripts/workflow.py validate`; write `result.md`; return the structured verdict.

## Validation

- `python3 scripts/workflow.py validate` green after DECOMP (state integrity; middle slices exist, REVIEW last).
- `phase.md` records breakdown + the five decisions; middle slice folders are bare (`slice.json` only).
