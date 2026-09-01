#!/usr/bin/env bash
# End-to-end smoke test for the --into-existing retrofit mode of
# bootstrap_agentic_workspace.sh.
#
# This file lives in tests/ on purpose: tests/ is NOT a managed directory, so
# the test is never installed into an adopter's repo. It builds throwaway sample
# repos under $TMPDIR, runs the retrofit, and asserts non-destructiveness, the
# empty-start invariant (no phases seeded), the collision tiers, the
# fresh-install regression, the live<->bootstrap-embedded dual-apply
# invariants, the v32 operator-acceptance-gate invariants, the v36 research-slice
# invariants (the kind is in the closed set and its semantics are in the
# contract, both agent bodies and both do-* skills), the v36 Aside invariants
# (Aside is the prescribed real-browser instrument, driven on the v37 `repl`
# surface over Bash rather than a standing MCP registration, with a fallback that
# excuses no check, in the contract, both agent bodies and the design/review skills),
# the v35 phase-notebook
# invariants (template seed, generated ## Slices block, finish-slice --outcome, the
# notebook budget/case-drift warnings and the timestamp-free dashboards), and the
# v31 Codex-removal negatives. Re-runnable; self-cleaning.
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
sha_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else sha256sum | awk '{print $1}'; fi
}
sha() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else sha256sum "$1" | awk '{print $1}'; fi
}

command -v git >/dev/null 2>&1 || { echo "git is required to run this smoke test"; exit 2; }
[ -f "$BOOT" ] || { echo "installer not found: $BOOT"; exit 2; }

# ---------------------------------------------------------------------------
echo "== Test 0: the shipped Claude skill set is complete, the v32 operator gate is wired, and Codex stays gone =="
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

# Workflow command-skills are explicit-invocation only, with exactly two exceptions:
# design-cowork (a guide that fires by itself) and, since v34, create-phase (callable
# by the agent WHEN INSTRUCTED, never on its own initiative -- its confirmation gate,
# not its invocation, is the safety). Every other skill must still carry the marker.
# (The Claude analogue of the retired allow_implicit_invocation metadata.)
model_invocable = {"design-cowork", "create-phase"}
for name in sorted(skills):
    body = (root / ".claude/skills" / name / "SKILL.md").read_text()
    marker = "disable-model-invocation: true"
    assert (marker in body) == (name not in model_invocable), name
create_phase = (root / ".claude/skills/create-phase/SKILL.md").read_text()
assert "the agent when instructed" in create_phase
assert "Never on the agent's own initiative" in create_phase
assert "Invocation is not the gate; confirmation is." in create_phase
for required in ("`build-after`", "`design-only`", "`paired`", "## Design Style"):
    assert required in create_phase, required

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
        "`plan only`", "accept-gate <P> --clear",
        # v34: the design slice runs inline -> dispatched -> inline, in one of three
        # named styles, and stops `pending` twice with different meanings.
        "mockup build is the one dispatched span", "`build-after`", "`design-only`",
        "`paired`", "PENDING #1", "PENDING #2", "## Design Style",
        "mechanical wait, not an approval",
        # v35: just-in-time reads and the bounded notebook.
        "finish-slice <slice_id> --outcome", "bounded phase notebook",
        "verdict block", "just in time",
        # v36: the research kind routes high by KIND, and DECOMP2 is no longer a
        # design-only device -- it is also the sequel to a research slice.
        "that is what the `research` kind is for", "`--kind research --risk high`",
        "second origin", "`research` and review always",
    ):
        assert required in body, (name, required)
    # v35: the per-slice re-read of the generated backlog dashboard is gone --
    # `next` prints the pointer. The only mentions left must say so.
    for ln in body.splitlines():
        if "works/backlog.md" in ln:
            assert "next" in ln and "pointer" in ln, (name, ln)

