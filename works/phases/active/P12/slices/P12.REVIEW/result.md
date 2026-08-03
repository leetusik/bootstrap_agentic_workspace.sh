# P12.REVIEW — phase review result

**Verdict: `changes_requested`.** One finding, one proposed fix slice. Everything else in the phase
landed as specified: all eight intent requirements and both amendments are implemented, backward
compatibility is proven byte-identical against the true pre-P12 baseline, and the docs/skills/
contract are coherent with the shipped engine. The single finding is a missing engine guard on
`doc-new-version` — the one command the intent named as "can never collide" is the only one in the
parallel family left unguarded.

Per the pass-only rule, **no doc versions were created**. `phase.md` §Doc Impact is complete and
correct (verified below); it is ready to consolidate verbatim the moment the fix lands and the
re-review passes.

## 1. Validation — all slices together

Every slice's own validation was re-run, not just the last one's. All scratchpad harnesses survived
the session; nothing was substituted.

| # | Command | Outcome |
|---|---|---|
| 1 | `python3 <scratchpad>/smoke_s2.py` (45 checks) | 3 of 4 runs **pass**; 1 run failed the known timing flake — characterized below, engine is correct |
| 2 | `python3 <scratchpad>/smoke_s3.py` (49 checks) | **pass** — `SMOKE PASSED (49 checks)` |
| 3 | `python3 <scratchpad>/smoke_s4.py` (44 checks) | **pass** — `SMOKE PASSED (44 checks)` |
| 4 | `bash <scratchpad>/smoke_s5.sh` (26 checks) | **pass** — `ALL S5 MATRIX CHECKS PASSED` (installer matrix A–D) |
| 5 | `bash tests/retrofit_smoke.sh` | **pass** — `ALL RETROFIT SMOKE TESTS PASSED` |
| 6 | `python3 installer/build.py --check` | **pass** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| 7 | `python3 scripts/workflow.py validate` | **pass** — `Workflow validation passed.` |
| 8 | `python3 scripts/workflow.py next` | **pass** — `current_phase=P12 current_slice=P12.REVIEW next_slice=none`, pointer sane |
| 9 | Backward-compat byte-identity vs. **pre-P12** (`<scratchpad>/rebuild_diff_review.py`) | **pass** — 17 artifacts `IDENTICAL` |
| 10 | `diff CLAUDE.md AGENTS.md` | **pass** — exactly the two title lines (L1, L3), nothing else |
| 11 | Skill twins: `parallel-phase`, `review-phase` | **pass** — each differs by exactly the two Claude-only frontmatter keys |
| 12 | `python3 scripts/workflow.py sync-agents --check` | **pass** — `agent files in sync with executors.toml/defaults` |

**On check 9 — the byte-identity proof was strengthened.** The S1/S4 harness compares the working
tree against `HEAD`, but HEAD now *contains* all of S1–S7, so that comparison had become
tautological (a guaranteed no-diff proving nothing). I re-pointed it at `6f9e3c7` — the last commit
before P12 began — so the diff is a genuine before/after of the whole phase. Result: all 17
generated artifacts (4 dashboards + 11 `docs/current/*.md` + `next` + `validate` output, timestamps
normalized) are byte-identical. **Backward compatibility is proven for the phase as a whole, not
just per slice.** This is the constraint the phase called hard, and it holds.

Supplementary coherence checks (all clean): the six documented `parallel-*` command lines in
`CLAUDE.md` match `workflow.py --help` exactly, name for name; `.github/workflows/workspace-ci.yml`
parses with two jobs (`validate`, `parallel-gate`); `.claude/settings.json` denies
`Bash(git push --force:*)` and no longer the blanket push; `WORKSPACE_VERSION = 24`; no stale skill
count survives in either README; `ls .claude/skills` = 16, `.agents/skills` = 15 (`do-whole-phase`
is Claude-only), matching S7's corrected counts.

