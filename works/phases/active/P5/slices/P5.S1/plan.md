# Plan — P5.S1 (make /explain opt-in at install, `--with-explain`)

## Context

Read `works/phases/active/P5/phase.md` first — its **Findings & Notes** section holds the full,
file-verified design (single gating point, exact line anchors, update-mode handling, test plan).
This plan is the actionable checklist; `phase.md` is the reference. Also read
`works/phases/active/P5/intent.md` for intent.

**Goal:** `/explain` stops installing by default. A new opt-in `--with-explain` flag includes it.
The live `.claude/skills/explain` / `.agents/skills/explain` files are **not touched** — gating is
install-time only. Bump `WORKSPACE_VERSION` + add a CHANGELOG entry, rebuild the artifact, add
tests. **All of this lands in ONE commit** (the orchestrator commits, not you).

## Steps

### 1. `installer/wrapper.sh` — add the `--with-explain` boolean flag
Mirror the existing `--force-empty-ok` / `--update` pattern exactly:
- Usage block (~L17, near `--dry-run`): add a line
  `  --with-explain              Also install the optional /explain skill (default: off)`
- Var init (~L54, near `dry_run=0`): add `with_explain=0`
- Arg-parse case (~L70, near `--dry-run) ...`): add `    --with-explain) with_explain=1; shift ;;`
- Env export (~L98, near `export DRY_RUN=...`): add `export WITH_EXPLAIN="$with_explain"`

### 2. `installer/main.py` — install-time gate + version bump
- **Gate:** immediately after `CLAUDE_SKILLS`/`CODEX_SKILLS` are derived (L59–60), insert the block
  from `phase.md` verbatim (the `WITH_EXPLAIN` env read, the `--update` presence-preservation `if`,
  `OPTIONAL_SKILLS`, `_excluded`, and the two filtered list comprehensions). Confirm by reading the
  file that `UPDATE` and `ROOT` are defined above this point. Make **no** other edits to the managed
  lists, conflict guard, dir creation, skill-write loop, or `flag_stale_skills` — they inherit the
  filtered lists.
- **Version bump:** `WORKSPACE_VERSION = 1` → `WORKSPACE_VERSION = 2` (~L40).

### 3. `CHANGELOG.md` — required v2 entry (release rule)
Insert this **new section between the intro and `## v1 — 2026-07-02`** (newest-first), matching the
existing bold-lead-in style:

```markdown
## v2 — 2026-07-02

- **`/explain` is now opt-in.** The `explain` skill is no longer installed by default. Pass
  `--with-explain` to include it on a fresh install or an `--into-existing` retrofit. The skill
  still ships inside the built artifact — it is only gated at install time.
- **Update preserves your choice.** `/update-workspace` keeps refreshing an already-installed
  `explain` (it is never dropped or flagged stale on update). A repo without it stays without it
  unless you re-run update with `--with-explain`.

Migration notes: none. Repos that installed `explain` under v1 keep it and keep receiving refreshes.
```

### 4. Rebuild the root artifact (never hand-edit it)
- `python3 installer/build.py` — regenerates `bootstrap_agentic_workspace.sh` from the edited
  `installer/` sources.
- `python3 installer/build.py --check` — must print the OK/in-sync line. If it reports drift, you
  forgot to rebuild or edited the artifact by hand.

### 5. `tests/retrofit_smoke.sh` — additive coverage only
Read the file to place these precisely (do not disturb existing tests; Test 6's hardcoded allowlist
already excludes `explain`, so it needs no change):
- **Default omits explain:** in the default fresh-install test (Test 5, after its existing
  presence checks, reusing that test's install dir var), assert both
  `.claude/skills/explain` and `.agents/skills/explain` are **absent** (an `ok`/`bad` pair).
- **New "Test 8 — /explain is opt-in":** fresh-install a new temp dir with `--with-explain`; assert
  exit 0, `workflow.py validate` passes, and that `.claude/skills/explain/SKILL.md`,
  `.agents/skills/explain/SKILL.md`, and `.agents/skills/explain/agents/openai.yaml` are present and
  **byte-match** the live repo copies (`diff -q "$REPO_ROOT/<rel>" "<install>/<rel>"`). Follow the
  file's existing helpers/idioms (`newtmp`, `ok`, `bad`, `$REPO_ROOT`, `$BOOT`) — read them first.

### 6. Verify end-to-end
- `python3 installer/build.py --check` → OK.
- `bash tests/retrofit_smoke.sh` → all tests pass (existing + the new default-omit assert + Test 8).
- A quick manual sanity check if cheap: fresh install without the flag → no `explain` dirs; with
  `--with-explain` → `explain` present. (The smoke suite already covers both; only do a manual pass
  if a test fails and you need to isolate it.)

## Constraints / hard rules for you (executor)
- Do **not** commit, do **not** run `start-slice`/`finish-slice`/`set-slice-status`/`doc-new-version`.
- Do **not** edit the live `.claude/skills/explain` / `.agents/skills/explain` files.
- Do **not** hand-edit `bootstrap_agentic_workspace.sh` — regenerate via `installer/build.py`.
- Durable docs are versioned at REVIEW, not here — the "Doc impact" notes are already in `phase.md`;
  append any new durable note there if you discover something, but do not run `doc-new-version`.
- Append a short cross-slice note to `phase.md` (Findings & Notes) if implementation revealed
  anything the REVIEW slice should know; then write `result.md`.

## Definition of done
- Default fresh/retrofit install omits `explain`; `--with-explain` includes it (both Claude + Codex).
- `installer/build.py --check` passes; `tests/retrofit_smoke.sh` passes (incl. new asserts + Test 8).
- `WORKSPACE_VERSION == 2` and the `## v2` CHANGELOG entry is present.
- `result.md` written; return `done` with a one-line summary + the list of files changed.
