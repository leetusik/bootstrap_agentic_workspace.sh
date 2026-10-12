# Result — P34.REVIEW (phase review, gate required)

- status: done
- tier: high
- model: opus
- effort: high
- summary: P34 passes. I validated all five slices together (validate, build `--check`, smoke 289 PASS / 0 FAIL, the contract and skill offsets, v55) and spot-checked both hook commands live in this checkout and in a `cp -R` copy (block mid-slice and on a dirty tree; allow at a clean boundary, on manual, `agent_id`, ceiling, cap and garbage; always rc 0). A fresh install ships both hooks at v55. Two minor fresh-eyes findings and one outside-boundary observation go to the operator in the walkthrough. qa v0015 appends 7 P34 checklist lines.
- review_verdict: pass
- validation: `python3 scripts/workflow.py validate` pass (pre-existing P32/P33 debt, stale-docs and oversized-section warnings only), before and after the qa version; `python3 installer/build.py --check` OK; `bash tests/retrofit_smoke.sh` (alone, once) ALL RETROFIT SMOKE TESTS PASSED, `grep -c '^PASS'` = 289, `^FAIL` = 0; `wc -c CLAUDE.md` = 12,274 ≤ 12,288; `do-whole-phase` commit bullet ends at 13,116 B, `do-next-slice` step 7 at 15,243 B (both < 16,000); `grep -n "^## v55" CHANGELOG.md` → 12; `WORKSPACE_VERSION = 55` (now `installer/main.py:45`); `python3 scripts/workflow.py rebuild-docs` OK
- deviations: (1) the plan's boundary probe said "commit everything in the copy". I do not commit in any git root, so I got the clean boundary by `git restore works/` plus removing the untracked `plan.md` in the copy. That returns the copy to HEAD, where `P34.REVIEW` is `todo`, which is the same clean boundary. (2) No operations version: this phase did not change `## Operator Runtime` (reasons below).
- doc_versions: qa v0015 (`## Regression Checklist`: 7 P34 lines appended); operations: none (Operator Runtime unchanged); every other durable change: none — deferred to a docs phase
- walkthrough: see *Walkthrough* below (also in the return)
- explain: not written — run /explain for this phase

## Boundary

`phase-scope P34` measures from creation commit `8945c74`, which created P33 and P34 together. Its range `1a159b0..50cea9d` (25 commits, 25 product files) therefore includes the files P32 and P33 changed. **P34's own boundary is `410a0e6..HEAD`** (its five commits `29075b9..50cea9d`). By `git diff --stat 410a0e6..HEAD -- . ':!works' ':!docs/index.json'` that is 10 files: `scripts/workflow.py`, `tests/retrofit_smoke.sh`, `installer/main.py`, `.claude/settings.json`, `CLAUDE.md`, `.claude/skills/do-whole-phase/SKILL.md`, `.claude/skills/do-next-slice/SKILL.md`, `CHANGELOG.md`, `docs/retrofit-guide.md`, `bootstrap_agentic_workspace.sh` (613+/74−). The other 15 engine-printed files are P32's and P33's and are not reviewed here.

## Gate stage 1 — manifest

`## Operator Runtime` (operations.md l.1817) is filled. The product is a CLI with no browser surface; verification is live CLI runs, and mutating probes run in `cp -R` copies. **Instrument: the terminal (Bash) in this checkout and in scratch copies. No browser was used, and no browser claim applies.**

## Gate stage 2 — independent spot-check (my own runs)

In this checkout (`P34.REVIEW` is `in_progress`). Counter files went to my scratchpad and were deleted afterwards. One counter fell back to `$TMPDIR` because the `scratchpad_dir` given did not exist, and I deleted that one too.

