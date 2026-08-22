# Result — P16.S4 (Executor prompts: `slice-executor-mid.md` + `slice-executor-high.md`)

Status: **done**. Both executor agent definitions now carry the gate/manifest/routing duties S1–S3
landed, and the mid tier reached **full body parity** with high (D2 included). Two files edited,
bodies only; frontmatter untouched, `sync-agents --check` green, artifact rebuilt.

## The headline outcome: the two bodies are now byte-identical

`diff <(sed -n '9,$p' slice-executor-mid.md) <(sed -n '9,$p' slice-executor-high.md)` is **empty**.

The plan's parity bullet expected three surviving differences ("the tier self-description, mid's
*Escalate early* wording, and high's 'never escalates'"). Reading both files side by side showed
those three were **already identical** before this slice — both files have always carried the same
two-bullet tier self-description, the same `## Escalate early instead of thrashing (mid tier only)`
section, and the same "`slice-executor-high` never returns `escalate`" sentence. The real drift was
exactly the five hunks the `DECOMP` finding named, and closing them leaves nothing behind.

**Remaining intentional differences (all in frontmatter, none in the body):**

| Field | mid | high |
|---|---|---|
| `name` | `slice-executor-mid` | `slice-executor-high` |
| `description` | "Mid tier for one-line code edits and docs; escalates as soon as a slice turns out to be real code writing." | "Top tier for decomposition, the phase review, and essentially all code writing; the escalation ceiling." |
| `tools` | `Read, Edit, Write, Glob, Grep, Bash` | + `WebSearch, WebFetch` |
| `model` / `effort` | `sonnet` / `xhigh` | `opus` / `xhigh` (owned by `executors.toml` + `sync-agents`; never hand-edited) |

