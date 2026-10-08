# Result — P27.F1 (fix / high)

- **status:** done
- **tier:** high
- **summary:** Both drivers now branch on the operator's words first under claude-design. Feedback goes verbatim into `feedback.md` with no read-back and no landing. The `DesignSync` read-back, the `output/` landing and the checks gate only literal approval and the mockup go-ahead. Also folded in: finding 3 (the S2 DesignSync decision and the `decisions.md` Doc impact line), both nits (the claude-design Never mockup trigger, executor L60), a smoke ordering pin per driver and the v48 CHANGELOG bullet for F3. Smoke 202/0.
- **files_changed:**
  - `.claude/skills/do-next-slice/SKILL.md` (step 3, the claude-design sentence run)
  - `.claude/skills/do-whole-phase/SKILL.md` (L30–33, the claude-design block)
  - `.claude/skills/design-cowork/SKILL.md` (L1216–1218, the claude-design Never mockup line)
  - `.claude/agents/slice-executor-mid.md` and `.claude/agents/slice-executor-high.md` (L60, identical)
  - `tests/retrofit_smoke.sh` (one ordering pin in the driver loop)
  - `CHANGELOG.md` (one bullet in `## v48`)
  - `bootstrap_agentic_workspace.sh` (rebuilt)
  - `works/phases/active/P27/phase.md` (`## Decisions`, `## Doc impact`, `## Notes for later slices`, `## Now`)
  - `works/phases/active/P27/slices/P27.F1/result.md` (new)
- **validation:**
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: `OK … in sync`. PASS
  - `bash tests/retrofit_smoke.sh`, run alone in the foreground, twice (the second run after the final `design-cowork` wording): **202 PASS, 0 FAIL**, `ALL RETROFIT SMOKE TESTS PASSED`, no `Non-UTF-8` line. PASS
  - `python3 scripts/workflow.py validate`: `Workflow validation passed.` Only the three warnings that were already there (P26 consolidation owed, stale docs, oversized sections). PASS
  - `wc -c CLAUDE.md`: 12,280, no diff (not touched). PASS
  - `diff` of executor L60 and L33 between the mid and high bodies: identical. The whole-file diff is only the frontmatter name, description and model. PASS
  - Ordering pin proven both ways: on `HEAD`'s driver text it is `False` for both drivers, and on the edited text `True` for both. PASS
- **deviations:**
  - The smoke pin is the ordering check, not the presence alternative. It sits inside the driver assertion block, so the count stays 202 (the plan allowed "plus any new passes").
  - I added one `operations.md` Doc impact line for F1's ordering beyond the plan's `decisions.md` line, because the claude-design runbook the docs phase will write describes this step.
  - I added one `## Decisions` line for F1's own ordering rule beside the S2 DesignSync line the plan asked for.
- **doc_impact:**
  - `- decisions.md: under claude-design, one git push per round (none over a local-dir connection), superseding rounds in the same slice (feedback.md marks superseded, a root SIGNOFF.md entry marks signed), and a missing DesignSync stops pending, never falling back to the drafter mid-round (P27.S2)`
  - `- operations.md: in the claude-design runbook the operator's words are routed first: feedback supersedes the round with no read-back and no landing (the round keeps only handoff.md and feedback.md), and the DesignSync read-back, landing and checks gate only literal approval and the mockup go-ahead (P27.F1)`

## What changed, and why

### 1. Both drivers: the operator's words are routed first (finding 1)

Before this fix, both drivers ran the `DesignSync` read-back, the `output/` landing and the checks on every return, and only then branched on the operator's words. So a failing read-back stopped `pending` before the feedback was recorded, and a superseded round got an `output/` that the skill's superseding commit (L206–208) does not carry.

After the fix, both drivers match `design-cowork`'s *Under claude-design* diagram (L146–160) and *Closing the round* (L864–865). Each branch now reads:
- **Feedback** is written verbatim to `feedback.md`, which marks the round superseded. "No read-back and no landing: the superseded round keeps only its `handoff.md` and `feedback.md`, read-only." The next round opens in the same slice, and its handoff is committed with that `feedback.md` and pushed. Then STOP at PENDING #1.
- **Literal approval, no mockup:** the read-back is done inline with `DesignSync`, then the landing and both checks. On a failure: `pending`, STOP, nothing signed. On a pass: SIGNOFF, the regroup, then continue (do-whole-phase also runs `finish-slice` and commits).
- **Mockup requested:** the same read-back, landing and checks gate the go-ahead, with the same stop on a failure. Then the landed record is committed, the mockup is dispatched and committed, the loop stops at PENDING #2, and SIGNOFF follows on approval.

