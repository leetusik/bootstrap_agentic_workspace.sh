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
# the v39 doc-staleness invariants (the last-updated marker at write time, with and
# without git, and the STALE flag an owed '## Doc impact' note raises), the v41 review-boundary
# invariants (every review surface re-runs the checklist inside the phase's boundary, never whole,
# and phase-scope reads that boundary from git -- advisory without git), the v35 phase-notebook
# invariants (template seed, generated ## Slices block, finish-slice --outcome, the
# notebook budget/case-drift warnings and the timestamp-free dashboards), the v43
# worktree-on-request invariants (nothing enters a worktree unhinted or unasked; parallel-start
# on a dirty tree commits only the phase folder plus the regenerated works/ files and cuts a
# nested .claude/worktrees/ checkout hidden by the repo's info/exclude; parallel-skip and
# new-phase --on-main are no-ops that stamp nothing), the v47 design-contract invariants
# (design-check names a gap, an unnumbered card and a // or http:// reference; design-close's
# regroup rewrites line 1 only, keeps a pre-close snapshot and is idempotent; design-register
# writes only the env-overridden registry, never the operator's ~/.config; v48: design-check skips claude-design/,
# design-migrate moves all-or-nothing and a pre-v47 root is steered to it, design-register prints the deck hint), the v48 design-tool
# invariants (design-cowork carries both loops, drafter and claude-design, with P26's governance
# shared), and the v31 Codex-removal negatives. Re-runnable; self-cleaning.
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
assert len(skills) == 18, len(skills)

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
for required in ("`build-after`", "`design-only`", "`paired`", "## Design Style",
                 # v42: the mockup question beside the style. v43: creation says nothing about
                 # worktrees and only relays the hint -- it never pins and never starts one.
                 "Mockup: requested", "Mockup: on request", "will you sign on the cards",
                 "Say nothing about worktrees", "Relay that hint; never act on it",
                 "never ask for a worktree on a docs phase"):
    assert required in create_phase, required
# v47 (P26.S4): the mockup question's default closes the round on the drafted cards, not on a
# return from Claude Design. v48 (P27.S3): the design tool is asked in the same breath and recorded
# as a `Design tool:` line; the DesignSync loop stays out of the skill itself.
assert "literal approval when they return to the drafted cards" in create_phase
for required in ("Design tool:", "`claude-design`", "`drafter`", "reads as `drafter`"):
    assert required in create_phase, required
assert "DesignSync" not in create_phase

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
        "WAITING ON OPERATOR", "`kind: co-work`",
        "never pass `run_in_background: false`", "never glob `~/.claude/plans/`",
        "`plan only`", "accept-gate <P> --clear",
        # v34: the design slice runs inline -> dispatched -> inline, in one of three
        # named styles, and stops `pending` twice with different meanings.
        "`build-after`", "`design-only`",
        "`paired`", "PENDING #1", "PENDING #2", "## Design Style",
        # v47 (P26.S4): the drafting is dispatched to the design subagent, the mockup build is
        # the one span dispatched to a slice executor, the round's lifecycle and the operator's
        # words stay inline, and the round closes through the engine.
        "`design-drafter`", "mockup build is the one span dispatched to a slice executor",
        "lifecycle and the operator's words stay inline", "new visual direction",
        'design-close <round> --words "<their literal words>"', "design-close <round> --superseded",
        # P26.F1: the feedback branch writes the revision round's handoff (every addressed card
        # listed), re-dispatches the drafter and reads back before PENDING #1 -- as design-cowork says.
        "**write its handoff**", "**every card still carrying the slice's address**",
        "the new round inherits the addressed cards",
        # v48 (P27.S3): the design tool is read from `## Design Style`, and the claude-design
        # branch is compact: the DesignSync read-back is inline, the record lands under
        # claude-design/, and a round costs two commits without a mockup, four with one.
        "`Design tool:` under `## Design Style`", "an absent line reads as `drafter`",
        "**`claude-design`**", "**read back inline with `DesignSync`**",
        "`docs/reference/design/claude-design/rounds/<NN-slug>/`",
        "**two commits without a mockup, four with one**",
        # v42: the mockup is on request, the operator's return closes the round, the
        # phase gate follows the mockup with a fixed waive note.
        "PENDING #2 exists only when a mockup was requested",
        "Mockup: requested", "Mockup: on request",
        "design-only, no mockup: the operator signed the round on the card set",
        # v43: a phase runs on this checkout unless the operator asks for a worktree;
        # the do-* skills never start one on their own initiative, and a hint is relayed,
        # not acted on. Merged back locally; the branch review records its two gate
        # sections as tagged notes.
        "unless the operator asked for a worktree", "parallel-start <P>", "EnterWorktree",
        "`parallel-start` on your own initiative", "(gate section — written at merge)", "git merge --no-ff",
        # v35: just-in-time reads and the bounded notebook.
        "finish-slice <slice_id> --outcome", "bounded phase notebook",
        "verdict block", "just in time",
        # v36: the research kind routes high by KIND, and DECOMP2 is no longer a
        # design-only device -- it is also the sequel to a research slice.
        "that is what the `research` kind is for", "`--kind research --risk high`",
        "second origin", "`research` and review always",
    ):
        assert required in body, (name, required)
    # v42 negatives: the mandatory mockup, "not an approval" return, and the
    # opt-in framing of the phase branch are retired from both drivers.
    for gone in ("mechanical wait", "can no longer be waived", "suggestion, never a default",
                 "Four commits and two `pending` stops", "where opting the phase in was the ask",
                 # v47 (P26.S4): the DesignSync loop's push and manifest phrases stay out of both
                 # drivers. v48 (P27.S3): DesignSync and Claude Design come back beside claude-design.
                 "_ds_manifest", "never dispatched",
                 "four commits, two", "one dispatched span", "Push the branch", "push the branch",
                 # P26.F1: the elided feedback step (no revision handoff, no read-back) is retired.
                 "in the same slice, re-dispatch the drafter"):
        assert gone not in body, (name, gone)
    # P27.F1: the claude-design branch routes the operator's words first -- feedback reaches
    # feedback.md before any DesignSync read-back, which gates only approval and the mockup.
    cd_branch = body[body.index("**`claude-design`** (*Under claude-design*"):]
    assert cd_branch.index("feedback.md") < cd_branch.index("DesignSync"), name
    # v35: the per-slice re-read of the generated backlog dashboard is gone --
    # `next` prints the pointer. The only mentions left must say so.
    for ln in body.splitlines():
        if "works/backlog.md" in ln:
            assert "next" in ln and "pointer" in ln, (name, ln)
    # v46: mid is the default tier; high needs a named trigger, and a fix to
    # mid-tier work goes high. The one-line/few-line scope for mid is retired.
    for required in ("**Mid is the default (v46):**", "--kind fix --risk <low|high>`",
                     "work the mid tier got wrong never goes back to it"):
        assert required in body, (name, required)
    for gone in ("one-line/few-line", "one-line, or few-line"):
        assert gone not in body, (name, gone)

