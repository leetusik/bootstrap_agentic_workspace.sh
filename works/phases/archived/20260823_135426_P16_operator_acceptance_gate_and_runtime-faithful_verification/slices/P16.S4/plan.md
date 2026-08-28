# Plan — P16.S4 (Executor prompts: slice-executor-mid.md + slice-executor-high.md)

## Goal

Make the two executor agent definitions (`.claude/agents/slice-executor-{mid,high}.md`) carry
the duties S3 wrote into the contract and the `review-phase` skill — so an executor reading
only its own prompt + `plan.md` behaves correctly on a gated phase — and close the drift
between the two tiers, including deferred job **D2** (mid has no co-work refusal clause).
Prose in two files only; `sync-agents --check` must stay green.

## Read first

- `works/phases/active/P16/phase.md` — decisions 7, 8, 9; and the S3 findings bullets
  "Doc-consolidation timing … DECIDED, binding for S4/S6", "Exact wording S4/S5/S6 must mirror",
  and the DECOMP finding "`slice-executor-mid.md` lags `-high.md` by more than D2".
- `.claude/skills/review-phase/SKILL.md` as S3 left it — especially the gate paragraph, the
  `## Gate stages` section (six stages), `## After a passing review`, and the "Two commands you
  never run" paragraph. **The executor prompt must mirror that checklist, not restate it in
  different words** — summarize tightly and point at the skill for the full stages.
- `CLAUDE.md` *Hard Rules* (the three new bullets) and *Orchestrator and executor*.
- `works/phases/active/P16/slices/P16.S3/result.md` for the per-file wording S3 shipped.
- Both agent files, whole, side by side. `scripts/workflow.py` `_patched_agent_md()` /
  `sync_agents()` — it rewrites only the `model:`/`effort:` frontmatter lines, so body edits
  are safe; do not touch the frontmatter.
- `tests/retrofit_smoke.sh` Test 0's per-tier assertions (strings that must survive:
  `` commit or push (no `git commit`, `git add`, `git push`) ``, `run workflow
  state-transition commands`, and for high `` never dispatched, because you have no `DesignSync` ``
  and `` return `needs_operator` ``). S6 will add new assertions later — you add none.
- `works/deferred/open/D2/deferred.json`.

## Changes (apply to BOTH files unless stated; keep the two bodies parallel in structure)

1. **Inputs:** add that the phase's `phase.json` may carry the `acceptance` block and that
   `acceptance.required` (true / false / null / block absent = legacy) is what turns the gate
   duties on; add `docs/current/operations.md` `## Operator Runtime` as an input for any slice
   claiming real-browser verification, and `## Operator Questions` in `phase.md` as the list to
   read and append to.

2. **Do — implementation / `fix` slices (F1):** a slice that claims "verified in a real
   browser" verifies in the manifest's runtime and access path, and additionally in the
   production build when they differ; if `## Operator Runtime` is absent **or still carries the
   `UNFILLED` marker**, return `needs_operator` asking for it (the orchestrator sets the slice
   `pending`) — never assume the most convenient runtime. Operator questions the slice raises
   go onto `phase.md`'s `## Operator Questions` list (beside the "Doc impact" habit), not only
   into `result.md`.

