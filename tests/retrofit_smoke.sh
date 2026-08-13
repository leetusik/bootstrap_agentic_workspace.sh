#!/usr/bin/env bash
# End-to-end smoke test for the --into-existing retrofit mode of
# bootstrap_agentic_workspace.sh.
#
# This file lives in tests/ on purpose: tests/ is NOT a managed directory, so
# the test is never installed into an adopter's repo. It builds throwaway sample
# repos under $TMPDIR, runs the retrofit, and asserts non-destructiveness, the
# empty-start invariant (no phases seeded), the collision tiers, the
# fresh-install regression, and the live<->bootstrap-embedded dual-apply
# invariants. Re-runnable; self-cleaning.
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
echo "== Test 0: release skill manifest is complete and symmetric =="
if python3 - "$REPO_ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
claude = {p.parent.name for p in (root / ".claude/skills").glob("*/SKILL.md")}
codex = {p.parent.name for p in (root / ".agents/skills").glob("*/SKILL.md")}
assert len(claude) == 17, len(claude)
assert len(codex) == 17, len(codex)
assert claude == codex, (sorted(claude - codex), sorted(codex - claude))
for name in codex:
    meta_path = root / ".agents/skills" / name / "agents/openai.yaml"
    assert meta_path.is_file(), name
    meta = meta_path.read_text()
    expected = "true" if name == "design-cowork" else "false"
    assert f"allow_implicit_invocation: {expected}" in meta, (name, expected)

for name in ("do-next-slice", "do-whole-phase"):
    body = (root / ".agents/skills" / name / "SKILL.md").read_text()
    reject = body.index("Before running any workflow command or changing the repository")
    assert reject < body.index("Run `python3 scripts/workflow.py next`")
    for required in ("`gate`", "`plan only`", "Reject any other requested execution mode", "For a `ready` slice", "dispatch directly"):
        assert required in body, (name, required)
    for forbidden in ("EnterPlanMode", "ExitPlanMode", "harness plan", "~/.claude/plans", "Agent tool", "background task", "run_in_background", "$ARGUMENTS", "DesignSync"):
        assert forbidden not in body, (name, forbidden)

for name in ("do-next-slice", "do-whole-phase"):
    claude_body = (root / ".claude/skills" / name / "SKILL.md").read_text()
    assert "In Codex" not in claude_body, name
PY
then ok "17+17 skills have complete invocation metadata and Codex execution semantics"; else bad "skill inventory, metadata, or Codex execution contract is incomplete"; fi

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

out=$(sh "$BOOT" "$R" --into-existing --name "Existing Project" --summary "An existing project." 2>&1)
rc=$?
[ "$rc" -eq 0 ] && ok "retrofit exits 0" || bad "retrofit exit=$rc -- $out"

[ "$(sha "$R/README.md")"     = "$RM" ] && ok "README.md byte-identical"  || bad "README.md changed"
[ "$(sha "$R/src/app.py")"    = "$AP" ] && ok "src/app.py byte-identical" || bad "src/app.py changed"
[ "$(sha "$R/scripts/util.py")" = "$UT" ] && ok "scripts/util.py byte-identical" || bad "scripts/util.py changed"
[ "$(git -C "$R" rev-parse HEAD)" = "$HEAD0" ] && ok "git HEAD unchanged" || bad "git HEAD changed"

mods=$(git -C "$R" status --porcelain | grep '^ M' | awk '{print $2}' | LC_ALL=C sort | tr '\n' ',')
[ "$mods" = ".claude/settings.json,.gitattributes,AGENTS.md,CLAUDE.md," ] \
  && ok "only the 4 intended files are modified (rest are additions)" \
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
[ -f "$R/.agents/skills/do-whole-phase/SKILL.md" ] \
  && [ -f "$R/.agents/skills/do-whole-phase/agents/openai.yaml" ] \
  && ok "retrofit ships Codex do-whole-phase body + metadata" || bad "retrofit missing Codex do-whole-phase package"
[ "$(find "$R/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "17" ] \
  && [ "$(find "$R/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "17" ] \
  && [ "$(find "$R/.agents/skills" -mindepth 3 -maxdepth 3 -name openai.yaml -type f | wc -l | tr -d ' ')" = "17" ] \
  && ok "retrofit installs both 17-skill inventories with complete Codex metadata" || bad "retrofit skill inventory incomplete"

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
assert main_version == top_changelog == marker_version == 29, (main_version, top_changelog, marker_version)
PY
then ok "release version is v29 in installer, top changelog heading, and fresh marker"; else bad "v29 release markers disagree"; fi
[ -f "$F/.claude/skills/retrofit/SKILL.md" ] && ok "fresh install ships the retrofit skill" || bad "fresh install missing retrofit skill"
[ "$(find "$F/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "17" ] \
  && [ "$(find "$F/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "17" ] \
  && [ "$(find "$F/.agents/skills" -mindepth 3 -maxdepth 3 -name openai.yaml -type f | wc -l | tr -d ' ')" = "17" ] \
  && ok "fresh install has 17 Claude + 17 Codex skills and all Codex metadata" || bad "fresh skill inventory incomplete"
