# Plan — P29.S1 Installer: nested by default

**Tier:** high (core invariant: the mode routing every install and every `--update` passes through).

Read first:
- `works/phases/active/P29/intent.md`
- `works/phases/active/P29/phase.md` `## Decisions` (decisions 1–9 are binding)
- `works/phases/active/P28/phase.md` `## Decisions` (the nested installer and the engine contract this builds on)

**Goal:** change which layout runs. Do not change how either layout installs.

## 1. `installer/wrapper.sh`

- **Add `--at-root`** (`at_root=1`) and export `AT_ROOT`.
- **Cross-flag checks.** Each failing check dies with one line:
  - `--at-root` with `--nested` → `--at-root and --nested are mutually exclusive`.
  - `--nested` with `--into-existing` → keep the existing check.
  - `--force-empty-ok` without `--at-root` and without `--into-existing` → `--force-empty-ok applies to the at-root install; add --at-root`. This replaces today's `--nested` + `--force-empty-ok` check, which the new rule already covers through the `--at-root`/`--nested` conflict.
  - `--at-root` with `--into-existing` is allowed (redundant).
  - `--at-root` and `--nested` are both allowed with `--update`; `main.py` checks them against the detected layout.
- **Usage text.** It must say:
  - the default is the private nested install (`<target>/workflow/` plus untracked host `.claude/` files, hidden by `.git/info/exclude`);
  - a new or empty dir is `git init`ed as the host;
  - `--at-root` is the committed, team-visible layout for a fresh dir;
  - `--into-existing` is the at-root retrofit;
  - `--update` detects the layout;
  - `--nested` is accepted and redundant.

  Keep it short. S2 does the final text pass against the docs.

## 2. `installer/main.py`: mode resolution

Replace `NESTED = os.environ.get("NESTED") == "1"` (around L52) with one resolver, placed **before** `HOST, ROOT` are set and before `MANAGED_DIRS` and `SHOWN_PREFIX` read `NESTED`. Inputs:
- `EXPLICIT_NESTED` from the `NESTED` env var
- `AT_ROOT_FLAG` from the `AT_ROOT` env var
- `RETROFIT`
- `UPDATE`

Then:

- **`RETROFIT`** → at-root.
- **`UPDATE`** → detect from `T = TARGET.resolve()`:
  - `nested_here` = `T/workflow/.agentic-nested.json` exists (use `lexists` or `is_file`).
  - `root_here` = `T/scripts/workflow.py` exists **and** works are present (`works/state.json`, or any `works/phases/active/*/phase.json`; the same test as the current update guard).
  - **Both** → refuse (exit 1, stderr): name both paths, say the layout is ambiguous, and say to pass `--nested` or `--at-root` explicitly. When the operator passes one of the two flags, that flag decides the layout.
  - **One** → that layout. An explicit flag that contradicts it refuses with one line, for example `--at-root given, but <T> holds a nested install (workflow/.agentic-nested.json); drop the flag`. A flag that matches does nothing.
  - **Neither** → at-root, so today's "no agentic workspace found here to update" error fires. In that error, replace the now-unreachable `--update --nested` hint line with one hint: a new install is just `sh … <dir>` (nested by default), or `--at-root` / `--into-existing`.
- **`AT_ROOT_FLAG`** (not updating) → at-root.
- **Otherwise** (a fresh install, whether or not `--nested` was given) → nested.

## 3. Fresh nested install into a host that is not a git repo (`nested_preflight`, not `UPDATE`)

1. **Today's refusals** for "not a directory" and "not inside a git work tree" now branch on whether `HOST` is absent, or empty in the `EMPTY_OK_ALLOWLIST` sense: no entries outside the allowlist. `.git` is in the allowlist, but in this branch the dir is not a repo.
2. **Empty or absent** → `mkdir -p` + `git init -q` the host. Set a module flag, `HOST_INITED = True`, and record whether the directory itself was created. Then continue with the normal nested checks.
3. **If any later refusal happens before the first write** (for example a `.gitignore` in an otherwise-empty dir re-includes a target and `_nested_unignored` refuses), undo the init: remove the `.git` this run created, and the directory if this run created it. Route that through `_nested_refuse`, so that every pre-write refusal cleans up. Nothing the operator had may be touched.
4. **Non-empty and not a git repo** → refuse with nothing written: `<HOST> is not a git repo and is not empty: run git init there first (then re-run), or install the committed at-root layout with --at-root`.
5. **Inside a work tree but not its root** → today's refusal, with `--at-root` added to the hint.
6. **The `git` missing check stays first.** Its text no longer says `--nested` is a choice: it reads "the default (nested) install needs git on PATH … or use --at-root".

