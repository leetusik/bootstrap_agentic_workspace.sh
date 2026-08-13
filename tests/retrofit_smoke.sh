#!/usr/bin/env bash
# End-to-end smoke test for the --into-existing retrofit mode of
# bootstrap_agentic_workspace.sh.
#
# This file lives in tests/ on purpose: tests/ is NOT a managed directory, so
# the test is never installed into an adopter's repo. It builds throwaway sample
# repos under $TMPDIR, runs the retrofit, and asserts non-destructiveness, the
# empty-start invariant (no phases seeded), the collision tiers, the
# fresh-install regression, the live<->bootstrap-embedded dual-apply
# invariants, and the v31 Codex-removal negatives. Re-runnable; self-cleaning.
#
# Usage:  bash tests/retrofit_smoke.sh
# Exit 0 if every check passes; non-zero otherwise.

set -u
export PYTHONDONTWRITEBYTECODE=1   # keep target repos free of __pycache__/

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT="$REPO_ROOT/bootstrap_agentic_workspace.sh"

FAILS=0
TMPDIRS=()
cleanup() { for d in "${TMPDIRS[@]:-}"; do [ -n "${d:-}" ] && rm -rf "$d"; done; }
trap cleanup EXIT

ok()  { printf 'PASS: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n' "$1"; FAILS=$((FAILS + 1)); }
newtmp() { local _d; _d=$(mktemp -d); TMPDIRS+=("$_d"); printf -v "$1" '%s' "$_d"; }
sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}

command -v git >/dev/null 2>&1 || { echo "git is required to run this smoke test"; exit 2; }
[ -f "$BOOT" ] || { echo "installer not found: $BOOT"; exit 2; }

# ---------------------------------------------------------------------------
echo "== Test 0: the shipped Claude skill set is complete, and Codex stays gone =="
if python3 - "$REPO_ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
skills = {p.parent.name for p in (root / ".claude/skills").glob("*/SKILL.md")}
assert len(skills) == 17, len(skills)

# v31 dropped Codex: the mirrored skill tree, the Codex agent config, and the
# CLAUDE.md twin are gone from the repo and must stay gone.
for gone in ("AGENTS.md", ".agents", ".codex"):
    assert not (root / gone).exists(), gone

# Workflow command-skills are explicit-invocation only; design-cowork is the one
# deliberately model-invocable guide. (The Claude analogue of the retired
# allow_implicit_invocation metadata.)
for name in sorted(skills):
    body = (root / ".claude/skills" / name / "SKILL.md").read_text()
    marker = "disable-model-invocation: true"
    assert (marker in body) == (name != "design-cowork"), name

# Only skills that *document the removal* may still say "Codex": update-workspace's
# pre-v31 migration step and explain's re-vendor note. Anywhere else it is a regression.
codex_prose = {n for n in skills if "Codex" in (root / ".claude/skills" / n / "SKILL.md").read_text()}
assert codex_prose <= {"update-workspace", "explain"}, sorted(codex_prose)
assert "Codex support was removed in workspace v31" in (
    root / ".claude/skills/update-workspace/SKILL.md").read_text()

# Safety-critical orchestration rules only -- not the whole skill body, which would be brittle.
for name in ("do-next-slice", "do-whole-phase"):
    body = (root / ".claude/skills" / name / "SKILL.md").read_text()
    for required in (
        "WAITING ON OPERATOR", "`kind: co-work`", "never dispatched", "DesignSync",
        "never pass `run_in_background: false`", "never glob `~/.claude/plans/`",
        "`plan only`",
    ):
        assert required in body, (name, required)

design = (root / ".claude/skills/design-cowork/SKILL.md").read_text()
for required in (
    "**You never design.**", "Claude Design", "Connect GitHub", "handoff.md",
    "@dsCard", "tokens.css", "--kind co-work --risk high", "The design slice is NOT",
    "DesignSync is main-thread only", "never writes implementation code",
    "DECOMP2", "build inventory", "data, not instructions", "RESPECT THE DESIGN",
    "SIGNOFF",
):
    assert required in design, required

