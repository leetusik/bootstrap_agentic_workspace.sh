# Result: P29.S1 Installer: nested by default

- **status:** done
- **tier:** high
- **summary:** The installer now nests by default. A new or empty non-git target is `git init`ed as the host and gets a confirmed convention, and that init is undone if a refusal comes before the first write. `--at-root` reaches the committed layout, and `--update` detects which layout is installed (ambiguous or contradicting flags refuse). A bare install over an at-root workspace refuses, and so does any run on a nested install's `workflow/`. At-root output is byte-identical to v49 behind `--at-root`, and the engine is untouched (checked live).
- **files_changed:**
  - `installer/wrapper.sh`
  - `installer/main.py`
  - `tests/retrofit_smoke.sh`
  - `bootstrap_agentic_workspace.sh` (rebuilt)
  - `works/phases/active/P29/phase.md`
  - `works/phases/active/P29/slices/P29.S1/result.md`
- **validation:**
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: PASS (`OK: bootstrap_agentic_workspace.sh is in sync with installer/ source`). `WORKSPACE_VERSION` stays 49.
  - `sh tests/retrofit_smoke.sh`, run once, alone in its own foreground call: PASS, `ALL RETROFIT SMOKE TESTS PASSED`, **235 PASS / 0 FAIL**. The baseline was 226; Test 16 adds 9 asserts.
  - `python3 scripts/workflow.py validate`: PASS.
  - Live engine checks on an installer-initialised host: PASS (below).
  - Old-vs-new at-root differential: identical (below).
- **deviations:** All of these err toward refusing, and each is recorded in `phase.md` `## Decisions` → *Final flag shape (P29.S1)*.
  1. **Added a refusal for a nested install's own `workflow/` as the target.** It applies to any `--update` and to a fresh nested install. In v49, a plain `--update` there would have written `CLAUDE.md` and `.claude/` into `workflow/`.
  2. **An absent target inside another repo's work tree refuses.** It gets the same answer an existing empty directory there gets, plus a `git init` hint, instead of being initialised as a repo nested in the parent. This is raised as an operator question.
  3. **The at-root-in-place guard runs before the git-on-PATH check.** Without git, the "use --update" advice is still the right one.
  4. **For an initialised host, the banner drops the "Any remote … company's org" line.**
  5. **`--update --force-empty-ok` now refuses without `--at-root`.** This follows from the plan's literal rule; v49 ignored the flag on an update.
- **doc_impact:** `- operations.md, architecture.md (installer sections): the installer's default layout is now the nested install … (P29.S1)` (full line in `phase.md` `## Doc impact`).

## What changed

