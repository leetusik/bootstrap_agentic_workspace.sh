# Phase P16: Operator acceptance gate and runtime-faithful verification

_Intent: see [intent.md](intent.md)._

## Objective

Put the product owner back in the loop: record how the operator runs and views the product as durable truth and require real-browser verification in that runtime (and prod when it differs); make every operator-visible phase stop pending with a concrete walkthrough before its review can pass, with operator-reported failures becoming fix slices; add a 'works as a product' dimension (every control does something, interaction states, liveness over time, dev+prod) and a fresh-eyes UX walkthrough beside record fidelity; route operator-question catalogues into the gate or deferred jobs so no review passes with unrouted questions; seed a terse cumulative product smoke list re-run by each phase; require the review executor to spot-check the running product itself; ship as the next workspace version with the installer rebuilt and adopters able to pick it up via update.

## Context

This is a **machinery-hardening phase for the upstream bootstrap repo**, not product visual
design: it edits the *text* of `design-cowork` and the machinery around it, and designs no
product's look. Decomposed in a **single pass** — no `co-work` slice, no `P16.DECOMP2`.

The six fixes F1–F6 come from `intent.md` §3–4 (root causes RC1–RC7 of the Mijual incident).
Read `intent.md` end to end before planning any slice — it is the phase's spec.

## Decomposition

Six middle slices, ordered so each commit is self-consistent: the engine first (so the prose can
name real commands), then the seeded doc bodies (so the prose can cite a real heading), then the
three prose surfaces that must agree with both, then the release.

| Slice | Order | Depends on | Covers |
|---|---|---|---|
| `P16.S1` | 10 | — | **F2 engine.** `scripts/workflow.py`: the `acceptance` block on `phase.json`, its stamping in `new_phase`, the `accept-gate` command, the `review-phase --verdict pass` refusal, `validate` shape checks, the `next` gate output, the `## Operator Questions` heading in the `phase.md` scaffold. |
| `P16.S2` | 20 | — | **F1 + F5 data side.** `installer/payloads/doc_bodies/operations.md` gains `## Operator Runtime`; `qa.md`'s `## Regression Checklist` is rewritten as the cumulative product smoke list. Seed-only files — verify how they reach fresh installs, retrofits, and `--update` (see *Findings*). |
| `P16.S3` | 30 | S1, S2 | **F1/F2/F4/F6 rules.** `CLAUDE.md` Hard Rules; `.claude/skills/review-phase/SKILL.md` (the biggest single change: gate opening, fresh-eyes stage, catalogue routing, review independence, smoke re-run); `do-next-slice` + `do-whole-phase` loop rules; one sentence in `parallel-phase`. |
| `P16.S4` | 40 | S3 | **Executor prompts.** `.claude/agents/slice-executor-{mid,high}.md`: the manifest-runtime line, the review-independence + fresh-eyes + catalogue-routing duties, the `walkthrough` return field, `accept-gate` on the Never list, the `## Operator Questions` running list beside "Doc impact", and **D2**'s co-work refusal clause for `mid`. `sync-agents --check` must stay green. |
| `P16.S5` | 50 | S2, S3 | **F3 + F4 + F1 inside fidelity.** `.claude/skills/design-cowork/SKILL.md`: a new *Verifying* section (the works-as-a-product sweep, both runtime modes, the manifest requirement) and the gap channel through RESPECT THE DESIGN. Note: **there is no fidelity specification there today** — this writes one. |
| `P16.S6` | 60 | S1–S5 | **Release.** `installer/main.py` `WORKSPACE_VERSION = 32`, a `## v32` CHANGELOG entry with **Migration notes**, `update-workspace` / README / `docs/retrofit-guide.md` prose, the new Test 0 invariants in `tests/retrofit_smoke.sh`, final rebuild. |

**Risk rationale — every slice is `high`.** Each touches more than one file and each must rebuild
the distributable, so none qualifies for `mid` ("a one-line/few-line code edit or docs"). `S2` is
the closest call: it is prose in two seed files, but that prose *defines* the manifest contract and
the smoke-list contract that S3–S5 cite by heading, so a mid escalation is likelier than a saving.
`S3` is the phase's largest slice and stays whole on purpose — splitting the contract from the
review procedure invites the two to disagree, which is precisely the failure class this phase
exists to close.

**Not split into more slices** because the four prose surfaces (contract, skills, agents,
design-cowork) each have one owner slice; the shared vocabulary is fixed below so they cannot
drift.

## Shared design decisions (settled here — slices must not diverge)

These are binding. `S1` implements them; `S3`, `S4`, `S5` describe them; `S6` documents them.

### 1. The acceptance gate lives on `phase.json` as `acceptance`

```json
"acceptance": {
  "required": null,        // null = undeclared | true = operator-visible | false = waived
  "walkthrough": null,     // the concrete walkthrough text, recorded when the gate opens
  "requested_at": null,
  "cleared_at": null,
  "note": null             // the operator's clearing note, or the waive reason
}
```

Read it through one helper — `phase_acceptance(data)` — exactly as `phase_execution(data)` is read,
so every caller agrees on what "gated" means. Five fields, no more: the dashboards stay lean.

### 2. Command surface: one command, `accept-gate`, orchestrator-only

