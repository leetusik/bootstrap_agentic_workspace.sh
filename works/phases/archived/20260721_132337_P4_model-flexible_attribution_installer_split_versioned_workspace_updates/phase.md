# Phase P4: Model-flexible attribution, installer split, versioned workspace updates

_Intent: see [intent.md](intent.md)._

## Objective

Remove hardcoded model pins from executor defs and commit-attribution text, split the monolithic installer into installer/ with a build step that emits the single committed distributable, and add CHANGELOG.md + integer workspace versioning surfaced by /update-workspace

## Context

## Decomposition

Three middle slices, sequenced **split-first** so the attribution and versioning
work lands in the new modular installer source instead of the monolith. This
matches the operator-approved guidance in `plan.md` and the cross-job note in
`intent.md`; no deviation from the proposed breakdown was needed.

- **P4.S1 — Split installer into `installer/` with build + drift check**
  (`implementation`, risk `high`, order 2). Job 2. Dissolve the 3,025-line
  self-contained `bootstrap_agentic_workspace.sh` into an `installer/` source
  tree + a build step that emits the identical-behavior single-file
  distributable at repo root (committed). Source of truth = live repo files
  (`.claude/skills/*`, `.agents/skills/*`, `scripts/workflow.py`,
  `.claude/agents/*.md`, `.codex/agents/*.toml`, `works/templates/*`,
  `.claude/settings.json`, contract text), plus `installer/`-local payloads for
  fresh-install-only seeds (the 11 `DOC_BODIES`, the P1-seed text). Build must be
  deterministic (byte-stable across runs); a drift check fails when the committed
  artifact ≠ rebuilt-from-source. All three modes (fresh, `--into-existing`,
  `--update`) stay functionally unchanged — consumers still `curl … | sh` the raw
  root file. **Goes first** because it dissolves the heredocs that S2 and S3 must
  edit; doing it first means their edits touch modular files, not the monolith,
  eliminating the double-maintenance seen in commit `fde6f46`.

- **P4.S2 — Model-flexible attribution sweep** (`implementation`, risk `low`,
  order 3, depends on S1). Job 1. `model: opus` → `model: inherit` in
  `.claude/agents/slice-executor{,-high}.md`; de-hardcode `GPT-5.5` from the
  Commit Convention (`CLAUDE.md`/`AGENTS.md` line 96) and the explain skill
  (`.claude/skills/explain/SKILL.md`, `.agents/skills/explain/SKILL.md`) — model
  names become examples, the rule becomes "attribute to the model that actually
  did the work"; make "on `opus`" / "on `gpt-5.5`" prose model-neutral
  (`CLAUDE.md`/`AGENTS.md` ~16/19/61, `README.md` ~170/246/289). The Codex toml
  keeps its explicit `model = "gpt-5.5"` (intent scopes it out; Codex needs an
  explicit model). Rebuild the distributable via S1's build. Depends on S1 so the
  wording edits land in the modular source. Risk `low` → executor runs at effort
  `high`.

