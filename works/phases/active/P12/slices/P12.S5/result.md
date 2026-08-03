# P12.S5 — PR + CI layer, agent-driven integration (result)

Status: **done**. All three plan decisions implemented as written; no engine (`scripts/workflow.py`)
change was needed — Decision 1 is precisely the decision *not* to add one.

## What landed

### 1. `.github/workflows/workspace-ci.yml` (new, 76 lines, ASCII)

One generic workflow, valid upstream and in any adopting workspace:

- `on: push` + `on: pull_request` (all branches).
- **Job `validate`** (`ubuntu-latest`, `actions/checkout@v4` only): `python3 scripts/workflow.py
  validate`, then two **shell-guarded upstream-only** steps — `if [ -f installer/build.py ]` →
  `python3 installer/build.py --check`, and `if [ -f tests/retrofit_smoke.sh ]` → `bash
  tests/retrofit_smoke.sh`. An adopting repo has neither and prints a skip line instead.
- **Job `parallel-gate`**, gated by
  `if: github.event_name == 'pull_request' && startsWith(github.head_ref, 'phase/')`. It checks out
  **the PR head sha** (`ref: ${{ github.event.pull_request.head.sha }}`, `fetch-depth: 0`) rather
  than the default PR *merge* commit — the gate must read the phase branch's own `phase.json`, and
  a merge commit would blend main's stale copy in. It derives `<P>` from the branch name with
  `sed -n 's|^phase/\(P[0-9][0-9]*\)-.*$|\1|p'` (S2's `phase/P<N>-<slug>` format; a non-matching
  head ref exits 0 with a note), makes sure `origin/<base>` exists (`git fetch --no-tags … || true`,
  belt-and-braces on top of `fetch-depth: 0`), then runs
  `python3 scripts/workflow.py parallel-gate "$phase" --branch-ref HEAD --main-ref "origin/$BASE_REF"`.
  `GATE CLOSED` exits 1 → red check.

Two notes for the record:
- **CI itself was not executed in this slice** — the boundaries forbid pushing, so nothing ran on
  GitHub. The first real run happens when the operator (or a parallel flow) pushes. Everything below
  is local verification of the file's syntax, the derivation logic and the commands it invokes.
- `--branch-ref HEAD` + `--main-ref origin/<base>` is exactly the CI shape `parallel-gate` was built
  for in S3: passing `--main-ref` explicitly avoids the "this checkout *is* the phase branch"
  refusal (detached at the branch tip), which is what a PR checkout looks like.

### 2. Installer embedding (fresh install + retrofit + `--update`, all three)

- `installer/build.py`: `FIXED_LIVE_FILES` gains `.github/workflows/workspace-ci.yml` and
  `.gitattributes` (payload embedding; emission is separate). Module docstring source list updated.
- `installer/main.py`: new **`emit_policy_files()`** section (with `CI_WORKFLOW_PATH`,
  `GITATTRIBUTES_PATH`, `GITATTRIBUTES_MERGE_LINE`, `_gitattributes_action()`,
  `_apply_gitattributes()`), called once from the write block after `.codex/config.toml`:
  - **CI = seed-once** — written only when absent, never overwritten (the `executors.toml`
    precedent); adopters own their CI.
  - **`.gitattributes` = line-merge** — `works/events.jsonl merge=union` appended (with a short
    explanatory comment block) only when the file does not already carry that exact line; existing
    content is never rewritten; the file is created verbatim from the payload when missing.
  - Both policies are honored under `--update` and `--dry-run` (which writes nothing but still
    reports), and they record into `UPDATE_SUMMARY` / `RETROFIT_SUMMARY` so the change list is
    truthful.
- `WORKSPACE_VERSION` 23 → **24**; `CHANGELOG.md` gains the `## v24 — 2026-08-03` entry with
  **Migration notes**.
- `.githooks/pre-commit`: staged-path regex extended with `\.github/` and `\.gitattributes$`.
- `installer/README.md`: both files added to the source-of-truth list with their policy, plus a
  paragraph on why they bypass `write_text` and stay out of `MANAGED_FILES`.
- `tests/retrofit_smoke.sh`: assertions updated (details below).
- Rebuilt `bootstrap_agentic_workspace.sh` is included in this slice's changes.

**Deliberate non-changes** (all per plan, all re-verified against the live files):
- `MANAGED_FILES` gets **neither** file — a GitHub-created repo that already has `.gitattributes` or
  its own workflow must not trip the fresh-install conflict guard. Both names are already in
  `EMPTY_OK_ALLOWLIST`, so such a target is a legal fresh-install destination, and the two policies
  handle coexistence (verified: matrix case A).
- `_is_machinery()` untouched — neither file is overwrite-always.
- `scripts/workflow.py` untouched — no `gh` subcommand (Decision 1).

### 3. `.claude/settings.json` deny narrowed

`"Bash(git push:*)"` → `"Bash(git push --force:*)"` in the live file; the rebuild carries it into the
distributable. `rm -rf` deny and the allow list are untouched. Consequence recorded in the CHANGELOG
migration notes: settings merge is additive, so **existing adopters keep the old blanket deny and
must remove it by hand** to adopt agent-driven integration.

## Validation

Everything ran locally, in temp dirs; the real repo was never committed and nothing was pushed
anywhere.

