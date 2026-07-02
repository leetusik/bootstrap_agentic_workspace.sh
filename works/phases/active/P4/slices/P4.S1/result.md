# Result

- Phase ID: P4
- Slice ID: P4.S1
- Slice: Split installer into installer/ with build + drift check
- Review status: pending
- Next action: P4.S2 (attribution sweep) and P4.S3 (versioning) now edit the modular `installer/` source + live files, then rebuild.

## Outcome

Dissolved the 3,025-line self-contained `bootstrap_agentic_workspace.sh` into an
`installer/` source tree plus a deterministic build step. The root file is now a
**build product** — one self-contained POSIX-sh file, committed, functionally
unchanged for all three modes (fresh / `--into-existing` / `--update`). This is a
pure refactor: the emitted target-repo content is byte-identical to the previous
installer's output (proven below). The double-maintenance is gone: to change what
the installer emits, edit the live file (or an `installer/payloads/` seed) and run
`python3 installer/build.py`.

**What moved where**

- `installer/wrapper.sh` — the POSIX-sh wrapper (former lines 1–99) ending in the
  `python3 - <<'INSTALLER_PY'` heredoc with a `#@@PYTHON_BODY@@` marker.
- `installer/main.py` — the python driver (config/env, write engine, retrofit +
  update policies, guards, docs + P1 seeding, finalizers, dispatch) with a
  `#@@GENERATED_PAYLOADS@@` marker. The `COMMAND_SKILLS` list, the per-file builder
  functions (`claude_skill`, `codex_skill`, `codex_openai_yaml`, `claude_subagent_md`,
  `codex_subagent_toml`), and the `WORKFLOW_DOC` / `WORKFLOW_PY` heredocs are gone.
  `MANAGED_DIRS`/`MANAGED_FILES` and `flag_stale_skills` now derive the skill sets
  from the manifest (`CLAUDE_SKILLS`/`CODEX_SKILLS`); a skill is Claude-only when it
  has no `.agents/skills/` mirror.
- `installer/build.py` — deterministic assembler + `--check` drift mode.
- `installer/README.md` — documents the edit → build → commit loop.
- `installer/payloads/doc_bodies/<doc>.md` (×11) — the fresh-only `DOC_BODIES`,
  sentinel-templated (`__PROJECT_NAME__`, `__PROJECT_SUMMARY__`).
- `installer/payloads/p1_seed/{phase,intent}.md` — the fresh-only P1 scaffold
  bodies, sentinel-templated (`__PHASE_NAME__`, `__PHASE_OBJECTIVE__`, `__CREATED_AT__`,
  `__INTENT_ORIGIN__`, `__INTENT_ORIGINAL__`).

**Source of truth = live repo files** (embedded verbatim by `build.py`, killing the
mirroring): `scripts/workflow.py`, `.claude/skills/*` + `.agents/skills/*` (+
`openai.yaml`), `.claude/agents/slice-executor{,-high}.md`,
`.codex/agents/slice-executor{,-high}.toml`, `.claude/settings.json`,
`.codex/config.toml`, `works/templates/*`, and the `CLAUDE.md` == `AGENTS.md`
contract body (asserted byte-equal, embedded once). Verified pre-flight that all of
these are already byte-identical to the current installer's emitted output.

**Build determinism / drift check**

- `python3 installer/build.py` — reassembles the root artifact from source. Determinism
  = sorted directory walks, sorted dict keys, `repr()` literals, no timestamps.
- `python3 installer/build.py --check` — non-zero on drift; wired into
  `tests/retrofit_smoke.sh` as Test 7 (closes the loop: live files ↔ artifact ↔
  fresh-install output).
- Payloads are embedded as `repr()` literals (single escaped lines) → no payload
  line can collide with the heredoc delimiter; `build.py` also asserts none does.

## Deviations from Plan