The clauses were moved and the "then, by their words" preamble was dropped. The new words are what the plan requires:
- "branch on their words first";
- the no-read-back line;
- "committed with that `feedback.md`";
- "on a pass";
- the mockup gate clause.

Each driver grew by about 250 bytes: do-next-slice 1,344 → 1,592 B, do-whole-phase 1,309 → 1,557 B.

These are all kept:
- the commit counts (**two commits without a mockup, four with one**), and "one more commit, push, stop and invocation per superseding round";
- do-next-slice's "one `pending` stop, two invocations";
- the per-round push, no `design-open`, no drafter, no mirroring.

Plan item 2: the PENDING #1 report wording is unchanged in both drivers. It already said approval signs "once the read-back passes".

Every existing driver pin still holds:
- `**read back inline with `DesignSync`**`, the `claude-design/rounds/<NN-slug>/` path and `**two commits without a mockup, four with one**`;
- the negatives `_ds_manifest`, `never dispatched`, `four commits, two`, `one dispatched span` and `Push the branch`.

No pin read the old ordering, so none needed updating.

### 2. Smoke: one ordering pin per driver

This goes in the driver loop of `tests/retrofit_smoke.sh`, right after the negatives:

```python
cd_branch = body[body.index("**`claude-design`** (*Under claude-design*"):]
assert cd_branch.index("feedback.md") < cd_branch.index("DesignSync"), name
```

I checked it against `git show HEAD:` for both drivers (`False`, the old order) and against the working tree (`True`).

### 3. Nit: the claude-design Never line (design-cowork L1216)

The old line was "Author a mockup **before the round has come back**". It now reads "Author a mockup **before the read-back has passed, the record has landed and the operator has given their go-ahead**". That is the trigger `## The mockup` gives (L773–774, "at their return once the record has landed") and *Closing the round* gives (L864–865, "once the read-back has passed and the record has landed"). The rest of the line is unchanged, and it stays hard-wrapped under 102 columns.

### 4. Nit: executor bodies, L60

"it transcribes the drafted record" now reads "it transcribes the drafted (or, under `claude-design`, landed) record". The change is identical in both bodies. The L33 bundle nit was left alone, as the plan says. The smoke's gated `landed record` check stays satisfied, since the bodies name `claude-design`.

### 5. Finding 3, notebook only

- `## Decisions` gained two lines:
  - the plan's DesignSync line, "Under claude-design, a missing DesignSync (no claude.ai login, `ocx claude`) stops the slice `pending`; never fall back to the drafter mid-round", tagged (P27.S2);
  - an F1 line for the feedback-first rule.
- The confirmed "one push per round" line (recorded by F3's cycle) was already there, so it was not duplicated.
- `## Doc impact` gained the plan's `decisions.md` line verbatim, plus the F1 `operations.md` line (see deviations).

### 6. The v48 CHANGELOG bullet (reconciled after F3)

One bullet was added to `## v48`, before the re-sync note: "**The installer's stdin program now declares utf-8** (PEP 263), so the Mac's system Python 3.9 can no longer reject it when a multibyte character lands on a read-chunk boundary." `WORKSPACE_VERSION` is untouched (still 48). The smoke's version-agreement check and its Migration-notes check both pass.

## Notebook edits (phase.md)

- **Decisions:** the two lines above.
- **Doc impact:** the two lines above.
- **Notes for later slices:** the F3 note is retagged for F2 only, since F1 consumed its part. A new F1 note for F2 and the re-run REVIEW covers:
  - the 202 baseline, and that the pin adds no PASS line;
  - keeping the driver branch order when F2 edits the claude-design handoff bullet;
  - executor L60's new wording.
- **Now:** rewritten for F2. The open item now reads "After F2, re-run REVIEW".

## Log

- The smoke logs are in the session scratchpad (`f1_smoke.log`, `f1_smoke2.log`). Both show 202 `^PASS:` lines and 0 `^FAIL`.
- `build.py` wrote 638,232 B, then 638,241 B after the final Never wording. `--check` was OK both times.
