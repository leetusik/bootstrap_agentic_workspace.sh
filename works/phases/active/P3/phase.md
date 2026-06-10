# Phase P3: Retrofit Guide & Skill: Adopting the Agentic Workspace into an Existing Project

## Objective

Enable developers to adopt this agentic workspace into a repository that is already under active development — not just a fresh/empty directory. Today bootstrap_agentic_workspace.sh assumes an empty target (it refuses non-empty dirs without --force-empty-ok and aborts if managed files already exist), and there is no documentation for retrofitting onto a project with existing code, README, scripts/, docs, or git history. This phase closes that gap.

Deliverables (the DECOMP slice sets the final slice breakdown; the form is fixed as guide + skill):
1. A retrofit guide (markdown) that walks an operator/agent through adding the workspace — contracts (CLAUDE.md/AGENTS.md), the works/ state machine, scripts/workflow.py, docs/ versioning, and skills — to an existing repo, including how to handle collisions with existing files, preserve git history, and seed the first phase from the project's current state instead of from scratch.
2. A delivered Skill, mirrored in .claude/skills and .agents/skills (with the Codex agents/openai.yaml) per project convention, that drives an agent through the retrofit; explicit-invocation only, consistent with the other workflow skills.
3. End-to-end verification that the guide + skill actually work on a representative existing repo (e.g., a dry-run adoption into a sample project).

