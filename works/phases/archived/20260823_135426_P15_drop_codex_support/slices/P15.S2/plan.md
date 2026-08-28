# Plan — P15.S2: Strip Codex from the installer and delete the Codex trees

This is the phase's **atomic** slice. `installer/build.py` reads the Codex trees as live
payload and asserts a 17↔17 skill inventory plus `CLAUDE.md == AGENTS.md`; deleting those trees
without fixing the build in the same commit makes the build `die()` and the pre-commit hook
reject the commit. Installer edits and deletions land together.

Read `works/phases/active/P15/phase.md` first — *What must stay atomic* item 1, *Findings &
Notes*, and *Constraints*. Line numbers below were verified at `75a8fb2`; re-check before editing.

## The hazard that shapes the verification

**`installer/build.py` only `compile()`s the assembled body (~L171) — it never executes it.**
So `installer/main.py`'s import-time parity guards never run at build time. If `build.py` stops
embedding the Codex payloads while `main.py` keeps `CODEX_SKILLS` and its parity `raise`, then
`python3 installer/build.py`, `--check`, and the pre-commit hook **all pass** and the artifact is
committed broken — every install, retrofit, and update would die at
`RuntimeError: embedded skill inventory must contain 17 matching…`. The same latent failure
applies to a `KeyError` if a payload key vanishes while its write remains.

The build guard structurally cannot catch this. **Therefore this slice must actually run the
built artifact** (see *Validation*). Do not treat a green `--check` as proof the artifact works.

## Suggested intra-slice sequence

`build.py` → `main.py` → `wrapper.sh` → delete the trees → `python3 installer/build.py` →
`.githooks/pre-commit` (order-free) → run the artifact → `--check`. Note `build.py` cannot run at
all once the trees are gone and it is unfixed, so fix it before deleting.

## 1. `installer/build.py`

- `FIXED_LIVE_FILES` — delete the three Codex entries (`.codex/config.toml` ~L47,
  `.codex/agents/slice-executor-{mid,high}.toml` ~L50-51). Left in place they hit
  `die("missing source file: …")`.
- Delete the `.agents/skills` payload globs (~L86-89).
- The parity block (~L95-117): delete the `codex_skills` comprehension, the two-arm length
  check, the `claude_skills != codex_skills` die, and the `missing_metadata` block.
  **Keep `EXPECTED_SKILL_COUNT` as a Claude-only count assert** — it is a real guard against a
  truncated payload, and it costs nothing.
- `AGENTS_HDR` (~L63) — delete; its only consumers are the two checks below.
- `collect_contract_body()` (~L121-130) — delete the `read("AGENTS.md")`, the `AGENTS_HDR`
  header check, and the body-equality check. **Keep the `CLAUDE_HDR` check**; `P15.S3` changes
  that literal, not this slice.
- Module docstring (~L11-15) — it names `.agents/skills/*`, the `.codex` subagents,
  `.codex/config.toml`, and "the `CLAUDE.md == AGENTS.md` contract body". Rewrite it.

## 2. `installer/main.py`

- `CODEX_SKILLS` and the import-time parity guards (~L55-71) — delete. **Keep the Claude-side
  count assert** to match `build.py`.
- `MANAGED_DIRS` (~L80-81), `MANAGED_FILES` (~L85, L94), and the per-skill `MANAGED_FILES`
  extend (~L100-105) — drop every `.agents` / `.codex` / `AGENTS.md` entry.
  **Record this behaviour change**: `MANAGED_FILES` losing `"AGENTS.md"` narrows the
  fresh-install conflict guard (~L447-454), so a target directory containing only an `AGENTS.md`
  now passes the guard instead of being rejected. That is correct — we no longer write there —
  but it is a real change and belongs in `phase.md`.
- Retrofit path — `_retrofit_handle()` (~L266) and the update contract dispatch (~L351): drop
  `"AGENTS.md"` from the tuples. Delete the `write_text("AGENTS.md", …)` at ~L478.
  `_merge_contract()` then never sees it, and **an existing repo's own `AGENTS.md` is left
  byte-identical** — today it is read (~L245) and rewritten (~L253) on every retrofit, so this
  makes the installer strictly less invasive. That is the desired outcome; say so in `phase.md`.
- The pointer-block text (~L241) names `` `.claude/`/`.agents/` `` — drop `.agents/`.
- Fresh-install Codex writes — delete the `CODEX_SKILLS` loop (~L555-557), the
  `.codex/agents/slice-executor-*.toml` writes inside the shared tier loop (~L561-563), and
  `.codex/config.toml` (~L572). Leave the Claude writes in that loop untouched.
- **`OBSOLETE_MACHINERY` (~L595-606)** — this is the adopter-migration mechanism the operator
  explicitly asked for, so get it right:
  - Add `.agents`, `.codex`, `AGENTS.md`, and **`AGENTS.workspace.md`**. The sidecar is included
    deliberately: `_merge_contract` created it for retrofitted adopters, and once the installer
    stops handling `AGENTS.md` it would never be refreshed and never flagged — a silent strand.
    Flagging it is exactly what this list is for.
  - **Fix `flag_obsolete_machinery()` (~L609-612): it checks only `is_file()`, so directory
    entries silently no-op.** Without this the whole migration promise is dead code. Use
    `.exists()` (or `is_file() or is_dir()`).
  - Collapse the now-redundant `.codex/agents/slice-executor.toml` (~L599) and
    `.codex/agents/slice-executor-low.toml` (~L605) entries — a `.codex` directory entry
    subsumes them and they would double-report.
  - Each entry carries a trailing comment explaining what retired it and when; follow that
    convention and name workspace v31.
