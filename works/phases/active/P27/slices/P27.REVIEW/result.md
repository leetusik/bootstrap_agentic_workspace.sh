# Result — P27.REVIEW (review)

- **status:** done
- **tier:** high
- **review_verdict:** `changes_requested`
- **summary:** Every slice validates together: smoke 201 PASS / 0 FAIL, `build.py --check` OK, `validate` passes, `CLAUDE.md` 12,280 B. The live engine and fresh-install checks pass, and all seven deliverables are present. Governance survived S2 (Implementing and Verifying are byte-identical to `fe9ef30`, and no restored line goes unlabelled), and `CLAUDE.md` kept every rule. Two in-boundary gaps in the claude-design path need fixing first: the drivers put a DesignSync read-back gate in front of the operator's feedback, which the skill does not do, and the legacy-migration command is not wired into the paths an orchestrator actually walks. A third, small gap: one S2 decision and its doc-impact line are missing from the notebook.
- **files_changed:** `works/phases/active/P27/slices/P27.REVIEW/result.md` (new), `works/phases/active/P27/phase.md` (`## Now`, plus the consumed S3 note in `## Notes for later slices` replaced by a note for the fix slices). No source edited.
- **validation:**
  - `bash tests/retrofit_smoke.sh` (run alone, in the foreground): **201 PASS, 0 FAIL**, `ALL RETROFIT SMOKE TESTS PASSED`. PASS
  - `python3 installer/build.py --check`: `OK … in sync`. PASS
  - `python3 scripts/workflow.py validate`: `Workflow validation passed.` The three warnings were already there (P26 consolidation owed, stale docs, oversized sections). PASS
  - `wc -c CLAUDE.md`: **12,280** (cap 12,288). PASS
  - Live engine check on scratch copies of vocky and Mijual (`design-migrate` dry, `--apply`, `design-check`, `design-init`, `design-register`, `design-open`): PASS, details below
  - Fresh install of the rebuilt installer into scratch: `design-cowork` ships `DesignSync` in `allowed-tools`; `design-drafter`'s `tools:` has no `DesignSync`; `workspace_version` is 48; `design-migrate` is in `--help`. PASS
- **deviations:** none from `plan.md`. Beyond the plan's letter, I ran two extra checks:
  - a CPython 3.9 fragility sweep of the installer body (scratch only);
  - a read-only `ls` / `stat` of `~/.config/agentic-workspace/` before and after the register runs, to prove it was untouched. Nothing was written there.
- **doc_versions:** none — deferred to a docs phase
- **walkthrough:** none (gate waived: `acceptance.required: false`)
- **explain:** not written — run /explain for this phase

## Findings (inside the boundary)

### 1. The drivers put a read-back gate in front of claude-design feedback, which the skill does not do
- **What the skill says.** In `design-cowork`, the *Under claude-design* loop routes **feedback before the read-back**. Its diagram at L149–155 puts the feedback branch first. *Closing the round* L864–865 needs the read-back only for literal approval: "(Under `claude-design`, once the read-back has passed and the record has landed.)"
- **What the drivers say.** Both do the read-back first, on every return:
  - `do-next-slice` step 3: "On the **resume**, read back inline with `DesignSync` …, land the returned record as the round's `output/`, and run the card and concreteness checks — a failure is reported …, set the slice `pending` again, STOP without signing. Then, by their words: …"
  - `do-whole-phase` has the same text in its claude-design branch.
