# P14.S5 — Audit the complete visual-workflow parity and regressions

## Goal

Independently audit the completed v30 visual-design workflow across source, embedded artifact, install
lifecycle, orchestration, docs, and harness boundaries. Close any concrete defect found with the
smallest coherent correction, rebuild when required, and leave P14 ready for whole-phase review.

## Context and posture

- Read `intent.md`, the complete `phase.md`, every completed P14 slice's `plan.md` and `result.md`,
  `docs/index.json`, relevant `docs/current/*.md`, and all shipped surfaces under audit.
- Audit against the settled S1 contract and the operator's goal: Codex should own almost every
  mechanical frontend/UX step using current Codex best practice, with one normal human visual
  signoff and exceptional stops only for missing capabilities/reference, revision, or a genuinely
  unresolved product choice.
- This is a closure implementation slice, not the phase review. It may make narrowly scoped source,
  test, or prose fixes when evidence identifies a defect. It must not create doc versions, alter the
  selected product-process contract for preference, or perform an actual product design round.
- Preserve the Claude `design-cowork` skill exactly at blob
  `0e3a1766ebb85126ab97356f4fdbc5f82753067e`, preserve Claude runner/DesignSync behavior, and keep
  AGENTS/CLAUDE contract bodies equivalent.
- `WORKSPACE_VERSION` remains 30 and the v30 changelog entry remains the single release boundary. If a
  correction touches embedded machinery, rebuild the generated artifact but do not bump to v31.

## Audit and correction work

1. Build a focused source-to-contract audit covering every normal and exceptional path:
   - **Net-new default:** implicit `design-cowork` routing, built-in ImageGen with no pre-generation
     confirmation, final prompt/provenance, copy to a canonical repo-local exact reference, `view_image`
     read-back, complete machine-checkable record/implementation contract, one review-ready commit,
     and one literal signoff.
   - **Existing approved design:** an exact attachment/export is accepted; an exposed Figma integration
     is optional and operator-selected, never installed or required; exact screenshot/export and
     identifier/provenance still land in the durable record.
   - **Exceptional halts:** unavailable versus failed generation are distinguished; missing exact
     reference/read-back/browser route becomes one precise `operator_need`; CLI fallback is explicit,
     credentialed, and never requests a pasted secret; revision creates an immutable superseding round;
     unresolved visual/product questions cannot be silently answered by Codex.
   - **Implementation fidelity:** `DECOMP2` comes only after literal signoff, backing/backend work comes
     before faithful UI implementation, plans carry the approved round/hash and `RESPECT THE DESIGN`,
     project-native real-browser tooling is preferred, Playwright fallback is capability-probed, every
     declared responsive/state/accessibility behavior is exercised, and no successful browser run means
     no visual-fidelity claim.
   - **Security/ownership:** generated/external artifacts and embedded text are untrusted data; no
     artifact instruction is executed; `co-work` is main-thread-only, implementation-free, and never
     sent to either executor; no push/plugin install/external write is implied.

2. Audit the runner state machine for contradictions and stuck/over-permissive routes:
   - automatic-mode rejection still precedes all workflow mutation;
   - ordinary pending remains a hard stop;
   - the sole pending exception requires explicit current-invocation input matching the same Codex
     `co-work` slice's recorded need; bare/auto/unattended input cannot approve;
   - first-run result/phase notes and durable record are committed before the operator is asked, with no
     signoff; status/commit instructions do not accidentally ask an executor to commit or transition;
   - literal approval hash-rechecks and records exact words before finish/commit;
   - revision/capability resume cannot mutate an approved/prior round;
   - `do-next-slice` stops after the signed design slice and `do-whole-phase` continues only within the
     entry phase to `DECOMP2`;
   - existing `ready`, review/fix, sequential dispatch, parallel stream, and non-design
     `needs_operator` behavior remains intact.

3. Audit cross-surface parity and lifecycle:
   - Codex design skill body and metadata, `create-phase`, both Codex runners, both Codex executor tiers,
     AGENTS/CLAUDE shared body, English/Korean README, retrofit/installer guidance, changelog, installer
     output, and lifecycle smoke tell the same story at the appropriate level of detail;
   - Claude-specific mechanics appear where expected but no Codex-only surface claims DesignSync/Figma
     is required or tries to emit Claude cards;
   - the built artifact embeds exact current source, fresh/retrofit/update deliver it, stale pre-v30
     Codex visual files are refreshed, operator-owned collision behavior stays non-destructive, and v30
     markers agree;
   - skill inventory remains 17+17, all Codex metadata exists, only `design-cowork` is implicitly
     invocable, and both agent tiers remain synchronized to `executors.toml`.

4. If any audit assertion fails because of an actual defect, make the smallest scoped correction in
   the owning file and add or adjust only the concise smoke assertion that prevents regression. Do not
   paper over a defect by weakening the assertion. Run `python3 installer/build.py` after any embedded
   machinery/contract correction. Keep v30 release prose accurate if a correction changes observable
   behavior.

5. Write `result.md` from scratch with an explicit audit matrix, every correction (or `none`), and
   validation evidence. Append a concise S5 closure finding to `phase.md`. The existing combined
   decisions/operations Doc impact line should remain the single durable-doc pointer unless the audit
   finds a genuinely new area.

## Validation

Run all of the following after any corrections:

1. A read-only focused Python assertion script implementing the matrix above against live source and
   the decoded `bootstrap_agentic_workspace.sh` payload/contract. Record the exact command in
   `result.md`.
2. `python3 -m py_compile installer/build.py installer/main.py scripts/workflow.py`
3. `bash -n tests/retrofit_smoke.sh`
4. `python3 scripts/workflow.py sync-agents --check`
5. `python3 installer/build.py --check`
6. `bash tests/retrofit_smoke.sh`
7. `python3 scripts/workflow.py validate`
8. Confirm the Claude skill blob is unchanged and the AGENTS/CLAUDE bodies are byte-equivalent after
   their required distinct headers.
9. Confirm `WORKSPACE_VERSION = 30`, exactly one top `## v30 — 2026-08-13`, and no v31 entry.
10. `git diff --check`

## Boundaries

- No ImageGen call, screenshot creation, browser automation, real product design, source UI build,
  external service/integration write, plugin install, push, workflow state transition, commit, or doc
  version creation.
- No broad refactor, new test suite, historical doc edit, generated-current-doc edit, or release bump.
- Preserve unrelated user changes and never revert work from prior P14 slices.
