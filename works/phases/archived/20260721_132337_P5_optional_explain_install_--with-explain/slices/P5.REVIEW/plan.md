# Plan — P5.REVIEW (phase review + doc consolidation)

## Your job

Review phase P5 as a whole: validate all slices together against the phase intent, then — on a
pass — consolidate the phase's durable-doc impact into new doc versions. You may run
`doc-new-version` (this is the review slice). You do **not** run `review-phase`, do **not** commit,
and do **not** transition slice/phase status — the orchestrator records your verdict.

Read first: `works/phases/active/P5/intent.md`, `works/phases/active/P5/phase.md` (Findings & Notes
+ Doc impact list), and each slice's `plan.md`/`result.md` (`P5.DECOMP`, `P5.S1`).

## Review checklist (behavioral validation, all slices at once)

1. **Intent match.** The confirmed intent: `/explain` no longer installs by default; the new
   `--with-explain` flag includes it on fresh/retrofit installs; `--update` preserves an
   already-installed copy (refreshes, never drops or stale-flags); the live skill files stay
   untouched and still embedded in the artifact; `WORKSPACE_VERSION` bumped with a matching
   CHANGELOG entry; root artifact rebuilt, never hand-edited. Verify each claim against the diff of
   the S1 commit (`git show --stat HEAD` and the files themselves).
2. **Code review of the gate.** Read the inserted block in `installer/main.py` (after the
   `CLAUDE_SKILLS`/`CODEX_SKILLS` derivation): env read, `--update` presence-preservation,
   `OPTIONAL_SKILLS`, filtered comprehensions. Confirm placement is before `MANAGED_DIRS`/
   `MANAGED_FILES` and that no downstream consumer (conflict guard, dir creation, write loop,
   `flag_stale_skills`) references `explain` when excluded. Read the `wrapper.sh` flag wiring
   (usage, init, parse, export).
3. **Release rule.** `WORKSPACE_VERSION == 2` in `installer/main.py` AND the `## v2 — 2026-07-02`
   entry exists in `CHANGELOG.md`, both in the same S1 commit.
4. **Build integrity.** `python3 installer/build.py --check` → must print OK (committed artifact in
   sync with `installer/` source).
5. **Behavioral tests.** `bash tests/retrofit_smoke.sh` → ALL tests pass, including the new Test 5
   default-omit asserts and Test 8 (`--with-explain` presence + byte-match dual-apply).
6. **State integrity.** `python3 scripts/workflow.py validate` → passes.
7. **Live skill untouched.** `git log --oneline -- .claude/skills/explain .agents/skills/explain`
   shows no commits from this phase touching those paths.

## Doc consolidation (only on a passing review)

Consolidate the `phase.md` "Doc impact" running list into new doc versions:

1. **operations** — `python3 scripts/workflow.py doc-new-version --doc operations --source P5.REVIEW
   --summary "Installer: /explain is opt-in via --with-explain; --update preserves an installed copy"`
   Then edit the returned new-version file: carry the previous version's content forward and add the
   new installer-flag section — `--with-explain` (default off; fresh + `--into-existing`), the
   `--update` preservation behavior, and the v2 release note (WORKSPACE_VERSION 2 / CHANGELOG v2).
2. **decisions** — `python3 scripts/workflow.py doc-new-version --doc decisions --source P5.REVIEW
   --summary "Decision: /explain gated opt-in at install time (default off), source kept live"`
   Then edit the returned file: carry content forward and record the decision — `/explain` is
   Mac-coupled (personal KB `~/projects/personal/knowledge`, viewer `localhost:8765`), so it is
   opt-in/default-off; gating is a single install-time filter of the derived skill inventories in
   `installer/main.py` (NOT source removal — the skill stays live and embedded); `--update`
   presence-preservation avoids the Claude/Codex stale-flag asymmetry (explain's `.claude` SKILL.md
   is the only one without `disable-model-invocation: true`); the "public users can use /explain"
   half is deferred as D1.
3. `python3 scripts/workflow.py rebuild-docs` — regenerate `docs/current/*.md`; never hand-edit those.

Keep both new versions consistent with each doc's existing structure and voice (read the previous
version first).

## Verdict

Write `works/phases/active/P5/slices/P5.REVIEW/result.md` (review evidence: what you checked, what
you ran, outcomes; doc versions created). Return a structured verdict for the orchestrator:
- `pass` — everything above holds; docs consolidated.
- `changes_requested` — name the concrete defect(s) and where; skip doc consolidation.
- `blocked` — name the impediment.