- **P4.S3 — CHANGELOG + integer workspace versioning in `/update-workspace`**
  (`implementation`, risk `medium`, order 4, depends on S1). Job 3. Seed a root
  `CHANGELOG.md` (v1 = this first versioned release; earlier history noted as
  pre-versioning). Add a `WORKSPACE_VERSION` integer constant in the installer
  source, stamped as `workspace_version` into `works/.workspace-version.json` by
  `write_version_marker()` (also update this repo's own marker). Extend the
  `/update-workspace` skill (both mirrors) to report "you're on vN → upstream vM"
  plus the CHANGELOG entries in between (read from the fresh upstream clone),
  alongside the existing `--dry-run` change-list; a missing local
  `workspace_version` is treated as pre-versioning. Depends on S1 so the version
  plumbing lives in the modular source.

- **P4.REVIEW** stays last (order 9999): validates all three slices together and
  consolidates the phase's durable-doc versions (see Doc impact below).

Risk tags are deliberate — they select executor effort (`low` → `high`, else
`xhigh`). S2 and S3 both depend on S1 but not on each other; `order` still runs
them S2 then S3.

## Findings & Notes

Durable research findings from the orchestrator (verified 2026-07-02). Each slice
appends its own cross-slice notes below when it finishes.

**Installer map** (`bootstrap_agentic_workspace.sh`, 3,025 lines): sh wrapper
1–99; python heredoc 100–3025. `COMMAND_SKILLS` 164–646 (15 skills;
`do-whole-phase` is `claude_only`); managed-files manifest 648–682; write engine +
retrofit/update policies 686–886; mode guards 890–972; `WORKFLOW_DOC` 974–1066
(emitted verbatim → `CLAUDE.md` + `AGENTS.md`); `DOC_BODIES` 1071–1512
(fresh-only); templates 1568–1631; P1 seed 1634–1721 (fresh-only); `WORKFLOW_PY`
1724–2663 (→ `scripts/workflow.py`); builders + emit 2667–2857 (`model: opus`
stamped at 2735; Codex toml `gpt-5.5` at 2852/2856); settings + codex config
2860–2903; finalizers 2905–3025 (`write_version_marker` 2909–2918 writes
`works/.workspace-version.json`: `upstream_url`, `synced_commit` [env
`SYNCED_COMMIT` or "bootstrap"], `synced_at`; nothing programmatic reads it today).

- **Payloads are byte-identical to live repo files** (sampled
  `.claude/agents/slice-executor.md`, `.claude/skills/do-next-slice/SKILL.md`) —
  the self-hosting repo is in sync, so building the distributable from live files
  is safe.
- **Repo-only files the installer never emits**: the installer itself,
  `README.md`, `LICENSE`, `.gitignore`, `tests/`.
- **Model-pin inventory (live repo)**: pins `.claude/agents/slice-executor.md:5`,
  `slice-executor-high.md:5` (`opus`), `.codex/agents/slice-executor{,-high}.toml:3`
  (`gpt-5.5`); trailers `CLAUDE.md:96`, `AGENTS.md:96`, explain `SKILL.md` in both
  mirrors; prose CLAUDE/AGENTS ~16/19/61, README ~170/246/289,
  `.codex/config.toml:8-9`. `tests/retrofit_smoke.sh` greps `effort:` lines, not
  `model:`, so S2's model change won't break it; effort or filename changes would.
- **`tests/retrofit_smoke.sh`** (164 lines, 6 blocks): retrofit
  non-destructiveness, idempotent re-run, foreign-workflow abort, docs-gating,
  fresh-install regression, live-vs-fresh drift diff. `--update` mode is currently
  untested. Uses `mktemp -d` + `trap cleanup EXIT`; requires git + python3.
- **`/update-workspace` mirrors** differ only in 2 frontmatter lines (the
  `.claude` copy has `allowed-tools` + `disable-model-invocation`); body identical.
  Preview = the installer's own `--update --dry-run` change-list; apply passes
  `SYNCED_COMMIT="$ref"`; it never auto-commits.
- No `CHANGELOG.md`, no version constant, and no build/packaging script exists
  anywhere in the repo today.

**P4.S1 — installer split done (2026-07-02).** The monolith is now a build product.

- **How to change what the installer emits (S2/S3, read this):** edit the **live
  repo file** — a skill (`.claude/skills/*` / `.agents/skills/*`), agent def
  (`.claude/agents/*.md`, `.codex/agents/*.toml`), `scripts/workflow.py`,
  `.claude/settings.json`, `.codex/config.toml`, `works/templates/*`, or the
  contract (`CLAUDE.md`; keep `AGENTS.md` byte-equal in the body — build asserts
  it) — or, for **fresh-install-only seeds with no live counterpart**, edit
  `installer/payloads/doc_bodies/<doc>.md` or `installer/payloads/p1_seed/{phase,intent}.md`.
  Then run **`python3 installer/build.py`** and commit the rebuilt
  `bootstrap_agentic_workspace.sh` with your edit. No more heredoc mirroring.
- **Where the P4 model/version edits land:** Job-1 attribution/model wording lives
  in live files — `.claude/agents/slice-executor{,-high}.md` (`model:` line),
  `CLAUDE.md`/`AGENTS.md` (Commit Convention + prose), `.claude/skills/explain/SKILL.md`
  + `.agents/skills/explain/SKILL.md`, `README.md`, `.codex/config.toml` prose.
  Job-3's `WORKSPACE_VERSION` constant + `write_version_marker()` live in
  `installer/main.py` (search `write_version_marker`, ~unchanged from the old
  finalizers); `CHANGELOG.md` is a new root file (repo-only, not emitted).
- **Drift guard:** `python3 installer/build.py --check` (also `tests/retrofit_smoke.sh`
  Test 7) fails if the committed artifact ≠ rebuilt-from-source. After any edit to a
  live file or payload, rebuild or CI/the smoke test will flag it.
- **`installer/main.py` gotchas:** `COMMAND_SKILLS`, the builder functions, and the
  `WORKFLOW_DOC`/`WORKFLOW_PY` heredocs are **gone**. Skill sets are derived at
  runtime (`CLAUDE_SKILLS`/`CODEX_SKILLS`) from the `PAYLOADS` manifest keys — a
  skill is Claude-only when it has no `.agents/skills/<name>/` mirror on disk (so
  adding/removing a skill needs no installer code change, just the live files +
  rebuild). Generated constants (`PAYLOADS`, `CONTRACT_BODY`, `DOC_BODIES`,
  `P1_PHASE_MD`, `P1_INTENT_MD`) are spliced at the `#@@GENERATED_PAYLOADS@@` marker.
- **Verified byte-identical** for all three modes (fresh / `--into-existing` /
  `--update`) via full `diff -r` of installed trees + update `--dry-run` reporting
  0 machinery files updated. Pure refactor confirmed.

**P4.S2 — model-flexible attribution sweep done (2026-07-02).**

- Edited **live files only**, then `python3 installer/build.py` — the S1 workflow
  held perfectly, no heredoc mirroring needed. Drift check + retrofit smoke (all 7
  blocks) + `validate` all green.
- **For S3:** the `Co-Authored-By: GPT-5.5 …` string in `CLAUDE.md`/`AGENTS.md`:96
  and the two explain `SKILL.md` mirrors is now an intentional **example inside
  rule text** — leave it. The only genuine model pin left in live machinery is the
  Codex `model = "gpt-5.5"` in `.codex/agents/*.toml:3` (scoped out by intent).
- `tests/retrofit_smoke.sh` greps `effort:` (not `model:`), so the `model: inherit`
  change didn't touch it; if S3 adds tests, keep them terse per the contract.
- The distributable is currently 209306 bytes after this rebuild — S3's CHANGELOG
  + `WORKSPACE_VERSION` work will change it again; just rebuild after S3's edits.

**P4.S3 — CHANGELOG + integer workspace versioning done (2026-07-02).**

- **Version plumbing:** `WORKSPACE_VERSION = 1` (int) lives in `installer/main.py`
  near the config constants (right after `UPSTREAM_URL`); `write_version_marker()`
  now stamps `"workspace_version": WORKSPACE_VERSION` into
  `works/.workspace-version.json` (key order: `upstream_url`, `workspace_version`,
  `synced_commit`, `synced_at`). The constant rides inside the built artifact, so
  adopting repos get it on install/update without needing `installer/`. **When you
  ship a machinery change to targets, bump this int AND add a `## v<N>` entry to
  root `CHANGELOG.md` in the same commit** (release rule now in `installer/README.md`).
- **`CHANGELOG.md` is repo-only — NOT emitted to targets.** `build.py` embeds only
  `FIXED_LIVE_FILES` + skills + contract + `payloads/`, so nothing extra was needed
  to keep it out (verified it is absent from the artifact). `/update-workspace` reads
  it from the **fresh upstream clone** (`$tmp/CHANGELOG.md`, a full checkout), never
  from the installed target — the target never has it. Anyone adding version-diff
  features should read upstream's CHANGELOG from the clone, not the target.
- **`/update-workspace` mirrors** now do a version-aware preview: preflight reads
  local `workspace_version` (absent ⇒ pre-versioning); after clone reads upstream M
  from the top `## v<M>` in the clone's CHANGELOG; preview reports vN→vM and prints
  the entries between, folded into the existing step 5 (no renumbering). Bodies kept
  byte-identical across both mirrors (diff-verified); the `.claude` copy keeps its 2
  extra frontmatter lines.
- **Update-mode diff sanity:** running the NEW artifact `--update` over the PREVIOUS
  (HEAD) artifact touches exactly the two `update-workspace/SKILL.md` files — because
  `main.py` and `CHANGELOG.md` are not emitted target files. The version constant
  still reaches the target (stamped into the marker), confirming the "constant rides
  the artifact, changelog is read from the clone" split works end to end.
- This repo's own `works/.workspace-version.json` was hand-updated to
  `"workspace_version": 1` (it's workspace state, only rewritten by install/update).
- Smoke test Test 5 (fresh block) gained a one-line grep asserting the fresh marker
  carries `workspace_version`. Artifact rebuilt (212202 bytes); drift check + all 7
  smoke blocks + `validate` green.

**P4.REVIEW — phase review PASSED (2026-07-02).**

- Validated all slices together: build determinism (byte-identical), `build.py
  --check` + `tests/retrofit_smoke.sh` (all 7 blocks) green, model-pin grep sweep
  clean (no `model: opus`/`opus`, no "on `opus`"/"on `gpt-5.5`" prose; all
  `gpt-5.5` are the Codex toml pins, the config comment, or examples-in-rule),
  end-to-end current-artifact check (fresh install stamps `workspace_version: 1`,
  target `validate` passes, `--update --dry-run` = 0 machinery), CHANGELOG present
  with `## v1` and absent from the artifact, `/update-workspace` mirror bodies
  byte-identical, repo `validate` green. Details in `P4.REVIEW/result.md`.
- **Verdict: pass.** All three intent jobs delivered; slice `result.md`s consistent
  with plans; hard rules honored (no per-slice doc versions; tests terse).
- **Consolidated docs** (`--source P4.REVIEW`): `decisions` → **v0014**,
  `operations` → **v0009**, `architecture` → **v0002**; `rebuild-docs` run. The
  three Doc impact items below are now consolidated.
- Note for future doc consolidations: keep `doc-new-version --summary` terse — the
  slug becomes the version filename, and an over-long one overflows the 255-byte
  filename limit during the editor's atomic temp-rename (hit once here on
  `operations`, recovered by recreating with a short summary).

## Doc impact

**All items below CONSOLIDATED at P4.REVIEW** → `decisions` v0014, `operations`
v0009, `architecture` v0002 (on the passing review).

Running list of durable-truth changes for the review slice to consolidate into new
doc versions (one version per affected doc, at `P4.REVIEW`, on a passing review).
S2/S3/REVIEW append here as they change durable truth.

- (S2, confirmed) `decisions`: v0013 "`opus` alias auto-tracks the top model"
  rationale is **superseded** by the Fable/Mythos tier above Opus — executor defs
  are now `model: inherit` (`.claude/agents/slice-executor{,-high}.md`), so the
  executor runs the session's model. Commit attribution is now **rule-based** —
  "attribute each commit to the model that actually did the work" — with model
  names (`GPT-5.5`) appearing only as examples in the Commit Convention
  (`CLAUDE.md`/`AGENTS.md`) and the explain skill; the Codex tomls keep their
  explicit `model = "gpt-5.5"` pin (Codex needs an explicit model). Record at review.
- (S1) `operations`: the installer is now a **build product** — new build/release
  procedure: edit live files or `installer/payloads/`, run `python3 installer/build.py`,
  commit the rebuilt `bootstrap_agentic_workspace.sh`; `installer/build.py --check`
  (also `tests/retrofit_smoke.sh` Test 7) guards drift. Record at review.
- (S1) `architecture`: repo shape gains an `installer/` source tree
  (`build.py` + `wrapper.sh` + `main.py` + `payloads/`) that assembles the
  single committed distributable at repo root; source of truth for emitted
  machinery = the live repo files (no more heredoc mirroring). Record at review.
- (S3) `operations`: workspaces are now **versioned** — an integer
  `WORKSPACE_VERSION` (starts at v1) is stamped as `workspace_version` into each
  target's `works/.workspace-version.json`, and a root `CHANGELOG.md` (repo-only,
  one `## v<N>` section per version, newest-first) records what each version brings.
  New **release rule** (in `installer/README.md`): when a machinery change ships to
  targets, bump `WORKSPACE_VERSION` in `installer/main.py` AND add the matching
  `CHANGELOG.md` entry in the same commit as the rebuilt artifact. `/update-workspace`
  now previews the sync as "you're on vN → upstream vM" plus the changelog entries in
  between (read from the fresh upstream clone), alongside the existing `--dry-run`
  change-list; a missing local `workspace_version` is treated as pre-versioning.
  Record at review (same `operations` doc as S1's build/release note).

## Constraints

## Open Questions

-
