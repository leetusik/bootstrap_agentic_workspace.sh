# P12.S5 — PR + CI layer, agent-driven integration

_Auto-mode plan. Context: `phase.md` §Decomposition (S5 row), §Settled Decisions → S1–S4 (binding:
the `execution` block, the `parallel-start/-status/-gate/-merge-finish/-consolidated/-teardown`
family and their exact flags), §Constraints, §Open Questions (the two S5-owned decisions). The
orchestrator pre-researched the installer with a read-only agent; its verified findings are folded
in below — re-verify line references before editing, files may have drifted._

## Goal

The CI layer plus everything the agent-driven integration (intent amendment 2) needs from the
engine/installer side. After S5: every push/PR runs `validate` in CI, `phase/*` PRs get the
quiet-point gate server-side, and the installer ships CI + `.gitattributes` to adopting
workspaces. The integration *sequence* itself (push → PR → gate → merge → merge-finish →
consolidation) becomes skill text in S6 — see Decision 1.

## Decisions S5 settles (record in `phase.md` §Settled Decisions)

1. **Skill-guided `gh`, no engine wrapper.** The orchestrator runs `gh` directly per the S6 skill;
   workflow.py gets no `gh` subcommand. Rationale: `gh` output/auth/error handling is agent
   territory, the engine stays offline-testable, and `parallel-gate` (S3) is already the shared
   engine-side check that both CI and the agent run before merging.
2. **One generic CI workflow, embedded seed-once; `.gitattributes` embedded with an idempotent
   line-merge.** `.github/workflows/workspace-ci.yml` works unchanged in the upstream repo and in
   adopting workspaces (shell-conditional steps for upstream-only checks). Update/retrofit policy:
   CI file is created when absent, never overwritten (executors.toml precedent — adopters
   customize CI); `.gitattributes` is line-merged (the `works/events.jsonl merge=union` line is
   appended if missing, existing content untouched) because a skipped file would silently lose the
   union rule on repos that already have one.
3. **Unblock the agent-driven push: the shipped `.claude/settings.json` deny list changes from
   `Bash(git push:*)` to `Bash(git push --force:*)`.** Amendment 2 requires the orchestrator to
   push phase branches and drive `gh`; a blanket deny blocks that outright (no prompt). With the
   deny narrowed, pushes and `gh` go through the normal interactive permission prompt — the
   operator still approves each one; nothing is pre-allowed. Existing adopters keep their old deny
   (settings merge is additive — a deny can never be removed downstream): the CHANGELOG migration
   note must say "remove `Bash(git push:*)` from `.claude/settings.json` by hand if you adopt
   agent-driven parallel integration".

## Implementation

### 1. `.github/workflows/workspace-ci.yml` (new)

- `on: push` + `on: pull_request` (all branches).
- **Job `validate`:** checkout, `python3 scripts/workflow.py validate`.
- **Upstream-only steps** (same job, shell-guarded `if [ -f installer/build.py ]`):
  `python3 installer/build.py --check` and `bash tests/retrofit_smoke.sh`. An adopting workspace
  has no `installer/` → steps no-op.
- **Job `parallel-gate`** (only `pull_request` whose head ref matches `phase/*`): checkout with
  `fetch-depth: 0`, derive `<P>` from the branch name (`phase/P<N>-<slug>` → `P<N>`), run
  `python3 scripts/workflow.py parallel-gate <P> --branch-ref <head-sha-or-ref> --main-ref
  origin/<base>`. `GATE CLOSED` → nonzero → red check. (Whether that blocks merge is the repo's
  branch-protection choice; the agent-side flow treats a red check as stop-and-report.)
- Keep it plain: ubuntu-latest, no external actions beyond `actions/checkout`, ASCII, no secrets.
- Validate the YAML at least by `python3 -c "import yaml; yaml.safe_load(...)"` (PyYAML is
  available locally; if not, fall back to careful structural review + `git show` of the file). CI
  cannot be executed in this slice (never push) — say so in result.md; the first real run happens
  when the operator (or a future parallel flow) pushes.

### 2. Installer embedding (both new files reach fresh installs, retrofits, AND updates)

Pre-researched mechanics — re-verify against the live files:

