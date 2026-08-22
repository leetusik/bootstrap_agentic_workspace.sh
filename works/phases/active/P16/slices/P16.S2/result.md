# Result — P16.S2 (Seed the operator runtime manifest and the cumulative product smoke list)

Status: **done**. Two seeded doc bodies edited, artifact rebuilt, fresh-install landing proven.
Prose only — no engine, skill, contract, or test file touched.

## What shipped

### 1. `installer/payloads/doc_bodies/operations.md` — new `## Operator Runtime`

Inserted verbatim between `## Local Development` and `## Environment Variables` (decision 5).
This is the text S3/S4/S5 must quote:

```markdown
## Operator Runtime

How the **operator** runs and views this product. Any slice claiming "verified in a real
browser" verifies here — this runtime, this access path, these devices — and additionally in
the production build when the two differ.

- Run command(s):
- Mode: <dev or production build; say where they differ — dev may enable StrictMode / Fast Refresh, production does not>
- Origin / host the operator browses: <localhost, LAN IP, Tailscale host, deployed URL>
- Devices / viewports / browsers: <e.g. desktop 1440px Chrome, phone 390px Safari>
- Production build command + origin (when different):
- Also needed to see what the operator sees: <auth/test account, seeded data, feature flags>
- Status: UNFILLED — fill before any slice claims real-browser verification

An absent section and an unfilled one mean the same thing: the slice stops `pending` and asks
the operator, it never assumes. Remove the `Status:` line once the fields above are real.
```

**The unfilled marker, decided here and fixed for the phase** (S3/S5 quote it; the greppable
token is `UNFILLED`):

    - Status: UNFILLED — fill before any slice claims real-browser verification

Note the em dash (` — `), not a hyphen. A grep for the section's state is
`grep -n "UNFILLED" docs/current/operations.md`; matching means the manifest is not yet real,
which the rules treat identically to the section being absent.

Six field bullets, in this order and with this exact leading text (the manifest's field list):
`- Run command(s):` · `- Mode:` · `- Origin / host the operator browses:` ·
`- Devices / viewports / browsers:` · `- Production build command + origin (when different):` ·
`- Also needed to see what the operator sees:`.

### 2. `installer/payloads/doc_bodies/qa.md` — `## Regression Checklist` rewritten

Heading text unchanged (every adopter already has it, decision 6); the one-line `- [ ] <check>`
stub is replaced by the cumulative-smoke-list contract:

```markdown
## Regression Checklist

The product's **cumulative smoke list**: headline behaviours only, one line each, append-only
across phases. Each phase's fidelity/review slice **appends** its surfaces' headline checks and
**re-runs the whole list** in the operator runtime (`## Operator Runtime` in the operations doc),
so later phases re-verify what earlier phases shipped. Headline behaviours, not exhaustive
assertions — if a check needs a paragraph it belongs in a *Manual QA Mission*, not here.

Line shape: `- [ ] <surface>: <one observable behaviour> (P<N>)` — the tag says which phase added it.

- [ ] <landing>: login / entry point is visible and works (P<N>)
- [ ] <main board>: every visible control does something observable (P<N>)
- [ ] <timers / live data>: ticks or refreshes without wiping in-progress typing (P<N>)
```

Line shape for S3/S5 to cite: `- [ ] <surface>: <one observable behaviour> (P<N>)`.
The three seeded example lines are deliberately generic (they double as the grain guide) and
each is drawn from an incident class in `intent.md` §1: invisible login, dead controls, and
liveness/refresh destroying in-progress input.

The rest of `qa.md` is untouched — no bullet was added under *Manual QA Missions* (the plan
preferred not, and the terseness sentence already routes paragraph-sized checks there).

### 3. Rebuild

`python3 installer/build.py` regenerated `bootstrap_agentic_workspace.sh` (337793 bytes). Doc
bodies are globbed by `collect_seed_payloads()` and embedded as `DOC_BODIES`, so no build-script
or payload-list edit was needed.

## Validation

| Command | Outcome |
|---|---|
| `python3 installer/build.py` | wrote `bootstrap_agentic_workspace.sh` (337793 bytes) |
| `python3 installer/build.py --check` | **OK** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py validate` | **Workflow validation passed** |
| Fresh-install proof (temp dir under the session scratchpad, deleted afterwards) | **12/12 checks passed** |
| `bash tests/retrofit_smoke.sh` | **ALL RETROFIT SMOKE TESTS PASSED** (Tests 0–8) |

The fresh-install proof ran `sh bootstrap_agentic_workspace.sh <tmp> --name "SmokeProduct"
--summary "..."` (the no-flag path used by smoke Test 5; the install log must be written
*outside* the target, or the empty-dir guard refuses) and asserted, by grep/string check:

1. `docs/current/operations.md` contains `## Operator Runtime`;
2. it contains the unfilled marker line verbatim;
3. all six field bullets are present;
4. the section sits between `## Local Development` and `## Environment Variables`;
5. `docs/current/qa.md` still has the `## Regression Checklist` heading;
6. it contains `cumulative smoke list` + `re-runs the whole list`;
7. it cites ``` `## Operator Runtime` in the operations doc ```;
8. the old `- [ ] <check>` stub is gone;
9. three seeded example lines are present;
10. the `docs/versions/{operations,qa}/v0001_bootstrap.md` originals carry the same text
    (so the seed is durable versioned truth, not only a generated snapshot);
11. no `__PROJECT_NAME__` / `__PROJECT_SUMMARY__` sentinel leaked (neither body uses them);
12. the fresh workspace passes its own `python3 scripts/workflow.py validate`.

The temp dir was removed after the assertions. No test file was added.

## Deviations from plan.md

None of substance.

- The plan allowed one optional bullet under *Manual QA Missions*; it was not added (the plan
  itself said "prefer not").
- Section lengths: `## Operator Runtime` is 14 non-blank lines and `## Regression Checklist` is
  10 — both inside the plan's "roughly" bounds.
- `bash tests/retrofit_smoke.sh` was listed as optional; it was run, and passed.

## Notes for later slices

- **S3/S5 quoting:** the two strings to reproduce exactly are the heading `## Operator Runtime`
  and the marker `- Status: UNFILLED — fill before any slice claims real-browser verification`.
  When S6 pins invariants in Test 0, `UNFILLED` and `## Operator Runtime` are the stable tokens;
  the prose sentences around them are not.
- **Seed reach (already recorded in `phase.md` *Findings*):** `--update` preserves all of
  `docs/`, and a retrofit installs doc bodies only when the target has no `docs/`. So these two
  sections land on **fresh installs only** — S6 owes the v32 CHANGELOG a Migration note telling
  existing adopters to add `## Operator Runtime` to their operations doc by hand (via
  `doc-new-version`, never by hand-editing `docs/current/`) and to rewrite their
  `## Regression Checklist` stub. This is exactly why decision 5's "absent == unfilled ==
  `pending` stop" rule has to exist.
- This repo's own `docs/current/operations.md` / `qa.md` were **not** edited (they are not the
  seed); the `REVIEW` slice consolidates the two *Doc impact* lines appended to `phase.md`.
