# Result — P4.REVIEW (phase review)

- Phase ID: P4
- Slice ID: P4.REVIEW
- Kind: review
- Review verdict: **pass**
- Next action: orchestrator records the verdict via `review-phase P4 --verdict pass --reviewer slice-executor`, then commits.

## Verdict

**PASS.** All three intent jobs are delivered, every slice's `result.md` is
consistent with its `plan.md` (deviations reasoned), workflow hard rules are
honored (no per-slice doc versions were created; tests stayed terse), and every
re-runnable validation is green. The three durable-doc versions have been
consolidated (below).

## Validation (all slices together, re-run at review)

1. **Build determinism** — `python3 installer/build.py` twice → two consecutive
   outputs byte-identical (`cmp` clean). PASS.
2. **Drift guard** — `python3 installer/build.py --check` → "OK: … in sync with
   installer/ source"; rebuilding left `git status` for the artifact clean (the
   committed artifact IS the rebuilt one). PASS.
3. **Retrofit smoke** — `bash tests/retrofit_smoke.sh` → ALL RETROFIT SMOKE TESTS
   PASSED (all 7 blocks): retrofit ×4, foreign-workflow abort, docs-gating,
   fresh-install regression incl. `fresh marker carries workspace_version` +
   effort split (base `xhigh`, `-high` `high`) + `phase-reviewer` absent + Codex
   `do-whole-phase` dropped, dual-apply parity (incl. both agent defs +
   `CLAUDE.md`/`AGENTS.md`), and Test 7 drift check. PASS.
4. **Model-pin grep sweep** (`.claude/ .agents/ .codex/ CLAUDE.md AGENTS.md
   README.md scripts/ installer/ tests/`): no `model: opus`; no `opus` at all in
   live machinery; no "on `opus`" / "on `gpt-5.5`" prose. Every `gpt-5.5`/`GPT-5.5`
   occurrence is one of — the scoped-out Codex toml pins
   (`.codex/agents/slice-executor{,-high}.toml:3`), the `.codex/config.toml:8-9`
   comment describing those tomls, or an explicit example inside rule text
   (Commit Convention `CLAUDE.md`/`AGENTS.md:96` + both explain `SKILL.md`
   mirrors). Executor defs confirmed `model: inherit`; `effort:` lines intact
   (`xhigh` / `high`). PASS.
5. **End-to-end current-artifact check** — fresh-installed the committed artifact
   into a temp git repo → `works/.workspace-version.json` carries
   `"workspace_version": 1`; target `python3 scripts/workflow.py validate` passed;
   `--update --dry-run` from the same artifact over it → "machinery updated: 0
   file(s)". PASS.
6. **CHANGELOG + mirrors** — root `CHANGELOG.md` exists with a `## v1` entry and
   is **absent** from the built artifact (grep of the artifact for the CHANGELOG
   body = 0; `WORKSPACE_VERSION = 1` and `"workspace_version": WORKSPACE_VERSION`
   ARE embedded, so the constant rides the artifact while the changelog stays
   repo-only). Both `/update-workspace` mirrors' bodies byte-identical below
   frontmatter; frontmatter differs only by the 2 extra `.claude` lines
   (`allowed-tools`, `disable-model-invocation`). PASS.
7. **Repo state integrity** — `python3 scripts/workflow.py validate` →
   "Workflow validation passed." PASS.

(S1's one-time old-vs-new byte-equivalence proofs for all three install modes
stand as recorded evidence in `P4.S1/result.md` and were not re-derived against
the now-changed HEAD, per the plan.)

## Judgement per intent job

