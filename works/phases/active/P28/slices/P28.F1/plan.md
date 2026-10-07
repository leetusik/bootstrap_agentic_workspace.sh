# Plan — P28.F1 Nested install verifies every host target is actually ignored (fix / high)

## Finding (P28.REVIEW, blocking)

A tracked host `.gitignore` pattern outranks `.git/info/exclude`. A negation such as `!.claude/skills/**`, an allowlist (`*` / `!*/` / `!*.md`) or `!CLAUDE*.md` therefore re-includes what our exclude block hides. The install's files then show as untracked, `git add -A` could stage them (and `workflow/` as a gitlink), and the installer still prints "the host's git status stays clean". Nothing checks this on install or on `--update --nested`.

The reproduction and the fix shape are in the `(from P28.REVIEW, for P28.F1)` note in `phase.md`. The review's `result.md` has the evidence.

**Rated high:** core invariant (the no-footprint guarantee), and it fixes S2's high-tier work.

## Fix

All of it lives in `installer/main.py`'s nested path (`nested_plan()` about L690, the write step, and the banner about L894). At-root installs stay byte-identical.

1. **Self-hiding skill dirs (prevention for the commonest case).**
   - Each of **our** installed skill directories, `.claude/skills/<installed>/`, also gets a `.gitignore` containing `*`.
   - A lower-level `.gitignore` outranks the parent's negation, and `*` matches the `.gitignore` itself, so the directory hides itself completely.
   - Add these files to the install, to `--update --nested` and to the `installed` bookkeeping, as S2 tracks host-side files.
   - Make sure the rewrite and post-check machinery ignore them.
   - This covers `!.claude/skills/**`-style hosts without refusing.
   - It cannot cover targets that sit directly in team directories: our agent files in `.claude/agents/`, `CLAUDE.local.md`, `.claude/settings.local.json` and `workflow/`.
2. **Preflight, before any write, on install and `--update --nested` alike.** Decide, for **every** host-side target, whether it **will be ignored** once our exclude block is in place:
   - the targets are each skill dir and the files in it, each agent file, `CLAUDE.local.md`, `.claude/settings.local.json` and `workflow/` (as a directory);
   - the check must be made **before** the block or the files exist. One way is `git -C HOST -c core.excludesFile=<temp file holding our exclude block> check-ignore -v --no-index --non-matching --stdin`. `core.excludesFile` ranks below `.gitignore`, which is exactly the question being asked: does a `.gitignore` negation beat us? Verify that this works for paths that do not exist yet, and for the directory form `workflow/` (a trailing slash, or creating the directory first if that is the only reliable way, as long as nothing else is written);
   - account for the per-dir `.gitignore` from step 1. If check-ignore cannot see a not-yet-written per-dir file, model it, or write and check the skill dirs in a staging order that still leaves the host untouched on refusal. **Choose and record which.**
   - **If any target would not be ignored:** refuse with **nothing written** and exit non-zero. Name each such target with the deciding `file:line:pattern`, and say in one line why: a tracked `.gitignore` re-includes it, and `info/exclude` cannot override that.
   - Do not add an override flag in this slice.
3. **Post-write check.** After writing, run `git -C HOST status --porcelain --untracked-files=all -- <targets>`. It must be empty.
   - Print the "stays clean" banner line **only** when it is.
   - Otherwise exit non-zero with the listed paths and a clear next step. This should be unreachable once step 2 works; it is the belt-and-braces.
4. **Tests:** extend Test 15 with one-line asserts:
   - **(a)** a host whose tracked `.gitignore` is `.claude/*`, `!.claude/skills/`, `!.claude/skills/**` installs, and the host status stays empty (prevention);
   - **(b)** a host with `!CLAUDE*.md` is refused, with nothing written (host tree unchanged, no `workflow/`) and the message naming `CLAUDE.local.md`;
   - **(c)** an allowlist host (`*` / `!*/` / `!*.md`) is refused with nothing written.

   Keep it to these three.
5. **Claims:**
   - correct the "the host's git status stays clean" wording in both READMEs' private-use section and in the `## v49` CHANGELOG entry. Say the install verifies every target is ignored and refuses when a tracked `.gitignore` would expose one;
   - add the per-dir `.gitignore` to the lists of what is written;
   - **keep `WORKSPACE_VERSION` 49.** v49 is committed locally and not pushed, so amend its entry in place.
6. Run `python3 installer/build.py`, then `--check`.

## Validation

- `bash tests/retrofit_smoke.sh`, as the only command in its own foreground Bash call. It must pass in full.
- `python3 scripts/workflow.py validate` passes.
- `python3 installer/build.py --check` passes.
- Re-run the review's three scratch reproductions (host H, allowlist host D, `!CLAUDE*.md` host E) in the session scratchpad:
  - H installs clean;
  - D and E refuse with nothing written;
  - a normal host still installs clean;
  - `--update --nested` on a clean install, after a team commit adds a negation, refuses with nothing written.
- Spot-check that at-root installs are byte-identical to the committed artifact's.

## Hand-off

- **`phase.md`:**
  - consume the F1 note;
  - add a `## Decisions` line for the per-dir `.gitignore`, the preflight method and the refusal rule;
  - add a `## Doc impact` line (architecture/operations: the ignore preflight and refusal; qa: Test 15 asserts);
  - rewrite `## Now` so it says the re-review is next.
- **`result.md`:** verdict block first.
