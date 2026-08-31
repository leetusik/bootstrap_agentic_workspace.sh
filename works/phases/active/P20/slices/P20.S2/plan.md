# Plan — P20.S2 (require a dedicated Aside profile for agent runs)

- Phase: **P20** — make the Aside prescription true
- Kind / risk: `implementation / high` → **`slice-executor-high`**
- Order 2 of 3; depends on `P20.S1` (**done**). `P20.S3` (release) follows. Mode: `auto`.

## What this slice is

**Intent part 3** — *whose browser an agent may drive* — written **into the text `P20.S1` just
landed**, not beside it. `P20.S1` rewrote every surface passage (two surfaces, `aside repl` over Bash,
the escape hatch, the assertion-suite framing); read those passages as they now stand before you touch
them. This slice adds **one axis** to them: the profile, and the new halt that enforces it.

It also **confirms intent part 4** — the fallback paragraphs are unchanged and must stay verbatim.

Read first, whole: `works/phases/active/P20/phase.md` (`## Decisions`, and the notes tagged for
`P20.S2` — especially **"Where S1's rewrite landed"**, which names every home) and
`works/phases/active/P20/intent.md` part 3. The blast radius is already established: **do not
re-inventory the tree.**

## The rule to write — confirmed by the operator, not yours to redecide

**Agent Aside runs happen on a dedicated profile, never the operator's signed-in one.** This is a
**doctrine-level requirement**, not a recommendation, and the reason is *authority*, not availability:

> Aside is a real desktop browser. The live probe on 2026-09-01 reached a profile holding the
> operator's **Google session, 49 imported passwords and 6 passkeys**. An agent driving that profile
> is not "browsing" — it can read the operator's mail, spend from saved cards, and authenticate as
> them anywhere those credentials reach. Nothing in a fidelity sweep needs any of that.

The mechanics, **verified against the installed CLI** (Aside 1.26.810.1915 — `aside --help`,
`aside account --help`, `aside repl --help`; read-only inspection, no session driven):

- `aside repl` takes **`--account <id>` per invocation**: `aside repl --account <id> "…"`. Account ids
  are short opaque tokens (`0`, `u0`, `u1`), cheap to record in a doc.
- **Prescribe the per-invocation flag, and *not* `aside account use <id>`.** `account use` sets the
  **default**, and the default is exactly the operator's signed-in profile — a default is the thing
  that silently reverts between sessions, machines and updates. Every call carries its own `--account`.
- `aside account list` (read-only) enumerates the local accounts. That is the concrete check behind
  the halt: an executor can see whether a dedicated profile exists **without driving anything**.
- The **`## Operator Runtime` manifest records which account id is the agent's** — otherwise the
  executor has nothing to pass.

**The halt — a new, third condition.** Keep it sharply distinct from the two that exist:

| | condition | consequence |
|---|---|---|
| runtime (v32) | `## Operator Runtime` absent or still `UNFILLED` | `needs_operator` → `pending` |
| instrument (v36) | manifest names no instrument | **nothing** — never stops a slice |
| **profile (v37, new)** | the manifest names **Aside** but records no agent account id, **or** `aside account list` shows only the operator's personal profile | **`needs_operator`** → `pending` |

The notebook's standing note applies: **write the profile halt without blurring it into the runtime
halt.** They fire on different evidence and a reader must be able to tell which one they are in.

**The workspace never resolves it for the operator.** Creating an Aside account is an outward-facing
operator action; v37 changes the prescription, not the "nothing installs, bundles, registers or
auto-configures Aside" rule. The executor **asks and stops** — it never falls back to the personal
profile "just for this check", and never runs `aside account use`.

## One judgment call, and how to handle it honestly

The fallback branch has the **same** exposure: a Linux/CI workspace driving "whatever real browser it
has" can just as easily be pointed at the operator's daily Chrome profile, and D11's reasoning is
about *authority*, which is instrument-independent. `intent.md` part 3 is written about Aside.

