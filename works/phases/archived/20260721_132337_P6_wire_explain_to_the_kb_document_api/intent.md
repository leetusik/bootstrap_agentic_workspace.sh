# Intent — P6

- Captured at: 2026-07-02T16:45:33+09:00
- Origin: operator

## Original Input (verbatim)

_Line breaks restored: the request arrived with its line-wrap newlines stripped (words jammed at wrap points); wording is untouched._

> Create a phase (via /create-phase — making it ≠ executing it; stop once intent is
> confirmed and the phase exists): "Wire /explain to the KB document API".
>
> WHY NOW. The knowledge repo at ~/projects/personal/knowledge finished its API track:
> a compose service on http://localhost:8766 whose POST /api/documents performs, in one
> locked call, exactly what /explain's steps 5–7 hand-roll today — writes the convention
> file docs/<project>/<date>-<slug>.md with frontmatter, inserts the Recent bullet in
> docs/index.md, upserts the SQLite row, and makes a scoped git commit
> "docs(<project>): add <slug>" staging only the files it touched (never -A, never
> pushes). The skill should call the API instead, keeping today's manual file flow only
> as an API-down fallback.
>
> GROUND TRUTH — read before decomposing:
> - ~/projects/personal/knowledge/docs/current/api.md   (full contract: Auth, POST /api/documents)
> - ~/projects/personal/knowledge/README.md             (§API summary)
> - this repo: .claude/skills/explain/SKILL.md and .agents/skills/explain/SKILL.md
>   (live sources; installer/build.py embeds them verbatim into the distributable)
>
> TARGET BEHAVIOR. Steps 1–4 (topic, KB-existence gate, research, style contract) and
> step 8 (the `here` project copy) stay unchanged. Steps 5–7 become:
>
> 1. Primary path — one call: POST http://localhost:8766/api/documents (curl, short
>    timeout of a few seconds) with JSON:
>    - required: title; markdown = the document body WITHOUT YAML frontmatter, starting
>      at the H1 (the API writes frontmatter itself); project (same derivation as the
>      current step 5; the API validates ^[A-Za-z0-9][A-Za-z0-9._-]*$); tags (2–5
>      lowercase-kebab); source_repo (absolute path of the current repo root).
>    - also pass co_authored_by with the agent's standard attribution — this replaces
>      the commit-trailer -m of the old step 7.
>    - leave date / slug / overwrite / commit at API defaults.
> 2. On 201: write NO file, do NOT touch docs/index.md, run NO git — the API did all of
>    it. Report from the response body: `url` is the viewer link; if committed:false
>    with commit_error, say the doc was saved but the commit failed and quote the error.
> 3. Fall back ONLY on transport failure (connection refused / timeout): keep today's
>    manual flow verbatim (file + frontmatter, Recent bullet after the
>    <!-- explain:recent --> marker, the two exact git -C commands), then tell the user
>    the API was down and a later POST /api/reindex — or docker compose up -d in the KB
>    repo — reconciles the DB.
> 4. HTTP errors are NOT fallback triggers (the API is up and refusing for a reason):
>    409 = duplicate — report existing_title/rel_path and ask before retrying with
>    overwrite:true (overwrite suppresses a duplicate Recent bullet). 422 = convention
>    violation — fix the payload once if the mistake is ours, else report. 401 =
>    KB_API_TOKEN is set — report that a bearer token is required; never fall back to a
>    file write on an HTTP error.
> 5. Frontmatter: extend the Claude copy's allowed-tools so the API path is permitted
>    (curl to localhost:8766) while keeping the git allowance for the fallback; preserve
>    the sanctioned difference between copies (the .agents copy carries no
>    argument-hint / allowed-tools).
>
> SCOPE GUARDS.
> - Edit the two live skill files, rebuild the distributable with
>   python3 installer/build.py, and installer/build.py --check must pass. No changes to
>   --with-explain gating, the update-mode force-refresh, or installer/main.py.
> - D1 (public portability of /explain) stays deferred: hardcoding
>   ~/projects/personal/knowledge and localhost:8766 remains correct — do not
>   parameterize anything.
> - Keep the two copies byte-consistent apart from that frontmatter difference.
>
> VERIFICATION. Lightweight smoke against the live API (compose stack in the KB repo):
> GET /healthz, then exercise the new path without leaving junk in the KB — a
> commit:false write to a scratch project that you then remove (delete the file, then
> POST /api/reindex) is acceptable. If you'd rather I validate a real /explain run
> end-to-end, set the slice pending and hand it to me.
>
> POST-SHIP (operator-authorized): as the phase's last step, sync the updated skill to
> ~/.claude/skills/explain/SKILL.md so the user-level /explain I invoke daily matches.
> That single outside-repo write is authorized; never commit outside this repo.

## Confirmed Intent (refined + clarified)

**One phase — P6 "Wire /explain to the KB document API" — creation only.** Decomposition and implementation happen later, when the operator executes the phase.

