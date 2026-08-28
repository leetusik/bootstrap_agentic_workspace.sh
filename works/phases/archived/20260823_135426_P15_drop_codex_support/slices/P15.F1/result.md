# Result — P15.F1: Settle the `pending` design exception

**Option A, as instructed: the exception is deleted.** `CLAUDE.md`'s `pending` hard rule no longer
carries a design carve-out, the v31 CHANGELOG section was corrected in place, one smoke-test
assertion that pinned the deleted wording was replaced, and the artifact was rebuilt and executed.

Finding 1 from `P15.REVIEW` is resolved. Option B was not implemented and no part of it was
partially applied.

---

## 1. The three edits

### `CLAUDE.md` — the operator co-work bullet (L67)

Deleted exactly the two sentences the plan named — from `**Narrow design exception:**` through
`…and no other pending gate is relaxed.` Nothing else in the bullet moved. The rule now reads
continuously, with no seam:

> …Work resumes only after explicit operator input clears the same item back to `in_progress`;
> normally the operator does that, or the orchestrator does it on their explicit say-so. `pending`
> means "waiting on the operator" and is distinct from `blocked` (an impediment or unmet dependency
> you cannot resolve yourself).

Read back from the **installed** contract, not just the repo copy (§4). The `git diff` is a
single-line replacement; the preceding sentence and the `pending`-vs-`blocked` distinction are
byte-unchanged.

### `CHANGELOG.md` — the v31 section

The generalized-exception description was **not** a standalone bullet; it was sentences 3-5 inside
the bullet headed *"The contract keeps every rule that was not Codex-specific."* — which is why the
review coupled the two edits into one. Both plan items therefore landed in a single bullet rewrite:

- the two sentences announcing the generalization, and the "guardrails unchanged and verbatim"
  sentence quoting them, are gone — the change they announced no longer happened;
- the framing was adjusted. With the exception deleted, *"keeps every rule that was not
  Codex-specific"* becomes literally true, but it would then be **silently incomplete**: the release
  does drop a rule, and an adopter reading the entry would never learn the carve-out is gone. The
  heading is now *"keeps every rule that was not Codex-specific, **and drops the one that was**"*,
  followed by a plain statement of what went and why (Codex-only because Codex was automatic-only;
  never held by Claude Code) and the resulting uniform `pending` gate.

Scope confirmed by diff: **only** the v31 section changed (one bullet, 7 lines → 8). No other
section, no version number, no date. v31 is corrected in place, not superseded.

### `tests/retrofit_smoke.sh` — Test 0's contract assertion

The plan's suspicion was right. Test 0's required-contract-string list pinned the deleted wording at
L105: `"A bare automatic invocation is never approval"`. Left alone it fails the build's own gate.

Rather than delete it and leave the deletion untested, I swapped it for a check that pins the *new*
truth in both directions:

```python
assert "Work resumes only after explicit operator input clears the same item" in claude
for gone in ("design exception", "never approval", "no other pending gate"):
    assert gone not in claude, gone
```

Positive: the surviving general rule is present. Negative: no reintroduction of the carve-out, in
any of its three distinctive phrasings. **Mutation-checked** — re-inserting the exception sentence
into a scratch copy of `CLAUDE.md` fails with `mutation caught, as intended: design exception`, so
the assertions are load-bearing rather than vacuous.

**PASS count is unchanged at 115** because the surrounding block reports a single `ok`, not one per
`assert` — three asserts replaced one inside the same block. No count change to explain.

## 2. Other references — swept, none left asserting the deleted rule

`grep -rln 'design exception\|never approval\|no other pending gate'` over the whole repo
(`*.md`, `*.sh`, `*.py`, `*.json`, `*.toml`, `*.yml`), classified:

| Location | Disposition |
| --- | --- |
| `tests/retrofit_smoke.sh` | the new **negatives** — asserts absence, correct |
| `bootstrap_agentic_workspace.sh` | rebuilt; **0 hits** after `build.py` (§3) |
| `docs/versions/operations/v0025_*` | historical version — never patched, correct |
| `docs/current/operations.md:145` | generated; the phase's outstanding `operations` doc impact covers it (§5) |
| `works/backlog.md:75` | generated — this slice's own name |
| `works/phases/active/P15/phase.json:14` | the review's recorded verdict note — history |
| `works/phases/**` (plans, results, `intent.md`) | the phase's own record of the disagreement — history |

Zero live instructions anywhere still assert the rule. `.claude/`, `README*.md`, and
`docs/retrofit-guide.md` had **no hits at all** — the exception never had a `.claude/**` counterpart,
which is precisely the review's point.

**One extra check worth recording:** `.claude/skills/design-cowork/SKILL.md` contains no
resume/clear clause of any kind (`grep -i 'resume\|clear'` returns one unrelated line about labeling
references). So nothing was orphaned by the deletion — it confirms the review's finding that the
operational clause backing the exception lived *solely* in the deleted Codex `do-whole-phase` body.

## 3. Validation — every command, with outcome

