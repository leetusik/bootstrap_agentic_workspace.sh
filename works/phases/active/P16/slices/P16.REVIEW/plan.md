# Plan — P16.REVIEW (phase review)

## Goal

Review phase P16 as a whole — validate all six middle slices together, judge the phase against
its objective, `intent.md` (F1–F6) and the docs, decide `pass` / `changes_requested` /
`blocked`, and **on a pass only** consolidate the phase's "Doc impact" list into new doc
versions. Follow the `review-phase` skill checklist and the executor prompt's review-slice
rules.

**This phase is legacy-shaped for the gate it built** (`phase.json` has **no** `acceptance`
block — it was created under v31; `accept-gate P16` prints "legacy phase … pass is allowed")
and it is **machinery-only** (no running product, no `## Operator Runtime` in this repo's
docs). So per shared decision 4 and the `review-phase` skill: **skip the gate stages, return
`walkthrough: none`, and say in one line that P16 reviews under the legacy path.** Do not
declare a gate on P16. This phase is **not** in parallel mode (no `execution` block), so a
pass **does** consolidate docs here.

## Read first

- `works/phases/active/P16/intent.md` (F1–F6 are the acceptance criteria; §1–3 are the why)
  and `phase.md` (decisions 1–9, every finding, the *Doc impact* list — 15 lines across
  `architecture`, `operations`, `qa`, `decisions` — and the empty *Operator questions* list).
- Every slice's `slice.json`, `plan.md`, and `result.md` (`P16.DECOMP`, `S1`–`S6`).
- `CLAUDE.md`, `.claude/skills/{review-phase,do-next-slice,do-whole-phase,parallel-phase,design-cowork,update-workspace}/SKILL.md`, `.claude/agents/slice-executor-{mid,high}.md`,
  `scripts/workflow.py` (the acceptance code paths), `installer/payloads/doc_bodies/{operations,qa}.md`,
  `installer/main.py` (version), `CHANGELOG.md` (v32), `tests/retrofit_smoke.sh`,
  `README.md`, `README.en.md`, `docs/retrofit-guide.md`.
- `docs/index.json` and `docs/current/{architecture,operations,qa,decisions}.md` (latest
  versions: architecture v0004, operations v0026, qa v0002, decisions v0034).

## Validate all slices together

Re-run, from the repo root, and record each outcome:

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check`
- `python3 scripts/workflow.py sync-agents --check`
- `bash tests/retrofit_smoke.sh` (covers S3–S6's Test 0 invariants, the tier-parity check,
  the three engine probes, and the fresh-install path)
- S1's engine behaviour end-to-end in a **throwaway copy** of the workspace under the session
  scratchpad (`/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/fee2369d-edde-464e-8664-97a6e42e35e0/scratchpad/`; S1's `result.md` lists the 24
  checks and the existing `wscopy` transcripts — re-run at least: new-phase stamp + scaffold
  heading; pass refused undeclared; `--require` → pass refused uncleared; `--open` → pending +
  `next` prints walkthrough + `--clear` command; `--clear` → pass accepted; `changes_requested`
  resets; `--waive` needs `--note`; stripped-block legacy passes with advisory; `validate`
  errors on done+uncleared). Never touch the real `works/`.
- S2/S6's fresh-install proof: install the rebuilt artifact into a scratchpad temp dir (log
  **outside** the target dir), assert `workspace_version` 32, `## Operator Runtime` + the
  `UNFILLED` marker, the rewritten `## Regression Checklist`, and that `new-phase` there
  stamps the five-field block; delete the dir.
- Cross-file consistency grep (the thing most likely to be wrong in a six-slice prose phase):
  `accept-gate`, `--require`, `--waive`, `--open --walkthrough`, `--clear`, `## Operator
  Runtime`, `UNFILLED`, `## Operator Questions`, `## Regression Checklist`, `walkthrough`,
  `needs_operator`, `acceptance.required` across CLAUDE.md, the six skills, both agent files,
  the two seed bodies, CHANGELOG, READMEs, retrofit-guide — every spelling matches what the
  engine (S1) and the seeds (S2) actually ship; no file describes a flag, field, heading, or
  return field that does not exist; the doc-consolidation-timing statement (pass path, before
  the gate) reads the same everywhere.

## Judge

- Does each of F1–F6 ship, as `intent.md` §4 states it, weighed against the house principles
  (lean dashboards, terse tests, explicit invocation)? Name any gap.
- Is the lifecycle coherent end to end for a gated phase (declare → build → review stages →
  `--open` → operator `--clear` or `changes_requested` → pass recorded on resume) and inert for
  waived/legacy phases and for this machinery repo? Would an orchestrator reading only
  `do-whole-phase` + `review-phase` + the executor prompt do the right thing?
- Did each slice meet its plan; are deviations explained in `result.md`?
- Is the v32 release complete (version, CHANGELOG + Migration notes, update path, READMEs,
  retrofit guide, Test 0)?
- **Complete validation and judgment before branching on the verdict** — the orchestrator
  needs the whole picture in one cycle.

## On `pass` only — consolidate docs

For each affected doc, one new version capturing the whole phase from the *Doc impact* list
(outside parallel mode this is done here): `architecture` (the `acceptance` block + review
lifecycle; executor prompts carry the gate duties; tier parity pinned by Test 0),
`operations` (the `accept-gate` command and how the gate is driven; the manifest section and
rule; the v32 release + migration), `qa` (the review's gate stages; the works-as-a-product
yardstick and sweep; the cumulative smoke list), `decisions` (the gate as contract law incl.
declaration point, legacy default, consolidation timing; the gap channel / signing ≠
accepting). Use `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source P16.REVIEW`,
edit only the returned `edit_path` (start from the current latest body — never hand-edit
`docs/current/*` or an old version), then `python3 scripts/workflow.py rebuild-docs` and
`python3 scripts/workflow.py validate`. Write only docs + `result.md` + `phase.md` on this slice
— never source.

On `changes_requested` or `blocked`: stop before consolidation; return numbered findings and
proposed fix slices (`P16.F<n>`, one line of scope each).

## Return

`result.md` with validation commands + outcomes, the judgment per F1–F6, the doc versions
created (or none), deviations; the structured verdict with `review_verdict`,
`doc_versions`, `walkthrough: none` (legacy, machinery-only — one line saying so), and
`explain: not written — run /explain for this phase`. Do not run `review-phase`,
`accept-gate`, `defer-job`, or any state-transition command; do not commit.
