# Result — P27.REVIEW (review)

- **status:** done
- **tier:** high
- **review_verdict:** `pass`
- **summary:** This re-review follows P27.F3, P27.F1 and P27.F2. All three first-pass findings and both nits are closed, and every slice validates together: smoke 203 PASS / 0 FAIL, `--check` OK, `validate` OK, `CLAUDE.md` 12,280 B. The live engine check and the fresh install also pass. F3 did real work: HEAD's installer with the cookie removed fails to install on this Mac's Python 3.9.6. The Doc impact list had no qa.md line for P27's smoke additions, so I appended one. Two non-blocking deferred-job candidates are listed below.
- **files_changed:**
  - `works/phases/active/P27/slices/P27.REVIEW/result.md`: this re-review on top, the first pass kept below it.
  - `works/phases/active/P27/phase.md`:
    - one `## Doc impact` line appended (qa.md);
    - the consumed F1/F2 → REVIEW note removed from `## Notes for later slices`;
    - `## Now` rewritten.
  - No source edited.
- **validation:**
  - `bash tests/retrofit_smoke.sh`, run alone in the foreground: **203 PASS, 0 FAIL**, exit 0, `ALL RETROFIT SMOKE TESTS PASSED`, and no `Non-UTF-8` line. PASS
  - `python3 installer/build.py --check`: `OK … in sync`. PASS
  - `python3 scripts/workflow.py validate`: `Workflow validation passed.` It printed only the three warnings that were already there (P26 consolidation owed, stale docs, oversized sections). PASS
  - `wc -c CLAUDE.md`: **12,280** (cap 12,288). No diff since `942ee3c`. PASS
  - Live engine check on scratch copies of changple_web, vocky and Mijual: `design-migrate` dry run and `--apply`, `design-check`, `design-init`, `design-open` and `design-register` (with a scratch registry and `AGENTIC_DESIGN_DECK_URL`). PASS
  - `design-migrate` moves the same things as before F2: the pre-F2 (`98d6d50`) and HEAD engines give identical dry runs on all three design.json-less roots and identical trees after `--apply`. On the design.json-present root they differ by the `tokens.css` listing line only. PASS
  - Fresh install of the rebuilt artifact into scratch (exit 0, `validate` passes):
    - `design-cowork` ships `DesignSync` in `allowed-tools`;
    - `design-drafter`'s `tools:` has no `DesignSync`;
    - `workspace_version` is 48 and `design-migrate` is in `--help`;
    - the drivers, executors, `design-cowork`, `workflow.py` and `CLAUDE.md` are byte-identical to the repo's.

    PASS
  - F3's 3.9 sweep, re-run on `design-cowork/SKILL.md` at HEAD with k = 0…95 and a real rebuild for each k:
    - with the cookie: **0 / 96** fail;
    - with the cookie removed from a scratch copy: **52 / 96** fail, k = 0 included.

    PASS
  - F1's ordering pin, checked both ways: `False` on `942ee3c` for both drivers, `True` at HEAD. PASS
  - Executor bodies: L33/L60 are identical between mid and high, and the only whole-file difference is the frontmatter `name`, `description` and `model`. PASS
- **deviations:** I followed `plan.md`, with three additions:
  1. **An end-to-end install with the cookie removed, plus a parse-only check of each fix commit's artifact without it** (scratch). The install exits 1 with `SyntaxError: Non-UTF-8 code … but no encoding declared`, and F2's commit is the first that fails, which proves the cookie is load-bearing at HEAD, not just in the sweep.
  2. **Four edge probes of F2's detector**, cases E–H below.
  3. **I appended the missing qa.md `## Doc impact` line myself instead of opening a fix slice.** It is bookkeeping, and the P21 and P15 reviews did the same on a pass. It is named here so the orchestrator can overrule it.
- **doc_versions:** none — deferred to a docs phase
- **walkthrough:** none (gate waived: `acceptance.required: false`)
- **explain:** not written — run /explain for this phase

## Re-review after P27.F3, P27.F1 and P27.F2

The boundary is unchanged: `phase-scope P27` is `fe9ef30..e94c902`, 7 commits, and the same 14 product files. The fix commits touched 10 of them: both executor bodies, `design-cowork`, both drivers, `CHANGELOG.md`, `installer/main.py`, `scripts/workflow.py`, `tests/retrofit_smoke.sh` and the rebuilt artifact. `CLAUDE.md`, `create-phase`, both READMEs and `docs/retrofit-guide.md` were not touched after `942ee3c`.

