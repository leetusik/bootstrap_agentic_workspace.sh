# Phase P5: Optional /explain install (--with-explain)

_Intent: see [intent.md](intent.md)._

## Objective

Make the /explain skill opt-in at install: default off, included only via a new --with-explain flag. It stays live in the repo and embedded in the built artifact; gating happens at install time in installer/main.py, keeping the derived skill inventories, conflict guard, dir creation, and stale-skill flagging consistent from one filter point. --update preserves an already-installed copy (never drops or flags it). Bump WORKSPACE_VERSION and add a CHANGELOG entry per the release rule, then rebuild the root artifact.

## Context

- `/explain` is coupled to the operator's personal Mac only, via `~/projects/personal/knowledge`
  (the KB repo it reads/writes/commits into) and a viewer at `localhost:8765` (docker + mkdocs).
  There are **no** absolute `/Users/sugang` paths — all coupling funnels through those two. Live
  skill files: `.claude/skills/explain/SKILL.md` and `.agents/skills/explain/SKILL.md`
  (+ `.agents/skills/explain/agents/openai.yaml`). They are left **as-is** — kept for the operator
  and still embedded in the built artifact.
- Root `bootstrap_agentic_workspace.sh` is a **build product** assembled by `installer/build.py`
  from live `installer/` sources + on-disk skills. `build.py` (`collect_live_payloads`, ~L71–85)
  globs and embeds **every** on-disk skill into the artifact's `PAYLOADS` — so `explain` stays in
  the artifact regardless. The opt-out therefore must happen at **install time** in
  `installer/main.py`; the root artifact is never hand-edited — it is rebuilt.
- This phase covers **only the first half** of the operator's request (make `/explain` optional at
  install). The "public users also can use the feature" half is **deferred** (parameterize KB path
  / viewer), promoted later — not built here. See [intent.md](intent.md).

## Decomposition

_Slice breakdown and rationale — filled by the `P5.DECOMP` slice._

- **`P5.S1` — implementation, risk `high`** — "Make /explain opt-in at install (--with-explain)".
  Adds the installer flag + install-time gate, the `WORKSPACE_VERSION` bump + `CHANGELOG` entry,
  rebuilds the root artifact, and adds test coverage. **One commit, do not split further.**
  Rationale: the drift check (`installer/build.py --check`, smoke Test 7) and the release rule
  (version bump ↔ CHANGELOG entry) both fail on partial states — a version bump without a CHANGELOG
  entry, or a source edit without a rebuilt artifact — so all parts must land together.
- **`P5.REVIEW`** (created with the phase) — validate all slices together (state integrity +
  behavioral: smoke tests), judge against intent, consolidate durable docs (operations + decisions),
  and confirm the version bump + CHANGELOG entry landed.

No fix slices are anticipated.

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

### S1 implementation design (verified against the files by DECOMP)

- **Single gating point.** In `installer/main.py`, right after `CLAUDE_SKILLS`/`CODEX_SKILLS` are
  derived (L59–60), filter `explain` out of both lists when not opted in. Every downstream
  consumer — `MANAGED_DIRS`/`MANAGED_FILES` (L62–96), the fresh-install conflict guard (~L358–365),
  dir creation (~L378–383), the skill-write loop (~L498–503), and `flag_stale_skills` (~L535–560) —
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
  `UPDATE` (L32) and `ROOT` (L41) are defined above this point — verified. Preserve the sorted order
  (list comprehensions do). No other edits to the managed lists / guard / loop / flagger are needed.
- **wrapper.sh flag.** Add a boolean `--with-explain` mirroring `--force-empty-ok` / `--update`: a
  usage line (~L17), `with_explain=0` init (~L54), an arg-parse case (~L70), and
  `export WITH_EXPLAIN="$with_explain"` (~L98). Composes with fresh / `--into-existing` / `--update`;
  no mutual-exclusion guard needed.
- **Release rule.** Bump `WORKSPACE_VERSION` (L40) `1 → 2` **and** add a `## v2 — <date>` entry to
  root `CHANGELOG.md` in the **same commit** (a behavior change reaching adopters via
  `/update-workspace`).
- **Rebuild.** After editing `installer/`, run `python3 installer/build.py` to regenerate the root
  artifact; verify with `python3 installer/build.py --check` (must print OK).
- **Tests are additive.** `tests/retrofit_smoke.sh` Test 6 (dual-apply) uses a **hardcoded
  allowlist that does not include `explain`** (verified: zero `explain` refs anywhere under
  `tests/`), so a default-off install does NOT break it — no fix needed there. Add: (a) an assert in
  the default fresh-install test (Test 5) that `.claude/skills/explain` and `.agents/skills/explain`
  are **absent**; (b) a new "Test 8" that installs with `--with-explain` and asserts the Claude skill
  + Codex mirror (`SKILL.md` + `agents/openai.yaml`) are present and byte-match the live repo copies.
  Test 7 (drift) still passes (the artifact still embeds `explain`).
- **Update-mode / stale-flag asymmetry.** `explain`'s `.claude` `SKILL.md` is the only Claude skill
  lacking `disable-model-invocation: true`, so `flag_stale_skills` would flag only its *Codex* copy
  if `explain` were dropped. The on-`--update` presence-preservation line above avoids this entirely:
  an installed `explain` stays in the expected sets and is never flagged; an absent one is never
  added (unless `--update --with-explain`).

## Constraints

- **One commit for S1** — source edits + rebuilt artifact + CHANGELOG + version bump + tests land
  together (the drift check and release rule fail on partial states).
- Never hand-edit `bootstrap_agentic_workspace.sh`; regenerate it via `installer/build.py`.
- Do not delete or edit the live `.claude/skills/explain` / `.agents/skills/explain` files — they
  stay for the operator and embedded in the artifact.
- Durable docs are versioned at `P5.REVIEW` only; S1 appends a one-line "Doc impact" note below
  instead of running `doc-new-version`.

## Doc impact (running list — for the REVIEW slice to consolidate)

- **operations doc:** new installer flag `--with-explain` (opt-in `/explain`, default off) + the
  `--update` preservation behavior (an already-installed `explain` is refreshed, never dropped or
  flagged).
- **decisions doc:** record the opt-in / default-off choice and its rationale (Mac-coupled feature),
  and that gating happens at install time in `installer/main.py` rather than by removing the source.

## Open Questions

- None open. (Opt-in vs opt-out was resolved to **opt-in / default-off**; the public-users half is
  deferred — see [intent.md](intent.md).)