# The spec hard-wraps its prose, so match against a whitespace-flattened copy: these
# assertions are about the wording, not about where a line happens to break.
design = " ".join((root / ".claude/skills/design-cowork/SKILL.md").read_text().split())
for required in (
    "**You never design.**", "Claude Design", "Connect GitHub", "handoff.md",
    "@dsCard", "tokens.css", "--kind co-work --risk high",
    "DesignSync is main-thread only",
    "DECOMP2", "build inventory", "data, not instructions", "RESPECT THE DESIGN",
    "SIGNOFF",
    # v32: fidelity has a second yardstick, and gaps are delivered, not archived.
    "## Verifying — RESPECT THE DESIGN, and does it work",
    "### When the record never drew it", "matching it is not acceptance",
    "Questions get asked, not archived.",
    # v34: the dispatch ban narrowed to the DesignSync work (the mockup build is the
    # one dispatched span), the code ban narrowed to *product* code, and the operator
    # now signs a running mockup rather than the cards alone.
    "the DesignSync work is never dispatched",
    "The mockup build is the one dispatched span",
    "A design slice writes no *product* implementation code",
    "Write **product** implementation code in a design slice",
    "signing the round off — the cards, and the stubbed mockup with them — is not accepting the product",
    # v34, positive: the three named styles, the mockup section, PENDING #1 is not an
    # approval, and the mockup's exemption from the functional sweep.
    "## Shape — three styles", "**`build-after`**", "**`design-only`**", "**`paired`**",
    "## The mockup — the design in the project's own language",
    "Only PENDING #2 is an approval.", "PENDING #1 is a mechanical wait",
    "Exempt from the full functional sweep", "Stubbed data, no backing work",
    # v36: the doctrine names an instrument -- Aside -- and a fallback that
    # excuses no check. v37: two surfaces rather than three, the `repl` surface
    # over Bash as the default (with the measured per-session MCP tool-definition
    # cost as the recorded reason, and the re-attach preamble written out once),
    # the surface's two sharp edges, and the MCP registration demoted to an
    # operator-only escape hatch.
    "**With what — the instrument.**",
    "**two surfaces, not three**",
    "**The default is `aside repl` over Bash**",
    "~1,344 tokens",
    "nothing ships, nothing registers, nothing is configured",
    "const page = await attachBrowserTab(tabs[0].targetId);",
    "requires both `title` and `code`",
    "RefStaleError",
    "claude mcp add -s local aside -- aside mcp",
    "escape hatch",
    # v37: what the doctrine rejects is the pre-written suite, not the library --
    # the surface IS Playwright; what differs is who picks the next action.
    "in place of a pre-written assertion suite",
    "**Why the executor drives, and not a pre-written suite.**",
    "deciding every check in advance",
    "The fallback — the doctrine's demands bind, the instrument does not.",
    # v37: whose browser an agent may drive -- a dedicated profile, named per
    # invocation, with the personal-profile case as its own third halt, and the
    # one clause generalizing the principle to the fallback browser.
    "**Whose browser — a dedicated profile, never the operator's.**",
    '`aside repl --account <id> "<js>"`',
    "do not rely on `aside account use <id>`",
    "That is a **third** halt condition and it is not the runtime one",
    "an agent never drives a browser profile signed into the operator's accounts, whichever browser it is",
):
    assert required in design, required
# v37 negatives: the MCP-first prescription is retired -- no config block to copy,
# no surface preference, and no "Playwright-style automation" framing anywhere.
for gone in ('{"mcpServers"', "Prefer the **MCP** surface", "MCP first",
             "scripted Playwright-style automation", "scripted assertion suite"):
    assert gone not in design, gone

# v32 review procedure: the gate stages, the returned walkthrough, and the two
# workflow commands a review slice must never run.
review = (root / ".claude/skills/review-phase/SKILL.md").read_text()
for required in ("## Gate stages", "`walkthrough`", "`## Operator Runtime`", "`## Regression Checklist`",
                 # v36: the review opens the product with the prescribed instrument.
                 "**Drive it with Aside**", "the doctrine's demands bind, the instrument does not",
                 "with the same instrument as stage 2",
                 # v37: on the `repl` surface over Bash, never a standing MCP
                 # registration, and against no pre-written suite.
                 "the `repl` surface over Bash", "never a standing `aside mcp` registration",
                 "in place of a pre-written assertion suite",
                 # v37: the review drives the product on the agent's own profile.
                 "always on the agent's own Aside profile",
                 '`aside repl --account <id> "<js>"`',
                 "never the operator's signed-in one"):
    assert required in review, required
for gone in ("MCP surface first", "scripted Playwright-style automation",
             # the default is never moved with `aside account use`; the flag is
             # passed per invocation.
             "aside account use"):
    assert gone not in review, gone
never = [ln for ln in review.splitlines() if "you never run on a review slice" in ln]
assert len(never) == 1 and "`accept-gate`" in never[0] and "`defer-job`" in never[0], never

