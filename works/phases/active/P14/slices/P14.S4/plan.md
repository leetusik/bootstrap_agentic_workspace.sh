# P14.S4 — Ship the replacement through installer and release lifecycle

## Goal

Release the completed Codex visual-cowork replacement as one coherent workspace version. Fresh
installs, non-destructive retrofits, and in-place updates must all receive the Codex-native skill,
inline orchestration, executor guardrails, shared harness branching, and correct metadata while
preserving Claude Code's established Claude Design/DesignSync behavior and adopter-owned work.

## Context and release boundary

- Read the P14 intent, phase notes, and S1-S3 results before editing. Treat their selected contract as
  settled; this slice ships and explains it rather than redesigning it.
- Current release is `WORKSPACE_VERSION = 29` with top changelog entry v29. Ship P14 as **v30**, dated
  **2026-08-13**, and keep changelog entries newest first.
- Preserve the 17+17 skill inventory and `allow_implicit_invocation: true` only for `design-cowork`.
- Preserve `.claude/skills/design-cowork/SKILL.md` byte-for-byte at blob
  `0e3a1766ebb85126ab97356f4fdbc5f82753067e` and preserve the Claude runner/executor semantics.
- `bootstrap_agentic_workspace.sh` is generated; edit live source, then rebuild it.
- Keep tests concise and extend the existing lifecycle smoke rather than creating a sprawling suite.
- Do not create durable doc versions. The review slice consolidates the existing decisions/operations
  impact after the phase passes.

## Implementation

1. Extend `tests/retrofit_smoke.sh` with focused, high-value assertions for the shipped visual path:
   - source inventory/metadata identifies Codex `design-cowork` as implicitly invocable and carries the
     ImageGen-or-exact-reference, durable record, one normal signoff, explicit pending resume,
     main-thread/no-executor, separate `DECOMP2`, and real-browser fidelity contract;
   - both Codex execution skills contain the inline first-run/resume behavior and never infer approval
     from a bare automatic invocation;
   - both Codex executor tiers refuse `co-work` on orchestrator-ownership grounds and do not contain a
     stale DesignSync capability claim;
   - the shared installed contract names both harness paths and their shared no-implementation,
     two-pass, untrusted-data, faithful-build invariants;
   - fresh install and retrofit contain the expected Codex skill body/metadata; update refreshes a
     deliberately stale pre-v30 Codex visual skill/metadata copy without flagging the still-current
     package as stale, while existing non-destructive/update guarantees remain intact;
   - v30 source, changelog, embedded installer, and fresh workspace marker agree.
   Reuse the existing scratch workspaces and dual-apply loop. Avoid generated images, browser launches,
   network calls, or a synthetic phase mutation test: these are source/installer lifecycle assertions.

2. Update the user/maintainer surfaces that need to explain the new behavior accurately:
   - `README.en.md`: add a concise visual-work section near the execution example/skills surface. State
     that `design-cowork` fires automatically for product visual work; Codex normally uses built-in
     ImageGen or an exact approved reference, persists the exact record, asks for one visual signoff,
     then implements in separate slices and checks in a real browser. Mention capability/revision
     halts as exceptions and distinguish Claude Code's Claude Design path. Emphasize that operators do
     not approve generation or every intermediate plan.
   - `README.md` (Korean): add the equivalent concise guidance in natural Korean.
   - `docs/retrofit-guide.md`: state that the installed harness-specific design workflow and Codex
     metadata arrive through retrofit/update, including the normal one-signoff boundary, without
     implying that retrofit overwrites pre-existing operator-owned files.
   - `installer/README.md`: document the intentional harness-specific `design-cowork` bodies alongside
     the already-intentional independent Codex execution bodies, including the preserved Claude blob
     guard if useful to maintainers.
   - `installer/main.py`: update the fresh-install completion summary only if needed so a new adopter
     can discover the automatic visual workflow without reading implementation details.
   Keep these statements user-facing and concise; do not duplicate the full skill contract.

3. Release v30:
   - change `installer/main.py` `WORKSPACE_VERSION = 29` to `30`;
   - add `## v30 — 2026-08-13` at the top of `CHANGELOG.md` describing the Codex-native visual path,
     one normal signoff and exceptional halts, inline runner resume semantics, Claude preservation,
     install/update delivery, and browser-fidelity handoff;
   - include clear migration notes: preview with `--update --dry-run`; updates refresh workspace-managed
     skill/runner/executor/contract files while preserving phases/docs and seed-once
     `executors.toml`; no plugin or Figma integration is required; no state migration or
     `sync-agents` rerun is required solely for this release unless the update output reports agent
     drift from an adopter override (the installer already routinely instructs `sync-agents`).

4. Rebuild `bootstrap_agentic_workspace.sh` from source after all changes.

5. Write `result.md` from scratch and append a concise release/lifecycle finding to `phase.md`. Reuse
   the existing combined `decisions`/`operations` Doc impact line unless this work establishes a truly
   different durable area.

## Validation

Run and record:

1. `python3 -m py_compile installer/build.py installer/main.py`
2. `bash -n tests/retrofit_smoke.sh`
3. `python3 scripts/workflow.py sync-agents --check`
4. `python3 installer/build.py --check`
5. `bash tests/retrofit_smoke.sh`
6. `python3 scripts/workflow.py validate`
7. Focused release assertions that:
   - `WORKSPACE_VERSION` is 30;
   - the top and only v30 changelog heading is dated 2026-08-13;
   - the built artifact embeds version 30 and the exact current Codex design/runner/executor/contract
     payloads;
   - the Claude design skill retains the required blob;
   - README English/Korean and retrofit/installer guidance all name the correct harness paths and one
     normal Codex signoff without claiming Figma is mandatory.
8. `git diff --check`

## Boundaries

- No visual generation, product design choice, UI implementation, browser automation, external write,
  plugin installation, push, doc versioning, workflow transition, or commit.
- Do not alter the selected S1-S3 mechanics merely to simplify smoke assertions or prose.
- Do not edit historical `docs/versions/*` or generated `docs/current/*`.
- Preserve unrelated user changes and all adopter non-destructive lifecycle behavior.
