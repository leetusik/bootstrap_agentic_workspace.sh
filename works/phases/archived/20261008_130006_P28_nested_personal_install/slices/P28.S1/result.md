# Result — P28.S1 Engine: nested awareness

- `status`: done
- `tier`: high
- `summary`: Taught `scripts/workflow.py` the nested personal install, every branch gated on `workflow/nested.json` (schema 1, validated; a malformed marker fails `validate` and every other command refuses): `HOST_ROOT`, host anchors in `phase.json` and a host-side `phase-scope`, `parallel-*` refused, host `.claude/agents` resolved through `renames.agents`, host-relative printed paths and hints, host design identity and doc provenance, and a new `nested-convention` command plus two `next` lines. Smoke Test 14 pins it; a differential run proves at-root output unchanged.
- `files_changed`: `scripts/workflow.py`, `tests/retrofit_smoke.sh`, `bootstrap_agentic_workspace.sh` (rebuilt), `works/phases/active/P28/phase.md`, `works/phases/active/P28/slices/P28.S1/result.md`
- `validation`:
  - `bash tests/retrofit_smoke.sh` (alone, foreground): PASS, 211 checks, `ALL RETROFIT SMOKE TESTS PASSED` (Tests 0–13 unchanged plus the 8 new Test 14 checks)
  - `python3 scripts/workflow.py validate`: PASS (only the existing P26/P27 debt, stale-doc and oversized-section warnings)
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: PASS (`WORKSPACE_VERSION` not bumped)
  - Differential at-root run (scratch, not shipped): 60 commands run in two fresh installs, one with the old engine and one with the new, git dates pinned. After normalizing timestamps, SHAs and tmp paths, outputs, exit codes and every resulting workspace file are identical. The one expected exception: the new `nested-convention` subcommand (old engine: argparse "invalid choice"; new engine: a one-line refusal at root).
  - Test 14 run against the OLD engine: every assert except the `validate` positive control FAILs, so the probes bite.
- `deviations`: additions within the plan's principle, nothing removed:
  1. More printed paths are host-relative than the `relative_to` sites alone: `doc-new-version`'s `edit_path=`, the `docs` listing, `deferred`'s `dashboard=`, `docs-debt` and `parallel-merge-finish` `<phase>/phase.md` lines, and the design commands' paths (`DESIGN_ROOT_SHOWN`). From a host cwd, an agent that writes to a ROOT-relative `edit_path` or design path would write into the host's own `docs/`, a footprint leak. Every one of these is identical at root.
  2. A malformed marker makes every command except `validate` refuse (`main`). The plan only said "validate errors". Refusing is how "never mistaken for at-root" holds for the other commands too.
  3. When a phase was created on an empty host (anchor recorded as `null`) and the host has commits now, `phase-scope` measures from the empty tree, as root does for a root commit. The plan's missing-anchor path stays for an absent or unresolvable anchor.
  4. In nested mode `new-phase`'s busy hint is suppressed as well as `parallel_start_hint`, because the parallel mode it suggests is off.
  5. Test 14 has 3 asserts beyond the plan's list: a `validate` positive control before the malformed case, `next` refusing on a malformed marker, and `sync-agents` resolving the renamed `wf-design-drafter` in the host and keeping its `name:`.
- `doc_impact`: 3 lines appended to `phase.md` `## Doc impact`: architecture.md (two roots / nested mode / `host_anchors` / host-side `phase-scope`), operations.md (`nested-convention`, the `next` lines, the parallel refusal, the host-root command prefix), qa.md (smoke Test 14).

## What landed (by plan section)

1. **Marker and roots.** `NESTED, NESTED_PROBLEMS = _load_nested()` and `HOST_ROOT` sit beside `ROOT`.
   - `nested_marker_problems()` is the schema 1 checker:
     - `schema`, `host_root`, `commit_convention` and `renames` are required;
     - `host_root` must be relative and resolve to a strict ancestor of ROOT;
     - a confirmed convention needs its text and an `allowed`/`forbidden` trailer rule;
     - an installed rename must be a bare name (no `/`, no leading `.`).
   - Unknown top-level keys only raise a `validate` warning, which leaves S2 room.
   - `validate` also errors when the host is not a git work tree, and warns when git is absent.
   - A marker too broken to name its host prints absolute paths and an absolute command.
