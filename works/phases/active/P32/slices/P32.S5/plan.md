# Plan — P32.S5: Installer and release — v53, the derived `executors.toml` seed, the nested `Explore` check, the full smoke run and its new baseline

Kind `implementation`, risk `low` (mid tier). Read `phase.md` first: D3 (the seed derivation), D8 (Explore managed everywhere), D12, D13, and every `## Notes for later slices` entry tagged for S5 (H4; the installer anchors; the smoke `DUAL_FIXED` note; the nested-rename note; the version note; the S2 baseline note; S4's note). `intent.md` is the why.

## Goal

The installer ships v53: the artifact embeds an adopter seed of `executors.toml` with the cheap-route block commented out (derived from the live file, which keeps it on), `Explore.md` is named wherever the installer names its agents, the nested-install rename of the unhyphenated `Explore` is checked, and the whole smoke suite passes with its new baseline recorded.

## Preconditions (check first; stop on a miss)

- `grep -n '^WORKSPACE_VERSION' installer/main.py` prints `52` and `grep -m1 '^## v' CHANGELOG.md` prints `## v52 — …`. If either is already 53 or higher (P33 merged in the meantime), **stop and return `needs_operator`**: the version order is the open operator question in `phase.md`; never lower a version.
- `git status --short` shows only your own changes once you start.

## Files

- `installer/main.py` — `WORKSPACE_VERSION = 53`; the at-root post-install agent listing (~1512: add `Explore.md` beside design-drafter); nothing else unless a check below demands it.
- `installer/build.py` — `derive_executors_seed(text: str) -> str` and its use in `collect_live_payloads` for `executors.toml` only; the module docstring's "embedded verbatim" sentence gains the one exception.
- `CHANGELOG.md` — a **minimal** `## v53 — 2026-10-12` section (S6 expands it): three or four bullets naming the route table, `executor-route`, the cheap route (on here, commented for adopters), `record-dispatch` / `dispatch-summary`, `Explore.md` and the Agent tool in the executors, and a **Migration notes** bullet (delete `mode = "…"` from `executors.toml` — the engine refuses it and says how to keep flex; re-run `sync-agents` after `--update`; uncomment the cheap-route block to opt in on the Anthropic API; the stale `.claude/skills/executor-mode/` is flagged for removal; a host `.claude/agents/Explore.md` clash renames ours). The smoke suite requires `WORKSPACE_VERSION == top CHANGELOG heading == fresh marker` and a Migration notes line per release, so this section must land in this slice.
- `tests/retrofit_smoke.sh` — `DUAL_FIXED`'s `executors.toml` comparison, the fresh-install seed assertions, the nested `Explore` rename probe; the baseline count.
- `.claude/skills/update-workspace/SKILL.md` — step 8 only: `sync-agents` re-applies "the preserved per-row overrides" (not "the preserved mode and per-tier overrides"); see S4's note in `phase.md`.
- `bootstrap_agentic_workspace.sh` — rebuilt.

Do **not** touch: `scripts/workflow.py`, `executors.toml` (live), the agent files, the skills, `CLAUDE.md`, READMEs, `docs/` (S6 owns `docs/retrofit-guide.md`).

## The seed derivation (D3) — implement exactly this

```python
CHEAP_BEGIN, CHEAP_END = "# cheap-route: begin", "# cheap-route: end"

def derive_executors_seed(text: str) -> str:
    """The adopter seed of executors.toml: the live file with the cheap-route block's
    non-comment lines commented out, so a fresh install inherits the mid row until the
    adopter opts in. Markers must both exist, once, in order; anything else is a build error."""
    lines = text.split("\n")
    begin = [i for i, l in enumerate(lines) if l.strip() == CHEAP_BEGIN]
    end = [i for i, l in enumerate(lines) if l.strip() == CHEAP_END]
    if len(begin) != 1 or len(end) != 1 or begin[0] >= end[0]:
        die("executors.toml: expected exactly one '# cheap-route: begin' … '# cheap-route: end' block")
    for i in range(begin[0] + 1, end[0]):
        if lines[i].strip() and not lines[i].lstrip().startswith("#"):
            lines[i] = "# " + lines[i]
    return "\n".join(lines)
```

`collect_live_payloads` applies it to `executors.toml` only (`payloads["executors.toml"] = derive_executors_seed(read("executors.toml"))`). Keep determinism (pure text transform). `--check` compares the rebuilt artifact as before.

## Smoke changes (`tests/retrofit_smoke.sh`)

1. **`DUAL_FIXED`** (~1216–1245): keep `executors.toml` in the manifest for the `FIXED_LIVE_FILES` cross-check, but compare it against the **derived seed**: before the loop, write the derived text to a temp file with `python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from build import derive_executors_seed; print(derive_executors_seed(open(sys.argv[2]).read()), end="")' "$REPO_ROOT/installer" "$REPO_ROOT/executors.toml" > "$TMP/executors.seed.toml"` and `diff -q` the fresh install's file against that for `executors.toml` (the other files unchanged). Guard the import against a stale `installer/__pycache__` (it is fine; `build.py` has no side effects at import — verify, and if `assemble()` runs at import, factor the entry point under `if __name__ == "__main__":`).
2. **Fresh install seed** (Test 5, near ~806–822): the installed `executors.toml` contains `# [claude.cheap]` and `# model = "haiku"` (commented) and no uncommented `[claude.cheap]`; `sync-agents --check` passes; `executor-route` bare on the fresh install shows the `cheap` row `sonnet  high  mid row`; `grep -c 'cheap-route: begin'` = 1 (the markers survive, so an adopter can uncomment).
3. **Live-vs-seed invariant:** uncommenting the seed's block (`sed 's/^# \(\[claude.cheap\]\|model = "haiku"\|effort = "high"\)$/\1/'`) reproduces the live file byte-for-byte (`cmp -s`). This replaces the old round-trip check and pins D3's single-source promise.
4. **Nested `Explore` clash** (Test 15 area, ~1672+): in a throwaway host that already has `.claude/agents/Explore.md`, run the nested install; assert the marker's `renames.agents` maps `Explore` → `wf-Explore`, `.claude/agents/wf-Explore.md` exists with `name: wf-Explore`, the host's own `Explore.md` is byte-identical to before, and the installed executor bodies say `subagent_type: wf-Explore` (grep). Record in `result.md` how many prose occurrences of the word `Explore` were rewritten in the installed executor body (count `wf-Explore`) — do not change `nested_rewrite`; the caveat goes to the CHANGELOG (S6 expands) as D8 says. If the rename breaks the install (a traceback, a missing file), that is an `escalate`, not a workaround.
5. **Stale skill flagging:** in the `--update` test (~1080–1095), seed `.claude/skills/executor-mode/SKILL.md` into the pre-update fixture and assert the update output's stale line names `.claude/skills/executor-mode` (the existing `flag_stale_skills` path, no new code).
6. **Baseline:** after everything passes, count the `PASS` lines the suite prints and record the number in `result.md` and the S6 note; the qa doc's line is a `## Doc impact` entry.

## Validation (run all; record each in the verdict block)

1. `python3 -m py_compile installer/build.py installer/main.py`.
2. `python3 installer/build.py` then `python3 installer/build.py --check` → OK.
3. `python3 scripts/workflow.py validate` → exit 0 (known warnings).
4. `python3 scripts/workflow.py sync-agents --check` → in sync (you changed no agent file).
5. `bash tests/retrofit_smoke.sh` — once, in the foreground, as the only command in its Bash call. It must end `ALL RETROFIT SMOKE TESTS PASSED`; report the count. A failure outside this slice's files that you cannot explain is an `escalate`.
6. `grep -n 'economy\|flex\|executor-mode' installer/main.py installer/build.py CHANGELOG.md | grep -v '^CHANGELOG.md:[0-9]*:.*## v5[0-2]\|v4\|v3\|v2'` → only the v53 Migration notes mention and older release sections.

## `result.md` and `phase.md`

- `result.md`: verdict block first — `status`, `tier: mid`, `model` and `effort` **copied from the `## Dispatch` section at the end of this plan**, `summary`, `files_changed`, `validation`, `deviations`, `doc_impact` — then the derived seed's cheap block as installed, the nested rename counts, and the smoke count.
- `phase.md`: remove the S5 notes you consumed; add a note **for S6** with the exact v53 CHANGELOG skeleton you wrote (so S6 expands rather than duplicates), the smoke baseline, the nested-rename caveat wording to carry into the CHANGELOG and READMEs, and the retrofit-guide lines S6 owns. Append `## Doc impact`: `qa.md: smoke baseline <N> PASS / 0 FAIL as of v53 (route table, instrument, agent and seed pins; the derived executors.toml seed) (P32.S5)` and `operations.md: Installer — the executors.toml seed is derived from the live file with the cheap-route block commented out; Explore.md is a managed agent file; v53 migration notes (P32.S5)`. Rewrite `## Now` (≤ 15 lines) for S6.

## Dispatch

```
slice=P32.S5
phase=P32
kind=implementation
risk=low
attempt=1
route=mid
reason=kind implementation rated low
tier=mid
subagent_type=slice-executor-mid
model=sonnet
pass_model=yes
effort=high
pass_effort=yes
attribution=Claude Sonnet 5.5
explore_model=haiku
explore_effort=high
```