- **Job 1 — model-flexible attribution.** Delivered. Executor defs are
  `model: inherit`; attribution is rule-first ("attribute each commit to the model
  that actually did the work") with `GPT-5.5` only as an example; prose is
  model-neutral; the Codex toml `model = "gpt-5.5"` pin is intentionally kept
  (Codex needs an explicit model). Matches the intent Job-1 scope exactly.
- **Job 2 — installer split.** Delivered. `bootstrap_agentic_workspace.sh` is a
  single committed distributable at repo root, assembled from `installer/`
  (`build.py`/`wrapper.sh`/`main.py`/`payloads/`); `curl … | sh` contract intact;
  all three modes byte-identical (S1 proof + review re-check); live files are the
  source of truth; drift guard wired into `build.py --check` and smoke Test 7.
- **Job 3 — CHANGELOG + integer versioning.** Delivered. `WORKSPACE_VERSION = 1`
  stamped into the marker (rides the artifact, so adopters get it without
  `installer/`); root `CHANGELOG.md` seeded with `## v1`; `/update-workspace`
  previews vN → vM reading the upstream clone's CHANGELOG, with a pre-versioning
  fallback; release rule documented in `installer/README.md`.
- **Slice consistency / hard rules.** Each `result.md` matches its `plan.md`;
  S1's three deviations (repr-literal payload encoding, P1-seed split
  code/payload, `PY`→`INSTALLER_PY` delimiter) are reasoned and do not affect
  emitted output. No per-slice `doc-new-version` was run (verified: no `P4.*`
  source in `docs/index.json` before this review). Tests stayed terse (S1: one
  Test 7 block; S3: one grep line in Test 5).

## Doc Versions Created (consolidated at review, `--source P4.REVIEW`)

- `decisions` → **v0014**: new "Model-flexible attribution, installer split into
  `installer/` (committed build product), and integer workspace versioning (phase
  P4)" decision entry; Status count bumped to eleven; two Superseded-Decisions
  notes added — the v0013 "`model: opus` is kept, not pinned" rationale is
  superseded by `model: inherit` (Fable/Mythos tier now above Opus), and the
  earlier "executor's `opus` model … unchanged" note is corrected to `inherit`.
  History was not rewritten — only new entries + supersession notes were added.
- `operations` → **v0009**: Status note (installer is a build product; workspaces
  versioned); a "Building and releasing the installer" section (edit → build →
  commit loop, drift guard, release rule, CHANGELOG repo-only); the update-path
  Provenance bullet gains `workspace_version` + a version-aware-preview bullet
  (vN → vM read from the upstream clone's CHANGELOG, pre-versioning fallback).
- `architecture` → **v0002**: repo-shape list gains `installer/`, the generated
  `bootstrap_agentic_workspace.sh`, repo-only `CHANGELOG.md`, and the
  `works/.workspace-version.json` marker fields; a new "Installer Source Tree"
  section documents `build.py`/`wrapper.sh`/`main.py`/`payloads/`, the
  live-files-as-source-of-truth rule, runtime-derived skill sets, and the
  byte-identity + drift-guard invariant.

`python3 scripts/workflow.py rebuild-docs` run once at the end; `docs/current/`
now shows decisions v0014, operations v0009, architecture v0002; `validate` green.

## Deviations from Plan

- The first `doc-new-version` for `operations` produced a filename long enough
  that the editor's atomic temp-rename overflowed the 255-byte filename limit. I
  surgically removed that over-long version (reset `operations.latest` back to
  v0008, dropped the just-added entry, deleted the file) and re-ran
  `doc-new-version` with a terse summary — final id
  `v0009_installer_is_a_build_product_version-aware_update_flow_release_rule`.
  Content is unchanged from what the plan called for; only the summary slug is
  shorter. No other deviations.

## Files Changed

- `docs/versions/decisions/v0014_installer_split_into_installer_committed_build_product_drift_guard_executor_model_inherit_rule-based_commit_attribution_supersedes_v0013_opus-alias_rationale_integer_workspace_versioning_root_changelog_release_policy.md` (new)
- `docs/versions/operations/v0009_installer_is_a_build_product_version-aware_update_flow_release_rule.md` (new)
- `docs/versions/architecture/v0002_installer_source_tree_assembles_the_committed_single-file_distributable.md` (new)
- `docs/index.json` (new version entries; via `doc-new-version` + `rebuild-docs`)
- `docs/current/{decisions,operations,architecture}.md` (regenerated by `rebuild-docs`)
- `works/phases/active/P4/slices/P4.REVIEW/result.md` (this file)
- `works/phases/active/P4/phase.md` (review note appended; Doc impact items marked consolidated)

## Roadmap Updates

- None. P4 is complete pending the orchestrator recording the `pass` verdict.

## Retrospective

- The strongest signals were re-runnable and cheap: the drift guard (`build.py
  --check` + smoke Test 7) plus the model-pin grep sweep together prove the
  live-files-as-source-of-truth invariant and the model-neutral goal hold on the
  current HEAD, without re-deriving S1's expensive tree diffs. The one snag —
  an over-long generated doc-version filename — is a reminder to keep
  `doc-new-version --summary` terse (the slug becomes the filename).