**Installer rebuild discipline** (`git show --name-only` per commit): every one of the six machinery
commits `e4590da`, `8c425e5`, `c639610`, `140e1d1`, `c381646`, `d953bc6` carries the rebuilt
`bootstrap_agentic_workspace.sh` in the *same* commit; `fbdd735` (READMEs) touched no machinery and
correctly carries no artifact. Constraint satisfied.

**Tests stayed lean.** `tests/` still holds exactly one file (`retrofit_smoke.sh`, adjusted not
expanded). Every scenario harness lives in the session scratchpad. No fixture sprawl. All temp-repo
commits stayed inside their temp repos — the real repo has no P12.REVIEW commit and a clean
`git status` apart from the orchestrator's own pre-existing state.

## 2. Intent walk — eight requirements + two amendments

| Intent item | Landed | Evidence |
|---|---|---|
| 1. No global next-job pointer contention | **yes** | `current_stream`/`stream_phases` filter upstream in `rebuild_index_and_state`; main skips opted-in phases, a worktree sees only its own; `pending` halts only its own stream (smoke_s2 asserts both directions) |
| 2. Branch-per-phase in a worktree | **yes** | `parallel-start` cuts `phase/P<N>-<slug>` + `git worktree add` from the stamp commit; creation stays on main so numbering is serialized |
| 3. Consolidation deferred to serialized post-merge on main | **partly — see Finding 1** | The *flow* exists end to end (`parallel-merge-finish` → `doc-new-version` → `parallel-consolidated`) and every doc surface states it; but the "can never collide" guarantee is prose-only |
| 4. Merge-safe generated files | **yes** | `.gitattributes` (`merge=union` on the append-only log; regenerate-not-merge documented for the five generated artifacts) + `parallel-merge-finish`; smoke_s3 proves a real divergent merge conflicts only in the four dashboards and regenerates truthfully |
| 5. Full PR + CI layer | **yes** | `workspace-ci.yml`: `validate` everywhere, upstream-only checks shell-guarded, `parallel-gate` job on `phase/*` PRs off the head sha. *Never executed on GitHub* — see §4 |
| 6. Quiet-point merge gate | **yes** | `parallel-gate`: branch phase `done`+`pass` read from the branch (never main's stale copy), main side quiet per `BUSY_PHASE_STATUSES`; exit-coded for CI; the working-tree-is-not-main guard closes the self-grading hole |
| 7. Worktree, not clone | **yes** | `git worktree add`, never a second clone; teardown removes it; stream detection is branch-based, so a teammate's plain clone behaves identically — no marker file |
| 8. Cross-stream visibility | **yes** | `parallel-status`: pointer + per-phase branch-side slice table via `git show`/`git ls-tree`, verdict naming the next command; the only command that writes nothing (smoke hashes `works/`+`docs/` around all 8 invocations) |
| A1. Proactive suggestion at both moments | **yes** | `new_phase` hint (another default-stream phase `in_progress`) and `cmd_next` hint via `parallel_start_hint` (a planned phase waiting behind an in-progress one); both name `parallel-start`, run nothing, and are mirrored in `create-phase` / `do-next-slice` / `do-whole-phase` skill text |
| A2. Agent-driven PR/merge | **yes** | The 10-step sequence lives in the `parallel-phase` skill, with the gate ruling: closed gate ⇒ stop and report. The commit-convention carve-out authorizes exactly that flow and nothing wider |

**One deliberate mechanism substitution, accepted.** Intent item 1 speaks of "`next` scoped to a
phase" and item 8 of "e.g. `status --all`". The phase implemented scoping by *git branch* (no
`--phase` flag) and named the view `parallel-status`. Both were settled decisions (S1 §2, S4 §1)
with sound reasoning — branch-derived membership needs no marker file and cannot drift from where
the work actually is, and the intent's own wording was illustrative ("e.g."). Every *functional*
requirement behind those phrasings is met. Not a finding.

## 3. Findings

### Finding 1 — `doc-new-version` is the one parallel-unsafe command left unguarded (**must fix**)

