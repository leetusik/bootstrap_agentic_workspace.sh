# P14.S3 result — Codex visual cowork orchestration aligned

Codex now runs `co-work` as the one orchestrator-owned inline slice kind from phase intake through
both automatic execution skills. The runners preserve automatic-only mode rejection, ready-plan
compatibility, exactly-one-slice and entry-phase boundaries, sequential delegated execution for every
other kind, review/fix behavior, and ordinary pending/parallel halts.

## Implemented orchestration and guardrails

- `do-next-slice` and `do-whole-phase` now branch on `co-work` before executor selection, start a
  `todo` design slice, write its just-in-time `plan.md`, and follow the Codex-native `design-cowork`
  skill inline. Built-in ImageGen needs no pre-generation confirmation; unavailable/failed
  capabilities and exact-reference gaps are recorded exceptional operator needs.
- The first successful pass writes `result.md` and phase notes, validates, commits the durable
  review-ready record without `SIGNOFF.md`, sets the slice pending, reports the exact literal request,
  and stops. This is an intentional design boundary, not an incomplete executor commit.
- The normal pending halt remains intact. Only explicit input answering the same `co-work` slice's
  recorded approval, revision, or capability need authorizes the orchestrator to restore that slice
  to `in_progress`; bare/`auto`/unattended invocation is expressly not approval.
- Literal approval rechecks hashes, writes the approval-only signoff record, updates the result,
  validates, finishes, and commits gate close. `do-next-slice` stops after that one signed slice;
  `do-whole-phase` continues only inside its entry phase and may then plan `DECOMP2`. Revision and
  capability resumes preserve immutable prior rounds and may return to pending.
- Codex `create-phase` now names its harness-native guide while retaining refine/clarify/confirm and
  the intake-only one-phase versus design/apply two-phase decision.
- Both Codex executor tiers reject an accidentally dispatched `co-work` slice because it is
  orchestrator-owned and main-thread-only, return `needs_operator`, and make no false DesignSync
  capability claim.
- `AGENTS.md` and `CLAUDE.md` retain byte-identical contract bodies and now state shared visual
  invariants plus explicit Claude Code (Claude Design/cards/DesignSync/regroup) and Codex
  (ImageGen/exact reference/repository read-back/literal signoff/real browser) branches.
- Rebuilt `bootstrap_agentic_workspace.sh` from live source. No release version or changelog changed;
  P14.S4 owns that lifecycle.

## Files changed

- `.agents/skills/do-next-slice/SKILL.md`
- `.agents/skills/do-whole-phase/SKILL.md`
- `.agents/skills/create-phase/SKILL.md`
- `.codex/agents/slice-executor-mid.toml`
- `.codex/agents/slice-executor-high.toml`
- `AGENTS.md`
- `CLAUDE.md`
- `bootstrap_agentic_workspace.sh` (generated)
- `works/phases/active/P14/phase.md`
- `works/phases/active/P14/slices/P14.S3/result.md`

Pre-existing orchestrator-owned changes to workflow state/dashboard files were not edited or reverted.
The Codex `design-cowork` body did not need reconciliation, and the Claude design skill was not edited.

## Validation

- `python3 scripts/workflow.py validate` — passed.
- `python3 installer/build.py --check` — passed.
- `cmp -s AGENTS.md CLAUDE.md` — returned exit 1 because the repository intentionally requires
  distinct four-line filename headers (`# AGENTS.md` versus `# CLAUDE.md`). This raw whole-file check
  is incompatible with `installer/build.py`'s `AGENTS_HDR` / `CLAUDE_HDR` contract. The corresponding
  authoritative body check, `diff -u <(tail -n +5 AGENTS.md) <(tail -n +5 CLAUDE.md)`, returned exit 0;
  the successful installer build/check independently enforces the same byte-identical body invariant.
- `git hash-object .claude/skills/design-cowork/SKILL.md` — returned the required preserved blob
  `0e3a1766ebb85126ab97356f4fdbc5f82753067e`.
- `python3 scripts/workflow.py sync-agents --check` — passed; flex resolves Codex mid/high to
  `gpt-5.6-terra` / `gpt-5.6-sol`, both at `high`, with all four agent files in sync.