| Invocation | Who / when | Effect |
|---|---|---|
| `accept-gate <P> --require` | orchestrator, at the `DECOMP` boundary | `required: true`. No status change — the phase is still being built. |
| `accept-gate <P> --waive --note "why"` | orchestrator, at the `DECOMP` boundary | `required: false` + the reason. A not-operator-visible phase **declares so explicitly**, never by omission. `--note` is mandatory here. |
| `accept-gate <P> --open --walkthrough "..."` | orchestrator, at the review, after the executor's validation **and** judgment | records the walkthrough, stamps `requested_at`, sets the phase `pending`, prints the operator instructions. Requires `required: true`. |
| `accept-gate <P> --clear [--note "..."]` | operator (or the orchestrator on their explicit say-so) | stamps `cleared_at`, returns the phase to `in_progress`. |
| `accept-gate <P>` | anyone | prints the current gate state; writes nothing. |

`accept-gate` is a phase-state command: **executors never run it** (it joins the Never list in both
agent files). The review executor returns the walkthrough text; the orchestrator opens the gate.
No `new-phase` flag and no `create-phase` hook — **the single mandatory declaration point is the
`DECOMP` boundary**, and the refusal below is the backstop that makes forgetting impossible.

### 3. What `review-phase` refuses, and what it never refuses

`review-phase --verdict pass` refuses when the phase carries an `acceptance` block and either

- `required` is `null` (undeclared) → error naming `accept-gate <P> --require|--waive`, or
- `required` is `true` and `cleared_at` is `null` → error naming `accept-gate <P> --open` /
  `--clear`.

`changes_requested` and `blocked` are **never** refused — the operator's failure report has to be
recordable. `review-phase --verdict changes_requested` **resets `walkthrough`, `requested_at` and
`cleared_at` to `null`**: the phase changed again, so the gate re-opens for the re-review.

### 4. Legacy phases (the `--update` answer)

`--update` never touches `works/`, so every phase an adopter already has keeps **no `acceptance`
key at all**. Absence = legacy = `pass` is allowed (print one advisory line, nothing more).
`validate` **does not warn** about a missing block — nagging five legacy phases on every run
violates the lean-dashboard principle; it only checks the block's *shape* when present, and errors
on `status: done` + `required: true` + `cleared_at: null` (the same shape as the existing "done but
review is not pass" error). `new_phase` stamps the block on every phase created from v32 on, so
"undeclared" and "legacy" are distinguishable and only new phases get the refusal.

**P16 itself is legacy-shaped** (created by v31) and machinery-only: its own `P16.REVIEW` passes
under the legacy path, and it should say so in one line rather than trying to self-apply the gate.

### 5. The operator runtime manifest: `## Operator Runtime` in the `operations` doc

Heading — quoted verbatim by S3/S4/S5 — is **`## Operator Runtime`**, seeded in
`installer/payloads/doc_bodies/operations.md` immediately after `## Local Development` and before
`## Environment Variables`. Fields: exact run command(s); mode (dev vs production build, and
whether they differ); the origin/host the operator actually browses; devices/viewports/browsers;
the production build command + origin when different; anything else needed to see what the operator
sees (auth, seeded data, feature flags).

The seed ships an explicit **unfilled marker** line, so "no manifest" is greppable rather than
guessed: **an absent section and an unfilled one are treated identically** — the slice claiming
real-browser verification stops `pending` and asks the operator, never assumes.

### 6. The cumulative product smoke list: `## Regression Checklist` in the `qa` doc

**Reuse the existing seeded section — no new file and no new template.** Every adopter already has
that heading, its doc is versioned once per phase at the review (exactly the append-at-review
cadence F5 wants), and inventing a parallel list would fork the truth. S2 rewrites the stub to
state the contract: headline behaviours only (terse — the small-test-files rule applies), appended
by each phase's fidelity/review, and **re-run whole** by every later phase.

### 7. Catalogue routing (F4): procedure plus one named list, no new engine check

Operator-question catalogues accumulate in a **`## Operator Questions` running list in `phase.md`**,
mirroring the proven "Doc impact" pattern (S1 adds the heading to the `new_phase` scaffold; S4 tells
executors to append to it). At the review each entry must be **routed**: folded into the `--open`
walkthrough as a decision to take, **or** filed with `defer-job` so it shows on the deferred
dashboard. An unrouted entry is a review finding — the review may not pass with one. No new
`phase.json` field and no engine check beyond the gate itself.

### 8. The review's new stages, and who performs them

The review executor — not a new agent tier — performs, after validating all slices and before
rendering the verdict, for a phase whose gate is `required: true`:

1. **Independent spot-check (F6):** open the running product in the manifest runtime and verify the
   phase's headline claims (N key flows) itself; never pass on other slices' reports alone.
2. **Fresh-eyes UX walkthrough (F3):** use the product as a first-time user and report everything
   dead, confusing, or annoying — **explicitly not judged against the design record**. Findings
   route to the gate walkthrough, never to silent fixes.
3. **Re-run the whole cumulative smoke list** (decision 6) and append this phase's headline checks.
4. Return `review_verdict: pass` **plus one new structured-return field, `walkthrough`** — the
   concrete script (URLs, actions, in the manifest runtime) plus the routed operator questions.
   The orchestrator runs `accept-gate --open` with it and STOPS.

**One new return field only** (`walkthrough`, review slices only). Routing evidence lives inside it
and in `result.md`.

### 9. The conditioning switch that keeps non-product work unaffected

Every F1/F3/F6 duty is conditioned on the phase's declaration: `required: true` → the duties bite;
`--waive` → none of them do. One switch instead of scattered "if applicable" hedges — and it is why
a machinery-only repo like this one (no running product, no manifest) is untouched by the new
rules.

## Findings & Notes

Verified against the tree at decomposition time.

- **Every slice must rebuild the artifact.** `.githooks/pre-commit` runs `installer/build.py --check`
  when anything under `installer/`, `scripts/workflow.py`, `CLAUDE.md`, `executors.toml`, `.claude/`,
  `.github/`, `.gitattributes`, `works/templates/`, or the artifact is staged. All six slices touch
  at least one of those, so each ends with `python3 installer/build.py` and leaves
  `python3 installer/build.py --check` + `python3 scripts/workflow.py validate` green.
- **No new payload file is needed.** `build.py` discovers skills by glob and doc bodies by glob
  (`collect_seed_payloads`), so `FIXED_LIVE_FILES` needs no edit and `EXPECTED_SKILL_COUNT` stays
  **17**. Deferred job **D3** ("smoke-execute the assembled artifact", triggered by touching
  `installer/build.py`) therefore does **not** fire in this phase.
- **`--update` preserves all of `docs/`** (`_update_handle` in `installer/main.py`), and a retrofit
  installs doc bodies only when the target has no `docs/` of its own. So the seeded
  `## Operator Runtime` and the rewritten `## Regression Checklist` reach **fresh installs only** —
  an existing adopter must add/fill them by hand. That is a **required Migration note** in the v32
  CHANGELOG entry (S6), and it is the concrete reason the "no manifest → `pending` stop" rule
  (decision 5) has to exist rather than assuming a manifest is present.
- **`design-cowork` has no fidelity specification today.** The only fidelity language is one line in
  *Shape* ("A **design-fidelity fix** slice is part of the normal shape, not a failure") and the
  *Implementing — RESPECT THE DESIGN* section. S5 therefore **writes a new section**, it does not
  edit an existing one. `CLAUDE.md`'s design rule already contains the string `real-browser fidelity`
  and Test 0 asserts it — keep that string alive.
- **`slice-executor-mid.md` lags `-high.md` by more than D2.** Beyond the missing co-work refusal
  clause it also lacks: the two-pass/`DECOMP2` decomposition language, the review's
  "complete validation and judgment before branching on the verdict" rule, the pass-only stop, the
  `explain:` pointer, and high's broader no-commit wording ("with no exception anywhere… any other
  git root"). S4 should close the gap deliberately rather than adding only the D2 line; Test 0's
  existing per-tier assertions are the place to pin whatever it lands.
- **`next`'s pending output is generic today** — it prints `set-phase-status <P> in_progress` as the
  clear command. S1 special-cases an open acceptance gate: print the walkthrough and
  `accept-gate <P> --clear`. Reuse the existing `pending` halt; do **not** invent a second halt
  state (`operator_wait_target` / `resolve_current` already stop selection, stream-scoped).
- **Parallel mode composes without new work.** `parallel-gate` already requires branch phase `done`
  + review `pass`, and the gate sits *before* that pass, on the branch, where the operator walks the
  branch's running product. `phase.json` is not a generated file, so the `acceptance` block merges
  with the phase folder. S3 needs at most one sentence in `parallel-phase`.
- **`.claude/settings.json` needs no change:** `Bash(python3 scripts/workflow.py:*)` already
  pre-approves `accept-gate`.
- **Doc-impact candidates for this repo's own durable docs** (the `REVIEW` consolidates them; active
  docs here are `architecture`, `operations`, `qa`, `decisions`): `decisions` — the gate, its
  declaration point and the legacy default; `operations` — how to drive `accept-gate`, the manifest,
  the v32 migration; `architecture` — the `acceptance` block and the review lifecycle; `qa` — the
  works-as-a-product dimension and the cumulative smoke list. Each slice appends its own one-line
  note to *Doc impact* below; **no slice runs `doc-new-version`**.
