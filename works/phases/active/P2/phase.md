# Phase P2: Archiving Workflow: Explicit Archiving, First-Class Partial Archive, and rotate-backlog

## Objective

Refine the archiving workflow and document it consistently across the contract, the skills, the tooling, and the bootstrap script. Decisions already confirmed with the operator: (1) Archiving is manual and user-requested only, never automatic — a passing review still only marks a phase done and leaves it in active/. (2) Default end-state process stays: once every active phase is done, archive them all together with archive-all. (3) Promote single-phase partial archiving (archive-phase <P>) from a manual escape hatch to a first-class, supported option, useful when there are many phases and only some are done. (4) Add a new rotate-backlog operation (a skill plus a workflow.py command, mirrored into both .claude/skills and .agents/skills) that archives every phase currently done, leaves in-progress phases untouched, then rebuilds the backlog/index/state dashboards — the partial rotation that archive-all cannot do because it requires ALL phases to be done. CRITICAL CONSTRAINT: every rule, skill, and tooling change must be applied in BOTH the live repo files AND their embedded copies inside bootstrap_agentic_workspace.sh (CLAUDE.md, AGENTS.md, the affected skills, and workflow.py are all duplicated inside the bootstrap heredocs), and CLAUDE.md and AGENTS.md must stay in sync. Also update the Workflow Commands list and the wording in the archive-phase, do-next-slice, do-whole-phase, and review-phase skills to match, and consider recording the decision in docs (decisions.md). The DECOMP slice will break this into slices and verify the exact embed sites.

## Context

This is a meta-phase: it edits the workspace's own contract, skills, and tooling. The hard part is not the logic (rotate-backlog reuses existing helpers) but the **dual application** — every live file has a byte-for-byte twin embedded in `bootstrap_agentic_workspace.sh`, and `CLAUDE.md` must equal `AGENTS.md`. Slices are factored by **artifact layer** (engine → skills → contract → decision doc) so that within each slice the live file and its embedded twin are edited together and never drift between slices.

## Decomposition

_Slice breakdown — filled by the `P2.DECOMP` slice._

Four middle slices, ordered engine → skills → contract → decision (outside-in: capability, then interface, then documentation, then rationale). Each slice keeps live + embedded copies in sync as part of its own definition of done.

- **P2.S1 — Engine: `rotate-backlog` command + archive repositioning (workflow.py, live + embedded).** Add a `rotate_backlog` function and `rotate-backlog` subparser to `scripts/workflow.py`, reusing `_phase_blockers` + `_archive_one`. Reword the `archive-phase` subparser help and the `archive_phase` comment to position single-phase archiving as first-class (not just an "escape hatch"). Mirror every change verbatim into the `WORKFLOW_PY` heredoc in the bootstrap (lines ~1116–1969). Verify with the test plan below. (kind: implementation, risk: medium)
- **P2.S2 — Skills: new `rotate-backlog` skill + archive-phase repositioning + cross-references (live 3-file skill + bootstrap COMMAND_SKILLS).** Create the new `rotate-backlog` skill in all three live files and add a `COMMAND_SKILLS` entry in the bootstrap. Rewrite the `archive-phase` skill so it presents three first-class options (archive-all / rotate-backlog / archive-phase). Update the archiving guidance in `do-next-slice`, `do-whole-phase`, and `review-phase` to mention `rotate-backlog` as the partial-rotation option. Apply to both `.claude` and `.agents` copies and the embedded bodies. (kind: implementation, risk: medium)
- **P2.S3 — Contract: CLAUDE.md ≡ AGENTS.md + bootstrap WORKFLOW_DOC.** Update the Workflow Commands list (add `rotate-backlog`; reword the `archive-phase` line from "escape hatch" to first-class partial archive) and the Hard Rules archiving bullet. Apply identically to `CLAUDE.md`, `AGENTS.md`, the `WORKFLOW_DOC` heredoc embed, and the stray archiving line in the embedded P1 `phase.md` (bootstrap line ~1085). Keep `CLAUDE.md` byte-equal to `AGENTS.md` (modulo the title + cross-reference line). (kind: implementation, risk: low)
- **P2.S4 — Decision record: decisions.md doc version.** Run `doc-new-version --doc decisions --source P2.S4`, fill in the archiving-workflow decision (manual archiving; archive-all default; first-class archive-phase; new rotate-backlog), `rebuild-docs`, and `validate`. (kind: docs, risk: low)