- `installer/build.py` `FIXED_LIVE_FILES` (~L42): add `".github/workflows/workspace-ci.yml"` and
  `".gitattributes"` (payload embedding only; emission is separate).
- `installer/main.py`:
  - Explicit emit calls in the write block (~L458-491) — **but not plain `_atomic_write` for
    either**: route both through the new policy helpers so fresh installs into a repo that already
    has a `.gitattributes` or its own CI don't clobber them (`.github`/`.gitattributes` are
    already in `EMPTY_OK_ALLOWLIST`, so such targets are legal fresh-install destinations):
    CI → write-if-absent; `.gitattributes` → line-merge helper (append the union line if absent;
    create the file when missing), used on install, retrofit, and update alike.
  - `_update_handle` (~L242-290): without an explicit branch both files fall to the final
    `preserved` case and **never reach existing adopters** — add the seed-once branch (CI, beside
    the executors.toml one at ~L280-285) and the line-merge branch (`.gitattributes`). Do NOT
    extend `_is_machinery` (neither file is overwrite-always).
  - `MANAGED_FILES`: add **neither** file (a GitHub-created repo with an existing workflow or
    `.gitattributes` must not abort the install; the policy helpers handle coexistence).
  - `WORKSPACE_VERSION` 23 → **24** (~L38).
- `CHANGELOG.md`: new top entry `## v24 — <today>`: CI workflow + `.gitattributes` shipping and
  their policies, the settings deny narrowing, and the **Migration notes** (hand-remove the old
  `git push` deny to adopt agent-driven integration; existing `.gitattributes` gains the union
  line automatically on update).
- `.githooks/pre-commit` (~L8): extend the staged-path regex with `^\.github/` and
  `^\.gitattributes$` so edits to either force the artifact-parity check.
- `installer/README.md` source-of-truth list (~L64-73): add both files with their policy.
- `tests/retrofit_smoke.sh`: update the assertions the new behavior touches — Test 1's
  exact-modification list (retrofit now also creates/merges `.gitattributes` and creates the CI
  file when absent), Test 5 (fresh-install presence), Test 6 (live-vs-embedded diff loop covers
  the two new payloads). Keep the suite's size/shape; adjust, don't expand beyond what the new
  files require.

### 3. `.claude/settings.json` (live + embedded)

Replace `"Bash(git push:*)"` in `deny` with `"Bash(git push --force:*)"`. Leave `rm -rf` deny and
the allow list untouched. (This file is in `FIXED_LIVE_FILES`; the rebuild picks it up.)

## Validation (lean; scratchpad harness, temp dirs; NEVER push, NEVER commit the real repo)

1. **Installer matrix smoke** (temp dirs, run the freshly built artifact):
   - fresh install into an empty dir → both files present, union line in `.gitattributes`;
   - fresh install into a git-repo dir that already has a custom `.gitattributes` + its own
     workflow file → both preserved, union line appended, no abort;
   - `--update` on a v23-shaped workspace missing both → both appear, `workspace_version` → 24;
     run `--update` again → idempotent (no changes); hand-edit the CI file, `--update` → preserved;
   - retrofit into a repo with existing `.gitattributes` → merged, not replaced.
2. `bash tests/retrofit_smoke.sh` — all tests pass with the updated assertions.
3. YAML parse check of the workflow; grep the derived-`<P>` logic against `parallel-start`'s real
   branch format (S2: `phase/P<N>-<slug>`, underscores, ≤40 chars).
4. Real tree: `python3 scripts/workflow.py validate` + `next` unchanged; `python3
   installer/build.py` + `--check` pass; `git config core.hooksPath` note — verify the new regex
   by running the hook script directly with a fake staged list if practical, else eyeball.
5. Re-run the S3 smoke (`smoke_s3.py`) once — it exercises merge-finish paths that S5 must not
   have disturbed (S5 touches no workflow.py logic; this is a cheap regression proof).

## Boundaries

Executor: no commits in the REAL repo (temp dirs fine), no pushes anywhere, no status
transitions, no `doc-new-version`, no other slice's `plan.md`. Write `result.md`; append the three
settled decisions to `phase.md` §Settled Decisions and Doc Impact notes (likely `operations` — CI
+ what adopters receive; `decisions` — skill-guided gh, seed-once CI, the narrowed push deny and
its additive-merge consequence).
