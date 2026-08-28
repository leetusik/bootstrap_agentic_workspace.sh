# Plan — P17.S2

Propagate the landed spec into every file that restates its invariants, and add `--kind`
validation to the engine. S1 decided the wording; this slice makes the other files agree and
adds the one piece of machine enforcement the phase buys.

## Read first

1. **`.claude/skills/design-cowork/SKILL.md`** — the landed spec (480 lines). **Copy from this
   file, not from `intent.md`.** Where they differ, the file is the reconciled version.
2. `works/phases/active/P17/phase.md` — `### From P17.S1` lists the seven one-line invariants to
   restate identically, the heading renames your grep sweep needs, and the corrected rebuild rule.
3. `works/phases/active/P17/intent.md` — §3 (the `--kind` hole) and §4 (agent-runnable
   `create-phase`) are specified there and nowhere else.

**Commit count is FOUR per design slice, not three.** S1's plan said three and was wrong.

## Part A — the engine (`scripts/workflow.py`)

Add `SLICE_KINDS` beside the other closed sets (L25-33; house style is a bare one-line set
literal, no trailing comma, no annotation). The set must be at least:

```
implementation · review · decomposition · fix · docs · qa · co-work
```

Verify against history before writing the literal:
`grep -rho '"kind": "[a-z0-9_-]*"' works/phases/ | sort | uniq -c`. It returns
`implementation · review · decomposition · fix · docs · qa` — **`co-work` count is zero**, because
no design phase has run here yet. A set derived from history alone would hard-error the one kind
this phase exists to protect.

**Hard error at creation.** Both `new-slice` and `promote-deferred` funnel through `create_slice()`
(~L837), which writes `kind` verbatim at ~L846. One guard there covers both call sites
(`new_slice` ~L906, `promote_deferred` ~L1787) with one message, in the house form
`raise SystemExit(f"invalid ...: {value}")` used by `set_slice_status` (~L925). **Validate the kind
before `require_phase`** — `promote-deferred` can create a phase before creating the slice, and a
rejected kind must not abort after the phase already exists.

**Warning, not error, in `validate()`.** In the slice loop (~L754-766), after the status check,
`warnings.append(...)` — never `errors.append`. Warnings print unconditionally and do **not** affect
the exit code, which is exactly the asymmetry required: an adopting repo carrying an invented kind
survives `/update-workspace` instead of having `validate` fail on history it cannot change. House
style ends a warning with a remedy clause.

**Do not use argparse `choices=`** — it appears nowhere in this file, it would bypass the shared
`create_slice` chokepoint, and it would print argparse's message instead of the house one. Adding a
`help=` to the two `--kind` arguments (~L1985, ~L2066) is welcome; note `--risk` next door is
**deliberately** unvalidated ("unrecognized values route to high"). That asymmetry is intentional —
say so in a comment so a later reader does not "fix" `--risk` for symmetry.

## Part B — `create-phase` becomes agent-runnable

- **Delete `disable-model-invocation: true`** from the frontmatter (L5).
- **Re-cut the prose at L10** — it says "Explicit invocation only", which would contradict the
  frontmatter the moment L5 is gone. It becomes: callable by the agent **when instructed** — by an
  approved plan or a direct instruction — and **never fired on its own initiative**. That is
  narrower than `design-cowork`, which does fire by itself.
- **The confirmation gate at step 3 does not move.** Whoever starts the intake, `new-phase` runs
  only after the operator explicitly confirms name and objective. State it in a way that survives
  the agent being the caller: **invocation is not the gate; confirmation is.**
- **Extend step 2's design-split question (L18) to the three styles** — `build-after`,
  `design-only`, `paired` — with the agent suggesting one and a reason, and the operator confirming
  or overriding. Keep the existing constraint intact and explain it: `design-only` **must** be
  chosen here because the `DECOMP` executor cannot run `new-phase`. Note that `DECOMP` may ask the
  question late (stopping `pending`) when a phase was created before its visual nature was clear.
- **Add a `## Design Style` step to the `intent.md` fill list (L36-40)** — the confirmed style, so
  `DECOMP` can read it.

