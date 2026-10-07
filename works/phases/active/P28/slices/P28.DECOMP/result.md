# Result — P28.DECOMP (decomposition)

## Verdict

- **status:** done
- **tier:** high
- **summary:** Checked against the official docs that Claude Code still loads `CLAUDE.local.md`, expands `@imports` in it, passes it to subagents, and finds `.claude/agents|skills` by walking up to the repo root. That closes design item 4, with one change: the import target is `workflow/CLAUDE.workspace.md`, never a `workflow/CLAUDE.md`. Then cut `P28.S1` (engine, high), `P28.S2` (installer `--nested`, high) and `P28.S3` (text + v49, low) as bare folders, chained 1→2→3.
- **files_changed:** `works/phases/active/P28/phase.md`; `works/phases/active/P28/slices/P28.S1/slice.json`, `P28.S2/slice.json`, `P28.S3/slice.json` (created by `new-slice`); `works/phases/active/P28/slices/P28.DECOMP/result.md`; plus the engine-regenerated `works/backlog.md`, `works/index.json`, `works/events.jsonl`
- **validation:** `python3 scripts/workflow.py validate` — passed (3 warnings that were already there: P26/P27 consolidation debt, stale docs, oversized doc sections; none from P28)
- **deviations:** One refinement of design item 4, within its intent. The import is `@workflow/CLAUDE.workspace.md` (the existing retrofit sidecar name), not `@workflow/CLAUDE.md`. The docs say a subdirectory `CLAUDE.md` loads on demand, and they never say an imported copy is de-duplicated against it. Also, the Claude Code check was done from the docs only. A throwaway local probe (a scratch host repo plus `claude -p`) was denied permission and not retried, so S2's live run is told to confirm the loading with `/context`.
- **doc_impact:** none. DECOMP changes no durable truth.

## The verification (Claude Code, docs fetched 2026-10-07; local CLI is 2.1.292)

All answers, with their sources, are in `phase.md` `## Decisions` under "Claude Code verification" and are not repeated in full here. In short:

| Question | Answer | Source |
|---|---|---|
| Is `CLAUDE.local.md` still supported? | Yes. It is the "Local instructions" scope. It loads at launch from cwd and every ancestor, after `CLAUDE.md` in the same directory, and is "treated the same way". The 2025 deprecation wording (issue #2394, closed) no longer appears in the docs | https://code.claude.com/docs/en/memory ; https://github.com/anthropics/claude-code/issues/2394 |
| Does it honour `@imports`? | Yes, because it is treated like `CLAUDE.md`. Paths resolve relative to the importing file, max 4 hops. An import outside cwd counts as "external" and needs a one-time approval. Imports inside code spans or fences are skipped | memory doc |
| Do subagents load it? | Yes. A non-fork subagent loads "every level of the CLAUDE.md hierarchy … including `CLAUDE.local.md`" unless `omitClaudeMd: true`, which none of our 3 agents set | https://code.claude.com/docs/en/sub-agents |
| Are `.claude/agents` loaded from the project root? | Yes. Claude Code walks up from cwd to the repository root and the closest one wins. `subagent_type` is the `name:` frontmatter ("the filename doesn't have to match"). Skills are found the same way. A personal skill beats a project skill | sub-agents doc; https://code.claude.com/docs/en/skills |
| `settings.local.json` | It overrides `settings.json`, and permission arrays from both merge. Claude Code adds it to the *global* git excludes only when it creates the file itself | https://code.claude.com/docs/en/settings |

The docs turned up four consequences, all pinned in `## Decisions` or the S2 notes:
1. **Import target:** `workflow/CLAUDE.workspace.md`. Nothing under `workflow/` is named `CLAUDE.md`, and there is no `workflow/.claude/`, because nested `.claude/skills` would also load on demand as `/workflow:<name>` duplicates.
2. **Where sessions start:** at the host root. Starting inside `workflow/` makes the nested repo the "repository root", so the host's `.claude/` is not found. Starting in a host subdirectory turns the import into an "external" one.
3. **Renames** change the `name:` frontmatter as well as the directory or filename. Clash detection reads the host's `name:` fields too.
4. **The installer-written `settings.local.json`** needs its own `info/exclude` entry.

**Fallback recorded:** if the S2 live run shows the import not expanding, inline the rewritten contract into `CLAUDE.local.md`. The `~/.claude/CLAUDE.md` fallback from `intent.md` is not needed.

Item 4 is closed, so no `P28.R1` or `P28.DECOMP2` was cut.

## The cut

```
python3 scripts/workflow.py new-slice --phase P28 --slice P28.S1 --name "Engine: nested awareness" --kind implementation --risk high --order 1
python3 scripts/workflow.py new-slice --phase P28 --slice P28.S2 --name "Installer --nested: zero-footprint install, rewrite, clash map, update" --kind implementation --risk high --order 2 --depends-on P28.S1
python3 scripts/workflow.py new-slice --phase P28 --slice P28.S3 --name "Text, /update-workspace, docs and release v49" --kind implementation --risk low --order 3 --depends-on P28.S2
```

All three succeeded. The `## Slices` table shows S1–S3 with these kinds and risks, and none of the three folders has a `plan.md`. The rating triggers, the compact machinery footprint (line refs spot-checked against the current tree; `_phase_creation_commit` sits at L2541, not L2549), design items 1–7 and the invariants are all in `phase.md` `## Decisions`. The per-slice notes for S1, S2, S3 and all slices are in `## Notes for later slices`.

## Dead ends

- The live probe was denied permission at the first Bash call (fixture creation) and not retried. The plan only required the docs.

## For the orchestrator

- After `finish-slice P28.DECOMP`, run `accept-gate P28 --require`, as the plan says. Per `intent.md`, the gate stays open until the operator has run the flow in the real company repo.
- No operator questions were raised.