- **Test 0 additions land in `S6`, all at once**, written against the final text of S1–S5, so the
  assertions are authored once and cannot describe wording that later moved. Keep them terse — the
  safety-critical invariants only (the refusal, the manifest heading, the `--waive` requirement, the
  co-work refusal in both tiers), not whole skill bodies.

- **The engine surface S3-S5 must quote verbatim (landed in `P16.S1`).** Command `accept-gate <P>`;
  flags `--require`, `--waive --note "..."`, `--open --walkthrough "..."`, `--clear [--note "..."]`;
  bare invocation shows the gate and writes nothing. Helper `phase_acceptance(data)` +
  `acceptance_gate_is_open(data)`. Events: `acceptance_required|waived|opened|cleared`. `next`, on an
  open gate, prints `acceptance_gate=open (requested_at=...)`, then a `WALKTHROUGH:` line, the
  walkthrough text, and `After the operator approves, clear it: python3 scripts/workflow.py
  accept-gate <P> --clear`. `--walkthrough-file` was deliberately **not** shipped (surface stays small).
- **`## Operator Questions` is now in the `new_phase` scaffold** (between `## Findings & Notes` and
  `## Constraints`), with one guidance line about routing at the review. **S4 must quote that exact
  heading** — note that this notebook, written before S1, carries a level-3 `### Operator questions`
  under *Findings & Notes* instead; the scaffold heading is the canonical one from v32 on.
- **`review-phase --verdict pass` refuses before it writes anything**, so a refused pass leaves no
  trace; `changes_requested` / `blocked` are never refused and `changes_requested` nulls
  `walkthrough`/`requested_at`/`cleared_at` while keeping `required` + `note`. A **malformed** (not
  absent) block is treated as legacy with its own advisory line — `validate` is the single authority
  on block shape.
