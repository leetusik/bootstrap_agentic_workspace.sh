# Plan — P28.S1 Engine: nested awareness (implementation / high)

## Goal

Teach `scripts/workflow.py` the nested mode. The engine sits at `<host>/workflow/scripts/workflow.py`, its state stays in the nested repo (`ROOT` = `<host>/workflow`), and product code lives in the host repo. **Every nested branch is gated on `ROOT/nested.json` existing. With no marker, behaviour and output are byte-for-byte today's.**

Read first:
- `works/phases/active/P28/phase.md`: `## Decisions` items 1–7 and the `P28.S1` notes;
- `intent.md`.

## 1. Marker and roots

- **Loader:** add `NESTED = _load_nested()` near `ROOT` (L16). It reads `ROOT/"nested.json"` and returns `None` when the file is absent. Then `HOST_ROOT = (ROOT / NESTED["host_root"]).resolve() if NESTED else None`.
- **Schema (S1 owns it; S2 writes it):**
  ```json
  {"schema": 1,
   "host_root": "..",
   "commit_convention": {"inferred": "<text>", "confirmed": false, "text": null, "coauthor_trailers": "unknown"},
   "renames": {"skills": {}, "agents": {}}}
  ```
  `coauthor_trailers` is one of `allowed`, `forbidden` or `unknown`. `renames` maps each original name to its installed name, e.g. `{"commit": "wf-commit"}`.
- **`validate`:** when `nested.json` exists, check its schema. A malformed marker is an **error**, so a broken nested install is never mistaken for at-root mode. Also check that `HOST_ROOT` is a git work tree (warn if git is absent).

## 2. Paths the operator sees

- With cwd = host, printed paths must resolve from the host. Add one helper, e.g. `shown(p) -> str`:
  - nested: the path relative to `HOST_ROOT` (so `workflow/works/...`);
  - otherwise: today's `relative_to(ROOT)` string.
- **Use it only for output** that agents act on: `slice_path=`, the new-phase, new-slice and finish messages, and `phase.md`/budget lines.
- **Never use it for stored values.** Paths persisted into `index.json`, `slice.json`, `phase.json` and `events.jsonl` stay ROOT-relative, because the state lives in the nested repo.
- There are about 30 `relative_to(ROOT)` sites. Classify each one (printed vs stored) and change only the printed ones. List the classification in `result.md`.
- Engine hint lines that print `python3 scripts/workflow.py …`: when nested, print `python3 workflow/scripts/workflow.py …`. Use one helper or constant for the command prefix rather than 42 edits, but only where a hint is actually printed.

## 3. Host anchors and `phase-scope`

- **`new_phase` (L1473):** when nested, record `"host_anchors": {"created": <host HEAD sha>}` in `phase.json`. If the host has no commits yet, record `null`.
- **`review_phase` (L1623):** on `--verdict pass`, when nested, set `host_anchors.review_pass` to the host HEAD.
- **Readers** must handle the field being absent (legacy and at-root phases).
- **`phase_scope` (L2622), when nested:**
  - **base:** `--base`, else `host_anchors.created`. Diff `base..head` (no `^`: the anchor *is* the HEAD at creation).
  - **head:** `--head`, else `host_anchors.review_pass` if the review passed, else host HEAD.
  - `--base`/`--head` and every rev-parse, diff, status and rev-list run with `_git(..., cwd=HOST_ROOT)`.
  - **Pathspec:** `[".", ":(exclude)workflow"]`. Do **not** exclude `works`/`docs` in the host, because a host's own `docs/` is product.
  - **Missing anchor:** print one line saying so, suggest `--base <host-sha>`, and list only working-tree changes, mirroring today's no-creation-commit path (L2685–2693).
  - Keep the output format identical to at-root mode, so the review skill reads it unchanged.
- **Doc provenance** (`rev-parse HEAD`, L450): use the host HEAD when nested.

## 4. Parallel off

