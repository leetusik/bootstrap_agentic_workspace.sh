# Result — P20.S2 (require a dedicated Aside profile for agent runs)

- **status**: `done`
- **summary**: Wrote intent part 3 into the text `P20.S1` landed — agent Aside runs happen on a dedicated
  profile named per invocation (`aside repl --account <id> "<js>"`, never `aside account use`), the
  `## Operator Runtime` manifest records which account id is the agent's, and a manifest naming Aside with no
  agent account id (or a machine holding only the operator's personal profile) is a third `needs_operator`
  halt distinct from the runtime one — across the contract, both agent bodies, `review-phase`,
  `design-cowork` (long form + the authority reasoning) and a new conditionally-required seed manifest field,
  with the v37 profile assertions pinned in `retrofit_smoke.sh`.
- **files_changed**:
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/CLAUDE.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/agents/slice-executor-high.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/agents/slice-executor-mid.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/skills/design-cowork/SKILL.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/.claude/skills/review-phase/SKILL.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/installer/payloads/doc_bodies/operations.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/tests/retrofit_smoke.sh`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh` (rebuilt artifact)
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/works/phases/active/P20/phase.md`
  - `/Users/sugang/projects/personal/bootstrap_agentic_workspace.sh/works/phases/active/P20/slices/P20.S2/result.md`
- **validation**:
  - `python3 installer/build.py` — PASS (wrote `bootstrap_agentic_workspace.sh`, 448341 bytes; re-run after the
    final rewrap so the artifact in the tree is current)
  - `python3 installer/build.py --check` — PASS (artifact in sync with `installer/` source)
  - `python3 scripts/workflow.py sync-agents --check` — PASS (mid sonnet@xhigh, high opus@xhigh, no drift)
  - `bash tests/retrofit_smoke.sh` — PASS, **139 PASS / 0 FAIL** (`ALL RETROFIT SMOKE TESTS PASSED`)
  - `python3 scripts/workflow.py validate` — PASS (`Workflow validation passed.`)
  - consistency grep `grep -rn -- "--account" CLAUDE.md .claude/ installer/payloads/` — exactly the five
    prescribing files (design-cowork ×3, both agent bodies, `review-phase`, `CLAUDE.md`); the seed names the
    field without the flag, which is correct for a manifest placeholder
  - `grep -rln "Aside\|aside " CLAUDE.md .claude/ installer/payloads/ works/templates/ scripts/` — the same five
    files plus the ops seed, i.e. no live carrier prescribes Aside without the profile rule
- **deviations**: none from the plan's instructions. Two judgment calls the plan asked me to make and report are
  in *Decisions I made* below (agent-body lines 33/36 left as pointers; the `aside account use` mention kept only
  in the two carriers whose register explains a rule).
- **doc_impact**: three lines appended to `## Doc impact` in `works/phases/active/P20/phase.md` — `qa.md`
  (dedicated profile, per-invocation `--account <id>`, the third halt, the fallback clause), `operations.md`
  (the new conditionally-required manifest field beside the still-optional instrument field), `decisions.md`
  (v37 closes D11 with a doctrine-level rule).
- **doc_versions**: n/a (non-review slice — no `doc-new-version`)

## What landed, where

The split S1 established held: **contract = the rule, agent bodies = the instruction, `design-cowork` = the
reasoning and the invocation, `review-phase` = one clause, seed = the recorded field.** Nothing was pasted twice.

1. **`.claude/skills/design-cowork/SKILL.md`** — the long form. A new paragraph **“Whose browser — a dedicated
   profile, never the operator's.”** sits between the escape-hatch sentence and *Why the executor drives*: the
   authority reason stated plainly (the probe reached a profile holding the operator's Google session, 49
   imported passwords and 6 passkeys; an agent there can read mail, spend from saved cards and authenticate as
   the operator), the invocation `aside repl --account <id> "<js>"` with the id shapes (`0`, `u0`, `u1`),
   `aside account list` named as the read-only check, `aside account use` named as the thing **not** to rely on
   (it moves the *default*, and the default is the operator's profile), and the halt — including that the
   workspace never creates an account for the operator, and that this is a **third** condition, not the runtime
   one. `--account <id>` also went onto the prescribed CLI invocation in the sharp-edges paragraph so the flag is
   impossible to miss on the line someone actually copies.
2. **`CLAUDE.md` line 76** — one compact rule sentence group (**“Whose browser: a dedicated profile.”**) inserted
   between the *instrument and runtime are different axes* sentence and *The fallback*, so the “third halt,
   distinct from the runtime halt above” reads against the halt it is being distinguished from. No reasoning
   imported.
3. **Both agent bodies, line 32** — byte-identical instruction, inserted where the executor is about to run the
   command: “Every call names the agent's own Aside profile — `aside repl --account <id> "<js>"`, the id recorded
   in `## Operator Runtime` — never the operator's signed-in one; if the manifest names Aside but records no
   agent account id, or the machine holds only the operator's personal profile, return `needs_operator` (a third
   halt, distinct from the runtime one) rather than borrowing it.” `sync-agents --check` reports no drift.
4. **`.claude/skills/review-phase/SKILL.md`, gate stage 2** — one clause at its neighbours' brevity: the review
   drives the product “always on the agent's own Aside profile (`aside repl --account <id> "<js>"`, the id from
   the manifest — never the operator's signed-in one; a manifest naming Aside with no agent account id, or only a
   personal profile on the machine, means `needs_operator`)”.
5. **`installer/payloads/doc_bodies/operations.md`** — a second manifest field, placed directly under the
   instrument field: `- Agent's Aside account id (required whenever the instrument above is Aside): <the
   dedicated agent profile, e.g. u1 — never the operator's signed-in one; `aside account list` shows what exists.
   No instrument named above, no profile to record>`.