## Findings & Notes

_Durable findings and cross-slice notes; `DECOMP` seeds this, and each slice appends when it finishes._

### VERIFIED EMBED-SITE MAP (read this before editing anything)

Every change has a live file and an embedded twin in `bootstrap_agentic_workspace.sh`. Confirmed during decomposition:

**1. Engine — `scripts/workflow.py`**
- Live: `scripts/workflow.py`.
- Embedded: `WORKFLOW_PY = r'''...'''` heredoc, bootstrap lines **1116–1969**. **Verified byte-identical to live** (38087 chars both). Any engine edit must be applied to both, and they must remain identical (re-diff after editing).
- Relevant live functions: `_phase_blockers` (L657), `_archive_one` (L671), `archive_phase` (L697), `archive_all` (L710), `review_phase` (L531). Argparse subparsers: `archive-phase` (L836), `archive-all` (L841).
- Embedded twins of those: `_phase_blockers` (L1772), `_archive_one` (L1786), `archive_phase` (L1812), `archive_all` (L1825), `review_phase` (L1646); subparsers `archive-phase` (L1951), `archive-all` (L1956).

**2. Skills — three files per skill, all generated in bootstrap from `COMMAND_SKILLS`**
- Live per skill: `.claude/skills/<name>/SKILL.md`, `.agents/skills/<name>/SKILL.md`, `.agents/skills/<name>/agents/openai.yaml`.
- `.claude` vs `.agents` SKILL.md differ ONLY by two frontmatter lines (`allowed-tools:` and `disable-model-invocation: true`) — present in `.claude`, absent in `.agents`. Bodies are identical.
- Embedded: `COMMAND_SKILLS = [...]` list, bootstrap lines **130–302**; generators `claude_skill`/`codex_skill`/`codex_openai_yaml` at **1973–2003**; write loop at **2006–2009**. Adding a skill = add one dict (`name`, `desc`, `tools`, `body`) to `COMMAND_SKILLS`; the loop and `MANAGED_DIRS`/`MANAGED_FILES` (extended at L329–336) pick it up automatically — no manual managed-list edits needed.
- Affected existing skill entries in `COMMAND_SKILLS`: `do-next-slice` (L132, archiving guidance at body L157), `do-whole-phase` (L165, archiving line at body L184), `review-phase` (L189), `archive-phase` (L265, desc L266, body L268–279).

**3. Contract — `CLAUDE.md` and `AGENTS.md` (must stay in sync)**
- Live: `CLAUDE.md` and `AGENTS.md` (identical except the H1 title and the "Equivalent to `X`" cross-reference line).
- Embedded: `WORKFLOW_DOC = """..."""`, bootstrap lines **403–483**, written to BOTH files at L484–485. So one edit to `WORKFLOW_DOC` updates both embedded contracts.
- Archiving touch-points in the contract: Hard Rules archiving bullet (live CLAUDE.md L54 / embed L452) and the Workflow Commands list `archive-*` line (live L77 / embed L475).
- STRAY extra site: the embedded P1 `phase.md` Constraints bullet at bootstrap line **1085** ("...archived together with `archive-all` once every active phase is done.") — update for consistency if the archiving story changes. (This is bootstrap-only; there is no live twin to sync since the live P1 phase.md was already generated.)

**4. Decision doc**
- Live: `docs/versions/decisions/vNNNN_*.md` (new version via `doc-new-version`) + regenerated `docs/current/decisions.md`. `decisions.md` is currently an empty bootstrap template — clean slate. No bootstrap embed for doc *content versions* (bootstrap only seeds `v0001_bootstrap`).