1. **P1 seed lives partly as code, partly as payload.** The plan's layout suggested
   `payloads/p1_seed/...` for "phase.md / intent.md bodies etc." I moved the
   *phase.md / intent.md body scaffolds* to `installer/payloads/p1_seed/` (sentinel-
   templated) as suggested, but kept `phase.json` (a dict) and `new_slice_files()`
   (which renders the `result.md` template) as code in `main.py` — they are logic /
   dict structures with no static-text form. `docs/README.md` (a computed category
   list) likewise stays as code. Rationale: these have heavy install-time
   interpolation and no live counterpart, so payload extraction adds byte-identity
   risk for zero maintenance benefit (the goal — killing double-maintenance —
   applies only to files that also exist live).
2. **Payload encoding = `repr()` literals, not a raw heredoc/JSON blob.** `repr()`
   guarantees a round-trip-exact Python literal, keeps every payload on one physical
   line (so nothing can collide with the heredoc delimiter), and stays deterministic.
   Trade-off: the generated artifact is not line-diffable inside the payload dict —
   acceptable because it is a build product; humans edit the live files / payloads.
3. **Heredoc delimiter changed `PY` → `INSTALLER_PY`** (distinctive, per the plan's
   safety note). This changes the *installer file's own* bytes but not the emitted
   output — the byte-identity constraint is on the emitted target files (proven by
   the fresh/update/retrofit equivalence diffs), which the plan's validation targets.

No other deviations. Emitted content is unchanged; wording/model/version edits are
deferred to S2/S3 as scoped.

## Validation Run

1. Determinism — `python3 installer/build.py` twice → **byte-identical** (`diff` of
   the two outputs empty); the committed root artifact is the rebuilt one. PASS.
   (Note: build.py prints `len()` char-count 208971; `wc -c` byte-count 209713 —
   same file, multi-byte UTF-8.)
2. `python3 installer/build.py --check` → **OK: artifact matches installer/ source**. PASS.
3. `bash tests/retrofit_smoke.sh` → **ALL RETROFIT SMOKE TESTS PASSED** (all 7 blocks,
   including new Test 7 drift check). PASS.
4. Fresh-mode functional equivalence — fresh-installed `git show HEAD:bootstrap…`
   (old.sh) and the new artifact into two temp dirs with identical args; `diff -r`
   of the full trees → **byte-identical (92 files each), incl. timestamps**; stdout
   identical; both exit 0. PASS.
5. Update-mode functional equivalence — fresh-installed old.sh into a temp git repo,
   then ran the NEW artifact `--update --dry-run` → **machinery updated: 0 file(s)**;
   real `--update` → exit 0, **0 machinery updated**, only generated/timestamp files
   changed (`works/{state,index,backlog,deferred}`, `docs/index.json`,
   `.workspace-version.json`); `python3 scripts/workflow.py validate` in the target → passed. PASS.
6. `python3 scripts/workflow.py validate` (this repo) → **Workflow validation passed**. PASS.
7. (extra) Retrofit-mode equivalence — old.sh vs new artifact `--into-existing` into
   identical existing repos; `diff -r --exclude=.git` → **byte-identical**. PASS.

## Files Changed

- `bootstrap_agentic_workspace.sh` (now a generated build product)
- `installer/build.py` (new)
- `installer/wrapper.sh` (new)
- `installer/main.py` (new)
- `installer/README.md` (new)
- `installer/payloads/doc_bodies/{product,experience,architecture,frontend,backend,data,api,operations,security,qa,decisions}.md` (new)
- `installer/payloads/p1_seed/{phase,intent}.md` (new)
- `tests/retrofit_smoke.sh` (added Test 7 drift check)

## Doc Versions Created

- None (per contract, non-review slices do not version docs). Doc-impact notes
  appended to `phase.md` for the review slice to consolidate.

## Roadmap Updates

- S2/S3 now edit the modular installer source + live files, then rebuild — no
  heredoc mirroring. See the S2/S3 cross-slice note in `phase.md`.

## Retrospective

- The strongest safety net was the full `diff -r` of installed trees (fresh /
  update / retrofit), which would flag any single-byte drift from sentinel
  substitution or repr round-tripping. All three modes are byte-identical.
- `repr()` literals + sorted keys made determinism trivial and sidestepped the
  heredoc-collision problem entirely (no bare delimiter line can appear).
- A pre-flight diff (live files vs current installer output) confirmed the
  self-hosting repo was already in sync, so embedding live files was safe.