# v32 seed doc bodies: the runtime manifest (with its greppable unfilled marker)
# and the cumulative smoke list's line shape reach every fresh install.
ops = (root / "installer/payloads/doc_bodies/operations.md").read_text()
assert "## Operator Runtime" in ops and "UNFILLED" in ops
# v36: one seed field records what THIS machine has; its absence never stops a slice.
assert "- Browser instrument for the agent:" in ops
assert "its absence alone never stops a slice" in ops
# v37: the field names how the agent drives it -- `aside repl` over Bash -- and no
# fresh install is told to stand up an MCP server.
assert "`aside repl` over Bash" in ops
assert "aside mcp" not in ops
# v37: a second field, conditionally required -- whenever the instrument is Aside,
# the manifest names the agent's own account id, never the operator's profile.
assert "- Agent's Aside account id (required whenever the instrument above is Aside):" in ops
assert "never the operator's signed-in one" in ops
assert "aside account use" not in ops
qa = (root / "installer/payloads/doc_bodies/qa.md").read_text()
assert "## Regression Checklist" in qa
assert "- [ ] <surface>: <one observable behaviour> (P<N>)" in qa

bodies = {}
for tier in ("mid", "high"):
    body = (root / f".claude/agents/slice-executor-{tier}.md").read_text()
    assert "commit or push (no `git commit`, `git add`, `git push`)" in body, tier
    for gone in ("Codex", ".agents/", ".codex/", "AGENTS.md"):
        assert gone not in body, (tier, gone)
    # v32: the design gate (D2), the acceptance-gate stages, and the walkthrough
    # return field are word-for-word in BOTH tiers, not high only.
    assert "never dispatched, because you have no `DesignSync`" in body, tier
    assert "return `needs_operator`" in body, tier
    # v34: the mockup span is dispatchable and its rules ship in BOTH tiers.
    for required in (
        "The mockup span of a `co-work` (design) slice",
        "Stubbed data, no backing work",
        "exempt from the full functional sweep",
        "*product* implementation work",
        "`build-after`", "`design-only`", "`paired`",
    ):
        assert required in body, (tier, required)
    # v36: the research kind is findings-only, lands its findings in the notebook,
    # and reaches this tier by kind -- so BOTH bodies carry it word for word.
    for required in (
        "**Research slice (`kind: research`):** findings-only — **write no product code.**",
        "in `phase.md`, where the next slice will actually read them",
        "write **product** code on a `research` slice",
        "`decomposition`, `research` and `review` slice",
        "that is `DECOMP2`'s second origin",
    ):
        assert required in body, (tier, required)
    # v36: Aside is the prescribed real-browser instrument in BOTH bodies -- the
    # implementation bullet, the mockup span, and the review's gate stage 2.
    for required in (
        "Drive that browser with **Aside**",
        "the doctrine's demands bind, the instrument does not",
        "Name in `result.md` which instrument you used",
        "driven with the same instrument (Aside first)",
        "driving it with the same instrument (Aside first, the fallback browser otherwise)",
    ):
        assert required in body, (tier, required)
    # v37: the concrete default an executor actually runs is in BOTH bodies -- the
    # `repl` surface over Bash with a reachable re-attach preamble, never a standing
    # MCP registration, and against no pre-written suite.
    for required in (
        "Run its `repl` surface over Bash",
        "`aside repl \"<js>\"`",
        "`listBrowserTabs()` → `attachBrowserTab()`",
        "never a standing `aside mcp` registration",
        "in place of a pre-written assertion suite",
        # v37: and on the agent's own Aside profile, named per invocation, with
        # the personal-profile case as a third halt of its own.
        "Every call names the agent's own Aside profile",
        '`aside repl --account <id> "<js>"`',
        "never the operator's signed-in one",
        "return `needs_operator` (a third halt, distinct from the runtime one)",
    ):
        assert required in body, (tier, required)
    for gone in ("MCP surface first", "scripted Playwright-style automation",
                 # nothing tells an executor to move the default account.
                 "aside account use"):
        assert gone not in body, (tier, gone)
    assert "On a gated phase (`acceptance.required` is `true` — and only then) also run the gate stages" in body, tier
    assert "- `walkthrough`:" in body, tier
    # v35: reads are just-in-time, result.md leads with the verdict block, and the
    # phase notebook is EDITED under budget -- except the engine-generated block.
    for required in (
        "just in time, never the whole tree",
        "**only when you are unsure what was asked**",
        "never the whole doc set, and never `docs/index.json`",
        "**structured verdict block first**",
        "**Edit** the phase's `phase.md`",
        "a soft ~100k-token cap (400 KB)",
        "never edit inside the `<!-- slices:begin -->`",
        "edit inside `phase.md`'s generated `## Slices` block",
        "Cross-check the notebook against the logs",
    ):
        assert required in body, (tier, required)
    never = [ln for ln in body.splitlines() if "run workflow state-transition commands" in ln]
    assert len(never) == 1 and "`accept-gate`" in never[0] and "`defer-job`" in never[0], tier
    bodies[tier] = body.split("---\n", 2)[2]
