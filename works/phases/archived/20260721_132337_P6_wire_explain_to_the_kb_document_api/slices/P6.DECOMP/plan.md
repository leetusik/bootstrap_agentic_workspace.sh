# P6.DECOMP — Plan (approved 2026-07-02)

Decompose P6 "Wire /explain to the KB document API". This slice creates the middle slices
as bare folders and seeds `phase.md` — no skill edits, no code, no pre-filling of the new
slices' `plan.md`.

## Orchestrator research findings — record these in phase.md

1. **Version drift — intent's release numbers are stale.** Intent says "bump
   WORKSPACE_VERSION 2→3 + `## v3`", but commit `da5e998` (the review-slice fix, 15:26
   today — before P6 intent capture at 16:45) already consumed v3: `installer/main.py` has
   `WORKSPACE_VERSION = 3` and CHANGELOG has `## v3`. The operator's resolved clarification
   was "follow the release rule" — applying it now means **3→4 + `## v4`** in the
   implementation commit. Approved by the operator in the DECOMP plan.
2. **build.py reads the live skill copies from disk** (`.claude/skills/*/SKILL.md`,
   `.agents/skills/*/SKILL.md` globs) — editing the two live files + `python3
   installer/build.py` is sufficient; no payload duplication. `--check` passes today.
3. **The two copies differ only by frontmatter lines 4–5** (`argument-hint`,
   `allowed-tools`) — the sanctioned difference, confirmed by diff.
4. **KB API is live and matches contract v0002** (`~/projects/personal/knowledge/docs/current/api.md`):
   `GET /healthz` → `{status:"ok", db:"ok", documents:1}`. Contract points the rewrite
   depends on: 201 body (`url`, `committed`, `commit_error`, `recent_updated`), 409 body
   (`existing_title`, `rel_path`), 422 validation, 401 only when `KB_API_TOKEN` set,
   `commit:false` → `committed:false` with no `commit_error`, overwrite suppresses the
   duplicate Recent bullet.

## Slices to create (exact commands)

    python3 scripts/workflow.py new-slice --phase P6 --slice P6.S1 \
      --name "Rewire /explain steps 5–7 to POST /api/documents (API-first, manual fallback)" \
      --kind implementation --risk medium --order 10
    python3 scripts/workflow.py new-slice --phase P6 --slice P6.S2 \
      --name "Sync updated /explain skill to ~/.claude/skills/explain (operator-authorized)" \
      --kind implementation --risk low --order 20

Scope to record in the phase.md breakdown:

- **P6.S1** (implementation, medium, order 10): rewrite steps 5–7 in both live skill copies —
  API-primary (`POST http://localhost:8766/api/documents`, curl, few-second timeout),
  transport-failure-only fallback (today's manual flow verbatim), HTTP-error handling per
  contract (409/422/401 never fall back), report from the response body; extend the Claude
  copy's `allowed-tools` for curl to localhost:8766 while keeping the git allowance; keep
  copies byte-consistent apart from the sanctioned difference; rebuild the distributable
  (`--check` passing); WORKSPACE_VERSION 3→4 + `## v4` CHANGELOG — all one commit per the
  release rule. Validation: build check, copy-consistency diff, live-API smoke (`healthz`,
  `commit:false` scratch write, delete file + `POST /api/reindex` cleanup). Steps 1–4 and 8
  unchanged.
- **P6.S2** (implementation, low, order 20): the single operator-authorized outside-repo
  write — copy the updated Claude-copy SKILL.md to `~/.claude/skills/explain/SKILL.md`,
  verify byte-identical; never commit outside this repo. Separate slice so the in-repo
  release commit stays pure and the operator gets a distinct gate before their daily-driver
  skill is overwritten; ordered last before REVIEW per intent's "as the phase's last step".

`P6.REVIEW` (order 9999) already exists — it validates all slices together and consolidates
Doc-impact notes into doc versions on pass.

## Constraints to record in phase.md

- Release rule: skill edits + rebuilt artifact + version bump + CHANGELOG land in ONE commit.
- D1 (public portability) stays deferred: `~/projects/personal/knowledge` and
  `localhost:8766` stay hardcoded — parameterize nothing.
- HTTP errors are never fallback triggers; fallback is transport failure only.
- Byte-consistency rule between the two copies (sanctioned frontmatter difference only).
- Intent offers operator validation of a real `/explain` run — S1/S2 planning may set the
  slice `pending` for that if chosen at their turn.

## Executor deliverables

1. Run the two `new-slice` commands (bare folders — do NOT create or pre-fill their `plan.md`).
2. Seed `phase.md`: breakdown + rationale under **Decomposition**; findings above under
   **Findings & Notes**; constraints above under **Constraints**.
3. Write this slice's `result.md`; return the structured verdict. No commits; no
   slice/phase status transitions.