**Decision to make and state (an open Operator Question from `DECOMP`):** whether `## Design Style`
is scaffolded into `works/templates/intent.md` for every phase or appended by `create-phase` only
when the phase is visual. Decomposition's read — and mine — is **only when visual**; a heading on
every non-visual phase is noise, and the template ships to every adopting repo. Implement that
unless you find a reason not to, state the decision in `result.md`, and make the rule **tolerate
the section's absence** — P17's own `intent.md` has no such section.

## Part C — the drivers

`.claude/skills/do-next-slice/SKILL.md` (L12, L25, L26, L37) and
`.claude/skills/do-whole-phase/SKILL.md` (L12, L20, L21, L22, L25, L29). `do-whole-phase` L21 is
the densest rewrite target — it is the whole design-slice procedure.

Beyond restating the seven invariants, **four behavioural gaps** that a `co-work` grep does not
find, because they are consequences of the old dispatch ban rather than restatements of it:

1. **`plan only` has no rule for `paired`.** Both drivers stop before `DECOMP2` because its plan
   depends on the landed design. `paired` has no `DECOMP2` — its apply slices are bare folders whose
   plans depend on a round that has not landed. As written, `plan only` would pre-plan them. Give it
   the general rule the spec's re-cut `Never` bullet already states: **stop before anything whose
   plan depends on a round that has not landed** — `REVIEW`, `DECOMP2`, and a `paired` apply slice
   alike.
2. **A `co-work` slice now resumes twice**, so under `do-next-slice` it takes **three** invocations
   (handoff → stop; read-back + mockup dispatch → stop; gate → SIGNOFF → finish). L26 says "continue
   at step 5 on resume", singular. Neither driver models a slice that resumes twice — fix both.
3. **"There is no executor and so no idle window on such a slice"** (`do-whole-phase` L21, and the
   judgment list at L25) is now false: the mockup span *is* a dispatched executor with a real idle
   window. Correct both, and note the window is short and sits between two operator stops.
4. **The two `pending` windows are indistinguishable to the engine** — both are `status: pending` on
   the same slice, and `validate()` cannot tell them apart. Every driver prints "WAITING ON
   OPERATOR" and says "report exactly what you need". Under PENDING #1 the operator is being told
   the handoff is ready; under PENDING #2 they are being asked to open a URL and approve. Specify
   **distinguishable operator-facing messaging** for each, since the distinction can live nowhere
   else.

Also: the gate-declaration rule at `do-whole-phase` L29 gains **a phase shipping a mockup takes
`--require`, and `design-only` can no longer be waived.** Order it against the style question — if
`DECOMP` is the slice that asks the style, the answer must land before the gate is declared, because
the declaration depends on it.

## Part D — the executor agents

`.claude/agents/slice-executor-mid.md` and `slice-executor-high.md` are **byte-identical below the
frontmatter** (only lines 2-5 differ). **Apply every body edit twice, verbatim**, and keep them
identical — `diff` them at the end and confirm only the frontmatter differs.

- **L32** (decomposition bullet): "never give a `co-work` slice implementation work" narrows to
  **product** implementation work; add that the plan may call for the design/apply pairs of `paired`
  and that a `co-work` slice may carry a dispatched mockup span. Mention all three styles.
- **L47** (`## Never`): "execute a `co-work` (design) slice … if you are ever handed one, do no
  design work and return `needs_operator`" — now wrong as an absolute. It becomes: you may be handed
  **the mockup span** of a `co-work` slice, which is legitimate; what you must still never do is the
  DesignSync work or any design decision.
- The mockup span's own rules belong where an executor will find them: built from
  `build-prompt.md` with no DesignSync, **stubbed data, no backing work**, RESPECT THE DESIGN,
  verified in the `## Operator Runtime` (absent/`UNFILLED` → `needs_operator`), **exempt from the
  full functional sweep**, and the third `needs_operator` condition — a record too thin, wrong, or
  inconsistent to build from is raised, never filled in.

The bodies are tier-neutral except at L14/L15/L54. **Do not write "high only"** into a shared body;
either state it tier-neutrally and let the drivers route, or use the both-tiers-in-one-sentence form
L14/L15 already uses.

## Part E — the contract (`CLAUDE.md`)

