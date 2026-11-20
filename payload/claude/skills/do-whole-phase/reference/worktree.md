# A phase in its own worktree

**The phase runs on this checkout unless the operator asked for a worktree.** Never run `parallel-start` on your own initiative: a `hint:` about a queued phase is relayed, not acted on.

**Start.** On the operator's word (`worktree`, `in a worktree`, `in parallel`, `on its own branch`) and with the phase still `planned`: `python3 scripts/workflow.py parallel-start <P>` (nested: `--host-branch <name>`, the name proposed from `nested-convention` and confirmed), `EnterWorktree` into the printed path (nested: the host worktree), re-run `next` there (`stream=…`) and run the whole loop in that session. The same when the operator ran `parallel-start` themselves.

**One exception: an explain phase (v86).** `create-phase`'s explain route starts its worktree unless `## Explain` says `worktree: no`: its confirmation was the word. In a nested install it runs `parallel-start <P>` with no `--host-branch` (a detached host worktree), then `EnterWorktree` and `next` (`explain_unit=`), and this skill in `auto`.

**Integrate after a `pass`** by the close checklist, the one place it is written: `.claude/skills/pr/reference/close.md` (*A worktree phase: integrate*: the gate first, never past a closed one; the merge; the gate sections the branch review's `result.md` holds under `## Gate sections (written at merge)`; the teardown).

**An explain phase merges back by itself, with no stop.** Its branch touches only its phase folder and the generated `works/` files, so right after its `pass` run the integration without asking; `parallel-gate` does not close on a busy stream when it prints `exemption=phase-folder-only (<n> paths)`. Tear down with `parallel-teardown <P> --discard-ignored` in a nested install (plain `parallel-teardown <P>` at root). A detached host worktree has nothing to integrate on the host.

**When the automatic merge cannot run** (a closed gate, something staged, a conflict outside the generated files): leave the branch `done` and unmerged and say so. `next` on the default stream then prints `merge_ready=<P>:<branch>`; whoever drives that stream integrates it at its next slice boundary, `parallel-gate <P>` first.

**The closing report** of an explain run comes last: after the teardown and its commit, from the default checkout.