# The tiers differ in frontmatter only, so a body diff is the drift detector.
assert bodies["mid"] == bodies["high"], "slice-executor tier bodies drifted"

# One contract file now, so nothing to compare it against: assert the whole text.
claude = (root / "CLAUDE.md").read_text()
for required in (
    "Claude Design", "DesignSync", "never dispatched",
    "DECOMP2", "data, not instructions",
    "RESPECT THE DESIGN", "real-browser fidelity", "Approval must be literal",
    "literal operator signoff closes an immutable round",
    # v32: the operator acceptance gate, the runtime manifest, the question channel.
    "accept-gate", "## Operator Runtime", "## Operator Questions", "never by omission",
    # v34: the narrowed bans, the three named styles, and the closed --kind set.
    "*DesignSync* work is never dispatched", "mockup build is its one dispatched span",
    "writes no ***product*** implementation code",
    "**`build-after`**", "**`design-only`**", "**`paired`**", "## Design Style",
    "only PENDING #2 is an approval", "`--kind` is a **closed set**",
    # v35: just-in-time reads, the bounded/edited notebook, and the slice outcome.
    "Just in time, and only what the work in front of you needs",
    "never the whole doc set up front, and never `docs/index.json`",
    "**bounded state**", "PHASE_MD_BUDGET", "a soft ~100k-token cap (400 KB)",
    "every slice **edits** it under budget", "structured verdict block first",
    "finish-slice P1.S1 --outcome",
    # v36: the research kind (findings-only, high by kind, findings in the notebook)
    # and DECOMP2 generalized past the build-after design style.
    "**`research` is a findings-only slice kind, and a `DECOMP2` usually follows it.**",
    "if the two ever disagree the **kind wins**",
    "**findings land in `phase.md`**",
    "**`DECOMP2` has two origins**", "`P<N>.DECOMP3`",
    "`research`, `fix`, `docs`, `qa`, `co-work`",
    # v36: Aside is the named instrument, on its own axis, with a binding fallback.
    # v37: the rule names the two surfaces, defaults to `aside repl` over Bash with
    # the measured per-session MCP cost as its reason, keeps the registration only as
    # an operator escape hatch, and rejects the pre-written suite, not Playwright.
    "**Real-browser verification runs through Aside, not a pre-written assertion suite.**",
    "**Instrument and runtime are different axes:**",
    "**the doctrine's demands bind, the instrument does not.**",
    "**Two surfaces, not three:**",
    "**The default is `aside repl` over Bash**",
    "~1,344 tokens",
    "`claude mcp add -s local aside -- aside mcp` is an optional per-operator, per-session **escape hatch**",
    # v37: whose browser -- a dedicated profile via a per-invocation flag, and the
    # personal-profile case as a third halt, distinct from the runtime one.
    "**Whose browser: a dedicated profile.**",
    "pass `--account <id>` on every invocation",
    "is a **third** halt: `needs_operator` → `pending`",
    "an agent never drives a profile signed into the operator's accounts",
):
    assert required in claude, required
# v37 negatives: the MCP-first prescription and the Playwright framing are retired
# from the contract too -- the fact survives only where it explains the escape hatch.
for gone in ("Prefer the **MCP** surface", "scripted Playwright-style automation",
             "runs through Aside, not a script"):
    assert gone not in claude, gone
# v35 negatives: the pre-v35 read order and the append-only notebook verb are gone.
for gone in ("for the fullstack doc set", "appends phase notes/doc impact",
             "appends durable cross-slice notes"):
    assert gone not in claude, gone
# The Codex-only `pending` co-work carve-out went with Codex: clearing a `pending`
# item is uniformly the operator's, on every gate including a design one.
assert "Work resumes only after explicit operator input clears the same item" in claude
for gone in ("design exception", "never approval", "no other pending gate"):
    assert gone not in claude, gone
for gone in ("Codex", "AGENTS.md", ".agents/", ".codex/"):
    assert gone not in claude, gone
