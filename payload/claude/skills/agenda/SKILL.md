---
name: agenda
description: Show the agenda, or run one agenda command on its items.
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# agenda

`/agenda` alone runs `python3 scripts/workflow.py agenda` (add `--json` for each item's stored fields); `works/agenda.md` is the same list, regenerated, never hand-edited. `/agenda <command> …` runs `python3 scripts/workflow.py agenda-<command> …`:

- `add --title "..." [--note "..."]`: a new Open item, first in the open order; prints its id.
- `edit <item> [--title ...] [--note ...]`: change the title or note, in any status.
- `move <item> --first | --last | --before <item> | --after <item>`: reorder an Open item.
- `defer <item>…`: Open to Deferred.
- `solve <item>… [--outcome "..."]`: Open or Deferred to Solved.
- `drop <item>… [--reason "..."]`: Open or Deferred to Dropped.
- `reopen <item>…`: back to Open, last in the open order.
- `delete <item>…`: remove the items for good.
- `link <item> --phase <P> | --deferred <D>`: tie an item to a phase or deferred job; a phase or job holds one item, and a phase of another stream is linked from its own checkout. `new-phase` and `defer-job` take `--agenda <item>` to link what they create.
- `unlink --phase <P> | --deferred <D>`: untie the phase or job from its item.

In a linked checkout, changes made on the web arrive as inbox entries that `sync`, `next` and `run-phases` apply as these commands; a refused one shows the command's line on the web.

An item is stored as `open | deferred | solved | dropped`, shown as Open, Deferred, Solved and Dropped. The fifth word, In progress, is never stored and no command sets it: an Open item reads In progress while a phase linked to it is not done; a Deferred, Solved or Dropped item never does.

- An item never affects `next`: the agenda is the operator's list, not the backlog.
- Defer makes no deferred job; to park work as one, run `/defer-job` with `--agenda <item>`.
- Leave out `--id`: the engine mints the item's id (`A7-m3`; `A7` is read as it) and prints it.
- A command on several items changes all or none; a refusal is one line. Send a title that starts with `-` as `--title=<t>`.
