# Result

- Phase ID: P6
- Slice ID: P6.S1
- Slice: Rewire /explain steps 5–7 to POST /api/documents (API-first, manual fallback)
- Review status: pending
- Next action: orchestrator `finish-slice P6.S1` → `validate` → single release commit → plan P6.S2

## Outcome

Done. `/explain` steps 5–7 are rewired to the KB document API in both live skill copies,
per the plan's pinned layout:

- **Step 5 — Save via the KB document API.** Keeps old step 5's project/slug/date
  derivation verbatim, then builds `body.md` (document without YAML frontmatter, starting
  at the H1) + `meta.json` (`title`, `project`, `tags`, `source_repo`, `co_authored_by`
  as the bare value — the API prepends `Co-Authored-By: ` itself; `date`/`slug`/
  `overwrite`/`commit` left at API defaults) in `/tmp/explain-<date>-<slug>/`, merges
  with the pinned `python3 -c` one-liner, and POSTs with the pinned
  `curl -sS --max-time 5 -o <tmp>/response.json -w '%{http_code}' --json @<tmp>/payload.json
  http://localhost:8766/api/documents`. Branches: **201** (write NO file, do NOT touch
  `docs/index.md`, run NO git; record `url`/`committed`/`commit_error` for the Report),
  **409** (report `existing_title`/`rel_path`, ASK before retrying with
  `"overwrite": true`), **422** (fix the payload once if ours, else report), **401**
  (bearer token required — no fallback); **curl exit ≠ 0** → step 6. HTTP errors never
  trigger a file fallback.
- **Step 6 — Fallback, only when the API is unreachable.** Old steps 5–7 content
  preserved: frontmatter template + file write, Recent bullet after
  `<!-- explain:recent -->` (same missing-marker rules), the two exact `git -C` commands
  with the Co-Authored-By second `-m`, plus the Report note that a later
  `POST /api/reindex` — or `docker compose up -d` in the KB repo — reconciles the DB.
- **Step 7 — Optional copy in the current project** (old step 8, content unchanged).
- **Step 8 — Report** (old step 9 updated): API path → the response `url` is the view
  link; if `committed:false` with `commit_error`, say the doc was saved but the commit
  failed and quote the error. Fallback path → old-style path + viewer URL + API-down note.
- Claude-copy frontmatter `allowed-tools` extended exactly per plan:
  `Read, Grep, Glob, Write, Bash(curl -sS --max-time 5:*), Bash(python3 -c:*), Bash(git -C ~/projects/personal/knowledge:*)`;
  the `.agents` copy keeps no `argument-hint`/`allowed-tools` (sanctioned difference).

Release bookkeeping in the same working set: `installer/main.py` `WORKSPACE_VERSION = 3`
→ `4` (constant only), `CHANGELOG.md` `## v4 — 2026-07-02` with migration notes,
distributable regenerated via `python3 installer/build.py`.

## Deviations from Plan

1. **Step 1 cross-reference renumbered.** Old step 1 said `PROJECT_COPY=yes (step 8)`;
   the project copy is now step 7, so the reference reads `(step 7)`. "Preserve steps 1–4
   verbatim" vs "renumber cleanly" — resolved in favor of a correct reference; no other
   change to steps 1–4.
2. **Smoke temp dir** — the validation run used the executor's session scratchpad
   directory instead of `/tmp` (environment rule); the skill's spelled commands were run
   verbatim with `<tmp>` substituted. The skill text itself pins
   `/tmp/explain-<date>-<slug>/` as planned.
3. **KB tree was dirty at slice start** (uncommitted in-flight work inside the KB repo —
   its own P3 review). Per the plan's pre-check guard the smoke was deferred until after
   the deterministic work; by then the KB work had been committed and the tree was clean,
   so the full smoke ran. No skip needed.

## Validation Run

1. **Copy-consistency diff** — `diff .claude/skills/explain/SKILL.md
   .agents/skills/explain/SKILL.md` → exactly lines 4–5 of the Claude copy
   (`argument-hint`, `allowed-tools`); nothing else. PASS
2. **Build** — `python3 installer/build.py` → `wrote bootstrap_agentic_workspace.sh
   (220843 bytes)`; `python3 installer/build.py --check` → `OK: bootstrap_agentic_workspace.sh
   is in sync with installer/ source` (exit 0). PASS
3. **Pre-checks** — `git -C ~/projects/personal/knowledge status --porcelain` → clean at
   smoke time (see Deviations 3); `GET /healthz` →
   `{"status":"ok","docs_root":"/repo/docs","db":"ok","documents":1}`. PASS
4. **Live smoke — 201** — the skill's own spelled commands with `"commit": false` added
   to `meta.json` (project `p6-smoke`, tags `["smoke-test","workflow-check"]`, title
   "P6 S1 smoke check", tiny body): merge exit 0; curl printed `201`, exit 0. Response:
   `rel_path: p6-smoke/2026-07-02-p6-s1-smoke-check.md`,
   `url: http://localhost:8765/p6-smoke/2026-07-02-p6-s1-smoke-check/`,
   `recent_updated: true`, `committed: false`, no `commit_error` (`commit_sha: null`). PASS
5. **Live smoke — 409** — identical re-POST → `409` with
   `detail.existing_title: "P6 S1 smoke check"` and
   `detail.rel_path: p6-smoke/2026-07-02-p6-s1-smoke-check.md`. PASS
6. **Cleanup** — `rm` the scratch doc + `rmdir` the empty `p6-smoke/` dir,
   `git -C ~/projects/personal/knowledge restore docs/index.md`, `POST /api/reindex` →
   `{"indexed":1,"removed":1,"skipped":[],"duration_ms":17}`; `healthz` → `documents:1`;
   `status --porcelain` → empty (clean). Zero junk left in the KB. PASS

## Files Changed

- `.claude/skills/explain/SKILL.md` — steps 5–7 → API-first 5–8 layout; allowed-tools extended
- `.agents/skills/explain/SKILL.md` — same body, sanctioned frontmatter difference kept
- `installer/main.py` — `WORKSPACE_VERSION = 4` (constant only)
- `CHANGELOG.md` — `## v4 — 2026-07-02` entry with migration notes
- `bootstrap_agentic_workspace.sh` — regenerated (220843 bytes)

## Doc Versions Created

- None (per phase rule): two "Doc impact" one-liners appended to `phase.md` — `operations.md`
  and `decisions.md` — for P6.REVIEW to consolidate.

## Roadmap Updates

- None. D1 stays deferred (KB path and ports remain hardcoded).

## Retrospective

- The 409 body nests its fields under `detail` (`detail.existing_title`,
  `detail.rel_path`) — the skill's wording ("report the response's `existing_title` and
  `rel_path`") still holds; noted in phase.md for the reviewer.
- On `commit:false` the 201 body carries `commit_sha: null` and simply omits
  `commit_error` — the Report branch ("`committed:false` **with** `commit_error`")
  matches the contract.
