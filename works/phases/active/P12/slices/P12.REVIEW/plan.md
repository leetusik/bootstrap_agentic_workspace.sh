# P12.REVIEW — phase review

_Auto-mode plan. All seven middle slices are `done` (S1 schema+selection, S2 opt-in lifecycle,
S3 merge machinery, S4 parallel-status, S5 PR+CI+installer, S6 skills+contract, S7 READMEs).
Read `phase.md` in full (§Decomposition, §Findings & Notes, §Constraints, §Settled Decisions
S1–S6, §Doc Impact) and `intent.md` (eight requirements + two amendments), then each slice's
`result.md`. P12 ran in **default single-stream mode**, so this review consolidates docs as
usual — the deferral it built applies only to phases opted into parallel mode._

## 1. Validate all slices together

Re-run each slice's own validation plus state integrity. The smoke harnesses live in the session
scratchpad `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/24f1b5d1-02b6-4fa6-a2fb-e576ba8bfef9/scratchpad/`:

- `python3 <scratchpad>/smoke_s2.py` (45 checks; note its known pre-existing timing flake — see §3),
  `python3 <scratchpad>/smoke_s3.py` (49), `python3 <scratchpad>/smoke_s4.py` (44),
  `bash <scratchpad>/smoke_s5.sh` (26). Temp-repo commits stay inside temp repos.
- `bash tests/retrofit_smoke.sh` — all tests.
- `python3 installer/build.py --check` — artifact in sync.
- `python3 scripts/workflow.py validate` and `next` — clean, pointer sane.
- Backward-compat byte-identity: one rebuild-diff pass (S1/S4 pattern — regenerate, diff the
  generated files with timestamp lines normalized).
- Mirror checks: `diff CLAUDE.md AGENTS.md` = exactly the two title lines; spot-check two skill
  twins; `python3 scripts/workflow.py sync-agents --check` clean.
- If a scratchpad harness is missing (session GC), note it and substitute a minimal inline check
  of the same behavior rather than skipping silently.

## 2. Review against the objective and intent

Walk `intent.md` point by point — the eight requirements and both amendments — and confirm each
landed (phase-scoped selection; branch-per-phase worktree; deferred serialized consolidation;
merge-safe generated files; PR+CI with the gate job; quiet-point merge gate; worktree-not-clone;
`parallel-status`; proactive suggestion at both moments; agent-run integration). Check the hard
constraints: backward compatibility (the byte-identity proof), installer rebuilds in the same
commits (git log), tests stayed lean, docs/skills/contract coherent with the shipped engine.

## 3. Judge the known open items (form the verdict from the complete picture)

Weigh explicitly, with your own reading of the code:

1. **S6 gap 1:** the branch-review consolidation deferral is prose-enforced only —
   `doc-new-version` does not refuse on a parallel stream, though `parallel-consolidated` already
   performs exactly that `current_stream()` check. A silent `vNNNN`/index collision later is the
   failure mode. Cheap engine guard vs prose-is-enough?
2. **S6 gap 2:** `parallel-merge-finish` warns on a parallel stream where `parallel-consolidated`
   hard-refuses — severity inconsistency.
3. **S4 finding:** the smoke_s2 "commit contains exactly the stamp + regenerated files" check has
   a second-resolution timing flake (reproduced on unmodified HEAD) — scratchpad-only, but decide
   whether the underlying nondeterminism (which files land in `parallel-start`'s engine commit)
   deserves a fix or a note.
4. Anything else your validation or reading surfaces.

Then form the verdict: `pass` | `changes_requested` | `blocked`. If `changes_requested`, complete
ALL validation and judgment first so every finding lands in this one cycle, number the findings,
propose concrete fix slices (id, name, kind `fix`, risk, one-line scope each), **stop before any
consolidation**, and return. Do not run any pass-only step on a non-pass verdict.

## 4. On a passing verdict ONLY: consolidate the docs

Consolidate `phase.md` §Doc Impact into new versions — never patch old files under
`docs/versions/`, never hand-edit `docs/current/*`:

- **`architecture`** (S1 note): the `execution` block + stream-scoped selection.
- **`operations`** (S2–S6 notes): the six `parallel-*` commands, hints, CI, the parallel-phase
  skill and skill/contract gates.
- **`decisions`** (S3, S5, S6 notes): regenerate-not-merge rationale; no-gh-wrapper, seed-once CI,
  narrowed push deny + additive-merge consequence; commit-convention carve-out and
  contract-routes/skill-explains split; and **supersede, not append**: rewrite the existing
  "parallel fan-out — rejected for now" decision to record that P12 ships phase-level parallelism
  while slice-level fan-out stays rejected.

For each: `python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source
P12.REVIEW`, edit only the printed `edit_path`, then `python3 scripts/workflow.py rebuild-docs`
once at the end, and `python3 scripts/workflow.py validate`.

## 5. Return

`result.md` in this slice's folder (validation matrix, intent walk, findings + judgment,
consolidation record or the stop). Return the structured verdict including `review_verdict`
(`pass|changes_requested|blocked`), `doc_versions` (on pass), and the fixed pointer
`explain: not written — run /explain for this phase`. No commits, no status transitions (the
orchestrator records the verdict via `review-phase`), no archiving.