**Write the one-clause generalization** — an agent never drives a browser profile signed into the
operator's accounts, whichever browser it is — because leaving it out puts a hole in the doctrine
exactly where the fallback lives. But do **not** silently expand scope: add an entry to
`## Operator Questions` in `phase.md` saying plainly that part 3 named Aside, that you generalized the
principle to the fallback browser in one clause, and that the operator should confirm or narrow it.
The review routes that entry (this phase's gate is **waived**, so it will be filed with `defer-job`
rather than folded into a walkthrough).

Do not generalize any further than that one clause on your own initiative.

## Files you own — the profile addition, in the homes S1 established

The split S1 preserved still holds: **contract = the rule, agent bodies = the instruction,
`design-cowork` = the reasoning and the invocation, seed = the recorded field.** Match each file's
existing register; do not paste the same paragraph into five places.

1. **`.claude/skills/design-cowork/SKILL.md`, *With what — the instrument*** (~420–460 as it now
   reads) — the **long form**, and the place the concrete invocation already lives. Put
   `--account <id>` **on the prescribed invocation itself** so the flag is impossible to miss, state
   the authority reason in a sentence or two (the credentials the probe found make the point without
   embellishment), name `aside account list` as the check and `aside account use` as the thing not to
   rely on, and state the halt. **Leave the fallback paragraph (~462–466) verbatim** apart from the
   one generalizing clause above, if that is where you judge it belongs.
2. **`CLAUDE.md` line 76** — one sentence of **rule**, in the compact register the contract uses:
   dedicated profile via `--account <id>`, manifest records which, personal-only → `needs_operator`.
   This is a routing contract; do not import the reasoning.
3. **`.claude/agents/slice-executor-high.md` and `slice-executor-mid.md`, line 32** — the
   **instruction**, and the only place a reader will actually be about to run the command. Both
   bodies, **byte-identical** in this passage; the smoke test asserts each string in both tiers, and
   drift is a defect. Run `python3 scripts/workflow.py sync-agents --check` afterwards.
   Judge whether lines 33 (mockup span) and 36 (review gate stage 2) need more than the pointer they
   already carry — they inherit "the same instrument", and inheriting the profile rule with it is
   probably right; say what you decided in `result.md`.
4. **`.claude/skills/review-phase/SKILL.md` line 43** — gate stage 2 has the review **open the running
   product itself**, so the review is a browser-driving slice and needs the rule too. One clause,
   matching its neighbours' brevity.