Intent item 3 promises that `vNNNN` allocation and `docs/index.json` / `docs/current/*` "can
**never** collide between parallel phases." The engine does not deliver *never* — it delivers
"as long as every agent obeys the prose." Reading the code:

- `new_doc_version` (`scripts/workflow.py:300`) performs **no** stream check. It will happily
  allocate a version from inside a parallel worktree.
- Its sibling `parallel_consolidated` (`:1294`) hard-refuses the *identical* condition four lines
  into its guard list: `stream = current_stream(all_active_phases())` → `raise SystemExit`. So the
  feature's own convention is engine-guarded — `doc-new-version` is the inconsistent one, and it is
  the **destructive** command while `parallel-consolidated` is mere bookkeeping. The guard priority
  is inverted.

I traced the failure mode rather than assuming it, and it is genuinely silent:

1. `next_doc_version_id` (`:290`) is `max+1` over that branch's index, so both streams pick the same
   `v0012`.
2. `new_doc_version`'s only collision check is `if dest.exists()` (`:313`) — comparing the **full
   path** `v0012_<slug>.md`. Two different summaries ⇒ two different slugs ⇒ **no raise**.
3. `docs/index.json` is authoritative and deliberately **not** in `GENERATED_FILES` (`:39`), so it
   is not covered by regenerate-not-merge. The merge conflicts there and is resolved by hand.
4. `validate_docs` checks only that `latest` resolves, its file exists, and `docs/current` is fresh
   — **no version-id uniqueness check**. So a hand-resolution that drops one side's entry leaves two
   files claiming `v0012`, one version's content silently absent from `docs/current`, and
   `validate` reporting success.

The fix is a four-line mirror of code that already exists 1000 lines away in the same file, and it
is backward-compatible by construction: `current_stream` returns `None` — without ever shelling out
to git — unless some active phase carries a parallel stamp, so an untouched workspace is unaffected.

Weighed against a `pass`-plus-deferral: normally I would not hold a phase for prose-vs-engine
enforcement, since this workspace is prose-driven throughout. Three things override that here — the
intent names this exact guarantee in absolute terms; the phase itself already chose engine
enforcement for the weaker sibling command; and the cost is trivial. Deferring a four-line guard
that closes the one silent-corruption path the phase was built to close is the worse trade.

### Finding 2 — `parallel-merge-finish` warns where `parallel-consolidated` refuses (**accepted as designed, no change**)

Verified in the code (`:1265-1266` warn vs. `:1307-1308` raise). I judge S3's rationale correct and
recommend **no fix**: `parallel-merge-finish` is idempotent and non-destructive (it regenerates and
prints), and on a parallel stream `rebuild_index_and_state` writes precisely the stream-scoped state
that checkout *should* have — so the operation is harmless there. Refusing would strand someone
mid-cleanup for no safety gain. The severity asymmetry is proportionate to the consequence
asymmetry, which is exactly right. Recorded so the open item is closed, not left dangling.

### Finding 3 — the `smoke_s2` timing flake is a harness bug, not an engine bug (**no repo change**)

Reproduced 1 in 4 runs. Captured the failing detail rather than trusting the label:

```
FAIL commit contains only the stamp + regenerated works files ::
['works/backlog.md', 'works/events.jsonl', 'works/index.json', 'works/phases/active/P2/phase.json']
```

The commit is a **subset** of the expected six — `works/state.json` and `works/deferred.md` are
absent because `now_iso()` has second resolution, so a same-second rebuild leaves them
byte-identical and they never enter the commit. Nothing extra ever appears, in any run.

