# P8.DECOMP result — decomposition of "Auto-explain at phase review"

## What I did

Decomposed P8 into **one atomic implementation slice** and settled the five design
decisions the plan asked me to close. Created the bare slice folder (no `plan.md`
pre-filled) and recorded the breakdown, settled decisions, verified touch surface,
constraints, and Doc-impact expectations in `phase.md`.

### Slice created

- **`P8.S1` "Auto-explain the phase at a passing review"** — `kind: implementation`,
  `risk: high`, `order: 10`, `depends_on: []`. Bare folder — only `slice.json`; `plan.md`
  intentionally NOT written (the slice authors its own at its turn).
  Created with:
  `python3 scripts/workflow.py new-slice --phase P8 --slice P8.S1 --name "Auto-explain the phase at a passing review" --kind implementation --risk high --order 10`

Single slice because the same-commit installer-rebuild rule is indivisible (machinery
prose + contract + version bump + CHANGELOG + README + `installer/build.py` rebuild must
land in one commit, exactly like P7.S1). `risk: high` — not `medium` like P7.S1 — because
this slice authors new procedural machinery, edits the core contract (`CLAUDE.md`/`AGENTS.md`),
and carves a scoped exception into a core executor safety invariant ("never commit"),
all shipping to every adopter: design judgment with real blast radius, warranting the top
tier rather than a mid-tier attempt-then-escalate. Full rationale in `phase.md` →
Decomposition.

### Five decisions — settled (full rationale in `phase.md` → Findings)

1. **Who runs explain** → the review executor (`slice-executor-high`), by locating the
   installed `explain/SKILL.md` and following it — referencing, never duplicating, the skill body.
2. **Skill detection + graceful skip** → ordered search (project → user → plugin cache →
   marketplace clones); not-found or `KB_STATUS=unconfigured|error` → skip with a note; the
   explain outcome NEVER changes the review verdict (reported as one line).
3. **Pass-gated** → explain fires only on a `pass`, after validation, alongside doc
   consolidation; change-ref = this phase.
4. **Executor research tools** → ADD `WebSearch, WebFetch` to `.claude/agents/slice-executor-high.md`
   `tools:` (Claude high only) so the cited "Best practices & next steps" section can run;
   safe (read-only, survives `sync-agents`, no drift). Codex mirror keeps no `tools` key →
   degrades to `skipped-offline`, which the skill handles.
5. **KB-repo commit carve-out** → narrow scoped exception to "never commit": the review
   executor MAY run the skill's `git -C <KB_ROOT> add/commit` only in the separate KB repo,
   only as the API-unreachable offline fallback, never in this workspace, never `push`.
   API-reachable path needs no carve-out (the KB API commits server-side). Codex degrades
   to skip under `workspace-write`.

## Verification of the plan's findings (against the real files)

Confirmed as stated:
- Explain skill v2 exists at `~/.claude/skills/explain/SKILL.md`, fully procedural, and its
  step 3 says verbatim it "runs unattended at automated phase reviews — the offline path
  must always fall through to a successful save." Change mode covers "a phase."
- `~/.claude/plugins/cache/` exists (the plugin-cache search path is real on this machine).
- Review executor = `slice-executor-high` (`.claude/skills/review-phase/SKILL.md`,
  `.claude/agents/slice-executor-high.md`, `.codex/agents/slice-executor-high.toml`);
  its `tools:` is `Read, Edit, Write, Glob, Grep, Bash` (no web tools); the Codex toml has
  no per-agent `tools` key.
- `installer/main.py` `WORKSPACE_VERSION = 15` (line 38); CHANGELOG top is `## v15`; docs
  latest are operations **v0015** and decisions **v0021**.
- No `.agents/skills/do-whole-phase` (Claude-only), confirmed.

**One correction to the plan** (recorded in `phase.md` → Findings + Constraints):
`CLAUDE.md` and `AGENTS.md` are **not** byte-equal — they differ ONLY at line 1
(`# CLAUDE.md` vs `# AGENTS.md`) and line 3 (the swapped "Equivalent to …" pointer);
lines 4–100 are byte-identical. S1 must apply the contract-body edit identically to both
while preserving each file's own two header lines — not try to make them fully byte-equal.

## Validation

- `python3 scripts/workflow.py new-slice --phase P8 --slice P8.S1 …` → **created** P8.S1
  (bare folder: `slice.json` only, no `plan.md`).
- `python3 scripts/workflow.py validate` → **passed** ("Workflow validation passed.").
- `python3 scripts/workflow.py next` → confirms `next_slice=P8.S1`, REVIEW remains last.

## Doc impact

No docs versioned here (decomposition never versions docs). Seeded the phase's "Doc impact"
expectations in `phase.md` for P8.REVIEW to consolidate:
- **operations** — review procedure now also produces a phase explainer on a pass (review =
  validate + docs + explain), gracefully skipped when the plugin/KB is absent; workspace v16;
  adopter setup pointer.
- **decisions** — a passing phase review auto-produces a phase explainer via the external
  explain skill (review-executor-run, ordered skill-detection with graceful skip, pass-gated,
  outcome never affects verdict, `WebSearch/WebFetch` added to the Claude high executor,
  scoped KB-repo-only commit carve-out; Codex degrades).

## Deviations from plan.md

- The plan described `CLAUDE.md`/`AGENTS.md` as "(byte-equal)"; I found they differ in
  their two header lines only (title + mirrored pointer) and recorded the correction so S1
  edits them body-identically rather than attempting full byte-equality. No change to the
  decomposition itself.
- Everything else matches the plan: single atomic implementation slice à la P7.S1, all five
  decisions settled and recorded, `validate` green, middle slice folder bare.
