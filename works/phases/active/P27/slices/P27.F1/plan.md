# Plan — P27.F1 (fix / high: repairs S3's mid-tier driver text)

## Finding (P27.REVIEW #1, plus #3 and two nits)

**The bug.** Both drivers' `claude-design` branch runs the steps on the operator's return in the wrong order:
- It **reads back and lands the round first** (DesignSync read-back, `output/`, card and concreteness checks) and only **then** branches on the operator's words.
- So a failing read-back stops `pending` before feedback is routed. The operator's feedback never reaches `feedback.md`, and a superseded round gets `output/` landed, which the skill's superseding commit does not carry.

**Where the text is:**
- `.claude/skills/do-next-slice/SKILL.md`, step 3: the `**`claude-design`**` sentence run inside the step-3 paragraph.
- `.claude/skills/do-whole-phase/SKILL.md` L30–33: the `**`claude-design`**` block under the co-work bullet.

**What `design-cowork` says** (the authority):
- The loop diagram under `### Under claude-design` (~L146–160) routes **feedback first**: `feedback.md` → a new round folder in the same slice → handoff → push → PENDING #1 again.
- The read-back gates only approval and the mockup go-ahead (~L864–865): "(Under `claude-design`, once the read-back has passed and the record has landed.)"
- The superseding commit (~L206–208) carries the superseded round's `feedback.md` and the new `handoff.md`. It carries no `output/`.

## Fix

1. **Reorder both drivers' claude-design branch** so that on the operator's return you **branch on their words first**:
   - **Anything else is feedback:** write their words verbatim into the round's `feedback.md`, which marks it superseded. **No read-back and no landing**: a superseded round keeps only its `handoff.md` and `feedback.md`, read-only. Then:
     - open the next `NN-slug` round in the same slice, inheriting the addressed cards;
     - write its handoff;
     - commit (the superseded round's `feedback.md` and the new `handoff.md` together) and push once for the round;
     - STOP at PENDING #1 again.
   - **Literal approval, no mockup requested:**
     - **Read back inline with `DesignSync`**: never handed to an executor. It needs the claude.ai login, so it fails under `ocx claude` and in a subagent.
     - Land the record as `output/` and run the card and concreteness checks.
     - A failure is reported as exactly those points, the slice goes `pending`, and you STOP with nothing signed.
     - On a pass: the SIGNOFF entry, the remote regroup, `finish-slice`, commit.
   - **Mockup requested** (their go-ahead): the same read-back, landing and checks gate it, with the same failure stop. Then:
     - commit the landed record and dispatch the mockup span;
     - commit and STOP at PENDING #2;
     - on their literal approval: the SIGNOFF entry, regroup, `finish-slice`, commit.

   Keep the commit counts (**two without a mockup, four with one**; one more commit, push and stop per superseding round) and every other clause: the per-round push, no `design-open`, no drafter, no mirroring.

   Keep each driver as compact as it is now: move clauses, don't add prose. `do-next-slice`'s resume and invocation counts stay.
2. **The PENDING #1 report wording** in `do-next-slice`, and in `do-whole-phase`'s "Report each window" line if it carries the claude-design variant, stays as is. It already says approval signs "once the read-back passes".
3. **Nit, the Never line.** `design-cowork`'s claude-design Never line on mockup timing (~L1216) is looser than `## The mockup` (~L773–774). Align its trigger with `## The mockup`'s wording: the mockup is built only on the operator's go-ahead after the read-back has passed and the record has landed.
4. **Nit, both executor bodies, L60.** Where the refusal/mockup clause says "drafted record" in a sentence that also covers claude-design, make it "drafted (or, under `claude-design`, landed) record", or an equally short tool-neutral phrasing.
   - Both bodies must stay **word-for-word identical** there; diff them.
   - Leave the L33 bundle nit alone.
5. **Finding #3, notebook only.**
   - Add to `## Decisions`: "Under claude-design, a missing DesignSync (no claude.ai login, `ocx claude`) stops the slice `pending`; never fall back to the drafter mid-round (P27.S2)".
   - Append to `## Doc impact`: `- decisions.md: under claude-design, one git push per round (none over a local-dir connection), superseding rounds in the same slice (feedback.md marks superseded, a root SIGNOFF.md entry marks signed), and a missing DesignSync stops pending, never falling back to the drafter mid-round (P27.S2)`.
   - F3 may already have recorded the operator's "one push per round" answer in `## Decisions`. Don't duplicate it.

**Smoke.** If a driver pin reads the old ordering, update it. Add **one** pin per driver: in the claude-design branch, "feedback" appears before "DesignSync". Or a simpler presence pin such as "No read-back and no landing" if the ordering check is awkward. Expect 202 PASS after F3 plus any new passes, 0 FAIL.

## Ship and validate

- `python3 installer/build.py`, then `--check`.
- `bash tests/retrofit_smoke.sh`, **alone in its Bash call**, in the foreground. If a `SyntaxError: Non-UTF-8 code` appears, F3's cookie did not hold: stop and report it, never reword around it.
- `python3 scripts/workflow.py validate`.
- `wc -c CLAUDE.md` is unchanged (not touched).

## Notebook

Record the decision and doc-impact lines above, and rewrite `## Now` for F2.

## Also (reconciled after F3)

- **v48 changelog.** F3 fixed the installer and left `WORKSPACE_VERSION` alone. v48 is still unreleased, so add one bullet to the existing `## v48` entry in `CHANGELOG.md`: "the installer's stdin program now declares utf-8 (PEP 263), so the Mac's system Python 3.9 can no longer reject it when a multibyte character lands on a read-chunk boundary". This is not a version bump.
- **Smoke baseline** after F3: 202 PASS.