- **Consequence.** Say the operator comes back with feedback on a round whose pane is incomplete. They stopped because they want changes, so the cards are missing. The driver then stops `pending` on the card-contract points. The operator's words never reach `feedback.md` and no superseding round opens. The words live only in the session, which `do-whole-phase` may end.
- **A second, smaller mismatch.** On feedback, the drivers land `output/` into the superseded round. The skill's superseding commit (L206–208) carries only `feedback.md` and the new `handoff.md`.
- **Fix: P27.F1** (`--kind fix --risk high`, because it repairs S3's mid-tier text).
  - Both drivers branch on the operator's words first. Feedback is recorded verbatim and superseded whatever the read-back would find. The read-back, landing and both checks gate only literal approval and the mockup go-ahead.
  - Add one line saying whether a superseded round's returned artifacts are landed. If they are, the skill's superseding-commit line names them too.
  - Keep the smoke pins, rebuild, and re-run the smoke.

### 2. `design-migrate` exists but the legacy-repo paths do not lead to it
Intent item 5 says legacy repos fail `design-check` and are refused by `design-open`. The command and its docs landed (CHANGELOG, READMEs, retrofit guide, the claude-design record section). But the paths an orchestrator walks in such a repo still point elsewhere. I verified each case on scratch copies:
- **(a) The engine's hints point to `design-init`, not `design-migrate`.**
  - On a pre-v47 root, `design-check` says `design.json missing (run: … design-init)` plus `round.json missing`. After `design-init`, `design-open` refuses with "…no well-formed round.json (run design-check)". Neither names `design-migrate` (vocky copy).
  - The order changes the result. Follow the hint on changple_web's copy (`design-init` first, then `design-migrate`) and the legacy root `tokens.css` silently stays as schema 1's `tokens.css`. It is not moved and not even listed as left in place, because it is in the design.json-mode `schema1` set. Migrating first moves it into `claude-design/`.
  - The intent says `design-init` runs only after migration, and only if the repo will use the drafter.
- **(b) The claude-design loop has no "migrate first" step.** The handoff step creates `claude-design/rounds/<NN-slug>/` "numbered after the highest one there". In an unmigrated legacy repo that restarts at `01` beside the legacy `rounds/01…NN`. `design-migrate` then refuses with `claude-design/rounds already exists` and the operator has to merge by hand (vocky copy, `live-vocky3`). The migration paragraph sits in the record section, which only binds under claude-design, and it is not a precondition anywhere in the loop or the drivers.
- **Fix: P27.F2** (`--kind fix --risk low`; bump it to `high` if the plan changes what `design-migrate` moves, since that touches a core invariant).
  - **Engine:** when the root holds a pre-v47 record (a `rounds/` entry without `round.json` and no `design.json`, or a root `SIGNOFF.md` beside non-schema-1 rounds), `design-check` and `design-open` name `design-migrate`, dry run first, ahead of `design-init`. Optionally, in design.json mode, `design-migrate` lists a kept root `tokens.css` when it moves legacy rounds.
  - **Skill:** the claude-design handoff bullet and the drafter's `design-init` bullet say to migrate a pre-v47 root record first, and why.
  - Add a smoke probe, rebuild, and re-run the smoke.

### 3. The notebook is missing one S2 decision and its doc-impact line
- `slices/P27.S2/result.md`, under *Additions beyond the plan's letter*, settles that "when `DesignSync` is not available in the session, stop `pending` … never fall back to the drafter mid-round", from "fixed per phase, never switched mid-round". It is in the skill and the CHANGELOG but not in `phase.md` `## Decisions`.
- `## Doc impact` has no `decisions.md` line for the claude-design specifics that are now durable rules:
  - one push per round (none over a local-dir connection);
  - superseding rounds in the same slice, where `feedback.md` marks a round superseded and a root `SIGNOFF.md` entry marks it signed;
  - the DesignSync-unavailable stop.

  The S3 `decisions.md` line covers the choice, the skipped folder and "C wins" only.
- **Fix: fold into P27.F1.** Add the decision line to `## Decisions` and append `- decisions.md: under claude-design, one git push per round (none over a local-dir connection), superseding rounds in the same slice (feedback.md marks superseded, a root SIGNOFF.md entry marks signed), and a missing DesignSync stops pending, never falling back to the drafter mid-round (P27.S2)`. Update the push clause if the operator overrides it (question 2 below).

### Nits (non-blocking; fold into F1 only if convenient)
- In the skill's claude-design *Never*, "Author a mockup **before the round has come back**" (L1216) is looser than *The mockup*'s timing ("at their return once the record has landed", L773–774). The shared Never line ("or one before the round is ready for it") still covers it.
- The executor L60 says the mockup span "transcribes the drafted record". Under claude-design it is the landed record.
- The executor L33 names `output/result.md` and `build-prompt.md`, while the skill allows "the bundle's own [contract] when it brought one" (L675–676). The orchestrator's `plan.md` names the real paths, so this is harmless.

## Judgment by the plan's points

1. **Intent coverage: all seven deliverables are present and coherent,** with gaps 1 and 2 above.
   - **(1) The choice:** `create-phase` L29 and L57–61; both drivers read `Design tool:`; absent means `drafter`.
   - **(2) Both loops** are in `design-cowork`, with `DesignSync` in `allowed-tools`.
   - **(3) `claude-design/`** is skipped by `design_scan` (the only recursive walk, L3275–3278; `cards/` and `rounds/` are root-level `iterdir`). Verified live: Mijual's 53 problems (52 besides `design.json missing`, stray `output/**/*.html` included) drop to that one once the record is under `claude-design/`, and to 0 after `design-init`. design-deck ignores the folder by construction: its `designdeck/contract.py` reads only `root/cards` and `root/rounds` (read-only look).
   - **(4)** The contract, both executors, both drivers, both READMEs, the retrofit guide, the banner and the smoke choice pins.
   - **(5) `design-migrate`**, with the wiring gap (finding 2).
   - **(6) The register hint:** the URL when set, the outside-folder warning, never a guess.
   - **(7) v48:** `WORKSPACE_VERSION` 48, the CHANGELOG entry with the P26.F1/F2 re-sync note naming design-deck, and the rebuilt artifact.
2. **Governance invariant: holds.**
   - Implementing and Verifying: `C == N` byte for byte (and `O == C`).
   - Word-diffs of Shape, The mockup, Closing and Never against `fe9ef30` show only tool labels and per-tool branches. Every C prohibition survives, either shared or in a tool list: "signed" is kept, O139–142, O306 and O251 are not restored, and the smoke negatives pin them.
   - Every `DesignSync`, `Connect GitHub`, `_ds_manifest`, `register_assets` and `finalize_plan` mention sits under a claude-design heading or label.
3. **The claude-design loop, end to end:**
   - The handoff lives in a new `claude-design/rounds/<NN-slug>/`, and there is one push per round.
   - PENDING #1: the skill and both drivers say the same thing.
   - The read-back is `list_files` against the numbered paths, then `_ds_manifest`, then concreteness.
   - Landing goes to `output/`. SIGNOFF is the root entry. The remote regroup is line 1 only, through `finalize_plan`.
   - Superseding: a new round folder in the same slice.
   - The mockup span dispatches from `build-prompt.md` plus the landed record.
   - Commits are 2/4 in the skill and both drivers.
   - Gaps: the feedback ordering (finding 1) and the legacy precondition (finding 2b). Also observed but restored as-is from O: nothing records the Claude Design project id that "target the project by id" needs.
4. **`CLAUDE.md`:** 9 lines changed, and no rule or never-rule was lost.
   - L15 and L52 gained the claude-design clauses.
   - The tightenings are meaning-neutral: "on product visual design work", "clears the same item to `in_progress`", "invocation and sharp edges", the githooks sentence, and "never pre-planned until its input lands".
   - Two small losses, both acceptable:
     - "`docs/index.json` (version history)" lost its reason, but the rule stays.
     - "(a requested throwaway mockup excepted)" drops "the one", but `design-cowork` keeps "the one exception".
   - L52 keeps the smoke-pinned blanket "The design subagent drafts, the operator decides:" and qualifies it at the end of the sentence with both tools. The "Never push without being asked" line is unchanged, and the per-round push is authorized only by the skill, exactly as at `7ecd381^`.
5. **Engine safety: holds.**
   - `design-migrate` runs every check before the first move and refuses with the full problem list.
   - On an `OSError` it rolls back in reverse and removes only the folders it created (S1 proved this with an `EACCES` probe).
   - It never deletes: the only removal is `rmdir` of an emptied `rounds/`, and an existing destination is refused with `lexists` rather than overwritten. It has no `subprocess` and runs no git.
   - Live, on vocky and Mijual: every file is byte-identical under `claude-design/` (tree hash), a second `--apply` prints `nothing to migrate`, and the real repos' tree hashes did not change.
   - `design-init`, then `design-check` OK, then `design-open` opened a drafter round `01` beside `claude-design/rounds/01…18`, so the two records coexist.
   - `design-register` with a scratch `AGENTIC_DESIGN_REGISTRY`: the URL is printed when set, the "set $AGENTIC_DESIGN_DECK_URL" line appears otherwise, the outside warning follows `DECK_PROJECTS_DIR`, and both the write path and the early-return path print the hint.
6. **The installer tokenizer trap: real and measured, but not a P27 finding.** Details below.
7. **Doc impact:** the list covers operations (S1, S2, S3), decisions, architecture and qa. The one gap is finding 3.
8. **Operator Questions:** all 3 are routed below.

## The installer tokenizer trap (point 6)

- **Reproduced** on `/usr/bin/python3` 3.9.6 (the only `python3` on this Mac). Reading a program from stdin fails when a 3-byte `—` has its lead byte at line offset 1021 or 1022, and passes at 1019, 1020, 1023 and 1024.
- **Measured fragility of today's artifact.** I inserted k ASCII bytes (k = 0…1023) at the start of one payload and let 3.9 parse the whole body from stdin. Nothing ran: `raise SystemExit(0)` sat after the `__future__` import. Failures by payload:
  - `design-cowork/SKILL.md`: **453 / 1024 (44%)**;
  - `slice-executor-high.md`: **194 / 1024 (19%)**;
  - `scripts/workflow.py`: 23 / 1024 (2%);
  - `do-next-slice/SKILL.md`: 0 / 1024.

  So an edit of arbitrary length to the design skill breaks the macOS system-Python install roughly half the time.
- **Guards.** `build.py` only `compile()`s the body in-process, which is not the stdin path. The pre-commit hook runs only `--check`. CI runs the smoke on `ubuntu-latest`, whose newer Python probably does not reproduce it (not verified). **Only a local smoke run on a 3.9 Mac catches it.**
- **Three fixes, measured or structural:**
  - A PEP 263 cookie `# -*- coding: utf-8 -*-` as line 1 of `installer/main.py`, which is the body's first line. I measured **0 / 2048** failures across the two worst payloads. It needs no `build.py` edit, so D3's trigger does not fire.
  - ASCII-escape the embedded strings in `build.py` (`!a` / `ascii()` in `_dict_literal` and `CONTRACT_BODY`). The artifact becomes pure ASCII.
  - Feed the body to Python from a temp file instead of stdin.

  Pair any of them with D3 (the build smoke-executes the artifact) to get a real guard.
- **Not a P27 finding.** The artifact P27 shipped works (smoke plus a fresh install). The trap is in `build.py`'s `repr()` embedding, which is older than this phase and outside `phase-scope`. S3's 3-byte rewording is recorded honestly as luck.
- **Recommendation:** fold it into P27 now as a fix slice **ordered before F1 and F2**. Both of those edit exactly the most exposed payloads (`design-cowork`, the drivers, `workflow.py`), and without it they have a real chance of needing another luck-based rewording. Suggested: `P27.F3`, "Make the installer body immune to the 3.9 stdin-tokenizer chunk trap", `--kind fix --risk high` (wide blast radius: every install and `/update-workspace` runs the artifact), placed ahead of F1 with a fractional `--order`. If the operator declines, file it as the deferred job below.

## Operator Question routing (all 3 routed)

1. **(P27.DECOMP) Deferred jobs D18, D20, D21, D23 and D24, whose triggers fired in P27.** This is a decision to relay. Recommendation: **leave them deferred** (the phase kept to its seven deliverables), but tell the operator the triggers have now fired, so each is due at the next matching edit:
   - **D20** "Pin the never-rule floor in smoke" matters most. `CLAUDE.md` is now 8 B under its cap, and this review had to verify rule preservation by hand.
   - D18, D21, D23 and D24 are cosmetic or cost-only.
2. **(P27.S2) How many pushes a claude-design slice gets.** This is a decision to relay. Recommendation: **confirm S2's "once per round, with its handoff commit (a superseding round's included); none over a local-dir connection".** A superseding round lives in the same slice, and over Connect GitHub its handoff reaches Claude Design only after a push. "One per slice" would force a local-dir connection or a pasted handoff for every revision. Whatever the answer, finding 3's `decisions.md` line records it.
3. **(P27.S3) The installer stdin-tokenizer trap.** This is a decision to relay. Recommendation: **fold it into P27 as `P27.F3`, ordered first** (see above), because the two fix slices edit the payloads that fail 44% and 19% of the time. The default otherwise is to defer it: file the deferred job below.