### 1. Finding 1 (claude-design feedback read back first) is closed
- **Both drivers now branch on the operator's words first.**
  - `do-next-slice` step 3 and the `do-whole-phase` claude-design block both open the resume with "branch on their words first".
  - **Feedback** comes first. The words go verbatim into `feedback.md`, with "No read-back and no landing: the superseded round keeps only its `handoff.md` and `feedback.md`, read-only". The next round opens in the same slice, and its handoff is committed with that `feedback.md` and pushed. Then the loop stops at PENDING #1 again, which costs one more commit, push, stop (and, in `do-next-slice`, invocation).
  - **Literal approval, no mockup:** the `DesignSync` read-back, the landing and the checks run, and a failure stops `pending` with nothing signed. "On a pass" comes the SIGNOFF entry and the regroup.
  - **Mockup requested:** "the same read-back, landing and checks gate their go-ahead".
- **The drivers agree with `design-cowork`:**
  - The *Under claude-design* diagram (L148–160) puts feedback first.
  - *Closing the round* L865–871 closes a superseded round by `feedback.md`, "keeps what it holds, read-only". Literal approval signs "once the read-back has passed and the record has landed".
  - The superseding commit (L206–208) carries only `feedback.md` and the new `handoff.md`, now matched by "committed with that `feedback.md`".
  - The commit counts ("**two commits without a mockup, four with one**") and the PENDING #1 report wording are unchanged and still match L187–204.
- **The new claude-design Never line (L1222–1224),** "before the read-back has passed, the record has landed and the operator has given their go-ahead", matches two places:
  - *The mockup* L779–780: "at their return once the record has landed";
  - *Closing* L871.

  The shared Never line keeps "(the timing is per tool, below)".
- **Executor L60** now reads "transcribes the drafted (or, under `claude-design`, landed) record" in both bodies. That agrees with the skill's "`build-prompt.md` plus the landed record" (L817–820).
- **The smoke pins it:** one ordering assert per driver (`feedback.md` before `DesignSync` in the claude-design branch). It fails on the pre-F1 text and passes at HEAD.
- **Finding 3's notebook lines are present:**
  - `## Decisions`: "A missing DesignSync stops `pending` (P27.S2)" and "Feedback is routed before the read-back under claude-design (P27.F1)".
  - `## Doc impact`: the `decisions.md` line (push per round, superseding in the same slice, the DesignSync-unavailable stop) and F1's `operations.md` line.

### 2. Finding 2 (legacy roots not steered to `design-migrate`) is closed
I re-ran the three cases on fresh scratch copies of the real design folders, using `cp -R` only. The real repos' `docs/reference/design` trees are clean.

- **A. changple_web, `design-init` first:**
  - `design-check` finds 13 problems. The first reads `design.json missing; pre-v47 record: run … design-migrate (dry run first), then design-init if this repo will use the drafter`.
  - `design-init`, `design-open` and `design-register` all refuse (rc 1) with the same steer, and the tree is unchanged.
  - `design-migrate --apply` moves `README.md`, `SIGNOFF.md`, `rounds` and **`tokens.css`** into `claude-design/`, byte-identical. The first review's silent-`tokens.css` path is closed.
  - Then `design-check` shows the plain `design.json missing (run: … design-init)`, `design-init` writes the manifest, and `design-check` is OK.
- **B. vocky, a claude-design round started before migrating:** `design-migrate --apply` refuses with `claude-design/rounds already exists; a claude-design round was started first -- move each legacy round into claude-design/rounds/ by hand, renumbering after the existing ones, remove the emptied rounds/, then re-run`. Nothing moves. F2's log shows the remedy followed literally and succeeding.
- **C. Mijual, a plain legacy root (drafter path):**
  - Before migrating: `design-check` finds 53 problems with the steer first, and `design-init`, `design-open` and `design-register` all refuse with the steer.
  - `--apply` leaves the `claude-design/` tree byte-identical to the pre-move root, and a second `--apply` reports `nothing to migrate`.
  - `design-check` shows the plain design.json-missing hint, then `design-init` writes the manifest, `design-check` is OK, and `design-open --slug coexist` opens `rounds/01-coexist`.
  - `design-register` with `AGENTIC_DESIGN_DECK_URL` set prints the URL and the outside-folder warning. The idempotent re-run with it unset prints the "set $AGENTIC_DESIGN_DECK_URL" line.
- **What `design-migrate` moves did not change.**
  - On all three design.json-less roots, the pre-F2 engine (`98d6d50`, which equals `942ee3c`) and HEAD print identical dry runs (4, 2 and 4 moves) and leave identical trees after `--apply`.
  - With a hand-written `design.json` (changple_web, 13 moves), the dry runs differ only by the added `left in place … tokens.css (kept as schema 1's tokens.css; …)` line.
  - The refactor of the design.json branch onto `design_legacy_record` keeps the same set and the same order of moves.