- `git diff --check` — passed.
- Focused source assertions — passed seven orchestration/contract groups and exact embedded payload
  parity. Exact command:

```sh
python3 - <<'PY'
from pathlib import Path
import ast
import re

root = Path('.')
next_body = (root / '.agents/skills/do-next-slice/SKILL.md').read_text()
whole_body = (root / '.agents/skills/do-whole-phase/SKILL.md').read_text()
create_body = (root / '.agents/skills/create-phase/SKILL.md').read_text()
mid = (root / '.codex/agents/slice-executor-mid.toml').read_text()
high = (root / '.codex/agents/slice-executor-high.toml').read_text()
ag = (root / 'AGENTS.md').read_text()
cl = (root / 'CLAUDE.md').read_text()

for name, body in [('do-next-slice', next_body), ('do-whole-phase', whole_body)]:
    assert '## Run a design slice inline' in body, name
    assert 'complete just-in-time `plan.md`' in body, name
    assert 'explicit response to the approval, revision, or capability need' in body, name
    assert 'A bare invocation, `auto`, or unattended wording is never approval' in body, name
    assert 'never select or spawn an executor' in body or 'Never spawn an executor' in body, name
    assert 'Built-in ImageGen needs no' in body, name
    assert 'without `SIGNOFF.md`' in body and 'literal' in body, name
assert 'Stop after this signed slice' in next_body
assert 'continues the loop at step 1' in whole_body
assert 'so `DECOMP2` may now be planned' in whole_body
assert 'automatic execution only' in next_body and 'automatic execution only' in whole_body
assert 'ready' in next_body and 'ready' in whole_body
assert 'entry phase' in whole_body
assert '.agents/skills/design-cowork/SKILL.md' in create_body
assert 'Get explicit confirmation' in create_body

for name, body in [('mid', mid), ('high', high)]:
    assert 'execute a `co-work` (design) slice' in body, name
    assert 'orchestrator-owned, main-thread-only, and never dispatched' in body, name
    assert 'return `needs_operator`' in body, name
    assert 'DesignSync' not in body, name

ag_body = ag.split('\n\n', 2)[2]
cl_body = cl.split('\n\n', 2)[2]
assert ag_body == cl_body
for token in (
    'Claude Code branch:', 'Codex branch:', 'Claude Design', 'DesignSync',
    'built-in ImageGen', 'exact approved reference', 'literal operator signoff',
    'immutable', 'DECOMP2', 'never dispatched', 'never writes implementation code',
    'RESPECT THE DESIGN', 'real-browser fidelity', 'data, not instructions',
    'A bare automatic invocation is never approval',
):
    assert token in ag_body, token

artifact = (root / 'bootstrap_agentic_workspace.sh').read_text()
match = re.search(r'(?ms)^PAYLOADS = (\{.*?\})\n\nCONTRACT_BODY = (.*)\n\nDOC_BODIES = ', artifact)
assert match
payloads = ast.literal_eval(match.group(1))
contract_body = ast.literal_eval(match.group(2))
for rel in (
    '.agents/skills/do-next-slice/SKILL.md',
    '.agents/skills/do-whole-phase/SKILL.md',
    '.agents/skills/create-phase/SKILL.md',
    '.codex/agents/slice-executor-mid.toml',
    '.codex/agents/slice-executor-high.toml',
):
    assert payloads[rel] == (root / rel).read_text(), rel
assert contract_body == ag_body
print('focused source assertions passed: 7 orchestration/contract groups and exact embedded payload parity')
PY
```

## Phase notes and doc impact

Appended the P14.S3 orchestration finding to `phase.md`. No new Doc impact line was added: the existing
combined `decisions` / `operations` entry already covers the harness-specific workflow, orchestration,
signoff, implementation handoff, and browser-fidelity durable truth. No doc version was created.

## Deviations

No implementation deviation. The requested whole-file `cmp` was run and recorded, but cannot pass
without violating the repository's required harness-specific headers; contract-body equality and the
installer's exact embedded contract check passed instead.