| Input | stdout | rc | trace `rule=` |
|---|---|---|---|
| `{"trigger":"manual"}` | — | 0 | manual |
| auto + session + scratchpad | block JSON naming `P34.REVIEW in_progress`, `block 1/8` | 0 | slice_in_progress (counter file `{"blocks": 1}`) |
| same again | block, `2/8` | 0 | slice_in_progress |
| + `"agent_id":"x"` | — | 0 | subagent |
| `AGENTIC_COMPACT_CEILING=1`, fake transcript (`claude-fable-5-1`, usage 10+500+20) | — | 0 | ceiling, `fill=530 ceiling=1` |
| same transcript, no env | block, `above 850000 tokens` | 0 | slice_in_progress, `fill=530 ceiling=850000` (Claude 5 → 1M ceiling) |
| `x` / empty stdin | — | 0 | error (`stdin is not a hook JSON object`) |
| `AGENTIC_COMPACT_BLOCK_CAP=2`, ×3 | block 1/2, block 2/2, then allow | 0 | cap; counter deleted |
| nonexistent `scratchpad_dir` | block (counter in `tempfile.gettempdir()`) | 0 | slice_in_progress |
| `compact-resume` `{}` and `garbage` | `compaction=done source=compact`, the `next` output (`current_slice=P34.REVIEW`), the resume line; 843 chars | 0 / 0 | — |

Boundary case, in a `cp -R` copy with `works/` restored to HEAD (`P34.REVIEW` `todo`, tree clean):

- `next` dirtied only `works/index.json` and `works/state.json` (both excluded); the gate allowed with `rule=boundary dirty=0`.
- `touch newproduct.txt` → block, `dirty: 1 file uncommitted (your own uncommitted work counts too)`.
- Removing the file → allow, and the counter was deleted.
- `rebuild` + `validate` left ` M docs/index.json` → still allowed (excluded).

`.claude/settings.json`: `PreCompact`/`auto` → `cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py compact-gate || true`, and `SessionStart`/`compact` → `… compact-resume || true`, both `timeout` 15. This matches the Decisions.

Installer, end to end: `sh bootstrap_agentic_workspace.sh <scratch>/fresh --at-root --force-empty-ok` returned rc 0. Its `.claude/settings.json` carries both hooks with the exact commands and timeout 15, and `works/.workspace-version.json` reads `workspace_version: 55`. In that git-less install the gate allowed with `rule=boundary dirty=-` (no git → fail open).

**Not doable here:** loading the hooks into a live Claude Code session. Project hooks load at launch, and this session predates them. That is the operator's walkthrough step (a)–(b).

## Gate stage 3 — fresh-eyes walkthrough (inside the boundary)

- `## Compact Instructions` (the last section of `CLAUDE.md`): short and unambiguous, with its keep/drop lists matching intent §3. It is `##`, not the intent's `# Compact instructions`. The docs do not say the heading form is load-bearing, because the summarizer reads the whole `CLAUDE.md`. The operator's `/compact` in the walkthrough is the live check.
- Contract trims: I read the full `410a0e6..HEAD` diff of `CLAUDE.md`. Every rule is still stated in the contract or in the skill that owns it. Two clauses left the contract without appearing in S3's cut list: the `(claude-design: no drafting, DesignSync inline)` parenthetical, and "do-next-slice never prefetches". Both are still stated where they bind: `do-whole-phase`, `design-cowork` and the executor files for DesignSync, and `do-whole-phase` for prefetching. Not a finding.
- Resume line: findable in both skills. It sits right after the pending halt in `do-next-slice` (l.16) and after the re-read bullet in `do-whole-phase` (offset 5,168). It reads as facts plus one action, and says to wait for a running executor and never re-dispatch it.
- `do-next-slice` step 3 still reads as one instruction. The co-work pointer ("*When the selected slice is a design slice* below carries it") resolves to the paragraph after step 7.
- **Finding A (minor):** `do-next-slice`'s worktree paragraph ("The phase runs on this checkout unless the operator asked for a worktree…") moved from before "Work exactly one slice:" (old l.16) to after step 7 (now l.39), to bring step 7 under 16 KB. Nothing before step 1 points to it. Its case (a), the `worktree` mode word on a `planned` phase, must run *before* step 1 (`parallel-start`, `EnterWorktree`, "continue at step 1 in that worktree"). A top-down reader now meets it only after "Commit by default". The whole skill is loaded at invocation, so the practical risk is low, but the order now reads backwards for a precondition. Possible fix: a one-sentence forward pointer before step 1, about 120 B, which keeps step 7 under 16 KB.
- **Finding B (minor):** neither README mentions the compaction hooks, which ship on for everyone. The nested-install bullets describe `settings.local.json` as only "your personal permissions" (`README.en.md:267`, `README.md:152`; also `README.en.md:616`, the `settings.json` tree comment "pre-approves workflow.py; denies force-push & rm -rf"). Since v55 that file also receives the two hooks. `CHANGELOG.md` v55 and `docs/retrofit-guide.md` do describe them.
- `CHANGELOG.md` v55: clear. The Migration notes tell an adopter exactly what to do: `/update-workspace`, relaunch or `/hooks`, optional `/autocompact 300k`, the two env vars. One present-tense nit: "The workspace records the guidance in the operations doc" is still an owed `## Doc impact` note. It becomes true once the docs phase pays it.
- `docs/retrofit-guide.md`: all four passages (the settings bullet, the review line, manual step 3, the two troubleshooting rows) now consistently say permissions **and hooks**.

