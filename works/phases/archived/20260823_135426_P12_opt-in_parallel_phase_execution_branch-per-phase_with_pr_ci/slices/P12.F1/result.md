# P12.F1 — result

**Status: done.** The review's must-fix finding 1 is closed: `doc-new-version` now hard-refuses on a
parallel stream, and `validate` fails loudly on a duplicate `vNNNN` within one doc. Two files
changed (`scripts/workflow.py` + the rebuilt installer artifact); no other surface touched.

## What landed

**1. The guard** (`scripts/workflow.py`, `new_doc_version`, immediately after the `doc_id in
DOC_TYPES` check and before `doc_index()` / any allocation or write):

```python
stream = current_stream(all_active_phases())
if stream:
    raise SystemExit(f"this checkout is on parallel stream {stream}; doc consolidation runs on the default stream, after the branch is merged -- defer it to the post-merge step (parallel-merge-finish, then doc-new-version, then parallel-consolidated)")
```

Wording mirrors `parallel_consolidated`'s sibling guard (same `this checkout is on parallel stream
{stream}; ...` opening, ASCII `--` for the dash, the next command named inline), extended with the
three-step post-merge sequence because this is the command an agent reaches for by mistake. A
four-line comment above it records *why* (single-index `max+1` allocation ⇒ silent collision), so the
guard is not mistaken for boilerplate later.

Placement matters and was checked, not assumed: the refusal precedes `doc_index()`, so a refusal
leaves **zero** partial state — verified by hashing `docs/` and comparing `docs/index.json` and
`works/events.jsonl` byte-for-byte across a refused invocation.

**2. The hardening** (`validate_docs`, per doc, right after the index-entry check so it still reports
even when `latest` is broken): collect the `v(\d+)` prefix of every version id and append
`duplicate doc version number in docs/index.json: <doc> vNNNN claimed by both <id-a> and <id-b>` on
any repeat. Purely additive; `re.match(r"v(\d+)", ...)` mirrors `next_doc_version_id` exactly, and
ids without a `vNNNN` prefix are skipped rather than errored (they were never allocated by the
engine).

**Backward compatibility is free by construction**, and was measured rather than argued:
`current_stream` returns `None` *without shelling out to git* unless some active phase carries a
parallel stamp — so for an untouched workspace the guard is unreachable, and it also works in a
workspace with no git at all (smoke section A runs `doc-new-version` in a non-git directory).

## Validation

| # | Command | Outcome |
|---|---|---|
| 1 | `python3 <scratchpad>/smoke_f1.py` (new, 23 checks) | **pass** — `SMOKE PASSED (23 checks)` |
| 2 | `python3 <scratchpad>/smoke_s3.py` (49 checks) | **pass** — `SMOKE PASSED (49 checks)`, regression clean |
| 3 | `python3 <scratchpad>/rebuild_diff_review.py` (byte-identity vs. pre-P12 `6f9e3c7`) | **pass** — 17 generated artifacts `IDENTICAL` |
| 4 | `python3 -m py_compile scripts/workflow.py` | **pass** |
| 5 | `python3 scripts/workflow.py validate` (real tree) | **pass** — `Workflow validation passed.` |
| 6 | `python3 scripts/workflow.py next` (real tree) | **pass** — `current_phase=P12 current_slice=P12.F1 next_slice=P12.REVIEW`, unchanged shape |
| 7 | `python3 installer/build.py` then `--check` | **pass** — artifact rebuilt (384221 bytes) and `OK: ... in sync with installer/ source` |
| 8 | `python3 scripts/workflow.py sync-agents --check` | **pass** — `agent files in sync` (untouched, checked for drift) |

`smoke_f1.py` (new harness, scratchpad only — `tests/` stays at its single file) builds throwaway
workspaces and covers, in five sections:

- **A. no parallel phase, no git at all** — `doc-new-version` → `rebuild-docs` → `validate` all
  succeed exactly as before, proving the guard never shells out on the default path.
- **B.** seeds P1 `in_progress` + P2 `planned` and opts P2 in with the real `parallel-start`
  (branch `phase/P2-second_phase`, real worktree).
- **C. the guard** — from the worktree, `doc-new-version` exits non-zero; the message names the
  stream, the default stream, the post-merge step and all three commands; `docs/` hash,
  `docs/index.json` bytes and `works/events.jsonl` are unchanged (zero partial state); an invalid
  `--doc` on a parallel stream is still reported as a doc error, not a stream refusal.
- **D. the default stream of the same repo** — `doc-new-version` succeeds, `edit_path` file exists,
  `index.latest` advances, `validate` passes, `parallel-status` still reads the branch.
- **E. the hardening** — a hand-crafted duplicate-`vNNNN` `docs/index.json` (a second entry with the
  same number and a different slug, exactly the hand-merge shape the review traced) makes `validate`
  fail with the doc, the number and both ids in the message; removing it makes `validate` pass again,
  and the untouched branch-side workspace validates throughout.

All commits in the smoke are confined to its temp repos. **`doc-new-version` was never run against
the real tree** — only inside the temp copies.

## Deviations from `plan.md`

**None substantive.** Two harness-only notes:

1. The plan's guard message was tightened to match `parallel_consolidated`'s actual phrasing (ASCII
   `--`, "after the branch is merged"), which the plan explicitly asked for ("match
   `parallel_consolidated`'s actual wording style (read it first)"). The three named commands are
   preserved verbatim.
2. My first draft of `smoke_f1.py` asserted the guard sits after the `DOC_TYPES` check by feeding an
   invalid `--doc` — unreachable via the CLI, because argparse's `choices` rejects it before
   `new_doc_version` ever runs. The assertion was rewritten to the property that actually matters
   (an invalid doc on a parallel stream reports the *doc* error, never the stream refusal); the
   in-function ordering is guaranteed by source placement.

No commits, no status transitions, no other slice's `plan.md` touched, no skill/contract/`parallel-*`
command changes.

## Note for the re-review

Nothing in the phase's §Doc Impact list is invalidated by this fix. One line **should be extended**
during consolidation: the S3 `operations` note describes the `parallel-*` family, and the S6
`decisions` note (c) states the deferral as a documentation choice — with F1 the deferral is now
**engine-enforced**, which is the sentence the new §Doc Impact entry below adds. The
supersede-not-append instruction for `docs/current/decisions.md` still stands unchanged.
