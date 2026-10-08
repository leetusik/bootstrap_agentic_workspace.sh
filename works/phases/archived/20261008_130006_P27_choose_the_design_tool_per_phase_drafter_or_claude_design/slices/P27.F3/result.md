# Result: P27.F3 (fix / high)

- **status:** done
- **tier:** high
- **summary:** The installer's stdin program now opens with a PEP 263 cookie (`# -*- coding: utf-8 -*-`, line 1 of `installer/main.py`), so system Python 3.9 can no longer reject it when a multibyte character straddles a read chunk. A rebuild sweep over 1024 insert lengths gives 0 failures with the cookie and 453 (`design-cowork`) and 194 (`slice-executor-high`) without it. A new smoke pin in Test 7 guards the cookie.
- **files_changed:** `installer/main.py`, `bootstrap_agentic_workspace.sh` (rebuilt), `tests/retrofit_smoke.sh`, `works/phases/active/P27/phase.md`, `works/phases/active/P27/slices/P27.F3/result.md`
- **validation:**
  - `python3 installer/build.py`, then `python3 installer/build.py --check`: `OK: bootstrap_agentic_workspace.sh is in sync with installer/ source` (pass)
  - `bash tests/retrofit_smoke.sh`, alone in its Bash call, in the foreground: **202 PASS, 0 FAIL**, `ALL RETROFIT SMOKE TESTS PASSED` (pass; the baseline of 201 plus the one new pin)
  - `python3 scripts/workflow.py validate`: `Workflow validation passed.` (pass; the three warnings are the pre-existing P26 consolidation, stale-docs and oversized-section ones)
  - The step-3 rebuild sweep on `/usr/bin/python3` 3.9.6, k = 0…1023 (pass):
    - with the cookie: `design-cowork/SKILL.md` **0 / 1024**, `slice-executor-high.md` **0 / 1024**;
    - without it: **453 / 1024** and **194 / 1024**, every failure `SyntaxError: Non-UTF-8 code starting with '\xe2' … but no encoding declared`.
  - End to end through `sh` (heredoc to stdin), a fresh install from a rebuilt artifact at a failing shift (k = 3, `design-cowork`) (pass): with the cookie, exit 0 and `scripts/workflow.py` installed; without it, exit 1 with the `Non-UTF-8 code` error and nothing installed.
- **deviations:** none.
  - The cookie is followed by a 4-line comment in `main.py` that says why line 1 must stay. This is still inside step 1: comments may precede the `__future__` import, and the cookie is line 1.
  - The Test 7 title gained ", and its stdin program declares utf-8".
  - No `WORKSPACE_VERSION` bump and no CHANGELOG line. Targets receive byte-identical files, so under `installer/README.md`'s release rule this is not a machinery change that ships to them. The orchestrator can overrule that.
- **doc_impact:** `- operations.md: the installer's stdin program declares utf-8 (PEP 263) so system Python 3.9 cannot reject it on a chunk-boundary multibyte character (P27.F3)`, appended to `phase.md` `## Doc impact`.

## What changed

- **`installer/main.py`:** new line 1 is `# -*- coding: utf-8 -*-`. Lines 2–5 are a comment: the cookie must stay on line 1 and be spelled utf-8, and the comment says why. `from __future__ import annotations` moves to line 6. All ASCII.
- **`build.py` prepends nothing.** `assemble()` sets `body = main_py.replace(PAYLOAD_MARKER, constants)` and splices it into `wrapper.sh` right after `python3 - <<'INSTALLER_PY'`. In the rebuilt artifact that heredoc opener is L86 and L87 is the cookie. `build.py` was not edited, so D3's trigger did not fire and the plan's escalation condition did not arise.
- **The artifact diff** is exactly the 5 added lines after L86. `build.py` `compile()`s the body from a `str`, which ignores the cookie, so nothing else changed.
- **`tests/retrofit_smoke.sh`, Test 7:** after the `--check` pass, one pin:
  ```sh
  cookie_line=$(grep -A1 -Fx "python3 - <<'INSTALLER_PY'" "$BOOT" | sed -n 2p)
  [ "$cookie_line" = "# -*- coding: utf-8 -*-" ] && ok "the installer's stdin program starts with the utf-8 coding cookie" || bad "…(got: $cookie_line)"
  ```
  It is proven real both ways. On the fixed artifact it extracts `# -*- coding: utf-8 -*-`. On the pre-fix scratch artifact it extracts `from __future__ import annotations`, so the pin fails there.
- **S3's 3-byte executor rewording** ("in both cases") is left as is, as the plan says.

## Why the cookie works (CPython 3.9 `Parser/tokenizer.c`, `decoding_fgets`)

