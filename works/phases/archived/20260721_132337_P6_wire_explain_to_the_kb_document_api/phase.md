# Phase P6: Wire /explain to the KB document API

_Intent: see [intent.md](intent.md)._

## Objective

Replace /explain steps 5–7 (manual file write, Recent bullet, KB git commit) with one POST to the KB document API at localhost:8766 — the API-owned write path — keeping today's manual flow only as a transport-failure fallback and handling HTTP errors per the API contract; steps 1–4 and 8 unchanged. Edit both live skill copies (byte-consistent apart from the sanctioned frontmatter difference), rebuild the distributable with installer/build.py (--check passing), bump WORKSPACE_VERSION 2→3 + CHANGELOG v3 per the release rule, and finish with the operator-authorized sync of the updated skill to ~/.claude/skills/explain/SKILL.md. D1 stays deferred — KB path and ports stay hardcoded.

## Context

## Decomposition

| Slice | Kind | Risk | Order | Scope |
|---|---|---|---|---|
| P6.S1 | implementation | medium | 10 | Rewire /explain steps 5–7 to `POST /api/documents` (API-first, manual fallback); rebuild distributable; version bump 3→4 + CHANGELOG `## v4` — one release commit |
| P6.S2 | implementation | low | 20 | Sync updated Claude-copy SKILL.md to `~/.claude/skills/explain/SKILL.md` (the single operator-authorized outside-repo write) |
| P6.REVIEW | review | — | 9999 | Validate all slices together; consolidate Doc-impact notes into doc versions on pass |