- **`accept-gate <P> --require` on an already-`done` phase is accepted and then fails `validate`**
  ("done but its operator acceptance gate was never cleared"). Correct behaviour, but **S6's
  migration note must say adopters opt *live* phases in, never finished ones.**
- **No second halt state and no new `parallel-*` work.** The gate rides the existing `pending` halt;
  `_phases_at_ref` reads only known keys, so `parallel-status`/`parallel-gate` are inert to the new
  key (verified in the throwaway copy).

- **The `## Operator Runtime` manifest, as seeded (landed in `P16.S2`).** Heading `## Operator
  Runtime`, sitting between `## Local Development` and `## Environment Variables` in
  `installer/payloads/doc_bodies/operations.md`. Its six field bullets, verbatim leading text and
  order: `- Run command(s):` · `- Mode:` · `- Origin / host the operator browses:` ·
  `- Devices / viewports / browsers:` · `- Production build command + origin (when different):` ·
  `- Also needed to see what the operator sees:`. **The unfilled marker line, decided once and
  quoted by S3/S5, is exactly** (em dash, not hyphen):
  `- Status: UNFILLED — fill before any slice claims real-browser verification`
  — the greppable token is `UNFILLED`, and the section's closing sentence states that an absent
  section and an unfilled one mean the same thing (the slice stops `pending` and asks; it never
  assumes). Stable tokens for S6's Test 0: `## Operator Runtime` and `UNFILLED`.
- **The smoke list's line shape (landed in `P16.S2`).** `## Regression Checklist` in
  `installer/payloads/doc_bodies/qa.md` is now the cumulative product smoke list; its contract
  paragraph says headline behaviours only, appended by each phase's fidelity/review slice and
  **re-run whole** in the operator runtime, citing `` `## Operator Runtime` in the operations doc ``
  by that exact phrase. Line shape S3/S5 should cite:
  `- [ ] <surface>: <one observable behaviour> (P<N>)`. Three generic example lines ship seeded
  (landing/login visible, every visible control does something observable, timers-refresh without
  wiping in-progress typing); the old `- [ ] <check>` stub is gone.
- **The seed reaches fresh installs only — confirmed end to end (`P16.S2`).** A fresh install of
  the rebuilt artifact into a temp dir lands both sections in `docs/current/*` *and* in
  `docs/versions/{operations,qa}/v0001_bootstrap.md`, and the fresh workspace validates. Combined
  with the `--update`/retrofit finding above, S6's v32 Migration note must tell existing adopters
  to add `## Operator Runtime` and rewrite their `## Regression Checklist` themselves, through
  `doc-new-version` (never by hand-editing `docs/current/`).

- **Doc-consolidation timing on a gated phase — DECIDED, binding for S4/S6 (`P16.S3`).** The review
  executor consolidates docs **in its `pass` path, before the gate opens** — i.e. exactly as today,
  outside parallel mode; the stage-4 smoke-list append to `## Regression Checklist` rides that same
  consolidation. Rationale: one dispatch, no new orchestrator duty, mechanics unchanged; and if the
  operator then reports failures, the `changes_requested` → fix → re-review cycle consolidates again
  and the newer versions supersede (versions are append-only durable truth — one describing code
  that exists is not false). The rejected alternative (defer like parallel mode, consolidate after
  the `--clear`) buys the cleaner semantics "docs describe accepted truth" but costs a second review
  dispatch or an orchestrator-run consolidation, i.e. new surface in three skills — not worth it for
  a window that only exists between a pass and a clear. Written into `CLAUDE.md`'s durable-docs rule
  and `review-phase`'s pass bullet; **S4 and S6 must say the same thing.** Parallel mode is
  unchanged: it still defers to the post-merge step.
- **Exact wording S4/S5/S6 must mirror (landed in `P16.S3`).**
  - Return field: **`walkthrough`**, review slices only, returned *beside* `review_verdict`;
    described everywhere as "the concrete script the operator runs — URLs to open, actions to try,
    in the manifest runtime and access path — plus the routed questions as decisions to take".
  - Missing/unfilled manifest: the review (or any slice claiming real-browser verification) returns
    **`needs_operator`** and the orchestrator sets it `pending`. Contract phrasing: "the executor
    returns `needs_operator`, the orchestrator sets the slice `pending`". Absent section == `UNFILLED`
    marker present.
  - Executor prohibitions (both agent files): **`accept-gate`** (phase-state command) and
    **`defer-job`** — the review *lists* the deferred jobs (title, reason, trigger) in `result.md`
    and its return; the orchestrator files them. The review's own workflow commands stay
    `doc-new-version` / `rebuild-docs` (pass only) plus `validate`.
  - Declaration point sentence: "right after `finish-slice <P>.DECOMP`, and in the same commit,
    `accept-gate <P> --require` or `accept-gate <P> --waive --note "why nothing operator-visible
    changes"`, decided from `intent.md` and the decomposition"; never by omission.
  - Legacy wording used everywhere: "a phase carrying **no `acceptance` block at all** is legacy
    (created before workspace v32) and passes directly with one advisory line".
  - Gate-stage order in `review-phase`: (1) find the manifest, (2) independent spot-check, (3)
    fresh-eyes UX walkthrough (explicitly **not** judged against the design record), (4) re-run the
    **whole** `## Regression Checklist` + append this phase's lines in the shape
    `- [ ] <surface>: <one observable behaviour> (P<N>)`, (5) route every `## Operator Questions`
    entry, (6) return the `walkthrough`. All six are conditioned on `acceptance.required is true`
    (decision 9): waived and legacy phases skip the whole section. **S5 states the design-side
    fidelity spec; S3 stated only the review-side duty** — S5 should not restate the review stages,
    only the fidelity sweep and the gap channel.
