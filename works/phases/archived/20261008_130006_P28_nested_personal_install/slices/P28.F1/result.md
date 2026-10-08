# Result — P28.F1 Nested install verifies every host target is actually ignored (fix / high)

- **status:** done
- **tier:** high
- **summary:** The nested install now makes sure every host-side target is ignored. Each skill dir we own gets a `.gitignore` of `*`, so a `!.claude/skills/**` host installs clean. Before any write, on install and `--update --nested` alike, the installer asks `git check-ignore` about every other target. It refuses with nothing written when a host `.gitignore` re-includes one, naming `target: re-included by file:line:pattern`. After writing, it asserts that the host's `git status` lists none of the targets, and only then prints "stays clean". Smoke Test 15 gains the three asserts, and the claims in both READMEs, the retrofit guide and the v49 CHANGELOG entry are corrected. The version stays 49.
- **files_changed:**
  - `installer/main.py`
  - `bootstrap_agentic_workspace.sh` (rebuilt)
  - `tests/retrofit_smoke.sh`
  - `README.md`, `README.en.md`
  - `CHANGELOG.md` (the v49 entry, amended in place)
  - `docs/retrofit-guide.md`
  - `works/phases/active/P28/phase.md`
  - `works/phases/active/P28/slices/P28.F1/result.md`
- **validation:**
  - `bash tests/retrofit_smoke.sh`, alone in its own foreground call: PASS, `ALL RETROFIT SMOKE TESTS PASSED`, 226 PASS and 0 FAIL (223 before, plus the 3 new Test 15 asserts).
  - `python3 installer/build.py --check`: PASS.
  - `python3 scripts/workflow.py validate`: PASS. The only warnings are the existing P26/P27 consolidation debt, stale docs and oversized sections.
  - Scratch reproductions with the final artifact, all as the plan asks:
    - host H installs clean;
    - hosts D and E refuse with nothing written;
    - a normal host installs clean;
    - `--update --nested` after a team negation commit refuses with nothing written (dry run too).
  - At-root differential, committed artifact against the rebuilt one: identical output and trees.
  - Extra checks: upgrading a pre-F1 install, idempotency, and a forced post-write failure. All below.
- **deviations:**
  - I also corrected `docs/retrofit-guide.md`. It is the one place that literally said "so the host's `git status` stays clean"; the READMEs only implied it with "all hidden by `.git/info/exclude`" and "no footprint". Same claim, same fix.
  - The plan asked to add the per-dir `.gitignore` to the `installed` bookkeeping. I did **not** add it to the marker: the engine's schema for `installed` is strict (exactly `skills` and `agents`, bare names), and each per-dir file is fully implied by its skill's name in `installed.skills`. The files are in `host_writes`, so the install and `--update --nested` write them and count them in the summary (`added`/`updated`/`unchanged`), and the skill dirs' exclude lines cover them. No engine change was needed.
  - I left out the review's optional text-only candidates (the README `--base` tip and the `git clean -fdx` caveat), because the plan did not take them.
- **doc_impact:** two lines appended to `phase.md` `## Doc impact`:
  - architecture/operations: the ignore preflight, the self-hiding skill dirs and the refusal;
  - qa: Test 15's three asserts.

## What changed in `installer/main.py` (nested path only)

1. **Self-hiding skill dirs** (`NESTED_SKILL_GITIGNORE = "*\n"`).
   - Every installed skill dir (shipped, plus stale ones still on disk) gets `.claude/skills/<n>/.gitignore` containing `*`, provided the path is absent or a real directory.
   - These files go into `host_writes`, sorted so each `.gitignore` is written before its `SKILL.md`. They are not in `files`, so neither the rewrite nor its post-check touches them.
   - `--update --nested` writes and counts them. Upgrading a pre-F1 install reports `added 18`.