for tier in ("mid", "high"):
    body = (root / f".claude/agents/slice-executor-{tier}.md").read_text()
    assert "commit or push (no `git commit`, `git add`, `git push`)" in body, tier
    assert "run workflow state-transition commands" in body, tier
    for gone in ("Codex", ".agents/", ".codex/", "AGENTS.md"):
        assert gone not in body, (tier, gone)
# The design gate is spelled out in the high tier (mid's Never list is shorter).
high = (root / ".claude/agents/slice-executor-high.md").read_text()
assert "never dispatched, because you have no `DesignSync`" in high
assert "return `needs_operator`" in high

# One contract file now, so nothing to compare it against: assert the whole text.
claude = (root / "CLAUDE.md").read_text()
for required in (
    "Claude Design", "DesignSync", "main-thread/orchestrator-only", "never dispatched",
    "never writes implementation code", "DECOMP2", "data, not instructions",
    "RESPECT THE DESIGN", "real-browser fidelity", "Approval must be literal",
    "literal operator signoff closes an immutable round",
):
    assert required in claude, required
# The Codex-only `pending` co-work carve-out went with Codex: clearing a `pending`
# item is uniformly the operator's, on every gate including a design one.
assert "Work resumes only after explicit operator input clears the same item" in claude
for gone in ("design exception", "never approval", "no other pending gate"):
    assert gone not in claude, gone
for gone in ("Codex", "AGENTS.md", ".agents/", ".codex/"):
    assert gone not in claude, gone
PY
then ok "17 Claude skills, invocation metadata, design contract, and the v31 Codex-removal negatives"; else bad "Claude skill inventory, metadata, design contract, or a Codex-removal negative failed"; fi

# ---------------------------------------------------------------------------
echo "== Test 1: retrofit into a representative existing repo (non-destructive) =="
newtmp R
mkdir -p "$R/src" "$R/scripts" "$R/.claude"
printf '# Existing Project\n\nReal code.\n'          > "$R/README.md"
printf 'print("hello")\n'                            > "$R/src/app.py"
printf 'def util():\n    return 1\n'                  > "$R/scripts/util.py"
printf '# Their Contract\n\nUse 4-space indent.\n'    > "$R/CLAUDE.md"
printf '# Their Contract\n\nUse 4-space indent.\n'    > "$R/AGENTS.md"
printf '{\n  "permissions": {\n    "allow": ["Bash(make:*)"]\n  },\n  "env": {"FOO": "bar"}\n}\n' > "$R/.claude/settings.json"
printf '*.py text\n'                                  > "$R/.gitattributes"
git -C "$R" init -q
git -C "$R" add -A
git -C "$R" -c user.email=t@t -c user.name=t commit -qm "initial existing repo"
HEAD0=$(git -C "$R" rev-parse HEAD)
RM=$(sha "$R/README.md"); AP=$(sha "$R/src/app.py"); UT=$(sha "$R/scripts/util.py")
AG=$(sha "$R/AGENTS.md")

out=$(sh "$BOOT" "$R" --into-existing --name "Existing Project" --summary "An existing project." 2>&1)
rc=$?
[ "$rc" -eq 0 ] && ok "retrofit exits 0" || bad "retrofit exit=$rc -- $out"

[ "$(sha "$R/README.md")"     = "$RM" ] && ok "README.md byte-identical"  || bad "README.md changed"
[ "$(sha "$R/src/app.py")"    = "$AP" ] && ok "src/app.py byte-identical" || bad "src/app.py changed"
[ "$(sha "$R/scripts/util.py")" = "$UT" ] && ok "scripts/util.py byte-identical" || bad "scripts/util.py changed"
# AGENTS.md is a cross-tool convention other tools still read; since v31 this
# workspace neither ships nor touches one.
[ "$(sha "$R/AGENTS.md")"     = "$AG" ] && ok "a repo's own AGENTS.md left byte-identical" || bad "retrofit modified the repo's own AGENTS.md"
[ "$(git -C "$R" rev-parse HEAD)" = "$HEAD0" ] && ok "git HEAD unchanged" || bad "git HEAD changed"