- **Contract kept compact (`P16.S3`).** Three new *Hard Rules* bullets (acceptance gate; operator
  runtime manifest; questions-get-asked + review independence), one new *Workflow Commands* line,
  and clauses grafted onto six existing sentences (*Orchestrator and executor*, *Canonical State*
  phase-state line, the `pending` rule, the `review-phase` rule, the durable-docs rule, the design
  rule). No new section. `real-browser fidelity` and every other Test 0 string survived unchanged —
  the design rule now ends "...fidelity to the record **and** whether it works as a product (every
  visible control does something, interaction states, liveness over time, in the operator's runtime
  as well as production)", which is the one clause S5 expands into a specification.
- **`parallel-phase` needed exactly one paragraph (`P16.S3`)**, in §4: the gate opens and clears on
  the branch, before the branch `pass`, so `parallel-gate`'s "branch phase `done` + review `pass`"
  already implies the operator accepted what is about to be merged. No engine or command change, and
  the deferred doc consolidation is untouched.

- **Executor prompts: mid and high now have byte-identical bodies (`P16.S4`).** The only surviving
  differences between `.claude/agents/slice-executor-{mid,high}.md` are in **frontmatter**
  (`name`, `description`, `tools` — high adds `WebSearch, WebFetch` — and the `sync-agents`-owned
  `model`/`effort`); `diff` of the two bodies from line 9 is empty. The three body differences the
  S4 plan expected to survive were already identical before the slice, so closing the `DECOMP`
  drift list left nothing behind. **S6 may pin this as a one-line Test 0 invariant** (bodies equal
  below the frontmatter) — S4 deliberately added no test assertions.
- **The exact strings S6's Test 0 can pin (landed in `P16.S4`), present once in each tier file.**
  Return field (a single unwrapped line in each file; line-wrapped here): `` - `walkthrough`: (review slice only, required when the phase's
  `acceptance.required` is `true`, otherwise `none`) the concrete script the operator runs — URLs to
  open, actions to try, in the manifest runtime and access path — plus the routed questions as
  decisions to take, and any deferred jobs you want filed (title, reason, trigger), since you never
  run `defer-job` yourself ``. Co-work refusal, now word-for-word in **both** tiers:
  `` execute a `co-work` (design) slice — those are run inline by the orchestrator and never
  dispatched, because you have no `DesignSync`; if you are ever handed one, do no design work and
  return `needs_operator` ``. Gate-stage opener: `` On a gated phase (`acceptance.required` is
  `true` — and only then) also run the gate stages ``. The Never bullet naming both prohibited
  commands keeps the existing Test 0 substring `run workflow state-transition commands` intact and
  adds `` `accept-gate` `` (1x) and `` `defer-job` `` to the same sentence.
- **`deferred_jobs_to_file` was NOT added — decision 8 holds (`P16.S4`).** The review's deferred-job
  list is folded into the `walkthrough` field's trailing clause plus `result.md`, so `walkthrough`
  remains the **one** new structured-return field. S5/S6 must not introduce a second field.
- **D2 is fixed (`P16.S4`).** `slice-executor-mid.md` now carries the co-work refusal clause,
  word-for-word identical to high's. The orchestrator can close it with
  `python3 scripts/workflow.py drop-deferred D2 --reason "fixed in P16.S4 — slice-executor-mid now carries the co-work refusal clause"`
  (not run in the slice: executors run no state-transition command).

- **`design-cowork` now has a fidelity specification (`P16.S5`).** New section
  **`## Verifying — RESPECT THE DESIGN, and does it work`**, placed between *Implementing — RESPECT
  THE DESIGN* and *Never*, with one sub-heading **`### When the record never drew it`** (the gap
  channel). Two yardsticks (*matches the record* / *works as a product*); the four sweep items are
  **every visible interactive element does something observable**, **interaction states**
  (focus/hover/keyboard, incl. browser defaults the record never drew), **liveness over time**, and
  **type into it and wait**. Then *Where it runs* (manifest runtime + production build when they
  differ; absent **or** `UNFILLED` → `needs_operator` → `pending`; every manifest viewport),
  *Re-run the whole list* (`## Regression Checklist`, append shape `- [ ] <surface>: <one observable
  behaviour> (P<N>)` via *Doc impact*), *What a fidelity slice may fix, and what it may not*, and
  *Evidence, terse*. The review's gate stages are **linked, not restated** — one sentence points at
  `review-phase` + the contract — and `acceptance.required: true` is named exactly once, as the
  switch an apply phase always trips. **`accept-gate` does not appear in the file at all.**
- **Sentences S6 can pin as Test 0 invariants (`P16.S5`), each present exactly once.**
  `## Verifying — RESPECT THE DESIGN, and does it work`, `### When the record never drew it`,
  `matching it is not acceptance`, `Questions get asked, not archived.`,
  `signing the cards is not accepting the product`. The 15 existing design-cowork assertions were
  re-run green — none of them moved. S5 added no test assertions itself (S6 owns Test 0).