- `flag_stale_skills()` (~L615-640) — drop the `.agents/skills` half and its `openai.yaml`
  ownership marker; keep the Claude `disable-model-invocation: true` marker logic exactly as is.
  Update the docstring, which is written as per-tool prose.
- `_is_machinery()` (~L286-289) — drop `.codex/config.toml`, `.codex/agents/`, `.agents/skills/`.
- Banners and comments — the fresh banner (~L711-724: "cross-tool", the
  `CLAUDE.md and AGENTS.md (equivalent)` line, "17 skills", the Codex line, the Codex half of
  the design line, `$create-phase (Codex)`) and the retrofit banner (~L697-710: the
  `CLAUDE.md/AGENTS.md` sidecar sentence, `$create-phase in Codex`). Also the comments at
  ~L55-57, L232, L276, L278, L348, L476, L552, L571, L618-619.

## 3. `installer/wrapper.sh`

The `usage()` heredoc only (~L20-28): "BOTH Claude Code and OpenAI Codex", the
`AGENTS.md`/`CLAUDE.md` equivalence line, and the `.agents/skills/` bullet. There are no
per-tool flags, so there is nothing to gate — only text to remove.

## 4. Delete the trees

`.agents/` (34 files), `.codex/` (3 files), `AGENTS.md`. Use `git rm -r` so the deletions are
staged for the orchestrator.

## 5. `.githooks/pre-commit`

Drop `AGENTS\.md$|`, `\.agents/|`, and `\.codex/|` from the L8 path alternation. This only
narrows the trigger set and does not affect this commit — `installer/**` and the artifact are
staged here and match either way. The hook is not embedded, so it needs no rebuild.

## Decisions already made — do not re-litigate

- `AGENTS.workspace.md` **is** flagged (above). The brief left this open; it is settled.
- `EXPECTED_SKILL_COUNT` **stays** in both files as a Claude-only assert.
- `tests/retrofit_smoke.sh` is expected red after this slice (its pinned modified-file list, the
  `AGENTS.workspace.md` greps, the inventory, and the drift manifest all still assume Codex).
  `P15.S4` fixes it. Do not touch `tests/` here, and do not run the smoke test as a gate.
- Whether the installer should *assert* it never touches a repo's own `AGENTS.md` is a test
  concern — note it in `phase.md` for `P15.S4`, do not add it here.

## Out of scope

`CLAUDE.md` and `.claude/**` (S3), `tests/**` (S4), `README*`, `docs/**`, `installer/README.md`,
`installer/payloads/doc_bodies/*` (S5), `WORKSPACE_VERSION` and `CHANGELOG.md` (S6).
Leave `WORKSPACE_VERSION` at 30 — S6 bumps it.

## Validation

- `python3 installer/build.py` succeeds, then `python3 installer/build.py --check` passes.
- **Run the artifact for real — this is the slice's most important gate:**
  - Fresh install into an empty temp dir: `bash bootstrap_agentic_workspace.sh <tmp> --name x
    --summary y`. It must complete, and the result must contain `.claude/skills` (17),
    `.claude/agents/slice-executor-{mid,high}.md`, `CLAUDE.md`, and **no** `.agents/`,
    `.codex/`, or `AGENTS.md`.
  - In that fresh workspace, `python3 scripts/workflow.py validate` and
    `python3 scripts/workflow.py sync-agents --check` both pass.
  - Retrofit into a temp dir seeded with its own `CLAUDE.md` **and its own `AGENTS.md`**
    (`--into-existing`): it must complete, and the seeded `AGENTS.md` must come out
    **byte-identical** (diff it) while `CLAUDE.md` gains the pointer block.
  - `--update` against a temp workspace that has `.agents/`, `.codex/`, `AGENTS.md`, and
    `AGENTS.workspace.md` present: confirm all four appear in the `stale … (remove manually?)`
    line, and that **nothing was deleted**. Simplest setup: fresh-install with the *committed*
    pre-S2 artifact (`git show HEAD:bootstrap_agentic_workspace.sh`), then `--update` with the
    new one.
- `python3 scripts/workflow.py validate` in this repo passes.
- `grep -rn 'codex\|\.agents\|AGENTS' installer/build.py installer/main.py installer/wrapper.sh
  .githooks/pre-commit` — no hits (case-insensitive).

## Notes for `phase.md`

Record: the fresh-install conflict-guard narrowing; that a repo's own `AGENTS.md` is now left
untouched (and the S4 test note); the final `OBSOLETE_MACHINERY` list and the `is_file()` →
`.exists()` fix; and — under *Open Questions* — that `build.py` only `compile()`s the artifact
body, so a broken install can pass every commit gate. That last one is a pre-existing hazard
this phase merely surfaced; flag it as a candidate deferred job, do not fix it here.