| # | Command | Outcome |
|---|---|---|
| 1 | `python3 installer/build.py` then `… --check` | PASS — `wrote bootstrap_agentic_workspace.sh (342685 bytes)`, then `OK: … in sync with installer/ source` |
| 2 | `bash tests/retrofit_smoke.sh` | PASS — `ALL RETROFIT SMOKE TESTS PASSED` (8 tests, incl. the 9 new/updated assertions), ~2.1 s |
| 3 | `bash <scratchpad>/smoke_s5.sh` (installer matrix, temp dirs) | PASS — `ALL S5 MATRIX CHECKS PASSED` (26 checks) |
| 4 | YAML parse: PyYAML (`/opt/homebrew/bin/python3.10`) + `ruby -ryaml` | PASS both — 2 jobs (`validate`, `parallel-gate`), triggers `push` + `pull_request`; file is pure ASCII (`grep -c '[^ -~\t]'` → 0) |
| 5 | `<P>` derivation vs. S2's real branch format | PASS — `phase/P13-parallel_phase_execution`→`P13`, `phase/P2-second_phase`→`P2`, `phase/P100-x`→`P100`; `feature/foo`, `phase/PX-y`, `phase/P7` → empty (job exits 0 with a note) |
| 6 | Real tree: `python3 scripts/workflow.py validate` / `next` | PASS — `Workflow validation passed.`; `next` unchanged (`current_phase=P12 current_slice=P12.S5 next_slice=P12.S6`) |
| 7 | pre-commit regex + parity coupling | PASS — regex matches `.github/workflows/workspace-ci.yml` and `.gitattributes`, not `.gitattributes.bak`/`tests/…`/`docs/…`; and in a throwaway copy of the tree, editing either live file makes `installer/build.py --check` fail (`<scratchpad>/drift_check_s5.sh`) |
| 8 | S3 regression: `python3 smoke_s3.py` | PASS — `SMOKE PASSED (49 checks)` (gate → merge-finish → consolidated → teardown → archive chain untouched) |

`smoke_s5.sh` matrix coverage (all in `mktemp -d` dirs):

- **A** fresh install into a git repo that already has a custom `.gitattributes`, an unrelated
  workflow, **and** its own `workspace-ci.yml` → no abort, their CI byte-identical (seed-once),
  their attribute rules kept, union rule appended exactly once, workspace validates.
- **B** fresh install into an empty dir → both files created, CI byte-identical to the live file,
  union rule present, install output mentions CI.
- **C** `--update` matrix on a v23-shaped workspace missing the CI file with a foreign
  `.gitattributes`: `--dry-run` writes nothing but lists the CI file → real `--update` seeds CI +
  line-merges attributes and reports `merged (additive): .gitattributes` → `workspace_version` is
  **24** → re-running `--update` is byte-idempotent for both → a hand-edited CI file survives the
  next `--update` → workspace still validates.
- **D** retrofit into a repo whose `.gitattributes` already carries the union rule → file untouched
  (sha-identical), CI seeded.

`tests/retrofit_smoke.sh` changes (adjusted, not expanded): Test 1's sample repo now ships its own
`.gitattributes` (`*.py text`), so the exact-modification assertion becomes the 4-file list
`.claude/settings.json,.gitattributes,AGENTS.md,CLAUDE.md,` (`sort` pinned to `LC_ALL=C`) plus three
new checks (their rule preserved, exactly one union rule, CI seeded); Test 5 asserts fresh-install
presence of both files and adds the `--update` seed-once/line-merge/idempotence/hand-edit block
(restoring both files verbatim at the end so Test 6 can diff them); Test 6's dual-apply loop covers
the two new payloads.

## Deviations from `plan.md`

1. **Policy emission is one helper called directly from the write block, not new branches inside
   `_update_handle` / `_retrofit_handle`.** The plan sketched "explicit emit calls + a seed-once
   branch and a line-merge branch in `_update_handle`". Both files bypass `write_text` entirely via
   `emit_policy_files()` instead, so the policy is defined **once** and provably applies to fresh
   install, retrofit and update alike (three separate branches could drift apart). Same observable
   behavior, verified in every mode by matrix cases A–D; both `_update_handle` and the update-policy
   comment block point at `emit_policy_files()` so the bypass is discoverable.
2. **The CI job checks out the PR head sha**, not the plain default checkout the plan's
   "checkout with `fetch-depth: 0`" implies. `actions/checkout` defaults to the PR *merge* commit on
   `pull_request`, whose `works/` content is a blend of both sides — the gate must read the branch's
   own state. `--branch-ref HEAD` then means the phase branch tip, as intended.
3. **Test 1 gained a `.gitattributes` in its sample repo** (one line) rather than the plan's "update
   the exact-modification list": that is what makes retrofit's line-merge path (the interesting
   case) run inside the existing test, and the modification list is updated accordingly. No new test
   file, no new sample repo.
4. **PyYAML is not installed for the default `python3`** here; the parse check ran on
   `/opt/homebrew/bin/python3.10` (PyYAML 6.0.1) and was cross-checked with `ruby -ryaml`. The
   plan's fallback was not needed.
5. One extra line was added to the fresh-install output naming the CI file and `.gitattributes`
   (user-facing discoverability; not in the plan, no behavior change).

## Doc impact (appended to `phase.md`, not versioned here)

- `operations` — what the workspace now ships for CI and what adopters receive/must do.
- `decisions` — skill-guided `gh` (no engine wrapper), seed-once CI + line-merged `.gitattributes`,
  and the narrowed push deny with its additive-merge consequence.
