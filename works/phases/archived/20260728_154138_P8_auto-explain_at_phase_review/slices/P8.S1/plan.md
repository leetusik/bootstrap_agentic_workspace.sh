# P8.S1 plan — Auto-explain the phase at a passing review

## Context

Second slice of `/do-whole-phase` on P8 (manual-approval mode). P8.DECOMP is done and committed (`d24edaa`): it created **P8.S1** (kind implementation, **risk high** → `slice-executor-high`, order 10) and settled the five design decisions in `phase.md`. This plan turns those settled decisions into concrete edits. One atomic slice: all machinery edits + v16 bump + CHANGELOG + README + rebuilt installer land in **one commit** (pre-commit `--check` enforces).

Goal: a **passing** phase review also produces a phase explainer via the knowledge plugin's explain skill — review = validate + consolidate docs + **explain** — best-effort, gracefully skipped when the skill/KB is unavailable, outcome **never** changes the verdict.

## Edits (per file; bodies of mirrored files stay identical)

### 1. `.claude/skills/review-phase/SKILL.md` + `.agents/skills/review-phase/SKILL.md` — the main edit

Insert a new **auto-explain** paragraph after the "On a **passing** review, before recording `pass`, consolidate docs: …" paragraph. Content requirements:

- Fires **only on a passing review, after doc consolidation**; on `changes_requested`/`blocked` no explainer (like doc versions). Best-effort: the outcome NEVER changes the `review_verdict`.
- **Locate the installed explain skill** — first hit wins: project `.claude/skills/explain/SKILL.md` → user `~/.claude/skills/explain/SKILL.md` → plugin installs (bounded search, e.g. `find ~/.claude/plugins -maxdepth 8 -path '*/skills/explain/SKILL.md'`, covering `cache/` and `marketplaces/`). None → skip, report `explain: skipped (skill not installed)`.
- Found → **read that SKILL.md and follow its instructions as written** (never duplicate its procedure here — drift risk), in **change mode with this phase as the change-ref**. The skill's own steps govern: its KB config probe (`KB_STATUS=unconfigured`/`error` → skip with note), its research judgment gate (degrades to `skipped-offline` when web tools are unavailable or erroring — never blocks the save), its API save, its API-unreachable local fallback.
- **Scoped commit exception:** the skill's offline fallback commits in the KB repo (`git -C <KB_ROOT>`) — allowed **only** there (a separate git root), never in this workspace's repo, never any push. Where the environment cannot write outside the workspace (Codex `workspace-write` sandbox), treat the fallback as an automatic skip and report it.
- Report one **`explain:` outcome line** in `result.md` and the structured return: `saved <url-or-path>` | `skipped (skill not installed)` | `skipped (KB unconfigured)` | `skipped-offline` | `failed (<short reason>)` — even `failed` never flips the verdict.

Mirror rule (verified): the two copies differ only in the `.claude` frontmatter's `allowed-tools:` + `disable-model-invocation:` lines; bodies must stay byte-identical.

### 2. `.claude/agents/slice-executor-high.md`

- Frontmatter `tools:` → `Read, Edit, Write, Glob, Grep, Bash, WebSearch, WebFetch` (Decision 4; verified `sync-agents` patches only `model:`/`effort:`, so this survives and `sync-agents --check` stays green). **Only this file** — mid/low and the Codex toml untouched on tooling.
- "Do" step 1 **review-slice bullet**: append — on a `pass`, after consolidating docs (step 5), also produce the phase explainer (auto-explain) by locating and following the installed knowledge-plugin explain skill as the review checklist (`.claude/skills/review-phase/SKILL.md` / `.agents/skills/review-phase/SKILL.md`) specifies; best-effort, outcome reported, never changes the `review_verdict`.
- "Never" **commit bullet**: add the scoped exception — a review slice's auto-explain offline fallback may run the explain skill's own `git -C <KB_ROOT> add/commit` in the separate knowledge-base repo; never in this workspace's repo, never any push.
- **Verdict block**: add field `explain`: (review slice only) the auto-explain outcome line (`saved <url-or-path>` | `skipped (<reason>)` | `skipped-offline` | `failed (<reason>)`).

### 3. `.codex/agents/slice-executor-high.toml`

