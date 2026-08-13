# Result — P15.S6: Ship the removal as workspace v31 with a CHANGELOG entry

**Status: done.** Two source edits — `installer/main.py` (`WORKSPACE_VERSION` 30 → 31) and a new
`## v31 — 2026-08-14` section appended to `CHANGELOG.md` — plus the rebuilt artifact. `git diff
--stat` is exactly those three files: `CHANGELOG.md +50`, `installer/main.py ±1`,
`bootstrap_agentic_workspace.sh ±1`. No commit, no state transition, no `doc-new-version`.

## What changed

### `installer/main.py:38`

`WORKSPACE_VERSION = 30` → `31`. The entire code change, as planned.

### `CHANGELOG.md` — the `## v31` section

Appended directly below the preamble and above `## v30 — 2026-08-13`, in house style: six bullets
each opening with a bolded claim sentence, closing with **Migration notes:**. Content drawn from all
five slice results, not just this one:

| Bullet | Sourced from |
| --- | --- |
| Codex support removed; Claude Code only | `S2` (34 + 3 files, the payload and the byte-equality assertion), `S3` (the header line and the three write paths) |
| The engine is single-harness | `S1` (presets, `[claude.<tier>]`-only, the v31 rejection message, the new `sync-agents` line format) |
| Retrofit is less invasive | `S2` finding 2 (byte-identical `AGENTS.md` on retrofit and update), `S4` (the sha pin that enforces it) |
| `--update` flags instead of deleting | `S2` (the final `OBSOLETE_MACHINERY` list, `.exists()`, the collapsed duplicates), `S4` (the exactly-once regression) |
| The contract keeps every non-Codex rule | `S3` findings 2-4 (the design rule collapsed to one branch; the `pending` design exception generalized, guardrails verbatim) |
| Docs and tests corrected against source | `S5` items 1-2 and 4 (the guide's contract-merge promise, the manual-fallback copy list, `installer/README.md`'s build-check list), `S4` (the absence regressions) |

Three judgment calls in the writing:

1. **The design-rule generalization is stated, though the plan's bullet list did not name it.**
   `S3` finding 2 widened a rule's applicability rather than narrowing it, and it ships in this
   release's `CLAUDE.md`. An adopter reading the CHANGELOG to decide whether to update is entitled
   to know a `pending` gate changed shape. It is described exactly as it stands, guardrails quoted.
   **If `P15.REVIEW` overrules `S3` here, this bullet moves with the contract edit** — that is the
   only coupling this slice created.
2. **The Migration notes point at `docs/retrofit-guide.md` § *Updating after adoption* rather than
   repeating it** (`S5` finding 2). The CHANGELOG states what the release changes and the minimum
   steps; the guide walks the procedure. The only overlap is the four flagged paths and the
   `[codex.*]` deletion, which the notes have to name to be usable on their own.
3. **A closing sentence the plan did not ask for: "If you drive this workspace from Codex, do not
   update — v30 is the last release with a Codex path."** The Migration notes tell an adopter how to
   update; they owed the one adopter for whom the answer is "don't" an equally plain sentence. It
   costs one line and is the single most decision-relevant fact in the entry.

Two concrete numbers were verified rather than asserted: the four `.agents`/`.codex` entries and the
artifact size. `git show c307eb9:bootstrap_agentic_workspace.sh | wc -c` = 474619 vs. the current
324207 — quoted as "~475 KB to ~324 KB". (Note `build.py` prints 322756: that is a **character**
count, not bytes; the file holds multi-byte em-dashes. The two numbers are not in conflict and
`--check` passes.)

No existing section was touched — v29 and v30 remain Codex-heavy written history.

### `bootstrap_agentic_workspace.sh`

Rebuilt (`installer/main.py` is embedded). The diff against `HEAD` is one line: the version constant.
Left unstaged for the orchestrator to commit alongside the two source files.

## Validation

Every command was run; nothing is inferred.