## Gate stage 4 — regression checklist

`## Regression Checklist` (qa.md) is this repo's machinery list. It is re-run by `bash tests/retrofit_smoke.sh` plus `validate`. `scripts/workflow.py`, `installer/main.py` and `tests/retrofit_smoke.sh` are in P34's diff and feed every line, so **every line is inside**. The single smoke run (289 PASS, 0 FAIL) plus `validate` is the re-run.

| Block | Lines | Inside / outside | Result |
|---|---|---|---|
| P16 (installer fresh install, gate refusal, Test 0 text) | 3 | inside | pass (smoke) |
| P18 (`## Slices` render, marker-less notebook) | 2 | inside | pass (smoke) |
| P19 (`new-slice --kind research`) | 1 | inside | pass (smoke) |
| P29 (nested/at-root install, bare `--update`, refusal) | 4 | inside | pass (smoke) |
| P30 (rotate-backlog proposal, `--archive-only`, `--consolidates`, `docs-debt`) | 4 | inside | pass (smoke) |
| P33 (rotate chain ×6, smoke count) | 7 | inside | pass. The P33 line's "247 PASS" is a stale number, superseded by the P34 line (289) |
| **total** | **21** | **21 inside, 0 outside** | all pass |

Appended (qa v0015), 7 lines tagged `(P34)`: `compact-gate` block/allow at the boundary; its allow paths (manual, `agent_id`, ceiling, cap, garbage, uncountable), always exit 0; `compact-resume` output; fresh-install hooks; the additive and idempotent merge (retrofit, `--update`, nested); the contract cap and the resume line in the first 16 KB; smoke 289 PASS.

## Gate stage 5 — operator questions

1. `/autocompact 300k` now? (P34.DECOMP) → walkthrough decision (d).
2. Added by this review: fix Findings A and B now (one small `P34.F1`), or defer them as a job? → walkthrough decision (e).

## Cross-check: notebook vs. logs

Every decision and deviation in the five `result.md` files is in `## Decisions`:

- DECOMP: version v55, command form, block mechanism, `in_review`.
- S1: a′ subagent, uncountable block, `docs/index.json` exclusion, two-repo nested dirty, trace `dirty=`, malformed-marker exemption, retry reading. Its method note (no probe commit) is not a decision.
- S2: `_merge_settings_dict`, the malformed→sidecar/refuse rule including the old `permissions` AttributeError, nested via the rewrite.
- S3: sizes, offsets, the worktree-paragraph move, the inline finish.
- S4: release.

Nothing was dropped.

`## Doc impact` (8 lines) covers every durable-truth change:

- operations ×4: the compaction rules, env vars, window guidance plus relaunch, the settings/hooks merge.
- architecture: the commands and the settings merge.
- decisions ×2: the veto design, and the contract plus skill shape. The latter covers S3's trims.
- qa: the smoke baseline.

S4's `docs/retrofit-guide.md` edits are direct edits to a non-versioned doc, so no line is owed, and `CHANGELOG.md` is likewise direct. Findings A and B are not durable-truth changes the phase made, so they need no line.

## Doc duties (pass)

- `doc-new-version --doc qa --source P34.REVIEW` → `docs/versions/qa/v0015_p34_review_regression_checklist_for_boundary-gated_compaction_compact-gate_compact-resume_hooks_install_and_merge_contract_cap_smoke_289.md`. I edited only `## Regression Checklist` (7 lines appended after the P33 smoke line), then ran `rebuild-docs` and `validate` (pass). The diff of v0014 against current shows only the 7 added lines.
- No operations version. `## Operator Runtime` records how the operator runs the product (engine, installer, scratch copies, smoke). P34 did not change that. The hooks and the relaunch fact are compaction behaviour inside the operator's Claude Code session, already owed in `## Doc impact` (operations line 3).

## Observations outside the boundary (deferred-job candidates)

1. **`next` still lists merged P33 as a parallel phase elsewhere.**
   - Reason: `next` and `compact-resume` print `parallel_phases_elsewhere=P33:phase/P33-… (not in this stream; each runs from its own branch)`, although P33 is `done`, merged, and its worktree and branch are retired. Its `execution` block still reads `mode: parallel`, `consolidation: pending`. That line is now also re-injected after every compaction, where it misleads a resumed session.
   - Trigger: when P33's `parallel-consolidated` is paid, or the next parallel-phase work, whichever comes first.

## Walkthrough

In the CLI runtime, in this checkout:

- (a) Relaunch Claude Code here (project hooks load at launch), then run `/hooks`. Check that `PreCompact` with matcher `auto` → `cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py compact-gate || true`, and `SessionStart` with matcher `compact` → `… compact-resume || true`, are both listed.
- (b) Run `/compact` once, at any point: manual compaction is never blocked. The resumed context should show `compaction=done source=compact`, the `next` pointer, and the resume line. Also check that the summary kept what `## Compact Instructions` names.
- (c) Optional. Run `printf '{"trigger":"auto","session_id":"me"}' | python3 scripts/workflow.py compact-gate` once mid-slice (a block JSON naming the slice) and once at a committed boundary (no output). The stderr trace line names the rule. Delete `$TMPDIR/agentic-compact-gate-me.json` if one is left.
- (d) Decide: `/autocompact 300k` now (recommended now that the veto is live; it is your own per-model setting), or keep `autoCompactWindow: 500000`.
- (e) Decide on Findings A and B (both minor):
  - A: `do-next-slice`'s worktree paragraph now sits after step 7 with no pointer before step 1.
  - B: the READMEs do not mention the compaction hooks and still call nested `settings.local.json` "your personal permissions".
  - Options: fix both in one small `P34.F1` (rated `high` by the tier rule, since S3 and S4 were `tier: mid`), or file them as a deferred job, or accept as is.
- (f) Accept with `python3 scripts/workflow.py accept-gate P34 --clear [--note "..."]`.

## Notes

- `phase.md` edits: consumed the DECOMP→REVIEW note; added the Review decision and the Findings A/B operator question; rewrote `## Now`. My first edit script anchored on `## Now`, which matched first inside the Objective text ("the notebook's ## Now"). That truncated the file, the same trap S2 hit. I restored it from `git show HEAD:` (the only uncommitted difference was the generated REVIEW row, which `next` regenerated) and re-applied the edits anchored on `\n## Now\n`. The final diff against HEAD is exactly the intended edits plus the generated row.
- The scratch copies `bcopy/` and `fresh/` remain in my session scratchpad, outside the repo; their `rm -rf` was denied.