### `rotate-backlog` SPEC (shared contract for S1/S2/S3)

- **Purpose:** the partial rotation `archive-all` cannot do. `archive-all` refuses unless EVERY active phase is done; `rotate-backlog` archives exactly the phases that are cleanly archivable right now and leaves the rest active.
- **Behavior:** iterate `phase_dirs()`; for each, archive it iff `_phase_blockers(pdir)` is empty (i.e. all slices done AND review verdict `pass`). Use `_archive_one(pdir, forced=False)` for each. Then call `rebuild_index_and_state()` once at the end.
- **No `--force` flag.** By definition it only touches phases with no blockers, so force has no meaning. Keep the surface minimal. (archive-phase/archive-all keep their `--force`.)
- **Output:** if nothing is archivable, print a friendly "no done phases to rotate; N phase(s) still active" and still run a harmless rebuild. Otherwise print the archived phase ids + their archive paths, mirroring `archive_all`'s output style.
- **Reuse, don't duplicate:** share `_phase_blockers` and `_archive_one` with archive-phase/archive-all. Do not fork the archive logic.
- **Relationship to the three archive operations (document this consistently):**
  - `archive-all` — batch-archive ALL active phases; refuses unless every one is done. The default end-state sweep.
  - `rotate-backlog` — archive every CURRENTLY-done phase, leave in-progress ones; partial rotation when only some are done.
  - `archive-phase <P>` — first-class single-phase archive (review-passed by default; `--force` for exceptional cleanup).

### S1 TEST PLAN (engine)

After implementing `rotate-backlog` in live workflow.py:
1. `python3 scripts/workflow.py rotate-backlog` with the current tree (P1 done+pass, P2 in_progress) should archive **P1 only** and leave **P2** active. BUT — see the sequencing note below; do NOT actually run a destructive rotate mid-phase.
2. Safer: write a throwaway check, or reason via a temp copy. The reviewer/operator can exercise it for real once P2 itself is done. Record the intended behavior and any non-destructive verification (e.g. `--help` shows the subcommand, `argparse` parses, embedded==live re-diff) in `result.md`.
3. Always re-run the embedded-vs-live diff (the one used in DECOMP) and `python3 scripts/workflow.py validate` after editing.

### S1 DONE — engine landed (note for S2/S3)

- `rotate-backlog` is implemented in live `scripts/workflow.py` and the embedded twin (byte-identical, 39707 chars). It reuses `_phase_blockers` + `_archive_one`; no `--force`.
- **Canonical command help strings** (reuse these verbatim in skills + contract so everything matches):
  - `archive-phase` → "Archive a single review-passed phase (first-class; use when only some phases are done)"
  - `archive-all` → "Batch-archive ALL active phases at once; only when every phase is done (last review slice complete)"
  - `rotate-backlog` → "Archive every currently-done phase and leave in-progress phases active, then rebuild (partial archive-all)"
- **Output strings** (for anyone documenting behavior): success → "rotated N done phase(s) to archived:" + per-phase lines + "left N phase(s) active: ..."; nothing-ready → "no done phases to rotate; N phase(s) still active: ...".
- **Embed-sync method that works:** edit live `workflow.py`, then regenerate the bootstrap `WORKFLOW_PY` heredoc body by slicing between `WORKFLOW_PY = r'''` and the next `'''` and substituting the live file (assert live has no `'''`). Re-diff to confirm identical. The full temp-dir bootstrap run is the strongest check.
- Added a live-only `.gitignore` (`__pycache__/`, `*.pyc`) — repo hygiene, not mirrored to bootstrap.

### S2 DONE — skills landed (note for S3)