**P6.S1** (implementation, medium, order 10): rewrite steps 5–7 in both live skill copies (`.claude/skills/explain/SKILL.md`, `.agents/skills/explain/SKILL.md`) — API-primary (`POST http://localhost:8766/api/documents`, curl, few-second timeout), transport-failure-only fallback (today's manual flow verbatim), HTTP-error handling per contract (409/422/401 never fall back), report from the response body; extend the Claude copy's `allowed-tools` for curl to localhost:8766 while keeping the git allowance; keep copies byte-consistent apart from the sanctioned difference; rebuild the distributable (`--check` passing); WORKSPACE_VERSION 3→4 + `## v4` CHANGELOG — all one commit per the release rule. Validation: build check, copy-consistency diff, live-API smoke (`healthz`, `commit:false` scratch write, delete file + `POST /api/reindex` cleanup). Steps 1–4 and 8 unchanged.

**P6.S2** (implementation, low, order 20): the single operator-authorized outside-repo write — copy the updated Claude-copy SKILL.md to `~/.claude/skills/explain/SKILL.md`, verify byte-identical; never commit outside this repo. Separate slice so the in-repo release commit stays pure and the operator gets a distinct gate before their daily-driver skill is overwritten; ordered last before REVIEW per intent's "as the phase's last step".

**Rationale:** two middle slices, not one — the in-repo release (skill rewrite + rebuilt artifact + version bump + CHANGELOG, one atomic commit) is cleanly separable from the outside-repo sync, and the sync deserves its own operator gate since it overwrites the operator's daily-driver skill. `P6.REVIEW` (order 9999) already exists and closes the phase.

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

- **Version drift — intent's release numbers are stale.** Intent says "bump WORKSPACE_VERSION 2→3 + `## v3`", but commit `da5e998` (the review-slice fix, 15:26 today — before P6 intent capture at 16:45) already consumed v3: `installer/main.py` has `WORKSPACE_VERSION = 3` and CHANGELOG has `## v3`. The operator's resolved clarification was "follow the release rule" — applying it now means **3→4 + `## v4`** in the implementation commit. Approved by the operator in the DECOMP plan.
- **build.py reads the live skill copies from disk** (`.claude/skills/*/SKILL.md`, `.agents/skills/*/SKILL.md` globs) — editing the two live files + `python3 installer/build.py` is sufficient; no payload duplication. `--check` passes today.
- **The two copies differ only by frontmatter lines 4–5** (`argument-hint`, `allowed-tools`) — the sanctioned difference, confirmed by diff.
- **KB API is live and matches contract v0002** (`~/projects/personal/knowledge/docs/current/api.md`): `GET /healthz` → `{status:"ok", db:"ok", documents:1}`. Contract points the rewrite depends on: 201 body (`url`, `committed`, `commit_error`, `recent_updated`), 409 body (`existing_title`, `rel_path`), 422 validation, 401 only when `KB_API_TOKEN` set, `commit:false` → `committed:false` with no `commit_error`, overwrite suppresses the duplicate Recent bullet.
- **Doc impact (P6.S1):** `operations.md` — /explain save path is now API-first with manual fallback.
- **Doc impact (P6.S1):** `decisions.md` — decision: /explain adopts the API-owned write path (`POST /api/documents`); manual flow demoted to unreachable-only fallback.
- **P6.S1 smoke confirmed the contract live** (skill's own spelled commands, `commit:false`, project `p6-smoke`): 201 → `recent_updated:true`, `committed:false`, `commit_sha:null`, `commit_error` omitted; identical re-POST → 409 with the duplicate fields nested under `detail` (`detail.existing_title`, `detail.rel_path`). Cleanup (rm doc + empty dir, `git restore docs/index.md`, `POST /api/reindex` → `removed:1`) left the KB tree clean, `documents:1`.
- **For P6.S2:** the file to sync outside the repo is the updated Claude copy `.claude/skills/explain/SKILL.md` (v4 body; `allowed-tools` now includes `Bash(curl -sS --max-time 5:*)` and `Bash(python3 -c:*)` alongside the KB git allowance). Verify byte-identical after copy.
- **Renumber ripple:** step 1's PROJECT_COPY pointer now reads "(step 7)" (project copy moved 8→7); the only edit inside steps 1–4.
- **P6.S2 sync done:** `~/.claude/skills/explain/SKILL.md` overwritten with the repo v4 Claude copy, `cmp` byte-identical (8957 bytes); the user-level `description` drift was normalized to the repo wording. No Doc-impact lines (outside durable repo truth).
- **P6.REVIEW: verdict pass.** All slices re-validated together — state `validate`, DECOMP ladder/notes, S1 copy-diff (frontmatter lines 4–5 only), `build.py --check`, `WORKSPACE_VERSION = 4` + `## v4` CHANGELOG with migration notes, one-commit release rule on `de71eba` (main.py hunk = constant only), full live-API smoke on scratch `p6-review-smoke` (201 `committed:false` no `commit_error` → 409 `detail.existing_title` → zero-junk cleanup, `removed:1`, `documents:1`), S2 `cmp` byte-identical — and the shipped skill matched every confirmed-intent point (verified against the `de71eba~1` diff: steps 1–4/project-copy content-unchanged apart from the `(step 7)` pointer, exact payload fields, 201/409/422/401 semantics, transport-only fallback preserved verbatim, allowed-tools extension, D1 hardcoding intact). Doc impact consolidated: **operations v0011** (API coupling on `localhost:8766`, API-first save path, v4 release-note bullet) and **decisions v0016** (P6 Decision Log entry; Status twelve → thirteen); `rebuild-docs` + `validate` pass. Note: the review executor session was interrupted by a transient API error after doc consolidation and resumed from on-disk state — no check skipped. The KB repo's modified `README.md` is its own in-flight work, out of smoke scope.

## Constraints

- Release rule: skill edits + rebuilt artifact + version bump + CHANGELOG land in ONE commit.
- D1 (public portability) stays deferred: `~/projects/personal/knowledge` and `localhost:8766` stay hardcoded — parameterize nothing.
- HTTP errors are never fallback triggers; fallback is transport failure only.
- Byte-consistency rule between the two copies (sanctioned frontmatter difference only).
- Intent offers operator validation of a real `/explain` run — S1/S2 planning may set the slice `pending` for that if chosen at their turn.

## Open Questions

-