- Reading from a `FILE*` (stdin included), 3.9 checks every chunk it gets from `Py_UniversalNewlineFgets` for valid UTF-8 whenever `tok->encoding` is NULL. A long line comes in fixed-size chunks, so a 3-byte `—` split across two chunks looks invalid, and the whole program is rejected before anything runs.
- A line-1/2 cookie whose name normalizes to `utf-8` sets `tok->encoding = "utf-8"` directly (`check_coding_spec`), which skips that per-chunk check. The chunks are then joined into whole lines and decoded normally.
- It does **not** take the `fp_setreadl` codec path. That path `ftell`s the stream and would fail on a pipe. This is why the cookie must be spelled utf-8 and not, say, latin-1.
  - Probe on 3.9.6: a piped `# -*- coding: latin-1 -*-` program fails with `SyntaxError: encoding problem: iso-8859-1`.
  - The same program with the `utf-8` cookie runs.
- The sweep fed the program over a pipe (`subprocess` `input=`), and the end-to-end run used `sh`'s heredoc, so both stdin kinds are covered.

## The sweep (scratch only)

Scratch: `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/235e941d-3d75-432a-8f92-8613f9d93c55/scratchpad/p27f3/`.

- **Four repo copies**, `rsync` without `.git` and `works/`, plus `works/templates` for the build:
  - `nocookie_dc` and `nocookie_seh`, taken **before** the edit;
  - `cookie_dc` and `cookie_seh`, taken after it.

  Each copy's `build.py --check` is OK. After the sweep, both `cookie_*` artifacts are byte-identical (`cmp`) to the repo's.
- **`sweep_rebuild.py <copy> <rel> 0 1024`**, one run per copy, four in parallel. For each k it:
  1. inserts `'a' * k` into the copy's `<rel>` immediately before the file's first `—`;
  2. **runs the copy's `installer/build.py`** to do a real rebuild;
  3. cuts the program out of the heredoc exactly as `sh` hands it over;
  4. inserts `raise SystemExit(0)` after the `__future__` line (the whole program is parsed from stdin before line 1 runs, so nothing executes);
  5. runs `/usr/bin/python3 -` on it.

  It restores the file and the artifact at the end. Output:
  ```
  cookie_dc: .claude/skills/design-cowork/SKILL.md: program line 1 = '# -*- coding: utf-8 -*-'; k 0..1023: 0 of 1024 fail
  cookie_seh: .claude/agents/slice-executor-high.md: program line 1 = '# -*- coding: utf-8 -*-'; k 0..1023: 0 of 1024 fail
  nocookie_dc: .claude/skills/design-cowork/SKILL.md: program line 1 = 'from __future__ import annotations'; k 0..1023: 453 of 1024 fail
      (3, "SyntaxError: Non-UTF-8 code starting with '\\xe2' in file <stdin> on line 65, but no encoding declared; …")
  nocookie_seh: .claude/agents/slice-executor-high.md: program line 1 = 'from __future__ import annotations'; k 0..1023: 194 of 1024 fail
      (7, "SyntaxError: Non-UTF-8 code starting with '\\xe2' in file <stdin> on line 57, but no encoding declared; …")
  ```
  The no-cookie counts match the review's 453 and 194 exactly.
- **`e2e.py`**, k = 3 on `design-cowork`, a real fresh install with `sh <artifact> <new scratch dir> --name E2E --summary e2e`:
  ```
  cookie_dc k=3: exit 0; installed scripts/workflow.py: True; last line: Next: create the first phase with /create-phase …
  nocookie_dc k=3: exit 1; installed scripts/workflow.py: False; last line: SyntaxError: Non-UTF-8 code starting with '\xe2' in file <stdin> on line 64, …
  ```
- **The real embedded files were never touched.** `git diff --quiet HEAD -- .claude scripts CLAUDE.md` is clean, and `installer/build.py` is unchanged.

## Notebook edits (`phase.md`)

- **`## Decisions`:** the operator's answers of 2026-09-30.
  - The installer fix is folded in as F3, ordered first. This is a new line, which also records the fix.
  - The claude-design push line (S2) is replaced in place by the confirmed one: once per round, with its handoff commit (a superseding round's included), none over a local-dir connection.
- **`## Doc impact`:** the plan's operations.md line was appended.
- **`## Notes for later slices`:** I removed the review note's "Installer trap" sub-bullet, which this slice consumed, and added a short F3 → F1/F2 note.
- **`## Now`:** rewritten for F1.
- **`## Operator Questions`:** untouched (append-only). The answers live in `## Decisions`. The operator's answer to question 1 (the D-triggers) was not in this slice's plan, so it is not recorded here.