The safety property that matters is "the engine commit contains *nothing but* the stamp and the
regenerated files" — that is an upper bound, and it holds unconditionally: `parallel-start` `git
add`s a fixed file list. The harness asserts set **equality** where its own check name says "only",
i.e. subset. So the engine is correct and the underlying nondeterminism (which of the fixed files
actually changed) is benign — **no fix is warranted in `scripts/workflow.py`**. The over-strict
assertion is scratchpad-only and outside the repo; anyone reusing that harness should relax `==` to
`<=`.

## 4. Residual risk carried forward (not a finding)

**CI has never executed.** S5 built `workspace-ci.yml` correctly and verified it locally as far as a
slice can (two independent YAML parsers, ASCII, branch-name derivation against S2's real format,
and every command it invokes run locally) — but pushing is outside a slice's boundaries, so no run
on GitHub has ever happened. The first real run is the operator's next push. Two things would only
surface there: runner-side `python3` availability and the `origin/<base>` fetch depth. This is
inherent to the boundary, not a defect, and it is already recorded in `phase.md` §S5.5 — noted here
so it is not mistaken for validated behavior.

## 5. Doc Impact verification (consolidation NOT run)

I verified §Doc Impact covers the phase's durable-truth changes even though this is a default-stream
phase, because the list is what a re-review will consolidate. It is **complete and accurate**: 11
notes across `architecture` (S1, S2), `operations` (S2, S3, S4, S5, S6) and `decisions` (S3, S5, S6
×2). Spot-checked against the shipped code — the command names, flags, guard conditions and the
`WORKSPACE_VERSION` 24 claim all match the engine. S7 correctly recorded no note (the READMEs mirror
truth already captured).

The S6 note flagged **"supersede, do not append"** for `docs/current/decisions.md` — the
orchestrator/executor entry currently ends with "*Parallel fan-out across slices (worktree
isolation)* — rejected for now". I confirmed that line is still present and now stale at the phase
level: P12 ships phase-level parallelism while slice-level fan-out remains rejected. The
consolidation must **rewrite** that sentence, not add a newer entry beside it. Carried into the
re-review's work.

**No `doc-new-version` was run, no `docs/current/*` touched, no `rebuild-docs` executed** — correct
for a non-pass verdict.

## 6. Proposed fix slice

| Id | Name | Kind | Risk | Scope |
|---|---|---|---|---|
| `P12.F1` | Guard `doc-new-version` against a parallel stream | `fix` | `high` | Add the `current_stream()` refusal to `new_doc_version` mirroring `parallel_consolidated`, with a message naming the post-merge path; rebuild the installer artifact in the same commit |

`high`, not `low`: it edits `scripts/workflow.py` (real engine code) and necessarily touches the
rebuilt artifact — two files, and the contract puts every cross-file change at the top tier.

Scope notes for whoever plans it: the refusal belongs immediately after the `doc_id in DOC_TYPES`
check, before any allocation or write, so a refusal leaves zero partial state. Re-run `smoke_s3` (it
exercises the real consolidation path on the default stream and must stay green) plus `validate`,
`build.py --check`, and the byte-identity pass. **Optional hardening the planner may fold in or
defer:** a `validate_docs` check for duplicate `vNNNN` prefixes within one doc, which would catch a
collision that already happened rather than only preventing new ones — secondary to the guard, and
fine to defer.

## Deviations from `plan.md`

1. **The byte-identity check was re-pointed from `HEAD` to `6f9e3c7`.** The plan said "one
   rebuild-diff pass (S1/S4 pattern)", but that pattern compares against `HEAD`, which now contains
   the entire phase — a tautology at review time. Comparing against the last pre-P12 commit is what
   the plan's *intent* (prove the phase changed nothing for a non-opted-in workspace) actually
   requires. Harness copied to `<scratchpad>/rebuild_diff_review.py`; the real repo is untouched.
2. **`smoke_s2` was run 4× rather than once**, to characterize the flake (§3 Finding 3) instead of
   reporting it as a bare pass/fail. The plan asked me to decide on the underlying nondeterminism,
   which needed the actual failing file list, not the check name.
3. **Step 4 (consolidation) was not executed** — required by the verdict, per the plan's own
   "stop before any consolidation" instruction and the pass-only rule.

No commits, no status transitions, no archiving, no other slice's `plan.md` touched.

`explain: not written — run /explain for this phase`