2. **Printed paths.**
   - `shown(path)` returns the host-relative path when nested and today's `relative_to(ROOT)` string otherwise.
   - `shown_rel(rel)` does the same for stored strings, and at root returns the stored string untouched.
   - `WORKFLOW_CMD` is `python3 workflow/scripts/workflow.py` when nested. It replaced the literal at 37 printed sites. The two copies of the `## Slices` guidance line (`SLICES_GUIDANCE` and the template fallback) keep the literal, because they are stored in `phase.md` and are byte-identical to the template.
3. **Host anchors and `phase-scope`.**
   - `new-phase` (and so `promote-deferred --create-phase`) writes `host_anchors: {"created": <host HEAD or null>}` right after `acceptance`.
   - `review-phase --verdict pass` adds `review_pass`.
   - `validate` checks the block's shape when present (closed keys; each value is a hex SHA or null).
   - `_phase_scope_nested()` reads the host: base = `--base` or `created` (`base..head`, no `^`); head = `--head`, else `review_pass` once the review passed, else the host HEAD. Its pathspec is `. :(exclude)workflow`, computed from `relpath(ROOT, HOST_ROOT)`. The line format is the same, with `mode=nested` and `read from the host repo, workflow/ excluded`.
   - A missing anchor prints one `creation_commit=none (<why> -- pass --base <host-sha> ...)` line and lists only the working tree.
   - `_git_available`, `_rev_parse`, `_diff_product_files` and `_status_product_files` gained `cwd`/`pathspec` parameters whose defaults keep at-root behaviour.
   - Doc provenance (`head_commit`) uses the host HEAD.
4. **Parallel off.**
   - `_refuse_parallel_when_nested()` runs first in `parallel-start`, `-gate`, `-merge-finish`, `-consolidated` and `-teardown`: one line, exit 1.
   - `parallel-status` and `parallel-skip` print the same line and exit 0.
   - `parallel_start_hint` returns None, and `current_stream` returns None when nested.
5. **Agents.**
   - `CLAUDE_AGENTS = (HOST_ROOT or ROOT)/.claude/agents`.
   - `installed_agent_name()` maps each canonical name through `renames.agents`. `executor_agent_files` uses it, so `sync-agents`, `executor-mode` and the `validate` drift check all follow it.
   - `_patched_agent_md` already kept every line except `model:`/`effort:`. Its docstring now pins that this includes the renamed `name:`.
   - `executors.toml` and `.env` stay at ROOT.
6. **Design identity.**
   - `design-init` takes its default id and name from `HOST_ROOT.name`.
   - The `design-register` entry's `repo` is `HOST_ROOT`.
   - The deck containment check uses `HOST_ROOT`.
   - `DESIGN_ROOT_REL` stays under ROOT.
   - (The plan said "design-open's identity". `design-open` carries no identity: the identity line, L3457, is `design-init`, so that is what changed.)
7. **`nested-convention`.**
   - Bare: prints `nested_host=`, `commit_convention=confirmed|UNCONFIRMED`, `coauthor_trailers=`, then the inferred and confirmed texts.
   - `--confirm --text … --trailers allowed|forbidden`: rewrites only `commit_convention` (keeps `inferred`), re-validates before writing, and logs a `nested_convention_confirmed` event.
   - `--text`/`--trailers` without `--confirm` is refused, and so is the whole command outside a nested install.
   - `next` prints `nested_host=` and `host_commit_convention=UNCONFIRMED (inferred: …) -- confirm … then: python3 workflow/scripts/workflow.py nested-convention --confirm --text "<convention>" --trailers allowed|forbidden`. Once confirmed, it prints `host_commit_convention=confirmed (coauthor_trailers=…) -- follow it …`.
   - The command is listed in `--help`.
8. **Test 14 "nested engine"**, in `tests/retrofit_smoke.sh` before the summary.
   - Fixture: a host with a baseline commit; `host/workflow/` holds the live engine, `works/templates/`, a seed install's `docs/`, `git init`, and the marker with an agent rename. Commands run from the host root.
   - Asserts:
     - the `created` anchor equals the host HEAD;
     - `phase-scope` lists the committed `src/feature.py` **and** the host's `docs/guide.md`, and nothing under `workflow/` (an untracked `workflow/scratch.txt` is present);
     - `parallel-start` exits non-zero with the line;
     - `next` prints `nested_host=`, `UNCONFIRMED (inferred: …)` and `slice_path=workflow/works/...`;
     - `--confirm` flips the convention;
     - `sync-agents` resolves the renamed agent and keeps its `name:`;
     - `validate` passes when well-formed, fails on a truncated marker, and `next` refuses on it.
   - S2's installer test becomes Test 15.

## `relative_to(ROOT)` classification (original line numbers)