- **The skill** says to migrate first in three places:
  - the drafter's `design-init` bullet (L337–339);
  - the claude-design handoff bullet (L360–362), "so the numbering continues from the old rounds";
  - the migration paragraph (L688–691).

  Each is labelled for its tool, so governance is unaffected.
- **F2's stated consequence is correct and not a finding.** The consequence: a root with a stray root `SIGNOFF.md` or `grounding/` gets `design-init` refused until it is migrated. Three reasons:
  1. **The refusal is narrow.** It fires only when there is **no `design.json`**. Case G, a schema-1 root *with* `design.json` and a stray root `SIGNOFF.md`, is not refused, and `design-check` is OK.
  2. **The files are legacy by construction.** Schema 1 writes `SIGNOFF.md` per round and has no root `grounding/`, since grounding is a round. So those entries in a root that has not yet run `design-init` can only be the old layout, or a hand-placed file that the dry run lists before anything moves.
  3. **The way out is non-destructive and always open.** Case F (a lone root `SIGNOFF.md`) runs `design-migrate --apply` and then `design-init`. The mixed-root carve-out, case E of F2's log, keeps `design-init` open where `design-migrate` itself asks for it, so they cannot deadlock.

### 3. F3 (the installer's 3.9 stdin trap) is fixed
- **The cookie is line 1 of the program.** Artifact L86 is `python3 - <<'INSTALLER_PY'`, and L87 is `# -*- coding: utf-8 -*-` (`installer/main.py` line 1). `installer/build.py` is unchanged since `942ee3c`, so D3's trigger did not fire.
- **The Test 7 pin exists.** The smoke prints "PASS: the installer's stdin program starts with the utf-8 coding cookie".
- **Spot sweep (scratch copies of HEAD, F3's `sweep_rebuild.py`, `/usr/bin/python3` 3.9.6, a real rebuild per k):**
  - with the cookie: `design-cowork/SKILL.md` fails for **0 of 96** values of k (k = 0…95);
  - the same copy with the cookie removed: **52 of 96** fail, **k = 0 included**, so HEAD's program as it stands fails without the cookie.
- **Per commit** (parse-only, `parse_nocookie.py`, cookie line stripped):
  - `942ee3c`, `c11ae52` and `98d6d50` parse;
  - **`e94c902` (F2) fails** on program line 68, the `do-next-slice` payload.

  F2 did not edit that payload. The chunk boundaries evidently depend on more than the line itself, most likely the tokenizer's buffer, which the longer payloads F2 did edit (`design-cowork`, `workflow.py`) size first. This is what the first review predicted when it put F3 first.
- **End-to-end:** the cookie-less HEAD artifact, run through `sh` into scratch, exits 1 with `Non-UTF-8 code starting with '\xe2' … on line 68` and installs nothing. The real artifact installs cleanly (the fresh install above ran on the same 3.9.6). Without F3, F2's commit would have shipped an installer that fails on this Mac.

### 4. No regression from the fixes
- **Governance:**
  - *Implementing* + *Verifying* are still byte-identical to `fe9ef30` (172 lines, `cmp`).
  - The fix edits to `design-cowork` are all tool-labelled lines: two handoff bullets, the claude-design record's migration paragraph and the claude-design Never line.
  - No shared governance line changed, and the drafter text in both drivers is unchanged (the word-diff touches only the claude-design runs).
- **`CLAUDE.md`:** untouched since `942ee3c` (12,280 B). The first pass's line-by-line judgment stands.
- **Executors:** L33/L60 are identical in the two bodies. The only change is F1's L60 clause, and the L33 bundle nit was left as the plan said.
- **The CHANGELOG `## v48` entry is coherent.**
  - F2 amended the `design-migrate` bullet (the three commands name it, `design-init` refuses, run it before the first `claude-design/rounds/`) and Migration note (3), "only after the migration".
  - F1 added the installer-cookie bullet.
  - `WORKSPACE_VERSION` stays 48, which is right, since F3 changes no shipped file. The smoke's version and Migration-notes checks pass.
- **Engine:**
  - `design_legacy_record` and `design_legacy_hint` add refusals and message text only. No path writes or moves anything new.
  - `design-migrate` is still all-or-nothing with rollback, never deletes, runs no git (no `subprocess`), and its refusals still come before the first move.
  - The scan skip for `claude-design/` is unchanged.

### Non-blocking notes (inside the boundary, no fix slice)
- **N1: in design.json mode, `design-migrate` merges beside an already-started claude-design round without a numbering check.**
  - Case E: vocky with a `design.json` and a `claude-design/rounds/01-new` created before migrating. The dry run would move `rounds/01-brand-app-landing` and `rounds/02-onboarding` in beside `01-new`, giving two `01-` rounds with no refusal.
  - The design.json-less path refuses and names the remedy (case B), but this path only refuses a same-name collision.
  - **Why it does not block:**
    - Nothing is lost, and nothing in the engine or design-deck reads `claude-design/`.
    - Reaching it takes a `design.json` on a legacy root, which only a v47 `design-init` run before F2 could create. None of the surveyed legacy repos has one, and F2's refusal prevents new ones.
    - It also takes ignoring the skill's migrate-first line.
  - It is a deferred-job candidate below.
- **The claude-design path's migrate-first guard is the skill's text, and the drivers don't carry it.** No engine command runs on that path, so an orchestrator reading only the driver's compact branch could create `claude-design/rounds/01-…` in an unmigrated root. The backstop is `design-migrate`'s refusal with the by-hand remedy (case B), and nothing is lost. F2's plan chose to leave the drivers alone. The drivers defer to `design-cowork` (*Under claude-design*), which carries the line, so I accept it as is.
- **In design.json mode, `design-register` does not steer.** On a root with `design.json` and legacy rounds (case D), it registers without the steer, because it only validates the manifest. `design-check` and `design-open` both name `design-migrate` there, so the orchestrator meets the steer on every path that uses the rounds.
- **The `design-init` argparse help** does not mention its new refusal. F2 did this on purpose to keep D21's trigger unfired. The refusal message is self-explanatory. It is worth adding to D21's scope when that job runs (see routing).

### Doc impact: complete, after one appended line
- **F1–F3's operations and decisions changes are covered:**
  - F3: operations (cookie);
  - F1: decisions (the S2 claude-design rules) and operations (feedback first);
  - F2: operations (the steer).

  The first pass's lines for S1–S3 still stand.
- **The gap:** no line recorded P27's smoke changes for qa.md, although P26 set the convention of an itemized qa line per smoke change and qa.md's *Test Commands* tracks the baseline. The changes:
  - the baseline moved 195 → 203;
  - the Test 7 cookie pin;
  - the F2 steer probe;
  - the F1 driver ordering assert;
  - the Python 3.9 trap as a known fragile area.

  S3's qa line names the choice pins and the Test 13 probes, but no count and nothing on Test 7. qa.md was already owed for P27, so it would have been consolidated anyway, but the list did not itemize these. **I appended one line** (`phase.md` `## Doc impact`, the last entry): baseline 203/0 with the +6/+1/+1 breakdown, the Test 0 ordering assert, and the fragile-area note, tagged with its slices and "recorded at P27.REVIEW".
- **Docs owed at the docs phase for P27:** operations, decisions, architecture and qa (plus P26's four).

### Operator Questions: all 3 routed, none new
1. **(P27.DECOMP) D18, D20, D21, D23 and D24: fold in or leave deferred?** This is still a decision to relay. **Recommendation: left deferred**, with the operator told which triggers have now fired:
   - **D20** "Pin the never-rule floor in smoke" fired at S3. `CLAUDE.md` is 8 B under its cap and was verified by hand twice now. Take it first.
   - **D18** "Slim the slice-executor bodies" fired at S3 and **again at F1** (the L60 content edit).
   - **D23** "Fix the doc-new-version skill's --source example" fired at S1–S3 and **again at F1/F2** (skill edits).
   - **D21** "Correct two stale one-line descriptions" fired at S1 (the `design-migrate` argparse help). F2 did not fire it again. Addendum for whoever runs it: `design-init`'s help line could mention its pre-v47 refusal.
   - **D24** "Correct README drift" fired at S3, and not again.
   - **D3** "Make installer/build.py smoke-execute the assembled artifact" **did not fire**: `build.py` was untouched and no broken artifact reached a commit. It stays the structural guard beyond the cookie, because it would catch any stdin-execution failure, not just this one.
2. **(P27.S2) Pushes per claude-design slice.** **Routed and answered** by the operator on 2026-09-30: once per round, with its handoff commit (a superseding round's included), and none over a local-dir connection. It is recorded in `## Decisions`, and the skill, both drivers and the `decisions.md` Doc impact line agree.
3. **(P27.S3) The installer stdin trap.** **Routed and answered** by the operator on 2026-09-30: "Fix now as P27.F3". The fix landed and is verified above. No deferred job is filed for it.

No slice after the first pass added an `## Operator Questions` entry.

### Deferred-job candidates (the orchestrator files them; I ran no `defer-job`)
- **"Point `design-drafter` at the `claude-design/` record as design memory"** (still valid, outside the boundary).
  - *Reason:* `design-drafter.md` Inputs §3 reads prior rounds' `SIGNOFF.md`, `feedback.md` and `result.md` "under `rounds/`" only. P27 did not change that file. In a repo that designed with claude-design before, the signed history in `claude-design/SIGNOFF.md` and `claude-design/rounds/*/output/` is invisible to the drafter unless the handoff's *Where to look* names it.
  - *Trigger:* the first `drafter` phase in a repo that holds a `claude-design/` record, or the next edit to `design-drafter.md`.
- **"`design-migrate`: refuse or flag a round-number collision with an existing `claude-design/rounds/` in design.json mode"** (N1).
  - *Reason:* with a `design.json`, legacy rounds merge in beside rounds already created under `claude-design/rounds/`, and duplicate `NN` prefixes pass silently (case E). The design.json-less path refuses with a remedy.
  - *Trigger:* the next edit to `design-migrate`, or the first repo found with a `design.json` on a legacy root.

### Observations (outside the boundary; not findings)
- The Claude Design project id ("target the project by id") still has no durable home. It was restored as-is from `7ecd381^`, so it is not a regression.
- design-deck's side (verifying it ignores `claude-design/`) stays with the note in `phase.md` for a later design-deck phase.

### Notebook cross-check
- **Decisions:** every decision in `slices/P27.F3/result.md`, `P27.F1/result.md` and `P27.F2/result.md` is in `## Decisions`:
  - F3: the cookie, spelled utf-8, no bump, `build.py` untouched;
  - F1: feedback first, the S2 DesignSync stop, the confirmed push;
  - F2: the detector, the hint, the `design-init` refusal, the `tokens.css` listing, the remedy, moves unchanged, migrate-first in the skill, drivers untouched.

  F2's "no argparse help edit" is a deliberate scope choice. It is recorded in its `result.md` and in the D21 addendum above.
- **Operator Questions:** all three are routed above.
- **`phase.md` edits:**
  - `## Doc impact`: +1 qa line (append-only kept).
  - `## Notes for later slices`: the consumed "(from P27.F1 and P27.F2, for the re-run REVIEW)" note is removed. The design-deck note stays.
  - `## Now`: rewritten.
  - Nothing else changed.

### Live-check log (scratch: `…/scratchpad/p27rereview/`)
- **Scripts:**
  - `setup.sh`: `cp -R` of the three real design folders, with the HEAD or pre-F2 engine.
  - `moves.sh`: pre-F2 vs HEAD dry runs.
  - `cases.sh`: post-apply trees and cases A–C, plus register.
  - `edges.sh`: cases D–H.
  - `sweep_rebuild.py`: F3's, copied.
  - `parse_nocookie.py`: a per-commit parse check (`art_<sha>.sh`).
- **Outputs:** `dry-{old,new}-*.txt`, `out_cookie.txt` / `out_nocookie.txt`, `e2e_nocookie.log`, `fresh_install.log`.
- **Edge cases:**
  - **D:** changple_web + `design.json`. `design-check`'s first `round.json missing` line carries the steer. `design-open` refuses with it. `design-register` succeeds (see notes).
  - **E:** vocky + `design.json` + `claude-design/rounds/01-new`. The dry run would merge `01-brand-app-landing` and `02-onboarding` beside `01-new` (N1).
  - **F:** no `design.json` and a lone root `SIGNOFF.md`. `design-check` and `design-init` steer, and `design-migrate` would move only it.
  - **G:** `design.json` + a stray root `SIGNOFF.md`. `design-check` is OK, `design-init` is not refused, and `design-migrate` would move it.
  - **H:** no design root. `design-init` writes the manifest (unaffected).
- **Isolation:**
  - `~/.config/agentic-workspace/`: listed and `stat`-ed before and after, identical (empty). Every run set `HOME` and `AGENTIC_DESIGN_REGISTRY` to scratch.
  - `git status -- docs/reference/design` in vocky, Mijual and changple_web: clean.
  - The workspace repo's `git status` shows only the `works/` files the orchestrator had already modified, plus this slice's two files.
  - One stray file I wrote by mistake to `/tmp` during a section extraction was deleted at once.

---

# First pass (2026-09-30): `changes_requested`, superseded by the re-review above

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
