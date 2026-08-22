# Plan — P16.S6 (Release: ship S1–S5 as workspace v32)

## Goal

Turn the five landed slices into a release adopters can pick up: `WORKSPACE_VERSION = 32`, a
`## v32` CHANGELOG entry with **Migration notes**, the `update-workspace` migration sentence,
README / retrofit-guide / `installer/README.md` prose where the machinery is documented, the
new safety-critical Test 0 invariants in `tests/retrofit_smoke.sh`, and the final rebuild.
Plus one folded-in deferred job: **D4** (retrofit-guide Troubleshooting row omits the
`.gitattributes` line-merge) — its trigger fires here; it is a one-row fix, so do it and say
so, without letting it grow.

## Read first

- `works/phases/active/P16/phase.md` — decisions 1–9; every *Findings & Notes* bullet from S1
  through S5, in particular: S1's "`--require` on a done phase … S6's migration note must say
  adopters opt *live* phases in"; DECOMP's "`--update` preserves all of `docs/` … required
  Migration note"; S3's "Doc-consolidation timing — DECIDED, binding for S4/S6" and "Exact
  wording S4/S5/S6 must mirror"; S4's "exact strings S6's Test 0 can pin" and the
  "byte-identical bodies" invariant; S5's "Sentences S6 can pin as Test 0 invariants".
- `works/phases/active/P16/intent.md` §1 (the incident — the CHANGELOG entry should say in one
  or two sentences *why* v32 exists) and §4.