5. **`installer/payloads/doc_bodies/operations.md`** — the seeded `## Operator Runtime` block, where
   S1 deliberately left room beside the instrument field. Add the **profile field**. Two things must
   stay true and they are in tension, so read the block before writing:
   - the existing `- Browser instrument for the agent:` line is **optional** ("its absence alone never
     stops a slice") — that clause is asserted by the smoke test and must survive;
   - the profile is **required whenever the instrument is Aside**.

   So the new field is **conditionally required**, and the seed must say so in its placeholder: if the
   manifest names Aside, it names the agent's account id too; if it names no instrument, there is no
   profile question. Keep the `- Status: UNFILLED` line and the block's shape intact.
6. **`tests/retrofit_smoke.sh`** — see below.

## The smoke test — in this slice, not deferred to `P20.S3`

After S1 the Test 5 blocks sit at roughly: design **~139–166**, review-phase **~173–182**, ops seed
**~190–196**, both agent bodies **~230–252**, `CLAUDE.md` **~302–318**, summary line **332**. Verify
those offsets before editing — S1 moved them once already.

- **The `design` text is whitespace-normalised** (`" ".join(...split())`), so any design-cowork
  assertion string must be written as **one line**. This bit S1's block layout; do not rediscover it.
- Add `# v37:` positives pinning what this slice establishes: the dedicated-profile requirement, the
  per-invocation `--account <id>`, and the personal-profile → `needs_operator` halt — in the contract,
  in **both** agent bodies, in `review-phase`, in `design-cowork`, and the new seed field.
- Keep every assertion S1 left green. In particular **do not touch** the instrument field's
  `"its absence alone never stops a slice"` — your new field is a *different* field with a *different*
  rule, and if your seed edit makes that string false, the seed is wrong, not the assertion.
- Consider a **negative** in the established idiom: nothing should prescribe `aside account use` as
  the way an agent selects its profile.
- Leave the `WORKSPACE_VERSION` three-way-equality assertion (~line 395 pre-S1) alone — `P20.S3`'s.

## Validate

Run all of these and record the outcomes in `result.md`:

1. `python3 installer/build.py` — **mandatory** (you edit machinery, and the orchestrator commits at
   this boundary); leave the rebuilt `bootstrap_agentic_workspace.sh` in the tree.
2. `python3 installer/build.py --check` — must pass.
3. `python3 scripts/workflow.py sync-agents --check` — no drift.
4. `bash tests/retrofit_smoke.sh` — **full run**, green. S1 left it at **139 PASS / 0 FAIL**; report
   what S2 makes it and account for any change in the count.
5. `python3 scripts/workflow.py validate` — must pass.
6. A consistency grep: every live carrier that prescribes driving a browser with Aside should now also
   carry the profile rule. `grep -rn "account" CLAUDE.md .claude/ installer/payloads/` and confirm the
   set is exactly the five files above.

**Read-only Aside inspection only** (`--help`, and `aside account list` if you want to see the shape).
**Drive nothing.** Do not open a browser, do not start a session, do not run `aside account use`, and
do not touch the operator's profile — this slice writes the rule that exists precisely because that
profile is dangerous. Make no browser claim.

## Notebook and result

- **Edit `phase.md`** under budget (it is at 87 lines / 15,210 bytes — **close to the 16 KB ceiling**,
  so this is a compressing edit, not an appending one): drop the notes you consumed (the
  agent-body-twinning note, the instrument/runtime-axes note, the nothing-installs note and the
  "Where S1's rewrite landed" note are all tagged for S2 and should go once spent), leave `P20.S3`'s
  and the review's notes intact, add your `## Operator Questions` entry, append your `## Doc impact`
  lines, and rewrite `## Now` (≤ 15 lines) as `P20.S3`'s handoff — S3 needs the smoke-test count, the
  fact that both doctrinal slices are complete, and what its sweep should look for.
- **`## Doc impact`** — at least `qa.md` (the profile requirement and the third halt in the
  *Verification doctrine*), `operations.md` (the new manifest field and its conditional requirement),
  `decisions.md` (v37 closes D11 with a doctrine-level rule). One line each, `(P20.S2)`.
- **`result.md`, verdict block first**, then the log: what you added where, how you resolved the
  optional-instrument / required-profile tension in the seed, the fallback-generalization call, the
  assertions you added, and the smoke counts. Reference `phase.md` by path rather than restating it.

## Do not

- Re-open intent part 3 — dedicated profile is **required**, confirmed; and do not soften the halt
  into a warning.
- Rewrite S1's surface wording, the fallback paragraphs, or the instrument/runtime axes rule.
- Bump `WORKSPACE_VERSION`, write the `## v37` CHANGELOG section, or edit `installer/main.py` — `P20.S3`.
- Edit `docs/current/*`, `docs/versions/*`, `docs/index.json`, `works/phases/archived/**`, the
  generated dashboards, or another slice's `plan.md`.
- Hand-edit `bootstrap_agentic_workspace.sh`; run any git command, status transition, `accept-gate`,
  `doc-new-version`, `defer-job` or `drop-deferred`.

## Verdict

Return the structured verdict block, `summary` in one line. `needs_operator` only if part 3 cannot be
written without an answer `intent.md` does not give — the fallback-generalization question is
explicitly **not** such a case: write the clause and log the question.