# The spec hard-wraps its prose, so match against a whitespace-flattened copy: these
# assertions are about the wording, not about where a line happens to break.
design = " ".join((root / ".claude/skills/design-cowork/SKILL.md").read_text().split())
for required in (
    "**You never design.**", "Claude Design", "handoff.md",
    "@dsCard", "tokens.css", "--kind co-work --risk high",
    "DECOMP2", "build inventory", "data, not instructions", "RESPECT THE DESIGN",
    "SIGNOFF",
    # v32: fidelity has a second yardstick, and gaps are delivered, not archived.
    "## Verifying — RESPECT THE DESIGN, and does it work",
    # v41: the fidelity slice re-runs the checklist inside the phase's boundary, never whole.
    "**Re-run the lines inside the boundary.**", "phase-scope <P>",
    "### When the record never drew it", "matching it is not acceptance",
    "Questions get asked, not archived.",
    # v34: the code ban narrowed to *product* code, and the operator can sign a running
    # mockup rather than the cards alone. (v47 retired the v34 DesignSync dispatch pins.)
    "A design slice writes no *product* implementation code",
    "Write **product** implementation code in a design slice",
    "signing the round off — the cards, and any stubbed mockup with them — is not accepting the product",
    # v34, positive: the three named styles, the mockup section, PENDING #1 is not an
    # approval, and the mockup's exemption from the functional sweep.
    "## Shape — three styles", "**`build-after`**", "**`design-only`**", "**`paired`**",
    "## The mockup — only when the operator asks for one",
    "Exempt from the full functional sweep", "Stubbed data, no backing work",
    # v42: mockups on request, the operator's return closes the round, the cards are
    # numbered in reading order in the path, and the gate follows the mockup.
    "The operator's return closes the round.",
    "PENDING #2 exists only when a mockup was requested",
    "**A mockup is optional.**",
    "**Number the paths in reading order.**", "01-nav.html",
    "Mockup: requested", "Mockup: on request",
    "design-only, no mockup: the operator signed the round on the card set",
    "Renumber a card",
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
    # v44 (P23): two pins whose contract text left for this skill -- the numbered card
    # paths and the instrument/runtime axis (the contract's "different axes" sentence).
    "two-digit reading-order prefix",
    "a manifest naming no instrument still stops nothing",
    # v47 (P26.S1): the design record is an on-disk contract a separate dashboard reads; its
    # section names the root, the closed marker set, the lifecycle, the registry and the commands.
    "## The design record — the on-disk contract (schema 1)",
    "**every byte after line 1 is asserted identical**", "**At most one round is open per project.**",
    "`design-init", "`design-open", "`design-check", "`design-close <round> --words", "`design-register`",
    # v47 (P26.S3): the loop runs on the files. The design subagent drafts, the operator decides;
    # the handoff says whether the round sets a new visual direction (the drafter's one licence for
    # frontend-design); the read-back runs design-check itself; only literal words sign, feedback
    # supersedes, and the round's lifecycle stays inline while the drafting is dispatched.
    "**The design subagent drafts, the operator decides.**", "subagent_type: design-drafter",
    "`new visual direction: yes` or `no`",
    "**The one exception:** `design-drafter` loads `frontend-design` on a round whose handoff says `new visual direction: yes`, and only there.",
    "**Never rest on the drafter's own `design_check` line.**",
    "SIGNOFF is taken on the operator's **literal** words",
    "`python3 scripts/workflow.py design-close <round> --superseded`",
    'design-close <round> --words "<their literal words>"',
    "**The mockup build is the one span dispatched to a slice executor:**",
    "the round's lifecycle and the operator's words stay inline",
    "### Importing a Claude Design bundle (optional)",
    # v48 (P27.S2): the bundle import is a drafter-mode input, and only the drafter loop is account-free.
    "**The drafter loop never requires a claude.ai account and does not use `DesignSync`**",
    "a design slice authorizes no `git push`",
    # v48 (P27.S2): the design tool is a per-phase choice read from `## Design Style` -- `drafter`
    # (P26's loop) or `claude-design` (the pre-P26 loop, restored) -- and `drafter` when the line is
    # absent. The claude-design record lives under claude-design/, which design-* and design-deck skip.
    "## Design tool — drafter or claude-design", "Design tool: drafter | claude-design",
    "**An absent line reads as `drafter`**", "**design-deck shows `drafter` rounds only.**",
    "**Governance is shared.**", "docs/reference/design/claude-design/",
    "## The claude-design record — the original layout", "**`claude-design/` is outside schema 1.**",
    "python3 scripts/workflow.py design-migrate --apply", "| `design-migrate [--apply]` |",
    "### Under drafter", "### Under claude-design", "**two without a mockup, four with one**",
    # ... and the restored loop's own mechanics come back, each labelled with its tool (v47's absence
    # pins for these phrases are swapped for presence pins).
    "**Claude Design reads the real repo itself**", "**Connect GitHub**", "The Design System pane",
    "`_ds_manifest.json`", "**DesignSync is main-thread only.**", "**the DesignSync work is never dispatched**",
    "**Read back with the `DesignSync` tool**", "`list_files` → `get_file` each card",
    "**`finalize_plan`**", "`write_files`", "**Target the project by id, never by name** — `get_project` to verify",
    "`register_assets`", "**`/design-sync`**", "**the cards appear in the pane**",
    "**Push the branch** so Claude Design reads current code",
    "**claude-design only:** the pane's own grammar, which never overrides schema 1",
):
    assert required in design, required
# v48 (P27.S2): where the restored loop and P26's disagreed, P26's governance won -- the build slices
# are cut once the design is *signed*, revisions are superseding rounds in the same slice (not one
# co-work slice per round), the mockup route goes into phase.md and SIGNOFF.md (not "the round's
# record"), and the design root is fixed (no repo-owned design/ tree).
for gone in ("cuts the build slices once the design has landed", "one `co-work` slice each",
             "in the round's record *and* in `phase.md`", "under its own `design/` tree instead",
             "**The workspace never requires a claude.ai account"):
    assert gone not in design, gone
# v47 (P26.S3): the frontmatter. The skill still auto-fires on the same trigger, says who drafts and
# who decides, and keeps no unquoted ": " in its description. v48 (P27.S2): it asks for the DesignSync
# tool again (the claude-design loop's read-back and regroup) and names both design partners.
raw_design = (root / ".claude/skills/design-cowork/SKILL.md").read_text()
front = raw_design.split("---\n", 2)[1]
allowed = next(ln for ln in front.splitlines() if ln.startswith("allowed-tools:"))
assert "DesignSync" in allowed and "Agent" in allowed, allowed
desc = next(ln for ln in front.splitlines() if ln.startswith("description:"))[len("description: "):]
assert ": " not in desc, desc
for required in ("the design subagent drafts, the operator decides",
                 "the operator designs in Claude Design", "claude-design", "DesignSync",
                 "Use when a phase or slice touches a design system, a redesign, mockups"):
    assert required in desc, required
assert "Claude Design + the operator" not in desc, desc
# v47: the contract section and the engine move together -- the root, the registry variable and
# the registry's default path the skill states are the engine's own constants. v48 (P27.S1/S2): so
# are the claude-design record's folder name and the design-deck URL variable.
import re
workflow_src = (root / "scripts/workflow.py").read_text()
for const in ("DESIGN_ROOT_REL", "DESIGN_REGISTRY_ENV", "DESIGN_REGISTRY_DEFAULT",
              "DESIGN_LEGACY_DIR", "DESIGN_DECK_URL_ENV"):
    value = re.search(r'^' + const + r' = "([^"]+)"$', workflow_src, re.M).group(1)
    assert value in design, (const, value)
# P26.F2: the Self-contained bullet (and the drafter's mirror of it) names every reference prefix
# design-check allows -- `#`, `data:`, `https:` -- read from DESIGN_ALLOWED_REFS so text and engine
# cannot drift; `tokens.css` takes the same set without the ../tokens.css exception.
refs = re.search(r'^DESIGN_ALLOWED_REFS = \(([^)]*)\)$', workflow_src, re.M).group(1)
refs = [r.strip().strip('"') for r in refs.split(",") if r.strip()]
assert refs and all(refs), refs
bullet = design.split("- **Self-contained.**", 1)[1].split(" - **", 1)[0]
drafter_rule = " ".join((root / ".claude/agents/design-drafter.md").read_text().split())
drafter_rule = drafter_rule.split("**Keep every card self-contained.**", 1)[1].split(" 3. **", 1)[0]
for text in (bullet, drafter_rule):
    for ref in refs + ["../tokens.css"]:
        assert "`" + ref.rstrip("/") + "`" in text, (ref, text)
    assert "`#` fragments included, without the `../tokens.css` exception" in text, text
    assert "The only relative reference allowed is `../tokens.css`" not in text, text
assert "A card references nothing relative except `../tokens.css`. " not in design
# P26.F1: the drafter's frontend-design licence is the handoff's `new visual direction` line, the
# operator's call; a missing line is an open question, and the drafter never infers the licence.
drafter = " ".join((root / ".claude/agents/design-drafter.md").read_text().split())
for required in ("the `new visual direction: yes` or `no` line", "your **only** licence to load it",
                 "If the line is missing, do not load it, and name the missing line in `open_questions`.",
                 "You never infer the licence yourself"):
    assert required in drafter, required
