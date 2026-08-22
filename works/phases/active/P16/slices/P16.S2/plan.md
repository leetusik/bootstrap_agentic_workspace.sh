# Plan — P16.S2 (Seed the operator runtime manifest and the cumulative product smoke list)

## Goal

Give adopting workspaces the two durable data homes F1 and F5 need, in the seeded doc bodies
that a fresh install (and a retrofit into a repo with no `docs/`) lands as each doc's
`v0001_bootstrap.md`:

- **F1 — `## Operator Runtime`** in `installer/payloads/doc_bodies/operations.md`
  (`phase.md` decision 5).
- **F5 — the cumulative product smoke list** as the rewritten `## Regression Checklist` in
  `installer/payloads/doc_bodies/qa.md` (decision 6 — reuse, no new file, no new template).

Seed prose only — no engine, no skill, no contract text (S3–S5 will *cite* these headings
verbatim; the contract rule lives in S3).

## Read first

- `works/phases/active/P16/phase.md` — decisions 5, 6, 8 (stage 3: the review re-runs the
  whole list and appends this phase's headline checks), 9 (the `required: true` switch), and the
  *Findings* bullet "`--update` preserves all of `docs/`" (why the seed reaches fresh installs
  only — S6 carries the migration note, you just make the seed good).
- `works/phases/active/P16/intent.md` §2 (the environment split: `npm run build && npm run
  start` on localhost vs `next dev -H 0.0.0.0` over Tailscale from another device; dev-only
  StrictMode / Fast-Refresh bug classes; a ≤480px viewport rendering a different product) and
  §4 F1/F5 — the manifest fields and the "terse, headline behaviours, re-run whole" contract
  come straight from there.
- `installer/payloads/doc_bodies/operations.md` and `qa.md` as they are (both are
  sentinel-templated — `__PROJECT_NAME__` / `__PROJECT_SUMMARY__` — keep the house style:
  short headings, `- Field:` bullets, `<placeholder>` angle-bracket slots, `- [ ]` checks).
- `installer/build.py` `collect_seed_payloads()` (doc bodies are globbed; no list to edit) and
  `CLAUDE.md`'s small-test-files rule (the smoke list must stay terse).

## Changes

### 1. `operations.md` — insert `## Operator Runtime` after `## Local Development`, before `## Environment Variables`

Heading text exactly `## Operator Runtime`. Under it, in a few lines:

- One sentence of purpose: this is how the **operator** runs and views the product; any slice
  that claims "verified in a real browser" verifies here — in this runtime, from this access
  path — and additionally in the production build when the two differ.
- The fields, as bullets with empty slots (the same style as *Local Development*):
  `Run command(s):` · `Mode:` (dev vs production build; whether they differ — e.g. dev
  enables StrictMode / Fast Refresh, prod does not) · `Origin / host the operator browses:`
  (localhost vs LAN/Tailscale/remote) · `Devices / viewports / browsers:` · `Production
  build command + origin (when different):` · `Also needed to see what the operator sees:`
  (auth, seeded data, feature flags).
- **The unfilled marker**, one greppable line the seed ships with — e.g.
  `- Status: UNFILLED — fill before any slice claims real-browser verification` — and one
  sentence: an absent section and an unfilled one are treated identically: the slice stops
  `pending` and asks the operator, it never assumes. Pick the marker wording once and record
  it in `phase.md` (S3/S5 quote it).

Keep the whole section to roughly 10–14 lines. Do not touch the other sections.

### 2. `qa.md` — rewrite `## Regression Checklist` as the cumulative product smoke list

Keep the heading text `## Regression Checklist` (every adopter already has it). Replace the
one-line stub with a short contract paragraph plus the list scaffold:

- Purpose: the product's **cumulative smoke list** — headline behaviours only, one line each,
  append-only across phases. Each phase's fidelity/review slice **appends** its surfaces'
  headline checks and **re-runs the whole list** in the operator runtime (`## Operator
  Runtime` in the operations doc) so later phases re-verify what earlier phases shipped.
- Terseness rule in one sentence: headline behaviours, not exhaustive assertions — if a line
  needs a paragraph, it belongs in a *Manual QA Mission*, not here.
- Line shape guidance: `- [ ] <surface>: <one observable behaviour> (P<N>)` — the phase tag
  tells a later reader which phase added it.
- Seed 3–4 example lines in angle brackets / generic form that show the intended grain (e.g.
  `- [ ] <landing>: login/entry is reachable and works (P<N>)`, `- [ ] <main board>: every
  visible control does something observable (P<N>)`, `- [ ] <timers / live data>: ticks or
  refreshes without wiping in-progress input (P<N>)`). Generic, product-neutral — this is a
  seed for any product.

Keep the section to roughly 10–12 lines. Leave the rest of `qa.md` as is (you may add one
bullet under *Manual QA Missions*' "What a real user would try" only if it helps; prefer not).

### 3. Rebuild

`python3 installer/build.py` → `python3 installer/build.py --check` passes (the doc bodies are
embedded in the artifact as `DOC_BODIES`).

## Validation

- `python3 installer/build.py --check` → OK.
- `python3 scripts/workflow.py validate` → passed (you changed nothing under `works/`).
- Prove the seed lands: in the session scratchpad
  (`/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/fee2369d-edde-464e-8664-97a6e42e35e0/scratchpad/`), run a **fresh install** of the rebuilt
  `bootstrap_agentic_workspace.sh` into an empty temp dir (see the README Quickstart /
  `installer/README.md` for the exact non-interactive invocation; `tests/retrofit_smoke.sh`
  shows how it drives the artifact) and assert with `grep` that
  `docs/current/operations.md` contains `## Operator Runtime` and the unfilled marker, and
  `docs/current/qa.md` contains the rewritten `## Regression Checklist`. Delete the temp dir
  afterwards. Optionally run `bash tests/retrofit_smoke.sh` to confirm nothing regressed.
- No test file is added; record the commands and outcomes in `result.md`.

## Record

- `result.md`: the final section texts as shipped (S3–S5 quote from them), the marker
  wording, validation transcript summary, deviations.
- `phase.md` *Findings & Notes*: one bullet with the exact `## Operator Runtime` field list and
  the exact unfilled-marker line; one bullet with the smoke-list line shape. *Doc impact*:
  `operations` — the seeded `## Operator Runtime` manifest section (fresh installs); `qa` — the
  `## Regression Checklist` is now the cumulative product smoke list. (This repo's own
  `docs/current/operations.md`/`qa.md` are not the seed — do **not** edit them; the review
  consolidates.)

## Do not

- Create a new template or payload file, or touch `build.py` / `main.py` / `CLAUDE.md` /
  `.claude/` / `CHANGELOG.md` / `tests/`.
- Edit `docs/current/*` or anything under `docs/versions/` in this repo.
- Commit, or run any workflow state-transition command.