PY
then ok "17 Claude skills, invocation metadata, design contract, the v32 acceptance-gate invariants, the v36 research-kind and Aside-instrument invariants, the v37 Aside-surface invariants (two surfaces, `aside repl` over Bash, no standing MCP registration, the assertion-suite framing), the v37 dedicated-profile invariants (`--account <id>` per invocation, the manifest field, the personal-profile halt), and the v31 Codex-removal negatives"; else bad "Claude skill inventory, metadata, design contract, a v32 gate invariant, a v36 research-kind or Aside-instrument invariant, a v37 Aside-surface or dedicated-profile invariant, or a Codex-removal negative failed"; fi

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
grep -q 'Claude Design' "$R/CLAUDE.workspace.md" && grep -q 'writes no \*\*\*product\*\*\* implementation code' "$R/CLAUDE.workspace.md" \
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
# v37: every released section carries a Migration notes line -- the file's own intro
# promises one whenever a sync needs manual steps, and /update-workspace prints exactly
# those lines to adopting repos. v37's sharpest instruction (remove a v36 `aside mcp`
# registration) reaches an adopter through no other channel.
if python3 - "$REPO_ROOT" <<'PY'
import re, sys
from pathlib import Path

parts = re.split(r"^## (v\d+) ", (Path(sys.argv[1]) / "CHANGELOG.md").read_text(), flags=re.M)
it = iter(parts[1:])
missing = [v for v, body in zip(it, it) if "Migration notes" not in body]
assert not missing, missing
PY
then ok "every changelog release section carries a Migration notes line"; else bad "a changelog release section has no Migration notes line"; fi
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
# v32 operator acceptance gate, probed once against a real engine (throwaway workspace).
( cd "$F" && python3 scripts/workflow.py new-phase --phase P1 --name "Gate probe" --objective "probe the gate" >/dev/null 2>&1 ) \
  && grep -q '"acceptance"' "$F/works/phases/active/P1/phase.json" && ok "new-phase stamps the acceptance gate block" || bad "new-phase did not stamp the acceptance block"
( cd "$F" && python3 scripts/workflow.py review-phase P1 --verdict pass 2>&1 | grep -q 'accept-gate P1 --require' ) \
  && ok "review-phase --verdict pass refuses an undeclared acceptance gate" || bad "an undeclared acceptance gate did not refuse the pass"
( cd "$F" && python3 scripts/workflow.py accept-gate P1 --waive >/dev/null 2>&1 ) && bad "accept-gate --waive should require --note" || ok "accept-gate --waive without --note is rejected"
# v34 closed --kind set, probed against the same throwaway engine. Creation is a hard
# error; validate() only WARNS, so the warning is asserted on stdout, never on the exit
# code -- that asymmetry is what lets an adopting repo's invented kinds survive an update.
( cd "$F" && python3 scripts/workflow.py new-slice --phase P1 --slice P1.S9 --name "typo" --kind cowork 2>&1 | grep -q "invalid slice kind: cowork" ) \
  && [ ! -d "$F/works/phases/active/P1/slices/P1.S9" ] \
  && ok "new-slice rejects an unknown --kind and creates nothing" || bad "new-slice accepted an unknown --kind"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P1 --slice P1.S9 --name "typo" --kind cowork 2>&1 | grep -q "co-work" ) \
  && ok "the unknown-kind error names the closed set" || bad "the unknown-kind error does not name the closed set"
# promote-deferred --create-phase creates the phase BEFORE the slice, so the kind must be
# rejected before that happens -- otherwise a typo leaves a half-created phase behind.
( cd "$F" && python3 scripts/workflow.py defer-job --title "kind probe" --reason r --trigger t --source manual >/dev/null 2>&1 ) || bad "defer-job probe failed"
( cd "$F" && python3 scripts/workflow.py promote-deferred D1 --phase P8 --slice P8.S1 --name x --kind cowork --create-phase 2>&1 | grep -q "invalid slice kind: cowork" ) \
  && [ ! -d "$F/works/phases/active/P8" ] \
  && ok "promote-deferred rejects an unknown --kind before --create-phase creates the phase" \
  || bad "promote-deferred left a half-created phase behind on an unknown --kind"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P1 --slice P1.S1 --name "design round" --kind co-work >/dev/null 2>&1 ) \
  && ok "new-slice accepts --kind co-work (absent from history, present in the set)" || bad "new-slice rejected --kind co-work"