## Deferred-job candidates (outside the boundary; the orchestrator files them, I ran no `defer-job`)

- **Only if question 3 is answered "defer":** "Make the installer body immune to the CPython 3.9 stdin-tokenizer chunk trap".
  - *Reason:* `build.py` embeds each payload as one long UTF-8 line read from stdin. 3.9 rejects the program when a multibyte character straddles an fgets chunk. The measured break rate of an arbitrary edit is 44% (`design-cowork`) and 19% (`slice-executor-high`). Only a local 3.9 smoke catches it, not `--check`, the pre-commit hook or CI. The fixes are a PEP 263 cookie on `main.py` line 1 (measured 0/2048), `ascii()` embedding in `build.py`, or a temp-file feed; see D3.
  - *Trigger:* the next edit to any embedded file (effectively the next machinery phase), or the first smoke failure with `Non-UTF-8 code starting with`.
- **"Point `design-drafter` at the `claude-design/` record as design memory".**
  - *Reason:* the drafter reads prior rounds only under `rounds/` (`design-drafter.md` L19–20). In a repo that designed with claude-design before, the signed history in `claude-design/SIGNOFF.md` is invisible to it unless the handoff's *Where to look* names it.
  - *Trigger:* the first `drafter` phase in a repo that holds a `claude-design/` record.