assert "**only** on a round that sets a new visual direction" not in drafter
# v37 negatives: the MCP-first prescription is retired -- no config block to copy,
# no surface preference, and no "Playwright-style automation" framing anywhere.
for gone in ('{"mcpServers"', "Prefer the **MCP** surface", "MCP first",
             "scripted Playwright-style automation", "scripted assertion suite",
             # v42 negatives: the mandatory mockup and the "not an approval" return.
             "Only PENDING #2 is an approval.", "mechanical wait", "SIGNOFF moves to the mockup gate",
             "cut the slice into four", "can no longer be waived",
             "the design in the project's own language",
             # v44: copied from the contract list, now that the Aside rule lives here.
             "runs through Aside, not a script"):
    # (v47's absence pins for the Claude Design + DesignSync loop were retired in v48 (P27.S2): that
    # loop is the `claude-design` tool now, and its phrases are presence pins above.)
    assert gone not in design, gone

# v44 (P23): the worktree rules left the contract for the skill that runs them, so their
# pins live here now, whitespace-flattened like design-cowork's: rule 1 is "only when
# asked", rule 8 retires the v42 pins, a hint is relayed and never acted on, and a closed
# gate is never merged past. D-3: `parallel-start` itself runs only on the operator's word.
parallel = " ".join((root / ".claude/skills/parallel-phase/SKILL.md").read_text().split())
for required in ("Worktree rules", "**When — only when asked**", "retired no-ops",
                 "Relay a hint to the operator; never act on it.",
                 "Never merge a parallel phase whose `parallel-gate` is closed",
                 "the do-* skills relay it and run nothing"):
    assert required in parallel, required
# v43 negatives copied from the contract list (the worktree-by-default framing), and the
# v42 leftover that had the do-* skills start a worktree whenever `next` printed the hint.
for gone in ("runs in its own worktree by default", "enters its worktree at **first execution**",
             "the do-* skills do this for you"):
    assert gone not in parallel, gone

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
                 "never the operator's signed-in one",
                 # v41: the review reviews the boundary of the phase, never the whole system --
                 # phase-scope is its input, and stage 4 re-runs the checklist inside it.
                 "## The boundary", "phase-scope <P>",
                 # v42: a branch review records its two gate sections as tagged notes, and
                 # the mockup qualifier applies only where the operator asked for one.
                 "(gate section — written at merge)", "a phase in which the operator asked for one",
                 "Re-run the checklist lines inside the boundary",
                 "an operator-created QA phase, never by a review"):
    assert required in review, required
for gone in ("MCP surface first", "scripted Playwright-style automation",
             # the default is never moved with `aside account use`; the flag is
             # passed per invocation.
             "aside account use",
             # v41: the whole-list re-run is retired from the review (the last phrase is
             # copied from the contract list in v44).
             "not just this phase's lines", "Re-run the whole smoke list",
             "re-runs the whole cumulative"):
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
# v41: the seed says the list is re-run inside the phase's boundary, never whole by a review.
assert "phase-scope <P>" in qa and "re-runs the whole list" not in qa

bodies = {}
for tier in ("mid", "high"):
    body = (root / f".claude/agents/slice-executor-{tier}.md").read_text()
    assert "commit or push (no `git commit`, `git add`, `git push`)" in body, tier
    for gone in ("Codex", ".agents/", ".codex/", "AGENTS.md"):
        assert gone not in body, (tier, gone)
    # v32: the design gate (D2), the acceptance-gate stages, and the walkthrough
    # return field are word-for-word in BOTH tiers, not high only.
    # v47 (P26.S4): who drafts, and what the mockup span reads.
    for required in ("the design subagent (`design-drafter`) drafts a round's cards, and the operator decides",
                     "the one span of that slice dispatched to a slice executor",
                     "its record on disk"):
        assert required in body, (tier, required)
    # v48 (P27.S2): the claude-design tool's words may come back into the bodies, but only beside
    # that tool's name -- the drafter loop's text stays DesignSync-free.
    for gated in ("DesignSync", "never dispatched, because you have no", "landed record"):
        assert gated not in body or "claude-design" in body, (tier, gated)
    assert "return `needs_operator`" in body, tier
    # v34: the mockup span is dispatchable and its rules ship in BOTH tiers.
    for required in (
        "The mockup span of a `co-work` (design) slice",
        "Stubbed data, no backing work",
        "exempt from the full functional sweep",
        "*product* implementation work",
        "`build-after`", "`design-only`", "`paired`",
        # v42: the mockup span exists only on request, and a branch review records
        # its two gate sections as tagged notes.
        "exists only when the operator asked for a mockup", "(gate section — written at merge)",
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
        # v44: two rules moved here from the contract -- the docs slice's
        # doc-new-version carve-out (OQ1, operator-approved) and the fractional
        # `--order` / advisory `depends_on` facts a DECOMP executor needs.
        "**The `docs` slice's carve-out:**",
        "a fractional `--order` (e.g. `4.5`) inserts a slice between two neighbors",
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
        # v41: the boundary rule and its phase-scope input are in BOTH bodies word for word.
        "The review reviews the boundary of the phase, not the whole system",
        "phase-scope <P>", "inside the phase's boundary",
    ):
        assert required in body, (tier, required)
    for gone in ("not just this phase's lines", "re-run the **whole**"):
        assert gone not in body, (tier, gone)
    never = [ln for ln in body.splitlines() if "run workflow state-transition commands" in ln]
    assert len(never) == 1 and "`accept-gate`" in never[0] and "`defer-job`" in never[0], tier
    # v46: mid is the default tier, escalates on named reasons (never for real code
    # or several files), and every verdict names its tier; mid gets the web tools.
    for required in ("the default tier, where most slices land", "**two strikes**",
                     "- `tier`: `mid` | `high`", "work the mid tier got wrong never goes back to it"):
        assert required in body, (tier, required)
    for gone in ("the light tier", "essentially all code writing"):
        assert gone not in body, (tier, gone)
    assert "tools: Read, Edit, Write, Glob, Grep, Bash, WebSearch, WebFetch\n" in body, tier
    bodies[tier] = body.split("---\n", 2)[2]
# The tiers differ in frontmatter only, so a body diff is the drift detector.
assert bodies["mid"] == bodies["high"], "slice-executor tier bodies drifted"

# One contract file now, so nothing to compare it against: assert the whole text.
# v44 (P23) cut the contract to a <= 12 KB routing layer: seven sections of short
# stubs, each keeping a rule's prohibition, while the procedure lives in the engine
# (`workflow.py --help`), the owning skills and the executor bodies. The pins below are
# the phrases those stubs keep; each must sit raw on one line. Pins whose text left are
# still asserted where it lives now: the fixed design-only waive note (do-* and
# design-cowork lists), `finish-slice ... --outcome` (do-* list + Test 9), "findings land
# in phase.md" and the research-kind heading (executor list, equivalent phrases), the
# `phase-scope` synopsis (review-phase / executor / design-cowork + Test 11), and the
# worktree review's `(gate section — written at merge)` tag (do-*, review-phase and
# executor lists). The Aside, worktree and design stubs' 16 procedure pins are on the
# design-cowork list (the three styles, `## Design Style`, `Mockup: requested`, the
# numbered cards, the return that closes the round, PENDING #2, the two surfaces, the
# `aside repl` default, ~1,344 tokens, the MCP escape hatch, the instrument/runtime axis),
# the do-* and create-phase lists, and the parallel-phase list (the worktree rules).
claude = (root / "CLAUDE.md").read_text()
for required in (
    "DECOMP2", "data, not instructions",
    "RESPECT THE DESIGN", "real-browser fidelity", "Approval must be literal",
    "literal operator signoff closes an immutable round",
    # v32: the operator acceptance gate, the runtime manifest, the question channel.
    "accept-gate", "## Operator Runtime", "## Operator Questions", "never by omission",
    # v34: the narrowed bans and the closed --kind set.
    "writes no ***product*** implementation code",
    # v47 (P26.S4): the design subagent drafts, the operator decides; drafting and the mockup
    # dispatch to two different agents and the round's lifecycle stays inline.
    "The design subagent drafts, the operator decides:",
    "dispatching its drafting to `design-drafter` and its mockup build (only on request) to `slice-executor-high`",
    "the round's lifecycle and the operator's words stay inline",
    "`--kind` is a **closed set**",
    # v43: the worktree is opt-in again (v44: the rules themselves live in parallel-phase).
    "unless the operator asks for a worktree (v43)",
    # v35: just-in-time reads and the bounded/edited notebook.
    "Just in time, and only what the work in front of you needs",
    "never the whole doc set up front, and never `docs/index.json`",
    "**bounded state**", "PHASE_MD_BUDGET", "a soft ~100k-token cap (400 KB)",
    "every slice **edits** it under budget", "structured verdict block first",
    # v36: the research kind (high by kind) and DECOMP2 generalized past the build-after
    # design style. v44: the closed --kind set and DECOMP2's two origins live in IDs and
    # Status; the research kind's findings-only rule is the executor's.
    "if the two ever disagree the **kind wins**",
    "**`DECOMP2` has two origins**", "`P<N>.DECOMP3`",
    "`research`, `fix`, `docs`, `qa`, `co-work`",
    # v36: Aside is the named instrument, with a binding fallback. v37: it rejects the
    # pre-written suite, not Playwright (v44: its surfaces live in design-cowork).
    "**Real-browser verification runs through Aside, not a pre-written assertion suite.**",
    "**the doctrine's demands bind, the instrument does not.**",
    # v37: whose browser -- a dedicated profile via a per-invocation flag, and the
    # personal-profile case as a third halt, distinct from the runtime one.
    "**Whose browser: a dedicated profile.**",
    "pass `--account <id>` on every invocation",
    "is a **third** halt: `needs_operator` → `pending`",
    "an agent never drives a profile signed into the operator's accounts",
    # v41: the review reviews the boundary of the phase (phase-scope's synopsis left
    # with Workflow Commands in v44).
    "**The review reviews the boundary of the phase, not the whole system:**",
    # v46: mid is the default tier, and a retry never returns to mid.
    "**mid the default**", "never returns to mid",
    "QA-sweep route",
):
    assert required in claude, required
