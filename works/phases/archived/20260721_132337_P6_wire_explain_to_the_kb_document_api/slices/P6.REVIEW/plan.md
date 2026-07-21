# P6.REVIEW — Plan (phase review + doc consolidation)

## Context

Final slice of P6. DECOMP, S1 (v4 shipped, commit `de71eba`), and S2 (user-level sync) are
done. The review slice — executed by `slice-executor` at xhigh — validates all of P6's
slices together, reviews the phase against `intent.md`/objective, and **only on a passing
review** consolidates the two "Doc impact" notes from `phase.md` into new durable doc
versions. The executor returns a `review_verdict`; the orchestrator records it with
`review-phase` (which closes both the phase and the REVIEW slice on pass — no separate
`finish-slice`).

## Executor step 1 — validate all slices together

- `python3 scripts/workflow.py validate` — state integrity.
- **DECOMP:** slice ladder exists as recorded (S1 order 10, S2 order 20); `phase.md` carries
  breakdown/findings/constraints.
- **S1:** `diff` the two live copies → exactly frontmatter lines 4–5; `python3
  installer/build.py --check` → in sync; `installer/main.py` has `WORKSPACE_VERSION = 4`;
  `CHANGELOG.md` has `## v4 — 2026-07-02` with Migration notes; commit `de71eba` contains
  skill copies + artifact + version + CHANGELOG together (release rule, one commit:
  `git show --stat de71eba`). **Live behavioral re-check** (zero-junk, same procedure as
  S1's smoke, using the skill's own spelled commands with `"commit": false`): KB tree clean
  → `GET /healthz` ok → POST scratch project `p6-review-smoke` → 201 with
  `committed:false`, no `commit_error` → identical re-POST → 409 with
  `detail.existing_title` → cleanup (rm doc + empty dir, `git -C
  ~/projects/personal/knowledge restore docs/index.md`, `POST /api/reindex` → row removed,
  tree clean).
- **S2:** `cmp .claude/skills/explain/SKILL.md ~/.claude/skills/explain/SKILL.md` → identical.

## Executor step 2 — review against intent (works/phases/active/P6/intent.md)

Confirm every confirmed-intent point in the shipped skill text: steps 1–4 + project-copy
step content-unchanged (only the PROJECT_COPY pointer renumbered); step 5 = single POST
with exactly title/markdown-sans-frontmatter/project/tags/source_repo/co_authored_by,
defaults untouched; 201 → no file/index/git + report from `url`/`committed`/`commit_error`;
409/422/401 handled per contract and never file-fallback; fallback only on transport
failure, preserving the old manual flow + reindex note; Claude-copy `allowed-tools`
extended, sanctioned frontmatter difference preserved; D1 untouched (KB path/ports still
hardcoded, nothing parameterized); no changes to `--with-explain` gating or installer logic
beyond the version constant.

## Executor step 3 — on pass ONLY: consolidate docs (never source)

Per `phase.md` Doc impact notes, two new versions (create → edit the new
`docs/versions/...` file → `python3 scripts/workflow.py rebuild-docs`; never hand-edit
`docs/current/`):

1. `doc-new-version --doc operations --summary "/explain saves via the KB document API (localhost:8766); manual flow is fallback-only; ships as workspace v4" --source P6.REVIEW`
   — in the *Optional skills at install* section: extend the personal-Mac coupling to
   include the document API on `localhost:8766`; describe the save path (API-first, manual
   flow only when unreachable; HTTP errors never file-fallback); add a v4 release note
   bullet mirroring the existing v2 one (constant + `## v4` entry + migration notes).
2. `doc-new-version --doc decisions --summary "Decision: /explain adopts the API-owned write path; manual flow demoted to unreachable-only fallback" --source P6.REVIEW`
   — new Decision Log entry (P6) in the house format (Context: API track finished, one
   locked call replaces the hand-rolled steps 5–7 / Decision: API-primary via spelled
   python3-merge + curl --json commands, quoting-safe payload files, transport-vs-HTTP
   failure semantics, bare co_authored_by, fallback preserved verbatim / Alternatives:
   jq (rejected: shell-quoting of title), agent-written payload JSON (rejected: manual
   escaping of a 200-line body), fallback on HTTP errors (rejected: the API is up and
   refusing for a reason) / Consequences: v4 ship, user-level sync, D1 still deferred);
   update the Status paragraph (twelve → thirteen, append the P6 item).

## Executor deliverables

`result.md` (verdict, per-check evidence, doc versions created); append the review note +
doc-version list to `phase.md`; return `review_verdict: pass | changes_requested | blocked`
with reasons. Never commits; never transitions status; `doc-new-version` allowed (review
slice).

## Orchestrator afterwards

`python3 scripts/workflow.py review-phase P6 --verdict <verdict> --reviewer slice-executor
--note "..."` → `validate` → commit
(`docs(review): pass P6 review and consolidate operations, decisions docs` on pass). On
`changes_requested`: create the proposed `P6.Fn` fix slices and loop. Phase stays in
`active/` — archiving is a separate operator ask. Then STOP: do not continue into another
phase; report the phase outcome.
