# Phase P7: Retire embedded /explain

_Intent: see [intent.md](intent.md)._

## Objective

Remove the explain feature from the bootstrap distribution — embedded skill copies (.claude/skills/explain, .agents/skills/explain), the --with-explain installer path, and KB API wiring — and point users at the knowledge repo's Claude Code plugin instead. Gated: starts only after the knowledge repo's P7 (Claude Code plugin) review passes; leave everything as-is until then. Rebuild the installer (python3 installer/build.py) as part of the work; likely resolves deferred D1 (hardcoded KB path/ports) by deletion.

## Context

Gate SATISFIED (orchestrator-verified in P7.DECOMP plan): knowledge repo's P7 "Claude Code plugin" is done + review pass. The plugin ships the explain skill + KB scaffolder, installable via `/plugin`. This bootstrap phase runs first (before bootstrap P8).

## Decomposition

**One implementation slice — `P7.S1` "Remove explain from the distribution"** (kind implementation, risk **medium**, order 10).

Rationale — the removal is **atomic and must land in one commit**: deleting the two skill copies, ripping out the installer's optional-skill mechanism, bumping `WORKSPACE_VERSION` 14→15, adding the CHANGELOG v15 entry with migration notes, editing README.en.md, updating the smoke test, and **rebuilding `bootstrap_agentic_workspace.sh` via `python3 installer/build.py`** all have to ship together. Any split leaves a lying intermediate state — e.g. a `--with-explain` flag that installs nothing, a smoke test asserting old behavior, or (fatal) a machinery edit whose rebuilt artifact lands in a *different* commit, which the `--check` pre-commit hook rejects. The same-commit rebuild rule is indivisible, so this is genuinely one slice.

Risk **medium** (not low, not high): the installer surgery — removing the whole `OPTIONAL_SKILLS` filter and the `--update` keep-refresh special-case cleanly, editing the smoke test's Test 8, writing migration notes — is judgment work, not literal plan-following, so `low` (→ slice-executor-low, a literal plan-follower) is off the table. But it is a well-scoped, fully-researched removal with every design decision already made (see Findings), not open-ended design, so `high` would over-provision. Medium → slice-executor-mid is the fit.

REVIEW stays at order 9999; S1 at order 10 slots cleanly between DECOMP (0) and REVIEW.

## Findings & Notes

### Verified removal footprint (matches the plan; corrections noted)

**Skill copies (delete — all 3 exist):**
- `.claude/skills/explain/SKILL.md`
- `.agents/skills/explain/SKILL.md`
- `.agents/skills/explain/agents/openai.yaml`

**`installer/wrapper.sh` (verified line-exact):** usage `--with-explain` line 16; `with_explain=0` line 52; case arm `--with-explain) with_explain=1; shift ;;` line 65; `export WITH_EXPLAIN="$with_explain"` line 90. Remove all four.

**`installer/main.py` (verified):**
- `WORKSPACE_VERSION = 14` at **line 38** → bump to **15**.
- The entire optional-skill mechanism, **lines 60–68**: `WITH_EXPLAIN = os.environ.get("WITH_EXPLAIN") == "1"` (60), the `--update` keep-refresh special-case `if UPDATE and (ROOT / ".claude/skills/explain/SKILL.md").exists(): WITH_EXPLAIN = True` (63–64), `OPTIONAL_SKILLS = {"explain": WITH_EXPLAIN}` (65), and the `_excluded` filtering of `CLAUDE_SKILLS`/`CODEX_SKILLS` (66–68). Explain is the ONLY optional skill, so the whole block goes; `CLAUDE_SKILLS`/`CODEX_SKILLS` (derived from `PAYLOADS` at lines 57–58) then flow unfiltered into `MANAGED_DIRS`/`MANAGED_FILES` (94–103) and the skill-write loop (481–486). Once explain is gone from source, `installer/build.py` no longer embeds it in `PAYLOADS`, so those lists never contain it — nothing else special-cases explain.
- **`flag_stale_skills` (lines 538–563) needs NO edit** — it is generic (a skill dir not in the expected set + a tool-specific marker → flagged stale). It already produces the desired `--update` behavior below.
- **`OBSOLETE_MACHINERY` (lines 523–529) needs NO explain entry** — that list is for individual retired *files*; stale skill *dirs* are handled by `flag_stale_skills`.