Mirror the three **body** edits from §2 (review bullet, Never carve-out, `explain` verdict field) into `developer_instructions` — its body text is currently identical to the `.md` body; keep it so. **No `tools` key** (Codex governs tools via `sandbox_mode`; no web research there → the skill's `skipped-offline` path; no outside-workspace writes → fallback = skip).

### 4. Driving-skill review paragraphs

- `.claude/skills/do-whole-phase/SKILL.md` line ~26: extend "— **only on a passing review** — consolidates the phase's "Doc impact" notes … into new doc versions (writing only docs, never source)" with "and produces the phase explainer via the installed knowledge-plugin explain skill (auto-explain — best-effort, gracefully skipped when the skill/KB is unavailable; the outcome never changes the verdict)"; "It returns a `review_verdict`" gains the `explain` outcome mention.
- `.claude/skills/do-next-slice/SKILL.md` line ~33 (same sentence shape) + byte-identical body edit in `.agents/skills/do-next-slice/SKILL.md` (~31). No `.agents` do-whole-phase (confirmed absent).

### 5. Contract — `CLAUDE.md` + `AGENTS.md`

Body-identical edits from line 4 on; preserve each file's own lines 1 & 3 (verified NOT byte-equal — headers differ). Two clause-level appends, kept compact:

- *Driving This Workspace* orchestrator/executor paragraph: "…behavioral validation is consolidated into the phase review, which validates all slices at once and consolidates the phase's durable-doc versions" + ", and — on a pass — produces the phase explainer via the knowledge plugin's explain skill (auto-explain; gracefully skipped when the skill/KB is unavailable)".
- Hard Rules "Every slice — …" bullet's matching clause ("behavioral validation and durable-doc consolidation are done by the phase review …") gets the same short "+ explain" extension.

### 6. `README.en.md`

- Line ~46 **Review gates** bullet: mention the review also consolidates doc versions and — with the knowledge plugin installed — files a phase explainer into your KB.
- Lines ~281–282 `slice-executor-high` description: "…validating the phase and consolidating its doc versions" + "and, on a pass, producing the phase explainer via the knowledge plugin's explain skill (gracefully skipped when absent)".
- Optional one-liner in the plugin box (~273–276): with the plugin installed, a passing phase review files a phase explainer automatically.
- No skill-count changes (no skill added/removed).

### 7. Version + CHANGELOG

- `installer/main.py` line 38: `WORKSPACE_VERSION = 15` → `16`.
- `CHANGELOG.md`: one new top entry `## v16 — <today>` (style of v15): passing review now auto-produces a phase explainer (detection order, pass-gated, verdict-neutral graceful skip), `WebSearch`/`WebFetch` added to the Claude high executor, scoped KB-repo-only commit carve-out, Codex degrades to skip. **Migration notes**: no action required (the step self-skips without the plugin); adopters who want auto-explain install the knowledge plugin + `/knowledge:setup`; executor confirms whether `--update` needs a `sync-agents` re-run note (agent-file payload changed) and words it accordingly. Never patch historical entries.

### 8. Rebuild (same commit)

`python3 installer/build.py`; stage the rebuilt `bootstrap_agentic_workspace.sh` with everything above. `works/templates/` untouched (no review wording — verified). No new test files (keep tests lean).

## Validation (executor runs; orchestrator re-runs only `validate`)

- `python3 installer/build.py --check` → green
- `python3 scripts/workflow.py sync-agents --check` → green (tools: edit must not trip drift)
- `bash tests/retrofit_smoke.sh` → all pass (installer regression)
- `python3 scripts/workflow.py validate` → green
- Mirror checks: `diff <(tail -n +4 CLAUDE.md) <(tail -n +4 AGENTS.md)` empty; review-phase and do-next-slice `.claude`/`.agents` bodies identical (frontmatter-only diff); `.md`/`.toml` high-executor bodies identical.
- Spot greps: auto-explain wording present in all edited machinery files AND embedded in the rebuilt artifact; `WORKSPACE_VERSION = 16` in source + artifact.
- Append/confirm the two Doc-impact one-liners in `phase.md` (operations, decisions — seeded by DECOMP).

## Orchestration after approval

Write this plan to `works/phases/active/P8/slices/P8.S1/plan.md` → `start-slice P8.S1` → dispatch **`slice-executor-high`** (risk high) as a background Agent task and wait → on `done`: read `result.md`, `finish-slice P8.S1`, `validate`, commit everything in **one commit** (`feat(review): auto-explain the phase at a passing review`) → loop: plan P8.REVIEW at the gate.

**Dogfood note:** P8's own REVIEW (next slice) will exercise this for real — this machine's KB resolves via the legacy convention, so expect an actual explainer save (API at `localhost:8766` up → 201; down → KB-repo fallback commit or a reported skip).