- **Three grafted clauses, no other new sections (`P16.S5`).** *Shape*'s fidelity-fix bullet now
  reads "for a departure from the record *or* a dead, no-op or unreachable control the functional
  sweep found"; *Implementing — RESPECT THE DESIGN* now ends by requiring the implement slice's
  `plan.md` **and** dispatch prompt to name `## Operator Runtime`; *Never* gained two bullets
  (verify-only-against-the-record / only in a convenient runtime; fix a design gap silently).

- **The release surface, as shipped (`P16.S6`).** The workspace version has exactly **one** stamp —
  `installer/main.py:38 WORKSPACE_VERSION = 32`; nothing else in the tree states the current version
  (every remaining `v31` is history: the CHANGELOG, the Codex-removal negatives in
  `tests/retrofit_smoke.sh`, the `update-workspace` / `explain` / retrofit-guide migration notes,
  `installer/main.py`'s `OBSOLETE_MACHINERY` comments, and the generated `docs/current/*`). The
  smoke test's existing three-way check (`installer/main.py` == top `## v<N>` heading == fresh
  `works/.workspace-version.json`) is what enforces the bump, so a future release slice needs no new
  test. `installer/README.md` needed no edit: its release rule is version-agnostic.
- **Fresh-install proof of v32 (`P16.S6`).** Installing the rebuilt artifact into a scratchpad temp
  dir (log written **outside** the target — S2's gotcha) gives `"workspace_version": 32`,
  `## Operator Runtime` + `UNFILLED` in `docs/current/operations.md`, the cumulative smoke list in
  `docs/current/qa.md`, a passing `validate`, and a `new-phase` there stamps the five null
  `acceptance` fields and scaffolds `## Operator Questions`. End-to-end, S1+S2 reach a fresh adopter.
- **The new Test 0 invariants were proved to bite (`P16.S6`).** Test 0's python body was extracted to
  the scratchpad and run against *mutated copies* of `.claude/`, `CLAUDE.md` and `installer/` (never
  the real tree): six independent mutations — mid's body altered (parity), `Questions get asked, not
  archived.` removed, `UNFILLED` → `TBD` in the seed, `accept-gate` off both Never lists, `never by
  omission` out of `CLAUDE.md`, `## Gate stages` renamed — each failed with the expected assertion,
  and the unmutated control passed. The **tier-parity check** is one line
  (`body.split("---\n", 2)[2]` compared between mid and high), so S4's byte-identical bodies are now
  a maintained invariant rather than a happy accident. Engine probes ride Test 5's existing throwaway
  fresh install (`$F`): the probe phase `P1` left there does not disturb the later `--update`
  assertions.
- **No defect found in S1–S5 (`P16.S6`).** Reading all five surfaces against each other while
  writing the release prose turned up no contradiction to report to the `REVIEW`: the vocabulary
  (`accept-gate` flags, `## Operator Runtime` + `UNFILLED`, `## Operator Questions`,
  `## Regression Checklist` line shape, the `walkthrough` return field, the pass-path consolidation
  timing) is spelled identically everywhere the release prose had to quote it.
- **`D4` is fixed in `P16.S6`; `D3` did not fire.** The retrofit guide's "only intended modification"
  Troubleshooting row now also names the `.gitattributes` line-merge (verified against
  `_gitattributes_action` / `_apply_gitattributes` in `installer/main.py` and the smoke test's
  `.claude/settings.json,.gitattributes,CLAUDE.md` modification set). The orchestrator can close it:
  `python3 scripts/workflow.py drop-deferred D4 --reason "fixed in P16.S6 — the retrofit guide's Troubleshooting row now lists the .gitattributes line-merge"`.


- **Phase review: `pass`, under the legacy path (`P16.REVIEW`).** P16 carries no `acceptance` block
  (created under v31) and this repo ships machinery, not a browsable product — so the six gate stages
  were skipped, `walkthrough` is `none`, and no gate was declared on P16, exactly as decision 4
  prescribes. Validation re-run across the whole phase: `validate`, `installer/build.py --check`,
  `sync-agents --check`, and `bash tests/retrofit_smoke.sh` (**119 PASS, 0 FAIL**) all green.
- **The review re-verified the phase's headline claims itself, in throwaway copies only.** (a) The
  engine end to end in `scratchpad/rvcopy` — 36 assertions covering the stamp, the two refusals, the
  open/clear cycle, the `changes_requested` reset, the `--waive` note requirement, the legacy
  advisory and the done+uncleared `validate` error; (b) **the operator-reports-failures path, which
  no earlier slice had exercised**: `--open` (phase `pending`) → `review-phase --verdict
  changes_requested` is accepted, returns the phase to `in_progress`, resets the three gate fields,
  reopens the `REVIEW` slice, and leaves `--clear` and `pass` correctly refused until the gate
  re-opens — the documented failure cycle works; (c) a fresh install of the rebuilt artifact (23
  assertions: version 32, both seeded sections in `docs/current` **and** in `v0001_bootstrap`,
  `new-phase` stamping the block, an undeclared pass refused there); (d) Test 0's python body run
  against six mutated copies — every mutation fails with the expected assertion, control passes, so
  the new invariants genuinely bite.
- **Cross-file vocabulary is consistent and describes only what exists.** `accept-gate --help` matches
  the documented flag surface; `--walkthrough-file` and `deferred_jobs_to_file` appear **nowhere**;
  the consolidation-timing sentence ("the pass path, before the gate opens; parallel still defers")
  reads the same in `CLAUDE.md`, `review-phase`, both agent files and the CHANGELOG.
- **Two observations recorded rather than fixed** (neither warrants a fix slice): this notebook's own
  `### Operator questions` heading predates S1's canonical `## Operator Questions` scaffold; and this
  repo deliberately has no `## Operator Runtime` (no browsable product), which the consolidated
  `operations` doc now states explicitly so a later agent does not read the absence as an oversight.
- **Operator questions: none to route** (the list is explicitly empty for `DECOMP` and `S1`–`S6`), so
  nothing blocked the pass. **No deferred jobs to file**; `D2`/`D4` were already closed by the
  orchestrator and `D3` did not fire.

### Deferred jobs

- **D2 — folded into `P16.S4`.** Its trigger ("next time `.claude/agents/slice-executor-*.md` are
  edited") is exactly S4, and the fix is one line in a file S4 is already rewriting. Promoting it
  would create a redundant slice — and `promote-deferred` pre-fills the new slice's `plan.md`, which
  decomposition may not do. **Recommendation to the orchestrator** (whose command it is): after S4
  lands, close it with
  `python3 scripts/workflow.py drop-deferred D2 --reason "fixed in P16.S4 — slice-executor-mid now carries the co-work refusal clause"`.
  Not run here: `DECOMP` may run no state-transition command but `new-slice`.
- **D4 — trigger fires, call is the orchestrator's.** "Next time `docs/retrofit-guide.md` is edited"
  is true in S6. It is a one-paragraph Troubleshooting addition about the `.gitattributes`
  line-merge, unrelated to P16's objective. Fold it into S6 if you want it closed while the file is
  open; otherwise leave it deferred. Do not let it grow the release slice.
- **D3 — does not fire** (see above): `installer/build.py` is not edited.

### Doc impact

_One line per durable-truth change; the `REVIEW` slice consolidates these into doc versions._

- (none from `P16.DECOMP` — it created slice folders and wrote this notebook.)
- `architecture` — `phase.json` gains an optional five-field `acceptance` block
  (`required`/`walkthrough`/`requested_at`/`cleared_at`/`note`), read only through
  `phase_acceptance()`; the phase review lifecycle now has an operator gate between the review
  executor's judgment and `review-phase --verdict pass` (refused while undeclared or uncleared; reset
  on `changes_requested`), and an absent block means legacy = pass allowed. (`P16.S1`)
- `operations` — new `accept-gate <P>` command (`--require` / `--waive --note` at the `DECOMP`
  boundary, `--open --walkthrough` at the review, `--clear [--note]` by the operator, bare = show);
  it is the only new engine surface, `next` prints the open gate's walkthrough, and `validate` errors
  on a `done` phase whose required gate was never cleared. (`P16.S1`)
- `operations` — the seeded operations doc gains an `## Operator Runtime` manifest section (run
  command(s), dev-vs-prod mode, the origin/host the operator browses, devices/viewports/browsers,
  the production build command + origin when different, and what else is needed to see what the
  operator sees), shipping with the marker line
  `- Status: UNFILLED — fill before any slice claims real-browser verification`; absent and
  unfilled are treated identically. Reaches **fresh installs only**. (`P16.S2`)
- `qa` — the seeded `## Regression Checklist` is now the product's **cumulative smoke list**:
  headline behaviours only, one line each (`- [ ] <surface>: <one observable behaviour> (P<N>)`),
  append-only across phases, appended to and **re-run whole** by each phase's fidelity/review slice
  in the operator runtime. Reaches **fresh installs only**. (`P16.S2`)
- `decisions` — the operator acceptance gate is now contract law: every phase declares
  operator-visibility explicitly at the `DECOMP` boundary (`accept-gate --require` /
  `--waive --note`, never by omission), a required gate stops the phase `pending` with a concrete
  walkthrough before `review-phase --verdict pass` can be recorded, operator-reported failures come
  back as `changes_requested` + `fix` slices, phases with no `acceptance` block stay legacy and pass
  directly, and **doc consolidation stays in the review's pass path, before the gate opens** (a
  later re-review supersedes). (`P16.S3`)