## The optional-instrument / required-profile tension in the seed

The plan flagged it correctly: the instrument field is **optional** (“its absence alone never stops a slice”, a
string the smoke test asserts and which must stay true), while the profile is **required whenever the instrument
is Aside**. I resolved it by making the requirement **relative to the field above it rather than absolute** — the
new field's own parenthetical says *required whenever the instrument above is Aside*, and its placeholder closes
with *No instrument named above, no profile to record*. That keeps three things simultaneously true: an operator
who names no instrument still trips nothing; an operator who names Aside owes an account id; and the instrument
field's own optionality clause is untouched and still asserted. The `- Status: UNFILLED` line and the block's
shape are intact, and the field carries no `aside mcp` string (the smoke test asserts its absence from the seed).

## Decisions I made, and why

- **Agent-body lines 33 (mockup span) and 36 (review gate stage 2) were left unchanged.** Both already point at
  “the same instrument (Aside first)”, and the profile rule is now part of what that pointer names — in the
  contract, in line 32 of the same file, and in both skills those bullets defer to. Adding a second copy would
  cost tokens in every executor session for no new instruction. The plan asked me to say what I decided; this is
  it.
- **`aside account use` is named only where a rule is being explained** — `design-cowork` (“do not rely on…”)
  and `CLAUDE.md` (“only moves the default, so it is not how a profile is selected”). It is **absent** from both
  agent bodies, `review-phase` and the seed, and the smoke test now asserts that absence. An executor reading its
  own body is told the positive form (pass the flag per invocation) and never sees the command it must not run.
- **The fallback generalization** (the plan's one judgment call): I wrote the single clause — *an agent never
  drives a browser profile signed into the operator's accounts, whichever browser it is* — into
  `design-cowork`'s fallback paragraph (the reasoning home) and the `CLAUDE.md` rule (the rule home), and
  **nowhere else**; the agent bodies, `review-phase` and the seed stay Aside-specific. `intent.md` part 3 is
  written about Aside, so the question is logged in `## Operator Questions` in `phase.md` for the review to route
  with `defer-job` (the gate is waived). Everything else in the fallback paragraphs is verbatim — part 4
  confirmed unchanged.

## Aside inspection — read-only, and one honest finding

Read-only only, as instructed: `aside --help`, `aside repl --help`, `aside account --help`. **No browser was
driven, no session started, `aside account use` was never run, and no browser claim is made anywhere in this
slice.** Verified facts:

- `aside repl --help` shows `--account <id>` as a per-invocation option (`aside repl --account u1 "await
  openTab('https://example.com')"` is in its own examples), and the same flag exists on `aside` itself.
- `aside account` has `list`, `status [id]` and `use <id>` — `use` sets the **default**, confirming the plan's
  reasoning for prescribing the flag instead.
- **`aside account list` needs the Aside app running.** On this machine it returned `Failed to request daemon
  auth challenge: fetch failed / Aside daemon is not reachable — make sure Aside Browser is running, then
  retry.` That is a real constraint on the halt's evidence, so the doctrine states it once, in the long form: the
  command enumerates local accounts *without driving anything*, but an unreachable daemon “is not evidence either
  way”. The manifest field remains the primary source of the agent's account id; `aside account list` confirms it.

## Smoke-test assertions added

All inside Test 5's existing python heredoc, in the established idiom, grouped under `# v37:` comments:

- **design** (whitespace-normalised, so each string is one line): the paragraph heading, `` `aside repl
  --account <id> "<js>"` ``, ``do not rely on `aside account use <id>` ``, `That is a **third** halt condition and
  it is not the runtime one`, and the fallback generalization clause.
- **review-phase**: `always on the agent's own Aside profile`, the invocation, `never the operator's signed-in
  one`; plus the new negative `aside account use`.
- **both agent bodies**: `Every call names the agent's own Aside profile`, the invocation, `never the operator's
  signed-in one`, `` return `needs_operator` (a third halt, distinct from the runtime one) ``; plus the negative.
- **`CLAUDE.md`**: `**Whose browser: a dedicated profile.**`, ``pass `--account <id>` on every invocation``,
  `` is a **third** halt: `needs_operator` → `pending` ``, and the generalization clause.
- **ops seed**: the new field's label + its conditional clause, `never the operator's signed-in one`, and the
  negative. S1's `its absence alone never stops a slice` and `` `aside repl` over Bash `` assertions are
  untouched and still green.
- The Test 5 summary `ok`/`bad` strings now name the dedicated-profile invariants beside the surface ones.

**On the count: 139 PASS / 0 FAIL, unchanged from S1 — and that is expected, not a missing test.** The suite
reports one `PASS` line per *block*, and every string above rides inside Test 5's single python heredoc, which
already emitted its one line. The count would only move if a slice added a new `ok`/`bad` block. Any of the new
assertions failing turns that one line into a `FAIL`. The `WORKSPACE_VERSION` three-way-equality assertion was
left alone — it is `P20.S3`'s.

## Notebook

`works/phases/active/P20/phase.md` was **compressed**, not appended to: the four notes tagged for `P20.S2` (agent
body twinning, instrument/runtime axes, nothing-installs, “Where S1's rewrite landed”) are spent and gone, the
S3-facing notes were tightened and re-tagged with post-S2 offsets and a new carrier-set grep note, the `P20.S2`
decision line was replaced in place with what landed, three `## Doc impact` lines and one `## Operator Questions`
entry were appended, and `## Now` was rewritten as S3's handoff. It sits at **91 lines / 15,983 bytes**, inside
the 200-line / 16 KB budget with room for S3. The notebook is not restated here; read it at
`works/phases/active/P20/phase.md`.