Reword the other `--nested …` messages in the same way: the layout is now the default, not a flag. The full list:
- L497, L499, L502, L506
- the already-installed exit-0 line at L516: `use --update to refresh it`
- the update banner at L976: `--update`, plus `(nested, detected)`
- the install banner at L991: still says "privately", and drops `(--nested)`
- the old plain-update hint at L1044

## 4. Layout-already-in-place guard (decision 4)

A fresh nested install into a target whose root holds an at-root workspace (`scripts/workflow.py` plus works present) refuses before anything is written. Exit 1, with: `<T> already holds an at-root agentic workspace: use --update to refresh it (a fresh install would put a second, nested one beside it)`.

This applies to the upstream repo itself too. Running the bare installer on it must refuse.

## 5. Convention for an initialised host (decision 5)

Where the marker's `commit_convention` is first written (around L914), check `HOST_INITED`. When the installer itself ran `git init` on the host, write:

```
{"inferred": None, "confirmed": True,
 "text": "type(scope): summary -- imperative, no trailing period",
 "coauthor_trailers": "allowed"}
```

- An existing host keeps v49's infer-and-ask path.
- Make sure the marker still passes the engine's `nested_marker_problems`: `inferred` null, and a confirmed convention with non-empty `text` and `allowed`.
- Make sure `nested_infer_convention` survives an unborn HEAD. `git log` exits 128, which is treated as no history. The code looks like it already handles this; confirm it live.
- The install banner should not tell an initialised host to confirm a convention. It should tell the operator to make the first nested commit, and say the host has no commits yet.

## 6. Engine

No change is expected. On a freshly initialised host, run live from the host root:
- `python3 workflow/scripts/workflow.py next`, with no `UNCONFIRMED` line
- `new-phase` (`host_anchors.created` is null)
- `validate`
- `phase-scope <P>`, which should diff from the empty tree

Touch `scripts/workflow.py` only if one of these actually breaks. If it does, keep the change minimal and say so in `result.md`.

## 7. Smoke suite (`tests/retrofit_smoke.sh`, decision 8; core probes only)

**Correction to decision 8's count.** The plain fresh at-root `sh "$BOOT"` calls I found are L765 (`$F`), L1089 (`--force-empty-ok`, `$H`), L1160 (`$G`), L1265 (`$W`) and L1501 (the nested seed, which builds an at-root tree that is then copied under `workflow/`). That is about 5, not 11.

1. Add `--at-root` to every invocation whose test expects the at-root layout. Find them by what each test asserts, not by the count. Check whether L1160's `--with-explain` is a rejection test before touching it.
2. Keep the P28 `--nested` probes (L1580+) passing unchanged, since `--nested` is now a no-op. Update only the greps on reworded messages.
3. Add **one** new test, "P29 nested by default", with probes (a)–(f) from decision 8:
   - (a) A bare install into a new non-existent dir: the host has `.git`, there is `workflow/.git`, and the marker's convention is confirmed with `trailers: allowed`. The host's `git status --porcelain --untracked-files=all` is empty, and `next` from the host root prints no `UNCONFIRMED`.
   - (b) A bare install into an existing git repo with one commit installs nested, and that host's status stays clean.
   - (c) A bare `--update` on the nested host from (b) works and says it is nested. `--update --nested` also works.
   - (d) A bare `--update` on an at-root install (`--at-root`) stays at-root: there is no `workflow/`, and the at-root files are refreshed.
   - (e) A bare install over that at-root workspace exits 1, and the tree is unchanged (compare a listing signature before and after).
   - (f) Each of these exits 1:
     - `--update --at-root` on the nested host
     - `--at-root --nested`
     - `--force-empty-ok` without `--at-root`
     - a bare install into a non-empty non-git dir, which also writes nothing: no `.git` and no `workflow/`
4. **Run the suite once, alone in its own foreground Bash call:** `sh tests/retrofit_smoke.sh`, with no chained prefix and nothing else in that call. Report the pass/fail totals. All must pass.

## 8. Build

`python3 installer/build.py`, then `python3 installer/build.py --check`, which must pass. Do not bump `WORKSPACE_VERSION`: that is S2's job.

## 9. Notebook (`phase.md`, edited under budget)

- **`## Decisions`:** add a compact **"Final flag shape (P29.S1)"** block for S2:
  - every flag;
  - the resolution order;
  - the exact refusal and hint texts that operators will see;
  - the banner changes;
  - the initialised-host convention.

  Also correct decision 8's count line.
- **`## Doc impact`:** one line about the install default, the `--at-root` flag, update auto-detection, and the initialised host (operations and architecture installer sections).
- **`## Now`:** rewrite it.

## Return

`result.md` with the verdict block first:
- `files_changed`
- the smoke totals
- the live engine check output, in short form

Do not commit and do not transition state.