- `operations` — how the gate is driven end to end: the orchestrator declares it after
  `finish-slice <P>.DECOMP`, opens it at the review with the executor's returned `walkthrough`
  (`accept-gate <P> --open --walkthrough "..."`, phase → `pending`) and STOPS, the operator clears it
  with `accept-gate <P> --clear [--note "..."]` (never `set-phase-status`), and the pass is recorded
  on the resume without re-dispatching the review; plus the manifest rule — any "verified in a real
  browser" claim verifies in `## Operator Runtime`'s runtime and access path (and in the production
  build when they differ), and an absent or `UNFILLED` section means `needs_operator` → `pending`,
  never an assumption. In parallel mode the gate opens and clears on the branch. (`P16.S3`)
- `qa` — the review's new gate stages, all conditioned on `acceptance.required: true`: the reviewer
  opens the running product itself in the manifest runtime and spot-checks the phase's headline
  claims (never passing on other slices' reports alone), walks it once with fresh eyes as a
  first-time user with findings explicitly **not** judged against the design record (they go to the
  operator gate, never to silent fixes), re-runs the **whole** cumulative `## Regression Checklist`
  and appends this phase's headline checks, and routes every `## Operator Questions` entry into the
  walkthrough or into a deferred job — an unrouted entry blocks the pass. (`P16.S3`)
- `architecture` — the executor prompts (`.claude/agents/slice-executor-{mid,high}.md`) now carry the
  gate duties themselves: the `acceptance.required` switch and the `## Operator Runtime` manifest as
  named inputs, the manifest-runtime rule for any real-browser claim (absent or `UNFILLED` →
  `needs_operator` → `pending`), the review's six gate stages summarized from the `review-phase`
  skill with consolidation staying in the pass path before the gate opens, the `## Operator
  Questions` append habit beside "Doc impact", `accept-gate` + `defer-job` added to the prohibited
  commands, and one new return field `walkthrough`; both tiers now share a byte-identical body
  (mid gained the co-work refusal — D2 — plus the two-pass decomposition, review-branching,
  `explain` pointer and broader no-commit wording). (`P16.S4`)
- `qa` — **fidelity verification now has a second, named yardstick beside "matches the record":
  "works as a product"**, specified in `design-cowork`'s new `## Verifying — RESPECT THE DESIGN, and
  does it work` section. The mandatory functional sweep — every visible interactive element does
  something observable, interaction states (focus/hover/keyboard, including browser defaults the
  record never drew), liveness over time (timers tick for a real interval; refresh does not destroy
  in-progress input), and type-into-it-and-wait for anything implying live behaviour — makes each
  failure a defect **even when the render is pixel-perfect**. Verification runs in the
  `## Operator Runtime` runtime and access path and additionally in the production build when they
  differ, at every viewport the manifest names (absent or `UNFILLED` → `needs_operator` →
  `pending`), and each fidelity slice re-runs the **whole** `## Regression Checklist` before
  appending its own headline lines. Evidence stays terse — the small-test-files rule applies to
  verification. (`P16.S5`)
- `decisions` — **the gap channel through RESPECT THE DESIGN**: what the design record never settled
  is still never invented, but "catalogue it" now means *deliver* it — each gap is a one-line
  question on the phase's `## Operator Questions` list (not only in `result.md`), routed at the
  review into the acceptance walkthrough or a deferred job, with an unrouted entry blocking the
  pass. A fidelity slice may fix departures from the record; a *design* question — something the
  record drew that is bad in the flesh, or never drew at all — may not be fixed silently or
  "improved". **Signing the cards is not accepting the product:** the operator meets the running
  product at the acceptance gate and may change their mind there, which is a `changes_requested`
  plus a new round or `fix` slice, not a fidelity failure. (`P16.S5`)

- `operations` — **workspace v32 is released**: `WORKSPACE_VERSION = 32` in `installer/main.py`, a
  `## v32 — 2026-08-23` CHANGELOG entry with Migration notes, the `update-workspace` pre-v32 step and
  the retrofit guide's *Updating after adoption* paragraph. Adopters update with
  `--update --dry-run` → `--update` → `sync-agents`; existing phases keep **no** `acceptance` block
  and pass as before (opt a **live** phase in with `accept-gate <P> --require`, never a `done` one),
  and because `--update` preserves all of `docs/`, `## Operator Runtime` and the rewritten
  `## Regression Checklist` reach **fresh installs only** — an adopter adds them with
  `doc-new-version` from `installer/payloads/doc_bodies/` and fills the manifest, or the first
  real-browser slice stops `pending` asking for it. (`P16.S6`)
- `architecture` — the executor-tier **parity invariant is now enforced**: `tests/retrofit_smoke.sh`
  Test 0 asserts that `.claude/agents/slice-executor-{mid,high}.md` are byte-equal below their
  frontmatter, alongside the v32 gate strings in `CLAUDE.md`, `review-phase`, the two loop skills,
  both agent files, `design-cowork` and the two seeded doc bodies, plus three engine probes
  (`new-phase` stamps the block; an undeclared `--verdict pass` is refused; `--waive` requires
  `--note`). (`P16.S6`)


- **Consolidated at `P16.REVIEW` (this phase is not in parallel mode), one version per doc:**
  `architecture` v0005 (the `acceptance` block, `phase_acceptance()`, the three enforcement points,
  parallel inertness, gate duties in the executor prompts, tier-parity invariant) ·
  `operations` v0027 (driving `accept-gate` end to end, the manifest rule, why this repo has none,
  the v32 release + migration) · `qa` v0003 (the two yardsticks, the functional sweep, where
  verification runs, the review's six gate stages — and this repo's own `## Regression Checklist`
  rewritten to the cumulative-smoke-list contract) · `decisions` v0035 (one Decision Log entry with
  the incident context, the nine-part decision, eight rejected alternatives, consequences).

### Operator questions

_Routed at the review into the acceptance walkthrough or a deferred job (shared decision 7)._

- (none from `P16.DECOMP`.)
- (none from `P16.S1`–`P16.S6` — machinery-only phase; every judgment call the release
  needed was already settled in *Shared design decisions* or by S1–S5's findings.)

## Constraints

- Single decomposition pass: **no `co-work` slice, no `P16.DECOMP2`** — this phase designs no
  product's look.
- Every slice leaves `python3 installer/build.py --check` and `python3 scripts/workflow.py validate`
  green, with the rebuilt `bootstrap_agentic_workspace.sh` in the same commit.
- Weigh every addition against the house principles: lean dashboards, terse tests, explicit
  invocation. F1–F3 carry most of the value; prefer one clear rule over a heavy engine feature.
- Keep the new engine surface to the one `accept-gate` command and the one `acceptance` block.
- No slice runs `doc-new-version`; durable truth goes to *Doc impact* above.

## Open Questions

- None open at decomposition. The two judgment calls the plan asked for are settled above: the gate
  is declared at the `DECOMP` boundary (decision 2) and legacy phases pass by default (decision 4).