3. **Do — review slice:** on `acceptance.required: true` (only then), perform the gate stages
   per the `review-phase` skill — find the manifest (absent/`UNFILLED` → `needs_operator`),
   independent spot-check of the running product (never pass on other slices' reports alone),
   fresh-eyes UX walkthrough **explicitly not judged against the design record** (findings to
   the walkthrough, never silent fixes), re-run the **whole** `## Regression Checklist` and
   append this phase's lines (`- [ ] <surface>: <one observable behaviour> (P<N>)`) through the
   pass-path doc consolidation, route every `## Operator Questions` entry (into the walkthrough
   or as a listed deferred job for the orchestrator to file; unrouted = finding, no pass), and
   return the `walkthrough`. Doc consolidation stays in the pass path **before** the gate opens
   (S3's binding decision). Waived (`false`) and legacy (no block) phases: review exactly as
   today. `null` → report as a finding; the engine refuses the pass anyway.

4. **Never list:** add `accept-gate` (phase-state command — the review returns the
   walkthrough, the orchestrator opens the gate) and `defer-job` (the review lists jobs —
   title, reason, trigger — the orchestrator files them) to the named prohibited commands.

5. **Return block:** add `walkthrough`: (review slice only, required when
   `acceptance.required` is `true`) — "the concrete script the operator runs — URLs to open,
   actions to try, in the manifest runtime and access path — plus the routed questions as
   decisions to take"; otherwise `none`. Also `deferred_jobs_to_file`: (review slice only)
   the jobs for the orchestrator to file, or `none` — **only if** you judge a dedicated field
   clearer than folding the list into `walkthrough`/`summary`; decision 8 says "one new return
   field only (`walkthrough`)", so the default is to fold the list into `walkthrough` and
   `result.md` and add **no** second field. State your choice in `result.md` and `phase.md`.

6. **Close the mid ↔ high drift (D2 + the rest), in `slice-executor-mid.md`:**
   - **D2:** add the co-work refusal to mid's *Never* list — a `co-work` (design) slice is
     never dispatched and mid has no `DesignSync`; if handed one, do no design work and return
     `needs_operator` (mirror high's wording so Test 0's future assertion can be one string for
     both tiers).
   - The two-pass / `DECOMP2` decomposition language in the decomposition bullet.
   - The review's "complete the validation and the judgment before you branch on the verdict"
     rule, the `changes_requested`/`blocked` full stop before pass-only work, and the
     `explain: not written — run /explain for this phase` pointer (Do step 1 and the return
     block field `explain`).
   - High's broader no-commit wording ("with no exception anywhere: not in this workspace's
     repo and not in any other git root, on any slice kind (read-only inspection … is fine)").
   Keep mid's *tier* semantics unchanged (it escalates real code writing; it can still be
   handed decomposition/review text for completeness — both files have always described every
   kind). Do not lengthen mid beyond what parity needs.

7. **Rebuild:** `python3 installer/build.py` → `--check` passes.

## Validation

- `python3 scripts/workflow.py sync-agents --check` → in sync (frontmatter untouched).
- `python3 installer/build.py --check` → OK; `python3 scripts/workflow.py validate` → passed.
- `bash tests/retrofit_smoke.sh` → passes.
- Parity diff: `diff <(sed 1,/^---$/d … )`-style or a side-by-side read of the two bodies —
  the only intended differences are the tier self-description, mid's *Escalate early* section
  wording, and high's "never escalates". List remaining intentional differences in `result.md`.
- Consistency grep in both files: `accept-gate`, `defer-job`, `walkthrough`, `## Operator
  Runtime`, `UNFILLED`, `## Operator Questions`, `## Regression Checklist`, `needs_operator`,
  `DesignSync` — spellings exactly as S1–S3 shipped; no invented flag or field.

## Record

- `result.md`: per-file change list, the `walkthrough`/`deferred_jobs_to_file` choice, the
  remaining intentional tier differences, validation outcomes, deviations, and a line
  confirming D2 is fixed so the orchestrator can `drop-deferred D2`.
- `phase.md` *Findings & Notes*: one bullet with the exact return-field wording S6's Test 0
  assertions can pin (and the D2 confirmation). *Doc impact*: `architecture` — executor
  prompts now carry the gate/manifest/routing duties and mid reached parity with high (one
  line).

## Do not

- Edit frontmatter, `executors.toml`, `scripts/workflow.py`, `CLAUDE.md`, any skill,
  `installer/payloads/`, `CHANGELOG.md`, `README*`, or `tests/`.
- Commit, or run any workflow state-transition command (`drop-deferred` included — the
  orchestrator runs it after this slice lands).
