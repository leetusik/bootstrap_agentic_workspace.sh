# Plan — P27.REVIEW (review)

## Scope

Review P27 against `works/phases/active/P27/intent.md` (seven confirmed deliverables plus the out-of-scope list) and `phase.md`. The boundary is what `python3 scripts/workflow.py phase-scope P27` prints: range `fe9ef30..942ee3c`, 14 product files.
- **Engine:** `scripts/workflow.py`.
- **Skills:** `design-cowork`, `create-phase`, `do-next-slice`, `do-whole-phase`.
- **Executors:** both executor bodies.
- **Contract and docs:** `CLAUDE.md`, both READMEs, `CHANGELOG.md`, `docs/retrofit-guide.md` (under `docs/`, so excluded from the product list but changed by S3; review it too).
- **Installer and tests:** `installer/main.py`, the rebuilt `bootstrap_agentic_workspace.sh`, `tests/retrofit_smoke.sh`.

Anything outside the boundary is an observation or a deferred-job candidate, never a finding.

**The acceptance gate is waived** (workspace machinery). No walkthrough and no browser run.

## Validate all slices together

- `bash tests/retrofit_smoke.sh`: **alone in its Bash call**, in the foreground. Expect 201 PASS, 0 FAIL.
- `python3 installer/build.py --check`.
- `python3 scripts/workflow.py validate`.
- `wc -c CLAUDE.md` ≤ 12,288.
- **Live engine check.** On a scratch copy of a legacy repo's design folder (e.g. `~/projects/personal/vocky/docs/reference/design/`, copied with `workflow.py` into your scratchpad), run `design-migrate` dry and then `--apply`, then `design-check`. Also run `design-register` there with `AGENTIC_DESIGN_REGISTRY` pointed at a scratch file and `AGENTIC_DESIGN_DECK_URL` set. **Never run anything in a real product repo, and never touch `~/.config/agentic-workspace/`.**
- **Fresh install.** Run the rebuilt installer into a scratch dir, the way smoke does, and confirm it ships `design-cowork` with `DesignSync` in `allowed-tools` and `design-drafter` without it.

## Judge

1. **Intent coverage.** Is each of the seven deliverables present and coherent?
   - The choice line: asked in `create-phase`, read by both drivers, "absent = drafter".
   - Both loops in `design-cowork`.
   - The `claude-design/` record, skipped by the engine.
   - The contract, executor and driver wording.
   - `design-migrate`.
   - The register hint.
   - v48 with its re-sync note.
2. **Governance invariant.** Spot-check S2's audit (`slices/P27.S2/result.md`) against `git show fe9ef30:.claude/skills/design-cowork/SKILL.md`.
   - Did any shared governance line lose its meaning?
   - Is Implementing / Verifying byte-identical?
   - Does any restored old-loop line contradict schema 1 or the "C wins" decisions without a tool label?
3. **Claude-design loop reads end-to-end.** Walk a claude-design round as the orchestrator would, from `create-phase` through the drivers and `design-cowork`, and look for gaps:
   - where the handoff is written;
   - push;
   - PENDING #1;
   - the DesignSync read-back;
   - landing;
   - SIGNOFF;
   - the remote regroup;
   - superseding;
   - the mockup span.

   Check the drivers' compact branch against the skill (commit counts 2/4, PENDING wording). Check the executors' mockup span under claude-design.
4. **CLAUDE.md.** Every rule and never-rule is kept after S3's byte tightening. Diff `fe9ef30:CLAUDE.md` against HEAD line by line, and name any meaning change.
5. **Engine safety.** `design-migrate` is all-or-nothing with rollback, never deletes, and never runs git. The scan skip covers every walk.
6. **Installer tokenizer trap (from S3).**
   - Assess the risk concretely: can a future edit to any embedded file make the shipped `bootstrap_agentic_workspace.sh` fail under the system Python 3.9, with only the smoke to catch it?
   - Say whether it is a finding in this phase's boundary: S3 edited embedded files and shipped the artifact, and the artifact works today.
   - Recommend a fix slice or a deferred job, with the structural fix named (ASCII-escape the embedded payload in `installer/build.py`, or feed it from a temp file).
   - Note that D3 ("Make installer/build.py smoke-execute the assembled artifact") is related.
7. **Doc impact completeness.** Verify the `## Doc impact` list covers every durable-truth change (operations, decisions, architecture, qa). Return `doc_versions: none — deferred to a docs phase`.
8. **Route every `## Operator Questions` entry** into the verdict as a decision for the orchestrator to relay, or as a deferred job to file:
   - the deferred-job triggers (D18, D20, D21, D23, D24);
   - claude-design push per round vs per slice;
   - the installer trap.

## Output

Write `result.md` with the verdict block first:
- `review_verdict: pass | changes_requested | blocked`;
- numbered findings with proposed fix slices (kind `fix`; risk `high` for any fix to mid-tier work, which is S3's, tier mid);
- deferred-job candidates, each with title, reason and trigger;
- the Operator Question routing;
- `doc_versions: none — deferred to a docs phase`;
- `explain: not written — run /explain for this phase`.

On a non-pass verdict, finish validation and judgment first, then stop before any pass-only step.

Edit `phase.md` `## Now`. Do not commit, do not transition state, do not edit source, do not run `accept-gate` or `review-phase`.
