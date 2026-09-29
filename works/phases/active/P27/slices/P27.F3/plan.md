# Plan: P27.F3 (fix / high: every install and `/update-workspace` runs the artifact)

## Problem

`bootstrap_agentic_workspace.sh` runs its installer as `python3 - <<'INSTALLER_PY'` (artifact ~L86). The Mac's system Python 3.9 reads a stdin program in ~1023-byte chunks. With no encoding declared, it rejects the whole program (`SyntaxError: Non-UTF-8 code … but no encoding declared`) when a multibyte character (`—`) straddles a chunk boundary inside one of `build.py`'s long `repr()`-embedded payload lines.

P27.REVIEW reproduced this on `/usr/bin/python3` 3.9.6. Measured break rates for a random-length insert:
- `design-cowork/SKILL.md`: 453/1024;
- `slice-executor-high.md`: 194/1024;
- `workflow.py`: 23/1024.

S3 dodged it only by a 3-byte rewording. See `slices/P27.REVIEW/result.md`, "Installer tokenizer trap", and the review's sweep scripts in `/private/tmp/claude-502/-Users-sugang-projects-personal-bootstrap-agentic-workspace-sh/235e941d-3d75-432a-8f92-8613f9d93c55/scratchpad/p27review/`.

**The operator chose to fix it now** (2026-09-30, answering the review's routed question: "Fix now as P27.F3").

## Fix

1. Make the first line of the stdin program a PEP 263 cookie, `# -*- coding: utf-8 -*-`. Put it as line 1 of `installer/main.py`, above `from __future__ import annotations`; comments may precede a `__future__` import.
   - Confirm in the rebuilt artifact that the line immediately after `python3 - <<'INSTALLER_PY'` is the cookie. A cookie counts only on line 1 or 2 of the program.
   - If `build.py` prepends anything to the program body, so the cookie would not land on line 1 or 2, stop and escalate: the plan then needs a `build.py` edit, and D3's trigger would fire.
2. `python3 installer/build.py`, then `--check`.
3. **Prove the fix with the review's sweep, re-run once as validation, not added as a test.**
   - For `design-cowork/SKILL.md` and `slice-executor-high.md`, insert 0–1023 bytes (containing no multibyte characters, as the review did) before a known `—`.
   - Rebuild into scratch and let `/usr/bin/python3` 3.9 **compile** the stdin program without running it. The review's harness shows how.
   - Expect 0 failures for both files.
   - Also show that the same sweep without the cookie still fails, so the test is real.
   - Never modify the real embedded files for the sweep: work on scratch copies of the repo.
4. **Add one small smoke pin, the only new test:** the artifact's installer program starts with the coding cookie. Assert that the line after `python3 - <<'INSTALLER_PY'` equals `# -*- coding: utf-8 -*-`. Put it beside the existing artifact or build checks in `tests/retrofit_smoke.sh`.
5. Leave S3's 3-byte executor rewording as is: it is harmless wording.

## Validation

- `bash tests/retrofit_smoke.sh`: run it **alone in its Bash call**, in the foreground. Expect 202 PASS, 0 FAIL.
- `python3 installer/build.py --check`.
- `python3 scripts/workflow.py validate`.
- The sweep from step 3: 0 failures with the cookie, and failures without it.

## Notebook

- In `## Decisions`, record the operator's answers of 2026-09-30:
  - the installer fix is folded in as F3, ordered first;
  - **claude-design pushes once per round**, with its handoff commit, a superseding round's included, and none over a local-dir connection. S2's choice is confirmed.
- In `## Doc impact`, add: `- operations.md: the installer's stdin program declares utf-8 (PEP 263) so system Python 3.9 cannot reject it on a chunk-boundary multibyte character (P27.F3)`.
- Rewrite `## Now` for F1.