mods=$(git -C "$R" status --porcelain | grep '^ M' | awk '{print $2}' | LC_ALL=C sort | tr '\n' ',')
[ "$mods" = ".claude/settings.json,.gitattributes,CLAUDE.md," ] \
  && ok "only the 3 intended files are modified (rest are additions)" \
  || bad "unexpected tracked modifications: $mods"

# .gitattributes is line-merged, never replaced; the CI workflow is seeded when absent.
grep -q '^\*\.py text$' "$R/.gitattributes" && ok ".gitattributes original rule preserved" || bad ".gitattributes original rule lost"
[ "$(grep -c '^works/events\.jsonl merge=union$' "$R/.gitattributes")" -eq 1 ] \
  && ok ".gitattributes gains exactly one union rule" || bad ".gitattributes union rule missing or duplicated"
[ -f "$R/.github/workflows/workspace-ci.yml" ] && ok "retrofit seeds the CI workflow" || bad "retrofit did not seed the CI workflow"

grep -q "Their Contract" "$R/CLAUDE.md" && ok "CLAUDE.md original content preserved" || bad "CLAUDE.md content lost"
[ -f "$R/CLAUDE.workspace.md" ] && ok "CLAUDE.workspace.md sidecar written" || bad "no CLAUDE.workspace.md sidecar"
[ "$(grep -c 'BEGIN agentic-workspace' "$R/CLAUDE.md")" -eq 1 ] && ok "exactly one marker block in CLAUDE.md" || bad "marker block count != 1"

if python3 - "$R/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
allow = d.get("permissions", {}).get("allow", [])
assert "Bash(make:*)" in allow, "custom permission lost"
assert "Bash(python3 scripts/workflow.py:*)" in allow, "workspace permission not added"
assert d.get("env", {}).get("FOO") == "bar", "unrelated key lost"
PY
then ok "settings.json additively merged (custom perm + env survive)"; else bad "settings.json merge incorrect"; fi

