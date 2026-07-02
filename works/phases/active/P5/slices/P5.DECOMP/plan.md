# Plan — P5.DECOMP (decompose the phase)

## Your job

Break phase P5 into its middle slice(s) and seed `phase.md` so the implementation and review
slices have the full design context. You create **bare** slice folders only (via `new-slice`) and
write `phase.md` — do **not** pre-fill any slice's `plan.md`, do **not** implement code, do **not**
commit or transition slice/phase status. Write `result.md` and return a verdict when done.

## Confirmed decomposition (one implementation slice + the existing review)

The change is a single cohesive unit that must land in one commit (the drift check and the release
rule both fail on partial states — e.g. a version bump without a CHANGELOG entry, or a source edit
without a rebuilt artifact). So there is exactly **one middle slice**:

- **`P5.S1` — implementation, risk `high`** — "Make /explain opt-in at install (`--with-explain`)".
  Adds the flag, the install-time gate, the version bump + CHANGELOG entry, rebuilds the artifact,
  and adds test coverage. Do not split it further.

`P5.REVIEW` already exists (created with the phase). No fix slices are anticipated.

### Action

Run exactly:

```
python3 scripts/workflow.py new-slice --phase P5 --slice P5.S1 \
  --name "Make /explain opt-in at install (--with-explain)" --kind implementation --risk high
```

(Order auto-assigns between DECOMP=0 and REVIEW=9999. Leave `P5.S1/plan.md` unwritten — the
orchestrator writes it at S1's turn.)

## Seed `phase.md` with this design (fill the empty sections)

Record the following into `phase.md` so `P5.S1` and `P5.REVIEW` inherit it. Keep it durable and
concrete; this is the shared phase notebook.

### Context
- `/explain` is coupled to the operator's personal Mac only, via `~/projects/personal/knowledge`
  (KB repo it reads/writes/commits into) and a viewer at `localhost:8765` (docker + mkdocs). There
  are **no** absolute `/Users/sugang` paths. Live skill files: `.claude/skills/explain/SKILL.md`
  and `.agents/skills/explain/SKILL.md` (+ `.agents/skills/explain/agents/openai.yaml`). They are
  left **as-is** (kept for the operator, still embedded in the artifact).
- Root `bootstrap_agentic_workspace.sh` is a **build product** assembled by `installer/build.py`
  from live `installer/` sources + on-disk skills. `build.py` (`collect_live_payloads`, ~:71–85)
  globs and embeds **every** on-disk skill into the artifact's `PAYLOADS` — so `explain` stays in
  the artifact regardless. The opt-out therefore must happen at **install time** in
  `installer/main.py`; never hand-edit the root artifact — rebuild it.

### Decomposition
- `P5.S1` (implementation, high) — installer flag + gate + version/CHANGELOG + rebuild + tests. One
  commit. Rationale: drift check (`build.py --check`, smoke Test 7) and the release rule
  (version bump ↔ CHANGELOG entry) require all parts together.
- `P5.REVIEW` — validate all slices (state + behavioral), consolidate durable docs (operations +
  decisions), confirm the version bump + CHANGELOG landed.

### Findings & Notes (the S1 implementation design — verified against the files)
- **Single gating point.** In `installer/main.py`, right after `CLAUDE_SKILLS`/`CODEX_SKILLS` are
  derived (~:59–60), filter `explain` out of both lists when not opted in. Every downstream
  consumer — `MANAGED_DIRS`/`MANAGED_FILES` (~:62–96), the fresh-install conflict guard (~:358–365),
  dir creation (~:378–383), the skill-write loop (~:498–503), and `flag_stale_skills` (~:535–560) —
  derives from those two lists, so one filter keeps them all consistent:
  ```python
  WITH_EXPLAIN = os.environ.get("WITH_EXPLAIN") == "1"
  # On --update, keep refreshing an already-installed explain (never drop it, never let
  # flag_stale_skills asymmetrically flag its Codex copy) regardless of the flag.
  if UPDATE and (ROOT / ".claude/skills/explain/SKILL.md").exists():
      WITH_EXPLAIN = True
  OPTIONAL_SKILLS = {"explain": WITH_EXPLAIN}
  _excluded = {n for n, on in OPTIONAL_SKILLS.items() if not on}
  CLAUDE_SKILLS = [s for s in CLAUDE_SKILLS if s not in _excluded]
  CODEX_SKILLS  = [s for s in CODEX_SKILLS if s not in _excluded]
  ```
  `UPDATE` (~:32) and `ROOT` (~:41) are defined above this point. Preserve the sorted order (list
  comprehensions do). No other edits to the managed lists / guard / loop / flagger are needed.
- **wrapper.sh flag.** Add a boolean `--with-explain` mirroring `--force-empty-ok`/`--update`: a
  usage line (~:17), `with_explain=0` init (~:54), an arg-parse case (~:70), and
  `export WITH_EXPLAIN="$with_explain"` (~:98). Composes with fresh/`--into-existing`/`--update`;
  no mutual-exclusion guard needed.
- **Release rule.** Bump `WORKSPACE_VERSION` (~:40) `1 → 2` AND add a `## v2 — <date>` entry to root
  `CHANGELOG.md` in the same commit (behavior change reaching adopters via `/update-workspace`).
- **Rebuild.** After editing `installer/`, run `python3 installer/build.py` to regenerate the root
  artifact; verify with `python3 installer/build.py --check` (must print OK).
- **Tests are additive.** `tests/retrofit_smoke.sh` Test 6 (dual-apply) uses a **hardcoded
  allowlist that does not include explain** (verified: zero `explain` refs in `tests/`), so a
  default-off install does NOT break it — no fix needed there. Add: (a) an assert in the default
  fresh-install test (Test 5) that `.claude/skills/explain` and `.agents/skills/explain` are
  **absent**; (b) a new "Test 8" that installs with `--with-explain` and asserts the Claude skill +
  Codex mirror (`SKILL.md` + `agents/openai.yaml`) are present and byte-match the live repo copies.
  Test 7 (drift) still passes (artifact still embeds explain).
- **Update-mode / stale-flag asymmetry.** `explain`'s `.claude` SKILL.md is the only Claude skill
  lacking `disable-model-invocation: true`, so `flag_stale_skills` would flag only its *Codex* copy
  if dropped. The on-`--update` presence-preservation line above avoids this entirely: an installed
  `explain` stays in the expected sets and is never flagged; an absent one is never added (unless
  `--update --with-explain`).

### Constraints
- One commit for S1 (source edits + rebuilt artifact + CHANGELOG + version + tests together).
- Never hand-edit `bootstrap_agentic_workspace.sh`; regenerate via `installer/build.py`.
- Do not delete or edit the live `.claude/skills/explain` / `.agents/skills/explain` files.
- Durable docs are versioned at `P5.REVIEW` only; S1 appends a one-line "Doc impact" note to
  `phase.md` instead of running `doc-new-version`.

### Doc impact (running list — for the REVIEW slice to consolidate)
- operations doc: new installer flag `--with-explain` (opt-in `/explain`) + `--update` preservation
  behavior.
- decisions doc: record the opt-in / default-off choice and its rationale (Mac-coupled feature).

## Definition of done for this slice
- `P5.S1` folder created (bare) via `new-slice`.
- `phase.md` seeded with the sections above.
- `result.md` written; return `done` with a one-line summary and the created slice id.
