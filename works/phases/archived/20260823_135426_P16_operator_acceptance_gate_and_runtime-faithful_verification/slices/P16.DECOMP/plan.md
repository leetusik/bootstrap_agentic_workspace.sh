# Plan — P16.DECOMP (decompose phase)

## Goal

Cut `P16` into middle slices and seed `phase.md`. Create **bare slice folders only** via
`new-slice` — never pre-fill another slice's `plan.md` — and record the breakdown, findings,
and cross-slice notes in `phase.md`.

This is **not** a product-visual-design phase: it edits the *text* of the `design-cowork`
skill and the machinery around it, it does not design any product's look. Decompose in a
**single pass** — no `co-work` slice, no `P16.DECOMP2`.

## Read first

- `works/phases/active/P16/intent.md` — the confirmed intent. Its verbatim section carries the
  whole incident handover (Mijual: P3 design signed → P5/P6 built and review-passed with ~230
  record-fidelity checks → operator opens the product and files 11 user-visible failures).
  Sections 3–4 of that document map root causes RC1–RC7 to the six fixes F1–F6 this phase
  ships. Read it end to end; the findings there are the phase's spec.
- `CLAUDE.md` — the contract, especially *Orchestrator and executor*, the design rule, the
  `pending` rule, and the upstream rebuild rule.
- `.claude/skills/review-phase/SKILL.md`, `.claude/skills/design-cowork/SKILL.md` (the
  *Implementing — RESPECT THE DESIGN* section and the fidelity-slice language),
  `.claude/skills/do-next-slice/SKILL.md`, `.claude/skills/do-whole-phase/SKILL.md`,
  `.claude/agents/slice-executor-{mid,high}.md`.
- `scripts/workflow.py` — `new_phase`, `review_phase`, `validate`, `set_phase_status`,
  `operator_wait_target` / `resolve_current` (how `pending` halts selection), the
  `phase.json` shape (`works/phases/active/P16/phase.json` is a fresh example), and how
  `parallel-start` stamps an `execution` block (the precedent for stamping a new block onto
  `phase.json`).
- `installer/build.py`, `installer/main.py` (`WORKSPACE_VERSION = 31`, `PAYLOADS`,
  `OBSOLETE_MACHINERY`, the `--update` path), `installer/payloads/doc_bodies/{operations,qa}.md`
  (the seeded doc bodies — `operations.md` has `## Local Development` / `## Environment
  Variables`; `qa.md` already has `## Manual QA Missions` and `## Regression Checklist`),
  `works/templates/`, `CHANGELOG.md` (the v31 entry is the house style), `tests/retrofit_smoke.sh`
  (Test 0 pins skill/contract invariants — new invariants go there, tersely), and
  `.claude/skills/update-workspace/SKILL.md` (how adopters pick up a new version).
- `works/deferred/open/D2/deferred.json` — `slice-executor-mid` has no co-work refusal clause;
  its trigger is "next time `.claude/agents/slice-executor-*.md` are edited", which this phase
  will do. Decide whether the executor-prompt slice folds D2 in (preferred — one line) and
  record that decision in `phase.md`; do **not** run `promote-deferred` yourself (state
  transition — the orchestrator does it if you recommend it).

## The hard constraint that shapes the cut

The orchestrator commits at every slice boundary and the tracked `.githooks/pre-commit` hook
runs `python3 installer/build.py --check` whenever `installer/`, `scripts/workflow.py`,
`CLAUDE.md`, `executors.toml`, `.claude/`, `.github/`, `.gitattributes`, `works/templates/`, or
the artifact is staged. So **every slice must leave the tree in a state where
`python3 installer/build.py` succeeds, `--check` passes, and `python3 scripts/workflow.py
validate` passes**, and any slice that touches an embedded machinery file must end by
rebuilding and staging `bootstrap_agentic_workspace.sh` in the same commit. Verify the current
embedded-file list in `build.py` yourself.

## What the phase must deliver (from `intent.md`; weigh each against lean-dashboard / terse-test / explicit-invocation principles)

- **F1 — Operator runtime manifest.** A durable, versioned place where an adopting workspace
  records how the operator runs and views the product (exact commands/mode such as `next dev`
  vs prod build, host/origin, devices/viewports/browsers). The natural home is a seeded
  section in the `operations` doc body (so it is versioned truth, scaffolded by the installer
  for fresh installs and retrofits). Contract rule + executor-prompt line: a slice claiming
  "verified in a real browser" MUST verify in the manifest's runtime and access path, and
  additionally in the production build when they differ; no manifest → the fidelity slice's
  first act is a `pending` stop asking the operator, never an assumption.
- **F2 — Operator acceptance gate, machine-enforced.** For any phase that changes
  operator-visible surfaces: after the review executor finishes validation and judgment, the
  phase goes `pending` with a short concrete walkthrough (URLs, actions, in the manifest
  runtime) and the run STOPS; `review-phase --verdict pass` may only be recorded after the
  operator clears the walkthrough; operator-reported failures become `fix` slices and the
  review re-runs. **The operator chose machine enforcement:** `workflow.py` must hold the
  gate state on `phase.json` (stamped at creation or by decomposition — decide which, and how
  a phase that is *not* operator-visible declares so explicitly rather than by omission) and
  `review-phase --verdict pass` must refuse while the gate is required-but-uncleared. Design
  the commands (e.g. a request/clear pair, or `set-phase-status pending` plus a clear command
  — keep the surface small), what `validate` checks, what `next` prints, and how existing
  adopter phases without the block behave (legacy phases must not break on `--update`; decide
  and record the default). Contract rule + `review-phase` skill procedure + `do-next-slice` /
  `do-whole-phase` loop rules (the loop stops at the gate and resumes on the operator's clear,
  exactly like any `pending`) + engine.