## Observations (outside the boundary; not findings)

- The design-deck note in `phase.md` (for a later design-deck phase) is backed by a read-only look: `designdeck/contract.py` `list_cards` / `list_rounds` read only `root/cards` and `root/rounds`. That phase needs just a test.
- The Claude Design project id ("target the project by id") has no durable home. It was restored as-is from `7ecd381^`, so this is not a regression.

## Live-check log (scratch: `…/scratchpad/p27review/`)

- **vocky:**
  - Before: `design-check` finds 3 problems.
  - Dry run: `SIGNOFF.md` and `rounds` would move, exit 0, tree hash unchanged (`289385a6…`).
  - `--apply`: both moved; the `claude-design/` tree hash equals the pre-move hash; the closing line carries the `design-init` hint.
  - `design-check`: 1 problem (`design.json missing`). A second `--apply` prints `nothing to migrate`.
- **Mijual:**
  - Before: 53 problems.
  - Dry run: `README.md`, `SIGNOFF.md`, `grounding` and `rounds`; tree unchanged (`1af1fc95…`).
  - `--apply`: byte-identical. `design-check`: 1 problem. Then `design-init`, `design-check` OK, and `design-open --slug coexist` opened `rounds/01-coexist`.
  - Register (scratch registry):
    - URL `http://100.64.0.9:8765/` plus the outside warning (`~/projects`);
    - the idempotent path with `DECK_PROJECTS_DIR=<scratch>` gives no warning;
    - with no URL, the "set $AGENTIC_DESIGN_DECK_URL" line.