( cd "$R" && python3 scripts/workflow.py validate >/dev/null 2>&1 ) && ok "validate passes in target" || bad "validate failed in target"
nph=$(find "$R/works/phases/active" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[ "$nph" = "0" ] && ok "no phases seeded (workspace starts empty)" || bad "expected 0 seeded phases, found $nph"
cp_state=$(python3 -c "import json;print(json.load(open('$R/works/state.json'))['current_phase'])" 2>/dev/null)
[ "$cp_state" = "None" ] && ok "state.json has no current phase" || bad "state.json current_phase: '$cp_state'"
( cd "$R" && python3 scripts/workflow.py next 2>&1 | grep -q "no active slice" ) && ok "next reports the empty-start state" || bad "next does not report empty start"
[ ! -d "$R/.agents" ] && [ ! -d "$R/.codex" ] \
  && ok "retrofit installs no Codex trees (.agents/, .codex/)" || bad "retrofit created a Codex tree"
[ ! -f "$R/AGENTS.workspace.md" ] \
  && ok "retrofit writes no AGENTS.workspace.md sidecar" || bad "retrofit wrote an AGENTS.workspace.md sidecar"
[ "$(find "$R/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "17" ] \
  && ok "retrofit installs the 17-skill Claude inventory" || bad "retrofit skill inventory incomplete"
grep -q 'Claude Design' "$R/CLAUDE.workspace.md" && grep -q 'never writes implementation code' "$R/CLAUDE.workspace.md" \
  && grep -q 'RESPECT THE DESIGN' "$R/CLAUDE.workspace.md" \
  && ok "retrofit sidecar carries the visual design contract" || bad "retrofit visual contract is incomplete"

# ---------------------------------------------------------------------------
echo "== Test 2: re-running retrofit is an idempotent no-op =="
out=$(sh "$BOOT" "$R" --into-existing 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "re-run exits 0" || bad "re-run exit=$rc"
printf '%s\n' "$out" | grep -q "already contains an agentic workspace" && ok "re-run reports nothing to do" || bad "re-run not a no-op"
[ "$(grep -c 'BEGIN agentic-workspace' "$R/CLAUDE.md")" -eq 1 ] && ok "re-run does not duplicate the marker block" || bad "marker block duplicated on re-run"

# ---------------------------------------------------------------------------
echo "== Test 3: a foreign scripts/workflow.py aborts atomically =="
newtmp D
mkdir -p "$D/scripts"
printf 'README\n' > "$D/README.md"
printf 'FOREIGN\n' > "$D/scripts/workflow.py"
nbefore=$(find "$D" -type f | wc -l | tr -d ' ')
out=$(sh "$BOOT" "$D" --into-existing 2>&1); rc=$?
nafter=$(find "$D" -type f | wc -l | tr -d ' ')
[ "$rc" -ne 0 ] && ok "collision aborts (exit=$rc)" || bad "collision did not abort"
[ "$nbefore" = "$nafter" ] && ok "abort wrote zero files (atomic)" || bad "abort wrote files ($nbefore -> $nafter)"
[ "$(cat "$D/scripts/workflow.py")" = "FOREIGN" ] && ok "foreign workflow.py left intact" || bad "foreign workflow.py modified"

# ---------------------------------------------------------------------------
echo "== Test 4: a pre-existing docs/ system gates the docs subsystem =="
newtmp E
mkdir -p "$E/docs"
printf 'README\n' > "$E/README.md"
printf '{"my":"docs"}\n' > "$E/docs/index.json"
ED=$(sha "$E/docs/index.json")
out=$(sh "$BOOT" "$E" --into-existing 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "foreign-docs retrofit exits 0" || bad "foreign-docs exit=$rc"
printf '%s\n' "$out" | grep -q "docs subsystem: skipped" && ok "docs subsystem skipped" || bad "docs subsystem not skipped"
[ "$(sha "$E/docs/index.json")" = "$ED" ] && ok "their docs/index.json untouched" || bad "their docs/index.json changed"
[ -z "$(find "$E/docs" -name 'v0001_bootstrap.md')" ] && ok "no workspace doc files scattered" || bad "workspace doc files scattered into their docs/"
[ ! -d "$E/docs/current" ] && ok "no docs/current scaffolded" || bad "docs/current scaffolded"
[ -f "$E/works/state.json" ] && ok "works subsystem still installed" || bad "works subsystem missing"

# ---------------------------------------------------------------------------
echo "== Test 5: fresh-install regression (the no-flag path is unchanged) =="
newtmp F
out=$(sh "$BOOT" "$F" --name "Fresh" --summary "fresh" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "fresh install exits 0" || bad "fresh install exit=$rc"
( cd "$F" && python3 scripts/workflow.py validate >/dev/null 2>&1 ) && ok "fresh workspace validates" || bad "fresh workspace failed validate"
nphf=$(find "$F/works/phases/active" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
[ "$nphf" = "0" ] && ok "fresh install seeds no phases (empty start)" || bad "fresh install seeded $nphf phase(s)"
if python3 - "$REPO_ROOT" "$F/works/.workspace-version.json" <<'PY'
import json, re, sys
from pathlib import Path

root, marker_path = map(Path, sys.argv[1:])
main_version = int(re.search(r"^WORKSPACE_VERSION = (\d+)$", (root / "installer/main.py").read_text(), re.M).group(1))
changelog_versions = [int(v) for v in re.findall(r"^## v(\d+) ", (root / "CHANGELOG.md").read_text(), re.M)]
assert changelog_versions == sorted(set(changelog_versions), reverse=True), changelog_versions
top_changelog = changelog_versions[0]
marker_version = json.loads(marker_path.read_text())["workspace_version"]
# No literal pin: the three-way equality already catches any partial bump, and a
# release slice can bump the version without touching this test.
assert main_version == top_changelog == marker_version, (main_version, top_changelog, marker_version)
PY
then ok "release version agrees across installer, top changelog heading, and fresh marker"; else bad "release version markers disagree"; fi
[ -f "$F/.claude/skills/retrofit/SKILL.md" ] && ok "fresh install ships the retrofit skill" || bad "fresh install missing retrofit skill"
[ "$(find "$F/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "17" ] \
  && ok "fresh install has the 17 Claude skills" || bad "fresh skill inventory incomplete"
[ ! -f "$F/AGENTS.md" ] && [ ! -d "$F/.agents" ] && [ ! -d "$F/.codex" ] \
  && ok "fresh install is Codex-free (no AGENTS.md, no .agents/, no .codex/)" || bad "fresh install still ships Codex machinery"
[ -f "$F/.claude/agents/slice-executor-mid.md" ] && [ -f "$F/.claude/agents/slice-executor-high.md" ] && ok "fresh install ships the 2 Claude slice-executor tiers" || bad "fresh install missing Claude slice-executor tier(s)"
grep -q '^model: sonnet$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-mid.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "fresh install follows seeded flex mode: sonnet@xhigh / opus@xhigh" || bad "fresh flex tiers wrong"
[ ! -f "$F/.claude/agents/slice-executor.md" ] && ok "legacy untiered slice-executor retired (absent on fresh install)" || bad "legacy untiered slice-executor should be retired but is present"
[ ! -f "$F/.claude/agents/slice-executor-low.md" ] && ok "low tier retired in v23 (absent on fresh install)" || bad "slice-executor-low should be retired but is present"
[ -f "$F/executors.toml" ] && ok "fresh install seeds the tracked executors.toml selection" || bad "fresh install missing executors.toml"
[ -f "$F/.github/workflows/workspace-ci.yml" ] && ok "fresh install seeds the CI workflow" || bad "fresh install missing .github/workflows/workspace-ci.yml"
grep -q '^works/events\.jsonl merge=union$' "$F/.gitattributes" && ok "fresh install seeds .gitattributes with the union rule" || bad "fresh install missing the .gitattributes union rule"
[ ! -f "$F/.env.example" ] && [ ! -f "$F/executors.toml.example" ] && ok "legacy .env.example / executors.toml.example retired (absent on fresh install)" || bad "a legacy tier-config example should be retired but is present"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && ok "sync-agents --check: seeded flex config matches live agents" || bad "sync-agents --check failed on a fresh install"
printf '# No active mode selects the built-in economy preset.\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) \
  && grep -q '^model: sonnet$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: high$' "$F/.claude/agents/slice-executor-mid.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" && grep -q '^effort: high$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "no mode selects economy: sonnet/opus at high" || bad "economy mode matrix wrong"
printf '[claude.high]\nmodel = "fable"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) && grep -q '^model: fable$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "executors.toml override patches the high-tier model" || bad "executors.toml override did not patch the high tier"
printf 'mode = "flex"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) \
  && grep -q '^model: sonnet$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-mid.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "mode = flex selects sonnet/opus at xhigh" || bad "flex mode matrix wrong"
printf '[claude.low]\nmodel = "sonnet"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'retired in workspace v23' ) && ok "retired [claude.low] section rejected with a migration message" || bad "[claude.low] should be rejected as a retired tier"
printf '[codex.high]\nmodel = "gpt-5.6-sol"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'removed in workspace v31' ) && ok "leftover [codex.*] section rejected with the v31 migration message" || bad "[codex.*] should be rejected as removed support"
printf 'mode = "cheap"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && bad "unknown mode should fail sync-agents" || ok "unknown mode rejected"
printf 'mode = "flex"\nmode = "economy"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && bad "duplicate mode should fail sync-agents" || ok "duplicate mode rejected"
printf '[claude.high]\nmodel = "opus"\nmode = "flex"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && bad "mode after a section should fail sync-agents" || ok "mode after a section rejected"
printf '[claude.high]\nmodel = "fable"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) || bad "sync-agents failed re-applying the fable override"
rm -rf "$F/.claude/skills/do-whole-phase"
printf '%s\n' '# stale pre-v31 visual skill' > "$F/.claude/skills/design-cowork/SKILL.md"
# Seed the pre-v31 Codex shape so the v31 migration flagging has something to find.
mkdir -p "$F/.agents/skills/do-next-slice" "$F/.codex/agents"
printf 'stale\n' > "$F/.agents/skills/do-next-slice/SKILL.md"
printf 'stale\n' > "$F/.codex/agents/slice-executor.toml"
printf 'stale\n' > "$F/.codex/agents/slice-executor-low.toml"
printf '# their own contract\n' > "$F/AGENTS.md"
printf '# stranded retrofit sidecar\n' > "$F/AGENTS.workspace.md"
update_out=$(sh "$BOOT" "$F" --update 2>&1); update_rc=$?
[ "$update_rc" -eq 0 ] && grep -q 'fable' "$F/executors.toml" \
  && ok "--update preserves an edited executors.toml (seed-once)" || bad "--update clobbered or failed on an edited executors.toml"
[ -f "$F/.claude/skills/do-whole-phase/SKILL.md" ] \
  && ok "--update restores a deleted skill package" || bad "--update did not restore the deleted skill package"
printf '%s\n' "$update_out" | grep -q 'stale workspace.*\.claude/skills/do-whole-phase' \
  && bad "--update incorrectly flags do-whole-phase as stale" || ok "--update does not flag do-whole-phase as stale"
diff -q "$REPO_ROOT/.claude/skills/design-cowork/SKILL.md" "$F/.claude/skills/design-cowork/SKILL.md" >/dev/null \
  && ok "--update refreshes a stale design-cowork skill body" || bad "--update did not refresh design-cowork"
printf '%s\n' "$update_out" | grep -q 'stale workspace.*\.claude/skills/design-cowork' \
  && bad "--update incorrectly flags current design-cowork as stale" || ok "--update keeps design-cowork in the current inventory"
# v31 migration: each retired Codex path is named exactly once (the .codex directory
# entry subsumes the two old per-file ones) and nothing is ever deleted.
stale_line=$(printf '%s\n' "$update_out" | grep 'stale workspace skills/machinery')
stale_bad=""
for pat in '\.agents' '\.codex' 'AGENTS\.md' 'AGENTS\.workspace\.md'; do
  n=$(printf '%s\n' "$stale_line" | grep -o "$pat" | wc -l | tr -d ' ')
  [ "$n" = "1" ] || stale_bad="$stale_bad $pat=$n"
done
[ -z "$stale_bad" ] \
  && ok "--update flags each pre-v31 Codex path as stale exactly once" \
  || bad "v31 stale-machinery line is wrong ($stale_bad) -- $stale_line"
[ -f "$F/.agents/skills/do-next-slice/SKILL.md" ] && [ -f "$F/.codex/agents/slice-executor.toml" ] \
  && [ -f "$F/AGENTS.md" ] && [ -f "$F/AGENTS.workspace.md" ] \
  && ok "--update never deletes the flagged pre-v31 machinery" || bad "--update deleted machinery it only flags"
rm -rf "$F/.agents" "$F/.codex" "$F/AGENTS.md" "$F/AGENTS.workspace.md"
printf '%s\n' "$update_out" | grep -q 'python3 scripts/workflow.py sync-agents' \
  && ok "--update instructs the adopter to re-run sync-agents" || bad "--update omitted the sync-agents migration step"
grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "--update resets agent files to upstream defaults (re-run sync-agents after updates)" || bad "--update did not reset the agent files"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) \
  && bad "preserved executor override should require re-sync after update" || ok "--update leaves a detectable executor drift until sync-agents"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) \
  && grep -q '^model: fable$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "sync-agents re-applies the preserved executor override" || bad "sync-agents did not restore the preserved override"
rm -f "$F/executors.toml"
sh "$BOOT" "$F" --update >/dev/null 2>&1 && [ -f "$F/executors.toml" ] \
  && ok "--update seeds a missing executors.toml (pre-v9 workspace)" || bad "--update did not seed a missing executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && ok "re-seeded executors.toml restores the tracked flex selection" || bad "re-seeded executors.toml drifts from the tracked flex selection"
# --update reaches a pre-v24 workspace: CI is seeded once, .gitattributes is line-merged.
rm -f "$F/.github/workflows/workspace-ci.yml"
printf '*.md text\n' > "$F/.gitattributes"
sh "$BOOT" "$F" --update >/dev/null 2>&1
[ -f "$F/.github/workflows/workspace-ci.yml" ] && ok "--update seeds a missing CI workflow (pre-v24 workspace)" || bad "--update did not seed the CI workflow"
grep -q '^\*\.md text$' "$F/.gitattributes" && grep -q '^works/events\.jsonl merge=union$' "$F/.gitattributes" \
  && ok "--update line-merges .gitattributes (their rule kept, union rule appended)" || bad "--update did not line-merge .gitattributes"
printf '# hand-edited\n' >> "$F/.github/workflows/workspace-ci.yml"
sh "$BOOT" "$F" --update >/dev/null 2>&1
grep -q '^# hand-edited$' "$F/.github/workflows/workspace-ci.yml" && ok "--update preserves an edited CI workflow (seed-once)" || bad "--update clobbered an edited CI workflow"
[ "$(grep -c '^works/events\.jsonl merge=union$' "$F/.gitattributes")" -eq 1 ] && ok "--update .gitattributes merge is idempotent (one union rule)" || bad ".gitattributes union rule duplicated on re-update"
rm -f "$F/.github/workflows/workspace-ci.yml" "$F/.gitattributes"
sh "$BOOT" "$F" --update >/dev/null 2>&1   # restore both verbatim for the Test 6 diff
[ ! -f "$F/.claude/agents/phase-reviewer.md" ] && ok "phase-reviewer retired (absent on fresh install)" || bad "phase-reviewer should be retired but is present"
[ -d "$F/.claude/skills/do-whole-phase" ] && ok "fresh install keeps do-whole-phase" || bad "do-whole-phase skill missing"
[ -f "$F/.claude/skills/explain/SKILL.md" ] && ok "fresh install ships the explain skill" || bad "explain skill missing"
grep -q "knowledge:setup" "$F/.claude/skills/explain/SKILL.md" && bad "vendored explain still points at the plugin-only /knowledge:setup" || ok "vendored explain is de-plugin-ified"
# Since v31 the installer neither claims nor writes AGENTS.md, so --force-empty-ok
# installs beside a repo's own copy instead of aborting on a managed-file conflict.
newtmp H
printf '# Their cross-tool contract\n' > "$H/AGENTS.md"
AGH=$(sha "$H/AGENTS.md")
out=$(sh "$BOOT" "$H" --force-empty-ok --name "Fresh" --summary "fresh" 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ -f "$H/CLAUDE.md" ] \
  && ok "--force-empty-ok installs beside a repo's own AGENTS.md" || bad "--force-empty-ok beside AGENTS.md exit=$rc -- $out"
[ "$(sha "$H/AGENTS.md")" = "$AGH" ] && ok "install leaves a pre-existing AGENTS.md byte-identical" || bad "install rewrote the repo's own AGENTS.md"

# ---------------------------------------------------------------------------
echo "== Test 6: dual-apply -- live files match the bootstrap-embedded copies =="
# The fresh install in $F is generated straight from the bootstrap payload, so it
# is the source of truth to diff the live repo against.
diff -q "$REPO_ROOT/scripts/workflow.py" "$F/scripts/workflow.py" >/dev/null \
  && ok "scripts/workflow.py == bootstrap-embedded WORKFLOW_PY" \
  || bad "DRIFT: scripts/workflow.py differs from the bootstrap-embedded copy"
skill_rels=$(cd "$REPO_ROOT" && find .claude/skills -type f -name SKILL.md | LC_ALL=C sort)
nskill=$(printf '%s\n' "$skill_rels" | grep -c .)
[ "$nskill" -eq 17 ] && ok "dual-apply covers all 17 skill bodies" || bad "expected 17 SKILL.md files to diff, found $nskill"
for rel in $skill_rels; do
  diff -q "$REPO_ROOT/$rel" "$F/$rel" >/dev/null \
    && ok "dual-apply: $rel" \
    || bad "DRIFT: $rel differs from the bootstrap-embedded copy"
done
DUAL_FIXED=".claude/agents/slice-executor-mid.md
.claude/agents/slice-executor-high.md
.claude/settings.json
executors.toml
works/templates/deferred_brief.md
works/templates/intent.md
.github/workflows/workspace-ci.yml
.gitattributes"
for rel in $DUAL_FIXED CLAUDE.md; do
  diff -q "$REPO_ROOT/$rel" "$F/$rel" >/dev/null \
    && ok "dual-apply: $rel" \
    || bad "DRIFT: $rel differs from the bootstrap-embedded copy"
done
# The manifest above is hand-maintained; the installer's own list is the thing it
# must cover, so cross-check it instead of trusting both to be edited together.
if python3 - "$REPO_ROOT" scripts/workflow.py $DUAL_FIXED <<'PY'
import ast, sys
from pathlib import Path

root, covered = Path(sys.argv[1]), set(sys.argv[2:])
fixed = None
for node in ast.walk(ast.parse((root / "installer/build.py").read_text())):
    if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "FIXED_LIVE_FILES" for t in node.targets):
        fixed = [e.value for e in node.value.elts]
assert fixed, "FIXED_LIVE_FILES not found in installer/build.py"
assert not sorted(set(fixed) - covered), sorted(set(fixed) - covered)
PY
then ok "dual-apply manifest covers every installer FIXED_LIVE_FILES entry"; else bad "dual-apply manifest misses a FIXED_LIVE_FILES entry (see installer/build.py)"; fi

# ---------------------------------------------------------------------------
echo "== Test 7: the committed installer is in sync with installer/ source =="
# The distributable bootstrap_agentic_workspace.sh is a build product assembled by
# installer/build.py from installer/ (live files + payloads). --check fails if the
# committed artifact drifts from source, closing the loop: live files <-> artifact.
if ( cd "$REPO_ROOT" && python3 installer/build.py --check >/dev/null 2>&1 ); then
  ok "installer/build.py --check: artifact matches installer/ source"
else
  bad "DRIFT: bootstrap_agentic_workspace.sh is stale -- run: python3 installer/build.py"
fi

# ---------------------------------------------------------------------------
echo "== Test 8: --with-explain is retired (now an unknown option) =="
newtmp G
out=$(sh "$BOOT" "$G" --with-explain --name "Fresh" --summary "fresh" 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "--with-explain is rejected (exit=$rc)" || bad "--with-explain should be unknown but install exited 0 -- $out"
printf '%s\n' "$out" | grep -q "unknown option --with-explain" && ok "reports the unknown-option error" || bad "no unknown-option error -- $out"
[ ! -d "$G/.claude/skills" ] && [ ! -d "$G/.agents/skills" ] && ok "rejected install writes nothing" || bad "install wrote skills despite the rejection"

# ---------------------------------------------------------------------------
echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL RETROFIT SMOKE TESTS PASSED"
  exit 0
else
  echo "$FAILS CHECK(S) FAILED"
  exit 1
fi