# v37 negatives: the MCP-first prescription and the Playwright framing are retired
# from the contract too -- the fact survives only where it explains the escape hatch.
# v41 negative: the whole-list re-run is retired from the contract.
for gone in ("Prefer the **MCP** surface", "scripted Playwright-style automation",
             "runs through Aside, not a script", "re-runs the whole cumulative",
             # v42 negatives: the mandatory mockup and the "not an approval" return are
             # retired from the contract. (v42 also retired parallel mode's opt-in framing;
             # v43 deliberately restored it, so those two negatives are gone with it --
             # the positive v43 assertions above carry that invariant now.)
             "only PENDING #2 is an approval", "mechanical wait", "can no longer be waived",
             # v43 negatives: the worktree-by-default framing is retired from the contract.
             "runs in its own worktree by default", "enters its worktree at **first execution**",
             # v47 (P26.S4): the DesignSync dispatch wording is gone from the contract.
             # v48 (P27.S3): Claude Design + DesignSync are back as the claude-design tool's
             # partner, so only the old dispatch phrases stay out.
             "never dispatched", "one dispatched span"):
    assert gone not in claude, gone
assert "`claude-design`" in claude and "the operator designing in Claude Design" in claude
# v47 (P26.S4): the installer's closing banner names the file loop, the drafter and the register hook.
banner = next(ln for ln in (root / "installer/main.py").read_text().splitlines() if "Visual design:" in ln)
for required in ("design-drafter", "docs/reference/design/", "design-register"):
    assert required in banner, required
for required in ("claude-design", "drafter"):
    assert required in banner, required
assert "DesignSync" not in banner
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
then ok "18 Claude skills and their invocation metadata; the prose invariants of the do-*, create-phase, design-cowork (both design tools, styles, mockups on request, numbered cards, Aside surfaces), parallel-phase (worktree only when asked, hints relayed) and review-phase skills and of both executor bodies; the v44 contract's never-stubs (acceptance gate, runtime, Aside dedicated profile, design, worktree, review boundary); the seed docs; and the v31 Codex-removal negatives"; else bad "Claude skill inventory or metadata, a do-*/create-phase/design-cowork/parallel-phase/review-phase prose invariant, an executor-body invariant, a contract never-stub, a seed-doc invariant, or a Codex-removal negative failed"; fi

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
[ "$(find "$R/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "18" ] \
  && ok "retrofit installs the 18-skill Claude inventory" || bad "retrofit skill inventory incomplete"
grep -q 'design subagent drafts, the operator decides' "$R/CLAUDE.workspace.md" && grep -q 'writes no \*\*\*product\*\*\* implementation code' "$R/CLAUDE.workspace.md" \
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
[ "$(find "$F/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "18" ] \
  && ok "fresh install has the 18 Claude skills" || bad "fresh skill inventory incomplete"
[ ! -f "$F/AGENTS.md" ] && [ ! -d "$F/.agents" ] && [ ! -d "$F/.codex" ] \
  && ok "fresh install is Codex-free (no AGENTS.md, no .agents/, no .codex/)" || bad "fresh install still ships Codex machinery"
[ -f "$F/.claude/agents/slice-executor-mid.md" ] && [ -f "$F/.claude/agents/slice-executor-high.md" ] && ok "fresh install ships the 2 Claude slice-executor tiers" || bad "fresh install missing Claude slice-executor tier(s)"
grep -q '^model: sonnet$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-mid.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor-high.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "fresh install follows seeded flex mode: sonnet@xhigh / opus@xhigh" || bad "fresh flex tiers wrong"
# P26.S2: the design subagent ships with the Skill tool (frontend-design) and never DesignSync.
[ -f "$F/.claude/agents/design-drafter.md" ] && grep -Eq '^tools: (.*, )?Skill(,.*)?$' "$F/.claude/agents/design-drafter.md" \
  && ! grep -q '^tools: .*DesignSync' "$F/.claude/agents/design-drafter.md" \
  && ok "fresh install ships the design-drafter subagent (Skill in tools, no DesignSync)" || bad "fresh install design-drafter missing, lacks Skill, or carries DesignSync"
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
p.write_text(p.read_text().replace("## Operator Questions", "- workflow.md: a durable change (P2.S1)\n- architecture.md: a durable change to architecture (P2.S2)\n\n## Operator Questions", 1))
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
# v39 doc staleness (D14): the `docs` listing carries every doc's last-updated marker, and a doc
# named by an unconsolidated '## Doc impact' note is flagged STALE there and named in `validate`.
# Advisory only -- operator-paced consolidation is the design, so staleness must be loud, not fatal.
docs_out=$( cd "$F" && python3 scripts/workflow.py docs 2>&1 )
printf '%s\n' "$docs_out" | grep -qE "^  updated=[0-9]{4}-[0-9]{2}-[0-9]{2} source=[^ ]+ commit=" \
  && ok "docs prints a last-updated marker (date, source, commit) under each doc" \
  || bad "docs did not print the per-doc last-updated marker"
printf '%s\n' "$docs_out" | grep -q "STALE: 1 unconsolidated '## Doc impact' note(s) from P2" \
  && printf '%s\n' "$docs_out" | grep -q "stale_docs=architecture" \
  && ok "docs flags the doc an owed note names as STALE" || bad "docs did not flag the stale doc"
( cd "$F" && python3 scripts/workflow.py validate 2>&1 | grep -q "warning: stale_docs=architecture" ) \
  && ok "validate names the stale docs (warning, exit 0)" || bad "validate did not name the stale docs"
( cd "$F" && python3 scripts/workflow.py archive-phase P2 2>&1 | grep -q "docs not consolidated" ) \
  && ok "archiving is blocked while the doc debt stands" || bad "a phase owing docs archived anyway"
( cd "$F" && python3 scripts/workflow.py docs-consolidated P2 >/dev/null 2>&1 && python3 scripts/workflow.py archive-phase P2 >/dev/null 2>&1 ) \
  && [ ! -d "$F/works/phases/active/P2" ] \
  && ok "docs-consolidated pays the debt and unblocks archiving" || bad "docs-consolidated did not unblock archiving"
( cd "$F" && python3 scripts/workflow.py docs-debt 2>&1 | grep -q "docs_debt=none" ) \
  && ok "docs-debt is silent once nothing owes consolidation" || bad "docs-debt still reports debt on a clean tree"
( cd "$F" && python3 scripts/workflow.py docs 2>&1 | grep -q "STALE" ) \
  && bad "docs still flags a stale doc after the debt was paid" \
  || ok "paying the consolidation debt clears the STALE flag"
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
# v39 last-updated marker at write time: the HEAD sha lands in the version frontmatter (which
# rebuild-docs copies verbatim into docs/current) AND in the index entry. Needs a repo with a
# commit, so the fixture becomes one here; the later dashboard test re-inits it harmlessly.
( cd "$F" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
    && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "marker baseline" >/dev/null 2>&1 ) \
  || bad "v39 marker probe: could not make the fixture a git repo"