[ -f "$F/.claude/agents/slice-executor-mid.md" ] && [ -f "$F/.claude/agents/slice-executor-high.md" ] && ok "fresh install ships the 2 Claude slice-executor tiers" || bad "fresh install missing Claude slice-executor tier(s)"
[ -f "$F/.codex/agents/slice-executor-mid.toml" ] && [ -f "$F/.codex/agents/slice-executor-high.toml" ] && ok "fresh install ships the 2 Codex slice-executor tiers" || bad "fresh install missing Codex slice-executor tier(s)"
grep -q '^model: sonnet$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-mid.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "fresh install follows seeded flex mode: Claude sonnet@xhigh / opus@xhigh" || bad "fresh Claude flex tiers wrong"
grep -q '^model = "gpt-5.6-terra"$' "$F/.codex/agents/slice-executor-mid.toml" \
  && grep -q '^model_reasoning_effort = "high"$' "$F/.codex/agents/slice-executor-mid.toml" \
  && grep -q '^model = "gpt-5.6-sol"$' "$F/.codex/agents/slice-executor-high.toml" \
  && grep -q '^model_reasoning_effort = "high"$' "$F/.codex/agents/slice-executor-high.toml" \
  && ok "fresh install follows seeded flex mode: Codex gpt-5.6-terra@high / gpt-5.6-sol@high" || bad "fresh Codex flex tiers wrong"
[ ! -f "$F/.claude/agents/slice-executor.md" ] && [ ! -f "$F/.codex/agents/slice-executor.toml" ] && ok "legacy untiered slice-executor retired (absent on fresh install)" || bad "legacy untiered slice-executor should be retired but is present"
[ ! -f "$F/.claude/agents/slice-executor-low.md" ] && [ ! -f "$F/.codex/agents/slice-executor-low.toml" ] && ok "low tier retired in v23 (absent on fresh install)" || bad "slice-executor-low should be retired but is present"
[ -f "$F/executors.toml" ] && ok "fresh install seeds the tracked executors.toml selection" || bad "fresh install missing executors.toml"
[ -f "$F/.github/workflows/workspace-ci.yml" ] && ok "fresh install seeds the CI workflow" || bad "fresh install missing .github/workflows/workspace-ci.yml"
grep -q '^works/events\.jsonl merge=union$' "$F/.gitattributes" && ok "fresh install seeds .gitattributes with the union rule" || bad "fresh install missing the .gitattributes union rule"
[ ! -f "$F/.env.example" ] && [ ! -f "$F/executors.toml.example" ] && ok "legacy .env.example / executors.toml.example retired (absent on fresh install)" || bad "a legacy tier-config example should be retired but is present"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && ok "sync-agents --check: seeded flex config matches live agents" || bad "sync-agents --check failed on a fresh install"
printf '# No active mode selects the built-in economy preset.\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) \
  && grep -q '^model: sonnet$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: high$' "$F/.claude/agents/slice-executor-mid.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" && grep -q '^effort: high$' "$F/.claude/agents/slice-executor-high.md" \
  && grep -q '^model = "gpt-5.6-luna"$' "$F/.codex/agents/slice-executor-mid.toml" && grep -q '^model_reasoning_effort = "high"$' "$F/.codex/agents/slice-executor-mid.toml" \
  && grep -q '^model = "gpt-5.6-terra"$' "$F/.codex/agents/slice-executor-high.toml" && grep -q '^model_reasoning_effort = "high"$' "$F/.codex/agents/slice-executor-high.toml" \
  && ok "no mode selects economy: Claude sonnet/opus and Codex luna/terra at high" || bad "economy mode matrix wrong"
printf '[claude.high]\nmodel = "fable"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) && grep -q '^model: fable$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "executors.toml override patches the high-tier model" || bad "executors.toml override did not patch the high tier"
printf 'mode = "flex"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) \
  && grep -q '^model: sonnet$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-mid.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-high.md" \
  && grep -q '^model = "gpt-5.6-terra"$' "$F/.codex/agents/slice-executor-mid.toml" && grep -q '^model_reasoning_effort = "high"$' "$F/.codex/agents/slice-executor-mid.toml" \
  && grep -q '^model = "gpt-5.6-sol"$' "$F/.codex/agents/slice-executor-high.toml" && grep -q '^model_reasoning_effort = "high"$' "$F/.codex/agents/slice-executor-high.toml" \
  && ok "mode = flex selects Claude sonnet/opus@xhigh and Codex terra/sol@high" || bad "flex mode matrix wrong"