- New `rotate-backlog` skill exists (3 live files + `COMMAND_SKILLS` entry). `archive-phase` skill rewritten to present three first-class options. `do-next-slice`/`do-whole-phase`/`review-phase` now say archiving is a separate manual step listing all three ops.
- **Sync method confirmed and reusable:** edit the bootstrap generator (`COMMAND_SKILLS` for skills; `WORKFLOW_DOC` for the contract), regenerate the live artifacts by bootstrapping into a temp dir and copying, then `diff -rq` live vs a fresh bootstrap to prove identity. For S3, `CLAUDE.md`/`AGENTS.md` are generated from `WORKFLOW_DOC` (written to both at bootstrap), so the same approach applies — and it auto-keeps CLAUDE.md ≡ AGENTS.md.
- **Phrasing to reuse in the contract (S3) for consistency:** "Archiving is a separate, manual step." The three ops: `archive-all` (full sweep, needs every phase done), `rotate-backlog` (partial — archive the done ones, leave the rest), `archive-phase <P>` (single review-passed phase).
- Standing invariants to re-check after S3: `diff -rq` live skills == fresh bootstrap; `diff -q` live workflow.py == fresh bootstrap; `diff` CLAUDE.md vs AGENTS.md (only title + cross-ref line differ); `validate`.

### S3 DONE — contract landed (note for S4/REVIEW)

- `CLAUDE.md`, `AGENTS.md`, and the bootstrap `WORKFLOW_DOC` now describe archiving as a separate manual step with all three ops; Workflow Commands list includes `rotate-backlog`. The bootstrap P1 `phase.md` template line was updated for future workspaces.
- **Decision:** live `works/phases/active/P1/phase.md` archiving lines (L68, L75) left unchanged — P1 is historical; its notebook records what P1 did and should not be rewritten.
- **All standing invariants pass:** `CLAUDE.md` body ≡ `AGENTS.md` body; live `CLAUDE.md`/`AGENTS.md`/skills/`workflow.py` all == fresh bootstrap output; `validate` passes. The only remaining work is S4 (decisions doc) and the REVIEW.
- For S4: `decisions.md` is an empty template; fill the Decision Log entry with this archiving-workflow decision (manual archiving; archive-all default; first-class archive-phase; new rotate-backlog) via `doc-new-version --doc decisions --source P2.S4`, then `rebuild-docs` + `validate`. Doc content versions are NOT embedded in the bootstrap, so S4 has no bootstrap twin.

### S4 DONE — decision recorded (note for REVIEW)

- `decisions` doc `v0002` records the archiving-workflow decision (manual archiving; archive-all default; first-class archive-phase; new rotate-backlog) with alternatives, consequences, source P2. `docs/current/decisions.md` regenerated; `validate` passes.
- **All four middle slices complete.** Phase deliverables: rotate-backlog command (S1), rotate-backlog skill + archive-phase repositioning (S2), contract sync (S3), decision record (S4). The REVIEW should re-check the standing invariants (CLAUDE≡AGENTS; live==fresh-bootstrap for contract/skills/engine; validate) and confirm the objective's dual-apply constraint was honored everywhere.

### SEQUENCING CAUTION (important)

P1 is currently `done`+`pass` and sits in `active/`. `rotate-backlog` and `archive-all` would archive P1 the moment they run. **Do NOT run a real `rotate-backlog`/`archive-all`/`archive-phase` during this phase** — it would archive P1 and disrupt the working tree mid-flight. Verify the new command non-destructively (help text, arg parsing, code review, embedded==live diff). Real archiving is an operator action for later. This phase only *adds and documents* the capability.

## Constraints

- Dual-apply every change: live file + its bootstrap-embedded twin. Re-diff embedded `workflow.py` against live after S1; they must stay byte-identical.
- `CLAUDE.md` and `AGENTS.md` stay in sync (only the title + cross-ref line differ).
- Reuse `_phase_blockers`/`_archive_one`; do not duplicate archive logic.
- Do not hand-edit `docs/current/*.md`; use `doc-new-version` + `rebuild-docs`.
- Do not actually archive any phase during P2 (would remove P1 from active/). Verify non-destructively.
- Keep `works/backlog.md`/`works/deferred.md` lean (generated).

## Open Questions

- None blocking. `rotate-backlog` semantics, naming, and the no-`--force` decision are settled above. If the operator later wants a `--dry-run` on rotate-backlog, that is a follow-up, not part of this phase.