head_sha=$( cd "$F" && git rev-parse HEAD 2>/dev/null )
marker_path=$( cd "$F" && python3 scripts/workflow.py doc-new-version --doc security --summary "marker probe" --source manual 2>&1 | sed -n 's/^edit_path=//p' )
[ -n "$head_sha" ] && grep -q "^commit: $head_sha\$" "$F/$marker_path" \
  && grep -q "\"commit\": \"$head_sha\"" "$F/docs/index.json" \
  && grep -q "^commit: $head_sha\$" "$F/docs/current/security.md" \
  && ok "doc-new-version records the HEAD sha in the frontmatter, docs/current and the index entry" \
  || bad "doc-new-version did not record the commit sha"
# ...and where git cannot answer at all (no git on PATH), the version is still written: the sha is
# recorded as unknown/null and nothing raises.
nogit_py=$( command -v python3 )
nogit_path=$( cd "$F" && PATH="/var/empty" "$nogit_py" scripts/workflow.py doc-new-version --doc security --summary "no git probe" --source manual 2>&1 | sed -n 's/^edit_path=//p' )
[ -n "$nogit_path" ] && grep -q "^commit: unknown\$" "$F/$nogit_path" && grep -q "\"commit\": null" "$F/docs/index.json" \
  && ok "doc-new-version survives a checkout without git (commit unknown/null, never fatal)" \
  || bad "doc-new-version broke or recorded a sha where git was unavailable"
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
# v45: executor-mode reports the mode bare, and switches it + syncs the agent files in one step.
cp "$REPO_ROOT/executors.toml" "$F/executors.toml"
em_out=$( cd "$F" && python3 scripts/workflow.py executor-mode 2>&1 )
printf '%s\n' "$em_out" | grep -q '^mode: flex (executors.toml)$' && printf '%s\n' "$em_out" | grep -q '^overrides: none$' \
  && printf '%s\n' "$em_out" | grep -q '^agent files: in sync$' \
  && ok "executor-mode (bare) reports the seeded flex mode, no overrides, agent files in sync" || bad "executor-mode status wrong: $em_out"
( cd "$F" && python3 scripts/workflow.py executor-mode economy >/dev/null 2>&1 ) && grep -q '^mode = "economy"$' "$F/executors.toml" \
  && grep -q '^effort: high$' "$F/.claude/agents/slice-executor-mid.md" && grep -q '^effort: high$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "executor-mode economy rewrites the mode line and syncs both tiers in one step" || bad "executor-mode economy did not switch and sync"
# P26.S2: design-drafter follows the high tier (one knob), not a tier of its own.
hi_model=$(sed -n 's/^model: //p' "$F/.claude/agents/slice-executor-high.md"); hi_effort=$(sed -n 's/^effort: //p' "$F/.claude/agents/slice-executor-high.md")
[ -n "$hi_model" ] && [ "$(sed -n 's/^model: //p' "$F/.claude/agents/design-drafter.md")" = "$hi_model" ] \
  && [ "$(sed -n 's/^effort: //p' "$F/.claude/agents/design-drafter.md")" = "$hi_effort" ] && [ "$hi_effort" = "high" ] \
  && ok "sync-agents keeps design-drafter on the high tier's model and effort (economy: opus@high)" || bad "design-drafter did not follow the high tier through executor-mode economy"
( cd "$F" && python3 scripts/workflow.py executor-mode flex >/dev/null 2>&1 ) && cmp -s "$REPO_ROOT/executors.toml" "$F/executors.toml" \
  && grep -q '^effort: xhigh$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "executor-mode flex round-trips the seeded executors.toml byte-identically" || bad "executor-mode round trip changed executors.toml"
printf '[claude.high]\nmodel = "fable"\n' > "$F/executors.toml"
em_out=$( cd "$F" && python3 scripts/workflow.py executor-mode economy 2>&1 )
printf '%s\n' "$em_out" | grep -q 'overrides in executors.toml still win' && [ "$(head -1 "$F/executors.toml")" = 'mode = "economy"' ] \
  && grep -q '^model = "fable"$' "$F/executors.toml" && grep -q '^model: fable$' "$F/.claude/agents/slice-executor-high.md" \
  && ok "executor-mode inserts a missing mode line, keeps the overrides and notes they still win" || bad "executor-mode override handling wrong: $em_out"
rm -f "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py executor-mode flex >/dev/null 2>&1 ) && [ "$(cat "$F/executors.toml")" = 'mode = "flex"' ] \
  && ok "executor-mode creates a one-line executors.toml when there is none" || bad "executor-mode did not create executors.toml"
( cd "$F" && python3 scripts/workflow.py executor-mode cheap >/dev/null 2>&1 ) && bad "executor-mode should refuse an unknown preset" || ok "executor-mode refuses an unknown preset"
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
[ "$nskill" -eq 18 ] && ok "dual-apply covers all 18 skill bodies" || bad "expected 18 SKILL.md files to diff, found $nskill"
for rel in $skill_rels; do
  diff -q "$REPO_ROOT/$rel" "$F/$rel" >/dev/null \
    && ok "dual-apply: $rel" \
    || bad "DRIFT: $rel differs from the bootstrap-embedded copy"
done
DUAL_FIXED=".claude/agents/slice-executor-mid.md
.claude/agents/slice-executor-high.md
.claude/agents/design-drafter.md
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
echo "== Test 7: the committed installer is in sync with installer/ source, and its stdin program declares utf-8 =="
# The distributable bootstrap_agentic_workspace.sh is a build product assembled by
# installer/build.py from installer/ (live files + payloads). --check fails if the
# committed artifact drifts from source, closing the loop: live files <-> artifact.
if ( cd "$REPO_ROOT" && python3 installer/build.py --check >/dev/null 2>&1 ); then
  ok "installer/build.py --check: artifact matches installer/ source"
else
  bad "DRIFT: bootstrap_agentic_workspace.sh is stale -- run: python3 installer/build.py"
fi
# P27.F3: the stdin program must open with the PEP 263 utf-8 cookie; without it CPython 3.9 rejects
# the program when a multibyte character straddles a ~1 KB read chunk of a long payload line.
cookie_line=$(grep -A1 -Fx "python3 - <<'INSTALLER_PY'" "$BOOT" | sed -n 2p)
[ "$cookie_line" = "# -*- coding: utf-8 -*-" ] \
  && ok "the installer's stdin program starts with the utf-8 coding cookie" \
  || bad "the line after python3 - <<'INSTALLER_PY' is not '# -*- coding: utf-8 -*-' (got: $cookie_line)"

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
echo "== Test 11: v41 phase-scope -- the phase's boundary is read from git, advisory everywhere =="
# $F is a clean git repo at the "smoke baseline" commit. A phase created and committed, then one
# product file committed after it: the boundary is exactly that file, and neither works/ nor docs/.
( cd "$F" && python3 scripts/workflow.py new-phase --phase P3 --name "Scope probe" --objective "probe the boundary" >/dev/null 2>&1 \
    && git add -A >/dev/null 2>&1 && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "create P3" >/dev/null 2>&1 ) \
  || bad "phase-scope probe: could not create and commit P3"
p3_created=$( cd "$F" && git rev-parse HEAD 2>/dev/null )
mkdir -p "$F/src" && printf 'print("probe")\n' > "$F/src/probe.py"
( cd "$F" && git add -A >/dev/null 2>&1 && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "P3 product change" >/dev/null 2>&1 ) \
  || bad "phase-scope probe: could not commit the product change"
scope_out=$( cd "$F" && python3 scripts/workflow.py phase-scope P3 2>&1 ); scope_rc=$?
[ "$scope_rc" -eq 0 ] && printf '%s\n' "$scope_out" | grep -q "^creation_commit=$p3_created" \
  && printf '%s\n' "$scope_out" | grep -q "^  A src/probe.py$" \
  && ! printf '%s\n' "$scope_out" | grep -qE "^  [AMDR] (works|docs)/" \
  && ok "phase-scope names the creation commit and the changed product file, and excludes works/ and docs/" \
  || bad "phase-scope did not print the boundary (rc=$scope_rc) -- $scope_out"
