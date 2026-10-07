# Plan — P29.REVIEW (phase review, acceptance gate REQUIRED)

**Tier:** high (review, by kind). Review P29 against its objective and `works/phases/active/P29/intent.md`, the confirmed intent, which is the yardstick. Read `phase.md` in full: `## Decisions` (decisions 1–9, the "Final flag shape (P29.S1)" block and the S2 texts block), `## Doc impact`, `## Operator Questions` and `## Notes for later slices`. Also read the three slice `result.md` files.

## Boundary

`python3 scripts/workflow.py phase-scope P29` gives the range `1518a5f..HEAD` and 10 product files:

- the `retrofit` and `update-workspace` skills
- `CHANGELOG.md`
- `README.md` and `README.en.md`
- `bootstrap_agentic_workspace.sh`
- `installer/README.md`, `installer/main.py` and `installer/wrapper.sh`
- `tests/retrofit_smoke.sh`

Review **only** this boundary. Anything outside it is an observation, never a finding, and comes back as a deferred-job candidate.

## 1. Validate all slices together

1. `python3 installer/build.py --check` must pass.
2. `python3 scripts/workflow.py validate` must pass.
3. **The smoke suite, run exactly once, as the only command in its own foreground Bash call:** `sh tests/retrofit_smoke.sh`. The S1 baseline was 235 PASS / 0 FAIL, and S2 changed only `WORKSPACE_VERSION` and texts. Report the totals.

## 2. Judge against the intent

Check each point of the confirmed intent against the code, by reading `resolve_layout()`, `nested_preflight` / `nested_init_host`, the init undo, and the convention written for a freshly initialised host:

- Nested is the default everywhere, including a fresh directory, which gets `git init`.
- At-root is reached only with `--at-root` or `--into-existing`.
- `--nested` is a harmless no-op.
- `--update` detects the layout, and `/update-workspace` needs no `--nested`.
- Existing at-root installs keep updating at-root, with no migration.
- The release is v50.

Then:
- **Decision 6, at-root byte-identical behind `--at-root`.** Spot-check it yourself. Run v49's artifact (`git show 1518a5f:bootstrap_agentic_workspace.sh`) with no flag and the current artifact with `--at-root`, both into fresh scratch directories, and diff the trees, ignoring timestamps and version stamps. Do the same for `--update` on one at-root fixture.
- **S1's five recorded deviations.** Judge each one.

## 3. Gate stages: open the running product yourself

The product is the installer CLI, so the "running product" is the built `bootstrap_agentic_workspace.sh` run in scratch directories under the session scratchpad or `mktemp -d`. Never run it against a real repo, and never against this checkout except the read-only refusal probe. Don't pass on the slices' reports alone. Walk through the following as a first-time user, reading every banner and hint for clarity and accuracy:

1. A bare install into a new, non-existent directory. Then, from that host root:
   - `python3 workflow/scripts/workflow.py next`, which should show no UNCONFIRMED;
   - `git status --porcelain --untracked-files=all`, which should be empty;
   - the banner's first-commit steps.
2. A bare install into a scratch git repo with one commit. Its convention should be inferred and unconfirmed, and the host status should stay clean.
3. A bare `--update` and `--update --dry-run` on each of those, then `--update --nested` (the v49 form).
4. `--at-root` into a fresh directory, then a bare install over it, which should refuse with the "use --update" advice, and a bare `--update` on it, which should stay at-root.
5. The refusals, each writing nothing:
   - a non-empty non-git directory;
   - a nested install's `workflow/`;
   - `--at-root --nested`;
   - `--force-empty-ok` without `--at-root`;
   - a new directory inside another repo's work tree;
   - a bare install on this upstream checkout, with `git status` checked before and after.
6. **Texts against behaviour.** Read the changed sections of both READMEs, `docs/retrofit-guide.md`, `installer/README.md`, the two skills, the wrapper's `--help` and CHANGELOG v50 against what steps 1–5 actually printed. A text that claims a behaviour the installer doesn't have is a finding.

**Regression Checklist.** In `docs/current/qa.md` `## Regression Checklist`, re-run **only** the lines whose surface one of the 10 boundary files feeds: the installer, install and update modes, the nested install, the smoke suite. Never re-run the whole list. Append this phase's headline checks as new lines, following the section's own format: the nested default, `--at-root`, update detection, and the bare-install-over-at-root refusal. That is one of the review's two gate-section writes, done with `doc-new-version --doc qa` → edit only the returned `edit_path` → `rebuild-docs`. `## Operator Runtime` needs no change, because the runtime is the CLI.

**Route every `## Operator Questions` entry.** There is one: whether a new directory inside another repo's work tree should keep refusing or should auto-init. Put it in the walkthrough as a decision for the operator, with S1's reasoning and your recommendation.

## 4. Verdict

- **On a pass:**
  - Verify that `## Doc impact` is complete for what the phase changed. Return `doc_versions: none — deferred to a docs phase`, apart from the qa gate-section version above.
  - Return the `explain: not written — run /explain for this phase` pointer.
  - Return a **`walkthrough`**: a short, copy-pasteable sequence of scratch commands the operator can run in about five minutes to see the nested default, the initialised host, update detection, `--at-root` and one refusal, with what each should print. Then the operator question.
- **On a non-pass:** finish the whole validation and judgement first. Then return numbered findings with proposed fix slices (name, kind `fix`, risk: `high` for a defect in S1's work, since S1 ran on high and a retry never goes down; S2's was mid, so a fix to S2's text is `high` too) and skip the pass-only steps.
- **Either way:** list out-of-boundary observations as deferred-job candidates. Include S1's note: an at-root `--update` on a non-existent path creates an empty directory before it errors.

Write `result.md` with the verdict block first: `review_verdict`, `walkthrough`, `doc_versions`, `explain`, and the deferred candidates. Edit `phase.md` `## Now`. Don't commit, don't run `review-phase`, `accept-gate` or `set-*-status`, and edit no product source.