2. **Ignore preflight** (`_nested_unignored`, called from `nested_plan()` right after the tracked-target refusal, before any write).
   - **Method:** `git -C HOST -c core.excludesFile=<temp file holding our exclude entries> check-ignore -v -z --no-index --non-matching --stdin`.
   - **What is asked:** every agent file, `CLAUDE.local.md`, `.claude/settings.local.json`, `workflow` (as a directory), and any installed skill entry that is not a real directory.
   - **Skill contents are modelled, not asked.** Our per-dir `.gitignore` is the deepest pattern list for every path inside the dir, so those files are ignored by construction. The file is not written first.
   - **Refusal rule:** a target whose deciding pattern is a negation, or which no pattern matches, refuses with exit 1 and nothing written. The message lists `  - <target>: re-included by <file>:<line>:<pattern>` and a one-line Why: a `.gitignore` re-includes it, and `info/exclude` ranks below every `.gitignore`. There is no override flag.
   - A `check-ignore` exit other than 0 or 1 also refuses ("cannot check …"). The temp exclude file lives in the system temp dir and is deleted.
3. **Post-write check** (`nested_verify_clean`, after every write and the engine's rebuild/validate, skipped on `--dry-run`).
   - It runs `GIT_OPTIONAL_LOCKS=0 git -C HOST --literal-pathspecs status --porcelain --untracked-files=all -- <every skill dir, agent file, CLAUDE.local.md, settings.local.json, workflow>`.
   - The result must be empty. Otherwise it exits 1, listing the `??` lines and a next step: stage nothing, find the rule with `git check-ignore -v --no-index <path>`, move the listed paths out of the repo, and report it.
   - `GIT_OPTIONAL_LOCKS` is an environment variable rather than `--no-optional-locks`, so a git older than 2.15 ignores it instead of failing the check after the files are written.
4. **Banner.**
   - **Install:** "hidden by .git/info/exclude, verified: the host's git status stays clean (…)" prints only when `verified_clean` is true. The Claude Code line also says "each dir hides itself with a .gitignore of *".
   - **`--update --nested`:** prints "verified: the host's git status lists none of the workspace's files".
   - **Dry run:** prints "checked: git will ignore every host-side file once written".

## Why this method (the probes)

The probes are `probe1.sh` and `probe2.sh` in the session scratchpad, run with git 2.45.2. They settled four questions.

- **Paths that do not exist yet.** `check-ignore --no-index` answers by pattern alone. A not-yet-existing *file* gets the right answer: dir-only patterns skip it, and its parent directories are matched as directories through git's parent-dir walk.
- **The directory `workflow/` cannot be asked about while it does not exist.** Both obvious forms give wrong answers:
  - `workflow` without a slash does not match our `/workflow/`, because a non-existent path is never treated as a directory;
  - `workflow/` with a trailing slash is evaluated as an empty basename inside `workflow/`. On the allowlist host it reported `.gitignore:1:*`, i.e. "ignored", although the real directory is re-included by `!*/` and shows as `?? workflow/`. That would be a **false pass**.

  With the directory present (empty), `workflow` is answered correctly in every case: our block on a plain host, `.gitignore:2:!*/` on an allowlist host, and `.gitignore:1:!workflow/`. So the preflight creates `workflow/` empty when it is absent, runs the check, and removes it again in a `finally`. That is the "create the directory first" route the plan allowed, and nothing else is written. On `--update`, and on a fresh install over an empty or `.git`-only `workflow/`, it already exists.
- **Why `core.excludesFile` asks the right question.** That slot ranks below every `.gitignore` and below the current `info/exclude`, and our block matches every target. So the answer is "ignored" unless a `.gitignore`, or an operator line already in `info/exclude`, decides otherwise, and those are exactly what can override our block once it sits in `info/exclude`. The block has no negations.
  - **No false pass.** A positive decision now stays positive in the final file. On `--update`, the old block in the current `info/exclude` gives the same answers as the new one.
  - **One approximation, and it errs safe.** An operator's own `info/exclude` negation of one of our targets refuses, even where our block would come after it and win. It is named in the refusal, so the operator can fix it.
  - **The global excludes file.** Overriding `core.excludesFile` drops the user's global excludes from the check. That cannot matter: they rank below `info/exclude`, where our block always matches.
- **The per-dir `.gitignore` works.** With `.claude/skills/explain/.gitignore` = `*`, `git status --porcelain --untracked-files=all` and `git add -A --dry-run` show nothing for the skill on host H (`!.claude/skills/**`) and on the allowlist host. `check-ignore` names `.claude/skills/explain/.gitignore:1:*` for both `SKILL.md` and the `.gitignore` itself.

## Validation detail

**Smoke.** The log is `smoke.log` in the session scratchpad. The three new lines:
- `PASS: a host .gitignore re-including .claude/skills/** still installs clean: each skill dir hides itself with a .gitignore of *`
- `PASS: a host whose .gitignore re-includes CLAUDE*.md is refused, naming CLAUDE.local.md and the deciding line, with nothing written`
- `PASS: an allowlist host (* / !*/ / !*.md) is refused, naming workflow/ and the deciding line, with nothing written`

"Nothing written" in the tests means four things: the path list is unchanged, `info/exclude` is byte-identical, there is no `workflow/`, and the exit is non-zero.

**Review reproductions** (`repro.sh`, final artifact). "Status" below means `git status --porcelain --untracked-files=all`.

| Host | `.gitignore` | Result |
|---|---|---|
| H | `.claude/*`, `!.claude/skills/`, `!.claude/skills/**` | rc 0, status empty, banner "verified … stays clean" |
| D | `*`, `!*/`, `!*.md` | rc 1, nothing written (tree, `info/exclude` and status signature unchanged, no `workflow/`). Names the 3 agents and `CLAUDE.local.md` (`.gitignore:3:!*.md`) and `workflow/` (`.gitignore:2:!*/`); `settings.local.json` stays ignored by `*`, and the skills are self-hiding |
| E | `!CLAUDE*.md` | rc 1, nothing written, `CLAUDE.local.md: re-included by .gitignore:1:!CLAUDE*.md` |
| N | `node_modules/` | rc 0, status empty |
| C | `.claude/*`, `!.claude/skills/`, `!.claude/agents/` (the common shape) | rc 0, status empty |
| U | clean install and a first `workflow/` commit, then a team commit adds `!CLAUDE*.md` | `--update --nested --dry-run` and `--update --nested` both refuse (rc 1). Host signature and `workflow/` content hashes are unchanged |
| U2 | clean install, then a team commit changes `.claude/*` + `!.claude/skills/` into `!.claude/skills/**` | `--update --nested` rc 0, unchanged 42, "verified", status empty |

**Upgrade from a pre-F1 v49 install** (`upgrade.sh`): the committed artifact installed into host H leaks 18 untracked skill files and still prints "stays clean". That is the bug.
- The new `--update --nested --dry-run` shows `added 18, unchanged 24` and "checked: …", and writes nothing (still 18 untracked).
- The new `--update --nested` adds the 18 per-dir `.gitignore` files: untracked 0, "verified".
- A second update gives `unchanged 42`, and re-running `--nested` gives "already installed" (rc 0).

**Belt and braces exercised** (`postcheck.sh`): I ran a scratch copy of the artifact with the preflight line replaced by `unignored = []` against host E. The post-write check exits 1, listing `?? CLAUDE.local.md` with the next step, and "stays clean" is not printed.

**At-root invariant** (`atroot.sh`): `git show HEAD:bootstrap_agentic_workspace.sh` against the rebuilt artifact. Fresh, `--into-existing`, `--update --dry-run`, `--update` and `--help` give identical output after normalising the target path and timestamps. The fresh and retrofit trees are byte-identical, file by file, after normalising timestamps.

## Notebook

`phase.md` changes:
- `## Decisions` gains "Ignore guarantee (P28.F1)".
- `## Doc impact`: two lines appended.
- `## Operator Questions`: one appended, on hosts that now refuse.
- `## Notes for later slices`: the F1 note is consumed.
- `## Now` is rewritten: the re-review is next.