( cd "$F" && python3 scripts/workflow.py phase-scope P3 --json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["mode"] == "default" and d["creation_commit"] == sys.argv[1] and d["commits"] == 2, d
assert {"status": "A", "path": "src/probe.py"} in d["files"], d
' "$p3_created" ) \
  && ok "phase-scope --json parses and carries the same creation commit, mode and file list" \
  || bad "phase-scope --json is not the same answer as the text form"
nogit_scope=$( cd "$F" && PATH="/var/empty" "$nogit_py" scripts/workflow.py phase-scope P3 2>&1 ); nogit_rc=$?
[ "$nogit_rc" -eq 0 ] && printf '%s\n' "$nogit_scope" | grep -q "^phase-scope: no git history readable here" \
  && ok "phase-scope without git is advisory: the no-history line and exit 0" \
  || bad "phase-scope failed or was silent without git (rc=$nogit_rc) -- $nogit_scope"

# ---------------------------------------------------------------------------
echo "== Test 12: v43 worktree on request -- nothing unasked, parallel-start on a dirty tree, the nested worktree, the exclude line, the retired pins =="
newtmp W
sh "$BOOT" "$W" --name "Worktree" --summary "worktree probe" >/dev/null 2>&1 || bad "v43 probe: fresh install failed"
( cd "$W" && git init -q -b main . 2>/dev/null || git init -q . ; git config user.email smoke@example.invalid && git config user.name smoke \
    && git add -A >/dev/null 2>&1 && git commit -qm "worktree baseline" >/dev/null 2>&1 ) || bad "v43 probe: no baseline commit"
# (0) creating and selecting a phase says nothing about worktrees: the default stream is the default.
np_out=$( cd "$W" && python3 scripts/workflow.py new-phase --phase P1 --name "Worktree probe" --objective "probe the default" 2>&1 )
printf '%s\n' "$np_out" | grep -q "worktree\|parallel-start\|parallel-skip" \
  && bad "new-phase volunteered a worktree with nothing in flight -- $np_out" || ok "new-phase says nothing about worktrees when nothing is in flight"
( cd "$W" && python3 scripts/workflow.py next 2>&1 | grep -q "^hint:" ) \
  && bad "next hinted a worktree for a lone planned phase" || ok "next hints nothing for a lone planned phase"
# The hint fires only where a worktree pays: a planned phase queued behind an in_progress one.
( cd "$W" && python3 scripts/workflow.py set-phase-status P1 in_progress >/dev/null 2>&1 ) || bad "v43 probe: could not start P1"
np2=$( cd "$W" && python3 scripts/workflow.py new-phase --phase P2 --name "Second probe" --objective "queued behind" 2>&1 )
printf '%s\n' "$np2" | grep -q "^hint: P1 is in progress -- this phase can run in parallel" \
  && ok "new-phase suggests a worktree only while another phase is in flight" || bad "new-phase printed no queued-behind hint -- $np2"
( cd "$W" && python3 scripts/workflow.py next 2>&1 | grep -q "^hint: P2 is waiting behind P1 -- it can run in parallel" ) \
  && ok "next suggests a worktree for a planned phase queued behind a live one" || bad "next printed no waiting-behind hint"
( cd "$W" && python3 scripts/workflow.py set-phase-status P1 planned >/dev/null 2>&1 ) || bad "v43 probe: could not reset P1 to planned"
# P1 is NOT committed (create-phase makes no commit). Dirty one tracked file, stage another unrelated change.
printf '\n# smoke: dirty edit that must stay behind\n' >> "$W/executors.toml"
mkdir -p "$W/src" && printf 'staged\n' > "$W/src/staged.py" && ( cd "$W" && git add src/staged.py )
ps_out=$( cd "$W" && python3 scripts/workflow.py parallel-start P1 2>&1 ); ps_rc=$?
[ "$ps_rc" -eq 0 ] && ok "parallel-start runs on a dirty tree" || bad "parallel-start refused a dirty tree (rc=$ps_rc) -- $ps_out"
# (a) the stamp commit is exactly the phase folder + (a subset of) the five works files
stamp_files=$( cd "$W" && git show --name-only --format= HEAD )
if python3 - "$stamp_files" <<'PY'
import sys
files = set(sys.argv[1].split())
five = {"works/state.json", "works/index.json", "works/backlog.md", "works/deferred.md", "works/events.jsonl"}
phase = {f for f in files if f.startswith("works/phases/active/P1/")}
assert "works/phases/active/P1/phase.json" in phase and "works/index.json" in files, files
assert files == phase | (files & five), files
PY
then ok "the stamp commit holds only the phase folder and the regenerated works/ files"; else bad "the stamp commit swept in other paths -- $stamp_files"; fi
( cd "$W" && git diff --cached --name-only | grep -qx "src/staged.py" && git diff --name-only | grep -qx "executors.toml" ) \
  && ok "the unrelated staged change stays staged and the dirty edit stays dirty on the default checkout" || bad "parallel-start disturbed the operator's changes"
# (b) the worktree is at .claude/worktrees/P<N>-<slug> and registered
wt="$W/.claude/worktrees/P1-worktree_probe"
[ -d "$wt" ] && ( cd "$W" && git worktree list --porcelain | grep -q "/\.claude/worktrees/P1-worktree_probe$" ) \
  && ok "the worktree lives at .claude/worktrees/P1-worktree_probe and is in git worktree list" || bad "worktree missing or unregistered"
( cd "$wt" && [ "$(git rev-parse --abbrev-ref HEAD)" = "phase/P1-worktree_probe" ] && python3 scripts/workflow.py next 2>&1 | grep -q "^stream=phase/P1-worktree_probe" ) \
  && ok "inside the worktree next prints stream=phase/P1-worktree_probe" || bad "the worktree is not on the phase stream"
# (c) the dirty edit is absent in the worktree, present on main
if ! grep -q "smoke: dirty edit" "$wt/executors.toml" && [ ! -e "$wt/src/staged.py" ] && grep -q "smoke: dirty edit" "$W/executors.toml"; then
  ok "the worktree starts from the stamp commit; the dirty edit and the staged file stayed behind"; else bad "uncommitted changes leaked into the worktree"; fi
# (d) exclude line, once; main's status never lists the nested worktree
[ "$(grep -cx '\.claude/worktrees/' "$W/.git/info/exclude")" = "1" ] && ok ".git/info/exclude carries .claude/worktrees/ exactly once" || bad "exclude line missing or duplicated"
( cd "$W" && ! git status --porcelain --untracked-files=all | grep -q "\.claude/worktrees" ) && ok "git status on main does not list the nested worktree" || bad "nested worktree shows as untracked"
# (e) P2 was never asked into a worktree, so it just runs here -- and parallel-skip is a no-op
ps2=$( cd "$W" && python3 scripts/workflow.py parallel-skip P2 2>&1 ); ps2_rc=$?
if [ "$ps2_rc" -eq 0 ] && printf '%s\n' "$ps2" | grep -q "no-op since v43" \
    && ! grep -q '"execution"' "$W/works/phases/active/P2/phase.json"; then
  ok "parallel-skip is a no-op that stamps nothing"; else bad "parallel-skip still wrote a pin (rc=$ps2_rc) -- $ps2"; fi
nx=$( cd "$W" && python3 scripts/workflow.py next 2>&1 )
if printf '%s\n' "$nx" | grep -q "^current_phase=P2" && ! printf '%s\n' "$nx" | grep -q "^hint:"; then
  ok "an unasked phase stays on the default stream and gets no worktree hint"; else bad "the default-stream phase was skipped or hinted -- $nx"; fi
# (f) --on-main is retired the same way: accepted, explained, stamps nothing
if ( cd "$W" && python3 scripts/workflow.py new-phase --phase P3 --name "On main" --objective "no longer pins" --on-main 2>&1 | grep -q "no-op since v43" ) \
    && ! grep -q '"execution"' "$W/works/phases/active/P3/phase.json"; then
  ok "new-phase --on-main is a no-op that stamps nothing"; else bad "new-phase --on-main still pinned"; fi
# (g) v42's legacy pin is still honoured where it exists: validate accepts it, parallel-start refuses it
python3 - "$W/works/phases/active/P2/phase.json" <<'PIN' || bad "could not write the legacy pin"
import json, sys
data = json.load(open(sys.argv[1]))
data["execution"] = {"mode": "default"}
json.dump(data, open(sys.argv[1], "w"), indent=2, ensure_ascii=False)
PIN
( cd "$W" && python3 scripts/workflow.py validate >/dev/null 2>&1 ) && ok "validate still accepts v42's legacy execution.mode=default" || bad "validate rejects the legacy pin"
if ( cd "$W" && python3 scripts/workflow.py parallel-start P2 2>&1 | grep -q "legacy pin" ) \
    && ! ( cd "$W" && git rev-parse --verify --quiet refs/heads/phase/P2-second_probe >/dev/null 2>&1 ); then
  ok "parallel-start refuses a legacy-pinned phase and cuts no branch"; else bad "parallel-start did not refuse the legacy pin"; fi
# (h) the gate runs from inside the worktree, and a local --no-ff merge + teardown of a clean nested worktree needs no --force
( cd "$wt" && python3 scripts/workflow.py accept-gate P1 --waive --note "smoke" >/dev/null 2>&1 \
    && python3 scripts/workflow.py set-slice-status P1.DECOMP done >/dev/null 2>&1 \
    && python3 scripts/workflow.py review-phase P1 --verdict pass >/dev/null 2>&1 \
    && git add -A >/dev/null 2>&1 && git commit -qm "P1 done" >/dev/null 2>&1 ) || bad "v43 probe: could not finish P1 on the branch"
( cd "$wt" && python3 scripts/workflow.py parallel-gate P1 2>&1 | grep -q "^main_state_source=main (local default branch" ) \
  && ok "parallel-gate run from the worktree reads the default stream from the local default branch" || bad "parallel-gate from the worktree did not fall back to the local default branch"
( cd "$W" && git restore --staged src/staged.py && git add -A works >/dev/null 2>&1 && git commit -qm "workflow state" >/dev/null 2>&1 ) \
  || bad "v43 probe: could not commit the default-stream workflow state before merging"
# Both sides regenerated the dashboards, so the merge conflicts in generated files -- resolved the
# documented way: take either side, conclude, and let parallel-merge-finish regenerate them.
( cd "$W" && { git merge --no-ff -q phase/P1-worktree_probe -m "merge(P1): Worktree probe" >/dev/null 2>&1 \
      || { unmerged=$(git diff --name-only --diff-filter=U); [ -n "$unmerged" ] \
           && printf '%s\n' "$unmerged" | xargs git checkout --theirs -- >/dev/null 2>&1 \
           && git add -A works >/dev/null 2>&1 && git commit -qm "merge(P1): Worktree probe" >/dev/null 2>&1; }; } \
    && python3 scripts/workflow.py parallel-merge-finish >/dev/null 2>&1 \
    && git add -A works >/dev/null 2>&1 && { git diff --cached --quiet || git commit -qm "post-merge" >/dev/null 2>&1; } \
    && python3 scripts/workflow.py parallel-teardown P1 >/dev/null 2>&1 && [ ! -d "$wt" ] ) \
  && ok "a local --no-ff merge lands (generated-file conflicts taken either side, then regenerated) and parallel-teardown removes the clean nested worktree" \
  || bad "merge, merge-finish or teardown failed"

# ---------------------------------------------------------------------------
echo "== Test 13: v47 design contract -- design-check names a gap, an unnumbered card and a // or http:// reference, design-close regroups line 1 only (idempotent), design-register writes only the env-overridden registry; v48: claude-design/ is skipped, design-migrate, the deck hint =="
# Runs in the fresh workspace $F. Every design command gets a scratch HOME as well as a scratch
# $AGENTIC_DESIGN_REGISTRY, so even a broken override could never reach the operator's ~/.config.
newtmp DZ
DR="$F/docs/reference/design"
REAL_REG="$HOME/.config/agentic-workspace/design-registry.json"
real_reg_sig() { if [ -e "$REAL_REG" ]; then sig "$REAL_REG"; else echo absent; fi; }
real_before=$(real_reg_sig)
dw() { ( cd "$F" && HOME="$DZ/home" AGENTIC_DESIGN_REGISTRY="$DZ/reg/design-registry.json" python3 scripts/workflow.py "$@" ); }
tree_sig() { ( cd "$DR" && find . -type f | LC_ALL=C sort | while read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done ); }
{ dw design-init --id smoke-design --name "Smoke design" && dw design-open --slug signin --slice P9.S1; } >/dev/null 2>&1 \
  || bad "design probe: design-init / design-open failed"
python3 - "$DR" <<'CARDS' || bad "design probe: could not write the round"
import pathlib, sys
d = pathlib.Path(sys.argv[1])
(d / "cards").mkdir(exist_ok=True)
(d / "tokens.css").write_text(":root { --ink: #111; }\n")
(d / "rounds/01-signin/handoff.md").write_text("# handoff\n")
for name in ("01-colors", "02-type", "03-button"):
    (d / "cards" / f"{name}.html").write_text(
        '<!-- @dsCard group="⏳ P9.S1 · Components" viewport="480x200" -->\n'
        f'<link rel="stylesheet" href="../tokens.css">\n<p>{name}</p>\n'
        # the contract's allowed references besides ../tokens.css: an in-page fragment, data:, https
        '<a href="#top"><img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" alt=""></a>'
        '<a href="https://example.com/">more</a>\n', encoding="utf-8")
CARDS
# P26.F1: a protocol-relative and a plain-http reference break the contract's "absolute https" rule.
cp "$DR/cards/03-button.html" "$DZ/03-button.keep"
printf '<img src="//cdn.example.com/x.png"><link rel="stylesheet" href="http://x.example/y.css">\n' >> "$DR/cards/03-button.html"
mv "$DR/cards/02-type.html" "$DR/cards/type.html"
out=$(dw design-check 2>&1); rc=$?
mv "$DR/cards/type.html" "$DR/cards/02-type.html"
cp "$DZ/03-button.keep" "$DR/cards/03-button.html"
ok_out=$(dw design-check cards/01-colors.html cards/02-type.html cards/03-button.html 2>&1); ok_rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q 'gap in the card numbering: no card numbered 02' \
    && printf '%s\n' "$out" | grep -q 'cards/type.html: unnumbered card path' \
    && printf '%s\n' "$out" | grep -Fq "cards/03-button.html: references '//cdn.example.com/x.png' (protocol-relative" \
    && printf '%s\n' "$out" | grep -Fq "cards/03-button.html: references 'http://x.example/y.css' (plain http" \
    && [ "$ok_rc" -eq 0 ]; then
  ok "design-check names a gap, an unnumbered card, a // and an http:// reference (exit 1) and passes the numbered set with ../tokens.css, #, data: and https references"
else bad "design-check missed the gap, the unnumbered card, or a // / http:// reference, or failed the allowed set (rc=$rc, restored rc=$ok_rc) -- $out $ok_out"; fi
mkdir -p "$DZ/pre" && cp "$DR"/cards/*.html "$DZ/pre/" && printf 'Signed: "ship it"\n' > "$DR/rounds/01-signin/SIGNOFF.md"
dw design-close 01-signin --words "ship it" >/dev/null 2>&1 || bad "design probe: design-close failed"
if python3 - "$DR" "$DZ/pre" <<'REGROUP'
import json, pathlib, sys
d, pre = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for old in sorted(pre.iterdir()):
    new = (d / "cards" / old.name).read_bytes()
    before = old.read_bytes()
    assert new.split(b"\n", 1)[1] == before.split(b"\n", 1)[1], old.name  # every byte after line 1
    assert new.split(b"\n", 1)[0] == b'<!-- @dsCard group="Components" viewport="480x200" -->', old.name
    assert (d / "rounds/01-signin/cards" / old.name).read_bytes() == before, old.name  # the snapshot
rnd = json.loads((d / "rounds/01-signin/round.json").read_text())
assert rnd["status"] == "signed" and rnd["signoff_words"] == "ship it" and len(rnd["cards"]) == 3, rnd
REGROUP
then ok "design-close regroups line 1 only: the address comes off, every later byte is identical, the snapshot keeps the pre-close bytes"
else bad "design-close changed more than the group on line 1, or lost the snapshot"; fi
before=$(tree_sig); again=$(dw design-close 01-signin --words "ship it" 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$again" | grep -q 'already signed' && [ "$(tree_sig)" = "$before" ] \
  && ok "design-close is idempotent: a second run writes nothing" || bad "a second design-close was not a no-op (rc=$rc) -- $again"
dw design-register >/dev/null 2>&1 || bad "design probe: design-register failed"
REG="$DZ/reg/design-registry.json"
reg_before=$( [ -f "$REG" ] && sha "$REG" ); again=$(dw design-register 2>&1)
if python3 - "$REG" "$F" <<'REG_OK' && [ -n "$reg_before" ] && [ "$(sha "$REG")" = "$reg_before" ] \
    && printf '%s\n' "$again" | grep -q 'nothing written'; then
import json, os, sys
reg = json.load(open(sys.argv[1]))
assert reg["schema"] == 1 and [p["id"] for p in reg["projects"]] == ["smoke-design"], reg
entry = reg["projects"][0]
assert os.path.isabs(entry["repo"]) and os.path.isabs(entry["root"]), entry
assert os.path.samefile(entry["root"], os.path.join(sys.argv[2], "docs/reference/design")), entry
REG_OK
  ok "design-register writes absolute paths to the env-overridden registry, and a second run writes nothing"
else bad "design-register wrote the wrong entry or was not idempotent -- $again"; fi
# v48 (P27.S1): design-register ends with the design-deck hint -- the URL only from the env, never guessed.
out=$( cd "$F" && HOME="$DZ/home" AGENTIC_DESIGN_REGISTRY="$DZ/reg/design-registry.json" \
       AGENTIC_DESIGN_DECK_URL="http://100.64.0.1:8765/" DECK_PROJECTS_DIR="$DZ/home/projects" \
       python3 scripts/workflow.py design-register 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fqx 'design-deck reads this registry: http://100.64.0.1:8765/' \
  && printf '%s\n' "$out" | grep -q '^warning: this repo is outside .*, so design-deck will show it as unavailable$' \
  && ok "design-register prints the design-deck hint: the URL from \$AGENTIC_DESIGN_DECK_URL, and a warning for a repo outside the deck's projects folder" \
  || bad "design-register printed no deck URL or no outside-folder warning (rc=$rc) -- $out"
[ ! -e "$DZ/home/.config" ] && [ "$(real_reg_sig)" = "$real_before" ] \
  && ok "design-register touched neither the scratch HOME's ~/.config nor the operator's real registry" \
  || bad "design-register wrote outside \$AGENTIC_DESIGN_REGISTRY"
# v48 (P27.S1): the claude-design tool's records live in claude-design/, which the scan never reads.
mkdir -p "$DR/claude-design/grounding/previews" "$DR/claude-design/rounds/01-old"
printf '<p>preview</p>\n' > "$DR/claude-design/grounding/previews/x.html"
printf '# old handoff\n' > "$DR/claude-design/rounds/01-old/handoff.md"
out=$(dw design-check 2>&1); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s\n' "$out" | grep -q 'claude-design' \
  && ok "design-check skips claude-design/: neither its grounding HTML nor its legacy rounds are problems" \
  || bad "design-check read claude-design/ (rc=$rc) -- $out"
# With design.json present, design-migrate moves only the old record's parts and lists the rest.
mkdir -p "$DR/rounds/02-legacy" && printf '# legacy\n' > "$DR/rounds/02-legacy/handoff.md"
printf 'Signed: "old"\n' > "$DR/SIGNOFF.md" && printf 'notes\n' > "$DR/notes.txt"
out=$(dw design-migrate --apply 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ -f "$DR/claude-design/rounds/02-legacy/handoff.md" ] && [ -f "$DR/claude-design/SIGNOFF.md" ] \
  && [ ! -e "$DR/rounds/02-legacy" ] && [ ! -e "$DR/SIGNOFF.md" ] && [ -f "$DR/rounds/01-signin/round.json" ] && [ -f "$DR/notes.txt" ] \
  && printf '%s\n' "$out" | grep -Fq 'left in place docs/reference/design/notes.txt' && dw design-check >/dev/null 2>&1 \
  && ok "design-migrate beside design.json moves only a round without round.json and the root SIGNOFF.md, lists other files as left in place, and design-check passes after" \
  || bad "design-migrate beside design.json moved the wrong entries (rc=$rc) -- $out"
# A pre-v47 root (no design.json): every top-level entry moves, a dry run first, all-or-nothing.
MG="$DZ/legacy"; MD="$MG/docs/reference/design"
mkdir -p "$MG/scripts" "$MD/rounds/01-a" "$MD/grounding" && cp "$F/scripts/workflow.py" "$MG/scripts/"
printf '# handoff\n' > "$MD/rounds/01-a/handoff.md"; printf 'Signed: "go"\n' > "$MD/SIGNOFF.md"
printf '<p>g</p>\n' > "$MD/grounding/g.html"; printf '# the old record\n' > "$MD/README.md"
mw() { ( cd "$MG" && HOME="$DZ/home" python3 scripts/workflow.py "$@" ); }
mig_sig() { ( cd "$MD" && find . -type f | LC_ALL=C sort | while read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done ); }
# P27.F2: a pre-v47 root is steered to design-migrate -- design-init refuses and writes nothing (so the old
# tokens.css cannot silently become schema 1's), and design-check names design-migrate ahead of design-init.
legacy_before=$(mig_sig); init_out=$(mw design-init 2>&1); init_rc=$?; chk_out=$(mw design-check 2>&1); chk_rc=$?
if [ "$init_rc" -ne 0 ] && printf '%s\n' "$init_out" | grep -Fq 'design-migrate' && [ ! -e "$MD/design.json" ] \
    && [ "$chk_rc" -ne 0 ] && printf '%s\n' "$chk_out" | grep -Fq 'design.json missing; pre-v47 record: run python3 scripts/workflow.py design-migrate' \
    && [ "$(mig_sig)" = "$legacy_before" ]; then
  ok "a pre-v47 design root is steered to design-migrate: design-init refuses without writing, and design-check names design-migrate ahead of design-init"
else bad "a pre-v47 root was not steered to design-migrate (init rc=$init_rc, check rc=$chk_rc) -- $init_out $chk_out"; fi
out=$(mw design-migrate 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(mig_sig)" = "$legacy_before" ] && printf '%s\n' "$out" | grep -q 'dry run -- nothing moved' \
    && ( for e in README.md SIGNOFF.md grounding rounds; do printf '%s\n' "$out" \
           | grep -Fqx "design-migrate: would move docs/reference/design/$e -> docs/reference/design/claude-design/$e" || exit 1; done ); then
  ok "design-migrate is a dry run by default: it names every top-level entry of a design.json-less root and moves nothing"
else bad "design-migrate's dry run moved something or missed an entry (rc=$rc) -- $out"; fi
out=$(mw design-migrate --apply 2>&1); rc=$?; again=$(mw design-migrate --apply 2>&1); again_rc=$?
if [ "$rc" -eq 0 ] && [ "$(ls -A "$MD")" = "claude-design" ] \
    && [ "$(mig_sig)" = "$(printf '%s\n' "$legacy_before" | sed 's#^\./#./claude-design/#')" ] \
    && [ "$again_rc" -eq 0 ] && printf '%s\n' "$again" | grep -q 'nothing to migrate'; then
  ok "design-migrate --apply moves all four entries under claude-design/ byte-identical, and a second --apply has nothing to migrate"
else bad "design-migrate --apply lost, changed or left an entry, or was not idempotent (rc=$rc/$again_rc) -- $out $again"; fi
printf 'Signed again\n' > "$MD/SIGNOFF.md"; printf '# brief\n' > "$MD/BRIEF.md"
mkdir -p "$MD/rounds/02-b" && printf '{}\n' > "$MD/rounds/02-b/round.json"
conflict_before=$(mig_sig); out=$(mw design-migrate --apply 2>&1); rc=$?
[ "$rc" -ne 0 ] && [ "$(mig_sig)" = "$conflict_before" ] && printf '%s\n' "$out" | grep -Fq 'claude-design/SIGNOFF.md already exists' \
  && printf '%s\n' "$out" | grep -Fq 'schema-1 round(s) 02-b' \
  && ok "design-migrate refuses an existing destination and a round.json in a design.json-less root, naming both, and moves nothing (not even the free BRIEF.md)" \
  || bad "design-migrate moved something past a conflict, or did not name every conflict (rc=$rc) -- $out"

# ---------------------------------------------------------------------------
echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL RETROFIT SMOKE TESTS PASSED"
  exit 0
else
  echo "$FAILS CHECK(S) FAILED"
  exit 1
fi
