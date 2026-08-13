# Plan — P15.REVIEW: phase review

Review the whole of `P15` — six implementation slices, all committed — against the phase
objective and `intent.md`, validate everything together, and **only on a passing verdict**
consolidate the "Doc impact" list into new doc versions.

This phase is **not** in parallel mode, so doc consolidation happens here rather than
post-merge.

## Read

`works/phases/active/P15/intent.md` (the operator's confirmed intent and the three resolved
clarifications), `phase.md` in full (the breakdown, ~40 cross-slice notes, the Doc impact list,
Constraints, and Open Questions), and each of `slices/P15.{DECOMP,S1,S2,S3,S4,S5,S6}/result.md`.

## 1. Validate the phase as a whole

Run, and report actual output:

- `python3 scripts/workflow.py validate`
- `python3 installer/build.py --check`
- `bash tests/retrofit_smoke.sh` — expected 115 PASS / 0 FAIL
- `python3 scripts/workflow.py sync-agents --check`
- **Execute the artifact end to end**, because the build gate only `compile()`s the body: a
  fresh install into a temp dir under the scratchpad, a retrofit into a repo that has its own
  `CLAUDE.md` and `AGENTS.md`, and an `--update` over a pre-v31 install. Confirm the fresh
  install reports workspace version 31, contains no `AGENTS.md`/`.agents`/`.codex`, and that the
  retrofit leaves the seeded `AGENTS.md` byte-identical.

## 2. Judge against the objective and intent

The objective: *remove all Codex-specific machinery, contract text, installer payload, tests,
and documentation so the workspace ships Claude Code only, and give existing adopters a flagged
upgrade path.*

Check each half honestly:

- **Complete removal.** Sweep the repo for anything Codex-shaped that should have gone. The
  deliberate survivors are: `CHANGELOG.md` history, `.claude/skills/{update-workspace,explain}`
  (documented migration/divergence notes), `installer/main.py`'s `OBSOLETE_MACHINERY` comments,
  `scripts/workflow.py`'s rejection strings, `tests/`' proof-of-absence negatives, and the
  generated/immutable `docs/current/**`, `docs/versions/**`, `works/**`. **A non-zero
  `grep -ri codex` is expected — judge whether each survivor is deliberate**, not whether the
  count is zero.
- **The adopter path actually works.** S2 built it and S4 pinned it; verify it end to end
  yourself rather than trusting either. In particular confirm the `is_file()` → `.exists()` fix
  is what makes the directory entries fire, and that `--update` deletes nothing.
- **Nothing regressed for Claude Code users.** The workspace must still drive normally.

## 3. Scrutinize the three judgment calls the phase made

These were orchestrator or executor decisions, not operator instructions. Challenge them; a
review that rubber-stamps them is not doing its job.

1. **The `pending` design exception was generalized, not deleted** (`CLAUDE.md`, S3). It was
   labelled a "Narrow Codex design exception"; the reasoning for keeping it was that the
   mechanism is not Codex-specific and Claude Code's default `auto` mode hits the identical
   situation, so deleting it would have silently removed a capability the operator never asked
   to remove. **This is the one place the phase widened a rule rather than narrowing it.** Judge
   whether that was right. If you disagree, say so explicitly and propose a fix slice — and note
   the coupling: `CHANGELOG.md`'s v31 section carries a bullet describing this change, so
   overruling it means editing `CLAUDE.md` and that bullet together.
2. **`AGENTS.workspace.md` was added to `OBSOLETE_MACHINERY`** (S2) — flagging a sidecar the
   installer created but will never refresh again. Reasonable, or overreach into files the
   operator owns?
3. **`.claude/skills/explain/SKILL.md` was edited despite being vendored** from
   `leetusik/knowledge @ d0c2c38`, creating upstream drift, plus a re-vendor comment. Right
   call?

## 4. Verify the intent's out-of-scope boundary held

`intent.md` says the historical record is preserved. Confirm `works/phases/active/P13` and
`P14`, `docs/versions/**`, `works/events.jsonl`, and the pre-v31 `CHANGELOG.md` sections are
untouched by this phase's commits (`git log --stat` over the phase's range). A violation here is
a `changes_requested`, not a note.

## 5. Spot-check the "actively wrong" doc fixes

S5 corrected ten passages that documented behaviour S1–S3 changed. Pick the load-bearing ones —
the retrofit guide's Tier 3 contract-merge promise, its manual-fallback steps, and
`installer/README.md`'s build-check list — and verify the *new* text against the *actual* code
in `installer/main.py` and `installer/build.py`. S5 caught one error in its own draft this way;
check whether it caught them all.

## 6. Doc consolidation — **only on a passing verdict**

If and only if the verdict is `pass`, consolidate the "Doc impact" list in `phase.md` into new
doc versions. Three docs are affected — `architecture`, `operations`, `decisions` — and several
Doc impact lines fold into the same doc (S2's and S3's `architecture` lines are the same
version; S1/S2/S3/S5 all touch `operations`).

```
python3 scripts/workflow.py doc-new-version --doc <doc> --summary "..." --source P15.REVIEW
```

Then write the new version files. Rules:

- **Never patch an existing file under `docs/versions/`** and never hand-edit
  `docs/current/*.md` — those are generated. Create new versions and let `rebuild-docs`
  regenerate the snapshots.
- `decisions` gets a **new appended decision** — "drop Codex support; ship Claude Code only",
  with the rationale (the dual-harness parity tax) and the migration mechanism
  (`OBSOLETE_MACHINERY` flagging, workspace v31). **Do not rewrite the 33 historical entries** —
  P13 and P14 remain accepted history that this decision supersedes.
- Note that S5's Doc impact line is about the **shipped seed payload**
  (`installer/payloads/doc_bodies/*.md`), not this repo's own `docs/current/` — do not
  double-count it.
- Finish with `python3 scripts/workflow.py rebuild-docs` and confirm `validate` still passes.

**A non-passing verdict stops before all of this.** Complete the validation and judgment first
so the orchestrator gets the whole picture in one cycle, then return the verdict with numbered
findings and proposed fix slices, and do no consolidation.

## 7. Open questions to close or carry

`phase.md` carries open questions from several slices. Resolve what you can and state what
carries forward. At minimum:

- **`installer/build.py` only `compile()`s the artifact body**, so a broken installer can pass
  every commit gate — the phase surfaced this and worked around it by running the artifact in
  every slice. It is pre-existing and out of scope. Recommend whether it should become a
  deferred job (`D3`); the orchestrator will file it.
- The retrofit guide's Troubleshooting row that omits the `.gitattributes` line-merge
  (pre-existing, non-Codex, flagged by S5).
- `D2` is already filed for the `slice-executor-mid` co-work refusal gap.

## Boundaries

- Do **not** commit and do **not** transition slice or phase status — the orchestrator runs
  `review-phase`, which moves both.
- Do **not** write a phase explainer. Return the fixed pointer
  `explain: not written — run /explain for this phase`.
- Return a `review_verdict` of `pass`, `changes_requested`, or `blocked`, with numbered findings.