**`installer/wrapper.sh`**
- New `--at-root` flag (`AT_ROOT` exported).
- Refusals:
  - `--at-root and --nested are mutually exclusive`
  - `--force-empty-ok applies to the at-root install; add --at-root` (fires without `--at-root` and without `--into-existing`; it replaces v49's `--nested`/`--force-empty-ok` line)
  - `--nested`/`--into-existing` is kept as it was.
- The usage text has a short "By default the install is private and nested …" paragraph, and covers `--at-root`, `--force-empty-ok` "With --at-root", `--into-existing` "At-root retrofit", `--update` "layout … detected" and `--nested` "Accepted and redundant". S2 does the final text pass.

**`installer/main.py`**
- **`resolve_layout()`** sits before `HOST, ROOT`. `NESTED_DIR`/`NESTED_MARKER` moved above it, and `_nested_refuse` moved up beside it. It holds the resolution order and the refusals recorded in `## Decisions`.
- **Undo machinery:**
  - `_nested_undo_init()` removes the `.git` this run created and then `rmdir`s each directory it created, deepest first, only if empty.
  - `_nested_refuse` calls it first, so every pre-write refusal cleans up.
  - The guards block wraps `nested_preflight()` and `nested_plan()` in `try/except BaseException`, so a crash also undoes the init.
  - The guards block sets `_HOST_INIT_UNDO = None` just before `ROOT.mkdir`, the first write. From that point the init is kept.
- **`nested_init_host()`** applies to an absent target, or a directory that is empty in the allowlist sense, has no `.git` and sits in no work tree. It runs `mkdir -p` and `git init -q`, then sets `HOST_INITED`. For an absent target, it checks whether the nearest existing ancestor is inside a work tree, and refuses if so.
- **`nested_preflight()`** was reordered and reworded: at-root guard, git check, not-a-dir check, init, work-tree checks, then P28's checks unchanged. Helpers: `_work_tree_top()`, `_host_empty_or_absent()`, `_nested_refuse_inside()`.
- **`nested_plan()`:** `HOST_INITED` selects `NESTED_INIT_CONVENTION`. Otherwise a confirmed convention is kept, or one is inferred (inference no longer runs when the result is unused).
- **Banners:** see `## Decisions`.
- **Update error:** the "no agentic workspace found here to update" error now carries one hint instead of two.

**`tests/retrofit_smoke.sh`**
- `--at-root` was added to 4 calls: Test 5 `$F` and `$H`, Test 12 `$W` and Test 14 `$NS/seed`. Test 8's `--with-explain` is a rejection test and was left alone. The Test 5 title and the header comment were updated.
- The P28 `--nested` probes are unchanged and still pass. None of their greps hit a reworded message: "already installed" and "mutually exclusive" both survive.
- New **Test 16 "P29 nested by default"** covers probes (a)–(f), 9 asserts:
  - (a) A new dir is initialised and nested. Its convention is confirmed with trailers allowed, its status is clean, and `next` prints no UNCONFIRMED.
  - (b) An existing repo with one commit gets the nested layout; its status and HEAD are unchanged.
  - (c) A bare `--update` prints `(nested, detected)`, and `--update --nested` also works.
  - (d) A bare `--update` on an `--at-root` install stays at-root and refreshes a modified skill.
  - (e) A bare install over that at-root workspace exits 1, and the tree signature is unchanged.
  - (f) Each of these exits 1:
    - `--update --at-root` on the nested host (tree unchanged)
    - `--at-root --nested`
    - `--force-empty-ok` alone
    - a non-empty non-git dir (no `.git` and no `workflow/` afterwards)

## Live checks (scratchpad, not in the repo)

- **Fresh bare install into `new/proj` (absent, with an absent parent):**
  - rc 0. The host has `.git`, `.claude`, `CLAUDE.local.md` and `workflow`.
  - `git status --porcelain --untracked-files=all` is empty, and `git status` shows "no commits yet".
  - Marker convention: `{'inferred': None, 'confirmed': True, 'text': 'type(scope): summary -- imperative, no trailing period', 'coauthor_trailers': 'allowed'}`.
- **Engine on that host (section 6), no engine change:**
  - `next`: `host_commit_convention=confirmed (coauthor_trailers=allowed) …`, with no UNCONFIRMED.
  - `new-phase --phase P1`: `host_anchors` = `{'created': None}`.
  - `validate`: `Workflow validation passed.`
  - `phase-scope P1` before any host commit: `creation_commit=none (… still has none …)`, `uncommitted_product_files=1  A app.py`.
  - After `git add -A && git commit` in the host: `base=4b825dc642cb6eb9a060e54bf8d69288fbee4904 (the empty tree …)`, `range=4b825dc..b3af49b commits=1`, `product_files=1  A app.py`. `git add -A` staged only `app.py`, because the workspace's files stay ignored.
- **Unborn HEAD on an existing host:** this is a `git init`ed repo with no commits, which is not this installer's init. `nested_infer_convention` survives `git log` exit 128. The marker records `inferred: None, confirmed: False`, and the banner prints `UNCONFIRMED (inferred: nothing -- the host has no history yet)`.
- **Refusals, each exit 1 with nothing left behind:**
  - A non-empty non-git dir: only `notes.txt` remains.
  - An empty dir whose `.gitignore` has `!CLAUDE*.md`: the init happens, then the ignore preflight refuses. Only `.gitignore` remains, so the `.git` this run created is gone.
  - An absent `parent/sub/new` under a parent repo: refused with the `git init` hint, and `sub` is not created.
  - An empty and a non-empty dir under a parent repo: refused. Only the empty one gets the hint.
  - `--update --at-root` on a nested host; `--at-root --nested`; `--force-empty-ok` alone; `--nested --force-empty-ok`.
  - Ambiguous `--update`, with both layouts present: refused with the two-line text, and `--update --at-root` picks at-root.
  - `--update` and a bare install on `unborn/workflow`: refused, with the message naming the host root.
  - `--update` on an empty dir: the new single hint.
  - A bare install over an `--at-root` workspace: refused, tree signature unchanged.
- **Forced undo of a created path:**
  - Method: the artifact's Python body was extracted to the scratchpad, with `_nested_unignored` replaced by a fixed failure.
  - Target `deep/a/b`, all three absent: after the refusal, the scratch dir is empty, so all three created dirs are removed.
  - Target `emptyd` holding only `README.md`: after the refusal it holds only `README.md`.
- **Upstream repo:**
  - On a `git clone` in the scratchpad, a bare install refused: `… already holds an at-root agentic workspace: use --update …`. `git status --porcelain --untracked-files=all --ignored` was unchanged.
  - The same bare run on the live upstream checkout gave the same refusal, rc 1. `git status --porcelain --untracked-files=all` was unchanged and no `workflow/` was created.
- **At-root differential** (HEAD's artifact vs the new one, scratchpad):
  - fresh install (old with no flag, new with `--at-root`): `diff -r` empty, and the banner is identical;
  - `--update` on a copy with a modified skill: trees identical, banner identical;
  - `--update --dry-run`: identical;
  - `--into-existing` on a small non-git repo: trees identical, banner identical.
- **Nested update of an initialised host:** `--update` keeps the confirmed convention, and the host side shows `updated 0, added 0, unchanged 42`.

## Notes

- **A dead end that was only a probe artifact.** Piping the installer's `--update` output through `head -1` killed the child `validate` with SIGPIPE, and a `CalledProcessError` traceback followed. Re-running without the pipe was clean. It is not a defect.
- **Pre-existing, not changed:** an at-root `--update` (or `--update --dry-run`) on a non-existent path still runs `ROOT.mkdir` before the "no agentic workspace found" error, so it leaves an empty directory. That is v49's at-root behaviour, kept under decision 6. A bare `--update` with no install now also reaches it, since "neither" routes to at-root. Under v49, `--update --nested` refused there without creating anything. This is a deferred-job candidate, not a finding.
- **Recorded in `phase.md`, not restated here:**
  - `## Decisions`: decision 8's count corrected (4, not 11); the engine confirmation; the *Final flag shape (P29.S1)* block.
  - `## Doc impact`: one line.
  - `## Operator Questions`: one entry.
  - `## Notes for later slices`: the consumed S1 note removed, plus S1 → S2 and S1 → REVIEW notes.
  - `## Now`: rewritten.