| # | Command | Outcome |
| --- | --- | --- |
| 1 | `python3 installer/build.py` | **PASS** — `wrote bootstrap_agentic_workspace.sh (322345 bytes) from installer/ source` |
| 2 | `python3 installer/build.py --check` | **PASS** — `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` |
| 3 | `python3 scripts/workflow.py validate` | **PASS** — `Workflow validation passed.` (exit 0) |
| 4 | `bash tests/retrofit_smoke.sh` | **PASS** — **115 PASS / 0 FAIL**, exit 0, `ALL RETROFIT SMOKE TESTS PASSED` |
| 5 | Exception traces in the rebuilt artifact | **PASS** — `grep -c` for all three strings = **0** |
| 6 | Fresh install of the rebuilt artifact | **PASS** — see §4 |
| 7 | Smoke-assertion mutation check | **PASS** — reintroducing the exception fails the new assertion |

Artifact size moved 322756 → **322345** characters (`build.py` prints characters, not bytes — S6
finding 4), consistent with removing two sentences.

## 4. The artifact was run, not just built

Per the standing rule that `build.py` only `compile()`s (the open question headed for `D3`), the
rebuilt artifact was installed for real into the scratchpad:

- **exit 0**, clean banner, no import-time error
- `works/.workspace-version.json` → `"workspace_version": 31` (unchanged by this fix, as intended)
- root inventory exactly `.claude .gitattributes .github CLAUDE.md docs executors.toml scripts works`
  — still Codex-free
- **installed `CLAUDE.md` is byte-identical to this repo's** (`diff` clean) — the check that proves
  `collect_contract_body()`'s `CLAUDE_HDR` slice still lands correctly after editing the contract body
- installed `CLAUDE.md` carries **0** traces of the exception, and its `pending` rule reads as the
  single continuous sentence quoted in §1
- inside the fresh workspace: `validate` → `Workflow validation passed.`; `sync-agents --check` →
  `mid   sonnet @ xhigh` / `high  opus @ xhigh` / `agent files in sync`, exit 0

## 5. Contract ↔ skills now agree

The point of the fix. Verified by reading all three:

- `CLAUDE.md` — "Work resumes only after explicit operator input clears the same item back to
  `in_progress`; normally the operator does that, or the orchestrator does it on their explicit say-so."
- `.claude/skills/do-next-slice/SKILL.md:14` — "Resume only after the operator approves and clears the
  `pending` status back to `in_progress`."
- `.claude/skills/do-whole-phase/SKILL.md:16` — "Resume only after the operator clears `pending` back
  to `in_progress`."

No contradiction remains. The contract's surviving "or the orchestrator does it on their explicit
say-so" is **not** a residual carve-out: it is still gated on explicit operator input and only names
who runs the command afterwards. That clause is pre-P15 and was never in conflict with either skill.

## 6. Doc impact

No `doc-new-version` was run — this is a `fix` slice, and the re-review consolidates on a pass.

One **correction** appended to the phase's "Doc impact" list, because a line there now states the
opposite of the shipped truth: `P15.S3`'s `operations` entry records item (a) as *"the `pending`
design exception is now harness-general"*. That is exactly what this slice reverted. The consolidated
`operations` version must instead record that the Codex-only carve-out was **removed** with Codex and
that the `pending` gate is uniform. Recorded in `phase.md` (§*Doc impact*) so the re-review does not
consolidate the retracted claim into a durable doc version.

This also folds into the existing `operations` line covering `docs/current/operations.md:141-146`,
which still describes the Codex-era inline-resume rule.

## 7. Deviations from `plan.md`

Two, both small, neither a scope change:

1. **"Remove the bullet describing the generalized exception"** — there was no such standalone
   bullet. The description lived inside the *"keeps every rule that was not Codex-specific"* bullet,
   so the plan's edits 2a and 2b were the same bullet and landed as one rewrite. This matches the
   review's own framing ("rewrite `CHANGELOG.md`'s v31 bullet … **and** fix its framing").
2. **The smoke-test assertion was replaced, not merely dropped.** The plan allowed dropping it with
   an explanation; I substituted an equivalent positive assertion plus three negatives so the
   deletion itself is regression-pinned, and mutation-checked them. PASS count is unchanged (115), so
   no count change needs explaining.

On the plan's open sub-question ("check whether the claim becomes simply true, or whether the wording
still needs adjusting"): it becomes true but incomplete, so the wording was adjusted — reasoning in §1.

## 8. Out of scope — untouched, as instructed

The two upheld judgment calls (`AGENTS.workspace.md` in `OBSOLETE_MACHINERY`; the vendored
`explain/SKILL.md` edit), the `D2` / `D3` parked items, the retrofit guide's `.gitattributes`
Troubleshooting clause, and all doc consolidation. Option B was not implemented in any part —
neither skill body was edited.

## 9. Boundaries

No commit, no `git add`. No `start-slice` / `finish-slice` / `set-slice-status` / `set-phase-status`
/ `review-phase`. No `doc-new-version` / `rebuild-docs`. Files changed: `CLAUDE.md`, `CHANGELOG.md`,
`tests/retrofit_smoke.sh`, the regenerated `bootstrap_agentic_workspace.sh`, this `result.md`, and
the `From P15.F1` + Doc impact correction in `phase.md`. The regenerated artifact is left for the
orchestrator to stage in the same commit.
