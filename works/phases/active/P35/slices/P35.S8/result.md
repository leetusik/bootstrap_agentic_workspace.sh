status: done
tier: mid
model: sonnet
effort: high
summary: The text for nested parallel and the host custom: installer block and exclude entry, a nested workflow/.gitattributes, nested-convention's broadened scope, the parallel-phase/do-*/commit skills and both READMEs; artifact rebuilt (no version bump), engine behavior unchanged.
validation:
- `python3 installer/build.py --check` -- pass (after the rebuild)
- scratch nested install from the rebuilt artifact -- pass (exclude block lists `/.claude/worktrees/`; `workflow/.gitattributes` carries the union line and no CI file; `CLAUDE.local.md` carries the parallel rule and the broadened wording; `nested-convention --help` shows the broadened scope; host `git status` clean)
- `--update` over an install from the pre-S8 artifact -- pass (adds the exclude line and `workflow/.gitattributes`, keeps a confirmed convention incl. its text and `forbidden` trailers, rewrites the managed block and the four skills; a second `--update` changes nothing)
- `grep -n "at-root" README.md README.en.md` filtered for parallel/병렬 -- no line still says worktrees need `--at-root`
- `bash tests/retrofit_smoke.sh` (alone) -- ALL PASSED, PASS count 292 before and 292 after (no assertion pinned to the old wording, so none changed)
- `python3 scripts/workflow.py validate` -- pass (existing stale_docs/oversized warnings only)
deviations: none
doc_impact: see phase.md `## Doc impact` (two P35.S8 lines)

# P35.S8 -- log

## What changed

- `installer/main.py`
  - `_nested_local_block`: the "No parallel worktrees" rule is replaced by the "Parallel phases, only on the operator's word" rule (the pair, `--host-branch` proposed from the custom and confirmed, the host side follows the custom, the engine never pushes/opens a PR/merges into the host default). The commit-convention bullet and the `UNCONFIRMED` bullet now say commits, branches and pull requests. The `host_commit_convention=` key is untouched.
  - `exclude_entries` gains `/.claude/worktrees/` (fresh install and `--update` both write it through the managed block).
  - `emit_policy_files(ci=True)`: a `ci` flag; the nested path now calls `emit_policy_files(ci=not NESTED)`, so `workflow/.gitattributes` is written with the at-root line-merge policy (create / append when missing / unchanged) on install and `--update`, with no CI file and nothing in the host. The `--update` summary lists it as `added` (first time) or `unchanged`.
  - The nested install/update tail lines (steps 3 and the "recorded" lines) say conventions (commits, branches, pull requests); the `host commit convention:` status labels are unchanged.
- `scripts/workflow.py` (text only): `nested-convention` subparser help, `--confirm` and `--text` help (the `--text` help names commit subjects/trailers, branch naming and base, PR shape and who merges), the `--confirm` error and the printed confirm hint (`<conventions>`), `nested_next_lines`' two `next` lines (key `host_commit_convention=` kept); `phase-scope`'s two labels (`creation_commit=… (the host HEAD at new-phase, or the host worktree's base after parallel-start)` and the `base=` kind).
- `.claude/skills/parallel-phase/SKILL.md`: line 24 reworded; §1 rules 2, 5, 6 carry the nested form; a new "Starting in a nested install" six-step block after §2; §3 gains the Streams line, the "worktree isolates files only" caveat and the nested commit routing; a new "Integrating in a nested install" nine-step block before the remote variant (which is marked at-root); two Guardrails lines.
- `.claude/skills/do-whole-phase/SKILL.md` and `do-next-slice/SKILL.md`: one sentence each for the `worktree` word in nested (propose the name, operator confirms, `EnterWorktree` to the host worktree) and, in do-whole-phase, the nested integration pointer.
- `.claude/skills/commit/SKILL.md`: "the host's conventions (commits, branches and pull requests)".
- `README.md` / `README.en.md`: the "only on `--at-root`" and "off in nested" claims removed at all eight places; a "nested install" paragraph in each worktree section (pair, `--host-branch`, base default, the host custom, no push/merge, teardown keeps the host branch, shared docker/ports/DBs) plus the Streams line.
- `bootstrap_agentic_workspace.sh` rebuilt with `python3 installer/build.py`; no version bump.

## Notes

- The `workflow/.gitattributes` payload is the at-root one; its comment names `python3 scripts/workflow.py parallel-merge-finish` (the at-root spelling). In a nested repo the engine is `python3 workflow/scripts/workflow.py` from the host root; left as is (same payload, per the plan).
- `tests/retrofit_smoke.sh` Test 14's title still says "parallel off"; S9 replaces that assertion block.
- `installer/README.md` and `update-workspace` skill had no parallel/nested wording to change.
- Scratch under `scratchpad/p35s8.1PNn` (`new/`, `old/`) and `scratchpad/pre-s8.sh`; `rm -rf` is denied, so left.