Constraints:
- Treat docs/current/*.md and CLAUDE.md as source of truth; if guide content becomes durable doc truth, add it via doc-new-version — never hand-edit generated snapshots under docs/current/.
- Whether to extend bootstrap_agentic_workspace.sh with a non-empty/existing-repo retrofit mode is for DECOMP to evaluate; IF the script is changed, the live script and the copy embedded in the bootstrap script must stay in sync (dual-apply), matching the constraint established in P2.
- Adoption must be safe and non-destructive — never clobber a target repo's existing files.
- Per the contract, this phase is created with DECOMP + REVIEW only; the DECOMP slice creates the middle slices (bare folders) and records the breakdown, findings, and notes in phase.md.

## Context

The installer `bootstrap_agentic_workspace.sh` is a shell wrapper (arg parse + defaults + env exports, `:50-84`) that runs an embedded Python heredoc which writes the whole workspace into a TARGET dir. Relevant internals discovered during decomposition:

- **Guards** (`:399-422`): (1) any pre-existing `MANAGED_FILES` path → hard abort "refusing to overwrite"; (2) dir non-empty beyond `EMPTY_OK_ALLOWLIST` (`.git`, README, LICENSE, `.github`, `.gitignore`, …) and `--force-empty-ok` not set → abort.
- **Writes** (`:375-396`): `write_text`/`write_json` do an atomic **unconditional overwrite**.
- **P1 seed** (`:1080-1140`): always creates exactly P1 with `DECOMP`+`REVIEW`, name/objective from `--phase-name`/`--phase-objective` (defaults "Bootstrap Intake" / "Capture the first real task…").
- **Final step** (`:2131-2137`): runs `scripts/workflow.py rebuild` then `validate`. `rebuild` is itself an **unconditional overwrite** of `docs/current/*.md` and `works/{state,index,backlog,deferred}` (`scripts/workflow.py:1234-1244`, `:1427-1452`), and `rebuild_docs` raises `SystemExit "latest doc file missing"` (`:1241`) if `docs/index.json` points at an absent version file. No git is ever run.
- **`MANAGED_*`** lists `:331-364`; **`COMMAND_SKILLS`** `:130-329`; skills emitted at `:2067-2070`; embedded `WORKFLOW_PY` raw string `:1143-2030`.

**Open question resolved (operator-confirmed during planning):**
- Mechanism → **extend the installer** with a flag-gated `--into-existing` mode (fresh path unchanged).
- Non-destructive strictness → **allow additive, idempotent merges** (settings.json union; marked CLAUDE.md/AGENTS.md section + sidecar).
- Verification artifact → **commit a reusable smoke test** (`tests/retrofit_smoke.sh`).

## Decomposition

Order: guide → installer → skill → verify. Guide first because it is where the per-path collision policy is designed (so S2 implements a written spec), and it de-risks the phase by shipping a usable manual procedure even if later slices slip. S2 is the highest-risk slice (touches the install guards/writes). S3 wraps the capability in a skill (dual-applied). S4 proves non-destructiveness and locks the dual-apply invariant with a committed test.

| Slice | Kind | Risk | Order | What it covers |
|---|---|---|---|---|
| `P3.S1` retrofit guide and durable docs | docs | low | 10 | `docs/retrofit-guide.md` adoption runbook + per-path collision policy; link from `README.md`; durable truth via `doc-new-version` on `operations` (adoption procedure) and `decisions` (v0003 retrofit decision). |
| `P3.S2` installer into-existing retrofit mode | implementation | high | 20 | Flag-gated `--into-existing` two-pass, four-tier non-destructive install in the bootstrap; gate the final rebuild/validate to installed subsystems; print a written/skipped/merged/aborted summary; fresh path byte-for-byte unchanged. |
| `P3.S3` retrofit skill dual-applied | implementation | medium | 30 | `retrofit` skill: append to `COMMAND_SKILLS` + add to `MANAGED_*`, hand-write 3 live files; explicit-invocation only; orchestrate preflight→installer→reconcile contract→validate→report. |
| `P3.S4` end-to-end verification and smoke test | qa | medium | 40 | `tests/retrofit_smoke.sh` (non-managed): sha256 non-destructiveness, abort atomicity, validate, P1 seeded-from-state, subsystem gate, fresh-install regression, live↔embedded dual-apply sync. |

`P3.REVIEW` (order 9999) closes the phase.

## Findings & Notes

**The four-tier install model (the core design for S2).** "Skip files that exist" is unsafe alone because the final `rebuild` re-overwrites generated files. So `--into-existing` runs **two passes** — PLAN (classify every managed path, no writes; abort up-front on any tier-4 collision so we never half-install) then APPLY:
- **Tier 1 — skip-if-exists (keep theirs):** pure content — `.claude|.agents` skill files, `.claude/agents/phase-reviewer.md`, `.codex/config.toml`, `works/templates/*`, `docs/README.md`.
- **Tier 2 — install subsystem wholesale, only if wholly absent:** `docs/` (gate on `docs/index.json`) and `works/` (gate on `works/state.json`). If present, write none of it and **gate the final rebuild** to only-installed subsystems. If `works/` already holds a workspace → abort "already has a workspace."
- **Tier 3 — additive idempotent merge:** `.claude/settings.json` (union `permissions.allow`/`deny`, preserve other keys; never touch `settings.local.json`); `CLAUDE.md`/`AGENTS.md` (append a concise workspace section between `<!-- BEGIN agentic-workspace -->`/`<!-- END … -->` markers + full-contract sidecar `*.workspace.md`; replace the marked block in place on re-run).
- **Tier 4 — hard abort on collision:** existing `scripts/workflow.py` (runtime shells to it — a foreign copy breaks everything). Abort "rename/relocate or adopt manually."

**Seeding P1 from project state.** No `edit-phase` command exists and the installer always seeds P1, so the only clean lever is the existing `--phase-name`/`--phase-objective` flags (no `workflow.py` change). The **skill** synthesizes a project-derived name/objective (README, package manifest, language, `git log` HEAD) and passes them through. P1 stays `DECOMP`+`REVIEW`-only — "seed from state" = better default text, not a different structure.

**Dual-apply map (keep live copy == bootstrap-embedded copy):**
- `scripts/workflow.py` (live) ↔ `WORKFLOW_PY` raw string (`:1143-2030`). **Plan: do not change `workflow.py`** to avoid this surface entirely.
- Each skill: live `.claude/skills/<n>/SKILL.md` + `.agents/skills/<n>/{SKILL.md,agents/openai.yaml}` ↔ `COMMAND_SKILLS` entry. **S3 must edit both.**
- `CLAUDE.md`/`AGENTS.md` (live, top-level) ↔ bootstrap `WORKFLOW_DOC` heredoc. Only if S3 updates the contract's skill inventory.
- S4 asserts the first two stay in sync.

**Membership gotchas.** Retrofit-only artifacts (`CLAUDE.workspace.md`, `AGENTS.workspace.md`) must **not** be added to `MANAGED_FILES` (else the fresh-install guard false-trips). The new `retrofit` skill's 3 files **must** be added to `MANAGED_DIRS`/`MANAGED_FILES` so fresh installs ship them (S4 fresh-install regression must re-bless this delta). Never write `.gitignore`; the guide tells adopters to add `__pycache__/` (created the moment `workflow.py` runs). Run the smoke test with `PYTHONDONTWRITEBYTECODE=1` and/or tolerate `__pycache__` in the "only-added" assertion.

### S1 done — guide is the locked spec (note for S2/S3/S4)

`docs/retrofit-guide.md` now specifies the retrofit behavior; **S2 must implement
to it and S4 verifies against it.** Concrete contract points S2/S3 must match:
- Flag is **`--into-existing`**. It prints a **summary** of created/skipped/merged
  paths and per-subsystem installed-vs-skipped at the end.
- Tier-4 abort message theme: "target already has scripts/workflow.py" → exit
  non-zero, no writes. "already contains an agentic workspace" when `works/state.json` present.
- Contract handling: keep their `CLAUDE.md`/`AGENTS.md`; append a block between
  `<!-- BEGIN agentic-workspace -->` / `<!-- END agentic-workspace -->`; write the
  full contract to sidecars **`CLAUDE.workspace.md`** / **`AGENTS.workspace.md`**.
- `.claude/settings.json`: **union** workspace permission entries into existing
  `permissions.allow`/`deny`; never touch `settings.local.json`.
- Seed P1 via `--phase-name`/`--phase-objective`; the `/retrofit` skill (S3)
  synthesizes them from README/manifest/language/HEAD.
- Durable docs landed: `operations` v0002 (procedure) + `decisions` v0003 (the decision).

### S2 done — `--into-existing` works as specified (note for S3/S4)

The installer mode is implemented and E2E-verified (non-destructive, atomic
abort, idempotent no-op, subsystem gate, merges). Concrete facts S3/S4 rely on:
- **Invocation:** `sh bootstrap_agentic_workspace.sh <dir> --into-existing [--phase-name … --phase-objective …]`.
- **Summary lines** S4 can assert against (stdout): `Retrofit complete (--into-existing) at …`, `  created: N new file(s)`, `  skipped (kept yours): N file(s)`, `  merged (additive): …`, `  docs subsystem: installed|skipped …`, `  works subsystem: installed; seeded phase P1 - <name>`.
- **Exit codes:** already-adopted repo (works/ present) → **exit 0** "nothing to retrofit"; foreign `scripts/workflow.py` → **exit 1**, zero writes.
- **S3 nuance:** a freshly-bootstrapped workspace ships the `retrofit` skill but **not** the bootstrap script (the installer isn't a managed file). So the skill must locate/obtain the installer (operator-provided path or the README curl one-liner) before invoking `--into-existing` — the skill orchestrates, it doesn't embed the installer.
- **S4 nuance:** `__pycache__/` appears once `workflow.py` runs; run the smoke test with `PYTHONDONTWRITEBYTECODE=1`. The dual-apply check covers `scripts/workflow.py` ↔ `WORKFLOW_PY` (unchanged this phase) and the new `retrofit` skill files ↔ `COMMAND_SKILLS` (added in S3).

### S3 done — `retrofit` skill shipped + dual-applied (note for S4)

The `retrofit` skill exists in `COMMAND_SKILLS` and as the three live files,
generated from the bootstrap so they match byte-for-byte. Facts for S4's smoke test:
- **Dual-apply assertion to encode:** run a fresh bootstrap into a temp dir, then
  `diff` the temp's `.claude/skills/retrofit/SKILL.md`, `.agents/skills/retrofit/SKILL.md`,
  `.agents/skills/retrofit/agents/openai.yaml` against the live repo's — must be identical.
  (Generalize to all skills if cheap.) Also assert live `scripts/workflow.py` ==
  the bootstrap's embedded `WORKFLOW_PY` block (unchanged this phase, but the check guards future drift).
- Skill membership in `MANAGED_*` is auto-derived from `COMMAND_SKILLS`; the fresh-install
  file set now includes the 3 retrofit files (the only intended delta — S4 fresh-install regression should expect it).
- No `settings.json`/`workflow.py` change. The skill body does **not** auto-commit.

## Constraints

- Fresh-install (no-flag) path must stay byte-for-byte unchanged and still `validate`. Gate all new behavior behind `if RETROFIT:`.
- Non-destructive: never overwrite/delete existing content; merges are additive + idempotent; a re-run of retrofit is a clean no-op.
- Never hand-edit `docs/current/*.md`; durable docs go through `doc-new-version` + `rebuild-docs`.
- Commit at each slice boundary; work on `main` (no branch) per the CLAUDE.md hard rule; never push.
- Review only — a passing P3 stays in `active/` (no archive); do not continue into a next phase.

## Open Questions

- None blocking. (S2 may split into S2a/S2b if the installer change grows; the slice decides.)