# v36 research kind: in the closed set, named by the rejection message, and creatable.
( cd "$F" && python3 scripts/workflow.py new-slice --phase P1 --slice P1.S9 --name "typo" --kind cowork 2>&1 | grep -q "'research'" ) \
  && ok "the unknown-kind error names research in the closed set" || bad "the closed set does not contain research"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P1 --slice P1.S2 --name "learn first" --kind research --risk high >/dev/null 2>&1 ) \
  && grep -q '"kind": "research"' "$F/works/phases/active/P1/slices/P1.S2/slice.json" \
  && ok "new-slice accepts --kind research (v36, findings-only, always the high tier)" || bad "new-slice rejected --kind research"
# v38 deferred doc consolidation, probed once against the same throwaway engine: a passing
# review records the debt instead of paying it, and archiving is held until it is paid.
( cd "$F" && python3 scripts/workflow.py new-phase --phase P2 --name "Docs debt probe" --objective "probe deferral" >/dev/null 2>&1 ) || bad "v38 probe: new-phase P2 failed"
python3 - "$F/works/phases/active/P2/phase.md" <<'PY2'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text().replace("## Operator Questions", "- workflow.md: a durable change (P2.S1)\n\n## Operator Questions", 1))
PY2
( cd "$F" \
  && python3 scripts/workflow.py accept-gate P2 --waive --note "probe" >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status P2.DECOMP done >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status P2.REVIEW done >/dev/null 2>&1 \
  && python3 scripts/workflow.py review-phase P2 --verdict pass 2>&1 | grep -q "docs-consolidated P2" ) \
  && ok "a passing review defers doc consolidation and names docs-consolidated" || bad "the passing review did not defer doc consolidation"
grep -q '"consolidation": "pending"' "$F/works/phases/active/P2/phase.json" \
  && ok "the passing review stamps the phase's consolidation debt" || bad "no consolidation debt stamped"
# ...and the debt is visible, advisory-only: one greppable line in `next`, a warning in
# `validate` that still exits 0 (operator-paced staleness must never fail CI or block the loop).
( cd "$F" && python3 scripts/workflow.py next 2>&1 | grep -q "consolidation_owed=P2" ) \
  && ok "next names the phases owing doc consolidation" || bad "next did not surface the doc debt"
debt_out=$( cd "$F" && python3 scripts/workflow.py validate 2>&1 ); debt_rc=$?
printf '%s\n' "$debt_out" | grep -q "warning: consolidation_owed=P2" && [ "$debt_rc" -eq 0 ] \
  && ok "validate warns about the doc debt and still exits 0" || bad "validate did not warn (or errored) on the doc debt"
# ...and `docs-debt` is the docs phase's worklist: the owing phase, its notes, the docs those
# notes name and the paying command -- read-only, so the tree must be byte-identical afterwards.
debt_list=$( cd "$F" && python3 scripts/workflow.py docs-debt 2>&1 )
printf '%s\n' "$debt_list" | grep -q "docs_debt=P2" \
  && printf '%s\n' "$debt_list" | grep -q "a durable change (P2.S1)" \
  && printf '%s\n' "$debt_list" | grep -q "docs-consolidated P2" \
  && ok "docs-debt lists the owing phase, its '## Doc impact' notes and the paying command" \
  || bad "docs-debt did not print the owing phase's worklist"
before_debt=$( cd "$F" && find works docs -type f | sort | xargs cat | sha_stdin )
( cd "$F" && python3 scripts/workflow.py docs-debt >/dev/null 2>&1 )
after_debt=$( cd "$F" && find works docs -type f | sort | xargs cat | sha_stdin )
[ -n "$before_debt" ] && [ "$before_debt" = "$after_debt" ] \
  && ok "docs-debt writes nothing (the workspace tree is unchanged after it runs)" \
  || bad "docs-debt modified the workspace"
( cd "$F" && python3 scripts/workflow.py archive-phase P2 2>&1 | grep -q "docs not consolidated" ) \
  && ok "archiving is blocked while the doc debt stands" || bad "a phase owing docs archived anyway"
( cd "$F" && python3 scripts/workflow.py docs-consolidated P2 >/dev/null 2>&1 && python3 scripts/workflow.py archive-phase P2 >/dev/null 2>&1 ) \
  && [ ! -d "$F/works/phases/active/P2" ] \
  && ok "docs-consolidated pays the debt and unblocks archiving" || bad "docs-consolidated did not unblock archiving"
( cd "$F" && python3 scripts/workflow.py docs-debt 2>&1 | grep -q "docs_debt=none" ) \
  && ok "docs-debt is silent once nothing owes consolidation" || bad "docs-debt still reports debt on a clean tree"
