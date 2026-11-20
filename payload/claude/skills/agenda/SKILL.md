---
name: agenda
description: Show the agenda, or run one agenda command on its items.
allowed-tools: Bash(python3 scripts/workflow.py:*)
disable-model-invocation: true
---

# agenda

`/agenda` runs `python3 scripts/workflow.py agenda` (`--json` for stored fields; `works/agenda.md` is the same list, generated). `/agenda <command> …` runs `agenda-<command> …`: `add --title "…" [--note "…"]`, `edit <item> [--title …] [--note …]`, `move <item> --first|--last|--before <item>|--after <item>`, `defer`, `solve [--outcome "…"]`, `drop [--reason "…"]`, `reopen`, `delete` (each on one or more items), `link <item> --phase <P>|--deferred <D>`, `unlink --phase <P>|--deferred <D>`; `new-phase` and `defer-job` take `--agenda <item>`.

In a linked checkout, changes made on the web arrive as inbox entries that `sync` and `next` apply as these commands; a refused one shows the command's line on the web.

Items are `open | deferred | solved | dropped`; an Open item reads In progress while a linked phase is not done. An item never affects `next`; defer makes no deferred job. Leave out `--id` (the engine mints `A7-m3`). A command on several items changes all or none; send a title starting with `-` as `--title=<t>`.