**`tests/retrofit_smoke.sh` (verified):** keep lines 173–174 ("default install omits explain") as a permanent regression — they now assert the only correct state, not an opt-in default. Replace **Test 8, lines 209–222** (`--with-explain` installs it + dual-apply diffs) with an assertion that `--with-explain` is now an **unknown option** (install fails / non-zero exit; wrapper's `-*) die "unknown option $1"` at line 67 handles it). Note: the current Test 8 block runs to line 222 (the dual-apply diff loop), not 218 — the whole block is replaced.

**`README.en.md` (verified):** flag-table row line 162; "14 core Agent Skills … optional `explain` … `--with-explain`" prose lines 171–172; skills-table row line 273; skill-interface prose lines 287–289 ("`explain` is the one exception…"). Remove explain/`--with-explain` throughout and point at the knowledge plugin (pointer below). Corrections to the plan's line hints: the prose mention is at **171–172** (not just 172); skill counts in the prose ("14 core Agent Skills", "15 Agent Skills" at line 253, "the one exception") will need recounting once explain is gone — down one skill. **Root `README.md` (Korean): NO explain-feature mention** — line 134 is only the prose word "explains" in the contract tagline; leave it.

**`CHANGELOG.md`:** add a new top `## v15 — <date>` entry with a **Migration notes** line; historical entries (v14 at line 12; the explain history at lines 253, 265, 287–294) stay untouched.

**`bootstrap_agentic_workspace.sh`:** the built artifact — regenerated by `python3 installer/build.py`, never hand-edited. It currently embeds explain at lines 16/52/65/90 (wrapper) and 162–163/189/227–232 (payloads + main.py body); the rebuild drops all of them.

**Clean baseline confirmed:** no explain refs in root `README.md` (feature), `works/templates/`, `.claude/settings.json`, `scripts/workflow.py`, or any non-explain skill. `docs/index.json` / `docs/versions/` carry explain history (operations v0010/v0011, decisions v0015/v0016) — those are durable doc history the REVIEW consolidates, not code to edit.

### `--update` behavior after retirement (decided)

Rely on the generic `flag_stale_skills`. On `--update` of a downstream that has explain installed: it is no longer in `PAYLOADS`, so it is never re-written (left as-is, never deleted). `.agents/skills/explain` carries the `agents/openai.yaml` marker → flagged **stale** ("remove manually?"). `.claude/skills/explain` carries **no** `disable-model-invocation: true` marker → treated as an operator-owned skill, left untouched and NOT flagged. This asymmetry is accepted; the CHANGELOG **Migration notes** must tell existing installs to remove both old copies manually and install the knowledge plugin instead. Nothing is ever auto-deleted.

### Knowledge-plugin install pointer (verified in `~/projects/personal/knowledge`)

From `~/projects/personal/knowledge/.claude-plugin/marketplace.json` (marketplace `knowledge`, plugin `knowledge` @ `./plugin`), `plugin/.claude-plugin/plugin.json` (v0.2.1, repo `github.com/leetusik/knowledge`), and `README.md` lines 16–20. Inside Claude Code:

    /plugin marketplace add leetusik/knowledge
    /plugin install knowledge@knowledge

Then `/knowledge:setup` once to scaffold a KB, and `/knowledge:explain <topic>` to use it. NOTE the namespace change: the embedded skill was bare `/explain`; the plugin's is **`/knowledge:explain`**. README/CHANGELOG copy should point users here, not invent any other pointer.

### Deferred D1

D1 ("Make /explain portable so public users can use it") is resolved by this deletion — the plugin makes it portable for real. The **orchestrator** runs `drop-deferred D1` after S1 lands (reason: resolved by retiring embedded explain in favor of the knowledge plugin). S1/executor must NOT run deferred commands.

### S1 execution note (done — for REVIEW)

The removal footprint in Findings matched reality exactly; every planned edit applied cleanly. Landed: both explain skill dirs deleted, wrapper's four explain bits removed, main.py's optional-skill block removed + `WORKSPACE_VERSION` → 15, smoke Test 8 rewritten to assert `--with-explain` is rejected, README.en.md pruned + knowledge-plugin pointer added, CHANGELOG v15 with Migration notes, and `bootstrap_agentic_workspace.sh` rebuilt (`--check` OK).

Notes for REVIEW:
- **Skill counts were re-derived, not decremented:** post-deletion `.claude/skills/*/` = 15 dirs, `.agents/skills/*/` = 14. README's "14 core … mirrored", "15 Agent Skills", and "15 Agent Skills (Claude Code)" are all correct as-is (explain was the separately-counted "optional" extra), so no number changed.
- **Sweep survivors are all expected:** zero explain hits in `installer/`, `.claude/`, `.agents/`, `README*`, and the rebuilt artifact. `tests/retrofit_smoke.sh` still contains `--with-explain`/`skills/explain` on lines 173–174 (kept regressions) and 209–214 (new Test 8) — required by plan step 4, not surprises. `docs/current/{operations,decisions}.md` + `docs/versions/**` + `docs/index.json` still carry explain history (the durable-doc consolidation REVIEW must supersede — operations v0010/v0011 + a new decisions entry).
- **`flag_stale_skills` / `OBSOLETE_MACHINERY` deliberately untouched** — the generic stale-skill flagging already gives the intended asymmetric `--update` behavior (Codex copy flagged, Claude copy left as operator-owned), documented in the CHANGELOG Migration notes.

## Constraints

- **Same-commit installer rebuild (non-negotiable):** S1 must run `python3 installer/build.py` and stage the rebuilt `bootstrap_agentic_workspace.sh` in the **same** commit as the machinery edits; `python3 installer/build.py --check` must pass (the `.githooks/pre-commit` hook enforces it — register once with `git config core.hooksPath .githooks`). The executor makes the edits + rebuild and validates; the orchestrator commits.
- **Workspace v15 + CHANGELOG policy:** `WORKSPACE_VERSION` 14→15 and a single new `## v15` CHANGELOG entry (newest-first) with **Migration notes**; never patch historical CHANGELOG entries.
- **Doc versioning is REVIEW-only:** S1 changes durable truth (operations + decisions) but must NOT run `doc-new-version`. It appends one-line **Doc impact** notes to the list below; P7.REVIEW consolidates them into new versions (supersede operations v0010/v0011 — explain no longer ships, plugin pointer; new decisions entry — embedded explain retired for the knowledge plugin).
- **D1 dropped by the orchestrator** after S1, not by the executor.
- **Design:** none — no product visual design in this phase.

## Doc impact

_Running list; REVIEW consolidates into doc versions. Slices append one-liners here._

- **operations** (P7.S1): explain no longer ships in the bootstrap; `--with-explain` retired (now an unknown option); `WITH_EXPLAIN`/`OPTIONAL_SKILLS` wiring removed; workspace bumped to v15. Supersedes operations v0010/v0011.
- **operations** (P7.S1): installers/users point at the knowledge repo's Claude Code plugin — `/plugin marketplace add leetusik/knowledge` → `/plugin install knowledge@knowledge`, then `/knowledge:setup` once and `/knowledge:explain <topic>` (namespace change from bare `/explain`).
- **decisions** (P7.S1): embedded explain retired in favor of the knowledge repo's Claude Code plugin; migration is manual (existing installs never auto-deleted). New decisions entry to add at REVIEW.

## Open Questions

- None. Gate satisfied, footprint verified, plugin pointer confirmed.