- Each of `P16.S1`…`P16.S5`'s `result.md` for what actually shipped.
- `CHANGELOG.md` — the `## v31 — 2026-08-14` entry is the house style (bold-lead bullets,
  one **Migration notes** bullet last); `installer/main.py` line ~38 `WORKSPACE_VERSION = 31`
  (the marker/version stamp; check for any other `31` that is a version, e.g. in help text or
  `installer/README.md`); `.claude/skills/update-workspace/SKILL.md` step 8 (the "Coming from a
  pre-v31 workspace" sentence is the pattern for a "pre-v32" one); `README.md` (Korean) and
  `README.en.md` — the command tables (`review-phase` rows around README.md:197,
  README.en.md:253/273) and the review-flow passages (README.en.md ~471 "Review it: the phase
  closes only on a passing review…", README.md ~128/239); `docs/retrofit-guide.md`
  § *Updating after adoption* and § *Troubleshooting* (the D4 row: "The only intended
  modification is the additive `.claude/settings.json` merge and the marked `CLAUDE.md`
  section"); `installer/README.md` if it lists versioned behaviour; `tests/retrofit_smoke.sh`
  Test 0 (structure, and the existing per-file assertion blocks you extend).
- `works/deferred/open/D4/deferred.json`.

## Changes

1. **Version:** `installer/main.py` `WORKSPACE_VERSION = 32`. Grep the installer and READMEs
   for any other place that states the current version and update it.

2. **`CHANGELOG.md` — `## v32 — 2026-08-23`** (today), above v31, in the v31 style. Cover,
   as bold-lead bullets: why (one sentence on the failure class: agent-side gates only, the
   product owner first saw the running product after two review-passed phases); the
   **operator acceptance gate** (the `acceptance` block, `accept-gate` and its four flags,
   the declaration at the `DECOMP` boundary — explicit `--require`/`--waive --note`, never by
   omission — the engine's `review-phase --verdict pass` refusal, `changes_requested` reset,
   the walkthrough via `next`, legacy = no block = passes directly); the **operator runtime
   manifest** (`## Operator Runtime`, the `UNFILLED` marker, absent == unfilled → the slice
   returns `needs_operator` → `pending`; prod build in addition when it differs); **works as
   a product** (design-cowork's new *Verifying* section: the four-item sweep, both runtime
   modes, whole-smoke-list re-run; the review's independent spot-check and fresh-eyes
   walkthrough not judged against the record); the **gap channel** (`## Operator Questions`,
   routed at the review into the walkthrough or `defer-job`, unrouted blocks the pass,
   "questions get asked, not archived"); the **cumulative smoke list** (`## Regression
   Checklist` reuse); **executor prompts** (gate duties, `walkthrough` return field — the one
   new field, `accept-gate`/`defer-job` prohibited, mid/high bodies now identical, D2 closed);
   doc consolidation timing (pass path, before the gate; parallel unchanged). Then **Migration
   notes**: preview with `--update --dry-run`; `--update` preserves `works/` and `docs/`, so
   (a) every existing phase has no `acceptance` block and passes as before — to gate a phase
   already in flight, run `accept-gate <P> --require` on a **live** phase only (never a
   `done` one — `validate` would then fail it); (b) `## Operator Runtime` and the rewritten
   `## Regression Checklist` reach **fresh installs only** — existing adopters add the
   section to their operations doc by `doc-new-version` (paste the seed text; point at the
   seed path in the upstream clone) and fill it, otherwise the first real-browser slice will
   stop `pending` asking for it; (c) `sync-agents` after the update as always. Keep the
   whole entry readable — v31's length is the ceiling.

3. **`.claude/skills/update-workspace/SKILL.md`** step 8: add a "**Coming from a pre-v32
   workspace:**" sentence mirroring the migration notes (legacy phases pass as before; opt
   live phases in with `accept-gate --require`; add and fill `## Operator Runtime` via a doc
   version, since `--update` never touches `docs/`; the `## Regression Checklist` smoke-list
   contract). Terse.

4. **READMEs (`README.md` Korean, `README.en.md`):** add an `accept-gate` row to each command
   table next to `review-phase`; extend the review-flow passage(s) by one sentence each: on a
   phase that changes what the operator sees, the review ends with the phase `pending` and a
   walkthrough — the operator walks the running product and clears the gate
   (`accept-gate <P> --clear`) before the pass is recorded. Mirror the Korean wording style
   of the surrounding text (write natural Korean, not a translation of the English sentence).
   Touch nothing else there.

5. **`docs/retrofit-guide.md`:** § *Updating after adoption* — one short paragraph or bullet
   on the v32 migration (same content as the notes); § *Troubleshooting* — **D4**: the "only
   intended modification" row now also lists the `.gitattributes` line-merge (confirm the
   exact behaviour against `installer/main.py` and the lifecycle smoke test before wording
   it). `installer/README.md`: only if it states versioned behaviour that v32 changes.

6. **`tests/retrofit_smoke.sh` Test 0 — terse new invariants** (the contract's small-test
   rule; pin safety-critical strings only, not bodies):
   - `CLAUDE.md`: `accept-gate`, `## Operator Runtime`, `## Operator Questions`, and the
     declaration phrase (e.g. `never by omission` or whatever S3 landed — quote from the file).
   - `review-phase/SKILL.md`: `## Gate stages`, `walkthrough`, and the never-run pair
     (`accept-gate` + `defer-job` in its prohibition sentence).
   - `do-next-slice` / `do-whole-phase`: `accept-gate` and `--clear` present.
   - Both executor tiers: the co-work refusal sentence (now in both — replace the old
     "high only" comment and assertion with a both-tiers loop), the gate-stage opener
     `` On a gated phase (`acceptance.required` is `true` — and only then) also run the gate stages ``,
     `` `walkthrough` `` in the return block, `` `accept-gate` `` and `` `defer-job` `` in the
     Never list; **and the one-line parity invariant**: the two files' bodies below the
     frontmatter are byte-equal (strip through the second `---` line and compare).
   - `design-cowork`: `## Verifying — RESPECT THE DESIGN, and does it work`,
     `### When the record never drew it`, `matching it is not acceptance`,
     `Questions get asked, not archived.`, `signing the cards is not accepting the product`.
   - Seed doc bodies (from the payload dir or a fresh install already exercised by the suite —
     reuse whatever test already installs fresh): `## Operator Runtime` + the `UNFILLED` marker
     in `operations`, the `(P<N>)` line shape in `qa`'s `## Regression Checklist`.
   - Engine (one cheap probe, in the suite's existing throwaway fresh install): `new-phase`
     stamps the `acceptance` block; `review-phase --verdict pass` on the undeclared phase
     exits non-zero; `accept-gate --waive` without `--note` exits non-zero. Three lines, no
     new test file.
   Quote every string from the files as they are now — never from memory. Keep the additions
   to roughly 25–40 lines total.

7. **Rebuild:** `python3 installer/build.py` → `--check` passes (the CHANGELOG is not
   embedded, but `main.py` and the skills are).

## Validation

- `python3 installer/build.py` then `python3 installer/build.py --check` → OK.
- `python3 scripts/workflow.py validate` → passed; `python3 scripts/workflow.py sync-agents --check` → in sync.
- `bash tests/retrofit_smoke.sh` → ALL PASSED, including your new Test 0 lines (make one of
  them fail deliberately once, e.g. by grepping a misspelling in a scratch copy of the
  assertion, to prove the new block actually runs — then restore; or simply confirm the new
  assertions execute by a temporary echo; do not leave debug output behind).
- Fresh install of the rebuilt artifact into a scratchpad temp dir
  (`/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/fee2369d-edde-464e-8664-97a6e42e35e0/scratchpad/`, log written **outside** the target dir —
  S2's gotcha): `works/.workspace-version.json` (or wherever the marker lives) says `32`;
  delete the dir afterwards.
- Grep the repo for stray `v31`/`31` version references that should now read 32 (excluding
  CHANGELOG history and `OBSOLETE_MACHINERY` comments).
- No test file added; `tests/retrofit_smoke.sh` remains the one suite.

## Record

- `result.md`: the CHANGELOG entry as shipped, the Test 0 lines added, the D4 fix, the
  version-bump locations, validation outcomes, deviations; a line confirming D4 is fixed so
  the orchestrator can `drop-deferred D4`.
- `phase.md` *Findings & Notes*: anything the `REVIEW` must know (e.g. where the version is
  stamped, the fresh-install proof); *Doc impact*: `operations` — workspace v32 release and its
  migration notes; `architecture` — executor-tier parity invariant now pinned by Test 0 (one
  line). The `REVIEW` consolidates the whole phase's list after you.

## Do not

- Edit `scripts/workflow.py`, `CLAUDE.md`, the review/loop/design skills, or the executor
  agents (S1–S5 are final; if you find a defect there, record it as a finding for the REVIEW
  rather than patching it here).
- Grow the release slice beyond D4 (D3 does not fire — `build.py` is untouched).
- Commit, or run any workflow state-transition command (`drop-deferred` included).