# v38 oversized doc sections: advisory only, at both sites. A fresh install's seed docs are tiny,
# so the clean tree must be silent; a version carrying a >10 KB H2 section must be named (doc,
# heading, size) by `validate` WITHOUT changing its exit code, and by `doc-new-version` itself --
# the only place a split can actually land.
( cd "$F" && python3 scripts/workflow.py validate 2>&1 | grep -q "oversized_doc_sections=" ) \
  && bad "validate flagged an oversized doc section on a clean fresh install" \
  || ok "validate is silent about doc sections on a clean fresh install"
big_path=$( cd "$F" && python3 scripts/workflow.py doc-new-version --doc data --summary "oversized probe" --source manual 2>&1 | sed -n 's/^edit_path=//p' )
python3 - "$F/$big_path" <<'PY2'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text() + "\n## Oversized probe section\n\n" + ("filler line to push this section past the threshold\n" * 240))
PY2
( cd "$F" && python3 scripts/workflow.py rebuild-docs >/dev/null 2>&1 ) || bad "rebuild-docs failed after the oversized probe"
big_out=$( cd "$F" && python3 scripts/workflow.py validate 2>&1 ); big_rc=$?
printf '%s\n' "$big_out" | grep -q "warning: oversized_doc_sections=1" \
  && printf '%s\n' "$big_out" | grep -q "data.md '## Oversized probe section'" \
  && [ "$big_rc" -eq 0 ] \
  && ok "validate names an oversized doc section (doc, heading, size) and still exits 0" \
  || bad "validate did not warn exit-code-neutrally about an oversized doc section (rc=$big_rc)"
( cd "$F" && python3 scripts/workflow.py doc-new-version --doc data --summary "split probe" --source manual 2>&1 | grep -q "note: oversized_doc_sections=1" ) \
  && ok "doc-new-version repeats the oversized-section note where the split can land" \
  || bad "doc-new-version did not flag the oversized section it is about to hand over for editing"
python3 - "$F/works/phases/active/P1/slices/P1.S1/slice.json" <<'PY2'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d["kind"] = "invented-by-an-adopter"
json.dump(d, open(p, "w"), indent=2)
PY2
kind_out=$( cd "$F" && python3 scripts/workflow.py validate 2>&1 ); kind_rc=$?
printf '%s\n' "$kind_out" | grep -q "unknown kind 'invented-by-an-adopter'" && [ "$kind_rc" -eq 0 ] \
  && ok "validate warns on an unknown kind and still exits 0 (adopting history survives)" \
  || bad "validate did not warn exit-code-neutrally on an unknown kind (rc=$kind_rc)"
python3 - "$F/works/phases/active/P1/slices/P1.S1/slice.json" <<'PY2'
import json, sys
p = sys.argv[1]
d = json.load(open(p)); d["kind"] = "co-work"
json.dump(d, open(p, "w"), indent=2)
PY2
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
works/templates/phase.md
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
echo "== Test 9: v35 phase notebook -- template seed, generated ## Slices block, finish-slice --outcome =="
# Runs against the fresh workspace from Test 5 ($F), which already carries the gate-probe P1.
sig() { python3 -c "import hashlib,os,sys;p=sys.argv[1];print(hashlib.sha256(open(p,'rb').read()).hexdigest(),os.stat(p).st_mtime_ns)" "$1"; }
PM="$F/works/phases/active/P2/phase.md"
( cd "$F" && python3 scripts/workflow.py new-phase --phase P2 --name "Notebook" --objective "notebook probe" >/dev/null 2>&1 )
grep -q '<!-- slices:begin -->' "$PM" && grep -q '<!-- slices:end -->' "$PM" && grep -q '^## Now$' "$PM" \
  && ok "new-phase seeds phase.md from the template (both markers + ## Now)" || bad "seeded phase.md is not the v35 shape"
