# P6.S1 — Plan (Rewire /explain steps 5–7 to POST /api/documents)

## Context

Second slice of P6 (`/do-whole-phase`, DECOMP done and committed). P6.S1 (implementation,
risk **medium** → `slice-executor` at xhigh) rewires the `/explain` skill's save path: steps
5–7 (manual file write, Recent bullet, KB git commit) become one
`POST http://localhost:8766/api/documents`; the manual flow survives only as a
transport-failure fallback; HTTP errors are handled per contract and never trigger a file
fallback. Steps 1–4 and the project-copy step stay unchanged. Same commit: rebuilt
distributable + WORKSPACE_VERSION 3→4 + `## v4` CHANGELOG (release rule; v3 already
consumed — see phase.md Findings).

Files: `.claude/skills/explain/SKILL.md`, `.agents/skills/explain/SKILL.md` (byte-consistent
apart from frontmatter lines 4–5), `installer/main.py` (line 40 constant only),
`CHANGELOG.md`, regenerated `bootstrap_agentic_workspace.sh`. Nothing else — no
`--with-explain` gating, no installer logic, no parameterization (D1 stays deferred).

## Design decisions (verified against KB server source)

- **`co_authored_by` is the bare value** — `server/gitops.py:49` prepends `Co-Authored-By: `
  itself. So the field is e.g. `Claude Fable 5 <noreply@anthropic.com>` (the model that did
  the work, same convention as the old commit trailer).
- **Response `url`** defaults to `http://localhost:8765/<project>/<date>-<slug>/`
  (`server/config.py:41`) — replaces the hand-built viewer link in the old Report step.
- **No shell-quoting hazards:** document body and title never pass through shell args. The
  agent **Writes** two files to a temp dir (`/tmp/explain-<date>-<slug>/`): `body.md` (the
  document **without** YAML frontmatter, starting at the H1) and `meta.json`
  (`{"title", "project", "tags", "source_repo", "co_authored_by"}` — date/slug/overwrite/
  commit left at API defaults). One spelled command merges them, one spelled curl posts:

      python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); m["markdown"]=open(sys.argv[2]).read(); json.dump(m, open(sys.argv[3], "w"))' <tmp>/meta.json <tmp>/body.md <tmp>/payload.json

      curl -sS --max-time 5 -o <tmp>/response.json -w '%{http_code}' --json @<tmp>/payload.json http://localhost:8766/api/documents

  (curl 8.7.1 on this machine; `--json` needs ≥7.82 — fine, D1 keeps this personal.)
- **Clean failure semantics:** curl exit ≠ 0 (refused/timeout/resolve) = transport failure →
  fallback. Exit 0 = the API answered → branch on the status code; **never** fall back on an
  HTTP error.

## New step layout (both copies, identical below frontmatter)

- **5. Save via the KB document API** — keep old step 5's project/slug/date derivation
  verbatim; build `body.md` + `meta.json`, merge, POST (spelled commands above). Then:
  - **201** → write NO file, do NOT touch `docs/index.md`, run NO git. Record `url`,
    `committed`, `commit_error` for the Report step.
  - **409** duplicate → report `existing_title`/`rel_path`, ASK the user before retrying
    with `"overwrite": true` added to `meta.json` (re-merge, re-POST; overwrite suppresses a
    duplicate Recent bullet).
  - **422** → fix the payload once if the mistake is ours, else report.
  - **401** → `KB_API_TOKEN` is set; report that a bearer token is required. No fallback.
  - **curl exit ≠ 0** → step 6.
- **6. Fallback — only when the API is unreachable** — old steps 5–7 content preserved:
  frontmatter template + file write, Recent bullet after `<!-- explain:recent -->` (same
  missing-marker rules), the two exact `git -C` commands with the Co-Authored-By second
  `-m`. Note for Report: API was down; a later `POST /api/reindex` — or
  `docker compose up -d` in the KB repo — reconciles the DB.
- **7. Optional copy in the current project** — old step 8, content unchanged.
- **8. Report** — old step 9 updated: API path → the response `url` is the view link; if
  `committed:false` with `commit_error`, say the doc was saved but the commit failed and
  quote the error. Fallback path → old-style path + viewer URL + the API-down note above.

Frontmatter (Claude copy only — the sanctioned difference; `.agents` copy keeps none):

    allowed-tools: Read, Grep, Glob, Write, Bash(curl -sS --max-time 5:*), Bash(python3 -c:*), Bash(git -C ~/projects/personal/knowledge:*)

## Release bookkeeping (same commit)

- `installer/main.py`: `WORKSPACE_VERSION = 3` → `4` (constant only).
- `CHANGELOG.md`: `## v4 — 2026-07-02` — /explain saves through the KB document API; manual
  flow is now fallback-only; HTTP errors never file-fallback. **Migration notes:** primary
  path needs the KB API compose service (`docker compose up -d` in
  `~/projects/personal/knowledge`); skill still works via fallback when down; applies to
  `--with-explain` installs, delivered by `/update-workspace` force-refresh.
- `python3 installer/build.py` → regenerate; `python3 installer/build.py --check` must pass.

## Executor validation (lean, live-API smoke; leaves zero junk)

1. `diff` the two copies → exactly the frontmatter lines 4–5 differ.
2. `python3 installer/build.py --check` → pass.
3. Pre-check `git -C ~/projects/personal/knowledge status --porcelain` → clean (it is
   today; if not, skip smoke and report). `GET /healthz` → ok.
4. Exercise the skill's own spelled commands with `"commit": false` in `meta.json`:
   project `p6-smoke`, tags `["smoke-test","workflow-check"]`, title "P6 S1 smoke check",
   tiny body → expect **201**, `committed:false`, no `commit_error`, sane `url`.
5. Re-POST identical → expect **409** with `existing_title`.
6. Cleanup: `rm` the created doc (+ empty `p6-smoke/` dir),
   `git -C ~/projects/personal/knowledge restore docs/index.md` (removes the Recent bullet;
   safe — tree was clean), `POST /api/reindex` → row removed; KB tree clean again.

## Doc impact (executor appends one-liners to phase.md; REVIEW consolidates)

- `operations.md` — /explain save path is now API-first with manual fallback.
- `decisions.md` — decision: /explain adopts the API-owned write path (`POST
  /api/documents`); manual flow demoted to unreachable-only fallback.

## Orchestrator after `done` verdict

`finish-slice P6.S1` → `validate` → single commit
`feat(explain): save through the KB document API with manual fallback (v4)` → plan P6.S2.