L24 (skill invocation — `create-phase` becomes a **second, narrower** exception: callable on
instruction, never autonomous), L58 (two-pass rule → three styles), L64 (never-dispatched → the
DesignSync work), L65 (idle-window skip list — `co-work` now has a window), L67 (`pending` must
accommodate a mechanical, non-approval window), L73 (works-as-a-product, qualified by the mockup's
sweep exemption), L75 (the invariant summary — the densest sentence in the repo), L81 (slice IDs:
the `DECOMP2` parenthetical needs qualifying, since `paired` has none), the `accept-gate` bullet
(mockup ⇒ `--require`, `design-only` no longer waivable), and the `new-slice` command line
(`--kind` is now a closed set) — **which appears twice**; update both.

## Part F — the test suite

`tests/retrofit_smoke.sh` **already fails** against S1's landed spec. Fix it; do not weaken it.

- **L58-59:** `assert (marker in body) == (name != "design-cowork"), name` asserts every skill but
  `design-cowork` carries `disable-model-invocation: true`. `create-phase` is now a second
  exception. Widen to both names and keep the assertion exact — it is what stops the marker being
  dropped by accident.
- **L80-90, three now-missing strings**, two of which assert superseded wording. Replace them with
  the *new* invariants rather than deleting the checks:
  - `"The design slice is NOT"` → assert the DesignSync work is never dispatched **and** that the
    mockup build is the one dispatched span.
  - `"never writes implementation code"` → the **product** implementation wording.
  - `"signing the cards is not accepting the product"` → S1 widened this to cover the stubbed
    mockup; assert the new sentence.
- **Add positive assertions for what this phase buys**, so a later edit cannot quietly undo it: the
  three style names, `## The mockup`, PENDING #1 not being an approval, and the mockup's sweep
  exemption.
- **L72** asserts driver strings (`` `kind: co-work` ``, `never dispatched`, `DesignSync`) — re-check
  after Part C and update what your edits move.
- A `validate()` **warning is exit-code-neutral**, so a test for the unknown-kind warning must assert
  on **stdout**, not the exit status.

Run the suite. It is the only real test this repo has; **it must pass before you return `done`.**

## Part G — sweep and rebuild

- **Grep sweep** for superseded wording across the whole tree: `co-work`, `cowork`, `DECOMP2`,
  `never dispatched`, `not dispatched`, `two passes`, `two phases`, `two commits`,
  `disable-model-invocation`, `Explicit invocation only`. **Heading names moved** — see the rename
  table in `phase.md`. Line numbers throughout this plan are pre-edit and will drift: **grep, do not
  trust them.**
- **Check the skills the six-file table omits:** `review-phase` and `do-*` mention `kind`; the
  `promote-deferred` and `defer-job` skills may document `--kind` and would need the closed set. Fix
  what you find; report what you checked.
- **Rebuild:** `python3 installer/build.py`, then `--check`. Almost everything you touch is an
  embedded payload, and the pre-commit hook rejects a drifted artifact. **Do not** bump
  `WORKSPACE_VERSION` and **do not** write a `CHANGELOG.md` entry — S3 owns both.
- `installer/main.py`'s `flag_stale_skills()` uses the `disable-model-invocation` marker as an
  *ownership* test, and skips any skill named in `CLAUDE_SKILLS` before reaching it — so
  `create-phase` losing the marker changes nothing today. **Leave the heuristic alone**; it is
  already an open Operator Question and is `defer-job` material, not this slice's work.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `bash tests/retrofit_smoke.sh` passes.
- `python3 installer/build.py --check` passes.
- `diff` the two executor agents — only frontmatter lines 2-5 differ.
- Kind validation, by hand: `new-slice --kind cowork` errors and names the set; `--kind co-work`
  succeeds; `validate` warns but exits 0 on the repo's existing `qa`/`docs` kinds. **Delete any
  scratch slice you create** and leave `works/` exactly as you found it.
- Re-read each edited file's changed sections and confirm none still states a superseded rule.

## Notes

- Append **Doc impact** notes to `phase.md` for anything durable you change — the `--kind` closed set
  and the `create-phase` invocation change both belong in `operations.md`/`decisions.md`. Do **not**
  run `doc-new-version`; the review consolidates.
- Raise contradictions rather than designing around them. `DECOMP` and S1 both did, and both times
  it improved the phase.
