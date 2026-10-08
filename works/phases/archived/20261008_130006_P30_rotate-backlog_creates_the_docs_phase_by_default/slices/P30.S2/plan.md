# Plan — P30.S2 Skills, texts and release v51

## Goal

Implement **D7–D10** of `works/phases/active/P30/phase.md` `## Decisions`. Write everything from S1's **final** printed keys (D2) and the `(from P30.S1, for P30.S2)` note, not from the draft. Read `intent.md` for the operator's words. S1's `result.md` shows real proposal output from a scratch copy; use it for examples.

## Steps

1. **`.claude/skills/rotate-backlog/SKILL.md` — rewrite (D7).**
   - **Frontmatter:**
     - Keep `name` and `disable-model-invocation: true`.
     - Rewrite `description` to say the default now also proposes the docs phase. Quote it if it contains `: `, because an unquoted colon-space is invalid YAML.
     - Set `allowed-tools: Bash(python3 scripts/workflow.py:*), Read, Edit, Write`, the same shape as create-phase.
   - **Body, in order:**
     - **(a)** Run `python3 scripts/workflow.py rotate-backlog`. When the invocation args contain `archive-only`, run it with `--archive-only` instead, relay, and stop: that is today's behaviour.
     - **(b)** Relay what was archived, and what was left active and why.
     - **(c)** Read the block's ending:
       - `docs_phase=none` → report and stop.
       - `docs_phase_covered=` lines → name the live docs phase that already pays them; nothing to create.
       - `docs_phase_proposal=` block → present the proposed `phase`, `name` and `objective`, plus the scope from `python3 scripts/workflow.py docs-debt` (summarised: phases, note count, docs). Ask the operator **once** to confirm. They may edit the name or objective, or narrow the phase list; a phase left out keeps owing and stays active.
       - A run may print both covered lines and a proposal.
     - **(d)** On their explicit yes, run the printed `create:` line, or the same shape with the edited name/objective and the narrowed `--consolidates` list. Then fill the new phase's `intent.md` exactly as create-phase's *docs-phase route* says:
       - Origin `operator`;
       - the operator's words verbatim (their `/rotate-backlog` invocation plus their confirming reply);
       - Confirmed Intent with the `docs-debt` scope;
       - the DECOMP cut: one `--kind docs` slice per doc, `doc-new-version` → `rebuild-docs` per note, `docs-consolidated <P>` (or `parallel-consolidated`, as `docs-debt`'s `pay:` line says) per covered phase, and the acceptance gate normally `--waive`d.
     - **(e)** STOP and report: the phase id, the `intent.md` path, and that `/do-whole-phase` executes it. Never decompose or plan slices.
   - **Rules to state:**
     - The confirmation gate is create-phase's, unchanged: typing `/rotate-backlog` is not the confirmation.
     - The docs phase runs on the default stream; never mention or start a worktree.
     - No `--force`; archiving is untouched.
     - Point to the `create-phase` skill's docs-phase route as the source of truth for `intent.md`, rather than duplicating all of it. Keep the skill short.
   - **Keep the paragraph** that contrasts rotate with `archive-all` and `archive-phase --force`.

2. **`.claude/skills/create-phase/SKILL.md` — the docs-phase route (D8).**
   - In *The docs-phase route*, step 4 / the `new-phase` instruction now passes `--consolidates <the confirmed phases>`, which is what lets `rotate-backlog` and `docs-debt` see the debt as being paid.
   - Add one sentence near the route's opening: `/rotate-backlog` is the default entry point that proposes this route, and it runs this same confirm-then-create sequence.
   - Do not touch any text smoke Test 0 pins. `grep -n create_phase tests/retrofit_smoke.sh` lists them, around L94–115: "the agent when instructed", "Never on the agent's own initiative", "Invocation is not the gate; confirmation is.", and the design pins.

3. **`.claude/skills/archive-phase/SKILL.md` (D9).**
   - In the rotate paragraph (~L20–24) and the gate sentence (~L32), rotate "leaves it active **and proposes the docs phase that pays it**".
   - Add a one-line mention of `--archive-only` beside the rotate command.

4. **Other texts.** Grep for `rotate-backlog` in:
   - `README.en.md` (and `README.md` if it names it);
   - `do-next-slice`, `do-whole-phase`, `review-phase` and `parallel-phase` SKILL.md;
   - the executor agents.

   Change a line **only if it becomes false**. "rotate-backlog to archive just the done phases" stays true, so leave those lines alone; at most one clause in the README where rotate is described for operators. Do not edit `CLAUDE.md` unless a line in it is now false; none is expected.

5. **Release (D10).**
   - `CHANGELOG.md` gets a new `## v51 — 2026-10-07` above v50, in the same style as v50. It covers:
     - `/rotate-backlog` now proposes the docs phase by default, and `/rotate-backlog archive-only` / `rotate-backlog --archive-only` opts out;
     - `new-phase --consolidates`;
     - the `docs-debt` `paid by:` line;
     - the `validate` shape check on `consolidates`;
     - **Migration notes:** none required. Older phases carry no key, and a docs phase created before v51 is simply not seen as covering, so rotate may propose one that already exists; decline it.
   - Set `WORKSPACE_VERSION = 51` in `scripts/workflow.py`. Check for any smoke assertion or text pinned to `50` (`grep -n "WORKSPACE_VERSION\|v50\|= 50" tests/retrofit_smoke.sh`) and follow how P29.S2 handled the bump.
   - Run `python3 installer/build.py`, then `python3 installer/build.py --check`.

## Validation

- `python3 scripts/workflow.py validate` passes.
- `python3 installer/build.py --check` passes.
- Run `bash tests/retrofit_smoke.sh` **once, as the only command in its own foreground Bash call**. The baseline is **239 PASS / 0 FAIL**, and it is expected to stay 239 (no new tests).
- Never run a real `rotate-backlog` in this repo.

## Notebook

- Append `## Doc impact` lines tagged `(P30.S2)`:
  - operations: the `/rotate-backlog` operator flow and opt-out word, and the docs-phase route's `--consolidates`;
  - decisions: if any new rationale was introduced.
- Consume the S1→S2 note, keep the REVIEW note, and rewrite `## Now` to point at the review.

Do not commit and do not transition state.
