# P14.S4 result — Codex visual cowork shipped as workspace v30

Workspace v30 now delivers the completed Codex visual-design cowork workflow through fresh install,
non-destructive retrofit, and in-place update. The release preserves the 17+17 skill inventory,
Codex implicit-invocation metadata only for `design-cowork`, Claude Code's unchanged Claude
Design/DesignSync workflow, adopter-owned files, phase/docs state, and seed-once `executors.toml`.

## Release and lifecycle work

- Extended `tests/retrofit_smoke.sh` at its existing source, retrofit, fresh, update, and dual-apply
  checkpoints. It now asserts the ImageGen-or-exact-reference record, one normal signoff and
  exceptional halts, inline first-run/literal resume, no executor dispatch, `DECOMP2`, untrusted-data
  and real-browser fidelity contracts; both executor rejection guards; both shared harness branches;
  exact fresh/retrofit payloads; and update replacement of deliberately stale pre-v30 Codex visual
  skill/metadata without false stale-package reporting.
- Updated the smoke's ready-plan wording to match P14.S3's `continue directly` contract and changed the
  release marker expectation from v29 to v30. Existing non-destructive, collision, empty-start,
  executor-config, policy-file, update, dual-apply, installer-drift, and retired-option checks remain.
- Added concise operator guidance to the English and Korean READMEs: `design-cowork` fires
  automatically; Codex uses ImageGen or an exact approved reference, persists the record, requests
  one visual signoff, implements separately, and checks a real browser; capability/reference/revision
  stops are exceptions; Claude Code retains Claude Design + DesignSync. Operators do not approve
  generation or every intermediate plan.
- Updated the retrofit guide to explain harness-specific visual delivery and metadata while preserving
  operator-owned files, phase/docs state, and `executors.toml`. Updated the installer maintainer guide
  to document the intentionally divergent design-cowork bodies and the preserved Claude blob guard.
- Bumped `WORKSPACE_VERSION` to 30 and added the newest-first `v30 — 2026-08-13` changelog entry with
  the native Codex path, one-gate semantics, inline resume, Claude preservation, lifecycle delivery,
  browser-fidelity handoff, and complete migration notes.
- Added one concise fresh-install completion line advertising the automatic harness-native visual
  workflows, then rebuilt `bootstrap_agentic_workspace.sh` from live source.

## Files changed

- `CHANGELOG.md`
- `README.en.md`
- `README.md`
- `docs/retrofit-guide.md`
- `installer/README.md`
- `installer/main.py`
- `tests/retrofit_smoke.sh`
- `bootstrap_agentic_workspace.sh` (generated)
- `works/phases/active/P14/phase.md`
- `works/phases/active/P14/slices/P14.S4/result.md`

Pre-existing orchestrator-owned workflow state/dashboard changes were not edited or reverted. No
source design contract, runner, executor, shared contract, generated/current durable doc, historical
doc version, product visual, plugin, browser, or external service was changed or invoked in this slice.

## Validation

- `python3 -m py_compile installer/build.py installer/main.py` — passed.
- `bash -n tests/retrofit_smoke.sh` — passed.
- `python3 scripts/workflow.py sync-agents --check` — passed; all four agent files match the tracked
  flex configuration.
- `python3 installer/build.py --check` — passed; the committed distributable matches live source.
- `bash tests/retrofit_smoke.sh` — passed all tests. The run covered source inventory and policy,
  representative non-destructive retrofit, idempotence, atomic collision refusal, foreign-docs
  preservation, v30 fresh install, economy/flex and override behavior, stale visual package update,
  seed-once/adopter-owned update behavior, full live-to-embedded parity, drift guard, and retired flag.
- `python3 scripts/workflow.py validate` — passed.
- `git hash-object .claude/skills/design-cowork/SKILL.md` — preserved
  `0e3a1766ebb85126ab97356f4fdbc5f82753067e`.
- `git diff --check` — passed.
- Focused v30 release assertions — passed. Exact command:

```sh
python3 - <<'PY'
from pathlib import Path
import ast
import hashlib
import re

root = Path('.')
main = (root / 'installer/main.py').read_text()
changelog = (root / 'CHANGELOG.md').read_text()
artifact = (root / 'bootstrap_agentic_workspace.sh').read_text()

assert re.search(r'^WORKSPACE_VERSION = 30$', main, re.M)
headings = re.findall(r'^## v\d+ — .*$', changelog, re.M)
assert headings[0] == '## v30 — 2026-08-13', headings[0]
assert sum(h.startswith('## v30 ') for h in headings) == 1
assert re.search(r'^WORKSPACE_VERSION = 30$', artifact, re.M)

match = re.search(r'(?ms)^PAYLOADS = (\{.*?\})\n\nCONTRACT_BODY = (.*)\n\nDOC_BODIES = ', artifact)
assert match
payloads = ast.literal_eval(match.group(1))
contract_body = ast.literal_eval(match.group(2))
for rel in (
    '.agents/skills/design-cowork/SKILL.md',
    '.agents/skills/design-cowork/agents/openai.yaml',
    '.agents/skills/do-next-slice/SKILL.md',
    '.agents/skills/do-whole-phase/SKILL.md',
    '.codex/agents/slice-executor-mid.toml',
    '.codex/agents/slice-executor-high.toml',
):
    assert payloads[rel] == (root / rel).read_text(), rel
agents_body = (root / 'AGENTS.md').read_text().split('\n\n', 2)[2]
claude_body = (root / 'CLAUDE.md').read_text().split('\n\n', 2)[2]
assert agents_body == claude_body == contract_body

claude_design = (root / '.claude/skills/design-cowork/SKILL.md').read_bytes()
blob = hashlib.sha1(f'blob {len(claude_design)}\0'.encode() + claude_design).hexdigest()
assert blob == '0e3a1766ebb85126ab97356f4fdbc5f82753067e', blob

readme_en = (root / 'README.en.md').read_text()
readme_ko = (root / 'README.md').read_text()
retrofit = (root / 'docs/retrofit-guide.md').read_text()
maintainer = (root / 'installer/README.md').read_text()
for token in ('design-cowork', 'built-in ImageGen', 'exact approved reference', 'one visual signoff', 'real browser', 'Claude Design + DesignSync', 'do not approve generation'):
    assert token in readme_en, token
for token in ('design-cowork', '내장 ImageGen', '정확한 레퍼런스', '승인을 한 번만', '실제 브라우저', 'Claude Design + DesignSync'):
    assert token in readme_ko, token
for token in ('harness-specific visual workflow', 'Claude Design + DesignSync', 'built-in', 'one exact approved reference', 'normally pauses once', 'pre-existing operator-owned files'):
    assert token in retrofit, token
for token in ('intentionally harness-specific', 'Claude Design', 'DesignSync', 'ImageGen-or-exact-reference', 'one-signoff', '0e3a1766ebb85126ab97356f4fdbc5f82753067e'):
    assert token in maintainer, token
for body in (readme_en, readme_ko, retrofit, maintainer):
    assert not re.search(r'(mandatory|required) Figma|Figma (?:is )?(?:mandatory|required)|Figma가 필수', body, re.I)
assert 'design-cowork fires automatically' in main
print('focused v30 release assertions passed')
PY
```

## Phase notes and doc impact

Appended the P14.S4 release finding to `phase.md`. No new Doc impact line was added: the existing
combined `decisions` / `operations` entry already covers the selected workflow, orchestration,
signoff, delivery, and real-browser fidelity truth. No doc version was created.

## Deviations

None.