**Goal.** Rewire the `/explain` skill's save path to the KB document API. The knowledge repo (`~/projects/personal/knowledge`) now runs a compose service `api` on `http://localhost:8766` whose `POST /api/documents` performs, in one locked call, exactly what `/explain` steps 5–7 hand-roll today: writes `docs/<project>/<date>-<slug>.md` with frontmatter, inserts the Recent bullet in `docs/index.md`, upserts the SQLite row, and makes the scoped git commit `docs(<project>): add <slug>` (staging only the files it touched — never `-A`, never pushes). The skill calls the API as its primary path; today's manual file flow survives only as an API-down fallback.

**Unchanged:** steps 1–4 (topic resolution, KB-existence gate, research, style contract) and step 8 (the `here` project copy).

**Steps 5–7 become:**

1. **Primary — one call:** `POST http://localhost:8766/api/documents` (curl, short few-second timeout) with JSON: `title`; `markdown` = the document body **without** YAML frontmatter, starting at the H1 (the API writes frontmatter itself); `project` (same derivation as the current step 5; the API validates `^[A-Za-z0-9][A-Za-z0-9._-]*$`); `tags` (2–5 lowercase-kebab); `source_repo` (absolute path of the current repo root); `co_authored_by` = the agent's standard attribution (replaces the commit-trailer `-m` of the old step 7). Leave `date`/`slug`/`overwrite`/`commit` at API defaults.
2. **On 201:** write NO file, do NOT touch `docs/index.md`, run NO git — the API did all of it. Report from the response body: `url` is the viewer link; if `committed:false` with `commit_error`, say the doc was saved but the commit failed and quote the error.
3. **Fallback ONLY on transport failure** (connection refused / timeout): keep today's manual flow verbatim (file + frontmatter, Recent bullet after the `<!-- explain:recent -->` marker, the two exact `git -C` commands), then tell the user the API was down and that a later `POST /api/reindex` — or `docker compose up -d` in the KB repo — reconciles the DB.
4. **HTTP errors are NOT fallback triggers** (the API is up and refusing for a reason): 409 = duplicate — report `existing_title`/`rel_path` and ask before retrying with `overwrite:true` (overwrite suppresses a duplicate Recent bullet). 422 = convention violation — fix the payload once if the mistake is ours, else report. 401 = `KB_API_TOKEN` is set — report that a bearer token is required. Never fall back to a file write on an HTTP error.
5. **Frontmatter:** extend the Claude copy's `allowed-tools` so the API path is permitted (curl to localhost:8766) while keeping the git allowance for the fallback; preserve the sanctioned difference between copies (the `.agents` copy carries no `argument-hint`/`allowed-tools`).

**Scope guards:**

- Edit the two live skill files (`.claude/skills/explain/SKILL.md`, `.agents/skills/explain/SKILL.md`); rebuild the distributable with `python3 installer/build.py`; `installer/build.py --check` must pass.
- No changes to `--with-explain` gating, the update-mode force-refresh, or `installer/main.py` **logic** — but per the resolved clarification below, the release rule applies: bump `WORKSPACE_VERSION` 2→3 (the one-integer constant in `installer/main.py`) + the `## v3` `CHANGELOG.md` entry in the same commit as the rebuilt artifact.
- D1 (public portability of `/explain`) stays deferred: hardcoding `~/projects/personal/knowledge` and `localhost:8766` remains correct — parameterize nothing.
- Keep the two copies byte-consistent apart from that frontmatter difference.

**Verification:** lightweight smoke against the live API (compose stack in the KB repo): `GET /healthz`, then exercise the new path without leaving junk in the KB — a `commit:false` write to a scratch project that is then removed (delete the file, then `POST /api/reindex`) is acceptable. Alternatively, set the slice `pending` and hand the operator a real end-to-end `/explain` run to validate.

**Post-ship (operator-authorized):** as the phase's last step, sync the updated skill to `~/.claude/skills/explain/SKILL.md` so the user-level `/explain` the operator invokes daily matches. That single outside-repo write is authorized; never commit outside this repo.

## Clarifications Resolved

- Q: The updated `/explain` skill ships to `--with-explain` adopters via `/update-workspace`, and the release rule says shipped changes bump `WORKSPACE_VERSION` (a constant in `installer/main.py`) + add a `CHANGELOG.md` entry in the same commit as the rebuilt artifact — but the scope guard says "no changes to installer/main.py". Which applies? — A (operator): **Follow the release rule** — bump `WORKSPACE_VERSION` 2→3 + a `## v3` CHANGELOG entry in the implementation commit; the main.py guard reads as "no machinery-logic changes" (the one-integer constant bump is release bookkeeping, not logic).

## Notes

- Intent confirmed via the approved plan-mode plan (ExitPlanMode approval, 2026-07-02).
- Refined wording was verified against `~/projects/personal/knowledge/docs/current/api.md` (v0002) and the live skill copies before confirmation: the API contract matched the operator's description on every checked point (payload fields, 201/409/422/401 semantics, commit/`commit_error` behavior, reindex reconciliation), and the two copies differ only by the `argument-hint`/`allowed-tools` frontmatter lines.