- The real vocky and Mijual design trees were only read (`cp -R`). `~/.config/agentic-workspace/` was only listed and `stat`-ed, identical before and after.
- **Finding 2 probes:**
  - `live-vocky2`: `design-init` on the legacy copy, then `design-open`, refused without naming `design-migrate`.
  - `live-vocky3`: with a `claude-design/rounds/01-new` created before migrating, `design-migrate` refused (`claude-design/rounds already exists`).
  - `live-cweb`: `design-init` first, then a dry run leaves `tokens.css` unlisted at the root.
- **Fresh install:** `fresh1` via `sh …/bootstrap_agentic_workspace.sh <scratch> --name Fresh --summary fresh`, exit 0, "Workflow validation passed", banner names both tools.
- **Sweep scripts:** `sweep.py` and `sweep_cookie.py` in the scratch folder.

## Slices' validation re-run

- **S1, S2, S3:** smoke, `build.py --check` and `validate`, all above. S3's `diff` of executor L33/L60 is identical, and `wc -c CLAUDE.md` is 12,280.
- **DECOMP:** `validate`.

## Notebook cross-check

- **Decisions.** Every `result.md` decision is in `## Decisions` except S2's DesignSync-unavailable stop (finding 3). S1's deviations 1–5 are behaviour details of the recorded rule, not new decisions.
- **Operator Questions.** All three are routed above.
- **`phase.md` edit.** `## Now` was rewritten. In `## Notes for later slices`, the consumed S3→REVIEW note was replaced by a short REVIEW→fix-slices note: the pins to keep, the executor mirror, the `CLAUDE.md` headroom and the installer trap. No other section changed.