- **F3 — "Works as a product" beside "matches the record".** The design-cowork fidelity
  specification gains a mandatory functional sweep: (a) every visible interactive element does
  something observable — a no-op control is a defect even if pixel-perfect; (b) interaction
  states — focus, hover, keyboard path — on every input and control; (c) liveness over time —
  timers tick, polling/refresh does not destroy in-progress input; (d) dev **and** prod when
  the manifest differs from prod. Plus a fresh-eyes UX walkthrough stage in the review: use
  the product as a first-time user, report everything dead/confusing/annoying, explicitly NOT
  judged against the design record; findings route to the F2 gate, never to silent fixes.
- **F4 — Gap channel through RESPECT THE DESIGN.** Keep "don't invent, catalogue it", but give
  catalogues a delivery mechanism: operator-question catalogues MUST be routed — folded into
  the F2 walkthrough as decisions-to-take, or turned into deferred jobs visible on the
  dashboard — and a review must not pass with an unrouted catalogue. Decide how much of this
  is engine-checkable (cheaply) versus review-procedure; prefer procedure plus one clear rule
  over a heavy engine feature.
- **F5 — Cumulative product smoke.** A durable, append-only, terse product smoke list that each
  phase's fidelity/review appends its headline checks to and **re-runs whole**, so a later
  phase re-verifies earlier phases' surfaces. Consider reusing the existing `qa.md`
  `## Regression Checklist` section as that list (versioned once per phase at the review,
  which matches the append-at-review cadence) before inventing a new file; if a new file is
  warranted, seed it from `works/templates/` and keep it headline-only.
- **F6 — Review independence.** One line in the review procedure and the executor prompt: the
  review executor independently opens the running product in the manifest runtime and
  spot-checks the phase's headline claims (N key flows) before rendering a verdict; it never
  passes a phase purely on other slices' reports.
- **Ship it:** `WORKSPACE_VERSION` → 32, a `## v32` CHANGELOG entry in the v31 style with
  **Migration notes** (what an adopter must do by hand — e.g. fill the runtime manifest,
  how legacy phases are treated), installer payload/doc-body updates, `update-workspace`
  prose if the update flow needs a new step, README/retrofit-guide mentions, and terse
  additions to `tests/retrofit_smoke.sh` Test 0 for the new safety-critical invariants.

## Suggested shape (a starting point — improve it if the tree disagrees)

Roughly six middle slices, ordered so each commit is self-consistent and later slices can
reference the engine commands the early ones created:

1. **Engine: acceptance gate state + commands** (`scripts/workflow.py`): the `phase.json`
   block, its stamping, the request/clear commands, the `review-phase pass` refusal, `validate`
   and `next` behavior, legacy-phase default. Pure engine; the prose that tells agents to use
   it comes later. Rebuild artifact. `risk: high`.
2. **Operator runtime manifest + cumulative smoke seeds** (F1 + F5 data side):
   `installer/payloads/doc_bodies/operations.md` (and `qa.md` or a new template), anything
   `build.py`/`main.py` need to ship them, and how a retrofit/update lands them. `risk: high`
   (cross-file).
3. **Contract + review/loop skills** (F1, F2, F4, F6 rules): `CLAUDE.md`,
   `.claude/skills/review-phase/SKILL.md`, `do-next-slice`, `do-whole-phase`, and any other
   skill that names the review or `pending`. `risk: high`.
4. **Executor prompts** (`.claude/agents/slice-executor-{mid,high}.md`): the runtime-manifest
   line, the review-independence line, the fresh-eyes walkthrough and catalogue-routing duties
   of a review executor, and D2's co-work refusal clause for `mid`. `risk: high` (two files, and
   `sync-agents --check` must stay green).
5. **design-cowork skill** (F3 + F4 + F1 inside the fidelity specification): the
   works-as-a-product sweep, the gap channel, the manifest requirement, the both-modes rule.
   `risk: high`.
6. **Release: v32** — `WORKSPACE_VERSION`, CHANGELOG, update-workspace/README/retrofit-guide
   prose, `tests/retrofit_smoke.sh` invariants, final rebuild. `risk: high`.

Merge, split, or reorder these if verification shows a better cut — this is a suggestion, not
a spec. Any slice touching more than one file or writing real code is `high`; reserve `low`
for a genuinely one-line/few-line edit or docs-only slice. Set `--depends-on` where a later
slice references an earlier one's commands or sections.

## Record in `phase.md`

- The slice breakdown (what each slice covers and why) and the risk rationale.
- **Design decisions the slices must share**, settled here so they do not diverge: the
  `phase.json` block name and field shape for the acceptance gate and the command names
  (slice 1 implements, slices 3–5 describe them — they must agree); where the runtime manifest
  lives and its heading; where the cumulative smoke list lives; how legacy phases and
  not-operator-visible phases are treated; how catalogues are routed (procedure vs engine).
- The D2 decision.
- Findings and gotchas from reading the tree (e.g. anything in `build.py`'s embedded-file
  list or `main.py`'s update path that constrains a slice).
- Leave the "Doc impact" list empty unless you changed durable truth (you should not — this
  slice creates folders and writes `phase.md`).

## Validation

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check` (you changed no embedded file, so it must still pass)

## Do not

- Pre-fill any middle slice's `plan.md`.
- Implement any part of F1–F6.
- Run any state-transition command other than `new-slice`.