grep -q '^| `P2.DECOMP` |' "$PM" && ok "new-phase renders the generated ## Slices block" || bad "## Slices block was not filled on phase creation"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P2 --slice P2.S1 --name "probe" >/dev/null 2>&1 )
out=$( cd "$F" && python3 scripts/workflow.py finish-slice P2.S1 --outcome "did X" 2>&1 )
grep -q '| did X |' "$PM" && ok "finish-slice --outcome lands in the slice's generated row" || bad "outcome missing from the ## Slices row -- $out"
out=$( cd "$F" && python3 scripts/workflow.py finish-slice P2.DECOMP 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^warning: no --outcome recorded for P2.DECOMP' \
  && ok "finish-slice without --outcome warns and still succeeds" || bad "omitted --outcome must warn, never fail (exit=$rc) -- $out"
before=$(sig "$PM"); ( cd "$F" && python3 scripts/workflow.py rebuild >/dev/null 2>&1 )
[ "$(sig "$PM")" = "$before" ] && ok "an unchanged phase.md is not rewritten by rebuild (no notebook churn)" || bad "rebuild rewrote an unchanged phase.md"
python3 - "$PM" <<'STRIP'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text("\n".join(l for l in p.read_text().split("\n") if "slices:begin" not in l and "slices:end" not in l))
STRIP
before=$(sig "$PM"); ( cd "$F" && python3 scripts/workflow.py rebuild >/dev/null 2>&1 )
[ "$(sig "$PM")" = "$before" ] && ok "a marker-less phase.md is left byte-identical (legacy no-op, no migration)" || bad "rebuild touched a marker-less phase.md"
if python3 - "$REPO_ROOT" <<'FALLBACK'
import ast, sys
from pathlib import Path

root = Path(sys.argv[1])
tree = ast.parse((root / "scripts/workflow.py").read_text())
fallback = next(n.value.value for n in ast.walk(tree) if isinstance(n, ast.Assign)
                and any(getattr(t, "id", "") == "PHASE_MD_TEMPLATE_FALLBACK" for t in n.targets))
assert fallback == (root / "works/templates/phase.md").read_text(), "fallback drifted from the shipped template"
FALLBACK
then ok "new_phase's embedded fallback is byte-identical to works/templates/phase.md"; else bad "PHASE_MD_TEMPLATE_FALLBACK drifted from works/templates/phase.md"; fi

# ---------------------------------------------------------------------------
echo "== Test 10: v35/v39 notebook guardrails -- budget warning, ## Doc Impact case drift, no dashboard timestamp churn =="
# Continues on $F (P2's phase.md lost its markers in Test 9; irrelevant here). v39's cap is
# bytes-only and generous (400 KB), so the filler is generated, never checked in: pad the
# notebook past it and drift the Doc impact heading in one edit.
python3 - "$PM" <<'PAD'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text() + "\n## Doc Impact\n\n" + "- filler\n" * 50_000)  # ~450 KB
PAD
out=$( cd "$F" && python3 scripts/workflow.py validate 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && ok "validate exits 0 with notebook warnings (warn, never error)" || bad "validate exited $rc on warnings -- $out"
printf '%s\n' "$out" | grep -q 'phase P2: phase.md is .* over the notebook budget' \
  && ok "an over-budget phase.md warns" || bad "no over-budget warning -- $out"
printf '%s\n' "$out" | grep -q 'has a `## Doc Impact` heading' \
  && ok "a case-drifted ## Doc Impact heading warns" || bad "no Doc-impact case-drift warning -- $out"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P2 --slice P2.S2 --name "budget probe" >/dev/null 2>&1 )
out=$( cd "$F" && python3 scripts/workflow.py finish-slice P2.S2 --outcome "probe" 2>&1 )
printf '%s\n' "$out" | grep -q '^phase.md: .* bytes (budget 409600 bytes)' && printf '%s\n' "$out" | grep -q 'OVER BUDGET' \
  && ok "finish-slice prints the notebook size and flags it over budget" || bad "finish-slice notebook size print missing -- $out"
grep -q 'Rebuilt at' "$F/works/backlog.md" "$F/works/deferred.md" \
  && bad "a markdown dashboard still carries a Rebuilt at timestamp" || ok "no Rebuilt at timestamp in either markdown dashboard"
# The churn this removes: repeated `next` calls must not dirty the two dashboards.
( cd "$F" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
    && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "smoke baseline" >/dev/null 2>&1 )
( cd "$F" && python3 scripts/workflow.py next >/dev/null 2>&1; python3 scripts/workflow.py next >/dev/null 2>&1 )
tracked=$( cd "$F" && git ls-files works/backlog.md works/deferred.md | wc -l | tr -d ' ' )
dirty=$( cd "$F" && git status --short -- works/backlog.md works/deferred.md )
[ "$tracked" = "2" ] && [ -z "$dirty" ] \
  && ok "two next calls leave the dashboards byte-identical (no timestamp churn)" || bad "next dirtied the dashboards (tracked=$tracked) -- $dirty"

# ---------------------------------------------------------------------------
echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL RETROFIT SMOKE TESTS PASSED"
  exit 0
else
  echo "$FAILS CHECK(S) FAILED"
  exit 1
fi