- These commands exit non-zero with one clear line when nested (`parallel worktrees are disabled in a nested personal install`): `parallel-start`, `parallel-gate`, `parallel-merge-finish`, `parallel-consolidated` and `parallel-teardown`.
- `parallel-status` and `parallel-skip` print that line and exit 0.
- `parallel_start_hint` (L2475) returns empty when nested.
- `current_stream` stays the default stream.

## 5. Agents through the host and the rename map

- `CLAUDE_AGENTS` (L102) becomes `(HOST_ROOT or ROOT) / ".claude" / "agents"`.
- `executor_agent_files` (L267–276) maps each canonical name (`slice-executor-mid`, `slice-executor-high`, `design-drafter`) through `NESTED["renames"]["agents"]` to its installed filename.
- `sync_agents` (L293), `executor-mode` and the validate drift check (about L1343) go through that function.
- When rewriting `model:`/`effort:`, `sync-agents` must keep the file's existing `name:` frontmatter (a renamed agent's `name:` is its `subagent_type`).
- `executors.toml` and `.env` stay at `ROOT`.

## 6. Design registry identity

When nested, `design-register` and `design-open`'s identity use the host: `repo = str(HOST_ROOT)`, id/name `HOST_ROOT.name`, and the `~/projects` containment check against `HOST_ROOT` (L3457, about L3617, about L3648). `DESIGN_ROOT_REL` stays under `ROOT`. Design artifacts in nested mode are private workflow files, not product.

## 7. `nested-convention` command

- **No flags:** print `commit_convention` and `coauthor_trailers`.
- **`--confirm --text "<convention>" --trailers allowed|forbidden`:** write `text`, set `confirmed: true` and set the trailers.
- **When not nested:** refuse with a clear line.
- **`next`, when nested:** add two lines:
  - `nested_host=<HOST_ROOT>`;
  - when not confirmed, `host_commit_convention=UNCONFIRMED (inferred: <…>) -- confirm with the operator before the first product commit, then: python3 workflow/scripts/workflow.py nested-convention --confirm ...`.
- **Help text:** add the command to `--help`.

## 8. Probes (core only, per the test rule)

Add **Test 14 "nested engine"** to `tests/retrofit_smoke.sh`, before the summary, using the existing `ok`/`bad`/`newtmp` helpers:
- **Fixture:**
  1. `git init` a host and commit a product file.
  2. Copy the current `scripts/workflow.py` plus `works/templates/` into `host/workflow/`, `git init` it, and write `nested.json`.
  3. Run `rebuild`.
  4. Run `new-phase P1`.
- **Asserts:**
  - `phase.json` carries `host_anchors.created` = host HEAD.
  - After a host product commit and an untracked file under `host/workflow/`, `phase-scope P1` lists the product file and nothing under `workflow/`.
  - `parallel-start P1` exits non-zero with the disabled line.
  - `next` prints `nested_host=` and `host_commit_convention=UNCONFIRMED`.
  - `nested-convention --confirm …` flips it.
  - A malformed `nested.json` makes `validate` fail.

S2's installer test becomes Test 15. Today's at-root tests must pass unchanged; that is the at-root invariant's check.

## Validation

- `bash tests/retrofit_smoke.sh`, run alone in its own Bash call in the foreground (it stalls when chained). It must end with zero failures.
- `python3 scripts/workflow.py validate` passes.
- `python3 installer/build.py`, then `python3 installer/build.py --check` passes. Do **not** bump `WORKSPACE_VERSION` (S3 does).

## Hand-off

- **`phase.md`:**
  - replace the consumed S1 notes;
  - add a `## Decisions` line pinning the final `nested.json` schema and the `host_anchors` field;
  - leave S2 a note with the exact schema it must write and the agent-rename contract;
  - add `## Doc impact` lines (architecture: two roots and nested mode; operations: `nested-convention`; qa: Test 14);
  - rewrite `## Now`.
- **`result.md`:** verdict block first, then the `relative_to(ROOT)` classification.