| Line | Site | Class | Change |
|---|---|---|---|
| 305, 306 | `sync_agents` changed / missing | printed (also the `agents_synced` event payload) | `shown()`: agent files live in the host when nested, where `relative_to(ROOT)` would raise; identical at root |
| 373 | `show_executor_mode` stale list | printed | `shown()` |
| 665 | `all_active_phases` phase `path` | stored (index.json, backlog.md; re-joined onto ROOT) | kept |
| 669 | slice `path` | stored | kept |
| 685 | `deferred_jobs` `path` | stored (deferred.md) | kept |
| 1316 | validate: missing deferred.json | printed | `shown()` |
| 1322 | validate: deferred in wrong folder | printed | `shown()` |
| 1347, 1352 | validate: agent file missing / out of sync | printed (agent paths) | `shown()` (+ `WORKFLOW_CMD`) |
| 1498 | `new-phase` message | printed | `shown()` |
| 1529 | `new-slice` message | printed | `shown()` |
| 1962 | `parallel-start` legacy-pin refusal | printed (unreachable when nested) | `shown()` |
| 1998 | `parallel-start` `stamp_paths` | operational git pathspec, run at ROOT | kept |
| 2011 | `parallel-start` stamp message | printed (unreachable when nested) | `shown()` |
| 2551 | `_phase_creation_commit` archived path | operational git pathspec, run at ROOT | kept |
| 2794 | `next` `slice_path=` | printed | `shown()` |
| 2836 | `defer-job` message | printed | `shown()` |
| 2853 | promoted slice `source.path` | stored (slice.json) | kept |
| 2861 | `promoted_to.path` | stored (deferred.json) | kept |
| 2865 | promote: destination exists | printed | `shown()` |
| 2869 | `promote-deferred` message | printed | `shown()` |
| 2883 | drop: destination exists | printed | `shown()` |
| 2887 | `drop-deferred` message | printed | `shown()` |
| 2927 | archive manifest `source_path` / `archive_path` | stored | kept |
| 2932 | `phase_archived` event | stored | kept |
| 2948 | `archive-phase` message | printed | `shown()` |
| 2977 | `archive-all` list | printed | `shown()` |
| 3004 | `rotate-backlog` list | printed | `shown()` |
| 3667 | `design-migrate` `rel` | printed | `shown()` |

That is 31 ROOT sites: 21 printed and changed, 10 stored or operational and kept. Three non-ROOT `relative_to` calls:
- 3301 and 3685 are design-root internals, unchanged.
- 3651 is the deck containment check, which now tests `HOST_ROOT or ROOT` (§6).

## Verified by hand in a scratch nested fixture (not shipped)

- `new-phase`, `next`, `phase-scope` (anchor; `--base`; review-pass head with a later unrelated host commit excluded; legacy phase with no anchor; empty-host anchor `null`, before and after the host's first commit).
- `--json` (same keys, `mode: nested`).
- All seven `parallel-*` commands.
- `nested-convention`: show, misuse, confirm, and the `next` line flipping.
- `sync-agents` / `--check` / `executor-mode` with the renamed agent.
- `doc-new-version`: `edit_path=workflow/docs/versions/...`, with the frontmatter `commit:` set to the host HEAD.
- The `docs` listing.
- `design-init` / `-open` / `-register` (id `host`, `repo` = host, root under `workflow/`).
- Malformed markers: unparseable JSON; bad trailers, a `../` rename and `host_root: "../.."` (not a work tree); an unknown key gives a warning only.

## Observations for later slices (also in `phase.md`)

- **Host-side files show up as uncommitted product files.** `phase-scope`'s working-tree list shows the installed host-side files (`.claude/agents/*`, skills, `CLAUDE.local.md`, `settings.local.json`) unless `.git/info/exclude` hides them. S2 already plans those entries; Test 15 should assert `phase-scope` stays clean after an install.
- **`docs/reference/design/` is missing from decision item 2's rewrite list.** In an installed nested skill or agent it would still point into the host's `docs/` (the design drafter writes cards there). The engine now prints `workflow/docs/reference/design/...`.
- **Marker-name collision at root.** An at-root repo that already has an unrelated `nested.json` at its root would be read as a broken nested install: `validate` fails and commands refuse, loudly. I raised it as an operator question; the marker name is one constant (`NESTED_MARKER`).
- **`## Slices` guidance line.** The guidance line inside the generated `## Slices` block keeps `python3 scripts/workflow.py rebuild`. It is stored text, byte-identical to the template, and a rebuild never rewrites it. This is harmless, and S2's rewrite does not touch `works/`.