That is the right shape: the body is written in the second person and *describes both tiers* ("You
are one of two capability tiers…"), so tier identity comes from the frontmatter and the dispatch,
not from divergent prose. It also gives the workspace a cheap invariant — a one-line body diff is
now a drift detector — which S6 may pin in Test 0 if it wants (**S4 added no test assertions**, per
the plan).

## Changes (applied identically to both files)

1. **Inputs** — three additions:
   - `phase.md`'s bullet now names the `## Operator Questions` list beside the "Doc impact" list,
     as something to read *and* append to.
   - New bullet for the phase's `phase.json`: the five-field `acceptance` block, with
     `acceptance.required` called out as "the single switch for every gate duty below" —
     `true` (duties bite) / `false` (waived) / `null` (a finding; the engine refuses the pass
     anyway) / **no block at all** = legacy (created before workspace v32).
   - New bullet for `## Operator Runtime` in `docs/current/operations.md` "whenever your slice will
     claim real-browser verification", plus `## Regression Checklist` in `docs/current/qa.md` for a
     review slice.
2. **Do 1 — implementation / `fix`** — the manifest rule: a slice claiming "verified in a real
   browser" verifies in the manifest's runtime and access path *and* in the production build when
   the two differ, "never in whichever runtime is most convenient for you, because dev-only bug
   classes and access-path differences live in exactly that gap"; absent **or** still carrying the
   `UNFILLED` marker → the slice returns `needs_operator` and the orchestrator sets it `pending`.
3. **Do 1 — review slice** — one added sentence-block, conditioned on `acceptance.required` being
   `true` "and only then", that mirrors the `review-phase` skill's six `## Gate stages` in the same
   order and points at the skill for the full text rather than re-deriving it: (1) find the
   manifest, (2) open the running product yourself / never pass on other slices' reports alone,
   (3) fresh-eyes walkthrough **explicitly not judged against the design record**, findings to the
   walkthrough and never to silent fixes, (4) re-run the **whole** `## Regression Checklist` and
   append `- [ ] <surface>: <one observable behaviour> (P<N>)`, (5) route every `## Operator
   Questions` entry (walkthrough, or listed for the orchestrator's `defer-job`; unrouted = finding,
   no pass), (6) return the `walkthrough`. Waived and legacy phases skip the section. The pass path
   now states S3's binding timing decision verbatim in intent: "the gate does not move that timing
   — you consolidate in the pass path, **before** the gate opens, and the stage-4 smoke-list append
   rides the same consolidation."
4. **Do 4** — operator-decision questions go on `phase.md`'s `## Operator Questions` running list,
   "the same habit as the 'Doc impact' list, and the only place the review can route them from —
   not only into `result.md`".
5. **Never** — the state-transition bullet now also names **`accept-gate`** ("a phase-state
   command: the review *returns* the walkthrough, the orchestrator opens the gate") and
   **`defer-job`** ("the review *lists* the jobs to file — title, reason, trigger — and the
   orchestrator files them"). The Test-0-asserted substring `run workflow state-transition
   commands` is untouched, as is `` commit or push (no `git commit`, `git add`, `git push`) ``.
6. **Return block** — one new field, placed directly after `review_verdict`:

   ```
   - `walkthrough`: (review slice only, required when the phase's `acceptance.required` is
     `true`, otherwise `none`) the concrete script the operator runs — URLs to open, actions
     to try, in the manifest runtime and access path — plus the routed questions as decisions
     to take, and any deferred jobs you want filed (title, reason, trigger), since you never
     run `defer-job` yourself
   ```

   The em-dashed middle clause is byte-identical to the string S3 shipped in
   `review-phase/SKILL.md` (verified by `grep -c` across all three files → 1/1/1).

### The `deferred_jobs_to_file` decision (plan item 5)

**Not added — no second return field.** Shared decision 8 says "one new return field only
(`walkthrough`)", and the plan set folding as the default. The listed jobs ride inside `walkthrough`
(the trailing clause above) plus `result.md`, exactly as `review-phase`'s stage 5 and its "two
commands you never run" paragraph describe. A dedicated field would have been a second thing to
keep in sync across the contract, the skill and two agent files for a list that is only ever read by
the orchestrator in the same breath as the walkthrough it accompanies. Recorded in `phase.md` too.

### Mid-only parity items (the D2 close-out and the rest)

All four gaps from the `DECOMP` finding "`slice-executor-mid.md` lags `-high.md` by more than D2"
are closed, with high's wording copied verbatim so a future Test 0 assertion can be one string for
both tiers:

- **D2 — the co-work refusal** is now in mid's *Never* list:
  "execute a `co-work` (design) slice — those are run inline by the orchestrator and never
  dispatched, because you have no `DesignSync`; if you are ever handed one, do no design work and
  return `needs_operator`". **D2 is fixed** — the orchestrator can now run
  `drop-deferred D2 --reason "fixed in P16.S4 — slice-executor-mid now carries the co-work refusal clause"`
  (not run here: executors run no state-transition command).
- The two-pass / `co-work` / `<P>.DECOMP2` language in the decomposition bullet.
- The review's "complete the validation and the judgment before you branch on the verdict", the
  `changes_requested` / `blocked` full stop before pass-only work, and the
  `explain: not written — run /explain for this phase` pointer (both in Do 1 and as the `explain`
  return field).
- High's broader no-commit wording ("with no exception anywhere: not in this workspace's repo and
  not in any other git root, on any slice kind (read-only inspection such as `git status` /
  `git diff` is fine)").

Mid's *tier* semantics are unchanged: it still escalates real code writing and cross-file work, and
its `## Escalate early` section is the same text it always had.

## Validation

| Command | Outcome |
|---|---|
| `python3 scripts/workflow.py sync-agents --check` | **agent files in sync** (`mid sonnet @ xhigh`, `high opus @ xhigh`, mode flex) — frontmatter untouched |
| `python3 installer/build.py` | wrote the artifact, **365435 bytes** |
| `python3 installer/build.py --check` | **OK** — artifact in sync with `installer/` source |
| `python3 scripts/workflow.py validate` | **Workflow validation passed** |
| `bash tests/retrofit_smoke.sh` | **ALL RETROFIT SMOKE TESTS PASSED**, exit 0, zero `FAIL` lines; Test 0 (`17 Claude skills, invocation metadata, design contract, and the v31 Codex-removal negatives`) passes with the new bodies |
| Parity diff (`diff` of both bodies from line 9) | **empty** — identical |
| Frontmatter diff (`git diff` filtered to frontmatter keys) | **no frontmatter lines changed** |
| Consistency grep, both files | `accept-gate` 1x, `defer-job` 3x, `walkthrough` 5x, `## Operator Runtime` 3x, `UNFILLED` 2x, `## Operator Questions` 3x, `## Regression Checklist` 2x, `needs_operator` 7x, `DesignSync` 1x — all with the S1–S3 spellings |
| Negative grep, both files | no `--walkthrough-file`, no invented field (`deferred_jobs_to_file` absent), and Test 0's per-tier negatives still absent |
| Artifact spot-check | both new bodies present in `bootstrap_agentic_workspace.sh` (2x each for the gate sentence and the DesignSync clause) |

## Deviations from `plan.md`

1. **The parity outcome is stronger than the plan predicted.** The plan expected three intentional
   body differences to survive; all three were already identical before this slice, so the bodies
   are now byte-identical and the "remaining intentional differences" list is frontmatter-only (see
   the table above). Nothing was removed from either file to achieve this — only mid gained text.
2. **`deferred_jobs_to_file` was not added** — the plan's stated default, and decision 8's "one new
   return field only". The list rides inside `walkthrough` + `result.md`.
3. **`## Regression Checklist` was added to the Inputs list** (for review slices) alongside the
   plan's named `## Operator Runtime`. The plan's item 3 requires re-running that list, and the
   `review-phase` skill's own *Read* block already lists both on a gated phase — omitting it from
   Inputs would have been the odd one out.
4. Nothing else: no frontmatter, `executors.toml`, `scripts/workflow.py`, `CLAUDE.md`, skill,
   `installer/payloads/`, `CHANGELOG.md`, `README*` or `tests/` edit; no test assertion added
   (S6 owns those); no commit and no state-transition command (`drop-deferred D2` left to the
   orchestrator).

## Doc impact recorded in `phase.md`

`architecture` — one line: the executor prompts now carry the gate/manifest/routing duties, the
`walkthrough` return field, `accept-gate`/`defer-job` on the Never list, and mid reached full body
parity with high (D2 closed).