printf '[claude.low]\nmodel = "sonnet"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'retired in workspace v23' ) && ok "retired [claude.low] section rejected with a migration message" || bad "[claude.low] should be rejected as a retired tier"
printf 'mode = "cheap"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && bad "unknown mode should fail sync-agents" || ok "unknown mode rejected"
printf 'mode = "flex"\nmode = "economy"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && bad "duplicate mode should fail sync-agents" || ok "duplicate mode rejected"
printf '[claude.high]\nmodel = "opus"\nmode = "flex"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && bad "mode after a section should fail sync-agents" || ok "mode after a section rejected"
printf '[claude.high]\nmodel = "fable"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) || bad "sync-agents failed re-applying the fable override"
rm -rf "$F/.agents/skills/do-whole-phase"
update_out=$(sh "$BOOT" "$F" --update 2>&1); update_rc=$?
[ "$update_rc" -eq 0 ] && grep -q 'fable' "$F/executors.toml" \
  && ok "--update preserves an edited executors.toml (seed-once)" || bad "--update clobbered or failed on an edited executors.toml"
[ -f "$F/.agents/skills/do-whole-phase/SKILL.md" ] \
  && [ -f "$F/.agents/skills/do-whole-phase/agents/openai.yaml" ] \
  && ok "--update restores a missing pre-parity Codex do-whole-phase package" || bad "--update did not restore Codex do-whole-phase"
printf '%s\n' "$update_out" | grep -q 'stale workspace.*\.agents/skills/do-whole-phase' \
  && bad "--update incorrectly flags Codex do-whole-phase as stale" || ok "--update does not flag Codex do-whole-phase as stale"
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
[ ! -f "$F/.codex/agents/phase-reviewer.toml" ] && [ ! -f "$F/.claude/agents/phase-reviewer.md" ] && ok "phase-reviewer retired (absent on fresh install)" || bad "phase-reviewer should be retired but is present"
[ -f "$F/.agents/skills/do-whole-phase/SKILL.md" ] && ok "fresh install ships Codex do-whole-phase" || bad "Codex do-whole-phase skill missing"
[ -f "$F/.agents/skills/do-whole-phase/agents/openai.yaml" ] && ok "fresh install ships Codex do-whole-phase policy" || bad "Codex do-whole-phase openai.yaml missing"
[ -d "$F/.claude/skills/do-whole-phase" ] && ok "fresh install keeps Claude do-whole-phase" || bad "Claude do-whole-phase missing"
[ -f "$F/.claude/skills/explain/SKILL.md" ] && ok "fresh install ships the Claude explain skill" || bad "Claude explain skill missing"
[ -f "$F/.agents/skills/explain/SKILL.md" ] && ok "fresh install ships the Codex explain skill" || bad "Codex explain skill missing"
[ -f "$F/.agents/skills/explain/agents/openai.yaml" ] && ok "fresh install ships the Codex explain policy" || bad "Codex explain openai.yaml missing"
grep -q "knowledge:setup" "$F/.claude/skills/explain/SKILL.md" && bad "vendored explain still points at the plugin-only /knowledge:setup" || ok "vendored explain is de-plugin-ified"

# ---------------------------------------------------------------------------
echo "== Test 6: dual-apply -- live files match the bootstrap-embedded copies =="
# The fresh install in $F is generated straight from the bootstrap payload, so it
# is the source of truth to diff the live repo against.
diff -q "$REPO_ROOT/scripts/workflow.py" "$F/scripts/workflow.py" >/dev/null \
  && ok "scripts/workflow.py == bootstrap-embedded WORKFLOW_PY" \
  || bad "DRIFT: scripts/workflow.py differs from the bootstrap-embedded copy"
for rel in $(cd "$REPO_ROOT" && find .claude/skills .agents/skills -type f \( -name SKILL.md -o -name openai.yaml \) | LC_ALL=C sort); do
  diff -q "$REPO_ROOT/$rel" "$F/$rel" >/dev/null \
    && ok "dual-apply: $rel" \
    || bad "DRIFT: $rel differs from the bootstrap-embedded copy"
done
for rel in \
  .claude/agents/slice-executor-mid.md .claude/agents/slice-executor-high.md \
  .codex/agents/slice-executor-mid.toml .codex/agents/slice-executor-high.toml \
  .claude/settings.json .codex/config.toml executors.toml \
  works/templates/deferred_brief.md works/templates/intent.md \
  .github/workflows/workspace-ci.yml .gitattributes \
  CLAUDE.md AGENTS.md ; do
  diff -q "$REPO_ROOT/$rel" "$F/$rel" >/dev/null \
    && ok "dual-apply: $rel" \
    || bad "DRIFT: $rel differs from the bootstrap-embedded copy"
done

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