| # | Command | Outcome |
| --- | --- | --- |
| 1 | `python3 installer/build.py` | **pass** — `wrote bootstrap_agentic_workspace.sh (322756 bytes) from installer/ source` |
| 2 | `python3 installer/build.py --check` | **pass** — `OK: … in sync with installer/ source` |
| 3 | `python3 scripts/workflow.py validate` | **pass** — `Workflow validation passed.` |
| 4 | **Fresh install of the built artifact** into `<scratch>/s6fresh` | **pass**, exit 0, no import-time error |
| 5 | `cat <scratch>/s6fresh/works/.workspace-version.json` | **pass** — `"workspace_version": 31` |
| 6 | Installed root inventory | **pass** — `.claude .gitattributes .github CLAUDE.md docs executors.toml scripts works`; no `AGENTS.md`, no `.agents`, no `.codex` |
| 7 | `bash tests/retrofit_smoke.sh` | **pass** — **115 PASS / 0 FAIL**, exit 0, no edit needed |
| 8 | The release assertion inside test 7 | **pass** — `release version agrees across installer, top changelog heading, and fresh marker` |
| 9 | CHANGELOG heading structure | **pass** — 31 `## v<N>` headings, all unique, strictly descending; exactly one `## v31`, dated `2026-08-14`, at L12 with `## v30` at L62 |
| 10 | `git diff --stat` | **pass** — only the three intended files |

### 4-6 — running the artifact, not just building it

`phase.md`'s standing open hazard is that `installer/build.py` only `compile()`s the assembled body,
so a version constant that never reaches `write_version_marker()` would still build, `--check`, and
pass the pre-commit hook. The marker read at #5 is the only thing that actually proves v31 ships.
It reports 31.

### 7-8 — the three-way version agreement

`S4` dropped the literal `== 30`, so the release block now asserts only
`main_version == top_changelog == marker_version`. That equality is stronger than it looks here:
`marker_version` is read from a **fresh install of the committed artifact**, so a bumped constant
with a stale artifact fails it. It passes, which independently re-confirms #1-#5. The smoke test
needed no edit, exactly as `S4` predicted.

## Consistency check — the three v31 prose pins

All three already said 31 and none needed editing; each was re-read against the bumped constant:

| Pin | Location | Agrees |
| --- | --- | --- |
| `S1`'s engine rejection message | `scripts/workflow.py:154` | yes |
| `update-workspace` step 8 migration paragraph | `.claude/skills/update-workspace/SKILL.md:61` | yes |
| The guide's migration paragraph | `docs/retrofit-guide.md:241,248` | yes |

Plus the four `# Codex support dropped in v31` comments on the `OBSOLETE_MACHINERY` entries
(`installer/main.py:579-582`) and `explain/SKILL.md:14`'s re-vendor note — six more, all 31. A
repo-wide grep for `workspace v3[01]` / `WORKSPACE_VERSION` / `pre-v31` found no other pin and no
stale `30` anywhere outside `CHANGELOG.md`'s own history and `docs/current/**` (generated, not this
slice's to touch).

## Deviations from `plan.md`

**None in scope.** Two additions inside the CHANGELOG's own wording, both argued above: the
design-rule bullet (judgment call 1) and the closing "don't update from Codex" sentence (judgment
call 3). Neither rewrites an existing section nor touches a file outside the plan's scope.
`tests/`, `docs/versions/**`, `docs/current/**`, `README*`, and every other `installer/` file are
untouched.

## Doc impact

**None new.** This slice ships the release; it introduces no durable truth beyond what the phase's
existing "Doc impact" lines already carry. The version number itself is release metadata, and
`docs/current/operations.md` already documents `WORKSPACE_VERSION` as a mechanism rather than
pinning its value. No `doc-new-version` was run — `P15.REVIEW` consolidates.

## Notes recorded in `phase.md`

A new *From `P15.S6`* section: the release version and date, the confirmed three-way version
agreement, the three prose pins re-verified, the `build.py`-characters-vs-bytes gotcha, and the one
coupling this slice created for `P15.REVIEW` (the design-rule bullet in the CHANGELOG moves with
`CLAUDE.md` if the review overrules `S3` finding 2).
