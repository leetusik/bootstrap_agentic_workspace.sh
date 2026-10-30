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
# contract, both agent bodies and both do-* skills), the real-browser instrument
# invariants (v36's doctrine, since P-zqhy on Claude in Chrome: the agent's dedicated
# Chrome profile selected with list_connected_browsers -> select_browser on its recorded
# deviceId, never a name label, before any other browser tool, a third halt, and a
# fallback the manifest chooses that excuses no check, in the contract, the executor
# body and the design/review skills),
# the v39 doc-staleness invariants (the last-updated marker at write time, with and
# without git, and the STALE flag an owed '## Doc impact' note raises), the v41 review-boundary
# invariants (every review surface re-runs the checklist inside the phase's boundary, never whole,
# and phase-scope reads that boundary from git -- advisory without git), the v35 phase-notebook
# invariants (template seed, generated ## Slices block, finish-slice --outcome, the
# notebook budget/case-drift warnings and the timestamp-free dashboards; v61: phase-section reads and writes
# one phase.md section, a 40 KB index budget naming the biggest sections; --entry K --replace writes one entry, and
# --to-topic moves entries verbatim to topics/ behind gist lines, its refusals writing nothing; per-section budgets
# and long entries named with a move command, 24 KB pages that never split an entry, a dangling pointer warning, and over 40 KB the required or advisory
# notebook_over_budget= step in next, the card and start-slice, silent under budget and for a done phase), the P41 run-phases invariants
# (a run's tokens resolve in order and a non-phase token refuses; a run passes a parked acceptance gate and
# halts at a pending slice while plain `next` still waits there), the P42 ready-set invariants (an undeclared phase
# keeps its plain pointer and prints no wave line; a declared slice is never ready before its dependency is done;
# a running barrier is never a wave slice, so a declared phase's open acceptance gate reads as a stop), the id
# invariants (new-phase, defer-job, promote-deferred and rotate's proposal mint P<n>-/D<n>-<tail> with the next number
# over every visible numbered id when no id is given, archived and promoted included; v73's P-/D- tokens and old P<n>
# stay valid; an archived id is spent; listings sort numbered ids by number then tokens, and rotate's all-numeric labels
# stay v72's; a number resolves when one phase holds it and is refused, listed, when two do; two branches mint the same
# number and merge clean), the v43
# worktree-on-request invariants (nothing enters a worktree unhinted or unasked; parallel-start
# on a dirty tree commits only the phase folder plus the regenerated works/ files and cuts a
# nested .claude/worktrees/ checkout hidden by the repo's info/exclude; parallel-skip and
# new-phase --on-main are no-ops that stamp nothing), the design-contract invariants on schema 2
# (P36.S3; P36.S5C: one open round per job, --new-job / --job, a per-round critique level; P46-nb: one
# connected job per co-work slice -- --new-job refused while another job of the slice has an open round, a
# legacy multi-job slice still valid, the size warning at 10 Pages / 30 boards, check=unlinked-page; design-check names a missing
# board, a missing support line, a .. reference and a title gap in a canvas tree; design-canvas,
# design-system and the read-only design-publish-plan (v60: the system copies only on a first publish or a
# changed pin, canvas.system optional); P36.S4: design-preview with no browser is an honest skip
# that writes nothing, with --click too (P36.S5A); v61 (P37.S6): with a browser, design-preview's machine
# checks on fixture boards (non-text-contrast, reflow, overprint, keyboard, the state bar, --strict, the
# .preview render and contact sheets); design-close snapshots byte-identical, signs the
# job and is idempotent; v61 (P37.S5): the publish's size manifest, design-readback (a listing names only what to
# fetch; --fetched diffs, --apply copies in), a generated SIGNOFF.md that needs a read-back, design-sign all or
# nothing, a superseding round's critique off, the absolute-path lint and the wave brief; design-migrate --to 2 moves a schema-1 record into schema1/ and a schema-1 root is
# steered to it; v48: design-check skips claude-design/, design-migrate moves all-or-nothing and a pre-v47
# root is steered to it; P36.S1: design-register is gone, an unknown command), the P36 design-tool invariants (design-cowork carries the drafter loop only, with a legacy
# rule for a `Design tool: claude-design` intent and a Legacy record note for claude-design/), the P28 nested-engine invariants (workflow/.agentic-nested.json: host anchors, host-side
# phase-scope, the paired worktree lifecycle, the convention gate, the agent rename map, a malformed marker is an
# error), the P28 nested-install invariants (--nested: a clean host status/HEAD/config, the clash rename,
# the workflow/ prefix, the contract import, the tracked-target refusal, --update --nested, the self-hiding
# skill dirs and the refusal when a host .gitignore re-includes a target), the P29 nested-by-default
# invariants (a bare install nests and git-inits a new dir, --update detects the layout, --at-root
# keeps the at-root path, a bare install over an at-root workspace refuses), the multi-repo host
# invariants (a fresh install over a folder of repos, per-repo phase-scope, a worktree set's start and
# safe teardown, the lossless --to-multi-repo conversion), the v61 skill
# directories (cores of 8 KB or less plus their reference files, on fresh, retrofit, --update and
# nested installs, a renamed skill included), and the v31 Codex-removal negatives. Re-runnable; self-cleaning.
#
# Usage:  bash tests/retrofit_smoke.sh
# Exit 0 if every check passes; non-zero otherwise.

set -u
export PYTHONDONTWRITEBYTECODE=1   # keep target repos free of __pycache__/

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT="$REPO_ROOT/bootstrap_agentic_workspace.sh"
SRC="$REPO_ROOT/payload"   # the shipped sources: emit path .x/... lives at $SRC/x/..., CLAUDE.md at $SRC/contract.md

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
# /explain is the knowledge plugin's: no install path touches or reports a path with an `explain` component.
# plant_old_explain writes the last shipped explain skill (1c5ea0e) when this clone has that history, else a
# marker copy; explain_sig is every such file under a tree with its hash (.git and workflow/ skipped).
plant_old_explain() { mkdir -p "$(dirname "$1")"; git -C "$REPO_ROOT" show 1c5ea0e:payload/claude/skills/explain/SKILL.md > "$1" 2>/dev/null \
  || printf -- '---\nname: explain\n---\nthe old workspace copy\n' > "$1"; }
explain_sig() { ( cd "$1" && find . \( -path ./.git -o -path ./workflow \) -prune -o -type f -print | grep -E '/explain(/|$)' | LC_ALL=C sort \
  | while read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done ); }

# P37.S1 (v61): the skills ship as whole directories. Checks an installed .claude/skills tree against
# the build's payload: every shipped skill file is there (byte-identical, or only present when
# `nested`, whose texts are rewritten), in its renamed dir where <shipped>=<installed> says so; every
# reference a core names exists and none is orphaned; and the shared do-* copies equal their source.
skill_tree_ok() {  # <skills dir> <exact|nested> [<shipped>=<installed> ...]
  python3 - "$REPO_ROOT" "$@" <<'PY'
import re, sys
from pathlib import Path
root, base, mode = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
renames = dict(a.split("=", 1) for a in sys.argv[4:])
sys.path.insert(0, str(root / "installer"))
from build import collect_live_payloads, SHARED_SKILL_FILES
live = collect_live_payloads()
def installed(key):
    _, _, name, inner = key.split("/", 3)
    return base / renames.get(name, name) / inner
names = set()  # the skills that ship reference files: their core names each one, and only those
for key, text in live.items():
    if key.startswith(".claude/skills/"):
        if "/reference/" in key:
            names.add(key.split("/")[2])
        assert installed(key).is_file(), installed(key)
        assert mode != "exact" or installed(key).read_text(encoding="utf-8") == text, installed(key)
for name in sorted(names):
    d = base / renames.get(name, name)
    named = set(re.findall(r"`reference/([\w.-]+\.md)`", (d / "SKILL.md").read_text(encoding="utf-8")))
    have = {p.name for p in (d / "reference").glob("*.md")}
    assert named == have, (d.name, sorted(named ^ have))
for dst, src in SHARED_SKILL_FILES.items():
    assert installed(dst).read_bytes() == installed(src).read_bytes(), dst
PY
}

command -v git >/dev/null 2>&1 || { echo "git is required to run this smoke test"; exit 2; }
[ -f "$BOOT" ] || { echo "installer not found: $BOOT"; exit 2; }

# ---------------------------------------------------------------------------
echo "== Test 0: the shipped Claude skill set is complete, the v32 operator gate is wired, and Codex stays gone =="
if python3 - "$REPO_ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
skills = {p.parent.name for p in (root / "payload/claude/skills").glob("*/SKILL.md")}
assert len(skills) == 18, len(skills)

# P37.S1 (v61): a skill ships as its whole directory, a core SKILL.md plus reference/*.md, and the
# do-* shared references fan out at build. Prose pins read the BUILT directory (core first, then its
# references), so a rule keeps its pin wherever in the skill it lives.
sys.path.insert(0, str(root / "installer"))
from build import collect_live_payloads, SHARED_SKILL_FILES
LIVE = collect_live_payloads()
def skill_dir_text(name):
    pre = f".claude/skills/{name}/"
    keys = sorted((k for k in LIVE if k.startswith(pre)), key=lambda k: (k != pre + "SKILL.md", k))
    return "\n".join(LIVE[k] for k in keys)
import re as _re
for name in ("design-cowork", "do-whole-phase", "do-next-slice"):
    core = (root / "payload/claude/skills" / name / "SKILL.md").read_bytes()
    assert len(core) <= 8192, (name, len(core))  # re-attached whole after a compaction
    named = set(_re.findall(r"`reference/([\w.-]+\.md)`", core.decode()))
    shipped = {k.rsplit("/", 1)[1] for k in LIVE if k.startswith(f".claude/skills/{name}/reference/")}
    assert named and named == shipped, (name, sorted(named ^ shipped))
for dst, src in SHARED_SKILL_FILES.items():
    assert LIVE[dst] == LIVE[src], dst
    assert not (root / "payload" / dst[1:]).exists(), ("a shared copy must not have a second source", dst)

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
    body = (root / "payload/claude/skills" / name / "SKILL.md").read_text()
    marker = "disable-model-invocation: true"
    assert (marker in body) == (name not in model_invocable), name
create_phase = (root / "payload/claude/skills/create-phase/SKILL.md").read_text()
assert "the agent when instructed" in create_phase
assert "Never on the agent's own initiative" in create_phase
assert "Invocation is not the gate; confirmation is." in create_phase
for required in ("`build-after`", "`design-only`", "`paired`", "## Design Style",
                 # v42: the mockup question beside the style. v43: creation says nothing about
                 # worktrees and only relays the hint -- it never pins and never starts one.
                 # P36.S6: the question now offers the working canvas as the default surface.
                 "Mockup: requested", "Mockup: on request", "will you sign on the canvas",
                 "Say nothing about worktrees", "Relay that hint; never act on it",
                 "never ask for a worktree on a docs phase"):
    assert required in create_phase, required
# v47 (P26.S4): the mockup question's default closes the round on the drafted design, not on a
# return from Claude Design. P36.S1: the design tool question and its `Design tool:` line are retired
# (drafter is the only tool; an absent line still reads as `drafter`); the mockup question stays.
# P36.S6: the drafted design is the published working canvas; a mockup comes in addition to it.
assert "literal approval when they return to the published canvas" in create_phase
assert "**in addition to** the canvas" in create_phase
assert "`drafter`" in create_phase and "Mockup: on request" in create_phase
for gone in ("ask which design tool", "Design tool: drafter", "Design tool: claude-design",
             "DesignSync", "design-deck", "design-register", "sign on the cards", "the drafted cards"):
    assert gone not in create_phase, gone
# Explain phases: the route lives in create-phase, the three references ship in do-whole-phase and
# fan out to do-next-slice, and the review pointer is one fixed string everywhere.
assert "## The explain route" in create_phase and "## Explain" in create_phase
for ref in ("explain-decomposition.md", "explain-chapter.md", "explain-review.md"):
    assert f".claude/skills/do-next-slice/reference/{ref}" in SHARED_SKILL_FILES, ref
POINTER = "not written — run /knowledge:explain P<N> for a document, or ask it for a book"
for rel in ("claude/agents/slice-executor.md",
            "claude/skills/review-phase/SKILL.md", "claude/skills/do-whole-phase/reference/review.md",
            "claude/skills/do-next-slice/reference/review.md"):
    assert POINTER in (root / "payload" / rel).read_text(encoding="utf-8"), rel
# v86 (P-mtrt.S6): the pointer names a document, not a chapter; every explain is its own phase, and the
# shipped prose says so. The old split's pointer survives only in tests/fixtures/ (history).
OLD_POINTER = "run /knowledge:explain P<N> for one chapter, or create an explain phase for a book"
for p in [*(root / "payload").rglob("*.md"), root / "installer/main.py", root / "installer/payloads/doc_bodies/operations.md",
          root / "README.en.md"]:
    assert OLD_POINTER not in p.read_text(encoding="utf-8"), p
for p in (root / "installer/payloads/doc_bodies/operations.md", root / "README.en.md"):
    _t = p.read_text(encoding="utf-8")
    assert POINTER in _t and "Every explain is its own **explain phase**" in _t and "merge" in _t, p
assert "every explain is its own explain phase" in (root / "installer/main.py").read_text(encoding="utf-8")
for p in [*(root / "payload").rglob("*.md"), root / "installer/main.py", root / "installer/payloads/doc_bodies/operations.md"]:
    t = p.read_text(encoding="utf-8")
    assert "run /explain for this phase" not in t and "run /knowledge:explain for this phase" not in t, p
# A book runs on the knowledge plugin's research pipeline (plugin 0.6.0+). The route keeps the heading
# and the must-cover field the plugin's readiness check reads; a chapter dispatches the plugin's critic on opus
# with same-model: accepted (v75); only explain executors may dispatch the plugin's research agents; the
# workspace's own explain-critic is retired.
assert "must-cover" in create_phase and "0.6.0" in create_phase and "**A confirmed proposal.**" in create_phase
_chapter = (root / "payload/claude/skills/do-whole-phase/reference/explain-chapter.md").read_text(encoding="utf-8")
assert "knowledge:explain-critic" in _chapter and "kind: chapter" in _chapter and "trace-<key>.md" in _chapter
assert "same-model: accepted" in _chapter and "`model: opus`" in _chapter and "model: sonnet" not in _chapter
_decomp = (root / "payload/claude/skills/do-whole-phase/reference/explain-decomposition.md").read_text(encoding="utf-8")
assert "installed_plugins.json" in _decomp and "pages/.gitignore" in _decomp and "slice: <P>.DECOMP" in _decomp
assert "**The explain carve-out" in (root / "payload/claude/agents/slice-executor.md").read_text(encoding="utf-8")
assert not (root / "payload/claude/agents/explain-critic.md").exists()
# v86 (P-mtrt.S3): every explain unit is a phase, created AND run after one confirmation. The route
# refuses from a phase worktree and for a book or chapter in a public project, keeps a literal `unit`
# line (absent reads as a 0.6.0 book, which still STOPs after creation), cites plugin sections with
# their headings, and declares the gate per unit; the contract carries both exceptions.
for required in ("every unit is a phase", "**one confirmation**", "Explain — confirm once; then it runs to publish.",
                 "start an explain from the main checkout", "`visibility: private` is absolute",
                 "The literal `unit` line", "**The required set, per unit:**", "- worktree: yes",
                 "- outline sign-off: off", "parallel-start <P>` (nested: with no `--host-branch`",
                 "in **`auto`**", "--stop-kind decision", "operator-action", "**with no `unit` line**",
                 "Run `/do-whole-phase` to research and write it.", "§9.2 *Research for a book (an explain phase)*",
                 "**The acceptance gate, per unit:**", "**An explain phase is the one exception:**"):
    assert required in create_phase, required
for gone in ("A single chapter is not a phase", "**A book is a phase, and this route makes one.**"):
    assert gone not in create_phase, gone
for _n in ("do-next-slice", "do-whole-phase"):
    _d = (root / "payload/claude/skills" / _n / "reference/decomposition.md").read_text(encoding="utf-8")
    assert "declares by its unit" in _d and "explain chapter: published private; a v2 is cheap" in _d, _n
    assert "always takes `--require` (the operator reads the book)" not in _d, _n
# v86 (P-mtrt.S5): the three explain references branch per unit. A document or chapter's DECOMP leads
# the research into `doc/` and cuts one S1; the evidence gate is a typed stop; the gate waives per unit;
# S1's critic is `kind: document` (none under quick); the review proves a document private on its own
# route and falls back to an API read-back; the merge back is pointed to, not restated.
_review = (root / "payload/claude/skills/do-whole-phase/reference/explain-review.md").read_text(encoding="utf-8")
for _txt, _pins in (
    (_decomp, ("## A document or a chapter", "works/phases/active/P<N>/doc/", "doc/pages/.gitignore",
               "--kind implementation --risk high --order 10", "**`STOPPED: evidence gate`**",
               "narrow the subject: DECOMP resumes from run.md", "explain document: published private; a v2 is cheap",
               "outline sign-off: on", "under `## The book`", "§3.9 *`quick` and `no-research`*")),
    (_chapter, ("## A document or a chapter: its one write slice", "mode: critique · kind: document",
                "`critique: none (quick)`", "works/phases/active/P<N>/doc/body.md")),
    (_review, ("## Plan a document's or a chapter's review", "/api/documents/by-path/<rel_path>",
               "/app/orgs/<org>/<project>/<slug>", "**Otherwise, the API read-back,**", "A chapter's order check",
               "§8 *D9: the report*", "§9.1 *The book suggestion*", "(*An explain phase merges back by itself*)")),
):
    for _p in _pins:
        assert _p in _txt, _p
    assert "all eleven fields are present" not in _txt
# The explain references point at the plugin's rules (B5 *Your dispatch* is the critic block's format):
# both critic blocks carry B5's `title:` line, and no restated title or order rule is left.
assert _chapter.count("title: <") >= 2 and "title: <" in _chapter.split("kind: document", 1)[1], "title:"
assert "titled `P<N>: <phase name>`" not in create_phase and "taught twice" not in _review

# Only skills that *document the removal* may still say "Codex": update-workspace's
# pre-v31 migration step. Anywhere else it is a regression.
codex_prose = {n for n in skills if "Codex" in skill_dir_text(n)}
assert codex_prose <= {"update-workspace"}, sorted(codex_prose)
# /explain is the knowledge plugin's: not shipped, and RETIRED_FILES never lists an explain path.
assert "explain" not in skills, skills
main_py = (root / "installer/main.py").read_text()
retired_table = main_py[main_py.index("RETIRED_FILES = {"):main_py.index("\n}\n", main_py.index("RETIRED_FILES = {"))]
assert "/explain/" not in retired_table, "RETIRED_FILES lists an explain path"
assert "Codex support was removed in workspace v31" in (
    root / "payload/claude/skills/update-workspace/SKILL.md").read_text()

# Safety-critical orchestration rules only -- not the whole skill body, which would be brittle.
for name in ("do-next-slice", "do-whole-phase"):
    body = skill_dir_text(name)
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
        "lifecycle and the operator's words stay inline",
        # P36.S6 / P46-nb / P47: a round runs in passes (a frame, the pages at once, a join; a
        # co-work slice designs one job), the critique dispatched to design-critic, one PENDING stop per round. v61 (P37.S5): the
        # round procedure (the handoff, the drafter's prompt, the read-back, the publish, the closes)
        # lives once, in design-cowork's references, pinned there; the drivers point at them.
        "`design-critic`", "Each round runs in passes, once per round", "its page drafters at once",
        "design-cowork/reference/opening.md", "`reference/publish.md`", "`reference/operator.md`",
        # P36.S1: a phase whose intent still says `Design tool: claude-design` is legacy -- the
        # drivers point at design-cowork's legacy rule instead of carrying the retired branch.
        "`Design tool: claude-design`", "re-confirm it on `drafter`",
        # v42: the mockup is on request, the operator's return closes the round, the
        # phase gate follows the mockup with a fixed waive note.
        "PENDING #2 exists only when a mockup was requested",
        "Mockup: requested", "Mockup: on request",
        "design-only, no mockup: the operator signed each job on its canvas",
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
        # The entry-level notebook: the orchestrator reads it through phase-section only, runs the
        # required step's notebook_move= lines before the next dispatch, and keeps the breakdown in a topic.
        "never with `Read`, `Edit` or `Write`", "`notebook_over_budget=`",
        "run each `notebook_move=` line under it, prefixed `python3 scripts/workflow.py`",
        "**The breakdown lives in `topics/breakdown.md`, never in `phase.md`:**",
    ):
        assert required in body, (name, required)
    assert "sending it back whole" not in body, name
    # v42 negatives: the mandatory mockup, "not an approval" return, and the
    # opt-in framing of the phase branch are retired from both drivers.
    for gone in ("mechanical wait", "can no longer be waived", "suggestion, never a default",
                 "Four commits and two `pending` stops", "where opting the phase in was the ask",
                 # v47 (P26.S4): the DesignSync loop's push and manifest phrases stay out of both
                 # drivers. P36.S1: the claude-design branch and every DesignSync / design-register
                 # mention are retired from both drivers again.
                 "_ds_manifest", "never dispatched", "DesignSync", "design-register", "**`claude-design`**",
                 "**read back inline with", "Read the tool first", "Under claude-design",
                 "four commits, two", "one dispatched span", "Push the branch", "push the branch",
                 # P26.F1: the elided feedback step (no revision handoff, no read-back) is retired.
                 "in the same slice, re-dispatch the drafter",
                 # P36.S6: schema-1 cards, their address and the regroup are gone from both drivers.
                 "numbered card paths", "no regroup", "the cards stay addressed", "card set",
                 "design-close <round> --",
                 # v61 (P37.S5): the drivers no longer restate the round procedure; one drafter output.
                 "build-prompt.md", "read `result.md` and"):
        assert gone not in body, (name, gone)
    # v35: the per-slice re-read of the generated backlog dashboard is gone --
    # `next` prints the pointer. The only mentions left must say so.
    for ln in body.splitlines():
        if "works/backlog.md" in ln:
            assert "next" in ln and "pointer" in ln, (name, ln)
    # v46: mid is the default row; high needs a named trigger, and a fix to
    # mid-row work goes high (v83 retired the cheap row). The one-line/few-line scope for mid is retired.
    for required in ("**Mid is the default (v46):**", "--kind fix --risk <low|high>`",
                     "work the mid row got wrong never goes back to it"):
        assert required in body, (name, required)
    for gone in ("one-line/few-line", "one-line, or few-line"):
        assert gone not in body, (name, gone)

# P41 (v69): /do-whole-phases is a core-only skill (no reference/ folder of its own) that runs
# do-whole-phase's loop once per phase. `do-whole-phase` is a PREFIX of `do-whole-phases`, so every
# check here names the exact path or the whole string, never a bare `do-whole-phase` search. Its core
# is not in the core-cap loop above (that asserts named == shipped, and this core names no bare
# `reference/<x>.md`); it is checked here instead: the cap, the full-path form of every reference it
# mentions, and the strings the product cannot afford to lose. `disable-model-invocation: true` is
# already pinned for every skill by the marker loop above.
assert "do-whole-phases" in skills, sorted(skills)
phases_core = (root / "payload/claude/skills/do-whole-phases/SKILL.md").read_text(encoding="utf-8")
assert len(phases_core.encode()) <= 8192, ("do-whole-phases", len(phases_core.encode()))
assert phases_core.startswith("---\nname: do-whole-phases\n"), "do-whole-phases frontmatter name"
assert not any(k.startswith(".claude/skills/do-whole-phases/reference/") for k in LIVE), "do-whole-phases ships a reference/"
_full = _re.findall(r"\.claude/skills/do-whole-phase/reference/([\w.<>-]+?)\.md", phases_core)
assert _full and len(_full) == phases_core.count("reference/"), ("a bare reference/ mention", _full)
for _x in _full:
    assert _x == "<x>" or f".claude/skills/do-whole-phase/reference/{_x}.md" in LIVE, _x
for required in (
    "run-phases", "**Every halt stops the whole run.**", "**The two overrides, and only these:**",
    "**Its target wins over the resume card's pointer for the whole run**",
    "git rev-list -1 --before=<started_at> HEAD", "never runs `parallel-start`", "gate_cleared=", "`notebook_over_budget=<P>`",
):
    assert required in phases_core, ("do-whole-phases", required)
# do-whole-phase (one phase) points at its sibling, by the exact path.
assert ".claude/skills/do-whole-phases/SKILL.md" in (root / "payload/claude/skills/do-whole-phase/SKILL.md").read_text(encoding="utf-8")

# P42 (v71): /do-whole-phase runs a declared phase's independent slices together. The protocol lives in
# one reference that ships with do-whole-phase only (do-next-slice still runs one slice), pinned on its
# exact path and a handful of whole strings; the DECOMP rules that make a slice independent live in
# decomposition.md, and explain chapters stay undeclared (explain-decomposition.md drops `--depends-on`).
_wave_rel = ".claude/skills/do-whole-phase/reference/wave.md"
assert _wave_rel in LIVE and ".claude/skills/do-next-slice/reference/wave.md" not in LIVE, "wave.md ships with do-whole-phase only"
wave = (root / "payload/claude/skills/do-whole-phase/reference/wave.md").read_text(encoding="utf-8")
for required in (
    "`ready_slices=<ids|none>`", "`running_slices=<ids|none>`", "## Wave",
    "**The join-rebuilt artifact is the one exception.**", "**Rolling (the default).**", "**At the join.**",
    "wait for every running span and never re-dispatch one",
    # Entry-level notebook writes at a return, beside the over-budget step.
    "Write its `notebook` entries one entry at a time, through `phase-section` only", "`--entry K --remove`",
):
    assert required in wave, ("wave.md", required)
decomp = (root / "payload/claude/skills/do-whole-phase/reference/decomposition.md").read_text(encoding="utf-8")
for required in ("**Independence means disjoint sets.**", "Never declare `DECOMP2`, `REVIEW` or a `co-work` slice"):
    assert required in decomp, ("decomposition.md", required)
for _rel in (".claude/skills/do-whole-phase/reference/explain-decomposition.md", ".claude/skills/do-next-slice/reference/explain-decomposition.md"):
    assert _rel in LIVE and "[--depends-on" not in LIVE[_rel], _rel

# The spec hard-wraps its prose, so match against a whitespace-flattened copy: these
# assertions are about the wording, not about where a line happens to break.
design = " ".join(skill_dir_text("design-cowork").split())
for required in (
    "**You never design.**", "Claude Design", "handoff.md",
    # P36.S6: the card marker is gone; a job's canvas passes `design-check <job>`.
    "design-check <job>", "tokens.css", "--kind co-work --risk high",
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
    "signing a job off — the canvas, and any stubbed mockup with it — is not accepting the product",
    # v34, positive: the three named styles, the mockup section, PENDING #1 is not an
    # approval, and the mockup's exemption from the functional sweep.
    "## Shape — three styles", "**`build-after`**", "**`design-only`**", "**`paired`**",
    "## The mockup — only when the operator asks for one",
    "Exempt from the full functional sweep", "Stubbed data, no backing work",
    # v42: mockups on request, the operator's return closes the round, the reading order is
    # recorded, and the gate follows the mockup. P36.S6: the order lives in board titles, and a
    # board changes only by a drafter pass or the operator's own edit.
    "The operator's return closes the round.",
    "PENDING #2 exists only when a mockup was requested",
    "**A mockup is optional.**",
    "**Board titles carry the reading order.**", "`01 · Page — Inbox`",
    "Mockup: requested", "Mockup: on request",
    "design-only, no mockup: the operator signed each job on its canvas",
    "Edit a board, `canvas.json`, a critique or a closed round's snapshot yourself",
    # v36: the doctrine names an instrument and a fallback that excuses no check.
    # P-zqhy: the instrument is Claude in Chrome -- its tools, held by slice-executor
    # alone; the operator's one-time setup; the agent's dedicated profile selected
    # first on every run; the third halt; and a fallback the manifest chooses.
    "**With what — the instrument.**",
    "Drive that browser with **Claude in Chrome**",
    "Its tools are `mcp__claude-in-chrome__*`",
    "**Nothing ships, nothing registers in settings:**",
    "start with `claude --chrome`, or run `/chrome` and pick \"Enabled by default\"",
    "**A separate Chrome profile for the agent**, signed into **none** of the operator's accounts",
    "**same claude.ai account and organization** as Claude Code",
    # P-zqhy.F1: the key is the deviceId, read with only the agent profile connected; never the
    # name, which Claude in Chrome anonymizes to a position label that moves between connections.
    "**Record its `deviceId`** in `## Operator Runtime` as `Agent's Chrome deviceId:`. Never a name:",
    "labels browsers by position (\"Browser 1\",",
    "connect **only** the agent profile",
    "Reinstalling the extension or signing it out gives the profile a new",
    # v37: what the doctrine rejects is the pre-written suite, not the library --
    # what differs is who picks the next action.
    "in place of a pre-written assertion suite",
    "**Why the executor drives, and not a pre-written suite.**",
    "deciding every check in advance",
    # v37 / P-zqhy: whose browser an agent may drive -- the dedicated profile, selected
    # before any other browser tool, with its own third halt, and the one clause
    # generalizing the principle to the fallback browser.
    "**Whose browser — the agent's profile, selected first, on every run.**",
    "So **before any other browser tool**:",
    "find the entry whose `deviceId` equals the recorded `Agent's Chrome deviceId:`. Never match on `name`",
    "`select_browser` with that `deviceId`",
    "Never pick a browser by guess, never act before selecting.",
    "the recorded `deviceId` **is** the operator's answer, given ahead of time in the manifest",
    "No Chrome tools in the session, no recorded `deviceId`, or no connected browser with that `deviceId` returns **`needs_operator`**",
    "its `deviceId` re-recorded after an extension reinstall or sign-out",
    "Never fall back to a label, never borrow another connected browser, and never create a profile on the operator's behalf.",
    "That is a **third** halt condition and it is not the runtime one",
    "A manifest that still names an older instrument counts as unfilled here",
    "**The fallback — chosen by the manifest, never by the agent mid-run; the doctrine's demands bind, the instrument does not.**",
    "**Chrome missing from a session whose manifest names it is the halt above, never a silent fallback**",
    "never a profile signed into the operator's accounts, whichever browser it is",
    "**Claude in Chrome** is the instrument, on the agent's own profile selected first",
    # v44 (P23): two pins whose contract text left for this skill -- the reading order (P36.S6:
    # board titles numbered 01..N as a set) and the instrument/runtime axis.
    "the numbers form `01..N` as a set",
    "the runtime halt fires on an absent or `UNFILLED` manifest",
    # v47 (P26.S1): the design record is an on-disk contract a separate dashboard reads; its
    # section names the root, the closed marker set, the lifecycle, the registry and the commands.
    # P36.S6: schema 2 -- jobs with canvas trees, one open round per job, immutable closed rounds.
    "## The design record — the on-disk contract (schema 2)",
    "**A closed round is immutable.**", "**At most one round is open per job.**",
    "`design-init", "`design-open", "`design-check", "`design-close <job>/<round> (--words",
    "`design-system", "`design-canvas", "`design-publish-plan <job>`", "`design-preview",
    # v47 (P26.S3): the loop runs on the files. The design subagent drafts, the operator decides;
    # the handoff says whether the round sets a new visual direction; the read-back runs design-check
    # itself; only literal words sign, feedback supersedes, and the round's lifecycle stays inline
    # while the drafting is dispatched. P36.S8C: frontend-design is retired from the drafter (its
    # useful lines carried, credited, in the drafter's craft), and the orchestrator still never loads it.
    "**The design subagent drafts, the operator decides.**", "subagent_type: design-drafter",
    "`new visual direction: yes` or `no`",
    "Load `artifact-design` or `frontend-design` for product design co-work: they will make you design. The drafter loads neither",
    "**Never rest on the drafter's own `design_check` line.**",
    "SIGNOFF is taken on the operator's **literal** words",
    "`python3 scripts/workflow.py design-close <job>/<round> --superseded`",
    'design-close <job>/<round> --words "<their literal words>"',
    "the round's lifecycle and the operator's words stay inline",
    # P36.S6: the schema-2 Artifact loop (P46-nb: one connected group per slice; P47: a frame, the pages at once, a join); critique is
    # opt-in per job, decided at DECOMP; the judge runs beside the drafter's next pass and is skipped
    # under a proxy; only the main thread publishes (from design-publish-plan), never forcing over an
    # operator's edit; one PENDING stop per round; the session's words are the record; the working
    # canvas replaces the mockup by default; the system is re-synced from code with tokens.css; and
    # built canvases are deleted only on the operator's yes.
    "**The passes — a frame, the pages at once, a join.**", "**One design slice is one connected group, one job:**",
    "**A one-page round skips the frame and the join:**", "**Publish only after the join.**",
    "**Foundations come first.**", "`off | critic | critic+judge`, unset = `off`",
    "**`critique: <level>`**", "**beside the drafter's answer pass**", "**`skip=yes`**",
    "**Only the main thread publishes**", "**Never `force`.**", "## PENDING #1 — one stop per round",
    "**The session's words are the record.**", "**The working canvas replaces the in-product mockup by default.**",
    "**Every sync writes `tokens.css`**", "**after the build slice that implemented a signed job lands**",
    "You delete one only on the operator's yes", "The loop needs the `Artifact` tool on the main thread",
    "**The three paths:**", "**Collected taste, never invented:**", "`[claude.critic]` row",
    # P36.S1: the bundle import stays as a drafter input (P36.S6: an operator attachment), and the
    # claude-design folder is a legacy record with its own short note and legacy rule.
    "### Operator attachments", "an exported Claude Design bundle",
    "a design slice authorizes no `git push`",
    "## Design tool", "**`drafter` is the only design tool.**", "**Legacy rule.**",
    "Design tool: claude-design", "re-confirm the phase on `drafter`",
    "An absent `Design tool:` line reads as `drafter`",
    "### Legacy record: claude-design/", "docs/reference/design/claude-design/",
    "**`claude-design/` is outside schema 2**", "### Legacy record: schema1/",
    "python3 scripts/workflow.py design-migrate --apply", "| `design-migrate [--to 2] [--apply]` |",
    "python3 scripts/workflow.py design-migrate --to 2",
    # P36.S8C: the approved design recipe. One critic pass, then one drafter answer pass (the judge
    # beside it, its upheld items one short pass); the handoff carries the operator's bar from bar.md,
    # prototype first, a target for every link, and one direction unless the operator asked.
    "one critic pass, then at most one drafter answer pass. There is no second critic pass.",
    "Its **upheld** items get **one more short drafter pass**",
    "**`## The operator's bar`**, a heading of its own.", "`none beyond the shipped bar`",
    "├── bar.md", "**Prototype first:**", "**Every link has a target in scope.**",
    "**One direction unless the operator asked for options.**",
    "a critic pass took 25–36 minutes on a flow-board job",
    # Moved from the drivers' pins (v61, P37.S5): the rule lives here once.
    "write the new round's handoff", "The new round edits the job's canvas in place",
    "line, the round address `<job>/<round>` and a `pass:` line", "`new visual direction: yes` or `no`",
    # v61 (P37.S5): the design lifecycle as engine one-liners and a slimmer record. The read-back
    # fetches only what the listing names; the engine writes SIGNOFF.md and one word signs every job
    # presented; a superseding round re-drafts with critique off; the stop report is a short chat
    # message; the slice's brief once, a delta per round; one drafter output; repo-relative paths only.
    "design-readback <job> --listing <file|->", "design-readback <job> --fetched <dir>",
    "`--fetched <dir> --apply`", "python3 scripts/workflow.py design-sign --slice <S> --words",
    "**All or nothing:**", "**Never write `SIGNOFF.md` yourself**",
    "**A superseding round's critique is off by default**",
    "**The stop report** is a chat message, never a file in the record",
    "**At most about 5 decisions**", '**Everything else is one "decided as drawn" list**',
    "**signs everything presented** (`design-sign`)",
    "**The slice's brief, once per slice: `waves/<slice>/brief.md`**", "**Each round's `handoff.md`, a short delta**",
    "**What you read of a span: its verdict block, and the round `result.md`'s `## Summary`**",
    "**One drafter output per round: `result.md`**", "**Repo-relative paths only.**",
    "**The notebook gets one gist line per signed job**", "| `design-sign --slice S --words \"…\"` |",
    # P46-nb: one connected group per co-work slice, one canvas and one artifact per round; a
    # legacy multi-job slice finishes as drawn. P47 (OQ1): a small unrelated surface may share the
    # slice's canvas, unlinked; a bigger unrelated group stays a co-work slice of its own.
    "**One connected group, one canvas.**", "**A small unrelated surface of the same phase may share a slice's canvas:**",
    "A bigger unrelated group is a co-work slice of its own, never a second job of a slice.",
    "**Never `--new-job` for another surface:**", "### Legacy record: a multi-job slice", "**It finishes as drawn:**",
):
    assert required in design, required
# P46-nb: the wave choice is retired from the drafting procedure.
assert "**A wave choice**" not in design, "**A wave choice**"
# P46-nb.F1: the retired cut (one job per surface, a wave of 3-4 jobs, an artifact per job, one stop per
# wave) is gone from every shipped surface that prescribes it: the DECOMP references, the slice executor,
# the do-* cores and verdicts, and both READMEs; the DECOMP references and READMEs say the new cut.
_cut = "**one co-work slice per connected group of related surfaces**"
for rel in ("claude/skills/do-whole-phase/reference/decomposition.md", "claude/skills/do-next-slice/reference/decomposition.md"):
    _t = (root / "payload" / rel).read_text(encoding="utf-8")
    assert _cut in _t and "each slice's one job with its critique level" in _t, rel
    for gone in ("one job per surface", "a wave of about 3–4 jobs", "each slice's jobs with their critique level"):
        assert gone not in _t, (rel, gone)
_t = (root / "payload/claude/agents/slice-executor.md").read_text(encoding="utf-8")
assert "each co-work slice's one job with its critique level" in _t and "co-work slice's jobs with their critique levels" not in _t
for rel in ("claude/skills/do-whole-phase/SKILL.md", "claude/skills/do-next-slice/SKILL.md"):
    _t = (root / "payload" / rel).read_text(encoding="utf-8")
    assert "stops `pending` once per round" in _t and "once per wave" not in _t, rel
_t = (root / "payload/claude/skills/do-whole-phase/reference/verdicts.md").read_text(encoding="utf-8")
assert "its page drafters are dispatched at once, then its page critics" in _t and "is its spans:** one drafter per job at once" not in _t
assert "a design wave's spans" not in (root / "payload/claude/skills/do-whole-phase/reference/wave.md").read_text(encoding="utf-8")
_ko, _en = ((root / n).read_text(encoding="utf-8") for n in ("README.md", "README.en.md"))
assert "### 시각 디자인 작업: 라운드마다 여러분이 승인" in _ko and "더 큰 무관한 묶음은 각자 별도의 디자인 slice가 됩니다" in _ko and "관련 없는 작은 화면은 링크 없이 같은 캔버스에 함께 그릴 수 있고" in _ko
assert "라운드마다 연결된 캔버스 하나를 Design canvas Artifact 하나로 게시" in _ko
for gone in ("job마다 여러분이 승인", "job 3–4개", "job마다 별도의 Design canvas", "wave 전체"):
    assert gone not in _ko, gone
assert "### Visual work: you sign each design round" in _en and "a bigger unrelated group is a design slice of its own" in _en and "a small unrelated surface may share its canvas, drawn unlinked" in _en
assert "one connected canvas as one Design canvas Artifact" in _en and 'signs the round' in _en
for gone in ("you sign each design job", "wave** of 3–4 jobs", "publishes each job to its", "once for the whole wave"):
    assert gone not in _en, gone
_t = (root / "payload/scripts/workflow.py").read_text(encoding="utf-8")
assert "or pass --new-job for another" not in _t and "merge them into one connected job with --new-job" in _t
# v61 (P37.S5): the orchestrator never hand-writes SIGNOFF.md, never reads build-prompt.md in a new
# round, and never pulls the canvas whole at the read-back.
for gone in ("**Write `SIGNOFF.md`** in the round folder", "and `build-prompt.md`, the", "`read` the canvas's files with `out_dir` and diff"):
    assert gone not in design, gone
# P36.S8C: the old multi-pass loop and the drafter's frontend-design licence are gone from the skill.
for gone in ("cap 3", "repeated findings", "**the cap:**", "`repeated`", "**The one exception:**",
             "only licence for `frontend-design`", "whether it used", "passes 02–03"):
    assert gone not in design, gone
# P36.S1: the retired tool's loop, DesignSync read-back, registry and deck are gone from the skill.
for gone in ("### Under claude-design", "### Under drafter", "## The claude-design record",
             "Design tool — drafter or claude-design", "Design tool: drafter | claude-design",
             "DesignSync", "design-register", "AGENTIC_DESIGN_REGISTRY", "AGENTIC_DESIGN_DECK_URL",
             "Connect GitHub", "_ds_manifest", "**claude-design:**", "**drafter:**", "dashboard",
             # P36.S6: the schema-1 card loop is gone -- the marker, the review address, the regroup,
             # the per-project open-round rule, and the two-span dispatch.
             "@dsCard", "⏳", "regroup", "card set", "At most one round is open per project",
             "**Two spans are dispatched:**", "**The drafter loop never requires a claude.ai account**"):
    assert gone not in design, gone
# v48 (P27.S2): where the restored loop and P26's disagreed, P26's governance won -- the build slices
# are cut once the design is *signed*, revisions are superseding rounds in the same slice (not one
# co-work slice per round), the mockup route goes into phase.md and SIGNOFF.md (not "the round's
# record"), and the design root is fixed (no repo-owned design/ tree).
for gone in ("cuts the build slices once the design has landed", "one `co-work` slice each",
             "in the round's record *and* in `phase.md`", "under its own `design/` tree instead",
             "**The workspace never requires a claude.ai account"):
    assert gone not in design, gone
# v47 (P26.S3): the frontmatter. The skill still auto-fires on the same trigger, says who drafts and
# who decides, and keeps no unquoted ": " in its description. P36.S1: no DesignSync tool and no
# claude-design wording in the frontmatter.
raw_design = (root / "payload/claude/skills/design-cowork/SKILL.md").read_text()
front = raw_design.split("---\n", 2)[1]
allowed = next(ln for ln in front.splitlines() if ln.startswith("allowed-tools:"))
assert "DesignSync" not in allowed and "Agent" in allowed, allowed
# v60 (P36.S9): the operator pre-approved the design loop's publish and comment calls ("Pre-approve both").
tools = [t.strip() for t in allowed.split(":", 1)[1].split(",")]
assert "Artifact" in tools and "ArtifactComments" in tools, allowed
desc = next(ln for ln in front.splitlines() if ln.startswith("description:"))[len("description: "):]
assert ": " not in desc, desc
for required in ("the design subagent drafts, the operator decides",
                 "Use when a phase or slice touches a design system, a redesign, mockups"):
    assert required in desc, required
for gone in ("the operator designs in Claude Design", "claude-design", "DesignSync"):
    assert gone not in desc, gone
assert "Claude Design + the operator" not in desc, desc
# v47: the contract section and the engine move together -- the root the skill states is the
# engine's own constant. v48 (P27.S1/S2): so is the claude-design record's folder name. P36.S1: the
# registry and design-deck constants are gone from the engine (P36.S4: named exactly, since
# design-preview's AGENTIC_DESIGN_BROWSER shares their prefix).
import re
workflow_src = (root / "payload/scripts/workflow.py").read_text()
for const in ("DESIGN_ROOT_REL", "DESIGN_LEGACY_DIR"):
    value = re.search(r'^' + const + r' = "([^"]+)"$', workflow_src, re.M).group(1)
    assert value in design, (const, value)
for gone in ("DESIGN_REGISTRY_ENV", "DESIGN_REGISTRY_DEFAULT", "DESIGN_DECK_URL_ENV", "design-register",
             "design_deck_hint", "AGENTIC_DESIGN_REGISTRY", "AGENTIC_DESIGN_DECK_URL"):
    assert gone not in workflow_src, gone
# P26.F2: the skill's reference bullet names every prefix design-check allows. P36.S3 put the engine on
# schema 2 (DESIGN_ALLOWED_REFS gained `/_blob/`); P36.S5 re-coupled the drafter's half and P36.S6 the
# skill's: both name every DESIGN_ALLOWED_REFS prefix, relative paths inside project/ (ds/<ns>/
# included) and `{{hole}}`, and the schema-1 `../tokens.css` exception is gone.
allowed = re.search(r'^DESIGN_ALLOWED_REFS = \(([^)]*)\)$', workflow_src, re.M)
assert allowed, "DESIGN_ALLOWED_REFS"
allowed = re.findall(r'"([^"]*)"', allowed.group(1))
assert allowed and "/_blob/" in allowed, allowed
bullet = design.split("- **References stay inside the canvas.**", 1)[1].split(" - **", 1)[0]
for ref in allowed + ["{{hole}}", "ds/<ns>/…"]:
    assert "`" + ref + "`" in bullet, (ref, bullet)
for term in ("relative path inside `project/`", "`..`"):
    assert term in bullet, (term, bullet)
assert "../tokens.css" not in bullet and "- **Self-contained.**" not in design, bullet
drafter_rule = " ".join((root / "payload/claude/agents/design-drafter.md").read_text().split())
drafter_rule = drafter_rule.split("**The reference rule:**", 1)[1].split(" - **", 1)[0]
for ref in allowed + ["{{hole}}", "ds/<ns>/…"]:
    assert "`" + ref + "`" in drafter_rule, (ref, drafter_rule)
for term in ("relative path inside `project/`", "`..`"):
    assert term in drafter_rule, (term, drafter_rule)
assert "../tokens.css" not in drafter_rule and "**Keep every card self-contained.**" not in drafter_rule, drafter_rule
assert "A card references nothing relative except `../tokens.css`. " not in design
# P26.F1, re-pinned by P36.S8C: the handoff's `new visual direction` line is the operator's call and
# licenses a new look only, built as one direction; a missing line is an open question. The drafter
# draws options only when the handoff quotes the operator asking, loads no skill, and carries
# frontend-design's useful lines with their Apache-2.0 credit.
drafter = " ".join((root / "payload/claude/agents/design-drafter.md").read_text().split())
for required in ("`new visual direction: yes` in the handoff licenses setting a new look; you still build it as **one** direction.",
                 "If the `new visual direction` line is missing, extend the established look and name the missing line in `open_questions`.",
                 "appear only when the handoff quotes the operator asking for options",
                 "licensed under the Apache License, Version 2.0", "That skill is not loaded.",
                 # P36.S8C: the recipe -- flow boards, the per-page state bar, links in the prototype,
                 # no decorative SVG, the detail and Toss rules, and the checks run with --click.
                 "**Flow boards: the clicked item is the item shown.**", "### The state bar (on every interactive Page)",
                 "**only that page's presets**", "A preset never moves to another page",
                 "**Every link stays in the prototype.**", "Decorative SVG artwork",
                 "**Controls never change size or move what is around them when they show state**",
                 "Scope page link colors to text links (`a:not([class])`)",
                 "**Toss-level care (the rules, never Toss's look).**",
                 "**Fix every `check=` line before you return**", "--strict`, with **no `--out`**",
                 "**never a reason to fold a component's states into a static board**",
                 # P46-nb: the connected canvas opens on its entry Page.
                 "**The connected canvas.**", "board 01 is the **entry Page**, `Main.dc.html`",
                 # P47: a round drafts in three passes, named on the dispatch's one pass line.
                 "`pass: frame | page <slug> | join`", "### Frame rules (`pass: frame`)",
                 "### Page rules (`pass: page <slug>`)", "### Join rules (`pass: join`)"):
    assert required in drafter, required
for gone in ("your **only** licence to load it", "load it through `Skill`", "`frontend_design`",
             "A **direction round** is one whose handoff says", "A job open in the same wave"):
    assert gone not in drafter, gone
# P36.S8C: the critic gives one pass on the bar rubric, hovers, types and clicks at desktop and 390 px
# with the engine's checks and a harness recipe for the rest, never restyles the state bar, and
# follows the handoff on directions; passes 02-03, the cap and `repeated` are gone.
critic = " ".join((root / "payload/claude/agents/design-critic.md").read_text().split())
for required in ("**You get one pass**", "**The bar, line by line**", "**The state bar is on every interactive Page, lists only that page's states**",
                 "**The state-bar exemption.**", "**The direction rule follows the handoff.**",
                 "**The interaction pass is yours where it needs judgment.**", "**What it still cannot do**",
                 "w.DesignBrowser(w.design_preview_browser(None), tempfile.mkdtemp())", "--states-only",
                 "You rule once, beside the drafter's answer pass",
                 # P46-nb: the connected checks replace the cross-job look.
                 "**the connected checks, each a Part 1 must-fix under the bar.**",
                 # P47: a critic judges one page or the joined canvas; measured lines are facts.
                 "`scope: page <slug>` or `scope: cross`", "**The measured lines are facts.**",
                 "They are `high`-confidence facts either way, never argued away by taste."):
    assert required in critic, required
# P47: the advisory measured lines (check=align, M1-M14) never block; the blocking set stays the four WCAG checks.
assert 'DESIGN_PREVIEW_BLOCKING = ("non-text-contrast", "reflow", "overprint", "keyboard")' in (root / "payload/scripts/workflow.py").read_text(encoding="utf-8")
for gone in ("passes 02 and 03", "Passes 02 and 03", "- repeated: N", "`repeated`:", "at pass 03",
             "`wave: <job>, <job>, …`", "**The cross-job look", "`wave choice`", "or `choice` (a cross-job conflict"):
    assert gone not in critic, gone
# v37 negatives: the MCP-first prescription is retired -- no config block to copy,
# no surface preference, and no "Playwright-style automation" framing anywhere.
for gone in ('{"mcpServers"', "Prefer the **MCP** surface", "MCP first",
             "scripted Playwright-style automation", "scripted assertion suite",
             # v42 negatives: the mandatory mockup and the "not an approval" return.
             "Only PENDING #2 is an approval.", "mechanical wait", "SIGNOFF moves to the mockup gate",
             "cut the slice into four", "can no longer be waived",
             "the design in the project's own language",
             # v44: copied from the contract list, now that the instrument rule lives here.
             # P-zqhy: the Aside procedure is retired whole (surfaces, CLI, profile flag).
             "runs through Aside, not a script", "Aside", "aside repl", "aside mcp",
             "aside exec", "aside account", "--account <id>", "attachBrowserTab", "RefStaleError"):
    # (v47's absence pins for the Claude Design + DesignSync loop were retired in v48 (P27.S2): that
    # loop is the `claude-design` tool now, and its phrases are presence pins above.)
    assert gone not in design, gone

# v44 (P23): the worktree rules left the contract for the skill that runs them, so their
# pins live here now, whitespace-flattened like design-cowork's: rule 1 is "only when
# asked", rule 8 retires the v42 pins, a hint is relayed and never acted on, and a closed
# gate is never merged past. D-3: `parallel-start` itself runs only on the operator's word.
parallel = " ".join((root / "payload/claude/skills/parallel-phase/SKILL.md").read_text().split())
for required in ("Worktree rules", "**When — only when asked**", "retired no-ops",
                 "Relay a hint to the operator; never act on it.",
                 "Never merge a parallel phase whose `parallel-gate` is closed",
                 "the do-* skills relay it and run nothing",
                 # v61 (P37.S9): the contract's "(v43)" tag and its three ways of asking moved here.
                 "**Since v43 this is opt-in:", "the **`worktree` mode word**",
                 "**`parallel-start <P>` run by the operator's own hand**"):
    assert required in parallel, required
# v43 negatives copied from the contract list (the worktree-by-default framing), and the
# v42 leftover that had the do-* skills start a worktree whenever `next` printed the hint.
for gone in ("runs in its own worktree by default", "enters its worktree at **first execution**",
             "the do-* skills do this for you"):
    assert gone not in parallel, gone
# v86 (P-mtrt.S4): an explain phase is the one worktree exception (its confirmation is the asking),
# a nested one cuts a detached host worktree, and it merges back by itself past a busy main when the
# engine's exemption holds; a no-notes pass settles consolidation; an unmerged branch shows as merge_ready=.
for required in ("**One exception: an explain phase (v86).**", "### An explain phase merges back by itself",
                 "**An explain phase needs no host branch (v86).**", "`exemption=phase-folder-only (<n> paths)`",
                 "`merge_ready=<P>:<branch>`", "`parallel-teardown <P> --discard-ignored`",
                 "**A phase with no debt settles itself (v86):**", "the main checkout's `.claude/settings.local.json`",
                 "(an explain phase's confirmation is the asking)"):
    assert required in parallel, required
for _n in ("do-next-slice", "do-whole-phase"):
    _w = " ".join((root / "payload/claude/skills" / _n / "reference/worktree.md").read_text(encoding="utf-8").split())
    _c = (root / "payload/claude/skills" / _n / "SKILL.md").read_text(encoding="utf-8")
    assert "**An explain phase**" in _w or "**One exception: an explain phase (v86).**" in _w, _n
    assert "merge_ready=" in _w and "merge_ready=" in _c and "(an explain: its confirmation asked)" in _c, _n
_ww = " ".join((root / "payload/claude/skills/do-whole-phase/reference/worktree.md").read_text(encoding="utf-8").split())
for required in ("**An explain phase merges back by itself, with no stop.**", "**When the automatic merge cannot run**",
                 "**The closing report** of an explain run comes last", "`parallel-teardown <P> --discard-ignored`"):
    assert required in _ww, required

# v32 review procedure: the gate stages, the returned walkthrough, and the two
# workflow commands a review slice must never run.
review = (root / "payload/claude/skills/review-phase/SKILL.md").read_text()
for required in ("## Gate stages", "`walkthrough`", "`## Operator Runtime`", "`## Regression Checklist`",
                 # v36: the review opens the product with the prescribed instrument.
                 "**Drive it with Claude in Chrome**", "the doctrine's demands bind, the instrument does not",
                 "with the same instrument as stage 2",
                 # v37: against no pre-written suite. P-zqhy: the agent's own Chrome profile,
                 # selected first, the third halt, and the manifest's fallback, by reference.
                 "its `mcp__claude-in-chrome__*` tools", "in place of a pre-written assertion suite",
                 "**before any other browser tool**, `list_connected_browsers`, then `select_browser`",
                 "on the entry whose `deviceId` is `## Operator Runtime`'s `Agent's Chrome deviceId:` (never a `name`",
                 "no recorded id, or no match means `needs_operator` (the third halt), never borrowing the operator's browser",
                 "The fallback is the manifest's choice, never yours mid-run",
                 "Setup, the halt and the fallback in full: `design-cowork`'s `reference/build.md`.",
                 # v41: the review reviews the boundary of the phase, never the whole system --
                 # phase-scope is its input, and stage 4 re-runs the checklist inside it.
                 "## The boundary", "phase-scope <P>",
                 # v42: a branch review records its two gate sections as tagged notes, and
                 # the mockup qualifier applies only where the operator asked for one.
                 "(gate section — written at merge)", "a phase in which the operator asked for one",
                 "Re-run the checklist lines inside the boundary",
                 "an operator-created QA phase, never by a review",
                 # P42.S4 (v71): a finding is a whole problem class, so one round finds every case.
                 "**A finding is a problem class, not an instance.**",
                 # The entry-level notebook: a decision is present as a gist line plus its topic, and a
                 # dangling pointer is a lost decision.
                 "**A decision counts as present when its gist line is in `## Decisions` and its detail is in the linked topic**",
                 "A dangling-pointer warning from `validate`"):
    assert required in review, required
# P42.S4 (v71): a second failure of the same rules stops for the operator instead of another fix round,
# in both loops' review references (separate files, so each exact path is read).
for _rel in ("claude/skills/do-whole-phase/reference/review.md", "claude/skills/do-next-slice/reference/review.md"):
    assert "**Stop instead of another round.**" in (root / "payload" / _rel).read_text(encoding="utf-8"), _rel
for gone in ("MCP surface first", "scripted Playwright-style automation",
             # P-zqhy: the Aside procedure is retired from the review.
             "Aside", "aside repl", "aside mcp", "--account <id>",
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
# v36: one seed field records what THIS machine has. P-zqhy: Claude in Chrome is its
# default (blank means it), and the fallback is a named real browser on a throwaway profile.
assert "- Browser instrument for the agent: <Claude in Chrome (the default; blank means it)" in ops
assert "the other real browser the agent drives on a throwaway profile" in ops
# P-zqhy.F1: the second field records the agent profile's deviceId -- the key slice-executor's
# select-first rule matches -- never its name, an anonymized position label.
assert "- Agent's Chrome deviceId: <the `deviceId` that `list_connected_browsers` prints for the dedicated agent profile" in ops
assert "while it is the only browser connected; never its `name`" in ops
assert "re-record after an extension reinstall or sign-out" in ops
assert "signed into none of the operator's accounts" in ops
for gone in ("Aside", "aside repl", "aside mcp", "aside account"):
    assert gone not in ops, gone
qa = (root / "installer/payloads/doc_bodies/qa.md").read_text()
assert "## Regression Checklist" in qa
assert "- [ ] <surface>: <one observable behaviour> (P<N>)" in qa
# v41: the seed says the list is re-run inside the phase's boundary, never whole by a review.
assert "phase-scope <P>" in qa and "re-runs the whole list" not in qa

# v66: one executor, slice-executor, replaces the mid/high pair; its frontmatter carries the mid row.
assert not (root / "payload/claude/agents/slice-executor-mid.md").exists()
assert not (root / "payload/claude/agents/slice-executor-high.md").exists()
for tier in ("slice-executor",):
    body = (root / "payload/claude/agents/slice-executor.md").read_text()
    fm = body.split("---\n", 2)[1]
    assert "name: slice-executor\n" in fm and "model: opus\n" in fm and "effort: medium\n" in fm, fm
    assert "commit or push (no `git commit`, `git add`, `git push`)" in body, tier
    for gone in ("Codex", ".agents/", ".codex/", "AGENTS.md"):
        assert gone not in body, (tier, gone)
    # v32: the design gate (D2), the acceptance-gate stages, and the walkthrough
    # return field are word-for-word in BOTH tiers, not high only.
    # v47 (P26.S4): who drafts, and what the mockup span reads.
    # P36.S6: the drafter drafts a job's canvas, the critic judges it, and the mockup span has no
    # Artifact access (the orchestrator alone publishes).
    for required in ("the design subagent (`design-drafter`) drafts a job's canvas, the critic (`design-critic`) judges it, and the operator decides",
                     "the one span of that slice dispatched to a slice executor",
                     "its record on disk", "no `Artifact` access", "in addition to its working canvas"):
        assert required in body, (tier, required)
    # P36.S1: the retired claude-design tool and DesignSync are gone from both executor bodies.
    for gone in ("DesignSync", "claude-design", "never dispatched, because you have no", "landed record",
                 "a round's cards", "the cards show"):
        assert gone not in body, (tier, gone)
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
        # `--order` / `depends_on` facts a DECOMP executor needs (v71: the dependency binds).
        "**The `docs` slice's carve-out:**",
        "a fractional `--order` (e.g. `4.5`) inserts a slice between two neighbors",
        # P42 (v71): a wave executor's rules, and `--depends-on` declares and binds.
        "## In a wave (your `plan.md` carries a `## Wave` section)", "**declares and binds**",
    ):
        assert required in body, (tier, required)
    assert "`depends_on` is advisory" not in body, (tier, "advisory depends_on")
    # v36: a named real-browser instrument in the implementation bullet, the mockup span and the
    # review's gate stage 2. P-zqhy: Claude in Chrome replaces Aside -- the executor holds its tools,
    # selects the agent's dedicated browser before any other browser tool, halts a third way when it
    # cannot, and takes a fallback only when the manifest names one.
    for required in (
        "Drive that browser with **Claude in Chrome**",
        "its `mcp__claude-in-chrome__*` tools in your tool list",
        "the doctrine's demands bind, the instrument does not",
        "Name in `result.md` which instrument you used",
        "in place of a pre-written assertion suite",
        "never the operator's signed-in one",
        "**Before any other browser tool**, call `list_connected_browsers`",
        "find the entry whose `deviceId` equals the `Agent's Chrome deviceId:` recorded in `## Operator Runtime`, and `select_browser` with it",
        "never match on `name` (a position label",
        "and never act before selecting",
        "The recorded id is the operator's answer, given ahead of time",
        "If your session has no Chrome tools, the manifest records no `deviceId`, or no connected browser carries it",
        "or its `deviceId` re-recorded after an extension reinstall or sign-out) rather than falling back to a label",
        "return `needs_operator` (a third halt, distinct from the runtime one)",
        "**The fallback is the manifest's choice, never yours mid-run:**",
        "Chrome missing from your session is the halt above, never a silent fallback.",
        "driven with the same instrument and the same select-first rule (Claude in Chrome, or the fallback the manifest names)",
        "driving it with the same instrument and the same select-first rule (Claude in Chrome, or the fallback the manifest names)",
    ):
        assert required in body, (tier, required)
    for gone in ("MCP surface first", "scripted Playwright-style automation",
                 # P-zqhy: no Aside procedure survives in the executor.
                 "Aside", "aside repl", "aside mcp", "aside account", "--account <id>", "attachBrowserTab"):
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
        # The entry-level notebook: phase.md is written one entry at a time through phase-section only, never
        # by Read/Edit/Write; a decomposition's breakdown lives in topics/breakdown.md behind a gist line.
        "**Write** the phase's `phase.md` one entry at a time, through `phase-section` only: **never `Read`, `Edit` or `Write` `phase.md`**.",
        "A decomposition slice writes its breakdown to `topics/breakdown.md`, never into `phase.md`",
        "Executors never act on `notebook_over_budget=`",
        "the soft budget is **40 KB**", "phase-section <P> <name> --replace|--append", "`topics/<slug>.md`",
        "never edit inside the `<!-- slices:begin -->`",
        "edit inside `phase.md`'s generated `## Slices` block",
        "Cross-check the notebook against the logs",
        # v41: the boundary rule and its phase-scope input are in BOTH bodies word for word.
        "The review reviews the boundary of the phase, not the whole system",
        "phase-scope <P>", "inside the phase's boundary",
    ):
        assert required in body, (tier, required)
    for gone in ("not just this phase's lines", "re-run the **whole**", "goes here too",
                 "read the section first so you send it back whole"):
        assert gone not in body, (tier, gone)
    never = [ln for ln in body.splitlines() if "run workflow state-transition commands" in ln]
    assert len(never) == 1 and "`accept-gate`" in never[0] and "`defer-job`" in never[0], tier
    # v46: mid is the default row, escalates on named reasons (never for real code
    # or several files); v66: every verdict names its route (the `tier` field retired).
    for required in ("the default row, where most slices land", "**two strikes**",
                     "- `route`: `high` | `research` | `mid` —", "work the mid row got wrong never goes back to it",
                     "## Escalate early instead of thrashing (mid row only)",
                     "The `high` and `research` rows never return `escalate`."):
        assert required in body, (tier, required)
    for gone in ("the light tier", "essentially all code writing", "- `tier`", "slice-executor-mid", "slice-executor-high",
                 "mid tier", "high tier", "top tier", "capability tiers"):
        assert gone not in body, (tier, gone)
    # P-zqhy: the Chrome wildcard rides last on a non-empty list (a Chrome-off session launches it
    # with the rest; an all-MCP list would be refused).
    assert "tools: Read, Edit, Write, Glob, Grep, Bash, WebSearch, WebFetch, Agent, mcp__claude-in-chrome__*\n" in fm, tier
    # v53 (P32.S3): the Agent tool is for read-only Explore lookups only; the verdict block
    # records model and effort beside tier.
    for required in ("## Delegate reads, never writes", "subagent_type: Explore",
                     "- `model`:", "- `effort`:", "delegate nothing",
                     "never to spawn another executor"):
        assert required in body, (tier, required)
    assert "never an executor tier" not in body, tier

# P-zqhy: only slice-executor drives a real browser; the drafter, the critic and Explore render
# headless or read, so none of them carries the Claude in Chrome tools.
for _agent in ("design-drafter", "design-critic", "Explore"):
    _fm = (root / f"payload/claude/agents/{_agent}.md").read_text().split("---\n", 2)[1]
    assert "mcp__claude-in-chrome" not in _fm, _agent
assert "Aside" not in (root / "payload/claude/agents/design-drafter.md").read_text(), "design-drafter still names Aside"
# P-zqhy: Aside is retired whole -- no shipped body (payload or seed doc) names it or its
# CLI; the English word "aside" stays, CHANGELOG.md and tests/fixtures/ keep frozen history.
for _base in ("payload", "installer/payloads"):
    for _f in sorted((root / _base).rglob("*")):
        if _f.is_file():
            _t = _f.read_text(encoding="utf-8", errors="replace")
            for _gone in ("Aside", "aside repl", "aside mcp", "aside exec", "aside account"):
                assert _gone not in _t, (str(_f.relative_to(root)), _gone)
            # P-zqhy.F1: the agent's browser is keyed on its deviceId; no shipped body keeps the
            # name-keyed field or a rule matching the anonymized `name` label.
            for _gone in ("Agent's Chrome browser name", "whose `name` is", "connected under that name"):
                assert _gone not in _t, (str(_f.relative_to(root)), _gone)
# P-zqhy.F1: the explain review's reader check selects by the same key.
_er = (root / "payload/claude/skills/do-whole-phase/reference/explain-review.md").read_text(encoding="utf-8")
assert "`select_browser` on the recorded `Agent's Chrome deviceId:`, never a `name` label" in _er
assert "no recorded id or no browser with it, return `needs_operator`" in _er

# v53 (P32.S3): the Explore agent's final body, and no Agent tool on it (it never nests).
explore = (root / "payload/claude/agents/Explore.md").read_text()
explore_fm = explore.split("---\n", 2)[1]
assert "tools: Read, Grep, Glob\n" in explore_fm and "omitClaudeMd: true\n" in explore_fm
assert "Agent" not in [ln for ln in explore_fm.splitlines() if ln.startswith("tools:")][0]
for required in ("not read / possibly stale", "Never recommend, judge, decide, edit or run anything",
                 "needs judgment"):
    assert required in explore, required

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
# executor lists). The instrument, worktree and design stubs' procedure pins are on the
# design-cowork list (the three styles, `## Design Style`, `Mockup: requested`, the
# numbered cards, the return that closes the round, PENDING #2, the two surfaces, the
# Claude in Chrome setup, list -> select, the third halt, the manifest's fallback, the instrument/runtime axis),
# the do-* and create-phase lists, and the parallel-phase list (the worktree rules).
claude = (root / "payload/contract.md").read_text()
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
    # P36.S6 / P46-nb / P47: the drafting in passes (frame, pages at once, join), the critique to
    # design-critic, and one publisher; each design slice is one canvas drafted page by page, one artifact per round.
    "Each design slice is one canvas drafted into the repo page by page",
    "dispatching its drafting to `design-drafter` (frame, pages at once, join), its critique to `design-critic` when the job's level asks, and its mockup build (only on request) to `slice-executor` on the high row",
    "the round's lifecycle and the operator's words stay inline, and only the main thread publishes",
    "executors never get `Artifact`",
    "`--kind` is a **closed set**",
    # v43: the worktree is opt-in again (v44: the rules themselves live in parallel-phase;
    # v61: the "(v43)" tag too, pinned on the parallel-phase list).
    "unless the operator asks for a worktree", "never on a `hint:`",
    # v35: just-in-time reads and the bounded/edited notebook.
    "Just in time, and only what the work in front of you needs",
    "never the whole doc set up front, and never `docs/index.json`",
    # v61 (P37.S9): the notebook is an index under a 40 KB budget, read and written one
    # section at a time; long material goes to a topic file.
    "**bounded state**", "PHASE_MD_BUDGET", "a soft 40 KB cap", "(`phase-section`)",
    "never drop a decision or a question", "`topics/<slug>.md`", "structured verdict block first",
    # v61 (P37.S9): intent.md records what, never how; dispatch prompts carry the slice id,
    # verdicts are recorded and spans metered; every pending stop is typed; the stop rules.
    "never the workflow's mechanics", "start each dispatch prompt `slice: <id>`",
    "`dispatch-summary` meters every span", "`--stop-kind`", "**The stop rules**",
    "at most ~5 decisions", "one \"decided as drawn\" list", "a report of about 2k chars plus links",
    # v36: the research kind (high by kind) and DECOMP2 generalized past the build-after
    # design style. v44: the closed --kind set and DECOMP2's two origins live in IDs and
    # Status; the research kind's findings-only rule is the executor's.
    "the **kind wins** a disagreement",
    "**`DECOMP2` has two origins**", "`P<N>.DECOMP3`",
    "`research`, `fix`, `docs`, `qa`, `co-work`",
    # v36: a named instrument, with a binding fallback. v37: it rejects the pre-written suite, not
    # Playwright. P-zqhy: the instrument is Claude in Chrome (its setup lives in design-cowork).
    "**Real-browser verification runs through Claude in Chrome, not a pre-written assertion suite.**",
    "**the doctrine's demands bind, the instrument does not.**",
    # v37: whose browser -- a dedicated profile, and the personal-profile case as a third halt.
    # P-zqhy: every run lists the connected browsers, then selects the manifest's, before any other
    # browser tool, by the deviceId it records (P-zqhy.F1: never a label); no tools, no id or no
    # match halts; the manifest picks a fallback.
    "**Whose browser: a dedicated profile.**",
    "An agent never drives a profile signed into the operator's accounts",
    "each run calls `list_connected_browsers`, then `select_browser` on the `deviceId` `## Operator Runtime` records (never a label), before any other browser tool",
    "No Chrome tools, no id, or no match is a **third** halt: `needs_operator` → `pending`, never borrowing another browser",
    "The manifest picks any fallback, never the agent mid-run",
    "Name the instrument in `result.md`; never claim a run you did not make",
    # v41: the review reviews the boundary of the phase (phase-scope's synopsis left
    # with Workflow Commands in v44).
    "**The review reviews the boundary of the phase, not the whole system:**",
    # v46: mid is the default tier, and a retry never returns to mid.
    "**mid the default**", "never returns to mid",
    "QA-sweep route",
    # v69 (P41): the two narrow exceptions a /do-whole-phases run needs -- it parks an open acceptance
    # gate and continues, every other stop halts the run. Without them the contract's `pending` rule
    # and the gate rule would forbid the run.
    "(bar `/do-whole-phases`' parked gate)",
    "(`/do-whole-phases` parks it and continues; every other stop halts the run)",
    # v71 (P42): the reversal of "never fan out slices" -- a declared phase's independent slices run at once.
    "a phase's declared, independent slices may run at once (`do-whole-phase`'s wave), all others alone",
    # v86 (P-mtrt.S3): the explain route creates and runs its phase; its confirmation is the worktree word.
    "Exceptions: `/rotate-backlog` and the explain route (after one confirmation) create and run their phase.",
    "A worktree starts only on the operator's word (for an explain, its confirmation)",
):
    assert required in claude, required
assert "never fan out slices" not in claude, "the contract still forbids fanning out slices"
# P36.F1: the contract's size cap (the operator's P34 pick, 12,288 B by wc -c) was a recorded rule
# no test held, so a release went out 338 B over it; the shipped CLAUDE.md is this file byte for byte.
assert len((root / "payload/contract.md").read_bytes()) <= 12288, "contract over its 12,288 B cap"
# v37 negatives: the MCP-first prescription and the Playwright framing are retired
# from the contract too -- the fact survives only where it explains the escape hatch.
# v41 negative: the whole-list re-run is retired from the contract.
for gone in ("Prefer the **MCP** surface", "scripted Playwright-style automation",
             "runs through Aside, not a script", "re-runs the whole cumulative",
             # P-zqhy: Aside is retired from the contract, procedure and name alike.
             "Aside", "--account <id>",
             # v42 negatives: the mandatory mockup and the "not an approval" return are
             # retired from the contract. (v42 also retired parallel mode's opt-in framing;
             # v43 deliberately restored it, so those two negatives are gone with it --
             # the positive v43 assertions above carry that invariant now.)
             "only PENDING #2 is an approval", "mechanical wait", "can no longer be waived",
             # v43 negatives: the worktree-by-default framing is retired from the contract.
             "runs in its own worktree by default", "enters its worktree at **first execution**",
             # v47 (P26.S4): the DesignSync dispatch wording is gone from the contract.
             # P36.S1: the claude-design tool, Claude Design and DesignSync are retired from it too.
             "never dispatched", "one dispatched span", "claude-design", "Claude Design", "DesignSync"):
    assert gone not in claude, gone
assert "the one design tool, `drafter`" in claude
# v47 (P26.S4): the installer's closing banner names the file loop and the drafter; P36.S1: one tool,
# no claude-design and no register hook.
banner = next(ln for ln in (root / "installer/main.py").read_text().splitlines() if "Visual design:" in ln)
# P36.S6: the banner names the critic and the canvas Artifact; the numbered cards are gone.
for required in ("design-drafter", "docs/reference/design/", "design-critic", "Design canvas Artifact"):
    assert required in banner, required
for gone in ("claude-design", "design-register", "DesignSync", "dashboard", "numbered cards"):
    assert gone not in banner, gone
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
# v61 (P37.S9): Compact Instructions keep the resume card and carry no re-read instruction.
compact = claude.split("## Compact Instructions", 1)[1]
assert "resume card" in compact and "never re-dispatch a running executor" in compact
assert "re-read" not in compact, "Compact Instructions carry a re-read instruction"
PY
then ok "18 Claude skills and their invocation metadata; the v61 skill directories (cores of 8,192 B or less, every reference a core names shipped and none orphaned, the shared do-* reference one source); the prose invariants of the do-*, create-phase, design-cowork (the one drafter tool and its legacy rule, styles, the schema-2 canvas loop with one connected canvas per round and opt-in critique, mockups on request, the Claude in Chrome instrument), parallel-phase (worktree only when asked, hints relayed) and review-phase skills and of both executor bodies; the v71 wave protocol (do-whole-phase's reference/wave.md, DECOMP's disjoint-sets rule, the executor's wave section, the contract's reversal of "never fan out slices"); the v44 contract's never-stubs (acceptance gate, runtime, Claude in Chrome dedicated profile, design, worktree, review boundary); the seed docs; and the v31 Codex-removal negatives"; else bad "Claude skill inventory or metadata, a do-*/create-phase/design-cowork/parallel-phase/review-phase prose invariant, an executor-body invariant, a contract never-stub, a seed-doc invariant, or a Codex-removal negative failed"; fi

# ---------------------------------------------------------------------------
echo "== Test 1: retrofit into a representative existing repo (non-destructive) =="
newtmp R
mkdir -p "$R/src" "$R/scripts" "$R/.claude"
printf '# Existing Project\n\nReal code.\n'          > "$R/README.md"
printf 'print("hello")\n'                            > "$R/src/app.py"
printf 'def util():\n    return 1\n'                  > "$R/scripts/util.py"
printf '# Their Contract\n\nUse 4-space indent.\n'    > "$R/CLAUDE.md"
printf '# Their Contract\n\nUse 4-space indent.\n'    > "$R/AGENTS.md"
printf '{\n  "permissions": {\n    "allow": ["Bash(make:*)"]\n  },\n  "env": {"FOO": "bar"},\n  "hooks": {\n    "PreCompact": [{"matcher": "auto", "hooks": [{"type": "command", "command": "echo foreign-precompact"}]}],\n    "PostToolUse": [{"matcher": "Edit", "hooks": [{"type": "command", "command": "echo foreign-post"}]}]\n  }\n}\n' > "$R/.claude/settings.json"
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
if python3 - "$R/.claude/settings.json" <<'PY'
import json, sys
h = json.load(open(sys.argv[1]))["hooks"]
resume = 'cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py compact-resume || true'
assert h["PreCompact"] == [{"matcher": "auto", "hooks": [{"type": "command", "command": "echo foreign-precompact"}]}], h["PreCompact"]
assert h["PostToolUse"] == [{"matcher": "Edit", "hooks": [{"type": "command", "command": "echo foreign-post"}]}], h["PostToolUse"]
assert h["SessionStart"] == [{"matcher": "compact", "hooks": [{"type": "command", "command": resume, "timeout": 15}]}], h["SessionStart"]
assert json.load(open(sys.argv[1]))["env"]["FOO"] == "bar"
PY
then ok "retrofit merges the resume hook additively: foreign PreCompact/PostToolUse handlers survive untouched, ours (SessionStart compact) present exactly once, no PreCompact of ours (v61)"; else bad "retrofit hooks merge incorrect"; fi
# v56: the project-level auto-compact window ships with the payload; retrofit fills it when the
# adopter's file has none, and a second --update leaves it alone.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["autoCompactWindow"] == 500000, d' "$R/.claude/settings.json" \
  && ok "retrofit sets autoCompactWindow=500000 when the adopter's settings.json has none" || bad "retrofit did not set autoCompactWindow"

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
skill_tree_ok "$R/.claude/skills" exact \
  && ok "retrofit installs every skill as its whole directory: each core's reference files, none orphaned, the shared do-* copy identical" || bad "retrofit skill directories incomplete (core + reference/)"
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
# A settings.json whose `hooks` is not an object is never clobbered: the payload goes to a sidecar.
newtmp HM
mkdir -p "$HM/.claude"
printf '{"permissions": {"allow": ["Bash(make:*)"]}, "hooks": "not-an-object"}\n' > "$HM/.claude/settings.json"
HMS=$(sha "$HM/.claude/settings.json")
out=$(sh "$BOOT" "$HM" --into-existing 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$(sha "$HM/.claude/settings.json")" = "$HMS" ] && [ -f "$HM/.claude/settings.workspace.json" ] \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "PreCompact" not in d["hooks"] and "SessionStart" in d["hooks"]' "$HM/.claude/settings.workspace.json" \
  && ok "a settings.json whose hooks is not an object is left byte-identical and the payload goes to settings.workspace.json" || bad "malformed hooks was clobbered or not sidecarred (rc=$rc) -- $out"

# ---------------------------------------------------------------------------
echo "== Test 5: fresh-install regression (the at-root path, behind --at-root since P29, is unchanged) =="
newtmp F
out=$(sh "$BOOT" "$F" --at-root --name "Fresh" --summary "fresh" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "fresh install exits 0" || bad "fresh install exit=$rc"
( cd "$F" && python3 scripts/workflow.py validate >/dev/null 2>&1 ) && ok "fresh workspace validates" || bad "fresh workspace failed validate"
if python3 - "$F/.claude/settings.json" <<'PY'
import json, sys
h = json.load(open(sys.argv[1]))["hooks"]
resume = 'cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py compact-resume || true'
assert h == {"SessionStart": [{"matcher": "compact", "hooks": [{"type": "command", "command": resume, "timeout": 15}]}]}, h
PY
then ok "a fresh at-root install ships only the resume hook (SessionStart compact -> compact-resume, timeout 15) and no PreCompact (v61: compaction is Claude Code's own)"; else bad "fresh install settings.json hooks wrong"; fi
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["autoCompactWindow"] == 500000' "$F/.claude/settings.json" \
  && ok "a fresh at-root install ships autoCompactWindow=500000 in project settings" || bad "fresh install settings.json lacks autoCompactWindow=500000"
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
# backlog.md's Pointer ends with the installed version; a missing marker reads `unknown`, never an error.
mv_ver=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["workspace_version"])' "$F/works/.workspace-version.json" 2>/dev/null)
newtmp VW; cp -R "$F" "$VW/ws"; rm -f "$VW/ws/works/.workspace-version.json"
vout=$( cd "$VW/ws" && python3 scripts/workflow.py rebuild 2>&1 ); vrc=$?
grep -qxF -e "- Workspace version: \`v$mv_ver\`" "$F/works/backlog.md" && [ "$vrc" -eq 0 ] \
  && grep -qxF -e '- Workspace version: `unknown`' "$VW/ws/works/backlog.md" \
  && ok "backlog.md shows the marker's version (v$mv_ver), and \`unknown\` once the marker is gone" \
  || bad "backlog.md version line wrong (marker v$mv_ver, rebuild rc=$vrc) -- $(grep -F 'Workspace version' "$F/works/backlog.md" "$VW/ws/works/backlog.md") $vout"
# v37: every released section carries a Migration notes line -- the file's own intro
# promises one whenever a sync needs manual steps, and /update-workspace prints exactly
# those lines to adopting repos. v37's sharpest instruction (remove a standing MCP
# registration v36 had prescribed) reaches an adopter through no other channel.
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
skill_tree_ok "$F/.claude/skills" exact \
  && ok "fresh install ships every skill as its whole directory: each core's reference files, none orphaned, the shared do-* copy identical" || bad "fresh install skill directories incomplete (core + reference/)"
[ ! -f "$F/AGENTS.md" ] && [ ! -d "$F/.agents" ] && [ ! -d "$F/.codex" ] \
  && ok "fresh install is Codex-free (no AGENTS.md, no .agents/, no .codex/)" || bad "fresh install still ships Codex machinery"
[ -f "$F/.claude/agents/slice-executor.md" ] && [ ! -e "$F/.claude/agents/slice-executor-mid.md" ] && [ ! -e "$F/.claude/agents/slice-executor-high.md" ] \
  && ok "fresh install ships the one slice-executor (v66), not the retired mid/high pair" || bad "fresh install: slice-executor.md missing or the retired pair present"
grep -q '^model: opus$' "$F/.claude/agents/slice-executor.md" && grep -q '^effort: medium$' "$F/.claude/agents/slice-executor.md" \
  && grep -q '^name: slice-executor$' "$F/.claude/agents/slice-executor.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/design-drafter.md" && grep -q '^effort: high$' "$F/.claude/agents/design-drafter.md" \
  && [ -f "$F/.claude/agents/Explore.md" ] && grep -q '^model: haiku$' "$F/.claude/agents/Explore.md" \
  && grep -q '^effort: xhigh$' "$F/.claude/agents/Explore.md" && grep -qx 'tools: Read, Grep, Glob' "$F/.claude/agents/Explore.md" \
  && ok "fresh install follows the route defaults: slice-executor carries mid opus@medium, design-drafter opus@high, explore haiku@xhigh" || bad "fresh install agent files do not follow the route defaults"
# P26.S2, re-pinned by P36.S8C: the design subagent loads no skill (frontend-design is retired from
# it, its useful lines carried in its craft), so it ships without the Skill tool, and never DesignSync.
[ -f "$F/.claude/agents/design-drafter.md" ] && grep -q '^tools: Read, Edit, Write, Glob, Grep, Bash$' "$F/.claude/agents/design-drafter.md" \
  && ! grep -Eq '^tools: (.*, )?Skill(,.*)?$' "$F/.claude/agents/design-drafter.md" \
  && ! grep -q '^tools: .*DesignSync' "$F/.claude/agents/design-drafter.md" \
  && ok "fresh install ships the design-drafter subagent (no Skill tool, no DesignSync)" || bad "fresh install design-drafter missing, still carries Skill, or carries DesignSync"
# P36.S5B, v61 (P37.S7): the design critic ships on the critic row (opus @ high since v80) and can write only its own file: no Edit.
[ -f "$F/.claude/agents/design-critic.md" ] && grep -q '^model: opus$' "$F/.claude/agents/design-critic.md" \
  && grep -q '^effort: high$' "$F/.claude/agents/design-critic.md" && grep -q '^tools: ' "$F/.claude/agents/design-critic.md" \
  && ! grep -Eq '^tools: (.*, )?Edit(,.*)?$' "$F/.claude/agents/design-critic.md" \
  && ok "fresh install ships the design-critic subagent (opus@high, no Edit in tools)" || bad "fresh install design-critic missing, off its row defaults, or carries Edit"
# An explain phase's critic is the knowledge plugin's knowledge:explain-critic (plugin 0.6.0); the workspace ships none.
[ ! -e "$F/.claude/agents/explain-critic.md" ] \
  && ok "fresh install ships no explain-critic (the plugin's knowledge:explain-critic judges chapters)" \
  || bad "fresh install still ships .claude/agents/explain-critic.md"
# ... and --update lists a copy holding the text v75-v80 shipped (tests/fixtures/v80, as v66's test plants
# tests/fixtures/v65) as stale (ours, unchanged), never deleting it; an edited copy is yours, kept.
newtmp ECR
ECRW="$ECR/ws"
sh "$BOOT" "$ECRW" --at-root --name "ECR" --summary "ecr" >/dev/null 2>&1 || bad "explain-critic retirement: fresh install failed"
cp "$REPO_ROOT/tests/fixtures/v80/explain-critic.md" "$ECRW/.claude/agents/explain-critic.md"
ecr_out=$(sh "$BOOT" "$ECRW" --update 2>&1); ecr_rc=$?
[ "$ecr_rc" -eq 0 ] && printf '%s\n' "$ecr_out" | sed -n '/^  stale (ours, unchanged/,/^  [^ ]/p' \
  | grep -qxE '    - \.claude/agents/explain-critic\.md  \(unchanged since v[0-9]+\)' \
  && [ -f "$ECRW/.claude/agents/explain-critic.md" ] \
  && ok "--update lists the retired explain-critic as stale (by content) and leaves it in place" \
  || bad "--update did not list the retired explain-critic as stale (rc=$ecr_rc) -- $ecr_out"
printf '\nmy own rule\n' >> "$ECRW/.claude/agents/explain-critic.md"
printf '%s\n' "$(sh "$BOOT" "$ECRW" --update 2>&1)" | grep -qxE '    - \.claude/agents/explain-critic\.md  \(differs from what v[0-9]+ shipped\)' \
  && ok "an edited explain-critic is yours, kept" || bad "an edited explain-critic was misclassified"
# v61 (P37.S7): shape pins on the two design agents -- one drafter output (no build-prompt.md bar as legacy), the
# strict self-check and the state-bar rules in the drafter, the render reuse in the critic.
D="$F/.claude/agents/design-drafter.md"; C="$F/.claude/agents/design-critic.md"
! grep -h 'build-prompt' "$D" "$C" | grep -vqiE 'legacy|no `build-prompt.md`' \
  && grep -q -- '--strict' "$D" && grep -q 'self_check=pass' "$D" && grep -q 'never follows the scroll' "$D" && grep -q 'one standalone bar' "$D" \
  && grep -q -- '--states-only' "$C" && grep -q 'sheet.png' "$C" && grep -q '^- open_items:' "$C" && grep -q '^- `open_items`' "$D" \
  && ok "the design agents carry the v61 shape (strict self-check, state-bar rules, render reuse, open_items, no build-prompt.md)" || bad "the design agent files are off the v61 shape"
[ ! -f "$F/.claude/agents/slice-executor-low.md" ] && ok "low tier retired in v23 (absent on fresh install)" || bad "slice-executor-low should be retired but is present"
[ -f "$F/executors.toml" ] && ok "fresh install seeds the tracked executors.toml selection" || bad "fresh install missing executors.toml"
[ -f "$F/.github/workflows/workspace-ci.yml" ] && ok "fresh install seeds the CI workflow" || bad "fresh install missing .github/workflows/workspace-ci.yml"
grep -q '^works/events\.jsonl merge=union$' "$F/.gitattributes" && ok "fresh install seeds .gitattributes with the union rule" || bad "fresh install missing the .gitattributes union rule"
[ ! -f "$F/.env.example" ] && [ ! -f "$F/executors.toml.example" ] && ok "legacy .env.example / executors.toml.example retired (absent on fresh install)" || bad "a legacy tier-config example should be retired but is present"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && ok "sync-agents --check: seeded route config matches live agents" || bad "sync-agents --check failed on a fresh install"
# v80: the seed executors.toml ships verbatim with every row commented out at its default (the cheap-route
# block and its derived seed are gone), so a fresh install runs the engine table; v83 retired the cheap row.
diff -q "$F/executors.toml" "$SRC/executors.toml" >/dev/null && ! grep -q '^\[claude\.' "$F/executors.toml" \
  && grep -qx '# \[claude\.explore\]' "$F/executors.toml" && grep -qx '# effort = "medium"' "$F/executors.toml" && ! grep -q 'claude\.cheap\]$' "$F/executors.toml" \
  && ok "the fresh install's executors.toml is the source verbatim, every row commented out at its default" || bad "the seeded executors.toml is not the verbatim all-commented source"
seed_er=$(cd "$F" && python3 scripts/workflow.py executor-route 2>&1)
printf '%s\n' "$seed_er" | grep -qE '^mid +slice-executor +opus +medium +default$' && ! printf '%s\n' "$seed_er" | grep -q '^cheap ' \
  && ! printf '%s\n' "$seed_er" | grep -q '^override=' \
  && ok "a fresh install has no cheap row (v83) and its mid row is opus@medium, with no override= line" || bad "a fresh install's route table or override lines wrong: $seed_er"
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
( cd "$F" && python3 scripts/workflow.py defer-job --id D1 --title "kind probe" --reason r --trigger t --source manual >/dev/null 2>&1 ) || bad "defer-job probe failed"
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
# v54 one-shot rotate-backlog (P33; v51 made it propose the docs phase): the doc debt is checked FIRST,
# and the first stdout line is the decision, rotate=<branch>. v72 (P43): while debt stands only the
# cleanly archivable phases are archived (archived=), parked work is gone around (parked=), running
# work stops the run; v78: an unstarted docs phase is replaced by one proposal covering all the debt.
# Probed on COPIES of the fixture while P2 still owes (the probe adds phases and archives, and the
# original's later assertions -- docs_debt=none, the STALE clear, archiving -- must stay untouched).
# rotate=refused (a parallel-stream checkout) needs a git branch stamped on a phase; P33.S1's
# result.md walks it on a scratch copy instead.
newtmp ROT; cp -R "$F/." "$ROT/"
rot_p1_order=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['order'])" "$ROT/works/phases/active/P1/phase.json")
rot_out=$( cd "$ROT" && python3 scripts/workflow.py rotate-backlog 2>&1 )
rot_pid=$(printf '%s\n' "$rot_out" | sed -n 's/^phase=//p')
rot_create=$(printf '%s\n' "$rot_out" | sed -n 's/^create: //p')
rot_jump=$(printf '%s' "$rot_create" | sed -n 's/.* --order \([^ ]*\) --consolidates .*/\1/p')
[ "$(printf '%s\n' "$rot_out" | head -1)" = "rotate=create" ] \
  && printf '%s\n' "$rot_out" | grep -q "^docs_phase_proposal=P2$" \
  && printf '%s' "$rot_create" | grep -q -- "new-phase --phase $rot_pid .*--consolidates P2$" \
  && [ -d "$ROT/works/phases/active/P2" ] && [ ! -d "$ROT/works/phases/active/$rot_pid" ] \
  && ok "rotate-backlog checks the debt first: rotate=create names the create command, creates and archives nothing (P2 still active)" \
  || bad "rotate-backlog did not open with rotate=create for the debt-only phase (or created/archived something)"
[ -n "$rot_jump" ] && python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "$rot_jump" "$rot_p1_order" \
  && ok "the create: line carries the queue-jump --order ahead of the planned phase ($rot_jump < $rot_p1_order)" \
  || bad "the create: line carries no --order ahead of the planned phase (got '$rot_jump', planned at $rot_p1_order)"
( cd "$ROT" && eval "$rot_create" >/dev/null 2>&1 ) && grep -q '"consolidates": \[' "$ROT/works/phases/active/$rot_pid/phase.json" \
  && ( cd "$ROT" && python3 scripts/workflow.py next 2>&1 | grep -q "^current_phase=$rot_pid$" ) \
  && ok "the create: line runs as is and the docs phase jumps the queue (next points at $rot_pid)" \
  || bad "the create: line failed, or the docs phase does not sort ahead of the planned phase"
rot_again=$( cd "$ROT" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rot_again" | head -1)" = "rotate=resume docs_phase=$rot_pid" ] \
  && printf '%s\n' "$rot_again" | grep -q "^docs_phase_covered=$rot_pid (pays P2)$" \
  && ! printf '%s\n' "$rot_again" | grep -q "^docs_phase_proposal=" \
  && ! printf '%s\n' "$rot_again" | grep -q "^docs_phase_order=" \
  && ok "re-run with a live docs phase: rotate=resume reports it covering P2, proposes no second docs phase, rewrites no order" \
  || bad "rotate-backlog did not resume the live docs phase (or proposed a duplicate, or rewrote an order already first)"
rot_before=$(ls "$ROT/works/phases/active" | wc -l | tr -d ' ')
( cd "$ROT" && python3 scripts/workflow.py new-phase --phase P9 --name "Wrong docs phase" --objective "pays a phase that owes nothing" --consolidates P1 2>&1 | grep -q "owes no doc consolidation" ) \
  && [ "$(ls "$ROT/works/phases/active" | wc -l | tr -d ' ')" = "$rot_before" ] && [ ! -d "$ROT/works/phases/active/P9" ] \
  && ok "new-phase --consolidates refuses a phase that owes nothing and writes nothing" \
  || bad "new-phase --consolidates accepted (or half-created) a phase that owes no consolidation"
( cd "$ROT" && python3 scripts/workflow.py rotate-backlog --archive-only 2>&1 | grep -qE "docs_phase|^rotate=" ) \
  && bad "rotate-backlog --archive-only printed a rotate= or docs-phase line" \
  || ok "rotate-backlog --archive-only prints no rotate= line and no docs-phase line"
# Replacement and the early sweep, on a copy while $rot_pid is live and unstarted: P5
# owes docs (uncovered), P6 is clean and done, and P1's acceptance gate is open with its REVIEW slice
# in_progress -- parked (accept-gate --open never moves that slice), never running.
newtmp ROTW; cp -R "$ROT/." "$ROTW/"
( cd "$ROTW" && for rp in P5 P6; do python3 scripts/workflow.py new-phase --phase "$rp" --name "Rotate probe $rp" --objective "probe" >/dev/null 2>&1 || exit 1; done \
  && python3 -c 'import sys; from pathlib import Path; p = Path(sys.argv[1]); p.write_text(p.read_text().replace("## Operator Questions", "- operations.md: a durable change (P5.S1)\n\n## Operator Questions", 1))' works/phases/active/P5/phase.md \
  && for rp in P5 P6; do python3 scripts/workflow.py accept-gate "$rp" --waive --note "probe" >/dev/null 2>&1 && python3 scripts/workflow.py set-slice-status "$rp.DECOMP" done >/dev/null 2>&1 \
       && python3 scripts/workflow.py set-slice-status "$rp.REVIEW" done >/dev/null 2>&1 && python3 scripts/workflow.py review-phase "$rp" --verdict pass >/dev/null 2>&1 || exit 1; done \
  && python3 scripts/workflow.py accept-gate P1 --require >/dev/null 2>&1 && python3 scripts/workflow.py set-slice-status P1.REVIEW in_progress >/dev/null 2>&1 \
  && python3 scripts/workflow.py accept-gate P1 --open --walkthrough "walk it" >/dev/null 2>&1 ) || bad "rotate probe: could not build the replacement copy"
rotw_out=$( cd "$ROTW" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rotw_out" | head -1)" = "rotate=replace replaced=$rot_pid" ] && printf '%s\n' "$rotw_out" | grep -q "^archived=P6$" \
  && printf '%s\n' "$rotw_out" | grep -q "^parked=P1 status=pending stop_kind=acceptance-gate$" \
  && [ ! -d "$ROTW/works/phases/active/P6" ] && [ -d "$ROTW/works/phases/active/P2" ] && [ -d "$ROTW/works/phases/active/P5" ] \
  && ok "the early sweep archives a clean done phase while P2's debt stands (archived=P6), and a gate-open phase with its REVIEW in_progress is parked, not running" \
  || bad "rotate-backlog did not archive the clean phase early (or archived a debtor, or stopped for a gate-open REVIEW): $rotw_out"
rotw_pid=$(printf '%s\n' "$rotw_out" | sed -n 's/^phase=//p'); rotw_create=$(printf '%s\n' "$rotw_out" | sed -n 's/^create: //p')
printf '%s\n' "$rotw_out" | grep -q "^docs_phase_replaced=$rot_pid (paid P2; " && printf '%s\n' "$rotw_out" | grep -q "^docs_phase_proposal=P2, P5$" \
  && [ ! -d "$ROTW/works/phases/active/$rot_pid" ] && grep -q '"type": "docs_phase_replaced"' "$ROTW/works/events.jsonl" \
  && ( cd "$ROTW" && eval "$rotw_create" >/dev/null 2>&1 ) && grep -q '"consolidates": \[' "$ROTW/works/phases/active/$rotw_pid/phase.json" \
  && ok "an unstarted docs phase is replaced: its folder removed (logged), one proposal covering P2 and the new P5 debt, its create: line run as is (v78)" \
  || bad "rotate-backlog did not replace the unstarted docs phase with one covering P2 and P5: $rotw_out"
rotw_before=$( cd "$ROTW" && find works docs -type f | sort | xargs cat | sha_stdin )
rotw_again=$( cd "$ROTW" && python3 scripts/workflow.py rotate-backlog 2>&1 )
rotw_after=$( cd "$ROTW" && find works docs -type f | sort | xargs cat | sha_stdin )
( cd "$ROTW" && python3 scripts/workflow.py new-phase --phase P7 --name "Rotate probe P7" --objective probe >/dev/null 2>&1 \
  && python3 -c 'import sys; from pathlib import Path; p = Path(sys.argv[1]); p.write_text(p.read_text().replace("## Operator Questions", "- qa.md: a durable change (P7.S1)\n\n## Operator Questions", 1))' works/phases/active/P7/phase.md \
  && python3 scripts/workflow.py accept-gate P7 --waive --note probe >/dev/null 2>&1 && python3 scripts/workflow.py set-slice-status P7.DECOMP done >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status P7.REVIEW done >/dev/null 2>&1 && python3 scripts/workflow.py review-phase P7 --verdict pass >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status "$rotw_pid.DECOMP" done >/dev/null 2>&1 \
  && python3 scripts/workflow.py new-slice --phase "$rotw_pid" --slice "$rotw_pid.S1" --name ops --kind docs --risk low >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status "$rotw_pid.S1" done >/dev/null 2>&1 ) || bad "rotate probe: could not start the docs phase"
rotw_started=$( cd "$ROTW" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rotw_again" | head -1)" = "rotate=resume docs_phase=$rotw_pid" ] && [ -n "$rotw_before" ] && [ "$rotw_before" = "$rotw_after" ] \
  && [ "$(printf '%s\n' "$rotw_started" | head -1)" = "rotate=resume docs_phase=$rotw_pid" ] && printf '%s\n' "$rotw_started" | grep -q "^docs_debt_waiting=P7 " \
  && [ -d "$ROTW/works/phases/active/$rotw_pid" ] \
  && ok "with nothing new owed a re-run resumes and writes nothing, and a started docs phase is never replaced: it finishes first while new debt waits" \
  || bad "rotate-backlog replaced a started docs phase, or a no-debt re-run wrote: $rotw_again / $rotw_started"
( cd "$ROT" && python3 scripts/workflow.py set-phase-status P1 pending >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status P1.S1 in_progress >/dev/null 2>&1 ) || bad "rotate probe: could not put P1 mid-flight"
rot_mid=$( cd "$ROT" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rot_mid" | head -1)" = "rotate=stop_midflight midflight=P1.S1:in_progress" ] \
  && printf '%s\n' "$rot_mid" | grep -q "^parked=P1 status=pending stop_kind=untyped$" \
  && printf '%s\n' "$rot_mid" | grep -q "^stopped_before=resume docs_phase=$rot_pid$" \
  && [ -d "$ROT/works/phases/active/P2" ] \
  && ok "an in_progress slice elsewhere stops the run: rotate=stop_midflight lists only the running slice, its pending phase is a parked= line" \
  || bad "rotate-backlog did not stop for another phase's running slice (or listed the parked phase as running): $rot_mid"
( cd "$ROT" && python3 scripts/workflow.py set-slice-status P1.S1 pending --stop-kind decision --on-words "the vendor's reply decides" >/dev/null 2>&1 ) \
  || bad "rotate probe: could not park P1.S1 under a typed stop"
rot_park=$( cd "$ROT" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rot_park" | head -1)" = "rotate=resume docs_phase=$rot_pid" ] \
  && printf '%s\n' "$rot_park" | grep -q "^parked=P1 status=pending stop_kind=untyped$" \
  && printf '%s\n' "$rot_park" | grep -q "^parked=P1.S1 status=pending stop_kind=decision$" \
  && ok "parked work is gone around: a pending phase and a slice pending under a typed stop give rotate=resume and one parked= line each" \
  || bad "rotate-backlog did not go around parked work: $rot_park"
# The uncommitted-edits check reads git, so it runs on a git init-ed copy (the ROT copies have no git,
# where nothing is dirty): a clean tree resumes, an untracked product file beside the parked slice stops.
newtmp ROTG; cp -R "$ROT/." "$ROTG/"
( cd "$ROTG" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
  && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "rotate baseline" >/dev/null 2>&1 ) || bad "rotate probe: could not git init the dirt copy"
rotg_clean=$( cd "$ROTG" && python3 scripts/workflow.py rotate-backlog 2>&1 | head -1 )
mkdir -p "$ROTG/src" && printf 'x = 1\n' > "$ROTG/src/app.py"
rotg_dirty=$( cd "$ROTG" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$rotg_clean" = "rotate=resume docs_phase=$rot_pid" ] \
  && [ "$(printf '%s\n' "$rotg_dirty" | head -1)" = "rotate=stop_uncommitted uncommitted=1" ] \
  && printf '%s\n' "$rotg_dirty" | grep -qx "  A src/app.py" \
  && printf '%s\n' "$rotg_dirty" | grep -q "^parked=P1.S1 status=pending stop_kind=decision$" \
  && printf '%s\n' "$rotg_dirty" | grep -q "^nothing was created, replaced or reordered" \
  && ok "parked work beside an uncommitted product file stops the run (rotate=stop_uncommitted names the path); a clean tree resumes" \
  || bad "rotate-backlog did not stop for uncommitted product edits beside parked work (clean: $rotg_clean): $rotg_dirty"
( cd "$ROT" && python3 scripts/workflow.py set-slice-status P1.S1 todo >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-phase-status P1 planned >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status "$rot_pid.DECOMP" in_progress >/dev/null 2>&1 ) || bad "rotate probe: could not start the docs phase's DECOMP"
rot_own=$( cd "$ROT" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rot_own" | head -1)" = "rotate=resume docs_phase=$rot_pid" ] \
  && ok "the docs phase's own in_progress slice is not mid-flight (rotate=resume)" \
  || bad "the docs phase's own in_progress slice stopped the run"
( cd "$ROT" && python3 scripts/workflow.py set-slice-status "$rot_pid.DECOMP" done >/dev/null 2>&1 \
  && python3 scripts/workflow.py docs-consolidated P2 >/dev/null 2>&1 ) || bad "rotate probe: docs-consolidated P2 failed"
rot_paid=$( cd "$ROT" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rot_paid" | head -1)" = "rotate=resume docs_phase=$rot_pid" ] && printf '%s\n' "$rot_paid" | grep -q "^archived=P2$" \
  && [ ! -d "$ROT/works/phases/active/P2" ] && [ -d "$ROT/works/phases/active/$rot_pid" ] \
  && ok "a docs phase that has paid its debt but not passed its review still resumes; the paid phase is archived early (archived=P2)" \
  || bad "a paid docs phase short of its review did not resume (or the paid phase was not archived early): $rot_paid"
( cd "$ROT" && python3 scripts/workflow.py accept-gate "$rot_pid" --waive --note "docs phase" >/dev/null 2>&1 \
  && python3 scripts/workflow.py set-slice-status "$rot_pid.REVIEW" done >/dev/null 2>&1 \
  && python3 scripts/workflow.py review-phase "$rot_pid" --verdict pass >/dev/null 2>&1 ) || bad "rotate probe: could not pass the docs phase's review"
rot_arch=$( cd "$ROT" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rot_arch" | head -1)" = "rotate=archive" ] && [ "$(printf '%s\n' "$rot_arch" | tail -1)" = "docs_phase=none" ] \
  && [ ! -d "$ROT/works/phases/active/P2" ] && [ ! -d "$ROT/works/phases/active/$rot_pid" ] && [ -d "$ROT/works/phases/active/P1" ] \
  && ok "once the debt is paid and the docs phase is done, rotate=archive archives the docs phase and leaves the open phase" \
  || bad "rotate-backlog did not archive the done docs phase at the end"
# A docs phase created before the queue jump (no --order: the default max + 1, behind planned work)
# is moved ahead on resume: one order write, printed and logged, then idempotent.
newtmp ROT2; cp -R "$F/." "$ROT2/"
( cd "$ROT2" && python3 scripts/workflow.py new-phase --phase P7 --name "Docs phase behind planned work" --objective "pays P2" --consolidates P2 >/dev/null 2>&1 ) || bad "rotate probe: new-phase --consolidates P2 failed"
rot2_old=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['order'])" "$ROT2/works/phases/active/P7/phase.json")
rot2_out=$( cd "$ROT2" && python3 scripts/workflow.py rotate-backlog 2>&1 )
[ "$(printf '%s\n' "$rot2_out" | head -1)" = "rotate=resume docs_phase=P7" ] \
  && printf '%s\n' "$rot2_out" | grep -q "^docs_phase_order=P7 $rot2_old -> 0$" \
  && grep -q '"order": 0,' "$ROT2/works/phases/active/P7/phase.json" \
  && grep -q '"type": "phase_reordered", "phase": "P7"' "$ROT2/works/events.jsonl" \
  && ( cd "$ROT2" && python3 scripts/workflow.py next 2>&1 | grep -q "^current_phase=P7$" ) \
  && ok "resume re-asserts the queue jump on a docs phase behind planned work (order $rot2_old -> 0, logged, next points at it)" \
  || bad "resume did not move the docs phase ahead of the planned phase"
( cd "$ROT2" && python3 scripts/workflow.py rotate-backlog 2>&1 | grep -q "^docs_phase_order=" ) \
  && bad "the queue-jump re-assert rewrote an order that already sorts first" \
  || ok "the queue-jump re-assert is idempotent (no second order write)"
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
big_path=$( cd "$F" && python3 scripts/workflow.py doc-new-version --doc architecture --summary "oversized probe" --source manual 2>&1 | sed -n 's/^edit_path=//p' )
python3 - "$F/$big_path" <<'PY2'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text() + "\n## Oversized probe section\n\n" + ("filler line to push this section past the threshold\n" * 240))
PY2
( cd "$F" && python3 scripts/workflow.py rebuild-docs >/dev/null 2>&1 ) || bad "rebuild-docs failed after the oversized probe"
big_out=$( cd "$F" && python3 scripts/workflow.py validate 2>&1 ); big_rc=$?
printf '%s\n' "$big_out" | grep -q "warning: oversized_doc_sections=1" \
  && printf '%s\n' "$big_out" | grep -q "architecture.md '## Oversized probe section'" \
  && [ "$big_rc" -eq 0 ] \
  && ok "validate names an oversized doc section (doc, heading, size) and still exits 0" \
  || bad "validate did not warn exit-code-neutrally about an oversized doc section (rc=$big_rc)"
( cd "$F" && python3 scripts/workflow.py doc-new-version --doc architecture --summary "split probe" --source manual 2>&1 | grep -q "note: oversized_doc_sections=1" ) \
  && ok "doc-new-version repeats the oversized-section note where the split can land" \
  || bad "doc-new-version did not flag the oversized section it is about to hand over for editing"
# v79: the doc set is five; a retired doc is refused (naming its successor) and nothing is written.
ret_out=$( cd "$F" && python3 scripts/workflow.py doc-new-version --doc backend --summary "retired probe" --source manual 2>&1 ); ret_rc=$?
[ "$ret_rc" -ne 0 ] && printf '%s\n' "$ret_out" | grep -q "backend is a retired doc (v79)" && printf '%s\n' "$ret_out" | grep -q -- "--doc architecture" \
  && [ ! -e "$F/docs/versions/backend" ] && [ "$(ls "$F/docs/current" | wc -l | tr -d ' ')" = "5" ] \
  && ok "a fresh install seeds five docs, and doc-new-version refuses a retired doc, naming its successor, writing nothing (v79)" \
  || bad "retired doc not refused, or the fresh doc set is not five (rc=$ret_rc) -- $ret_out"
# v39 last-updated marker at write time: the HEAD sha lands in the version frontmatter (which
# rebuild-docs copies verbatim into docs/current) AND in the index entry. Needs a repo with a
# commit, so the fixture becomes one here; the later dashboard test re-inits it harmlessly.
( cd "$F" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
    && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "marker baseline" >/dev/null 2>&1 ) \
  || bad "v39 marker probe: could not make the fixture a git repo"
head_sha=$( cd "$F" && git rev-parse HEAD 2>/dev/null )
marker_path=$( cd "$F" && python3 scripts/workflow.py doc-new-version --doc decisions --summary "marker probe" --source manual 2>&1 | sed -n 's/^edit_path=//p' )
[ -n "$head_sha" ] && grep -q "^commit: $head_sha\$" "$F/$marker_path" \
  && grep -q "\"commit\": \"$head_sha\"" "$F/docs/index.json" \
  && grep -q "^commit: $head_sha\$" "$F/docs/current/decisions.md" \
  && ok "doc-new-version records the HEAD sha in the frontmatter, docs/current and the index entry" \
  || bad "doc-new-version did not record the commit sha"
# ...and where git cannot answer at all (no git on PATH), the version is still written: the sha is
# recorded as unknown/null and nothing raises.
nogit_py=$( command -v python3 )
nogit_path=$( cd "$F" && PATH="/var/empty" "$nogit_py" scripts/workflow.py doc-new-version --doc decisions --summary "no git probe" --source manual 2>&1 | sed -n 's/^edit_path=//p' )
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
# v53 route table (P32.S1): executors.toml overrides the engine's rows key by key, sync-agents
# writes the four managed agent files from them (v66: one slice-executor, carrying the mid row), and executor-route prints the routing decision,
# writing nothing. Its probes unset the environment variables it reads, so a run inside an ocx
# session (a loopback ANTHROPIC_BASE_URL) or on Bedrock still sees the plain table.
erenv() { env -u ANTHROPIC_BASE_URL -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE -u CLAUDE_CODE_USE_BEDROCK -u CLAUDE_CODE_USE_VERTEX -u CLAUDE_CODE_USE_FOUNDRY -u ANTHROPIC_DEFAULT_HAIKU_MODEL "$@"; }
er() { ( cd "$F" && erenv python3 scripts/workflow.py executor-route "$@" 2>&1 ); }
rm -f "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) \
  && grep -q '^model: opus$' "$F/.claude/agents/slice-executor.md" && grep -q '^effort: medium$' "$F/.claude/agents/slice-executor.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/design-drafter.md" && grep -q '^effort: high$' "$F/.claude/agents/design-drafter.md" \
  && grep -q '^model: haiku$' "$F/.claude/agents/Explore.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/Explore.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/design-critic.md" && grep -q '^effort: high$' "$F/.claude/agents/design-critic.md" \
  && ok "no executors.toml: sync-agents writes the route defaults (slice-executor mid opus@medium, design-drafter opus@high, design-critic opus@high, Explore haiku@xhigh)" \
  || bad "the route defaults matrix is wrong"
printf '[claude.high]\nmodel = "fable"\n' > "$F/executors.toml"
sa_out=$( cd "$F" && python3 scripts/workflow.py sync-agents 2>&1 ); er_out=$(er P1.DECOMP)
printf '%s\n' "$sa_out" | grep -q 'already in sync; nothing written' && grep -q '^model: opus$' "$F/.claude/agents/slice-executor.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/design-drafter.md" \
  && printf '%s\n' "$er_out" | grep -qx 'model=fable' && printf '%s\n' "$er_out" | grep -qx 'subagent_type=slice-executor' \
  && ok "a [claude.high] alias override writes no agent file (v66: high is passed per dispatch) and shows in executor-route; design-drafter keeps its own row" \
  || bad "a [claude.high] override wrote a file, reached design-drafter, or is missing from executor-route: $sa_out / $er_out"
printf '[claude.high]\nmodel = "claude-opus-5-5"\n' > "$F/executors.toml"
hi_out=$( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 ); hi_rc=$?
[ "$hi_rc" -ne 0 ] && printf '%s\n' "$hi_out" | grep -q 'since v66 one executor file carries the mid row' \
  && ok "a full model id on [claude.high] is refused with the v66 migration line" || bad "[claude.high] full id not refused (rc=$hi_rc): $hi_out"
printf '[claude.mid]\nmodel = "claude-sonnet-5-5"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) && grep -q '^model: claude-sonnet-5-5$' "$F/.claude/agents/slice-executor.md" \
  && ok "a full model id on [claude.mid] is accepted and written into slice-executor.md" || bad "[claude.mid] full id was refused or not written to slice-executor.md"
printf '[claude.design]\nmodel = "fable"\neffort = "max"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) && grep -q '^model: fable$' "$F/.claude/agents/design-drafter.md" \
  && grep -q '^effort: max$' "$F/.claude/agents/design-drafter.md" && grep -q '^effort: medium$' "$F/.claude/agents/slice-executor.md" \
  && ok "a [claude.design] override patches design-drafter alone" || bad "a [claude.design] override did not reach design-drafter, or reached slice-executor"
printf 'mode = "flex"\n' > "$F/executors.toml"
mode_out=$( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 ); mode_rc=$?
[ "$mode_rc" -ne 0 ] && printf '%s\n' "$mode_out" | grep -q 'retired in workspace v53' \
  && ok "a leftover mode = line is refused with the v53 migration message" || bad "mode = \"flex\" was not refused with the v53 migration (rc=$mode_rc): $mode_out"
printf '[claude.low]\nmodel = "sonnet"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'retired in workspace v23' ) && ok "retired [claude.low] section rejected with a migration message" || bad "[claude.low] should be rejected as a retired tier"
printf '[codex.high]\nmodel = "gpt-5.6-sol"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'removed in workspace v31' ) && ok "leftover [codex.*] section rejected with the v31 migration message" || bad "[codex.*] should be rejected as removed support"
printf '[claude.cheap]\nmodel = "haiku"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'the cheap row was retired in workspace v83' ) \
  && ok "a leftover [claude.cheap] is refused with the v83 migration message" || bad "[claude.cheap] should be rejected as a retired row"
printf '[claude.research]\nmodel = "claude-opus-5-5"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'must be an Agent-tool alias' ) \
  && ok "a full model id on the research row is refused (it runs a file the mid row owns, so an alias only)" || bad "[claude.research] accepted a full model id"
printf '[claude.research]\neffort = "hgih"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'effort must be one of' ) \
  && ok "an effort outside the Agent tool's levels is refused" || bad "[claude.research] accepted an unknown effort"
printf '[claude.nope]\nmodel = "opus"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check 2>&1 | grep -q 'unknown route' ) \
  && ok "an unknown [claude.<row>] is refused" || bad "[claude.nope] was accepted"
rm -f "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) || bad "sync-agents failed restoring the route defaults"
er_out=$(er)
[ "$(printf '%s\n' "$er_out" | grep -cE '^(high|research|design|critic|judge|mid|explore) ')" = "7" ] && ! printf '%s\n' "$er_out" | grep -q '^cheap ' && printf '%s\n' "$er_out" | grep -qx 'proxy=none' \
  && printf '%s\n' "$er_out" | grep -qE '^route +agent +model +effort +source$' \
  && printf '%s\n' "$er_out" | grep -qE '^design +design-drafter +opus +high +default$' \
  && printf '%s\n' "$er_out" | grep -qE '^critic +design-critic +opus +high +default$' && printf '%s\n' "$er_out" | grep -qE '^judge +design-critic +opus +high +default$' \
  && printf '%s\n' "$er_out" | grep -qE '^high +slice-executor +opus +high +default$' && printf '%s\n' "$er_out" | grep -qE '^research +slice-executor +opus +high +default$' \
  && printf '%s\n' "$er_out" | grep -qE '^mid +slice-executor +opus +medium +default$' \
  && printf '%s\n' "$er_out" | grep -qE '^explore +Explore +haiku +xhigh +default$' \
  && ! printf '%s\n' "$er_out" | grep -q '^warning=fairness' && ! printf '%s\n' "$er_out" | grep -q 'tier' && ! printf '%s\n' "$er_out" | grep -q '^fallback=' \
  && ok "executor-route (bare) prints the seven-row route table with its agent column, no tier and no cheap row (v80 defaults: every opus row @high, mid opus@medium, explore haiku@xhigh; v83) and proxy=none" || bad "executor-route bare table wrong: $er_out"
er_out=$(er P1.DECOMP)
printf '%s\n' "$er_out" | grep -qx 'route=high' && ! printf '%s\n' "$er_out" | grep -q '^tier=' \
  && printf '%s\n' "$er_out" | grep -qx 'subagent_type=slice-executor' && printf '%s\n' "$er_out" | grep -qx 'model=opus' \
  && printf '%s\n' "$er_out" | grep -qx 'effort=high' && printf '%s\n' "$er_out" | grep -qx 'attribution=Claude Opus 5.5' \
  && ok "executor-route sends a decomposition slice to the high row (slice-executor, opus@high, Claude Opus 5.5, no tier= line)" || bad "executor-route P1.DECOMP wrong: $er_out"
er_out=$(er P1.S2)
printf '%s\n' "$er_out" | grep -qx 'route=research' && printf '%s\n' "$er_out" | grep -qx 'effort=high' \
  && printf '%s\n' "$er_out" | grep -qx 'subagent_type=slice-executor' \
  && ok "executor-route sends a research slice to the research row (slice-executor, opus@high)" || bad "executor-route research slice wrong: $er_out"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P1 --slice P1.S9 --name "docs probe" --kind docs --risk low >/dev/null 2>&1 ) \
  || bad "route probe: new-slice P1.S9 (docs, low) failed"
er_out=$(er P1.S9)
printf '%s\n' "$er_out" | grep -qx 'route=mid' && printf '%s\n' "$er_out" | grep -qx 'reason=kind docs rated low' && ! printf '%s\n' "$er_out" | grep -q '^tier=' \
  && printf '%s\n' "$er_out" | grep -qx 'subagent_type=slice-executor' && printf '%s\n' "$er_out" | grep -qx 'model=opus' \
  && printf '%s\n' "$er_out" | grep -qx 'effort=medium' && printf '%s\n' "$er_out" | grep -qx 'attribution=Claude Opus 5.5' && ! printf '%s\n' "$er_out" | grep -q '^fallback=' \
  && ok "a low docs slice runs on the mid row, opus@medium (v83: no Haiku slice row)" || bad "executor-route low docs slice wrong: $er_out"
er_out=$( cd "$F" && erenv CLAUDE_CODE_USE_BEDROCK=1 python3 scripts/workflow.py executor-route P1.S9 2>&1 )
er_x=$( cd "$F" && erenv CLAUDE_CODE_USE_FOUNDRY=1 python3 scripts/workflow.py executor-route --explore 2>&1 )
printf '%s\n' "$er_out" | grep -qx 'model=opus' && ! printf '%s\n' "$er_out" | grep -q '^fallback=' \
  && printf '%s\n' "$er_x" | grep -qx 'model=haiku' && ! printf '%s\n' "$er_x" | grep -q '^fallback=' \
  && ok "on Bedrock and Foundry nothing falls back: a low docs slice stays on the mid row and explore keeps haiku" || bad "platform fallback wrong: $er_out / $er_x"
er_out=$(er P1.S9 --retry)
printf '%s\n' "$er_out" | grep -qx 'route=high' && printf '%s\n' "$er_out" | grep -qx 'attempt=2' && printf '%s\n' "$er_out" | grep -qx 'reason=second attempt' \
  && printf '%s\n' "$er_out" | grep -qx 'subagent_type=slice-executor' && printf '%s\n' "$er_out" | grep -qx 'model=opus' \
  && ok "executor-route --retry sends a second attempt to the high row (the same slice-executor, on opus)" || bad "executor-route --retry wrong: $er_out"
printf '[claude.mid]\nmodel = "sonnet"\neffort = "high"\n' > "$F/executors.toml"
er_out=$(er P1.S9)
printf '%s\n' "$er_out" | grep -qx 'model=sonnet' && printf '%s\n' "$er_out" | grep -qx 'attribution=Claude Sonnet 5.5' \
  && ok "a [claude.mid] override carries a low docs slice with it (sonnet, attributed to Claude Sonnet 5.5)" || bad "executor-route mid override on a docs slice wrong: $er_out"
er_out=$( cd "$F" && env -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE ANTHROPIC_BASE_URL=http://127.0.0.1:10100 python3 scripts/workflow.py executor-route P1.S9 2>&1 )
printf '%s\n' "$er_out" | grep -qx 'model=sonnet' && ! printf '%s\n' "$er_out" | grep -q '^fallback=' \
  && ok "behind a loopback ANTHROPIC_BASE_URL (ocx/Kiro) a slice row never falls back" || bad "executor-route proxy moved a slice row: $er_out"
er_out=$(er)
printf '%s\n' "$er_out" | grep -qx 'override=mid sonnet@high (default opus@medium)' && [ "$(printf '%s\n' "$er_out" | grep -c '^override=')" = "1" ] \
  && ok "the bare table prints an override= line for the row executors.toml pins, beside its default" || bad "executor-route override= line wrong: $er_out"
printf '[claude.mid]\nmodel = "opus"\neffort = "medium"\n' > "$F/executors.toml"
er_out=$(er)
printf '%s\n' "$er_out" | grep -q '^override=mid opus@medium same as the default ' \
  && ok "a row set to its default prints override=... same as the default" || bad "executor-route same-as-default override wrong: $er_out"
er_out=$( cd "$F" && env -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE ANTHROPIC_BASE_URL=http://127.0.0.1:10100 python3 scripts/workflow.py executor-route --explore 2>&1 )
printf '%s\n' "$er_out" | grep -qx 'model=sonnet' && printf '%s\n' "$er_out" | grep -qx 'subagent_type=Explore' \
  && ok "behind the same proxy executor-route --explore falls back to sonnet" || bad "executor-route --explore proxy fallback wrong: $er_out"
er_out=$(er --drafter)
printf '%s\n' "$er_out" | grep -qx 'agent=design-drafter' && printf '%s\n' "$er_out" | grep -qx 'route=design' \
  && ! printf '%s\n' "$er_out" | grep -q '^tier=' && printf '%s\n' "$er_out" | grep -qx 'subagent_type=design-drafter' \
  && printf '%s\n' "$er_out" | grep -qx 'model=opus' && printf '%s\n' "$er_out" | grep -qx 'effort=high' \
  && ok "executor-route --drafter names design-drafter on its own design row (no tier= line, opus@high)" || bad "executor-route --drafter wrong: $er_out"
# P36.S5B, P39.S1, v75: the critic and the judge both run design-critic; either may share the drafter's model.
er_out=$(er --critic); er_j=$(er --judge)
printf '%s\n' "$er_out" | grep -qx 'route=critic' && printf '%s\n' "$er_out" | grep -qx 'subagent_type=design-critic' \
  && printf '%s\n' "$er_out" | grep -qx 'model=opus' && printf '%s\n' "$er_out" | grep -qx 'effort=high' \
  && printf '%s\n' "$er_j" | grep -qx 'route=judge' && printf '%s\n' "$er_j" | grep -qx 'subagent_type=design-critic' \
  && printf '%s\n' "$er_j" | grep -qx 'model=opus' && printf '%s\n' "$er_j" | grep -qx 'effort=high' && ! printf '%s\n' "$er_j" | grep -q '^tier=' \
  && ok "executor-route --critic (opus@high) and --judge (opus@high) both dispatch design-critic" || bad "executor-route --critic/--judge wrong: $er_out / $er_j"
printf '[claude.critic]\nmodel = "opus"\neffort = "xhigh"\n' > "$F/executors.toml"
er_out=$( cd "$F" && env -u ANTHROPIC_BASE_URL python3 scripts/workflow.py executor-route --critic 2>&1 ); er_rc=$?
[ "$er_rc" -eq 0 ] && printf '%s\n' "$er_out" | grep -qx 'model=opus' \
  && ! printf '%s\n' "$(er)" | grep -q '^warning=fairness' \
  && ok "a critic on the drafter's model is accepted (exit 0, model=opus) and the bare table does not warn (v75)" || bad "the critic on the drafter's model was refused or warned (rc=$er_rc): $er_out"
rm -f "$F/executors.toml"
# P39.S1: the judge is exempt from the critic-vs-drafter rule -- at the defaults it is Opus over the Opus drafter.
er_out=$( cd "$F" && env -u ANTHROPIC_BASE_URL -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE python3 scripts/workflow.py executor-route --judge 2>&1 ); er_rc=$?
[ "$er_rc" -eq 0 ] && printf '%s\n' "$er_out" | grep -qx 'model=opus' && ! printf '%s\n' "$er_out" | grep -q 'warning=fairness' \
  && ! printf '%s\n' "$er_out" | grep -q '^skip=' \
  && ok "the judge on the drafter's model (opus over opus) is allowed: executor-route --judge exits 0 with no fairness warning" || bad "executor-route --judge refused or warned at the defaults (rc=$er_rc): $er_out"
# The loopback-proxy skip needs a Fable judge: it never fires at the default (Opus), only on a Fable override.
er_out=$( cd "$F" && env -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE ANTHROPIC_BASE_URL=http://127.0.0.1:10100 python3 scripts/workflow.py executor-route --judge 2>&1 ); er_rc=$?
[ "$er_rc" -eq 0 ] && ! printf '%s\n' "$er_out" | grep -q '^skip=' \
  && ok "behind a loopback proxy the default (opus) judge prints no skip= and exits 0" || bad "executor-route --judge proxy at the default wrong (rc=$er_rc): $er_out"
printf '[claude.judge]\nmodel = "fable"\n' > "$F/executors.toml"
er_out=$( cd "$F" && env -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE ANTHROPIC_BASE_URL=http://127.0.0.1:10100 python3 scripts/workflow.py executor-route --judge 2>&1 ); er_rc=$?
[ "$er_rc" -eq 0 ] && printf '%s\n' "$er_out" | grep -q '^skip=yes reason=loopback ' \
  && ok "behind a loopback proxy (no Fable) a Fable-overridden judge prints skip=yes and exits 0" || bad "executor-route --judge proxy skip wrong (rc=$er_rc): $er_out"
rm -f "$F/executors.toml"
( cd "$F" && env -u ANTHROPIC_BASE_URL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE CLAUDE_CODE_EFFORT_LEVEL=high python3 scripts/workflow.py executor-route P1.DECOMP 2>&1 | grep -q '^warning=CLAUDE_CODE_EFFORT_LEVEL' ) \
  && ok "executor-route warns that CLAUDE_CODE_EFFORT_LEVEL outranks every per-dispatch effort" || bad "executor-route did not warn on CLAUDE_CODE_EFFORT_LEVEL"
cp "$SRC/executors.toml" "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) || bad "sync-agents failed on the repo's own executors.toml"
er_out=$(er)
printf '%s\n' "$er_out" | grep -qE '^mid +slice-executor +opus +medium +default$' && printf '%s\n' "$er_out" | grep -qx 'agent files: in sync' \
  && ! printf '%s\n' "$er_out" | grep -q '^override=' \
  && ok "the shipped executors.toml sets no row: the engine defaults, no override= line, agent files in sync" || bad "executor-route on the shipped executors.toml wrong: $er_out"
( cd "$F" && python3 scripts/workflow.py executor-mode 2>&1 | grep -q 'invalid choice' ) \
  && ok "executor-mode is gone from the engine (v53: executor-route replaces it)" || bad "the engine still accepts executor-mode"
# v61 dispatch record + transcript meter (P37.S2): record-dispatch keeps only the verdict (the pre-v61
# flags parse and are named as ignored); dispatch-summary meters the main thread and the spans from
# Claude Code's transcripts -- one request per message id with its largest output, spans attributed by
# their `slice:` line, list-priced (an unknown model never guessed), a span ending on a usage limit is
# `limit` -- and with no transcripts prints one line plus the recorded tables (old records stay readable).
rd() { ( cd "$F" && CLAUDE_CONFIG_DIR="$F/.no-claude-config" python3 scripts/workflow.py "$@" 2>&1 ); }
rd_out=$(rd record-dispatch P1.DECOMP --verdict done --tokens 5 --route high); rd_rc=$?; rd_last=$(tail -1 "$F/works/events.jsonl")
[ "$rd_rc" -eq 0 ] && printf '%s\n' "$rd_out" | grep -qx 'recorded=executor_dispatched' \
  && printf '%s\n' "$rd_out" | grep -qx 'ignored: --route --tokens (v61 meters spans from transcripts)' \
  && printf '%s\n' "$rd_last" | grep -q '"verdict": "done"' && ! printf '%s\n' "$rd_last" | grep -q '"tokens"' \
  && ok "record-dispatch --verdict done --tokens 5 records the verdict only and names the old flags ignored" || bad "record-dispatch wrong (rc=$rd_rc): $rd_out / $rd_last"
rd record-dispatch P9.S1 --verdict done >/dev/null; rc1=$?
[ "$rc1" -ne 0 ] && ok "record-dispatch refuses an unknown slice" || bad "record-dispatch accepted an unknown slice"
printf '%s\n' '{"ts": "2026-01-01T00:00:00+00:00", "type": "executor_dispatched", "slice": "P1.S9", "phase": "P1", "kind": "docs", "route": "cheap", "model": "haiku", "effort": "high", "attempt": 1, "verdict": "escalate", "tokens": 900}' >> "$F/works/events.jsonl"
printf 'not json\n' >> "$F/works/events.jsonl"
ds_out=$(rd dispatch-summary); ds_rc=$?
[ "$ds_rc" -eq 0 ] && printf '%s\n' "$ds_out" | grep -q '^transcripts=none found under ' && printf '%s\n' "$ds_out" | grep -qx 'records=2' \
  && printf '%s\n' "$ds_out" | grep -qE '^cheap +1 +0 +1 ' && printf '%s\n' "$ds_out" | grep -qx 'skipped_lines=1' \
  && ok "dispatch-summary with no transcripts: one line, the recorded tables, an old record readable, a malformed line skipped" || bad "dispatch-summary without transcripts wrong (rc=$ds_rc): $ds_out"
rd dispatch-summary --phase P7 >/dev/null; rc1=$?
[ "$rc1" -eq 1 ] && ok "dispatch-summary --phase: an unknown phase exits 1" || bad "dispatch-summary --phase P7 rc=$rc1"
newtmp MT
cp -R "$F" "$MT/ws"
( cd "$MT/ws" && python3 scripts/workflow.py new-slice --phase P1 --slice P1.S7 --name "meter probe" --kind implementation --risk low >/dev/null 2>&1 )
python3 - "$MT" <<'PY'
import json, os, sys
mt = sys.argv[1]
ev = os.path.join(mt, "ws", "works", "events.jsonl")
with open(ev, "a") as f:
    for ts, old, new in (("2026-01-01T10:00:00+00:00", "todo", "in_progress"), ("2026-01-01T11:00:00+00:00", "in_progress", "done")):
        f.write(json.dumps({"ts": ts, "type": "slice_status_changed", "slice": "P1.S7", "old_status": old, "new_status": new}) + "\n")
proj = os.path.join(mt, "projects", "-fixture")
sub = os.path.join(proj, "sess1", "subagents")
os.makedirs(sub)
def asst(ts, mid, model, out, cr=0, w1h=0, w5=0, inp=0, content=None, stop="end_turn"):
    return {"type": "assistant", "timestamp": ts, "message": {"id": mid, "model": model, "content": content or [], "stop_reason": stop,
            "usage": {"input_tokens": inp, "cache_read_input_tokens": cr, "cache_creation_input_tokens": w1h + w5,
                      "cache_creation": {"ephemeral_1h_input_tokens": w1h, "ephemeral_5m_input_tokens": w5}, "output_tokens": out}}}
def user(ts, text):
    return {"type": "user", "timestamp": ts, "message": {"role": "user", "content": text}}
def write(path, rows):
    with open(path, "w") as f:
        f.write("".join(json.dumps(r) + "\n" for r in rows))
write(os.path.join(proj, "sess1.jsonl"), [
    user("2026-01-01T10:29:00.000Z", "go"),
    asst("2026-01-01T10:30:00.000Z", "m1", "claude-opus-5-5", 5, cr=1000000, w1h=100000, inp=10),
    asst("2026-01-01T10:30:01.000Z", "m1", "claude-opus-5-5", 500, cr=1000000, w1h=100000, inp=10),
    asst("2026-01-01T10:31:00.000Z", "m2", "claude-opus-5-5", 100, inp=1000)])
write(os.path.join(sub, "agent-aaa.jsonl"), [
    user("2026-01-01T10:35:00.000Z", "slice: P1.S7\nfolder: works/phases/active/P1/slices/P1.S7"),
    asst("2026-01-01T10:40:00.000Z", "s1", "claude-opus-5-5", 50, inp=2000, content=[{"type": "text", "text": "Done.\n- status: done"}]),
    asst("2026-01-01T10:41:00.000Z", "s3", "claude-opus-5-5", 3, inp=500, stop=None)])  # a stream-start entry: no final usage ever follows
json.dump({"agentType": "slice-executor-high", "model": "opus", "effort": "high", "finished": True}, open(os.path.join(sub, "agent-aaa.meta.json"), "w"))
write(os.path.join(sub, "agent-bbb.jsonl"), [
    user("2026-01-01T10:41:00.000Z", "round: 01-x/01-x\nslice: P1.S7"),
    asst("2026-01-01T10:42:00.000Z", "s2", "claude-mystery-1", 10, inp=100),
    {"type": "assistant", "timestamp": "2026-01-01T10:43:00.000Z", "error": "rate_limit", "isApiErrorMessage": True,
     "message": {"id": "syn1", "model": "<synthetic>", "content": [{"type": "text", "text": "You've hit your session limit · resets 3:10am (Asia/Seoul)"}],
                 "usage": {"input_tokens": 0, "output_tokens": 0}}}])
json.dump({"agentType": "design-drafter", "model": "opus", "effort": "xhigh", "finished": True}, open(os.path.join(sub, "agent-bbb.meta.json"), "w"))
PY
mt_json=$( cd "$MT/ws" && python3 scripts/workflow.py dispatch-summary --phase P1 --json --transcripts "$MT/projects/-fixture" 2>&1 )
printf '%s\n' "$mt_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)["metered"]["slices"]["P1.S7"]
m = d["main"]
assert m["requests"] == 2 and m["output"] == 600, m
spans = {s["agent"]: s for s in d["spans"]}
assert spans["slice-executor-high"]["slice"] == "P1.S7" and spans["slice-executor-high"]["attributed_by"] == "slice-line", spans
assert spans["slice-executor-high"]["outcome"] == "done", spans
assert spans["design-drafter"]["outcome"] == "limit" and spans["design-drafter"]["reset"] == "3:10am (Asia/Seoul)", spans
assert spans["design-drafter"]["usage"]["requests"] == 1 and spans["design-drafter"]["usage"]["unpriced"] == 1, spans
u = spans["slice-executor-high"]["usage"]
assert u["requests"] == 2 and u["no_final"] == 1 and u["output_floor"] is True and spans["design-drafter"]["usage"]["output_floor"] is False, u
assert m["output_floor"] is False, m
' && ok "the meter: two main-thread ids from three entries keep the largest output, spans attributed by their slice: line, a span ending on a usage limit is limit with its reset" || bad "the transcript meter miscounted: $mt_json"
mt_out=$( cd "$MT/ws" && python3 scripts/workflow.py dispatch-summary --phase P1 --transcripts "$MT/projects/-fixture" 2>&1 )
printf '%s\n' "$mt_out" | grep -qE '^main +- +2 +1\.10M +600 +1\.02 ' && printf '%s\n' "$mt_out" | grep -qE '^design-drafter +1 +1 +100 +10 +\? ' \
  && ok "dispatch-summary prices the main thread at list price (\$1.02) and leaves an unknown model unpriced (?)" || bad "dispatch-summary pricing wrong: $mt_out"
printf '%s\n' "$mt_out" | grep -qE '^note=output_floor spans=1/3 \(33%\) main=0/2 ' && printf '%s\n' "$mt_out" | grep -qE '^slice-executor-high +1 +2 +[^ ]+ +≥53 +≥[0-9.]+ ' \
  && ! printf '%s\n' "$mt_out" | grep -E '^(main|design-drafter) ' | grep -q '≥' \
  && ok "dispatch-summary flags a span request that never logged a final usage: the note= count and the ≥ floor on that group only" || bad "dispatch-summary floor note/mark wrong: $mt_out"
# v66: a DECOMP estimates time, not session-$, and writes a `spends money:` line per slice; the [means] header says so.
grep -q 'spends money:' "$SRC/claude/skills/do-whole-phase/reference/decomposition.md" && grep -q 'spends money:' "$SRC/claude/skills/do-next-slice/reference/decomposition.md" \
  && grep -q 'spends money:' "$SRC/claude/agents/slice-executor.md" && ! grep -q '\$ per span' "$SRC/claude/agents/slice-executor.md" \
  && grep -q 'a DECOMP estimates time from these' "$SRC/scripts/workflow.py" \
  && ok "a DECOMP estimates time only and writes a per-slice spends-money line (both references, the executor, the [means] header)" || bad "the DECOMP time-only / spends-money wording is missing or a session-\$ estimate remains"
# v66: one slice-executor runs every slice row, so the meter reads its route from the kind and the model
# (research by kind, haiku as cheap, the high row's family as high, else mid); an old slice-executor-high
# span keeps its reading. v80: on the defaults high and mid are both opus, so the span's effort tells them apart.
rm -f "$MT/ws/executors.toml"
python3 - "$MT" <<'PY'
import json, os, sys
proj = os.path.join(sys.argv[1], "projects", "-fixture2")
sub = os.path.join(proj, "sess2", "subagents")
os.makedirs(sub)
def row(ts, kind, payload):
    return json.dumps({"type": kind, "timestamp": ts, "message": payload}) + "\n"
open(os.path.join(proj, "sess2.jsonl"), "w").write(row("2026-01-01T10:29:00.000Z", "user", {"role": "user", "content": "go"}))
for n, (agent, model, sid, effort) in enumerate((("slice-executor", "claude-opus-5-5", "P1.S7", "high"), ("slice-executor", "claude-opus-5-5", "P1.S7", "medium"),
                                                 ("slice-executor", "claude-haiku-5-5", "P1.S7", None), ("slice-executor", "claude-opus-5-5", "P1.S2", None),
                                                 ("slice-executor-high", "claude-opus-5-5", "P1.S7", None), ("slice-executor", "claude-sonnet-5-5", "P1.S7", None))):
    ts = f"2026-01-01T10:3{n}:00.000Z"
    with open(os.path.join(sub, f"agent-x{n}.jsonl"), "w") as f:
        f.write(row(ts, "user", {"role": "user", "content": f"slice: {sid}"}))
        f.write(row(ts, "assistant", {"id": f"x{n}", "model": model, "content": [{"type": "text", "text": "- status: done"}], "stop_reason": "end_turn",
                                      "usage": {"input_tokens": 10, "output_tokens": 5}}))
    json.dump({"agentType": agent, "finished": True, **({"effort": effort} if effort else {})}, open(os.path.join(sub, f"agent-x{n}.meta.json"), "w"))
PY
mt2=$( cd "$MT/ws" && python3 scripts/workflow.py dispatch-summary --phase P1 --json --transcripts "$MT/projects/-fixture2" 2>&1 )
printf '%s\n' "$mt2" | python3 -c '
import json, sys
slices = json.load(sys.stdin)["metered"]["slices"]
routes = {s["id"]: (s["agent"], s["route"]) for d in slices.values() for s in d["spans"]}
assert routes == {"x0": ("slice-executor", "high"), "x1": ("slice-executor", "mid"), "x2": ("slice-executor", "cheap"),
                  "x3": ("slice-executor", "research"), "x4": ("slice-executor-high", "high"), "x5": ("slice-executor", "mid")}, routes
' && ok "the meter reads slice-executor spans by kind, model and effort (opus@high high, opus@medium mid, haiku cheap, sonnet mid, a research slice research) and still reads an old slice-executor-high span" \
  || bad "the meter misread slice-executor routes: $mt2"
# A minted, tailed slice id (P<n>-<tail>.S1) attributes by its `slice:` line, and dispatch-summary --phase takes the
# brief name (the bare number, while one phase holds it).
mt_tok=$( cd "$MT/ws" && python3 scripts/workflow.py new-phase --name "Meter token" --objective probe 2>&1 | sed -n 's/^created phase \(P[^:]*\):.*/\1/p' )
mt_num=$(printf '%s\n' "$mt_tok" | sed -nE 's/^P([0-9]+)-[0-9a-z]{2}$/\1/p')
( cd "$MT/ws" && python3 scripts/workflow.py new-slice --phase "$mt_num" --slice S1 --name "token meter" --kind implementation --risk low ) >/dev/null 2>&1 || bad "token meter probe: new-slice failed"
python3 - "$MT" "$mt_tok.S1" <<'PY'
import json, os, sys
sub = os.path.join(sys.argv[1], "projects", "-fixture2", "sess2", "subagents")
with open(os.path.join(sys.argv[1], "ws", "works", "events.jsonl"), "a") as f:  # the slice's window, so the phase filter finds the session
    for ts, old, new in (("2026-01-01T10:00:00+00:00", "todo", "in_progress"), ("2026-01-01T10:55:00+00:00", "in_progress", "done")):
        f.write(json.dumps({"ts": ts, "type": "slice_status_changed", "slice": sys.argv[2], "old_status": old, "new_status": new}) + "\n")
with open(os.path.join(sub, "agent-t0.jsonl"), "w") as f:
    f.write(json.dumps({"type": "user", "timestamp": "2026-01-01T10:50:00.000Z", "message": {"role": "user", "content": "slice: " + sys.argv[2]}}) + "\n")
    f.write(json.dumps({"type": "assistant", "timestamp": "2026-01-01T10:51:00.000Z", "message": {"id": "t0", "model": "claude-sonnet-5-5", "content": [{"type": "text", "text": "- status: done"}],
                                                                                              "stop_reason": "end_turn", "usage": {"input_tokens": 10, "output_tokens": 5}}}) + "\n")
json.dump({"agentType": "slice-executor", "finished": True}, open(os.path.join(sub, "agent-t0.meta.json"), "w"))
PY
mt3=$( cd "$MT/ws" && python3 scripts/workflow.py dispatch-summary --phase "$mt_num" --json --transcripts "$MT/projects/-fixture2" 2>&1 )
printf '%s\n' "$mt3" | python3 -c '
import json, sys
spans = [s for d in json.load(sys.stdin)["metered"]["slices"].values() for s in d["spans"]]
assert [(s["slice"], s["attributed_by"]) for s in spans] == [(sys.argv[1] + ".S1", "slice-line")], spans
' "$mt_tok" && [ -n "$mt_num" ] && ok "the meter attributes a minted, tailed slice id ($mt_tok.S1) by its slice: line, and dispatch-summary --phase takes the bare number" \
  || bad "the meter did not attribute a minted slice id: $mt3"
# v61 pure compaction (P37.S3): compaction is Claude Code's own -- no PreCompact hook, no compact-gate. After
# a compaction the SessionStart hook runs compact-resume, which prints the resume card (also `next --card`):
# computed from state, at most 2,048 B, naming files and never asking for a re-read. A pending stop is typed
# (set-slice-status ... pending --stop-kind --on-words), printed by next and the card, cleared on leaving pending.
newtmp CGT
CG="$CGT/ws"
sh "$BOOT" "$CG" --at-root --name "Card" --summary "card probe" >/dev/null 2>&1 \
  && ( cd "$CG" && python3 scripts/workflow.py new-phase --phase P1 --name "Card probe" --objective "probe the resume card" >/dev/null 2>&1 ) \
  || bad "resume card: could not build the fixture"
cg_help=$( cd "$CG" && python3 scripts/workflow.py --help 2>&1 ); cg_help_rc=$?
( cd "$CG" && python3 scripts/workflow.py compact-gate </dev/null >/dev/null 2>&1 ); cg_rc=$?
[ "$cg_help_rc" -eq 0 ] && printf '%s\n' "$cg_help" | grep -q 'dispatch-summary' && [ "$cg_rc" -ne 0 ] && ! printf '%s\n' "$cg_help" | grep -q 'compact-gate' && ! grep -qE 'cmd_compact_gate|AGENTIC_COMPACT_|COMPACT_RESUME_LINE' "$CG/scripts/workflow.py" \
  && ok "compact-gate is gone from the engine (no subcommand, no knobs, no resume line)" || bad "compact-gate still present (rc=$cg_rc)"
# every subcommand's --help exits 0 (a crash in an argparse help string once hid behind a green suite);
# the list is the engine's own, read from the top-level help
( cd "$CG" && printf '%s\n' "$cg_help" | python3 -c '
import re, subprocess, sys
names = re.search(r"\{([^}]+)\}", " ".join(sys.stdin.read().split())).group(1).split(",")
bad = [n for n in names if subprocess.run([sys.executable, "scripts/workflow.py", n, "--help"], capture_output=True).returncode != 0]
assert len(names) > 20 and not bad, bad
' ) && ok "every subcommand's --help exits 0 (the list read from the engine's own top-level help)" || bad "a subcommand's --help fails"
card_ok() { # card_ok <text>: at most 2,048 bytes, no re-read, the pointer, the next action and the file paths
  [ "$(printf '%s' "$1" | wc -c | tr -d ' ')" -le 2048 ] && ! printf '%s\n' "$1" | grep -qi 're-read' \
    && printf '%s\n' "$1" | grep -q '^pointer: phase P1 ' && printf '%s\n' "$1" | grep -q '^next action: ' \
    && printf '%s\n' "$1" | grep -q '^plan: works/phases/active/P1/slices/P1.DECOMP/plan.md' && printf '%s\n' "$1" | grep -q '^result: not yet' \
    && printf '%s\n' "$1" | grep -q '^phase: works/phases/active/P1/phase.md' && printf '%s\n' "$1" | grep -q '^intent: works/phases/active/P1/intent.md'
}
card=$( cd "$CG" && python3 scripts/workflow.py next --card 2>&1 ); cr_rc=$?
[ "$cr_rc" -eq 0 ] && card_ok "$card" && printf '%s\n' "$card" | grep -q '^next action: start-slice P1.DECOMP, then plan it' \
  && ok "next --card prints the resume card: <= 2,048 B, the pointer, the next action (plan it), the file paths, no re-read" || bad "next --card wrong (rc=$cr_rc): $card"
( cd "$CG" && python3 scripts/workflow.py start-slice P1.DECOMP >/dev/null 2>&1 && printf 'the plan\n' > works/phases/active/P1/slices/P1.DECOMP/plan.md ) || bad "resume card: start-slice failed"
mkdir -p "$CGT/proj/s1/subagents" && printf '{}\n' > "$CGT/proj/s1.jsonl"
printf '{"agentType":"slice-executor-high","description":"P1.DECOMP decomposition executor"}' > "$CGT/proj/s1/subagents/agent-a.meta.json"
printf '{"agentType":"Explore","description":"an old lookup","finished":true}' > "$CGT/proj/s1/subagents/agent-b.meta.json"
cr_out=$( cd "$CG" && printf '{"source":"compact","transcript_path":"%s","cwd":"%s"}' "$CGT/proj/s1.jsonl" "$CG" | python3 scripts/workflow.py compact-resume 2>&1 ); cr_rc=$?
cr_card=$(printf '%s\n' "$cr_out" | sed 1d)
[ "$cr_rc" -eq 0 ] && [ "$(printf '%s\n' "$cr_out" | head -1)" = "compaction=done source=compact" ] && card_ok "$cr_card" \
  && printf '%s\n' "$cr_card" | grep -qx 'running spans: slice-executor-high: P1.DECOMP decomposition executor' \
  && printf '%s\n' "$cr_card" | grep -q '^next action: an executor is running (see spans): wait for its notification, never re-dispatch' \
  && ok "compact-resume (fake hook stdin) prints the card: running spans from the session's unfinished .meta.json only, wait -- never re-dispatch" || bad "compact-resume card wrong (rc=$cr_rc): $cr_out"
cr_out=$( cd "$CG" && printf 'not json' | python3 scripts/workflow.py compact-resume 2>&1 ); cr_rc=$?
[ "$cr_rc" -eq 0 ] && printf '%s\n' "$cr_out" | head -1 | grep -qx 'compaction=done source=compact' && printf '%s\n' "$cr_out" | grep -q '^pointer: phase P1 ' \
  && ok "compact-resume on garbage stdin still prints the card and exits 0" || bad "compact-resume garbage stdin wrong (rc=$cr_rc): $cr_out"
( cd "$CG" && python3 scripts/workflow.py set-slice-status P1.DECOMP in_progress --stop-kind decision --on-words x >/dev/null 2>&1 ); tp_rc=$?
[ "$tp_rc" -ne 0 ] && ok "set-slice-status refuses --stop-kind/--on-words without pending" || bad "set-slice-status accepted --stop-kind without pending"
tp_set=$( cd "$CG" && python3 scripts/workflow.py set-slice-status P1.DECOMP pending --stop-kind decision --on-words "choose the design style; DECOMP records it and cuts the slices" 2>&1 ); tp_rc=$?
tp_next=$( cd "$CG" && python3 scripts/workflow.py next 2>&1 )
tp_card=$( cd "$CG" && python3 scripts/workflow.py next --card 2>&1 )
( cd "$CG" && python3 scripts/workflow.py validate >/dev/null 2>&1 ); tp_val=$?
[ "$tp_rc" -eq 0 ] && [ "$tp_val" -eq 0 ] && python3 -c 'import json,sys; p=json.load(open(sys.argv[1]))["pending"]; assert set(p)=={"kind","on_words","since"} and p["kind"]=="decision", p' "$CG/works/phases/active/P1/slices/P1.DECOMP/slice.json" \
  && printf '%s\n' "$tp_next" | grep -qx 'stop_kind=decision' && printf '%s\n' "$tp_next" | grep -qx 'on_words=choose the design style; DECOMP records it and cuts the slices' \
  && printf '%s\n' "$tp_card" | grep -q '^stop: decision (since .*) -- the operator.s words will: choose the design style' && [ "$(printf '%s' "$tp_card" | wc -c | tr -d ' ')" -le 2048 ] \
  && ok "a typed pending stop is stored as pending {kind, on_words, since}; next and the card print the kind and the words; validate passes" || bad "typed pending wrong (rc=$tp_rc val=$tp_val): $tp_set / $tp_next / $tp_card"
( cd "$CG" && python3 scripts/workflow.py set-slice-status P1.DECOMP in_progress >/dev/null 2>&1 ) \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "pending" not in d and d["status"]=="in_progress", d' "$CG/works/phases/active/P1/slices/P1.DECOMP/slice.json" \
  && ok "leaving pending clears the typed record" || bad "the pending record survived set-slice-status in_progress"
tp_bare=$( cd "$CG" && python3 scripts/workflow.py set-slice-status P1.DECOMP pending 2>&1 ); tp_rc=$?
[ "$tp_rc" -eq 0 ] && [ "$(printf '%s\n' "$tp_bare" | grep -c '^warning: untyped pending stop')" -eq 1 ] \
  && ok "a bare pending still works, with one warning line" || bad "bare pending wrong (rc=$tp_rc): $tp_bare"
( cd "$CG" && python3 scripts/workflow.py set-slice-status P1.DECOMP in_progress >/dev/null 2>&1 )
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["pending"]={"kind":"nap","on_words":"x","since":"t"}; json.dump(d,open(p,"w"))' "$CG/works/phases/active/P1/slices/P1.DECOMP/slice.json"
tp_val=$( cd "$CG" && python3 scripts/workflow.py validate 2>&1 ); tp_rc=$?
[ "$tp_rc" -ne 0 ] && printf '%s\n' "$tp_val" | grep -q 'carries a pending record' \
  && ok "validate rejects a pending record on a slice that is not pending" || bad "validate missed a stray pending record: $tp_val"
# v66: the high row owns no file (passed per dispatch), so the fable override lives only in executors.toml
# and executor-route; the [claude.mid] effort override is the one sync-agents writes into slice-executor.md.
printf '[claude.high]\nmodel = "fable"\n\n[claude.mid]\neffort = "high"\n' > "$F/executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) && grep -q '^effort: high$' "$F/.claude/agents/slice-executor.md" \
  || bad "sync-agents failed applying the fable + mid-effort overrides"
rm -rf "$F/.claude/skills/do-whole-phase"
# v61 (P37.S1): a v60-shaped install has no reference/ files; one in our skill dir that we do not ship is the operator's.
rm -rf "$F/.claude/skills/do-next-slice/reference" && rm -f "$F/.claude/skills/design-cowork/reference/shape.md"
printf 'my notes\n' > "$F/.claude/skills/design-cowork/notes.md"
mkdir -p "$F/.claude/skills/executor-mode" && printf -- '---\nname: executor-mode\ndisable-model-invocation: true\n---\nstale v45 skill\n' > "$F/.claude/skills/executor-mode/SKILL.md"
printf '%s\n' '# stale pre-v31 visual skill' > "$F/.claude/skills/design-cowork/SKILL.md"
# v61 (P37.S8): ownership by content. A v30-shaped tree: the commit skill exactly as v30 shipped it (ours,
# unchanged), the adopter's own explain skill at a path v30 shipped, a shipped file they modified, their
# own file under .codex/, and their own AGENTS.md / a stranded sidecar that is not v30's text.
mkdir -p "$F/.agents/skills/commit" "$F/.agents/skills/explain" "$F/.agents/skills/do-next-slice" "$F/.codex/agents"
v30_commit_skill() { cat <<'V30'
---
name: commit
description: Group pending changes by topic into focused conventional commits.
---

# commit

Inspect pending changes, group them by logical topic, and create one focused commit per group using `type(scope): summary` (imperative, no trailing period).

Never push, force-push, use `git add -A`, or skip hooks unless explicitly asked.
V30
}
v30_commit_skill > "$F/.agents/skills/commit/SKILL.md"
printf -- '---\nname: explain\n---\nthe knowledge repo keeps its own portable explain here\n' > "$F/.agents/skills/explain/SKILL.md"
# An old workspace copy of the retired explain skill, byte-for-byte, plus the operator's own file beside it.
plant_old_explain "$F/.claude/skills/explain/SKILL.md"; printf 'my notes\n' > "$F/.claude/skills/explain/notes.md"
explain_before=$(explain_sig "$F")
printf 'stale\n' > "$F/.agents/skills/do-next-slice/SKILL.md"
printf 'model = "mine"\n' > "$F/.codex/agents/mine.toml"
printf '# their own contract\n' > "$F/AGENTS.md"
printf '# stranded retrofit sidecar\n' > "$F/AGENTS.workspace.md"
# Intents: an active phase naming a retired mechanism is flagged, a done one is not (dry-run only:
# these hand-made phase.json files never reach validate).
mkdir -p "$F/works/phases/active/P90" "$F/works/phases/active/P91"
printf '{"id": "P90", "status": "in_progress"}\n' > "$F/works/phases/active/P90/phase.json"
printf '{"id": "P91", "status": "done"}\n' > "$F/works/phases/active/P91/phase.json"
printf '# Intent\n\nRun the compact-gate before every slice.\n' | tee "$F/works/phases/active/P90/intent.md" > "$F/works/phases/active/P91/intent.md"
dry_out=$(sh "$BOOT" "$F" --update --dry-run 2>&1)
printf '%s\n' "$dry_out" | grep -qx '    - P90 intent\.md names compact-gate (retired v61: pure compaction and the resume card, compact-resume / next --card) — re-confirm with the operator' \
  && ! printf '%s\n' "$dry_out" | grep -q 'P91 intent\.md' && grep -q 'Run the compact-gate' "$F/works/phases/active/P90/intent.md" \
  && ok "--update flags an active phase whose intent.md names compact-gate (read-only), never a done one" || bad "--update intent flagging wrong -- $dry_out"
rm -r "$F/works/phases/active/P90" "$F/works/phases/active/P91"
update_out=$(sh "$BOOT" "$F" --update 2>&1); update_rc=$?
update_stale=$(printf '%s\n' "$update_out" | sed -n '/^  stale (ours, unchanged/,/^  [^ ]/p')
[ "$update_rc" -eq 0 ] && grep -q 'fable' "$F/executors.toml" \
  && ok "--update preserves an edited executors.toml (seed-once)" || bad "--update clobbered or failed on an edited executors.toml"
[ -f "$F/.claude/skills/do-whole-phase/SKILL.md" ] \
  && ok "--update restores a deleted skill package" || bad "--update did not restore the deleted skill package"
printf '%s\n' "$update_out" | grep -q '^    - \.claude/skills/do-whole-phase' \
  && bad "--update incorrectly flags do-whole-phase as stale" || ok "--update does not flag do-whole-phase as stale"
diff -q "$SRC/claude/skills/design-cowork/SKILL.md" "$F/.claude/skills/design-cowork/SKILL.md" >/dev/null \
  && ok "--update refreshes a stale design-cowork skill body" || bad "--update did not refresh design-cowork"
printf '%s\n' "$update_out" | grep -q '^    - \.claude/skills/design-cowork/SKILL\.md' \
  && bad "--update incorrectly flags current design-cowork as stale" || ok "--update keeps design-cowork in the current inventory"
skill_tree_ok "$F/.claude/skills" exact && printf '%s\n' "$update_out" | grep -qx '    + \.claude/skills/do-next-slice/reference/dispatch\.md' \
  && printf '%s\n' "$update_out" | grep -qx '    + \.claude/skills/design-cowork/reference/shape\.md' \
  && ok "--update on a v60-shaped install adds the reference files, each listed as added" || bad "--update did not add the reference files to a v60-shaped install -- $update_out"
printf '%s\n' "$update_out" | grep -qx '    - \.claude/skills/design-cowork/notes\.md  (not shipped by this version)' \
  && [ -f "$F/.claude/skills/design-cowork/notes.md" ] && ! printf '%s\n' "$update_stale" | grep -q 'notes\.md' \
  && ok "--update reports an unshipped file in our skill dir as yours, kept (per file, never stale, never deleted)" || bad "--update mis-reported an unshipped file in a skill dir -- $update_out"
rm -f "$F/.claude/skills/design-cowork/notes.md"
report_lists() { printf '%s\n' "$1" | sed -n '/^  stale (ours, unchanged/,$p' | grep -E '^  (stale|yours|note:)|^    - ' | grep -v '^    - P[0-9]'; }
if [ "$(printf '%s\n' "$update_stale" | grep -c '^    - ')" -eq 1 ] \
  && printf '%s\n' "$update_stale" | grep -qx '    - \.agents/skills/commit/SKILL\.md  (unchanged since v30)'; then
  ok "--update lists only the unchanged v30 file as stale (ours, by content)"
else bad "--update stale list wrong -- $update_stale"; fi
kept_bad=""
for k in '\.agents/skills/do-next-slice/SKILL\.md  (differs from what v30 shipped)' \
         '\.codex/agents/mine\.toml  (not a file the workspace shipped)' 'AGENTS\.md  (differs from what v30 shipped)' \
         'AGENTS\.workspace\.md  (differs from what v30 shipped)' '\.claude/skills/executor-mode/SKILL\.md  (differs from what v52 shipped)'; do
  printf '%s\n' "$update_out" | grep -qx "    - $k" || kept_bad="$kept_bad [$k]"
done
[ -z "$kept_bad" ] && ok "--update reports a modified shipped file, their .codex file and AGENTS.md as yours, kept" \
  || bad "--update yours-kept list wrong:$kept_bad -- $update_out"
[ "$(printf '%s\n' "$explain_before" | wc -l | tr -d ' ')" -eq 3 ] && [ "$(explain_sig "$F")" = "$explain_before" ] \
  && ! printf '%s\n%s\n' "$dry_out" "$update_out" | grep -Eq '/explain(/|[[:space:]]|$)' \
  && ok "--update and --update --dry-run leave every explain file (.agents/ and .claude/, the old shipped copy too) byte-identical and never name one" \
  || bad "--update touched or reported an explain path -- $(printf '%s\n%s\n' "$dry_out" "$update_out" | grep -E '/explain(/|[[:space:]]|$)')"
if python3 - "$F" "$update_out" <<'PY'
import os, re, sys
listed = re.findall(r"^    - (\S+)  \(", sys.argv[2], re.M)
assert listed and not [p for p in listed if os.path.isdir(os.path.join(sys.argv[1], p))], listed
assert not re.search(r"^    - \.agents  |^    - \.codex  |^    - \.claude/skills/executor-mode  ", sys.argv[2], re.M)
PY
then ok "--update never flags or lists a directory (.agents, .codex, a retired skill dir): every listed path is a file"
else bad "--update listed a directory -- $update_out"; fi
! printf '%s\n' "$update_out" | grep -q '^  note: \.agents/' \
  && ok "--update notes no directory as removable while it holds a file that is yours" || bad "--update noted .agents removable beside a kept file"
[ -n "$(report_lists "$update_out")" ] && [ "$(report_lists "$dry_out")" = "$(report_lists "$update_out")" ] \
  && ok "--update --dry-run prints the same stale and kept lists" || bad "--dry-run lists differ -- $(report_lists "$dry_out") /// $(report_lists "$update_out")"
[ -f "$F/.agents/skills/commit/SKILL.md" ] && [ -f "$F/.agents/skills/explain/SKILL.md" ] && [ -f "$F/.codex/agents/mine.toml" ] \
  && [ -f "$F/AGENTS.md" ] && [ -f "$F/AGENTS.workspace.md" ] && [ -f "$F/.claude/skills/executor-mode/SKILL.md" ] \
  && ok "--update never deletes a file it lists (stale or kept)" || bad "--update deleted a file it only lists"
rm -rf "$F/.agents" "$F/.codex" "$F/AGENTS.md" "$F/AGENTS.workspace.md" "$F/.claude/skills/explain"
printf '%s\n' "$update_out" | grep -q 'python3 scripts/workflow.py sync-agents' \
  && ok "--update instructs the adopter to re-run sync-agents" || bad "--update omitted the sync-agents migration step"
grep -q '^effort: medium$' "$F/.claude/agents/slice-executor.md" \
  && ok "--update resets agent files to upstream defaults (re-run sync-agents after updates)" || bad "--update did not reset the agent files"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) \
  && bad "preserved executor override should require re-sync after update" || ok "--update leaves a detectable executor drift until sync-agents"
( cd "$F" && python3 scripts/workflow.py sync-agents >/dev/null 2>&1 ) \
  && grep -q '^effort: high$' "$F/.claude/agents/slice-executor.md" \
  && ( cd "$F" && env -u ANTHROPIC_BASE_URL python3 scripts/workflow.py executor-route P1.DECOMP 2>&1 | grep -qx 'model=fable' ) \
  && ok "sync-agents re-applies the preserved executor override (mid effort in slice-executor.md; the high row's fable in executor-route)" || bad "sync-agents did not restore the preserved override"
rm -f "$F/executors.toml"
sh "$BOOT" "$F" --update >/dev/null 2>&1 && [ -f "$F/executors.toml" ] \
  && ok "--update seeds a missing executors.toml (pre-v9 workspace)" || bad "--update did not seed a missing executors.toml"
( cd "$F" && python3 scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) && ok "re-seeded executors.toml restores the tracked route selection" || bad "re-seeded executors.toml drifts from the tracked route selection"
# v66: the v65 executor pair is retired by content. A v65-shaped at-root install (the two files exactly as
# v65 shipped them, from tests/fixtures/v65 -- the suite never reads git history): --update lists both stale,
# a copy sync-agents patched (model/effort lines only) too, and installs the one slice-executor.md.
newtmp V65
V65W="$V65/ws"
sh "$BOOT" "$V65W" --at-root --name "V65" --summary "v65 probe" >/dev/null 2>&1 || bad "v65 probe: fresh install failed"
rm -f "$V65W/.claude/agents/slice-executor.md"
cp "$REPO_ROOT/tests/fixtures/v65/slice-executor-mid.md" "$V65W/.claude/agents/slice-executor-mid.md"
sed -e 's/^model: opus$/model: fable/' -e '/^effort: /d' "$REPO_ROOT/tests/fixtures/v65/slice-executor-high.md" > "$V65W/.claude/agents/slice-executor-high.md"
v65_out=$(sh "$BOOT" "$V65W" --update 2>&1); v65_rc=$?
[ "$v65_rc" -eq 0 ] && printf '%s\n' "$v65_out" | grep -qx '    - \.claude/agents/slice-executor-mid\.md  (unchanged since v65 (its model/effort lines aside))' \
  && printf '%s\n' "$v65_out" | grep -qx '    - \.claude/agents/slice-executor-high\.md  (unchanged since v65 (its model/effort lines aside))' \
  && diff -q "$SRC/claude/agents/slice-executor.md" "$V65W/.claude/agents/slice-executor.md" >/dev/null \
  && [ -f "$V65W/.claude/agents/slice-executor-mid.md" ] && [ -f "$V65W/.claude/agents/slice-executor-high.md" ] \
  && ok "--update of a v65-shaped install lists both old executors stale (a sync-agents-patched copy too), keeps them on disk, installs slice-executor.md" \
  || bad "--update of a v65-shaped install wrong (rc=$v65_rc) -- $v65_out"
printf '\nmy own rule\n' >> "$V65W/.claude/agents/slice-executor-mid.md"
v65_out=$(sh "$BOOT" "$V65W" --update 2>&1)
printf '%s\n' "$v65_out" | grep -qx '    - \.claude/agents/slice-executor-mid\.md  (differs from what v65 shipped (its model/effort lines aside))' \
  && printf '%s\n' "$v65_out" | grep -qx '    - \.claude/agents/slice-executor-high\.md  (unchanged since v65 (its model/effort lines aside))' \
  && ok "an old executor with a body edit is yours, kept (only its model/effort lines are ours to ignore)" || bad "a body-edited v65 executor was misclassified -- $v65_out"
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
# --update merges the resume hook additively and idempotently.
set_a=$(sha "$F/.claude/settings.json")
sh "$BOOT" "$F" --update >/dev/null 2>&1
[ "$(sha "$F/.claude/settings.json")" = "$set_a" ] \
  && ok "--update on a workspace that already has the hooks leaves settings.json byte-identical (idempotent)" || bad "--update changed an up-to-date settings.json"
# v61: a v60-shaped settings.json (our compact-gate beside the adopter's own PreCompact handler; the
# 450000 window v66-v81 shipped) loses exactly our handler, keeps theirs, moves to 500000 and lists both.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["hooks"]["PreCompact"]=[{"matcher":"auto","hooks":[{"type":"command","command":"echo foreign"},{"type":"command","command":"cd \"$CLAUDE_PROJECT_DIR\" && python3 scripts/workflow.py compact-gate || true","timeout":15}]},{"matcher":"manual","hooks":[{"type":"command","command":"cd \"$CLAUDE_PROJECT_DIR\" && python3 scripts/workflow.py compact-gate || true"}]}]; d["autoCompactWindow"]=450000; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$F/.claude/settings.json"
# ... and the same one report lists the stale v30 file beside them, noting its directory removable.
mkdir -p "$F/.agents/skills/commit" && v30_commit_skill > "$F/.agents/skills/commit/SKILL.md"
upd_out=$(sh "$BOOT" "$F" --update 2>&1); rm -r "$F/.agents"
if python3 - "$F/.claude/settings.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
h = d["hooks"]
assert h["PreCompact"] == [{"matcher": "auto", "hooks": [{"type": "command", "command": "echo foreign"}]}], h["PreCompact"]
assert [x["command"] for g in h["SessionStart"] for x in g["hooks"]] == ['cd "$CLAUDE_PROJECT_DIR" && python3 scripts/workflow.py compact-resume || true']
assert d["autoCompactWindow"] == 500000, d
PY
then printf '%s\n' "$upd_out" | grep -q '^  removed: .claude/settings.json hooks.PreCompact compact-gate (retired in v61)$' \
  && printf '%s\n' "$upd_out" | grep -q '^  changed: .claude/settings.json autoCompactWindow 450000 -> 500000 (today.s default; set it back if you chose 450000)$' \
  && printf '%s\n' "$upd_out" | grep -qx '    - \.agents/skills/commit/SKILL\.md  (unchanged since v30)' \
  && printf '%s\n' "$upd_out" | grep -qx '  note: \.agents/ holds only stale files: remove the emptied directory once they are gone' \
  && ok "--update on a v60-shaped settings.json removes only our compact-gate handlers (the group they emptied pruned), keeps the adopter's PreCompact hook, sets 500000 and lists both, in one report with the stale file and its directory note" \
  || bad "--update did not report the settings changes -- $upd_out"
else bad "--update did not retire our PreCompact handler cleanly -- $upd_out"; fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["autoCompactWindow"]=700000; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$F/.claude/settings.json"
upd_out=$(sh "$BOOT" "$F" --update 2>&1)
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["autoCompactWindow"] == 700000' "$F/.claude/settings.json" && ! printf '%s\n' "$upd_out" | grep -q '^  changed: .*autoCompactWindow' \
  && ok "--update keeps an autoCompactWindow the adopter chose (700000), reporting no change" || bad "--update moved an adopter's 700000 window -- $upd_out"
set_b=$(sha "$F/.claude/settings.json")
sh "$BOOT" "$F" --update >/dev/null 2>&1
[ "$(sha "$F/.claude/settings.json")" = "$set_b" ] \
  && ok "a second --update after the merge leaves settings.json byte-identical" || bad "--update hooks merge is not idempotent"
# 500000 window (v82): a v65-shaped settings.json (window 300000, what v56 and v61-v65 shipped) moves to 500000 with its changed: line.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["autoCompactWindow"]=300000; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$F/.claude/settings.json"
upd_out=$(sh "$BOOT" "$F" --update 2>&1)
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["autoCompactWindow"] == 500000' "$F/.claude/settings.json" \
  && printf '%s\n' "$upd_out" | grep -q '^  changed: .claude/settings.json autoCompactWindow 300000 -> 500000 (today.s default; set it back if you chose 300000)$' \
  && ok "--update moves a v65-shaped 300000 window to 500000 and lists it" || bad "--update did not move the 300000 window -- $upd_out"
cp "$SRC/claude/settings.json" "$F/.claude/settings.json"   # drop the probe's foreign handler before the Test 6 diff
rm -f "$F/.github/workflows/workspace-ci.yml" "$F/.gitattributes"
sh "$BOOT" "$F" --update >/dev/null 2>&1   # restore both verbatim for the Test 6 diff
[ ! -f "$F/.claude/agents/phase-reviewer.md" ] && ok "phase-reviewer retired (absent on fresh install)" || bad "phase-reviewer should be retired but is present"
[ -d "$F/.claude/skills/do-whole-phase" ] && ok "fresh install keeps do-whole-phase" || bad "do-whole-phase skill missing"
[ -f "$F/.claude/skills/do-whole-phases/SKILL.md" ] && ok "fresh install ships the do-whole-phases skill" || bad "fresh install missing the do-whole-phases skill"
[ -f "$F/.claude/skills/do-whole-phase/reference/wave.md" ] && ok "fresh install ships do-whole-phase's reference/wave.md (the wave protocol)" || bad "fresh install missing do-whole-phase/reference/wave.md"
[ ! -e "$F/.claude/skills/explain" ] && grep -qF '/plugin marketplace add leetusik/knowledge' "$F/docs/current/operations.md" \
  && grep -qF '/plugin install knowledge@knowledge' "$F/docs/current/operations.md" \
  && ok "fresh install ships no explain skill; its operations doc points at the knowledge plugin" || bad "fresh install still ships explain, or the operations doc lacks the plugin pointer"
# Since v31 the installer neither claims nor writes AGENTS.md, so --force-empty-ok
# installs beside a repo's own copy instead of aborting on a managed-file conflict.
newtmp H
printf '# Their cross-tool contract\n' > "$H/AGENTS.md"
AGH=$(sha "$H/AGENTS.md")
out=$(sh "$BOOT" "$H" --at-root --force-empty-ok --name "Fresh" --summary "fresh" 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ -f "$H/CLAUDE.md" ] \
  && ok "--force-empty-ok installs beside a repo's own AGENTS.md" || bad "--force-empty-ok beside AGENTS.md exit=$rc -- $out"
[ "$(sha "$H/AGENTS.md")" = "$AGH" ] && ok "install leaves a pre-existing AGENTS.md byte-identical" || bad "install rewrote the repo's own AGENTS.md"

# ---------------------------------------------------------------------------
echo "== Test 6: dual-apply -- live files match the bootstrap-embedded copies =="
# The fresh install in $F is generated straight from the bootstrap payload, so it
# is the source of truth to diff the live repo against.
diff -q "$SRC/scripts/workflow.py" "$F/scripts/workflow.py" >/dev/null \
  && ok "scripts/workflow.py == bootstrap-embedded WORKFLOW_PY" \
  || bad "DRIFT: scripts/workflow.py differs from the bootstrap-embedded copy"
skill_rels=$(cd "$SRC" && find claude/skills -type f -name SKILL.md | sed 's|^|.|' | LC_ALL=C sort)
nskill=$(printf '%s\n' "$skill_rels" | grep -c .)
[ "$nskill" -eq 18 ] && ok "dual-apply covers all 18 skill bodies" || bad "expected 18 SKILL.md files to diff, found $nskill"
for rel in $skill_rels; do
  diff -q "$SRC/${rel#.}" "$F/$rel" >/dev/null \
    && ok "dual-apply: $rel" \
    || bad "DRIFT: $rel differs from the bootstrap-embedded copy"
done
DUAL_FIXED=".claude/agents/slice-executor.md
.claude/agents/design-drafter.md
.claude/agents/design-critic.md
.claude/agents/Explore.md
.claude/settings.json
executors.toml
works/templates/deferred_brief.md
works/templates/intent.md
works/templates/phase.md
.github/workflows/workspace-ci.yml
.gitattributes"
for rel in $DUAL_FIXED CLAUDE.md; do
  src="$SRC/${rel#.}"; [ "$rel" = "CLAUDE.md" ] && src="$SRC/contract.md"
  diff -q "$src" "$F/$rel" >/dev/null \
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
# Runs against the fresh workspace from Test 5 ($F), which already carries the gate-probe P1 (P2 was archived above,
# and an archived id is spent since v73, so the notebook probe is P4).
sig() { python3 -c "import hashlib,os,sys;p=sys.argv[1];print(hashlib.sha256(open(p,'rb').read()).hexdigest(),os.stat(p).st_mtime_ns)" "$1"; }
PM="$F/works/phases/active/P4/phase.md"
( cd "$F" && python3 scripts/workflow.py new-phase --phase P4 --name "Notebook" --objective "notebook probe" >/dev/null 2>&1 )
grep -q '<!-- slices:begin -->' "$PM" && grep -q '<!-- slices:end -->' "$PM" && grep -q '^## Now$' "$PM" \
  && ok "new-phase seeds phase.md from the template (both markers + ## Now)" || bad "seeded phase.md is not the v35 shape"
grep -q '^| `P4.DECOMP` |' "$PM" && ok "new-phase renders the generated ## Slices block" || bad "## Slices block was not filled on phase creation"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P4 --slice P4.S1 --name "probe" >/dev/null 2>&1 )
out=$( cd "$F" && python3 scripts/workflow.py finish-slice P4.S1 --outcome "did X" 2>&1 )
grep -q '| did X |' "$PM" && ok "finish-slice --outcome lands in the slice's generated row" || bad "outcome missing from the ## Slices row -- $out"
out=$( cd "$F" && python3 scripts/workflow.py finish-slice P4.DECOMP 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '^warning: no --outcome recorded for P4.DECOMP' \
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
tree = ast.parse((root / "payload/scripts/workflow.py").read_text())
fallback = next(n.value.value for n in ast.walk(tree) if isinstance(n, ast.Assign)
                and any(getattr(t, "id", "") == "PHASE_MD_TEMPLATE_FALLBACK" for t in n.targets))
assert fallback == (root / "payload/works/templates/phase.md").read_text(), "fallback drifted from the shipped template"
FALLBACK
then ok "new_phase's embedded fallback is byte-identical to works/templates/phase.md"; else bad "PHASE_MD_TEMPLATE_FALLBACK drifted from works/templates/phase.md"; fi

# ---------------------------------------------------------------------------
echo "== Test 10: v35/v39 notebook guardrails -- budget warning, ## Doc Impact case drift, no dashboard timestamp churn =="
# Continues on $F (P4's phase.md lost its markers in Test 9; irrelevant here). v39's cap is
# bytes-only (v61: 40 KB, an index), so the filler is generated, never checked in: pad the
# notebook past it and drift the Doc impact heading in one edit.
python3 - "$PM" <<'PAD'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text() + "\n## Doc Impact\n\n" + "- filler\n" * 50_000)  # ~450 KB
PAD
out=$( cd "$F" && python3 scripts/workflow.py validate 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && ok "validate exits 0 with notebook warnings (warn, never error)" || bad "validate exited $rc on warnings -- $out"
printf '%s\n' "$out" | grep -q 'phase P4: phase.md is .* over the notebook budget of 40960 bytes; biggest sections: ## Doc Impact ' \
  && ok "an over-budget phase.md warns (40 KB) and names its largest section" || bad "no over-budget warning naming the largest section -- $out"
printf '%s\n' "$out" | grep -q 'has a `## Doc Impact` heading' \
  && ok "a case-drifted ## Doc Impact heading warns" || bad "no Doc-impact case-drift warning -- $out"
( cd "$F" && python3 scripts/workflow.py new-slice --phase P4 --slice P4.S2 --name "budget probe" >/dev/null 2>&1 )
out=$( cd "$F" && python3 scripts/workflow.py finish-slice P4.S2 --outcome "probe" 2>&1 )
printf '%s\n' "$out" | grep -q '^phase.md: .* bytes (budget 40960 bytes)' && printf '%s\n' "$out" | grep -q 'OVER BUDGET' \
  && ok "finish-slice prints the notebook size and flags it over budget" || bad "finish-slice notebook size print missing -- $out"
printf '%s\n' "$out" | grep -q 'biggest sections: ## Doc Impact ' && printf '%s\n' "$out" | grep -q 'topics/<slug>.md' \
  && ok "finish-slice names the biggest sections and suggests topics/ when over budget" || bad "over-budget size line does not name the largest section -- $out"
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
echo "== Test 10b: v61 phase-section -- phase.md is an index, read and written one section at a time =="
# Runs on a copy of $F so the probe phase never reaches the later tests' pointer.
newtmp PSW; cp -R "$F" "$PSW/ws"; PW="$PSW/ws"; ps() { ( cd "$PW" && python3 scripts/workflow.py phase-section "$@" ); }
( cd "$PW" && python3 scripts/workflow.py new-phase --phase P8 --name "Index probe" --objective "section probe" >/dev/null 2>&1 )
PN="$PW/works/phases/active/P8/phase.md"
python3 - "$PN" <<'SEED'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text()
t = t.replace("## Operator Questions\n", "## Operator Questions\n\n- **OQ1 (S1):** Should the probe keep the old shape?\n  A second line of context.\n- **OQ2 (S1):** Another one?\n", 1)
t = t.replace("## Now\n", "## Now\n\n- old now line\n", 1)
p.write_text(t)
SEED
out=$(ps P8); printf '%s\n' "$out" | grep -q 'Objective$' && printf '%s\n' "$out" | grep -q 'Operator Questions$' && printf '%s\n' "$out" | grep -q 'total' \
  && ok "phase-section <P> lists the headings with their bytes and a total" || bad "phase-section index wrong -- $out"
out=$(ps P8 Now); printf '%s\n' "$out" | grep -qx '## Now' && printf '%s\n' "$out" | grep -q 'old now line' && ! printf '%s\n' "$out" | grep -q '## Decisions' \
  && ok "phase-section <P> Now prints that section, heading included, and nothing else" || bad "phase-section Now wrong -- $out"
ps P8 nope >/dev/null 2>&1; rc=$?; [ "$rc" -eq 1 ] && ok "an unknown section exits 1" || bad "unknown section exit=$rc"
cp "$PN" "$PSW/before.md"
printf 'fresh now\n' | ps P8 Now --replace >/dev/null 2>&1
python3 - "$PSW/before.md" "$PN" <<'SPLICE'
import sys
old, new = (open(p, encoding="utf-8").read() for p in sys.argv[1:3])
cut = old.index("## Now\n")
assert new[:cut] == old[:cut], "bytes before ## Now changed"
assert new[cut:].startswith("## Now\n") and "fresh now" in new[cut:] and "old now line" not in new, "the section was not replaced"
SPLICE
[ $? -eq 0 ] && ok "--replace of Now keeps every byte before the section identical and swaps its body" || bad "--replace changed bytes outside the section"
printf 'mid decision\n' > "$PSW/dec.txt"; cp "$PN" "$PSW/before2.md"; ps P8 Decisions --replace --file "$PSW/dec.txt" >/dev/null 2>&1
python3 - "$PSW/before2.md" "$PN" <<'SPLICE2'
import re, sys
old, new = (open(p, encoding="utf-8").read() for p in sys.argv[1:3])
split = lambda t: re.split(r"(?m)^(?=## )", t)
a, b = split(old), split(new)
assert len(a) == len(b)
for x, y in zip(a, b):
    if x.startswith("## Decisions"):
        assert "mid decision" in y
    else:
        assert x == y, x[:30]
SPLICE2
[ $? -eq 0 ] && ok "--replace of a middle section (Decisions, from --file) leaves every other section byte-identical" || bad "--replace of Decisions touched another section"
for target in Slices "Doc impact" "Operator Questions"; do
  printf 'x\n' | ps P8 "$target" --replace >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] && ok "--replace refuses $target" || bad "--replace of $target was accepted"
done
printf 'x\n' | ps P8 Slices --append >/dev/null 2>&1; [ $? -ne 0 ] && ok "--append refuses the generated Slices section" || bad "--append of Slices was accepted"
printf '%s\n' '- widget.md: a new line (S1)' | ps P8 "Doc impact" --append >/dev/null 2>&1
ps P8 "Doc impact" | grep -q 'widget.md: a new line' && ok "--append adds a line to Doc impact" || bad "--append to Doc impact lost the line"
ps P8 "Operator Questions" --append <<'OQAPP' >/dev/null 2>&1
- **OQ3 (S2):** Third?
OQAPP
ps P8 "Operator Questions" | grep -q 'OQ3 (S2)' && ok "--append adds an Operator Questions entry" || bad "--append to Operator Questions lost the entry"
out=$(ps P8 --resolve OQ1 --pointer "Decisions line 2"); rc=$?
ps P8 "Operator Questions" > "$PSW/oq.txt"
[ "$rc" -eq 0 ] && grep -qx -- '- \*\*OQ1\*\* (resolved → Decisions line 2): Should the probe keep the old shape?' "$PSW/oq.txt" \
  && ! grep -q 'A second line of context' "$PSW/oq.txt" && grep -q 'OQ2 (S1)' "$PSW/oq.txt" && grep -q 'OQ3 (S2)' "$PSW/oq.txt" \
  && ok "--resolve collapses a two-line entry to one resolved line and leaves its neighbours" || bad "--resolve result wrong (rc=$rc) -- $(cat "$PSW/oq.txt")"
ps P8 --resolve OQ1 --pointer "again" >/dev/null 2>&1; [ $? -ne 0 ] && ok "a second --resolve of the same entry is refused" || bad "an already-resolved entry was resolved again"
ps P8 --resolve OQ9 --pointer "x" >/dev/null 2>&1; [ $? -ne 0 ] && ok "--resolve of a missing entry is refused" || bad "--resolve of a missing entry succeeded"
( cd "$PW" && python3 scripts/workflow.py validate >/dev/null 2>&1 ) ; mkdir -p "$PW/works/phases/active/P8/topics" && printf '# topic\n' > "$PW/works/phases/active/P8/topics/contract.md"
out=$( cd "$PW" && python3 scripts/workflow.py validate 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s\n' "$out" | grep -q 'P8' && ok "validate accepts a topics/ folder beside phase.md without a word" || bad "validate flagged topics/ (rc=$rc) -- $out"
python3 - "$PW/works/phases/active/P8/phase.md" <<'BIG'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); p.write_text(p.read_text() + "\n".join("- long decision line %d padding padding padding" % i for i in range(1500)) + "\n")
BIG
out=$( cd "$PW" && python3 scripts/workflow.py validate 2>&1 )
printf '%s\n' "$out" | grep -q 'phase P8: phase.md is .* over the notebook budget of 40960 bytes; biggest sections: ## ' && printf '%s\n' "$out" | grep -q 'topics/<slug>.md' \
  && ok "a notebook over 40 KB warns in validate, names its biggest sections and points at topics/" || bad "no 40 KB warning with sections -- $out"
# Entries: --entry K --replace writes one entry, --to-topic moves entries losslessly behind gist lines, and
# every refusal writes nothing. On a fresh probe phase P9 with a small synthetic notebook.
( cd "$PW" && python3 scripts/workflow.py new-phase --phase P9 --name "Entry probe" --objective "entry probe" >/dev/null 2>&1 )
PE="$PW/works/phases/active/P9/phase.md"
python3 - "$PE" <<'SEED'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text()
dec = ("1. **Alpha:** the first decision, short enough to be its own gist.\n"
       "2. **Beta:** a long decision. " + "It carries detail the next slice reads only when it needs it. " * 12 + "\n"
       "   - a nested point under Beta\n"
       "3. [topics/x.md](topics/x.md)\n")
t = t.replace("`topics/breakdown.md`._\n", "`topics/breakdown.md`._\n\n" + dec, 1)
t = t.replace("Last on purpose._\n", "Last on purpose._\n\n- now line\n", 1)
p.write_text(t)
SEED
cp "$PE" "$PSW/e0.md"; printf 'the **Alpha** decision, replaced\n' | ps P9 Decisions --entry alpha --replace >/dev/null 2>&1
python3 - "$PSW/e0.md" "$PE" <<'ENTRY'
import sys
old, new = (open(p, encoding="utf-8").read() for p in sys.argv[1:3])
line = "1. **Alpha:** the first decision, short enough to be its own gist."
assert old.count(line) == 1 and new == old.replace(line, "1. the **Alpha** decision, replaced", 1), "bytes outside the entry changed"
ENTRY
[ $? -eq 0 ] && ok "--entry K --replace swaps only that entry (its marker kept) and leaves every other byte identical" || bad "--entry --replace touched bytes outside the entry"
cp "$PE" "$PSW/e1.md"
for refusal in "Decisions --to-topic decisions --entry 3" "Decisions --to-topic breakdown --entry 1" "Now --to-topic now" \
               "Doc_impact --to-topic notes" "Operator_Questions --entry 1 --replace" "Decisions --entry 1 --remove"; do
  # shellcheck disable=SC2086
  set -- $refusal; sect=$(printf '%s' "$1" | tr '_' ' '); shift
  printf 'x\n' | ps P9 "$sect" "$@" >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] && cmp -s "$PSW/e1.md" "$PE" && [ ! -e "$PW/works/phases/active/P9/topics" ] \
    && ok "phase-section refuses $sect $* and writes nothing" || bad "phase-section $sect $* was not refused cleanly (rc=$rc)"
done
ps P9 Decisions --to-topic decisions --entry 1-2 --dry-run >/dev/null 2>&1; dry_rc=$?
dry_clean=no; cmp -s "$PSW/e1.md" "$PE" && [ ! -e "$PW/works/phases/active/P9/topics" ] && dry_clean=yes
ps P9 Decisions --to-topic decisions --entry 1-2 >/dev/null 2>&1; mv_rc=$?
python3 - "$PSW/e1.md" "$PE" "$PW/works/phases/active/P9/topics/decisions.md" <<'MOVE'
import re, sys
old, new, topic = (open(p, encoding="utf-8").read() for p in sys.argv[1:4])
dec = lambda t: re.search(r"(?ms)^## Decisions\n.*?(?=^## )", t).group(0)
others = lambda t: t.replace(dec(t), "")
assert others(old) == others(new), "a section other than Decisions changed"
body = dec(old).split("\n")
starts = [i for i, l in enumerate(body) if re.match(r"\d+\. ", l)]
entries = ["\n".join(body[s:e]).rstrip("\n") for s, e in zip(starts, starts[1:] + [len(body)])]
for n, entry in enumerate(entries[:2], 1):
    assert f"## Decisions {n}\n\n{entry}\n" in topic, f"entry {n} is not verbatim in the topic"
    ptr = re.search(rf"(?m)^{n}\. (.+) → \[topics/decisions\.md\]\(topics/decisions\.md\) § Decisions {n}$", dec(new))
    assert ptr and len(re.sub(r"[*`]", "", ptr.group(1))) >= 24 and len(ptr.group(1)) <= 160, f"pointer {n} lacks a gist"
assert entries[2] in dec(new), "the unmoved entry changed"
MOVE
[ $? -eq 0 ] && [ "$dry_rc" -eq 0 ] && [ "$dry_clean" = yes ] && [ "$mv_rc" -eq 0 ] \
  && ok "--to-topic --dry-run writes nothing; the move puts each entry verbatim in topics/<slug>.md and leaves a pointer line with a gist" \
  || bad "--to-topic was not lossless (dry rc=$dry_rc clean=$dry_clean, move rc=$mv_rc)"
# Budgets and paging (design §4-§5): a probe phase P10 whose Decisions (~70 KB, one entry bigger than a
# page) is over its 12 KB budget, read in 24 KB pages; then a dangling pointer warns in validate.
( cd "$PW" && python3 scripts/workflow.py new-phase --phase P10 --name "Page probe" --objective "page probe" >/dev/null 2>&1 )
PP="$PW/works/phases/active/P10/phase.md"
python3 - "$PP" <<'SEED'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text()
dec = "".join(f"- **D{n}:** decision {n}. " + "detail " * 140 + "\n" for n in range(1, 41))
dec += "- **Huge:** " + "x" * 30000 + "\n\nA prose paragraph after the entries.\n"
t = t.replace("`topics/breakdown.md`._\n", "`topics/breakdown.md`._\n\n" + dec, 1)
p.write_text(t)
SEED
out=$(ps P10)
printf '%s\n' "$out" | grep -q '12288  over,long:41 Decisions$' && printf '%s\n' "$out" | grep -qx 'move: phase-section P10 "Decisions" --to-topic decisions --entry 1-41' \
  && val=$( cd "$PW" && python3 scripts/workflow.py validate 2>&1 ) && printf '%s\n' "$val" | grep -q 'phase P10: phase.md ## Decisions: .* over its 12288 B budget; long entries: 1, 2, 3, 4, 5, 6, 7, 8 +33 more; move: phase-section P10 "Decisions"' \
  && ok "an over-budget section and its long entries are named, with the move command, by the index (heading last) and validate" || bad "budget report wrong -- $out"
pg_rc=0; ps P10 Decisions > "$PSW/plain.txt" || pg_rc=1; n=$(head -1 "$PSW/plain.txt" | sed -n 's/^<!-- page 1 of \([0-9]*\) · Decisions · entries 1–[0-9]* of 41 · next: phase-section P10 "Decisions" --page 2 -->$/\1/p')
: > "$PSW/pages.txt"; for k in $(seq 1 "${n:-0}"); do ps P10 Decisions --page "$k" > "$PSW/page$k.txt" || pg_rc=1; done
python3 - "$PP" "$PSW" "${n:-0}" <<'PAGES'
import re, sys
text, d, n = open(sys.argv[1], encoding="utf-8").read(), sys.argv[2], int(sys.argv[3])
sec = re.search(r"(?ms)^## Decisions\n.*?(?=^## )", text).group(0).rstrip("\n") + "\n"
pages = [open(f"{d}/page{k}.txt", encoding="utf-8").read() for k in range(1, n + 1)]
assert n >= 3 and pages[0] == open(f"{d}/plain.txt", encoding="utf-8").read(), "a plain read is not page 1"
assert all(p.startswith("<!-- page ") for p in pages) and pages[-1].split("\n")[0].endswith("· last page -->")
assert "".join(p.split("\n", 1)[1] for p in pages) == sec, "the pages do not concatenate to the section"
for p in pages[1:]:
    assert re.match(r"(- \*\*|A prose)", p.split("\n", 1)[1]), "a page starts inside an entry"
assert any(len(p.encode()) > 24 * 1024 for p in pages), "the entry bigger than a page was split"
PAGES
[ $? -eq 0 ] && [ "$pg_rc" -eq 0 ] && ok "a section over 24 KB reads in pages: a plain read is page 1, pages break only between entries and concatenate to the section byte for byte" \
  || bad "paged read wrong (n=$n rc=$pg_rc) -- $(head -1 "$PSW/plain.txt" | cut -c1-200)"
cp "$PP" "$PSW/p0.md"; r1=0; r2=0; ps P10 Decisions --page 99 >/dev/null 2>&1 || r1=1; printf 'x\n' | ps P10 Decisions --page 1 --replace >/dev/null 2>&1 || r2=1
[ "$r1" -eq 1 ] && [ "$r2" -eq 1 ] && cmp -s "$PSW/p0.md" "$PP" && ok "--page out of range and --page with a write flag are refused, writing nothing" || bad "--page refusals wrong (range=$r1 write=$r2)"
ps P10 Decisions --to-topic decisions --entry 1 >/dev/null 2>&1
q=$( cd "$PW" && python3 scripts/workflow.py validate 2>&1 | grep -c 'the moved entry is lost' ); rm "$PW/works/phases/active/P10/topics/decisions.md"
lost=$( cd "$PW" && python3 scripts/workflow.py validate 2>&1 ); lost_rc=$?
[ "$q" = 0 ] && [ "$lost_rc" -eq 0 ] && printf '%s\n' "$lost" | grep -q 'phase P10: phase.md ## Decisions entry 1 points at topics/decisions.md, which does not exist: the moved entry is lost' \
  && ok "validate stays quiet on a good pointer and warns on a dangling one (a lost decision), exit 0" || bad "dangling-pointer warning wrong (quiet=$q rc=$lost_rc) -- $lost"
# The required step (design §6): over 40 KB, next / start-slice / the card print it; silent under budget and when done.
newtmp NBW; cp -R "$F" "$NBW/ws"; NW="$NBW/ws"; rm -rf "$NW/works/phases/active/"* "$NW/works/phases/archived/"*; nb() { ( cd "$NW" && python3 scripts/workflow.py "$@" ); }
nb new-phase --phase P11 --name "Step probe" --objective "step probe" >/dev/null 2>&1; NP="$NW/works/phases/active/P11/phase.md"
nb start-slice P11.DECOMP >/dev/null 2>&1; base=$(nb next 2>&1); base_card=$(nb next --card 2>&1)
python3 - "$NP" <<'SEED'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text()
dec = "".join(f"- **D{n}:** decision {n}. " + "detail " * 400 + "\n" for n in range(1, 18))
p.write_text(t.replace("`topics/breakdown.md`._\n", "`topics/breakdown.md`._\n\n" + dec, 1))
SEED
out=$(nb next 2>&1); card=$(nb next --card 2>&1); st=$(nb set-slice-status P11.DECOMP todo >/dev/null 2>&1; nb start-slice P11.DECOMP 2>&1)
printf '%s\n' "$out" | grep -q '^notebook_over_budget=P11 ([0-9]* of 40960 B) -- required before the next dispatch: move long entries to topics first (gists stay, nothing is lost)$' \
  && printf '%s\n' "$out" | grep -qx 'notebook_move=phase-section P11 "Decisions" --to-topic decisions --entry 1-17' \
  && printf '%s\n' "$card" | grep -q '^notebook: over budget ([0-9]*/40960 B) -- run the notebook_move lines `next` prints before the next dispatch$' \
  && printf '%s\n' "$st" | grep -qx 'started P11.DECOMP' && printf '%s\n' "$st" | grep -q '^warning: notebook P11 is over budget ' \
  && ok "over 40 KB with a long entry, next prints the required step and its move, the card one line, start-slice a warning and still starts" || bad "required step wrong -- $out / $st"
nb phase-section P11 Decisions --to-topic decisions --entry 1-17 >/dev/null 2>&1
[ "$(nb next 2>&1)" = "$base" ] && [ "$(nb next --card 2>&1)" = "$base_card" ] \
  && ok "after the move the notebook is under budget and next and the card are byte-identical to before" || bad "under-budget next or card changed after the move"
python3 - "$NP" <<'SEED'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text()
oq = "".join(f"- **OQ{n} (S1):** question {n}? " + "context " * 400 + "\n" for n in range(1, 18))
p.write_text(t.replace("## Operator Questions\n", "## Operator Questions\n\n" + oq, 1))
SEED
out=$(nb next 2>&1)
printf '%s\n' "$out" | grep -q '^notebook_over_budget=P11 ([0-9]* of 40960 B) -- advisory: nothing left to move (Slices [0-9]* B generated; Operator Questions [0-9]* B: collapse answered entries with --resolve OQ<n> --pointer <ref>)$' \
  && ! printf '%s\n' "$out" | grep -q '^notebook_move=' \
  && ok "when nothing can move, next prints the advisory step and no notebook_move line" || bad "advisory step wrong -- $out"
nb set-phase-status P11 done >/dev/null 2>&1
! nb next 2>&1 | grep -q 'notebook' && ! nb next --card 2>&1 | grep -q '^notebook:' && ! nb run-phases 2>&1 | grep -q '^notebook_' \
  && ok "a done phase over budget prints no step in next, the card or run-phases" || bad "a done phase still prints the step"

# ---------------------------------------------------------------------------
echo "== Test 10c: P41 run-phases -- a run's phase list, and a parked acceptance gate only a run passes =="
# On a copy of $F emptied of its phases, so the probe phases are the whole pointer and never reach the later tests.
newtmp RPW; cp -R "$F" "$RPW/ws"; RW="$RPW/ws"; rm -rf "$RW/works/phases/active/"* "$RW/works/phases/archived/"*; rp() { ( cd "$RW" && python3 scripts/workflow.py "$@" ); }
for n in 1 2 3; do rp new-phase --phase "P$n" --name "Run probe $n" --objective "run probe" >/dev/null 2>&1 || bad "run-phases probe: new-phase P$n failed"; done
out=$(rp run-phases 3,p1 P2 1 2>&1); rc=$?; ref=$(rp run-phases P1 worktree 2>&1); ref_rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qx 'queue=P3,P1,P2' && [ "$ref_rc" -eq 2 ] && printf '%s\n' "$ref" | grep -q '^refused=worktree ' && ! printf '%s\n' "$ref" | grep -q '^queue=' \
  && ok "run-phases keeps the tokens' order (3,p1 P2 1 -> P3,P1,P2) and refuses a non-phase token with exit 2 and no queue" || bad "run-phases tokens wrong (rc=$rc ref_rc=$ref_rc) -- $out / $ref"
{ rp accept-gate P1 --require && rp accept-gate P1 --open --walkthrough "probe" && rp set-slice-status P2.DECOMP pending --stop-kind decision --on-words "probe"; } >/dev/null 2>&1 \
  || bad "run-phases probe: could not park P1 or stop P2.DECOMP"
out=$(rp run-phases P1 P2 P3 2>&1); plain=$(rp next 2>&1)
printf '%s\n' "$out" | grep -q '^parked=P1 ' && printf '%s\n' "$out" | grep -qx 'halt=P2.DECOMP status=pending' && printf '%s\n' "$out" | grep -qx 'stop_kind=decision' \
  && ! printf '%s\n' "$out" | grep -q '^target_' && printf '%s\n' "$plain" | grep -qx 'waiting_on_operator=P1' \
  && ok "run-phases passes a parked gate and halts at a pending slice, while plain next still waits on the parked phase" || bad "run-phases parking wrong -- $out / $plain"

# ---------------------------------------------------------------------------
echo "== Test 10d: P42 the ready set -- an undeclared phase keeps its plain pointer, a declared dependency binds =="
# Same emptied copy of $F as 10c: P1 is undeclared (the pointer, as before); P2 is declared and read through run-phases P2.
newtmp RSW; cp -R "$F" "$RSW/ws"; SW="$RSW/ws"; rm -rf "$SW/works/phases/active/"* "$SW/works/phases/archived/"*; rs() { ( cd "$SW" && python3 scripts/workflow.py "$@" ); }
{ for n in 1 2; do rs new-phase --phase "P$n" --name "Ready probe $n" --objective "ready probe" && rs finish-slice "P$n.DECOMP" --outcome cut; done \
  && rs new-slice --phase P1 --slice P1.S1 --name s1 && rs new-slice --phase P1 --slice P1.S2 --name s2 \
  && rs new-slice --phase P2 --slice P2.S1 --name s1 --depends-on none && rs new-slice --phase P2 --slice P2.S2 --name s2 --depends-on P2.S1; } >/dev/null 2>&1 \
  || bad "ready-set probe: setup failed"
plain=$(rs next 2>&1); card=$(rs next --card 2>&1); run=$(rs run-phases P1 2>&1)
printf '%s\n' "$plain" | grep -qx 'current_slice=P1.S1' && printf '%s\n' "$run" | grep -qx 'target_slice=P1.S1' \
  && ! printf '%s\n%s\n%s\n' "$plain" "$card" "$run" | grep -q -e '^ready_slices=' -e '^running_slices=' -e '^wave: ' \
  && ok "an undeclared phase's ready set is its first open slice alone: next, the card and run-phases print no ready, running or wave line" \
  || bad "undeclared phase output changed -- $plain / $card / $run"
r1=$(rs run-phases P2 2>&1); rs start-slice P2.S1 >/dev/null 2>&1; r2=$(rs run-phases P2 2>&1); rs finish-slice P2.S1 --outcome x >/dev/null 2>&1; r3=$(rs run-phases P2 2>&1)
rs new-slice --phase P2 --slice P2.S0 --name s0 --order 5 --depends-on P2.S2 >/dev/null 2>&1; fwd=$?
printf '%s\n' "$r1" | grep -qx 'ready_slices=P2.S1' && printf '%s\n' "$r2" | grep -qx 'ready_slices=none' && printf '%s\n' "$r2" | grep -qx 'running_slices=P2.S1' \
  && printf '%s\n' "$r3" | grep -qx 'ready_slices=P2.S2' && [ "$fwd" -ne 0 ] && [ ! -e "$SW/works/phases/active/P2/slices/P2.S0" ] \
  && ok "a declared slice is never ready before its dependency is done, and new-slice refuses a dependency not ordered before it" \
  || bad "declared ready set wrong (fwd rc=$fwd) -- $r1 / $r2 / $r3"
{ rs set-phase-status P1 done && rs start-slice P2.S2 && rs finish-slice P2.S2 --outcome x && rs start-slice P2.REVIEW \
  && : > "$SW/works/phases/active/P2/slices/P2.REVIEW/result.md" && rs accept-gate P2 --require && rs accept-gate P2 --open --walkthrough probe; } >/dev/null 2>&1 \
  || bad "ready-set probe: could not open P2's acceptance gate"
gn=$(rs next 2>&1); gc=$(rs next --card 2>&1)
printf '%s\n' "$gn" | grep -qx 'waiting_on_operator=P2' && printf '%s\n' "$gc" | grep -q '^stop: phase P2 acceptance gate open ' \
  && ! printf '%s\n%s\n' "$gn" "$gc" | grep -q -e '^running_slices=' -e '^wave: ' \
  && ok "a declared phase at its open acceptance gate reads as a stop: the running REVIEW is a barrier, never a wave's running or returned slice" \
  || bad "declared gate reads as a wave -- $gn / $gc"
# v77: a decomposition cannot finish while a middle slice it leaves open is undeclared; set-slice-deps declares
# one, and finish-slice then prints the engine's parallel plan. An explain phase's chapters stay exempt.
{ rs new-phase --phase P3 --name "Forced probe" --objective "forced declaration" && rs new-slice --phase P3 --slice P3.S1 --name s1; } >/dev/null 2>&1 \
  || bad "forced-declaration probe: setup failed"
fr=$(rs finish-slice P3.DECOMP --outcome cut 2>&1); fr_rc=$?; fr_todo=$(grep -c '"status": "todo"' "$SW/works/phases/active/P3/slices/P3.DECOMP/slice.json")
{ rs set-slice-deps P3.S1 --depends-on none && rs new-slice --phase P3 --slice P3.S2 --name s2 --depends-on none \
  && rs new-slice --phase P3 --slice P3.S3 --name s3 --depends-on P3.S1; } >/dev/null 2>&1 || bad "forced-declaration probe: declaring failed"
fp=$(rs finish-slice P3.DECOMP --outcome cut 2>&1); fp_rc=$?
{ rs new-phase --phase P4 --name "Explain probe" --objective "explain exempt" && printf '\n## Explain\n\n- subject: P3\n' >> "$SW/works/phases/active/P4/intent.md" \
  && rs new-slice --phase P4 --slice P4.S1 --name chapter; } >/dev/null 2>&1 || bad "forced-declaration probe: explain setup failed"
rs finish-slice P4.DECOMP --outcome cut >/dev/null 2>&1; fe_rc=$?
[ "$fr_rc" -ne 0 ] && printf '%s\n' "$fr" | grep -q 'undeclared: P3.S1' && printf '%s\n' "$fr" | grep -q 'set-slice-deps' \
  && [ "$fr_todo" -eq 1 ] \
  && [ "$fp_rc" -eq 0 ] && printf '%s\n' "$fp" | grep -qx 'parallel_plan=P3: S1 + S2 -> S3 -> REVIEW' \
  && printf '%s\n' "$fp" | grep -q '^parallel_rounds=3 rounds for 4 open slices; 2 run beside another' && [ "$fe_rc" -eq 0 ] \
  && ok "a decomposition refuses to finish over an undeclared middle slice (nothing written), set-slice-deps declares it, finish-slice prints the engine's parallel plan, and an explain phase is exempt (v77)" \
  || bad "forced declaration wrong (refuse rc=$fr_rc, pass rc=$fp_rc, explain rc=$fe_rc) -- $fr / $fp"

# ---------------------------------------------------------------------------
echo "== Test 10e: ids -- P<n>-/D<n>-<tail> minted with the next number beside P<n>/D<n> and v73's P-/D- tokens, one listing order, an archived id is spent, two branches mint the same number and merge clean =="
# On a copy of $F emptied of its phases, deferred jobs and git history. Explicit P<n>/D<n>, tailed and v73 token ids keep working.
newtmp MIW; cp -R "$F" "$MIW/ws"; MW="$MIW/ws"; rm -rf "$MW/.git" "$MW/works/phases/active/"* "$MW/works/phases/archived/"* "$MW/works/deferred/"*/*
mi() { ( cd "$MW" && python3 scripts/workflow.py "$@" ); }
tail_re='([a-hjkmnp-tv-z][0-9a-hjkmnp-tv-z]|[0-9][a-hjkmnp-tv-z])'  # two Crockford symbols, a letter among them
mi_note() { python3 -c 'import sys; from pathlib import Path; p = Path(sys.argv[1]); p.write_text(p.read_text().replace("## Operator Questions", "- architecture.md: a durable change (" + sys.argv[2] + ".S1)\n\n## Operator Questions", 1))' "$MW/works/phases/active/$1/phase.md" "$1"; }
mi_owe() { mi_note "$1" && mi accept-gate "$1" --waive --note probe && mi set-slice-status "$1.DECOMP" done && mi set-slice-status "$1.REVIEW" done && mi review-phase "$1" --verdict pass; }
m1=$(mi new-phase --name "Minted" --objective "mint probe" 2>&1); mp=$(printf '%s\n' "$m1" | sed -n 's/^created phase \(P[^:]*\):.*/\1/p')
md=$(mi defer-job --title "minted" --reason r --trigger t --source manual 2>&1); mdid=$(printf '%s\n' "$md" | sed -n 's/^created deferred job \(D[^:]*\):.*/\1/p')
printf '%s\n' "$mp" | grep -qxE "P1-$tail_re" && [ -d "$MW/works/phases/active/$mp/slices/$mp.DECOMP" ] && [ -d "$MW/works/phases/active/$mp/slices/$mp.REVIEW" ] \
  && printf '%s\n' "$mdid" | grep -qxE "D1-$tail_re" && [ -f "$MW/works/deferred/open/$mdid/deferred.json" ] \
  && ok "new-phase without --phase mints P1-<tail> on an empty workspace (two Crockford symbols, a letter among them) with its DECOMP and REVIEW; defer-job without --id mints D1-<tail>" \
  || bad "minted ids wrong -- $m1 / $md"
pm=$(mi defer-job --id D5 --title "to promote" --reason r --trigger t --source manual >/dev/null 2>&1 && mi promote-deferred D5 --create-phase --slice S1 --name "promoted" 2>&1)
pp=$(printf '%s\n' "$pm" | sed -n 's/^promoted D5 -> \(P[^.]*\)\.S1: .*/\1/p')
printf '%s\n' "$pp" | grep -qxE "P2-$tail_re" && [ -f "$MW/works/phases/active/$pp/slices/$pp.S1/slice.json" ] && [ -d "$MW/works/deferred/promoted/D5" ] \
  && ok "promote-deferred --create-phase without --phase mints the next number (P2-<tail> after P1-<tail>) and takes a bare --slice S1" || bad "promote-deferred did not mint (or refused the bare suffix) -- $pm"
mi archive-phase "$pp" --force >/dev/null 2>&1; arch=$(ls "$MW/works/phases/archived")
re_tok=$(mi new-phase --phase "$pp" --name again --objective again 2>&1); re_act=$(mi new-phase --phase "$mp" --name again --objective again 2>&1)
nact=$(ls "$MW/works/phases/active" | wc -l | tr -d ' ')
p3=$(mi new-phase --name "After archive" --objective probe 2>&1 | sed -n 's/^created phase \(P[^:]*\):.*/\1/p')
d6=$(mi defer-job --title "after promote" --reason r --trigger t --source manual 2>&1 | sed -n 's/^created deferred job \(D[^:]*\):.*/\1/p')
printf '%s\n' "$arch" | grep -qE "^[0-9]{8}_[0-9]{6}_${pp}_to_promote$" && printf '%s\n' "$re_tok" | grep -q "phase already exists (archived): $pp" \
  && printf '%s\n' "$re_act" | grep -q "phase already exists: $mp" && [ "$nact" = 1 ] \
  && printf '%s\n' "$p3" | grep -qxE "P3-$tail_re" && printf '%s\n' "$d6" | grep -qxE "D6-$tail_re" \
  && ok "a tailed phase archives as <stamp>_P2-<tail>_<slug>; new-phase refuses an explicit id that exists active or archived (an archived id is spent); the next mint counts the archived P2 (P3-<tail>) and the promoted D5 (D6-<tail>)" \
  || bad "archived tailed id not spent, or the next number missed it -- $arch / $re_tok / $re_act / $nact / $p3 / $d6"
( for n in 9 10; do mi new-phase --phase "P$n" --name "Numeric $n" --objective probe || exit 1; done \
  && for d in D10 D2; do mi defer-job --id "$d" --title "$d" --reason r --trigger t --source manual || exit 1; done && mi_owe P9 && mi_owe P10 ) >/dev/null 2>&1 \
  || bad "mixed-id probe: setup failed"
rot_num=$(mi rotate-backlog 2>&1)
printf '%s\n' "$rot_num" | grep -qx 'docs_phase_proposal=P9, P10' && printf '%s\n' "$rot_num" | grep -qx 'name=Consolidate the doc impact of P9–P10' \
  && printf '%s\n' "$rot_num" | grep -qE "^phase=P11-$tail_re$" \
  && ok "an all-numeric debt keeps v72's order and en-dash label (P9–P10), and the proposal's phase= mints the next number (P11-<tail>)" || bad "all-numeric rotate label changed -- $rot_num"
( mi new-phase --phase P11-ab --name "Tailed 11" --objective probe && mi_owe P11-ab ) >/dev/null 2>&1 || bad "mixed-id probe: tailed P11-ab setup failed"
rot_tail=$(mi rotate-backlog 2>&1)
printf '%s\n' "$rot_tail" | grep -qx 'docs_phase_proposal=P9, P10, P11-ab' && printf '%s\n' "$rot_tail" | grep -qx 'name=Consolidate the doc impact of P9–P11-ab' \
  && printf '%s\n' "$rot_tail" | grep -qE "^phase=P12-$tail_re$" \
  && ok "a tailed id joins a consecutive range with its ends written in full (P9–P11-ab), and an explicit tailed id counts toward the next number (P12-<tail>)" || bad "tailed range label wrong -- $rot_tail"
( mi new-phase --phase P46-k2 --name "Tailed 46" --objective probe && mi new-phase --phase P-7kq2 --name "Token" --objective probe \
  && mi defer-job --id D-m3xa --title token --reason r --trigger t --source manual && mi_owe "$mp" && mi_owe P46-k2 && mi_owe P-7kq2 ) >/dev/null 2>&1 || bad "mixed-id probe: could not pass $mp, P46-k2 or P-7kq2"
rot_mix=$(mi rotate-backlog 2>&1); val_mix=$(mi validate 2>&1); val_rc=$?
dlist=$(sed -n '/^## Open/,/^## Promoted/p' "$MW/works/deferred.md" | sed -n 's/^| `\([^`]*\)` |.*/\1/p' | tr '\n' ' ')
printf '%s\n' "$rot_mix" | grep -qx "docs_phase_proposal=$mp, P9, P10, P11-ab, P46-k2, P-7kq2" && printf '%s\n' "$rot_mix" | grep -qx "name=Consolidate the doc impact of $mp, P9, P10, P11-ab, P46-k2, P-7kq2" \
  && [ "$dlist" = "$mdid D2 $d6 D10 D-m3xa " ] && [ "$val_rc" -eq 0 ] && printf '%s\n' "$val_mix" | grep -q '^Workflow validation passed' \
  && ok "mixed ids (P1-<tail>, P9, P46-k2, P-7kq2) list numbered ids by number, then v73 tokens (rotate's proposal, the deferred dashboard: $dlist), and validate passes" \
  || bad "mixed ids out of order or invalid -- $rot_mix / deferred: $dlist / $val_mix"
# Two branches of one repo each mint a phase and a deferred job unseen by the other, so both draw number 1: the
# merge conflicts in generated files only, and taking either side then `rebuild` (payload/gitattributes) leaves
# both phases and both jobs, valid, and the shared number is refused until the tail is typed.
newtmp TBW; cp -R "$F" "$TBW/ws"; TW="$TBW/ws"; rm -rf "$TW/.git" "$TW/works/phases/active/"* "$TW/works/phases/archived/"* "$TW/works/deferred/"*/*; : > "$TW/works/events.jsonl"
tw() { ( cd "$TW" && python3 scripts/workflow.py "$@" ); }
tg() { git -C "$TW" -c user.email=smoke@example.invalid -c user.name=smoke "$@"; }
( tw rebuild && tg init -q && tg add -A && tg commit -qm base \
  && tg checkout -q -b one && tw new-phase --name "Branch one" --objective one && tw defer-job --title one --reason r --trigger t --source manual && tg add -A && tg commit -qm one \
  && tg checkout -q - && tg checkout -q -b two && tw new-phase --name "Branch two" --objective two && tw defer-job --title two --reason r --trigger t --source manual ) >/dev/null 2>&1 \
  || bad "two-branch probe: setup failed"
tb_p1=$(tg show --name-only --format= one | sed -n 's|^works/phases/active/\([^/]*\)/phase.json$|\1|p'); tb_d1=$(tg show --name-only --format= one | sed -n 's|^works/deferred/open/\([^/]*\)/deferred.json$|\1|p')
# Deterministic: a same-tail draw (1 in 924 per kind) is the add/add conflict the engine documents, never a silent
# mix -- so when branch two drew branch one's tail, it redoes its side with explicit, distinct tails.
if [ -d "$TW/works/phases/active/$tb_p1" ] || [ -d "$TW/works/deferred/open/$tb_d1" ]; then
  tb_t=ab; [ "$tb_p1" = P1-ab ] && tb_t=ac; tb_u=ab; [ "$tb_d1" = D1-ab ] && tb_u=ac
  ( tg reset -q --hard && tg clean -qfd && tw new-phase --phase "P1-$tb_t" --name "Branch two" --objective two \
    && tw defer-job --id "D1-$tb_u" --title two --reason r --trigger t --source manual ) >/dev/null 2>&1 || bad "two-branch probe: the same-tail redo failed"
fi
( tg add -A && tg commit -qm two ) >/dev/null 2>&1 || bad "two-branch probe: branch two did not commit"
tg merge -q --no-edit one >/dev/null 2>&1; conflicted=$(tg diff --name-only --diff-filter=U | tr '\n' ' ')
outside=$(printf '%s\n' $conflicted | grep -vxE 'works/(state\.json|index\.json|backlog\.md|deferred\.md)')
( for f in $conflicted; do tg checkout --theirs -- "$f" || exit 1; done; tw rebuild && tg add -A && tg commit -qm merge ) >/dev/null 2>&1
tb_val=$(tw validate 2>&1); tb_rc=$?; tb_run=$(tw run-phases 1 2>&1); tb_run_rc=$?
[ -z "$outside" ] && [ "$(ls "$TW/works/phases/active" | grep -cE "^P1-$tail_re$")" = 2 ] && [ "$(ls "$TW/works/deferred/open" | grep -cE "^D1-$tail_re$")" = 2 ] \
  && [ "$tb_rc" -eq 0 ] && [ -z "$(tg status --porcelain)" ] && [ "$(grep -c '"type": "phase_created"' "$TW/works/events.jsonl")" = 2 ] \
  && [ "$tb_run_rc" -eq 2 ] && printf '%s\n' "$tb_run" | grep -qE "^refused=1 -- names P1-$tail_re, P1-$tail_re: type the tail" \
  && ok "two branches each mint a phase and a deferred job with the same number (P1-, D1-) and merge with conflicts only in generated files (${conflicted:-none}); either side + rebuild validates, and run-phases 1 then lists both" \
  || bad "two-branch mint did not merge clean -- conflicted: $conflicted / outside: $outside / $tb_val / $tb_run"

# ---------------------------------------------------------------------------
echo "== Test 10f: brief names -- 13 / P13 name the one P13-<tail>, a shared number is refused and listed, an exact P12 wins, 7kq2 / P-7kq2 still name a v73 id, and the CI seed parses all three branch shapes =="
# Same emptied copy of $F as 10c: a v73 token phase beside P12 and P12-ab. Brief names go through one choke point after argparse.
newtmp BNW; cp -R "$F" "$BNW/ws"; BN="$BNW/ws"; rm -rf "$BN/.git" "$BN/works/phases/active/"* "$BN/works/phases/archived/"* "$BN/works/deferred/"*/*; bn() { ( cd "$BN" && python3 scripts/workflow.py "$@" ); }
bn_pid=7kq2; bn_up=7KQ2
( bn new-phase --phase "P-$bn_pid" --name "Brief" --objective probe && bn new-phase --phase 12 --name "Numbered" --objective probe \
  && bn new-phase --phase P12-ab --name "Twelve tailed" --objective probe ) >/dev/null 2>&1 || bad "brief-name probe: setup failed"
r1=$(bn run-phases "$bn_pid" 12 2>&1); r2=$(bn run-phases "P-$bn_up, p12" "$bn_pid" 2>&1); r3=$(bn run-phases "P$bn_pid" 2>&1); r3_rc=$?; r4=$(bn run-phases gate 2>&1); r4_rc=$?
printf '%s\n' "$r1" | grep -qx "run=P-$bn_pid,P12" && printf '%s\n' "$r2" | grep -qx "queue=P-$bn_pid,P12" \
  && [ "$r3_rc" -eq 2 ] && printf '%s\n' "$r3" | grep -q "^refused=P$bn_pid .*P-$bn_pid" && ! printf '%s\n' "$r3" | grep -q '^queue=' && [ "$r4_rc" -eq 2 ] && printf '%s\n' "$r4" | grep -q '^refused=gate ' \
  && ok "run-phases takes a bare token, P-token in any case and 12/p12 (the exact P12 wins over P12-ab), keeps the order and drops duplicates, and refuses P<token> without its dash and a mode word" \
  || bad "run-phases brief names wrong -- $r1 / $r2 / $r3 / $r4"
bn_gate=$(bn accept-gate "$bn_pid" --waive --note probe 2>&1); bn_show=$(bn accept-gate "p-$bn_up" 2>&1); bn_old=$(bn accept-gate 12 2>&1); bn_bad=$(bn accept-gate "P$bn_pid" 2>&1); bn_bad_rc=$?
bn_did=$(bn defer-job --title brief --reason r --trigger t --source manual 2>&1 | sed -n 's/^created deferred job \(D[^:]*\):.*/\1/p'); bn_drop=$(bn drop-deferred 1 --reason x 2>&1)
printf '%s\n' "$bn_gate" | grep -qx "phase P-$bn_pid: operator acceptance WAIVED -- probe" && printf '%s\n' "$bn_show" | grep -qx "phase=P-$bn_pid" && printf '%s\n' "$bn_old" | grep -qx 'phase=P12' \
  && [ "$bn_bad_rc" -ne 0 ] && printf '%s\n' "$bn_bad" | grep -q "not a phase id" && printf '%s\n' "$bn_did" | grep -qxE "D1-$tail_re" && printf '%s\n' "$bn_drop" | grep -q "^dropped $bn_did:" \
  && ok "a phase or deferred-id argument takes the brief name (accept-gate 7kq2, p-7KQ2, 12; drop-deferred 1 names the one D1-<tail>) and refuses P7kq2 with the shapes" || bad "brief names on commands wrong -- $bn_gate / $bn_show / $bn_old / $bn_bad / $bn_did / $bn_drop"
bn_t=$(bn new-phase --name "Tailed" --objective probe 2>&1 | sed -n 's/^created phase \(P[^:]*\):.*/\1/p'); bn_tu=$(printf '%s' "${bn_t#P13-}" | tr '[:lower:]' '[:upper:]')
r5=$(bn run-phases 13 "p13-$bn_tu" 2>&1); bn_ag=$(bn accept-gate p13 2>&1)
bn_sl=$(bn new-slice --phase 13 --slice 13.S1 --name brief --kind implementation --risk low --depends-on none 2>&1)
bn_t2=ab; [ "$bn_t" = P13-ab ] && bn_t2=ac
bn new-phase --phase "13-$bn_t2" --name "Twin" --objective probe >/dev/null 2>&1 || bad "brief-name probe: the twin P13-$bn_t2 failed"
r6=$(bn run-phases 13 2>&1); r6_rc=$?; bn_amb=$(bn accept-gate 13 2>&1); bn_amb_rc=$?; bn_full=$(bn accept-gate "p13-$(printf '%s' "$bn_t2" | tr '[:lower:]' '[:upper:]')" 2>&1)
printf '%s\n' "$bn_t" | grep -qxE "P13-$tail_re" && printf '%s\n' "$r5" | grep -qx "run=$bn_t" && printf '%s\n' "$bn_ag" | grep -qx "phase=$bn_t" \
  && printf '%s\n' "$bn_sl" | grep -q "^created slice $bn_t.S1: " \
  && [ "$r6_rc" -eq 2 ] && printf '%s\n' "$r6" | grep -q "^refused=13 -- names .*$bn_t" && printf '%s\n' "$r6" | grep -q "^refused=13 -- names .*P13-$bn_t2" && ! printf '%s\n' "$r6" | grep -q '^queue=' \
  && [ "$bn_amb_rc" -ne 0 ] && printf '%s\n' "$bn_amb" | grep -q "names 2 phases numbered 13: .*type the tail" && printf '%s\n' "$bn_full" | grep -qx "phase=P13-$bn_t2" \
  && ok "a bare new-phase mints the next number over P12 and P12-ab ($bn_t); 13, p13 and p13-<TAIL> name it while it is the only P13 (run-phases, accept-gate, new-slice --slice 13.S1); a second P13 makes 13 a refusal listing both, and 13-<tail> still names one" \
  || bad "the number lookup is wrong -- $bn_t / $r5 / $bn_ag / $bn_sl / $r6 / $bn_amb / $bn_full"
seed_block=$(sed -n '/# branch-parse:begin/,/# branch-parse:end/p' "$SRC/github/workflows/workspace-ci.yml")
newtmp CIW; mkdir -p "$CIW/works/phases/active/P46-k2" && : > "$CIW/works/phases/active/P46-k2/phase.json"
ci_parse() { ( cd "$CIW" && HEAD_REF=$1 && phase= && eval "$seed_block" && printf '%s' "$phase" ); }
c1=$(ci_parse "phase/P-$bn_pid-slug"); c2=$(ci_parse phase/P12-slug); c3=$(ci_parse phase/feature-x); c4=$(ci_parse phase/P46-k2-some-slug); c5=$(ci_parse phase/P12-ab-slug)
[ -n "$seed_block" ] && [ "$c1" = "P-$bn_pid" ] && [ "$c2" = "P12" ] && [ -z "$c3" ] && [ "$c4" = "P46-k2" ] && [ "$c5" = "P12" ] \
  && ok "the CI seed's branch parse gives P46-k2 for phase/P46-k2-slug (its folder exists), P12 for phase/P12-slug and for phase/P12-ab-slug (no P12-ab folder: a slug word), P-token for phase/P-token-slug, and nothing for another branch" \
  || bad "the CI seed's branch parse is wrong -- [$c1] [$c2] [$c3] [$c4] [$c5]"

# ---------------------------------------------------------------------------
echo "== Test 10g: P44 doc versions by minute -- v<yyMMddHHmm> in UTC beside v0001, a same-minute second version takes the next minute, docs/current follows latest, validate takes both shapes =="
# A fresh install (its docs are v0001_bootstrap). The number is still the digits after `v`, per doc.
newtmp DVW; DV="$DVW/ws"; sh "$BOOT" "$DV" --at-root --name "DocVer" --summary "dv" >/dev/null 2>&1 || bad "doc-version probe: the fresh install failed"
dv() { ( cd "$DV" && python3 scripts/workflow.py "$@" ); }
dv_v1=$(dv doc-new-version --doc product --summary "first by minute" --source manual 2>&1 | sed -n 's|^created doc version product/\(v[0-9]*\)_.*|\1|p')
dv_v2=$(dv doc-new-version --doc product --summary "second by minute" --source manual 2>&1 | sed -n 's|^created doc version product/\(v[0-9]*\)_.*|\1|p')
if python3 - "$dv_v1" "$dv_v2" <<'PY'
import re, sys
from datetime import datetime, timedelta, timezone
a, b = sys.argv[1:3]
assert re.fullmatch(r"v[0-9]{10}", a) and re.fullmatch(r"v[0-9]{10}", b), (a, b)
assert "v0001" < a < b and int(a[1:]) > 1, (a, b)
t = datetime.strptime(a[1:], "%y%m%d%H%M").replace(tzinfo=timezone.utc)
assert abs(datetime.now(timezone.utc) - t) <= timedelta(minutes=3), (a, "is not the current UTC minute")
PY
then ok "a new doc version is v + 10 digits (the current UTC minute) and sorts after v0001"; else bad "a new doc version is not v<yyMMddHHmm> after v0001 -- [$dv_v1] [$dv_v2]"; fi
python3 - "$dv_v1" "$dv_v2" <<'PY' && ok "a second version of the same doc in the same minute takes the next minute" || bad "the same-minute second version did not take the next minute -- [$dv_v1] [$dv_v2]"
import sys
from datetime import datetime, timedelta
a, b = (datetime.strptime(x[1:], "%y%m%d%H%M") for x in sys.argv[1:3])
assert b - a == timedelta(minutes=1), (a, b)
PY
dv_path=$(ls "$DV"/docs/versions/product/"$dv_v2"_*.md 2>/dev/null | head -n 1)
printf '\nBY-MINUTE-PROBE\n' >> "$dv_path"; dv rebuild-docs >/dev/null 2>&1
dv_docs=$(dv docs 2>&1)
[ -n "$dv_path" ] && cmp -s "$dv_path" "$DV/docs/current/product.md" && printf '%s\n' "$dv_docs" | grep -q "^product: latest=${dv_v2}_" && grep -q "BY-MINUTE-PROBE" "$DV/docs/current/product.md" \
  && ok "docs/current is generated from the new latest (docs lists it)" || bad "docs/current did not follow the new latest ($dv_v2)"
dv_val=$(dv validate 2>&1); dv_rc=$?
[ "$dv_rc" -eq 0 ] && printf '%s\n' "$dv_val" | grep -q '^Workflow validation passed' && ! printf '%s\n' "$dv_val" | grep -q 'has the highest version number' \
  && ok "validate passes on a doc holding both shapes (v0001 and two v<minute>) with no latest warning" || bad "validate failed or warned on a mix of both version shapes (rc=$dv_rc) -- $dv_val"
python3 - "$DV/docs/index.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); info = d["docs"]["product"]
info["latest"] = info["versions"][0]["id"]
info["versions"].append(dict(info["versions"][-1], path=info["versions"][-1]["path"] + ".dup"))
json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
dv_val=$(dv validate 2>&1); dv_rc=$?
printf '%s\n' "$dv_val" | grep -q 'warning: doc product: latest is v0001_bootstrap, but v[0-9]\{10\}_.* has the highest version number' \
  && printf '%s\n' "$dv_val" | grep -q "duplicate doc version number in docs/index.json: product v$(printf '%s' "$dv_v2" | cut -c2-) claimed by both" && [ "$dv_rc" -ne 0 ] \
  && ok "validate warns when latest is not the highest version and still errors on a duplicate number (named as written)" || bad "validate missed the latest-not-highest warning or the duplicate (rc=$dv_rc) -- $dv_val"

echo "== Test 10h: v74 a read leaves the tree clean -- next, run-phases, rebuild, rebuild-docs and validate on a committed install change no tracked file; a real change still moves the stamps =="
# Before v74 every rebuild rewrote state.json's updated_at and both index.json stamps, so a plain
# `next` dirtied the tree. The sleep makes a rewritten stamp differ from the committed one.
newtmp RCW; RC="$RCW/ws"; sh "$BOOT" "$RC" --at-root --name "ReadClean" --summary "rc" >/dev/null 2>&1 || bad "read-clean probe: the fresh install failed"
rcw() { ( cd "$RC" && python3 scripts/workflow.py "$@" ); }
rc_stamp() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["updated_at"])' "$RC/works/state.json" 2>/dev/null; }
( cd "$RC" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
    && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "read-clean baseline" >/dev/null 2>&1 ) \
  || bad "read-clean probe: could not make the fixture a git repo"
sleep 1
for rc_cmd in next run-phases rebuild rebuild-docs validate; do rcw "$rc_cmd" >/dev/null 2>&1; done
rc_dirty=$(git -C "$RC" status --porcelain 2>&1)
[ -z "$rc_dirty" ] && ok "next, run-phases, rebuild, rebuild-docs and validate leave a committed install's tree clean (no stamp-only write)" \
  || bad "a read dirtied the tree -- $rc_dirty"
rc_before=$(rc_stamp); sleep 1
rcw new-phase --name "Read clean probe" --objective "a real change" >/dev/null 2>&1
rc_after=$(rc_stamp); rc_dirty=$(git -C "$RC" status --porcelain 2>&1)
[ -n "$rc_before" ] && [ "$rc_before" != "$rc_after" ] && printf '%s\n' "$rc_dirty" | grep -q '^ M works/state.json$' && printf '%s\n' "$rc_dirty" | grep -q '^ M works/index.json$' \
  && ok "a real change (new-phase) still rewrites state.json and index.json with a new stamp" \
  || bad "a real change did not move the stamps ($rc_before -> $rc_after) -- $rc_dirty"

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
echo "== Test 12: v43 worktree on request -- nothing unasked, parallel-start on a dirty tree, the nested worktree, the exclude line, the retired pins; v86 the no-notes consolidation flip and the gate's checked exemption =="
newtmp W
sh "$BOOT" "$W" --at-root --name "Worktree" --summary "worktree probe" >/dev/null 2>&1 || bad "v43 probe: fresh install failed"
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
# (i) v86: a no-notes pass settles a worktree phase's debt; the gate's checked exemption, both ways.
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(not (d.get('consolidation') == d['execution'].get('consolidation') == 'done'))" \
    "$wt/works/phases/active/P1/phase.json" \
  && ok "a passing review with no Doc impact note flips a worktree phase's consolidation to done (both fields)" \
  || bad "the no-notes pass left the worktree phase owing consolidation"
( cd "$W" && python3 scripts/workflow.py set-phase-status P2 in_progress >/dev/null 2>&1 ) || bad "v86 probe: could not make the default stream busy"
g_out=$( cd "$W" && python3 scripts/workflow.py parallel-gate P1 2>&1 ); g_rc=$?
[ "$g_rc" -eq 0 ] && printf '%s\n' "$g_out" | grep -q "^exemption=phase-folder-only (" && printf '%s\n' "$g_out" | grep -q "^GATE OPEN" \
  && ok "parallel-gate opens on a busy default stream for a branch touching only its phase folder and the works files" \
  || bad "the checked exemption did not open the gate (rc=$g_rc) -- $g_out"
( cd "$wt" && git checkout -q -b probe/extra && mkdir -p src && printf 'x\n' > src/probe.py && git add src/probe.py \
    && git commit -qm "probe: a product file" && git checkout -q phase/P1-worktree_probe ) >/dev/null 2>&1 || bad "v86 probe: could not cut the product-file branch"
g_out=$( cd "$W" && python3 scripts/workflow.py parallel-gate P1 --branch-ref probe/extra 2>&1 ); g_rc=$?
[ "$g_rc" -ne 0 ] && printf '%s\n' "$g_out" | grep -q "^exemption=none: src/probe.py" && printf '%s\n' "$g_out" | grep -q "default stream is not quiet: phase P2" \
  && ok "a branch touching any other path gets no exemption: the busy default stream still closes the gate" \
  || bad "the exemption let a product-file branch past a busy default stream (rc=$g_rc) -- $g_out"
( cd "$W" && git branch -q -D probe/extra && python3 scripts/workflow.py set-phase-status P2 planned >/dev/null 2>&1 ) || bad "v86 probe: could not reset the probe"
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
echo "== Test 13: schema-2 design record -- design-open makes a job and refuses a second open round of it, one connected job per slice (P46-nb: --new-job refused while the slice has an open round, the merge after the close, a legacy multi-job slice still passes and takes --job, --critique, the 10-Page size warning, mounted boards not counted), the board lint (leaves-canvas, same-target-list, unlinked-page), design-check names a missing board, a missing support line, a .. reference and a title gap, design-canvas / design-system / design-publish-plan (system copies on a first publish or a changed pin only), design-preview skips honestly without a browser, v61 design-preview machine checks on fixture boards (non-text-contrast, reflow and overprint, keyboard, the state bar, --strict, the .preview render and contact sheets; skipped with no browser), design-close snapshots and signs, a superseded round's slice reuses its job, v61 design-readback / design-sign / a generated SIGNOFF.md / the absolute-path lint and wave briefs, design-migrate --to 2; claude-design/ is skipped, the pre-v47 design-migrate, design-register is gone =="
# Runs in the fresh workspace $F.
newtmp DZ
DR="$F/docs/reference/design"
JD="$DR/jobs/01-signin"
CP="$JD/canvas/project"
dw() { ( cd "$F" && python3 scripts/workflow.py "$@" ); }
tree_sig() { ( cd "${1:-$DR}" && find . -type f | LC_ALL=C sort | while read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done ); }
# 1. The slice's first round creates its job; at most one open round per job (P36.S5C: per job, not per project).
dw design-init --id smoke-design --name "Smoke design" >/dev/null 2>&1 || bad "design probe: design-init failed"
open_out=$(dw design-open --slug signin --slice P9.S1 2>&1); open_rc=$?
out=$(dw design-open --slug other --slice P9.S1 2>&1); rc=$?
if [ "$open_rc" -eq 0 ] && [ -f "$JD/job.json" ] && [ -f "$JD/rounds/01-signin/round.json" ] \
    && [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -Fq 'refused -- 01-signin/01-signin is open' \
    && [ ! -e "$JD/rounds/02-other" ] && [ ! -e "$DR/jobs/02-other" ]; then
  ok "design-open creates job 01-signin with round 01-signin, and a second round of the same job while one is open refuses and creates nothing"
else bad "design-open did not create the job and round, or a second round of the open job was not refused (rc=$open_rc/$rc) -- $open_out $out"; fi
# 2. A minimal valid canvas tree passes; one broken variant names each kind of break.
python3 - "$JD" <<'CANVAS' || bad "design probe: could not write the canvas tree"
import json, pathlib, sys
job = pathlib.Path(sys.argv[1])
project = job / "canvas/project"
(job / "rounds/01-signin/handoff.md").write_text("# handoff\n")
project.mkdir(parents=True, exist_ok=True)
boards = {"Main.dc.html": {"x": 0, "y": 0, "w": 880, "h": 560, "title": "01 · Sign-in"},
          "Error.dc.html": {"x": 960, "y": 0, "w": 880, "h": 560, "title": "02 · Error"}}
index = {"v": 3, "createdOnFiles": {"v": 1, "at": "2026-10-14T00:00:00Z"}, "title": "Sign-in", "launch": {"view": "canvas"},
         "pages": [], "boards": boards, "order": list(boards), "notes": {}, "designSystems": []}
(project / "canvas.json").write_text(json.dumps(index, ensure_ascii=False), encoding="utf-8")
for name, board in boards.items():
    (project / name).write_text(
        '<!doctype html>\n<html><head>\n<script src="./support.js"></script>\n'
        '<link rel="stylesheet" href="ds/smoke/tokens.css">\n</head>\n'
        # the allowed references besides a relative path inside project/: #, data:, https, /_blob/, a {{hole}}
        '<body><x-dc><a href="#top"><img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=" alt=""></a>'
        '<a href="https://example.com/">more</a><img src="/_blob/abc123" alt=""><img src="{{logo}}" alt="">'
        f'<p>{board["title"]}</p></x-dc></body></html>\n', encoding="utf-8")
CANVAS
mkdir -p "$DZ/good" && cp -R "$CP/." "$DZ/good/"
python3 - "$CP" <<'BREAK' || bad "design probe: could not break the canvas tree"
import json, pathlib, sys
project = pathlib.Path(sys.argv[1])
index = json.loads((project / "canvas.json").read_text(encoding="utf-8"))
index["boards"]["Gone.dc.html"] = {"x": 0, "y": 680, "w": 400, "h": 300, "title": "04 · Gone"}  # no file, and no 03
index["order"].append("Gone.dc.html")
(project / "canvas.json").write_text(json.dumps(index, ensure_ascii=False), encoding="utf-8")
main = (project / "Main.dc.html").read_text(encoding="utf-8")
main = main.replace('<script src="./support.js"></script>\n', "").replace('href="ds/smoke/tokens.css"', 'href="../escape.css"')
(project / "Main.dc.html").write_text(main, encoding="utf-8")
BREAK
out=$(dw design-check 01-signin 2>&1); rc=$?
cp -R "$DZ/good/." "$CP/"
ok_out=$(dw design-check 2>&1); ok_rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -Fq "board 'Gone.dc.html' is listed but its file is missing" \
    && printf '%s\n' "$out" | grep -Fq 'Main.dc.html: missing the exact line <script src="./support.js"></script>' \
    && printf '%s\n' "$out" | grep -Fq "Main.dc.html: references '../escape.css' (" \
    && printf '%s\n' "$out" | grep -Fq 'no board titled "03 · …"' && [ "$ok_rc" -eq 0 ]; then
  ok "design-check names a missing listed board, a missing support line, a .. reference and a title gap (exit 1), and passes the valid tree with #, data:, https, /_blob/ and {{hole}} references"
else bad "design-check missed a break in the canvas tree, or failed the valid tree (rc=$rc, valid rc=$ok_rc) -- $out $ok_out"; fi
# 3. The canvas record and the publish plan: null for a removed board; v60 (P36.S9): the system install
# copies only on a first publish or a changed system pin (canvas.system), never on a plain republish.
url_out=$(dw design-canvas 01-signin --url https://example.com/artifact/abc 2>&1); url_rc=$?
dw design-canvas 01-signin --url https://claude.ai/artifact/SmokeCanvas1 >/dev/null 2>&1 \
  || bad "design probe: design-canvas --url failed"
dw design-system --artifact https://claude.ai/artifact/SmokeSystem1 --namespace smoke --version 5-sys \
  --files tokens.json,tokens.css >/dev/null 2>&1 || bad "design probe: design-system failed"
pin() { python3 - "$CP/canvas.json" "$1" <<'PIN'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
index = json.loads(path.read_text(encoding="utf-8"))
index["designSystems"] = [{"title": "Smoke", "namespace": "smoke", "artifact": "https://claude.ai/artifact/SmokeSystem1",
                           "version": sys.argv[2], "copiedAt": "2026-10-18T00:00:00Z"}]
path.write_text(json.dumps(index, ensure_ascii=False), encoding="utf-8")
PIN
}
# plan_is <expect-system-copies: 1|0> <expect Error.dc.html: live|null>
plan_is() { dw design-publish-plan 01-signin 2>&1 | python3 -c '
import json, sys
plan = json.load(sys.stdin)
system = "https://claude.ai/artifact/SmokeSystem1"
assert plan["url"] == "https://claude.ai/artifact/SmokeCanvas1", plan
assert plan["root"].endswith("/jobs/01-signin/canvas") and plan["file_path"].endswith("/jobs/01-signin/canvas/project/canvas.json"), plan
want = {"project/Main.dc.html": "project/Main.dc.html",
        "project/Error.dc.html": "project/Error.dc.html" if sys.argv[2] == "live" else None}
if sys.argv[1] == "1":
    want.update({"project/ds/smoke/tokens.json": {"artifact": system, "path": "project/tokens.json"},
                 "project/ds/smoke/tokens.css": {"artifact": system, "path": "project/tokens.css"}})
assert plan["files"] == want, plan["files"]
' "$1" "$2" >/dev/null 2>&1; }
pin 5-sys || bad "design probe: could not pin the system in canvas.json"
plan_is 1 live && first_ok=1 || first_ok=0
dw design-canvas 01-signin --version 1700000000-aaaa >/dev/null 2>&1 || bad "design probe: design-canvas --version failed"
published=$(python3 -c 'import json, sys; c = json.load(open(sys.argv[1]))["canvas"]; print(" ".join(c["published"]), c["system"])' "$JD/job.json")
[ "$url_rc" -ne 0 ] && printf '%s\n' "$url_out" | grep -Fq 'is not an Artifact address' \
  && [ "$published" = "project/Error.dc.html project/Main.dc.html project/canvas.json 5-sys" ] \
  && ok "design-canvas rejects a non-claude host, and --version records the published file list and the installed system pin (canvas.system)" \
  || bad "design-canvas accepted a foreign host or recorded the wrong published list or system pin (rc=$url_rc) -- $url_out / $published"
mv "$CP/Error.dc.html" "$DZ/Error.dc.html"
python3 - "$CP/canvas.json" <<'DROP' || bad "design probe: could not drop the board from canvas.json"
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
index = json.loads(path.read_text(encoding="utf-8"))
del index["boards"]["Error.dc.html"]
index["order"].remove("Error.dc.html")
path.write_text(json.dumps(index, ensure_ascii=False), encoding="utf-8")
DROP
plan_is 0 null && again_ok=1 || again_ok=0
dw design-system --artifact https://claude.ai/artifact/SmokeSystem1 --namespace smoke --version 6-sys \
  --files tokens.json,tokens.css >/dev/null 2>&1 && pin 6-sys || bad "design probe: could not move the system to 6-sys"
plan_is 1 null && moved_ok=1 || moved_ok=0
python3 - "$JD/job.json" <<'PRE60' || bad "design probe: could not write a pre-v60 job.json"
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
job = json.loads(path.read_text(encoding="utf-8"))
del job["canvas"]["system"]
path.write_text(json.dumps(job, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PRE60
pre60_chk=$(dw design-check 01-signin 2>&1); pre60_rc=$?
plan_is 0 null && pre60_ok=1 || pre60_ok=0
if [ "$first_ok$again_ok$moved_ok$pre60_ok" = "1111" ] && [ "$pre60_rc" -eq 0 ]; then
  ok "design-publish-plan maps each project file to itself and a board removed since the last publish to null; the system install copies ride a first publish, are left out of a republish, come back when canvas.json's pin moves, and a pre-v60 job.json without canvas.system is valid and leaves them out"
else bad "design-publish-plan sent or dropped the system copies at the wrong time (first=$first_ok republish=$again_ok moved=$moved_ok pre-v60=$pre60_ok check rc=$pre60_rc) -- $(dw design-publish-plan 01-signin 2>&1) $pre60_chk"; fi
# P36.S4: design-preview with no browser is an honest skip -- it says so, exits 0 and writes nothing.
printf '/* a stand-in runtime path; never run */\n' > "$DZ/dc-runtime.js"
before=$(tree_sig)
out=$( export AGENTIC_DESIGN_BROWSER=/nonexistent; dw design-preview 01-signin --runtime "$DZ/dc-runtime.js" 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qx 'preview=skipped reason=no-browser' && ! printf '%s\n' "$out" | grep -q '^board=' \
  && [ "$(tree_sig)" = "$before" ] \
  && ok "design-preview with no browser prints preview=skipped reason=no-browser, exits 0 and leaves the design root byte-identical" \
  || bad "design-preview did not skip honestly without a browser (rc=$rc) -- $out"
# P36.S5A: --click skips the same way: no state or link line, no --out folder, no preview.json.
out=$( export AGENTIC_DESIGN_BROWSER=/nonexistent; dw design-preview 01-signin --runtime "$DZ/dc-runtime.js" --click --out "$DZ/pv" 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qx 'preview=skipped reason=no-browser' && ! printf '%s\n' "$out" | grep -Eq '^(board=|state |link )' \
  && [ ! -e "$DZ/pv" ] && [ "$(tree_sig)" = "$before" ] \
  && ok "design-preview --click with no browser prints preview=skipped reason=no-browser, exits 0 and writes nothing" \
  || bad "design-preview --click did not skip honestly without a browser (rc=$rc) -- $out"
# v61 (P37.S6): the machine checks on tiny fixture boards, in a copy of this workspace (a job of its own).
# Each fixture shows one finding: a 1.5:1 button border (non-text-contrast) beside a 3.5:1 one (none);
# two labels that cross only at 200% text (overprint, text200 only); a row wider than 320px (reflow,
# w320 only); a <span> with a click listener and no tabindex that opens a dialog (keyboard); a sticky
# state bar (state-bar, rendered and static). --strict exits 1 naming the blocking checks, the render
# stays in .preview/<job>/<round>/, and --contact-sheet writes one sheet per board. With no browser on
# this machine the block says so and asserts nothing (the honest skip above still runs everywhere).
newtmp MC; cp -R "$F/." "$MC/"
mc() { ( cd "$MC" && python3 scripts/workflow.py "$@" ); }
MJ=$(mc design-open --slug fixture --slice P9.S6 2>&1 | sed -n 's#^design-open: created job .*/jobs/\([^/]*\)/ .*#\1#p')
[ -n "$MJ" ] || bad "machine-check probe: design-open failed"
python3 - "$MC/docs/reference/design/jobs/$MJ/canvas/project" <<'FIXTURE' || bad "machine-check probe: could not write the fixture boards"
import json, pathlib, sys
project = pathlib.Path(sys.argv[1])
project.mkdir(parents=True, exist_ok=True)
boards = {"Main.dc.html": {"x": 0, "y": 0, "w": 800, "h": 600, "title": "01 · Page — Fixture", "expand": "fill", "is_interactive": True},
          "Borders.dc.html": {"x": 0, "y": 700, "w": 400, "h": 200, "title": "02 · Component — Borders"}}
index = {"v": 3, "createdOnFiles": {"v": 1, "at": "2026-10-20T00:00:00Z"}, "title": "Fixture", "launch": {"view": "canvas"},
         "pages": [], "boards": boards, "order": list(boards), "notes": {}, "designSystems": []}
(project / "canvas.json").write_text(json.dumps(index), encoding="utf-8")
head = '<!doctype html>\n<html><head>\n<script src="./support.js"></script>\n</head>\n'
(project / "Main.dc.html").write_text(head + '''<body style="margin:0;background:#fff;color:#111;font:16px/1.4 Arial,sans-serif"><x-dc>
<div data-proto="state-bar" style="position:sticky;top:0;background:#eee"><div role="group" aria-label="Fixture"><button type="button" aria-pressed="true" style="min-height:44px">Only</button></div></div>
<h1>Fixture</h1>
<div style="position:relative;height:60px"><span style="position:absolute;left:0;top:0">Alpha label</span><span style="position:absolute;left:130px;top:0">Beta</span></div>
<div style="min-width:360px;background:#ddd">A row 360px wide</div>
<p><span id="pop" style="cursor:pointer">Open the note</span></p>
<button type="button" style="width:120px;height:48px;background:#fff;border:1px solid #888;color:#111">Go</button>
</x-dc>
<script>document.getElementById('pop').addEventListener('click', () => { const d = document.createElement('div');
  d.setAttribute('role', 'dialog'); d.setAttribute('aria-label', 'Note'); d.textContent = 'The note'; document.body.appendChild(d); });</script>
</body></html>
''', encoding="utf-8")
(project / "Borders.dc.html").write_text(head + '''<body style="margin:0;background:#fff;color:#111;font:16px Arial,sans-serif"><x-dc>
<button type="button" style="width:120px;height:48px;background:#fff;border:1px solid #d0d0d0;color:#111">Weak</button>
<button type="button" style="width:120px;height:48px;background:#fff;border:1px solid #8a8a8a;color:#111">Strong</button>
</x-dc></body></html>
''', encoding="utf-8")
FIXTURE
printf '/* a stand-in runtime: the fixture boards need none */\n' > "$MC/stub-runtime.js"
mc_out=$(mc design-preview $MJ --runtime stub-runtime.js --strict --contact-sheet 2>&1); mc_rc=$?
if printf '%s\n' "$mc_out" | grep -qx 'preview=skipped reason=no-browser'; then
  printf 'SKIP: %s\n' "design-preview machine checks on fixture boards: no Chrome/Chromium on this machine (nothing asserted)"
else
  MCO="$MC/docs/reference/design/.preview/$MJ/01-fixture"
  mc_lint=$(mc design-check $MJ 2>&1)
  has() { printf '%s\n' "$mc_out" | grep -Eq "$1"; }
  [ "$mc_rc" -eq 1 ] && has '^self_check=fail blocking=non-text-contrast:1,reflow:1,overprint:1,keyboard:1$' \
    && ok "design-preview --strict exits 1 and self_check=fail names the blocking checks (non-text-contrast, reflow, overprint, keyboard)" \
    || bad "design-preview --strict did not fail the self-check as expected (rc=$mc_rc) -- $(printf '%s\n' "$mc_out" | grep -E '^(issue|self_check)')"
  has 'board=Borders\.dc\.html view=frame check=non-text-contrast: button "Weak": the control.s boundary is 1\.[45][0-9]:1' \
    && ! has 'check=non-text-contrast: button "Strong"' \
    && ok "non-text-contrast names a 1.5:1 button border and passes a 3.5:1 one" \
    || bad "non-text-contrast missed the 1.5:1 border or flagged the 3.5:1 one -- $(printf '%s\n' "$mc_out" | grep 'non-text')"
  has 'view=text200 check=overprint: span "Alpha label" and span "Beta" overprint' && ! has 'view=w320 check=overprint' \
    && has 'view=w320 check=reflow: content is 36[0-9]px wide at 320px wide' && ! has 'view=text200 check=reflow' \
    && ok "overprint names two labels that cross only at 200% text, and reflow a row wider than 320px only at 320px" \
    || bad "overprint or reflow missed its fixture or fired in the wrong view -- $(printf '%s\n' "$mc_out" | grep -E 'overprint|reflow')"
  has 'check=keyboard: span#pop "Open the note" opens dialog .*on click \(a click handler\) but never keyboard focus' \
    && ok "keyboard names a <span> with a click listener and no tabindex, and the dialog it opens" \
    || bad "keyboard missed the click-only span -- $(printf '%s\n' "$mc_out" | grep -E 'keyboard')"
  has 'board=Main\.dc\.html view=frame check=state-bar: the state bar is position: sticky' \
    && printf '%s\n' "$mc_lint" | grep -q "Main.dc.html: the state bar's own style is position: sticky (check=state-bar)" \
    && ok "a sticky state bar is a rendered state-bar issue and a design-check lint" \
    || bad "the sticky state bar was not flagged by both halves -- $(printf '%s\n' "$mc_out" | grep state-bar) / $mc_lint"
  sheets=$(ls "$MCO" 2>/dev/null | grep -c '\.sheet\.png$')
  [ "$sheets" -eq 2 ] && [ -f "$MCO/preview.json" ] && [ "$(cat "$MC/docs/reference/design/.preview/.gitignore" 2>/dev/null)" = "*" ] \
    && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["self_check"]["result"]=="fail" and len(d["sheets"])==2 and d["out"].endswith(".preview/"+sys.argv[2]+"/01-fixture")' "$MCO/preview.json" "$MJ" \
    && ok "the render stays in the git-ignored .preview/<job>/<round>/ with preview.json naming it, and --contact-sheet writes one sheet per board" \
    || bad "the default render folder, its preview.json or the contact sheets are wrong (sheets=$sheets) -- $(ls -a "$MCO" "$MC/docs/reference/design/.preview" 2>&1)"
fi
# 4. design-close snapshots the tree byte for byte and signs the job; a superseded round's slice reuses it.
# v61 (P37.S5): signing needs a settled read-back of the round's publish and the round's build contract
# (result.md ## Build); a hand-written SIGNOFF.md (legacy) is kept, with a warning.
printf 'Published files of x (version 1700000000-aaaa), 2 files:\n- "project/Main.dc.html"  text/html  1 bytes\n' \
  | dw design-readback 01-signin --listing - >/dev/null 2>&1 || bad "design probe: design-readback --listing failed"
printf -- '- verdict: done\n\n## Summary\n\nSign-in.\n\n## Build\n\nBuild the boards.\n' > "$JD/rounds/01-signin/result.md"
pre=$(tree_sig "$CP")
printf 'Signed: "ship it"\n' > "$JD/rounds/01-signin/SIGNOFF.md"
close_out=$(dw design-close 01-signin/01-signin --words "ship it" 2>&1) || bad "design probe: design-close --words failed -- $close_out"
printf '%s\n' "$close_out" | grep -Fq 'kept the hand-written' && grep -qx 'Signed: "ship it"' "$JD/rounds/01-signin/SIGNOFF.md" \
  && ok "design-close keeps a hand-written (legacy) SIGNOFF.md, with a warning" \
  || bad "design-close overwrote a hand-written SIGNOFF.md or did not warn -- $close_out"
if [ "$(tree_sig "$JD/rounds/01-signin/canvas/project")" = "$pre" ] && python3 - "$JD" <<'SIGNED'
import json, pathlib, sys
job = pathlib.Path(sys.argv[1])
rnd = json.loads((job / "rounds/01-signin/round.json").read_text())
assert rnd["status"] == "signed" and rnd["signoff_words"] == "ship it" and rnd["canvas_version"] == "1700000000-aaaa", rnd
assert json.loads((job / "job.json").read_text())["status"] == "signed"
SIGNED
then ok "design-close --words snapshots the canvas tree byte-identical, records canvas_version and signs the job"
else bad "design-close lost the snapshot, the canvas_version or the job's signed status"; fi
before=$(tree_sig); again=$(dw design-close 01-signin --words "ship it" 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$again" | grep -q 'already signed' && [ "$(tree_sig)" = "$before" ] \
  && ok "design-close is idempotent: a second run writes nothing" || bad "a second design-close was not a no-op (rc=$rc) -- $again"
{ dw design-open --slug revise --slice P9.S1 && printf '# handoff\n' > "$JD/rounds/02-revise/handoff.md" \
    && dw design-close 01-signin/02-revise --superseded && dw design-open --slug third --slice P9.S1 \
    && printf '# handoff\n' > "$JD/rounds/03-third/handoff.md"; } >/dev/null 2>&1 || bad "design probe: the superseding rounds failed"
[ "$(ls "$DR/jobs")" = "01-signin" ] && [ "$(ls "$JD/rounds" | tr '\n' ' ')" = "01-signin 02-revise 03-third " ] \
  && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))["supersedes"] == ["02-revise"]' "$JD/rounds/03-third/round.json" \
  && ok "a superseded round's slice reuses its job: rounds 02 and 03 open in job 01-signin, each superseding the last" \
  || bad "design-open after --superseded did not reuse the slice's job -- $(ls -R "$DR/jobs")"
# P36.S1: design-register and its registry / design-deck hint are retired -- the command is unknown.
out=$(dw design-register 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'invalid choice' \
  && ok "design-register is gone: the engine rejects it as an unknown command (exit $rc)" \
  || bad "design-register still answers (rc=$rc) -- $out"
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
  && [ ! -e "$DR/rounds" ] && [ ! -e "$DR/SIGNOFF.md" ] && [ -f "$JD/rounds/01-signin/round.json" ] && [ -f "$DR/notes.txt" ] \
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
# 5. P36.S3: a schema-1 (v47 card) record is legacy -- design-open refuses it with the migrate hint, and
# design-migrate --to 2 moves cards/, tokens.css and rounds/ into schema1/ byte-identical (a dry run first).
S1="$DZ/schema1"; SD="$S1/docs/reference/design"
mkdir -p "$S1/scripts" "$SD/cards" "$SD/rounds/01-a/cards" && cp "$F/scripts/workflow.py" "$S1/scripts/"
printf '{"schema": 1, "id": "old-cards", "name": "Old cards"}\n' > "$SD/design.json"
printf '<!-- @dsCard group="Components" viewport="480x200" -->\n<p>a</p>\n' > "$SD/cards/01-a.html"
cp "$SD/cards/01-a.html" "$SD/rounds/01-a/cards/01-a.html" && printf ':root { --ink: #111; }\n' > "$SD/tokens.css"
printf '{"schema": 1, "round": "01-a", "status": "signed"}\n' > "$SD/rounds/01-a/round.json"
sw() { ( cd "$S1" && HOME="$DZ/home" python3 scripts/workflow.py "$@" ); }
s1_before=$(tree_sig "$SD")
open_out=$(sw design-open --slug b --slice P9.S1 2>&1); open_rc=$?
dry=$(sw design-migrate --to 2 2>&1); dry_rc=$?
if [ "$open_rc" -ne 0 ] && printf '%s\n' "$open_out" | grep -Fq 'is schema 1; schema-1 record (numbered cards): run python3 scripts/workflow.py design-migrate --to 2' \
    && [ "$dry_rc" -eq 0 ] && printf '%s\n' "$dry" | grep -q 'dry run -- nothing moved' && [ "$(tree_sig "$SD")" = "$s1_before" ]; then
  ok "an unmigrated schema-1 root makes design-open refuse with the design-migrate --to 2 hint, and the dry run moves nothing"
else bad "a schema-1 root was not refused with the hint, or the dry run moved something (open rc=$open_rc, dry rc=$dry_rc) -- $open_out $dry"; fi
out=$(sw design-migrate --to 2 --apply 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(ls -A "$SD" | tr '\n' ' ')" = "design.json schema1 " ] \
    && [ "$(tree_sig "$SD/schema1")" = "$(printf '%s\n' "$s1_before" | grep -v '^\./design\.json ')" ] \
    && python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d["schema"] == 2 and d["id"] == "old-cards" and d["name"] == "Old cards" and d["system"]["artifact"] is None, d' "$SD/design.json" \
    && sw design-check >/dev/null 2>&1; then
  ok "design-migrate --to 2 --apply moves cards/, tokens.css and rounds/ under schema1/ byte-identical, rewrites design.json to schema 2, and design-check passes after"
else bad "design-migrate --to 2 lost, changed or left an entry, or did not rewrite design.json (rc=$rc) -- $out"; fi

# 6. P46-nb.S1: one connected group per co-work slice, one job. --new-job refuses while another job of the
# slice has an open round and writes nothing; once the slice's other rounds are closed it creates the job
# (a merge into one connected job); a legacy multi-job slice (a wave drawn before the rule) still passes and
# takes --job; a critique level per round. The size warning sits at 10 Pages / 30 boards.
WV="$DZ/wave"; WR="$WV/docs/reference/design"
mkdir -p "$WV/scripts" && cp "$F/scripts/workflow.py" "$WV/scripts/"
ww() { ( cd "$WV" && HOME="$DZ/home" python3 scripts/workflow.py "$@" ); }
# legacy_job <design root> <src job> <src round> <new job> <new round>: a second job of the same slice,
# hand-written beside the first with its round open, the way a pre-P46-nb wave left it.
legacy_job() { python3 - "$@" <<'LEGACY'
import json, pathlib, sys
root, sjob, srnd, njob, nrnd = pathlib.Path(sys.argv[1]), *sys.argv[2:]
job = json.loads((root / "jobs" / sjob / "job.json").read_text())
rnd = json.loads((root / "jobs" / sjob / "rounds" / srnd / "round.json").read_text())
(root / "jobs" / njob / "rounds" / nrnd).mkdir(parents=True)
(root / "jobs" / njob / "job.json").write_text(json.dumps(dict(job, job=njob, title=njob.split("-", 1)[1])))
(root / "jobs" / njob / "rounds" / nrnd / "round.json").write_text(json.dumps(dict(rnd, round=nrnd, title=nrnd.split("-", 1)[1])))
LEGACY
}
ww design-init --id wave >/dev/null 2>&1 || bad "wave probe: design-init failed"
a_out=$(ww design-open --slug checkout --slice P9.S4 --critique critic 2>&1); a_rc=$?
b_out=$(ww design-open --slug settings --slice P9.S4 --new-job 2>&1); b_rc=$?
bad_out=$(ww design-open --slug loud --slice P9.S4 --new-job --critique judge 2>&1); bad_rc=$?
printf '# handoff\n\ncritique: critic\n' > "$WR/jobs/01-checkout/rounds/01-checkout/handoff.md"
if [ "$a_rc" -eq 0 ] && [ "$b_rc" -ne 0 ] \
    && printf '%s\n' "$b_out" | grep -Fq 'refused -- P9.S4 has 01-checkout/01-checkout open; a co-work slice designs one connected group as one job: draw it in this job (--job 01-checkout): an unrelated page stays on this canvas, unlinked' \
    && [ ! -e "$WR/jobs/02-settings" ] \
    && [ "$bad_rc" -ne 0 ] && printf '%s\n' "$bad_out" | grep -Fq -e "--critique 'judge' is not one of off, critic, critic+judge" \
    && [ ! -e "$WR/jobs/02-loud" ] && ww design-check >/dev/null 2>&1; then
  ok "--new-job refuses while another job of the slice has an open round, names it and points at --job (an unrelated page stays on that canvas, unlinked), and writes nothing; a bad --critique level is refused and creates nothing"
else bad "--new-job with a round open in the slice, or the critique level, is wrong (rc=$a_rc/$b_rc/$bad_rc) -- $a_out $b_out $bad_out"; fi
m_out=$( { ww design-close 01-checkout/01-checkout --superseded >/dev/null && ww design-open --slug settings --slice P9.S4 --new-job; } 2>&1); m_rc=$?
printf '# handoff\n\ncritique: off\n' > "$WR/jobs/02-settings/rounds/01-settings/handoff.md"
chk=$(ww design-check 2>&1); chk_rc=$?
if [ "$m_rc" -eq 0 ] && [ -f "$WR/jobs/02-settings/rounds/01-settings/round.json" ] \
    && python3 -c 'import json, sys; assert [json.load(open(p)).get("critique") for p in sys.argv[1:]] == ["critic", "off"]' \
         "$WR/jobs/01-checkout/rounds/01-checkout/round.json" "$WR/jobs/02-settings/rounds/01-settings/round.json" \
    && [ "$chk_rc" -eq 0 ] && printf '%s\n' "$chk" | grep -Fq 'open rounds: 02-settings/01-settings'; then
  ok "once every other round of the slice is closed, --new-job creates the merged job; --critique critic is stored, a new job's default is off, and design-check passes"
else bad "the merge path (--new-job after the close) failed (rc=$m_rc/$chk_rc) -- $m_out $chk"; fi
bare=$(ww design-open --slug again --slice P9.S4 2>&1); bare_rc=$?
{ ww design-close 02-settings/01-settings --superseded \
    && ww design-open --slug settings-v2 --slice P9.S4 --job 02-settings; } >/dev/null 2>&1; job_rc=$?
if [ "$bare_rc" -ne 0 ] && printf '%s\n' "$bare" | grep -Fq 'P9.S4 has 2 jobs (01-checkout, 02-settings); name the one this round belongs to with --job <job> (02-settings/01-settings open); a co-work slice designs one connected group as one job; draw it in this job: an unrelated page stays on this canvas, unlinked' \
    && ! printf '%s\n' "$bare" | grep -Fq -e '--new-job' \
    && [ "$job_rc" -eq 0 ] && [ ! -e "$WR/jobs/03-again" ] \
    && python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d["status"] == "open" and d["supersedes"] == ["01-settings"] and d["critique"] == "off", d' \
         "$WR/jobs/02-settings/rounds/02-settings-v2/round.json"; then
  ok "a bare design-open in a slice with two jobs (one closed, one open) refuses, asks for --job and names the open round, never the refused --new-job, and --job opens the job's next round after a close"
else bad "the bare design-open was not refused, or --job did not open the superseding round (rc=$bare_rc/$job_rc) -- $bare"; fi
printf '# handoff\n' > "$WR/jobs/02-settings/rounds/02-settings-v2/handoff.md"
# A legacy multi-job slice: P9.S5's jobs 03-alpha and 04-beta both open, hand-written as a wave left them.
ww design-open --slug alpha --slice P9.S5 >/dev/null 2>&1 && legacy_job "$WR" 03-alpha 01-alpha 04-beta 01-beta \
  || bad "wave probe: could not write the legacy two-job slice"
printf '# handoff\n' > "$WR/jobs/03-alpha/rounds/01-alpha/handoff.md"; printf '# handoff\n' > "$WR/jobs/04-beta/rounds/01-beta/handoff.md"
leg=$(ww design-check 2>&1); leg_rc=$?
leg_job=$( { ww design-close 04-beta/01-beta --superseded >/dev/null && ww design-open --slug beta-v2 --slice P9.S5 --job 04-beta; } 2>&1); leg_job_rc=$?
if [ "$leg_rc" -eq 0 ] && printf '%s\n' "$leg" | grep -Fq '03-alpha/01-alpha, 04-beta/01-beta' && ! printf '%s\n' "$leg" | grep -q 'warning' \
    && [ "$leg_job_rc" -eq 0 ] && [ -f "$WR/jobs/04-beta/rounds/02-beta-v2/round.json" ]; then
  ok "a legacy slice with two open jobs passes design-check with no problem and no warning, and --job opens a job's next round as before"
else bad "the legacy multi-job slice got a problem or a warning, or refused --job (rc=$leg_rc/$leg_job_rc) -- $leg $leg_job"; fi
printf '# handoff\n' > "$WR/jobs/04-beta/rounds/02-beta-v2/handoff.md"
# pages_canvas <project> <N>: N Pages (expand: fill), Main first, each linking to the next.
pages_canvas() { python3 - "$1" "$2" <<'PAGES'
import json, pathlib, shutil, sys
project, count = pathlib.Path(sys.argv[1]), int(sys.argv[2])
shutil.rmtree(project, ignore_errors=True); project.mkdir(parents=True)
names = ["Main"] + [f"Step{n}" for n in range(2, count + 1)]
boards = {f"{n}.dc.html": {"x": i * 1500, "y": 0, "w": 1440, "h": 900, "title": f"{i + 1:02d} · {n}", "expand": "fill"}
          for i, n in enumerate(names)}
(project / "canvas.json").write_text(json.dumps({"v": 3, "createdOnFiles": {"v": 1}, "boards": boards, "order": list(boards)}))
for i, name in enumerate(boards):
    nxt = f'<a href="{names[i + 1]}.dc.html">next</a>\n' if i + 1 < len(names) else ""
    (project / name).write_text('<!doctype html>\n<script src="./support.js"></script>\n<p>page</p>\n' + nxt)
PAGES
}
pages_canvas "$WR/jobs/02-settings/canvas/project" 11 || bad "wave probe: could not write the eleven-Page canvas"
out=$(ww design-check 2>&1); rc=$?
pages_canvas "$WR/jobs/02-settings/canvas/project" 10 || bad "wave probe: could not write the ten-Page canvas"
ten=$(ww design-check 2>&1); ten_rc=$?
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -Fq 'warning: job 02-settings has 11 Pages / 11 boards — past one review of a connected group; split into rounds or slices along the least-connected seam' \
    && [ "$ten_rc" -eq 0 ] && ! printf '%s\n' "$ten" | grep -Fq 'past one review' && ! printf '%s\n' "$out$ten" | grep -Fq 'check=unlinked-page'; then
  ok "a job past the size threshold (11 Pages) makes design-check warn with the connected-group text, exit 0; 10 Pages does not warn"
else bad "the size warning is wrong at 11 / 10 Pages (rc=$rc/$ten_rc) -- $out $ten"; fi
# check=unlinked-page: a second Page the entry Page reaches by no link or mount warns; a mount of a flow
# board that links to it (fragment and ./ stripped) clears it.
python3 - "$WR/jobs/02-settings/canvas/project" <<'UNLINKED' || bad "wave probe: could not write the unlinked canvas"
import json, pathlib, shutil, sys
project = pathlib.Path(sys.argv[1]); shutil.rmtree(project); project.mkdir(parents=True)
boards = {"Main.dc.html": {"x": 0, "y": 0, "w": 1440, "h": 900, "title": "01 · Main", "expand": "fill"},
          "Flow.dc.html": {"x": 1500, "y": 0, "w": 400, "h": 300, "title": "02 · Flow"},
          "Other.dc.html": {"x": 2000, "y": 0, "w": 1440, "h": 900, "title": "03 · Other", "expand": "fill"}}
(project / "canvas.json").write_text(json.dumps({"v": 3, "createdOnFiles": {"v": 1}, "boards": boards, "order": list(boards)}))
for name in boards:
    (project / name).write_text('<!doctype html>\n<script src="./support.js"></script>\n<a href="{{ next }}">x</a>\n')
UNLINKED
un=$(ww design-check 2>&1); un_rc=$?
CV="$WR/jobs/02-settings/canvas/project"
printf '<dc-import name="Flow"></dc-import>\n' >> "$CV/Main.dc.html"; printf '<a href="./Other.dc.html#top">other</a>\n' >> "$CV/Flow.dc.html"
linked=$(ww design-check 2>&1); linked_rc=$?
if [ "$un_rc" -eq 0 ] && printf '%s\n' "$un" | grep -Fq "jobs/02-settings/canvas/project/Other.dc.html: Page not reachable from the entry Page Main.dc.html by a link or a mount (check=unlinked-page) -- link it from a board the entry reaches, or list it as unrelated in the round's join.json (it stays on this canvas, unlinked)" \
    && [ "$linked_rc" -eq 0 ] && ! printf '%s\n' "$linked" | grep -Fq 'check=unlinked-page'; then
  ok "design-check warns on a Page the entry Page reaches by no link or mount (check=unlinked-page), exit 0; a mounted flow board linking it clears the warning"
else bad "check=unlinked-page is wrong (rc=$un_rc/$linked_rc) -- $un $linked"; fi
# 6b. v88 (P47-p5.S4): the per-page round record. design-open --pages records the page list (a reserved
# slug refuses and writes nothing); design-check prints the round's stage= from disk; --page checks one
# page without canvas.json (a foreign-prefix board and a #to: to a non-page are problems); check=pending-link
# warns before join.json and is a problem after it, so design-close --words refuses; join.json's unrelated
# list exempts a Page from check=unlinked-page; check=token-drift and check=transition-all warn.
PG="$DZ/pages"; PR="$PG/docs/reference/design"; PJ="$PR/jobs/01-board"; PP="$PJ/canvas/project"; PRD="$PJ/rounds/01-board"
mkdir -p "$PG/scripts" && cp "$F/scripts/workflow.py" "$PG/scripts/"
pw() { ( cd "$PG" && HOME="$DZ/home" python3 scripts/workflow.py "$@" ); }
pw design-init --id pages >/dev/null 2>&1 || bad "pages probe: design-init failed"
res_out=$(pw design-open --slug board --slice P9.S6 --pages list,frame 2>&1); res_rc=$?
open_out=$(pw design-open --slug board --slice P9.S6 --pages list,detail 2>&1); open_rc=$?
printf '# handoff\n' > "$PRD/handoff.md"; st_frame=$(pw design-check 01-board 2>&1)
if [ "$res_rc" -ne 0 ] && printf '%s\n' "$res_out" | grep -Fq "page 'frame' is reserved" && [ "$open_rc" -eq 0 ] \
    && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))["pages"] == ["list", "detail"]' "$PRD/round.json" \
    && printf '%s\n' "$st_frame" | grep -Fqx 'design-check: 01-board/01-board stage=frame'; then
  ok "design-open --pages records the round's page list in round.json (a reserved slug refuses), and design-check prints stage=frame"
else bad "design-open --pages or the stage line is wrong (rc=$res_rc/$open_rc) -- $res_out $open_out $st_frame"; fi
# page_files <project> <round> <boards.json body> [extra List.dc.html line]: the list page's files.
page_files() { python3 - "$@" <<'PAGE'
import pathlib, sys
project, rdir, boards = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
extra = sys.argv[4] if len(sys.argv) > 4 else '<a href="#to:detail">open</a>'
project.mkdir(parents=True, exist_ok=True); (rdir / "pages/list").mkdir(parents=True, exist_ok=True)
head = '<!doctype html>\n<script src="./support.js"></script>\n'
(project / "List.dc.html").write_text(head + extra + "\n")
(project / "ListRow.dc.html").write_text(head + "<p>row</p>\n")
(rdir / "pages/list/boards.json").write_text(boards)
(rdir / "frame.md").write_text("# frame\n")
PAGE
}
LB='{"List.dc.html": {"w": 1440, "h": 900, "title": "List", "expand": "fill"}, "ListRow.dc.html": {"w": 400, "h": 80, "title": "List row"}}'
page_files "$PP" "$PRD" "$LB" || bad "pages probe: could not write the list page"
clean=$(pw design-check 01-board --page list 2>&1); clean_rc=$?
whole=$(pw design-check 01-board 2>&1); whole_rc=$?
page_files "$PP" "$PRD" "${LB%\}}, \"Detail.dc.html\": {\"w\": 1440, \"h\": 900, \"title\": \"Detail\"}}" '<a href="#to:settings">x</a>' \
  && printf '<!doctype html>\n<script src="./support.js"></script>\n' > "$PP/Detail.dc.html" || bad "pages probe: could not write the foreign board"
foreign=$(pw design-check 01-board --page list 2>&1); foreign_rc=$?
rm -f "$PP/Detail.dc.html"; page_files "$PP" "$PRD" "$LB"
if [ "$clean_rc" -eq 0 ] && printf '%s\n' "$clean" | grep -Fq 'design-check: OK -- page list of 01-board/01-board: 2 board(s), 2 file(s)' \
    && printf '%s\n' "$clean" | grep -Fqx 'design-check: 01-board/01-board stage=pages 0/2' \
    && [ "$whole_rc" -eq 0 ] && printf '%s\n' "$whole" | grep -Fq 'List.dc.html: 1 #to: placeholder link(s) left (detail) (check=pending-link)' \
    && [ "$foreign_rc" -ne 0 ] && printf '%s\n' "$foreign" | grep -Fq "board 'Detail.dc.html' is outside page list's files (a page writes only files whose stem starts List; this stem is page detail's)" \
    && printf '%s\n' "$foreign" | grep -Fq 'List.dc.html: links #to:settings, which is not a page of 01-board/01-board'; then
  ok "design-check --page passes a clean page with no canvas.json and flags a foreign-prefix board and a #to: to a non-page; the whole-job check warns check=pending-link before the join"
else bad "design-check --page is wrong (rc=$clean_rc/$whole_rc/$foreign_rc) -- $clean $whole $foreign"; fi
# The join: every page done, canvas.json written, then join.json -- the #to: left becomes a problem.
python3 - "$PP" "$PRD" <<'JOIN' || bad "pages probe: could not write the joined canvas"
import json, pathlib, sys
project, rdir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for slug in ("list", "detail"):
    (rdir / "pages" / slug).mkdir(parents=True, exist_ok=True)
    (rdir / "pages" / slug / "result.md").write_text("- status: done\n")
boards = {"Main.dc.html": {"x": 0, "y": 0, "w": 1440, "h": 900, "title": "01 · Main", "expand": "fill"},
          "List.dc.html": {"x": 1500, "y": 0, "w": 1440, "h": 900, "title": "02 · List", "expand": "fill"},
          "ListRow.dc.html": {"x": 0, "y": 1000, "w": 400, "h": 80, "title": "03 · List row"}}
(project / "canvas.json").write_text(json.dumps({"v": 3, "createdOnFiles": {"v": 1}, "boards": boards, "order": list(boards)}))
(project / "Main.dc.html").write_text('<!doctype html>\n<script src="./support.js"></script>\n<a href="List.dc.html">list</a>\n')
JOIN
pre=$(pw design-check 01-board 2>&1); pre_rc=$?
printf '{"related": ["list"], "unrelated": []}\n' > "$PRD/join.json"
post=$(pw design-check 01-board 2>&1); post_rc=$?
pw design-canvas 01-board --url https://claude.ai/artifact/pages1 --version 1700000000-pg >/dev/null 2>&1
close=$(pw design-close 01-board/01-board --words "ship it" 2>&1); close_rc=$?
if [ "$pre_rc" -eq 0 ] && printf '%s\n' "$pre" | grep -Fqx 'design-check: 01-board/01-board stage=join' && printf '%s\n' "$pre" | grep -Fq 'warning: jobs/01-board/canvas/project/List.dc.html: 1 #to: placeholder link(s) left (detail) (check=pending-link)' \
    && [ "$post_rc" -ne 0 ] && printf '%s\n' "$post" | grep -Fqx 'design-check: 01-board/01-board stage=joined' \
    && printf '%s\n' "$post" | grep -Fq -- '- jobs/01-board/canvas/project/List.dc.html: 1 #to: placeholder link(s) left (detail) (check=pending-link) -- the join rewires each to a real link; design-close --words refuses while one is left' \
    && [ "$close_rc" -ne 0 ] && printf '%s\n' "$close" | grep -Fq 'check=pending-link' \
    && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))["status"] == "open"' "$PRD/round.json"; then
  ok "check=pending-link is a warning before join.json (stage=join) and a problem after it (stage=joined), and design-close --words refuses the round"
else bad "check=pending-link or the close refusal is wrong (rc=$pre_rc/$post_rc/$close_rc) -- $pre $post $close"; fi
# The unrelated-page exemption, and the style lints on a frame.css that names tokens.
python3 - "$PP" <<'UNREL' || bad "pages probe: could not write the unrelated Page"
import json, pathlib, sys
project = pathlib.Path(sys.argv[1]); index = json.loads((project / "canvas.json").read_text())
index["boards"]["Detail.dc.html"] = {"x": 3000, "y": 0, "w": 1440, "h": 900, "title": "04 · Detail", "expand": "fill"}
index["order"].append("Detail.dc.html"); (project / "canvas.json").write_text(json.dumps(index))
head = '<!doctype html>\n<script src="./support.js"></script>\n'
(project / "Detail.dc.html").write_text(head + "<p>detail</p>\n")
(project / "List.dc.html").write_text(head + '<a href="Main.dc.html">back</a>\n')
(project / "frame.css").write_text(":root { --ink: #1a1a1a; --radius-md: 6px; --space-4: 16px; }\n")
(project / "ListRow.dc.html").write_text(head + '<style>.row { color: #1A1A1A; border: 1px solid var(--ink); padding: 16px; '
    'border-radius: 50%; transition: all .2s; } [data-proto="state-bar"] { background: #ff0000; }</style>\n<p class="row">row</p>\n')
UNREL
un=$(pw design-check 01-board 2>&1); un_rc=$?
printf '{"related": ["list"], "unrelated": ["detail"]}\n' > "$PRD/join.json"
ex=$(pw design-check 01-board 2>&1); ex_rc=$?
printf '<a href="Detail.dc.html">detail</a>\n' >> "$PP/Main.dc.html"
reached=$(pw design-check 01-board 2>&1)
if [ "$un_rc" -eq 0 ] && printf '%s\n' "$un" | grep -Fq "Detail.dc.html: Page not reachable from the entry Page Main.dc.html by a link or a mount (check=unlinked-page) -- link it from a board the entry reaches, or list it as unrelated in the round's join.json (it stays on this canvas, unlinked)" \
    && [ "$ex_rc" -eq 0 ] && ! printf '%s\n' "$ex" | grep -Fq 'check=unlinked-page' \
    && printf '%s\n' "$reached" | grep -Fq "Detail.dc.html: the round's join.json lists this Page as unrelated, but the entry Page Main.dc.html reaches it (check=unlinked-page)" \
    && printf '%s\n' "$ex" | grep -Fq 'ListRow.dc.html: 2 raw value(s) where the system or frame.css names a token (check=token-drift): #1A1A1A (color = var(--ink)), 16px (padding = var(--space-4))' \
    && ! printf '%s\n' "$ex" | grep -Fq -e '#ff0000' -e '50%' \
    && printf '%s\n' "$ex" | grep -Fq 'ListRow.dc.html: transition: all (check=transition-all)'; then
  ok "join.json's unrelated list exempts a Page from check=unlinked-page (a reached one warns); check=token-drift names raw values a token names, allowing 1px borders, % and [data-proto] chrome; check=transition-all warns"
else bad "the unrelated-page exemption or the style lints are wrong (rc=$un_rc/$ex_rc) -- $un $ex $reached"; fi
# 6c. v88 (P47-p5.S5): design-preview --page renders one page of a per-page round from its boards.json (a
# synthesized index.json in the render folder, never canvas.json), into .preview/<job>/<round>/pages/<slug>/,
# and only that page's boards; check=align names one known miss per cheap kind (first-line, beside-control,
# control-height), each printed line with its 2x zoom crop beside the render, and self_check is unchanged
# (advisory). With no browser the block says so and asserts nothing.
AL="$DZ/align"; AR="$AL/docs/reference/design"; AJ="$AR/jobs/01-rows"; AP="$AJ/canvas/project"; ARD="$AJ/rounds/01-rows"
mkdir -p "$AL/scripts" && cp "$F/scripts/workflow.py" "$AL/scripts/"
aw() { ( cd "$AL" && python3 scripts/workflow.py "$@" ); }
{ aw design-init --id align && aw design-open --slug rows --slice P9.S7 --pages list,detail; } >/dev/null 2>&1 || bad "align probe: design-init or design-open --pages failed"
printf '# handoff\n' > "$ARD/handoff.md"
python3 - "$AP" "$ARD" <<'ALIGN' || bad "align probe: could not write the page fixtures"
import json, pathlib, sys
project, rdir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
project.mkdir(parents=True, exist_ok=True)
head = '<!doctype html>\n<html><head>\n<script src="./support.js"></script>\n</head>\n'
btn = 'style="width:64px;height:{h}px;background:#fff;border:1px solid #555;color:#111;font:16px Arial,sans-serif"'
(project / "ListAlign.dc.html").write_text(head + '<body style="margin:0;background:#fff;color:#111;font:16px/1.25 Arial,sans-serif"><x-dc>\n'
    '<div style="display:flex;align-items:center;gap:16px;width:420px;margin:24px"><span style="width:140px">A cell that wraps onto two lines</span><span>Short</span></div>\n'
    f'<div style="display:flex;align-items:flex-start;gap:16px;margin:24px"><span>Label</span><button type="button" {btn.format(h=44)}>Act</button></div>\n'
    f'<div style="display:flex;align-items:flex-start;gap:16px;margin:24px"><button type="button" {btn.format(h=44)}>One</button><button type="button" {btn.format(h=40)}>Two</button></div>\n'
    '</x-dc></body></html>\n', encoding="utf-8")
(project / "Detail.dc.html").write_text(head + '<body><x-dc><p>detail</p></x-dc></body></html>\n', encoding="utf-8")
for slug, boards in (("list", {"ListAlign.dc.html": {"w": 520, "h": 360, "title": "Rows"}}),
                     ("detail", {"Detail.dc.html": {"w": 400, "h": 200, "title": "Detail"}})):
    (rdir / "pages" / slug).mkdir(parents=True, exist_ok=True)
    (rdir / "pages" / slug / "boards.json").write_text(json.dumps(boards), encoding="utf-8")
ALIGN
printf '/* a stand-in runtime: the fixture boards need none */\n' > "$AL/stub-runtime.js"
al_out=$(aw design-preview 01-rows --runtime stub-runtime.js --page list 2>&1); al_rc=$?
bad_out=$(aw design-preview 01-rows --runtime stub-runtime.js --page nope 2>&1); bad_rc=$?
if printf '%s\n' "$al_out" | grep -qx 'preview=skipped reason=no-browser'; then
  printf 'SKIP: %s\n' "design-preview --page and check=align on fixture boards: no Chrome/Chromium on this machine (nothing asserted)"
else
  ALO="$AR/.preview/01-rows/01-rows/pages/list"
  has() { printf '%s\n' "$al_out" | grep -Eq "$1"; }
  [ "$al_rc" -eq 0 ] && has '^board=ListAlign\.dc\.html ' && ! has 'board=Detail\.dc\.html' && [ -f "$ALO/ListAlign.frame.png" ] \
    && [ -f "$ALO/index.json" ] && [ ! -e "$AP/canvas.json" ] && has '^self_check=pass blocking=none$' \
    && [ "$bad_rc" -ne 0 ] && printf '%s\n' "$bad_out" | grep -Fq "design-preview: --page 'nope' is not a page of 01-rows/01-rows (pages: list, detail; or frame)" \
    && ok "design-preview --page renders only that page's boards from its boards.json into .preview/<job>/<round>/pages/<slug>/ (index.json there, no canvas.json written), self_check unchanged; an unknown page refuses" \
    || bad "design-preview --page is wrong (rc=$al_rc/$bad_rc) -- $al_out $bad_out"
  has 'board=ListAlign\.dc\.html view=frame check=align: first-line [0-9.]+px \(span "A cell that wraps o…" vs span "Short"\)' \
    && has 'check=align: beside-control [0-9.]+px \(span "Label" vs button "Act"\)' \
    && has 'check=align: control-height 4px \(button "One" vs button "Two"\)' \
    && has 'check=align: first-line .* crop=.*/ListAlign\.align-0[1-9]\.png$' && [ -f "$ALO/ListAlign.align-01.png" ] \
    && has '^advisory=align:[0-9]' \
    && ok "check=align names a first-line, a beside-control and a control-height miss, each line ending with its 2x zoom crop beside the render; advisory= counts them" \
    || bad "check=align missed a fixture miss or its crop -- $(printf '%s\n' "$al_out" | grep -E 'align|advisory')"
fi
# 7. P36.S8C: the board lint and the board count. A link to an outside https page (Google Fonts CSS
# excepted) and a <sc-for> whose every row links to one board are warnings; a board another board
# <dc-import>s is not counted (34 boards, 4 mounted: 30 counted, no size warning); bar.md at the root is no stray.
python3 - "$WR" <<'LINT' || bad "lint probe: could not write the canvas"
import json, pathlib, sys
root = pathlib.Path(sys.argv[1]); project = root / "jobs/01-checkout/canvas/project"; project.mkdir(parents=True, exist_ok=True)
(root / "bar.md").write_text("# The operator's bar\n\n- none beyond the shipped bar\n")
names = ["Main", "Item"] + [f"Part{n}" for n in range(1, 33)]
boards = {f"{n}.dc.html": {"x": i * 500, "y": 0, "w": 400, "h": 300, "title": f"{i + 1:02d} · {n}"} for i, n in enumerate(names)}
(project / "canvas.json").write_text(json.dumps({"v": 3, "createdOnFiles": {"v": 1}, "boards": boards, "order": list(boards)}))
head = '<!doctype html>\n<script src="./support.js"></script>\n'
for name in boards:
    (project / name).write_text(head + "<p>board</p>\n")
(project / "Main.dc.html").write_text(head + '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter">\n'
    '<sc-for list="{{ rows }}" as="r"><a href="Item.dc.html">{{ r.name }}</a></sc-for>\n'
    '<a href="https://elsewhere.example/sign-in">Sign in</a>\n'
    '<dc-import name="Part1"></dc-import><dc-import name="Part2"></dc-import><dc-import name="Part3"></dc-import><dc-import name="Part4"></dc-import>\n')
LINT
out=$(ww design-check 01-checkout 2>&1); rc=$?
all_out=$(ww design-check 2>&1); all_rc=$?
if [ "$rc" -eq 0 ] && [ "$all_rc" -eq 0 ] && ! printf '%s\n' "$all_out" | grep -Fq 'bar.md' \
    && printf '%s\n' "$out" | grep -Fq 'Main.dc.html: 1 link(s) leave the prototype (check=leaves-canvas): https://elsewhere.example/sign-in' \
    && ! printf '%s\n' "$out" | grep -Fq 'fonts.googleapis.com' \
    && printf '%s\n' "$out" | grep -Fq 'Main.dc.html: every row of a <sc-for> list links to Item.dc.html (check=same-target-list)' \
    && ! printf '%s\n' "$out" | grep -Fq 'past one review' && ! printf '%s\n' "$out" | grep -Fq 'bar.md'; then
  ok "design-check warns on a link leaving the prototype (not Google Fonts) and on a list whose rows all link to one board, exit 0; boards another board mounts are not counted (34 boards, 4 mounted: no size warning); bar.md is no stray"
else bad "the board lint, the mounted-board count or bar.md is wrong (rc=$rc/$all_rc) -- $out $all_out"; fi

# 8. v61 (P37.S5): the design lifecycle one-liners. The publish records a size manifest; design-readback
# reads a canvas listing (no hash) and names only what to fetch; --fetched diffs, --apply copies in;
# design-close generates SIGNOFF.md and refuses without a read-back; design-sign signs every presented job
# or none; a superseding round's critique defaults off; the record carries repo-relative paths only, and a
# brief a handoff names must exist. Its second job is a legacy wave's (hand-written: --new-job now refuses
# while the slice's first round is open), so design-sign --slice signs a legacy slice's presented jobs.
LF="$DZ/life"; LR="$LF/docs/reference/design"
mkdir -p "$LF/scripts" && cp "$F/scripts/workflow.py" "$LF/scripts/"
lw() { ( cd "$LF" && HOME="$DZ/home" python3 scripts/workflow.py "$@" ); }
lw design-init --id life >/dev/null 2>&1 && lw design-open --slug one --slice P9.S7 --critique critic >/dev/null 2>&1 \
  && legacy_job "$LR" 01-one 01-one 02-two 01-two || bad "life probe: design-open failed"
python3 - "$LR" <<'LIFE' || bad "life probe: could not write the canvases"
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
(root / "waves/P9.S7").mkdir(parents=True, exist_ok=True)
(root / "waves/P9.S7/brief.md").write_text("# Wave P9.S7\n\nruntime: docs/reference/design/.type/artifact-type/dc-runtime.js\n")
for job, rnd in (("01-one", "01-one"), ("02-two", "01-two")):
    project = root / "jobs" / job / "canvas/project"; project.mkdir(parents=True, exist_ok=True)
    boards = {"Main.dc.html": {"x": 0, "y": 0, "w": 400, "h": 300, "title": "01 · Main"},
              "Two.dc.html": {"x": 500, "y": 0, "w": 400, "h": 300, "title": "02 · Two"}}
    (project / "canvas.json").write_text(json.dumps({"v": 3, "createdOnFiles": {"v": 1}, "boards": boards, "order": list(boards)}))
    for name in boards:
        (project / name).write_text('<!doctype html>\n<script src="./support.js"></script>\n<p>' + name + '</p>\n')
    (project / "app.css").write_text("p { color: #222; }\n")
    rdir = root / "jobs" / job / "rounds" / rnd
    (rdir / "handoff.md").write_text("# handoff\n\nbrief: waves/P9.S7/brief.md\ncritique: off\n")
    (rdir / "result.md").write_text("- verdict: done\n- open_items: D1, D2\n\n## Summary\n\nTwo boards.\n\n## Build\n\nBuild both.\n")
LIFE
printf '# handoff\n\nbrief: waves/P9.S7/brief.md\nruntime: /private/tmp/scratch/dc-runtime.js\n' > "$LR/jobs/01-one/rounds/01-one/handoff.md"
abs_out=$(lw design-check 2>&1); abs_rc=$?
printf '# handoff\n\nbrief: waves/P9.S7/brief.md\ncritique: critic\n' > "$LR/jobs/01-one/rounds/01-one/handoff.md"
mv "$LR/waves/P9.S7/brief.md" "$DZ/brief.md"; brief_out=$(lw design-check 2>&1); brief_rc=$?; mv "$DZ/brief.md" "$LR/waves/P9.S7/brief.md"
clean_out=$(lw design-check 2>&1); clean_rc=$?
if [ "$abs_rc" -eq 1 ] && printf '%s\n' "$abs_out" | grep -Fq 'jobs/01-one/rounds/01-one/handoff.md: an absolute path (check=abs-path): line 4 /private/' \
    && [ "$brief_rc" -eq 1 ] && printf '%s\n' "$brief_out" | grep -Fq 'jobs/02-two/rounds/01-two/handoff.md: names brief waves/P9.S7/brief.md, which is missing' \
    && [ "$clean_rc" -eq 0 ] && grep -qx '\*' "$LR/.type/.gitignore"; then
  ok "design-check makes an absolute path in an open round's handoff a problem and a missing named wave brief a problem; the record passes with repo-relative paths, and design-open git-ignores the type cache"
else bad "the absolute-path lint or the brief check is wrong (rc=$abs_rc/$brief_rc/$clean_rc) -- $abs_out $brief_out $clean_out"; fi
{ lw design-canvas 01-one --url https://claude.ai/artifact/LifeOne && lw design-canvas 01-one --version 300-a \
    && lw design-canvas 02-two --url https://claude.ai/artifact/LifeTwo && lw design-canvas 02-two --version 400-a; } >/dev/null 2>&1 \
  || bad "life probe: design-canvas failed"
python3 - "$LR/jobs/01-one" <<'MANIFEST' && ok "design-canvas --version records the publish's size manifest in job.json and the version on the open round" || bad "design-canvas recorded no manifest or no round publish"
import json, pathlib, sys
job = pathlib.Path(sys.argv[1]); project = job / "canvas/project"
manifest = json.loads((job / "job.json").read_text())["canvas"]["manifest"]
assert manifest == {f"project/{f.name}": f.stat().st_size for f in project.iterdir() if f.is_file()}, manifest
assert json.loads((job / "rounds/01-one/round.json").read_text())["published"] == "300-a"
MANIFEST
# listing <version> [<file to grow by 9 bytes>]: an Artifact list scope:files output of job 01-one's local tree
listing() { python3 - "$LR/jobs/01-one/canvas/project" "$1" "${2:-}" <<'LISTING'
import pathlib, sys
project, version, grow = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
print(f'Published files of https://claude.ai/artifact/LifeOne (version {version}), an Artifact of type "Design", 9 files by path:')
for path, size in (("SKILL.md", 16042), ("index.html", 34176), ("artifact-type/dc-runtime.js", 187897), ("project/ds/life/tokens.css", 900)):
    print(f'- "{path}"  text/plain  {size} bytes')
for f in sorted(project.iterdir()):
    print(f'- "project/{f.name}"  text/plain  {f.stat().st_size + (9 if f.name == grow else 0)} bytes')
LISTING
}
close_out=$(lw design-close 01-one/01-one --words "ship it" 2>&1); close_rc=$?
same=$(listing 300-a | lw design-readback 01-one --listing - 2>&1)
moved=$(listing 301-b app.css | lw design-readback 01-one --listing - 2>&1)
unloc=$(listing 302-c | lw design-readback 01-one --listing - 2>&1)
if [ "$close_rc" -ne 0 ] && printf '%s\n' "$close_out" | grep -Fq 'no read-back since the last publish (300-a): run design-readback 01-one --listing' \
    && [ ! -e "$LR/jobs/01-one/rounds/01-one/SIGNOFF.md" ] \
    && printf '%s\n' "$same" | grep -qx 'readback=unchanged version=300-a' \
    && printf '%s\n' "$moved" | grep -qx 'readback=changed version=301-b files=1' && printf '%s\n' "$moved" | grep -qx 'fetch=project/app.css' \
    && printf '%s\n' "$unloc" | grep -qx 'readback=changed-unlocated version=302-c reason=same-sizes files=2' \
    && printf '%s\n' "$unloc" | grep -qx 'fetch=project/Main.dc.html,project/Two.dc.html' \
    && ! printf '%s\n%s\n%s\n' "$same" "$moved" "$unloc" | grep -Eq 'SKILL|artifact-type|index.html|ds/|color'; then
  ok "design-close --words refuses with no read-back and writes nothing; design-readback reads a listing: same version unchanged, a resized file changed (only it fetched), same sizes changed-unlocated (the boards fetched), the type's files and ds/ ignored, no content printed"
else bad "the read-back of a listing is wrong (close rc=$close_rc) -- $close_out / $same / $moved / $unloc"; fi
listing 303-d app.css | lw design-readback 01-one --listing - >/dev/null 2>&1
mkdir -p "$DZ/fetched/project" && printf 'p { color: #222; }\nb { font-weight: 600; }\n' > "$DZ/fetched/project/app.css"
diff_out=$(lw design-readback 01-one --fetched "$DZ/fetched" 2>&1); diff_rc=$?
cmp -s "$DZ/fetched/project/app.css" "$LR/jobs/01-one/canvas/project/app.css" && copied_early=1 || copied_early=0
apply_out=$(lw design-readback 01-one --fetched "$DZ/fetched" --apply 2>&1); apply_rc=$?
if [ "$diff_rc" -eq 0 ] && printf '%s\n' "$diff_out" | grep -qx 'diff=project/app.css +1 -0' && printf '%s\n' "$diff_out" | grep -q '^readback=differs ' \
    && [ "$copied_early" -eq 0 ] && [ -f "$DZ/fetched/readback.diff" ] \
    && [ "$apply_rc" -eq 0 ] && printf '%s\n' "$apply_out" | grep -q '^readback=edited version=303-d files=1' \
    && cmp -s "$DZ/fetched/project/app.css" "$LR/jobs/01-one/canvas/project/app.css"; then
  ok "design-readback --fetched prints diff=<path> +A -B and writes the diff to the scratch dir only; --apply copies the fetched file over the canvas file (read-back edited)"
else bad "design-readback --fetched / --apply is wrong (rc=$diff_rc/$apply_rc) -- $diff_out / $apply_out"; fi
sign_no=$(lw design-sign --slice P9.S7 --words "accept" 2>&1); sign_no_rc=$?
st() { python3 -c 'import json, sys; print(" ".join(json.load(open(p))["status"] for p in sys.argv[1:]))' "$@"; }
no_state=$(st "$LR/jobs/01-one/rounds/01-one/round.json" "$LR/jobs/02-two/rounds/01-two/round.json")
[ -e "$LR/jobs/01-one/rounds/01-one/SIGNOFF.md" ] && no_state="$no_state signoff-written"
printf 'Published files of x (version 400-a), 1 file:\n- "project/Main.dc.html"  text/html  80 bytes\n' | lw design-readback 02-two --listing - >/dev/null 2>&1
sign_out=$(lw design-sign --slice P9.S7 --words "accept" 2>&1); sign_rc=$?
if [ "$sign_no_rc" -ne 0 ] && printf '%s\n' "$sign_no" | grep -Fq '02-two/01-two: no read-back since the last publish (400-a)' \
    && [ "$no_state" = "open open" ] \
    && [ "$sign_rc" -eq 0 ] && printf '%s\n' "$sign_out" | grep -qx 'signed=01-one/01-one version=303-d readback=edited open_items=D1,D2 files=4' \
    && printf '%s\n' "$sign_out" | grep -qx 'signed=02-two/01-two version=400-a readback=unchanged open_items=D1,D2 files=4' \
    && [ "$(st "$LR/jobs/01-one/rounds/01-one/round.json" "$LR/jobs/02-two/rounds/01-two/round.json" "$LR/jobs/01-one/job.json" "$LR/jobs/02-two/job.json")" = "signed signed signed signed" ] \
    && [ -f "$LR/jobs/02-two/rounds/01-two/SIGNOFF.md" ] && lw design-check >/dev/null 2>&1; then
  ok "design-sign signs neither job while one lacks a read-back, then signs both presented jobs in one call, one line each"
else bad "design-sign is not all-or-nothing or did not sign both (rc=$sign_no_rc/$sign_rc) -- $sign_no / $sign_out"; fi
sup_out=$(lw design-open --slug one-fix --slice P9.S7 --job 01-one 2>&1)
RD="$LR/jobs/01-one/rounds/02-one-fix"
printf '# handoff\n\nbrief: waves/P9.S7/brief.md\ncritique: off\n' > "$RD/handoff.md"
printf -- '- verdict: done\n- open_items: none\n\n## Summary\n\nFixed.\n\n## Build\n\nAs drawn.\n' > "$RD/result.md"
printf -- '- verdict: pass\n- open_items: C4, C7\n' > "$RD/critique-01.md"
{ lw design-canvas 01-one --version 500-e && listing 500-e | lw design-readback 01-one --listing -; } >/dev/null 2>&1
close_out=$(lw design-close 01-one/02-one-fix --words "ship it, as drawn" 2>&1); close_rc=$?
if printf '%s\n' "$sup_out" | grep -Fq 'critique off (a superseding round'"'"'s default' \
    && python3 -c 'import json, sys; assert json.load(open(sys.argv[1]))["critique"] == "off"' "$RD/round.json" \
    && [ "$close_rc" -eq 0 ] && printf '%s\n' "$close_out" | grep -Fq 'SIGNOFF.md generated' \
    && grep -qx '  > ship it, as drawn' "$RD/SIGNOFF.md" && grep -qx -- '- \*\*Canvas version:\*\* 500-e' "$RD/SIGNOFF.md" \
    && grep -qx -- '- \*\*Read-back:\*\* unchanged at 500-e (published 500-e)' "$RD/SIGNOFF.md" \
    && grep -qx -- '- \*\*Open items:\*\* C4, C7' "$RD/SIGNOFF.md" && grep -qx -- '- \*\*Supersedes:\*\* 01-one' "$RD/SIGNOFF.md"; then
  ok "a superseding round defaults critique off; design-close --words generates SIGNOFF.md: the words verbatim, the canvas version, the read-back and the open-item ids"
else bad "the superseding round's critique or the generated SIGNOFF.md is wrong (close rc=$close_rc) -- $sup_out / $close_out / $(cat "$RD/SIGNOFF.md" 2>&1)"; fi

# ---------------------------------------------------------------------------
echo "== Test 14: P28 nested engine -- workflow/.agentic-nested.json: host anchors, host-side phase-scope, the paired worktree lifecycle (v86: an explain phase's detached pair), the convention gate, the agent rename map, a malformed marker fails validate =="
# A host repo with one product commit, and the live engine + templates (+ a seed install's docs) in a
# nested git repo at host/workflow/ beside the marker. Every command runs from the host root, the way
# a nested session does. The at-root invariant is every earlier test passing unchanged.
newtmp NS
NH="$NS/host"
sh "$BOOT" "$NS/seed" --at-root --name "Nested seed" --summary "nested probe" >/dev/null 2>&1 || bad "nested probe: seed install failed"
mkdir -p "$NH/src" "$NH/workflow/scripts" "$NH/workflow/works" \
  && ( cd "$NH" && { git init -q -b main . 2>/dev/null || git init -q .; } && git config user.email smoke@example.invalid \
       && git config user.name smoke && printf 'print("host")\n' > src/app.py && git add -A >/dev/null 2>&1 \
       && git commit -qm "host baseline" >/dev/null 2>&1 ) \
  && cp "$SRC/scripts/workflow.py" "$NH/workflow/scripts/" && cp -R "$SRC/works/templates" "$NH/workflow/works/" \
  && cp -R "$NS/seed/docs" "$NH/workflow/" && ( cd "$NH/workflow" && git init -q . ) \
  || bad "nested probe: could not build the host + workflow/ fixture"
cat > "$NH/workflow/.agentic-nested.json" <<'NESTED'
{"schema": 1, "host_root": "..",
 "commit_convention": {"inferred": "type(scope): summary", "confirmed": false, "text": null, "coauthor_trailers": "unknown"},
 "renames": {"skills": {}, "agents": {"design-drafter": "wf-design-drafter"}}}
NESTED
nw() { ( cd "$NH" && python3 workflow/scripts/workflow.py "$@" ); }
{ nw rebuild && nw new-phase --phase P1 --name "Nested probe" --objective "probe the host"; } >/dev/null 2>&1 \
  || bad "nested probe: rebuild / new-phase failed"
host_head=$( cd "$NH" && git rev-parse HEAD )
if python3 - "$NH/workflow/works/phases/active/P1/phase.json" "$host_head" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
assert data.get("host_anchors") == {"created": sys.argv[2]}, data.get("host_anchors")
PY
then ok "new-phase records host_anchors.created = the host HEAD in phase.json"; else bad "phase.json carries no host anchor equal to the host HEAD"; fi
# The host's own docs/ is product; an untracked file inside the nested repo is not.
mkdir -p "$NH/docs" && printf 'guide\n' > "$NH/docs/guide.md" && printf 'print("feature")\n' > "$NH/src/feature.py"
( cd "$NH" && git add src docs >/dev/null 2>&1 && git commit -qm "product change" >/dev/null 2>&1 ) || bad "nested probe: could not commit the product change"
printf 'scratch\n' > "$NH/workflow/scratch.txt"
scope_out=$(nw phase-scope P1 2>&1); scope_rc=$?
[ "$scope_rc" -eq 0 ] && printf '%s\n' "$scope_out" | grep -q "^mode=nested$" \
  && printf '%s\n' "$scope_out" | grep -q "^base=$host_head (" \
  && printf '%s\n' "$scope_out" | grep -qx "  A src/feature.py" && printf '%s\n' "$scope_out" | grep -qx "  A docs/guide.md" \
  && ! printf '%s\n' "$scope_out" | grep -qE "^  [AMDR] (workflow/|src/app.py)" \
  && ok "phase-scope reads the host repo from the anchor: the product commit's files (the host's docs/ included), nothing under workflow/" \
  || bad "nested phase-scope did not read the host boundary (rc=$scope_rc) -- $scope_out"
ps_out=$(nw parallel-start P1 2>&1); ps_rc=$?
[ "$ps_rc" -ne 0 ] && printf '%s\n' "$ps_out" | grep -q "^parallel-start in a nested install needs --host-branch <name>" \
  && ! grep -q '"execution"' "$NH/workflow/works/phases/active/P1/phase.json" \
  && ok "nested parallel-start without --host-branch refuses and writes nothing" || bad "nested parallel-start did not refuse a missing --host-branch (rc=$ps_rc) -- $ps_out"
nx=$(nw next 2>&1)
printf '%s\n' "$nx" | grep -q "^nested_host=/" && printf '%s\n' "$nx" | grep -q "^host_commit_convention=UNCONFIRMED (inferred: type(scope): summary)" \
  && printf '%s\n' "$nx" | grep -qx "slice_path=workflow/works/phases/active/P1/slices/P1.DECOMP" \
  && ok "next names the host, holds the unconfirmed convention, and prints host-relative paths" || bad "nested next lines missing -- $nx"
nw nested-convention --confirm --text "type(scope): summary" --trailers forbidden >/dev/null 2>&1 || bad "nested probe: nested-convention --confirm failed"
nx=$(nw next 2>&1)
if printf '%s\n' "$nx" | grep -q "^host_commit_convention=confirmed (coauthor_trailers=forbidden)" && ! printf '%s\n' "$nx" | grep -q "UNCONFIRMED" \
    && python3 -c 'import json,sys; c=json.load(open(sys.argv[1]))["commit_convention"]; assert c["confirmed"] is True and c["text"] == "type(scope): summary" and c["inferred"] == "type(scope): summary", c' "$NH/workflow/.agentic-nested.json"; then
  ok "nested-convention --confirm records the text and the trailer rule, and next stops flagging it"; else bad "nested-convention --confirm did not flip the convention -- $nx"; fi
# The agent rename map: design-drafter is installed as wf-design-drafter in the host's .claude/agents.
mkdir -p "$NH/.claude/agents" && cp "$SRC/claude/agents/slice-executor.md" "$SRC/claude/agents/design-critic.md" "$SRC/claude/agents/Explore.md" "$NH/.claude/agents/" \
  && sed 's/^name: design-drafter$/name: wf-design-drafter/' "$SRC/claude/agents/design-drafter.md" > "$NH/.claude/agents/wf-design-drafter.md"
nw sync-agents >/dev/null 2>&1
if nw sync-agents --check >/dev/null 2>&1 && grep -qx "name: wf-design-drafter" "$NH/.claude/agents/wf-design-drafter.md" \
    && [ ! -e "$NH/.claude/agents/design-drafter.md" ] && [ ! -e "$NH/workflow/.claude" ]; then
  ok "sync-agents resolves agents in the host's .claude/agents through the rename map and keeps the renamed name:"
else bad "sync-agents missed the host agent dir or the rename map, or rewrote name:"; fi
nw validate >/dev/null 2>&1 && ok "validate passes on a well-formed nested install" || bad "validate failed on a well-formed nested install -- $(nw validate 2>&1)"
# v61: the resume card from the host prints host-relative paths, within its 2,048 B.
card=$(nw next --card 2>&1); cr_rc=$?
[ "$cr_rc" -eq 0 ] && [ "$(printf '%s' "$card" | wc -c | tr -d ' ')" -le 2048 ] && printf '%s\n' "$card" | grep -qx 'phase: workflow/works/phases/active/P1/phase.md' \
  && printf '%s\n' "$card" | grep -qF 'commands run as `python3 workflow/scripts/workflow.py <command>`' \
  && ok "nested: next --card names host-relative paths and the nested engine command, within 2,048 B" || bad "nested next --card wrong (rc=$cr_rc): $card"
printf '{"schema": 1, "host_root": ".."' > "$NH/workflow/.agentic-nested.json"
val_out=$(nw validate 2>&1); val_rc=$?; nx_out=$(nw next 2>&1); nx_rc=$?
[ "$val_rc" -ne 0 ] && printf '%s\n' "$val_out" | grep -Fq ".agentic-nested.json: cannot be read as JSON" \
  && [ "$nx_rc" -ne 0 ] && printf '%s\n' "$nx_out" | grep -Fq ".agentic-nested.json is malformed" \
  && ok "a malformed .agentic-nested.json fails validate and stops every other command (never read as at-root mode)" \
  || bad "a malformed .agentic-nested.json passed validate or ran next (rc=$val_rc/$nx_rc) -- $val_out $nx_out"
cr_out=$(printf '{}' | nw compact-resume 2>&1); cr_rc=$?
[ "$cr_rc" -eq 0 ] && [ "$(printf '%s\n' "$cr_out" | head -1)" = "compaction=done source=compact" ] \
  && ok "a malformed marker never stops the resume hook: compact-resume still runs and exits 0" \
  || bad "the resume hook refused on a malformed marker (rc=$cr_rc): $cr_out"
# The paired worktree lifecycle (P35): a nested phase runs in a host worktree with the nested worktree inside,
# claims its own stream, shows in the main backlog's Streams view, resumes through the compaction hook's cwd, is
# guarded at teardown and is retired nested-first, keeping the host branch. It runs last: it restores a valid
# marker (the truncated one above is the previous assertion's) and commits the fixture's nested repo.
cat > "$NH/workflow/.agentic-nested.json" <<'NESTED'
{"schema": 1, "host_root": "..",
 "commit_convention": {"inferred": "type(scope): summary", "confirmed": true, "text": "type(scope): summary", "coauthor_trailers": "forbidden"},
 "renames": {"skills": {}, "agents": {"design-drafter": "wf-design-drafter"}}}
NESTED
NW="$NH/workflow"
printf '/workflow/\n/.claude/agents/\n' >> "$NH/.git/info/exclude"
printf 'temp/\n' >> "$NW/.git/info/exclude"
( cd "$NW" && git config user.email smoke@example.invalid && git config user.name smoke && git branch -M main >/dev/null 2>&1 \
    && git add -A >/dev/null 2>&1 && git commit -qm "nested baseline" >/dev/null 2>&1 ) || bad "paired lifecycle: could not commit the nested fixture"
nw rebuild >/dev/null 2>&1; ( cd "$NW" && git add -A >/dev/null 2>&1 && git commit -qm "rebuild" >/dev/null 2>&1 )
ps_out=$(nw parallel-start P1 --host-branch feat/side 2>&1); ps_rc=$?
HWT=$(printf '%s\n' "$ps_out" | sed -n 's/^host_worktree=//p'); PBR=$(printf '%s\n' "$ps_out" | sed -n 's/^branch=//p')
if [ "$ps_rc" -eq 0 ] && [ -d "$HWT/workflow" ] && git -C "$NH" worktree list | grep -qF "$HWT" && git -C "$NW" worktree list | grep -qF "$HWT/workflow" \
    && [ -z "$(git -C "$NH" status --short)" ]; then
  ok "paired parallel-start: both repos list the new worktree, <host-wt>/workflow exists and the host's git status is empty"
else bad "paired parallel-start (rc=$ps_rc) -- $ps_out -- host status: $(git -C "$NH" status --short)"; fi
wt_next=$( cd "$HWT" && python3 workflow/scripts/workflow.py next 2>&1 ); main_next=$(nw next 2>&1)
nw rebuild >/dev/null 2>&1
if printf '%s\n' "$wt_next" | grep -q "^stream=phase/P1-" && ! printf '%s\n' "$main_next" | grep -q "^current_phase=P1" \
    && grep -A8 '^## Streams' "$NW/works/backlog.md" | grep -E '^\|' | grep -F 'P1' | grep -qF 'feat/side'; then
  ok "the worktree's next prints stream=phase/P1-..., the main checkout skips P1, and backlog.md's ## Streams row carries P1 with feat/side"
else bad "stream claim or Streams row wrong -- worktree: $wt_next -- main: $main_next -- $(grep -A8 '^## Streams' "$NW/works/backlog.md")"; fi
# v67: a state change in the worktree refreshes the main checkout's backlog, read from the worktree's files (uncommitted).
( cd "$HWT" && python3 workflow/scripts/workflow.py set-slice-status P1.DECOMP in_progress >/dev/null 2>&1 )
grep -F '`P1.DECOMP`' "$NW/works/backlog.md" | grep -qF '`in_progress`' && grep -qF '_Read live from its worktree `' "$NW/works/backlog.md" \
  && ok "a slice status changed in the worktree shows in the main checkout's backlog, with nothing run there" \
  || bad "the main backlog did not follow the worktree -- $(grep -F 'P1.' "$NW/works/backlog.md")"
hook_out=$(printf '{"session_id":"t","source":"compact","cwd":"%s"}' "$HWT" | python3 "$NH/workflow/scripts/workflow.py" compact-resume 2>&1)
printf '%s\n' "$hook_out" | grep -q "^stream=phase/P1-" && printf '%s\n' "$hook_out" | grep -q "^pointer: phase P1 " \
  && ok "compact-resume replayed from the main checkout with the worktree's cwd redirects to the worktree's own stream" \
  || bad "the compaction hook did not follow the worktree cwd -- $hook_out"
printf 'product\n' > "$HWT/src/side.py" && git -C "$HWT" add src/side.py >/dev/null 2>&1 && git -C "$HWT" commit -qm "side" >/dev/null 2>&1
mkdir -p "$HWT/workflow/temp" && printf 'note\n' > "$HWT/workflow/temp/note.txt"
git -C "$HWT/workflow" checkout -q -- . >/dev/null 2>&1   # drop the regenerated works/ files `next` rewrote
printf 'merged\n' > "$HWT/workflow/merged.txt" && git -C "$HWT/workflow" add -A >/dev/null 2>&1 && git -C "$HWT/workflow" commit -qm "phase work" >/dev/null 2>&1
git -C "$NW" add -A >/dev/null 2>&1 && git -C "$NW" commit -qm "regenerated works" >/dev/null 2>&1
git -C "$NW" merge --no-ff -q -m "merge phase" "$PBR" >/dev/null 2>&1 || bad "paired lifecycle: could not merge $PBR into the nested default branch"
td_out=$(nw parallel-teardown P1 2>&1); td_rc=$?
[ "$td_rc" -ne 0 ] && printf '%s\n' "$td_out" | grep -qF "parallel-teardown P1 refused -- nothing was removed:" \
  && printf '%s\n' "$td_out" | grep -qF "ignored, worktree-only files would be deleted" && printf '%s\n' "$td_out" | grep -qF "temp/" \
  && [ -d "$HWT/workflow" ] && git -C "$NH" worktree list | grep -qF "$HWT" \
  && ok "paired parallel-teardown refuses first on the ignored worktree-only temp/ and removes nothing" \
  || bad "the teardown guard did not refuse (rc=$td_rc) -- $td_out"
td_out=$(nw parallel-teardown P1 --discard-ignored 2>&1); td_rc=$?
nested_at=$(printf '%s\n' "$td_out" | grep -n '^removed nested worktree' | head -1 | cut -d: -f1); host_at=$(printf '%s\n' "$td_out" | grep -n '^removed host worktree' | head -1 | cut -d: -f1)
if [ "$td_rc" -eq 0 ] && [ -n "$nested_at" ] && [ -n "$host_at" ] && [ "$nested_at" -lt "$host_at" ] && printf '%s\n' "$td_out" | grep -q "^kept host branch feat/side:" \
    && [ -n "$(git -C "$NH" branch --list feat/side)" ] && [ ! -e "$HWT" ] \
    && ! git -C "$NH" worktree list | grep -qF "$HWT" && ! git -C "$NW" worktree list | grep -qF "$HWT" \
    && ! git -C "$NH" worktree list --porcelain | grep -q '^prunable' && ! git -C "$NW" worktree list --porcelain | grep -q '^prunable'; then
  ok "paired parallel-teardown --discard-ignored removes the nested worktree before the host worktree and keeps the host branch feat/side"
else bad "paired teardown wrong (rc=$td_rc) -- $td_out"; fi
# v86 (§9.4): an explain phase's pair goes detached without --host-branch -- no host branch is made, kept or deleted.
{ nw new-phase --phase P2 --name "Explain: probe" --objective "detached host" \
    && printf '\n## Explain\n\n- unit: document\n' >> "$NW/works/phases/active/P2/intent.md"; } >/dev/null 2>&1 || bad "detached pair: could not create the explain phase"
hb_before=$(git -C "$NH" branch --list | wc -l | tr -d ' ')
ps_out=$(nw parallel-start P2 2>&1); ps_rc=$?
HWT2=$(printf '%s\n' "$ps_out" | sed -n 's/^host_worktree=//p'); PBR2=$(printf '%s\n' "$ps_out" | sed -n 's/^branch=//p')
if [ "$ps_rc" -eq 0 ] && printf '%s\n' "$ps_out" | grep -q '^host_branch=- (detached host worktree' && [ -d "$HWT2/workflow" ] \
    && ! git -C "$HWT2" symbolic-ref -q HEAD >/dev/null 2>&1 && [ "$(git -C "$NH" branch --list | wc -l | tr -d ' ')" = "$hb_before" ] \
    && python3 -c 'import json,sys; e=json.load(open(sys.argv[1]))["execution"]; assert e["host_branch"] is None and e["host_branch_created"] is False, e' "$NW/works/phases/active/P2/phase.json" \
    && nw validate >/dev/null 2>&1; then
  ok "nested parallel-start of an explain phase with no --host-branch cuts a detached host worktree: host_branch null, no host branch made, validate passes"
else bad "detached explain pair wrong (rc=$ps_rc) -- $ps_out -- $(nw validate 2>&1 | tail -3)"; fi
PG="$HWT2/workflow/works/phases/active/P2/doc/pages"
mkdir -p "$PG" && printf '*\n!.gitignore\n' > "$PG/.gitignore" && printf 'cached\n' > "$PG/p1.html" \
  && git -C "$HWT2/workflow" add works/phases/active/P2/doc >/dev/null 2>&1 && git -C "$HWT2/workflow" commit -qm "dossier" >/dev/null 2>&1 \
  && git -C "$NW" add -A >/dev/null 2>&1 && { git -C "$NW" commit -qm "default state" >/dev/null 2>&1; git -C "$NW" merge --no-ff -q -m "merge P2" "$PBR2" >/dev/null 2>&1; } \
  || bad "detached pair: could not commit the dossier or merge $PBR2"
td_out=$(nw parallel-teardown P2 --discard-ignored 2>&1); td_rc=$?
if [ "$td_rc" -eq 0 ] && printf '%s\n' "$td_out" | grep -q '^no host branch: the host worktree was detached' && printf '%s\n' "$td_out" | grep -q '^deleted 1 ignored' \
    && [ ! -e "$HWT2" ] && [ "$(git -C "$NH" branch --list | wc -l | tr -d ' ')" = "$hb_before" ] \
    && ! git -C "$NH" worktree list | grep -qF "$HWT2" && ! git -C "$NW" worktree list | grep -qF "$HWT2" && nw validate >/dev/null 2>&1; then
  ok "the detached pair's teardown --discard-ignored drops the ignored pages/ and both worktrees and leaves no host branch"
else bad "detached pair teardown wrong (rc=$td_rc) -- $td_out"; fi


# ---------------------------------------------------------------------------
echo "== Test 15: P28 nested install -- --nested leaves the host clean (status, HEAD, config), renames a clashing skill, prefixes every engine path, imports the contract, refreshes in place with --update --nested, and refuses a host whose .gitignore would expose a target =="
# A host with a tracked team contract, settings.json, .gitattributes, CI and its own `commit` skill
# (a clash with ours), plus Conventional-Commit history. Every workflow command runs from the host root.
newtmp NI
IH="$NI/host"
mkdir -p "$IH/.claude/skills/commit" "$IH/.claude/skills/design-cowork" "$IH/.github/workflows" "$IH/src" && ( cd "$IH" && { git init -q -b main . 2>/dev/null || git init -q .; } \
  && git config user.email smoke@example.invalid && git config user.name smoke && printf '# Team contract\n' > CLAUDE.md \
  && printf '{"permissions": {"allow": ["Bash(npm test:*)"]}}\n' > .claude/settings.json && printf '*.png binary\n' > .gitattributes \
  && printf 'name: ci\non: push\njobs: {}\n' > .github/workflows/ci.yml \
  && printf -- '---\nname: commit\ndescription: the team commit skill\n---\n\nTeam rules.\n' > .claude/skills/commit/SKILL.md \
  && printf -- '---\nname: design-cowork\ndescription: the team design skill\n---\n\nTeam design rules.\n' > .claude/skills/design-cowork/SKILL.md \
  && git add -A && git commit -qm "chore: initial import" \
  && for s in "feat(api): add users" "fix(api): empty body" "docs: setup" "refactor(core): split"; do printf '%s\n' "$s" >> src/log.txt && git add -A && git commit -qm "$s" || exit 1; done ) >/dev/null 2>&1 \
  || bad "nested install: could not build the host fixture"
ih_head=$(cd "$IH" && git rev-parse HEAD); ih_skill=$(sha "$IH/.claude/skills/commit/SKILL.md"); ih_design=$(sha "$IH/.claude/skills/design-cowork/SKILL.md")
iw() { ( cd "$IH" && python3 workflow/scripts/workflow.py "$@" ); }
ih_clean() { [ -z "$(cd "$IH" && git status --porcelain)" ]; }
out=$(sh "$BOOT" "$IH" --nested 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "--nested installs into the host repo (exit 0)" || bad "--nested install failed (rc=$rc) -- $out"
ih_clean && [ "$(cd "$IH" && git rev-parse HEAD)" = "$ih_head" ] && ! ( cd "$IH" && git config --local --get core.hooksPath >/dev/null ) \
  && ok "the host is untouched: git status --porcelain empty, HEAD unchanged, core.hooksPath unset" || bad "the nested install left a host footprint -- $(cd "$IH" && git status --porcelain)"
[ -d "$IH/workflow/.git" ] && [ ! -e "$IH/workflow/.claude" ] && [ ! -e "$IH/workflow/CLAUDE.md" ] && [ -f "$IH/workflow/CLAUDE.workspace.md" ] \
  && ok "workflow/ is a nested git repo holding the contract as CLAUDE.workspace.md, with no CLAUDE.md and no .claude/" || bad "workflow/ layout is wrong (.git, CLAUDE.md, .claude/)"
python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["renames"]; assert r == {"skills": {"commit": "wf-commit", "design-cowork": "wf-design-cowork"}, "agents": {}}, r' "$IH/workflow/.agentic-nested.json" >/dev/null 2>&1 \
  && grep -qx "name: wf-commit" "$IH/.claude/skills/wf-commit/SKILL.md" && [ "$(sha "$IH/.claude/skills/commit/SKILL.md")" = "$ih_skill" ] \
  && ok "the clashing commit skill installs as wf-commit (marker rename + name:), and the host's own commit skill is byte-identical" || bad "the commit clash was not renamed cleanly"
# v61 (P37.S1): a renamed split skill keeps its whole directory -- core and reference files -- under the new name.
skill_tree_ok "$IH/.claude/skills" nested commit=wf-commit design-cowork=wf-design-cowork && grep -qx "name: wf-design-cowork" "$IH/.claude/skills/wf-design-cowork/SKILL.md" \
  && [ "$(sha "$IH/.claude/skills/design-cowork/SKILL.md")" = "$ih_design" ] && [ ! -e "$IH/.claude/skills/design-cowork/reference" ] && ih_clean \
  && ok "nested: the clashing design-cowork installs as wf-design-cowork with its reference/ files, the do-* references (shared copy included) ship, the host's own design-cowork is untouched, and the host stays clean" \
  || bad "nested: a renamed split skill or its reference files were not installed cleanly -- $(cd "$IH" && git status --porcelain)"
left=$(cd "$IH" && grep -rlF "python3 scripts/workflow.py" .claude CLAUDE.local.md workflow/CLAUDE.workspace.md workflow/works/templates 2>/dev/null)
[ -z "$left" ] && grep -rqF "python3 workflow/scripts/workflow.py" "$IH/.claude/skills/do-next-slice" "$IH/.claude/settings.local.json" \
  && ok "no unprefixed python3 scripts/workflow.py in the host's .claude/, CLAUDE.local.md, the contract or the templates" || bad "unprefixed engine command left in: $left"
if python3 - "$IH/CLAUDE.local.md" <<'PY'
import sys
fence = found = False
for line in open(sys.argv[1], encoding="utf-8"):
    fence = (not fence) if line.lstrip().startswith(("```", "~~~")) else fence
    found = found or (line.strip() == "@workflow/CLAUDE.workspace.md" and not fence)
assert found
PY
then ok "CLAUDE.local.md imports @workflow/CLAUDE.workspace.md on its own line, outside any fence"; else bad "CLAUDE.local.md lacks the import line outside fences"; fi
nx=$(iw next 2>&1)
iw validate >/dev/null 2>&1 && printf '%s\n' "$nx" | grep -qF 'host_commit_convention=UNCONFIRMED (inferred: Conventional Commits "type(scope): summary" (5/5 recent subjects' \
  && ok "from the host, validate passes and next shows the UNCONFIRMED inferred Conventional-Commits convention" || bad "nested validate / next wrong -- $nx"
iw new-phase --phase P1 --name "Nested install probe" --objective "probe" >/dev/null 2>&1; scope=$(iw phase-scope P1 2>&1)
printf '%s\n' "$scope" | grep -q "^product_files=0 " && ! printf '%s\n' "$scope" | grep -q "uncommitted_product_files=" && ih_clean \
  && ok "right after install, new-phase then phase-scope lists nothing (info/exclude hides every host-side file)" || bad "phase-scope sees the install as product -- $scope"
out=$(sh "$BOOT" "$IH" --nested 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q "already installed" && ih_clean && ok "re-running --nested is an idempotent exit 0" || bad "re-running --nested was not a clean no-op (rc=$rc) -- $out"
iw nested-convention --confirm --text "type(scope): summary" --trailers forbidden >/dev/null 2>&1 || bad "nested install: nested-convention --confirm failed"
# An earlier nested install's explain skill (listed under `installed`, its exclude line in the block, no self-hiding
# .gitignore): --update keeps it recognised and hidden, and never writes, flags or reports it.
plant_old_explain "$IH/.claude/skills/explain/SKILL.md"
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["installed"]["skills"]=sorted(d["installed"]["skills"]+["explain"]); open(p,"w").write(json.dumps(d,indent=2)+"\n")' "$IH/workflow/.agentic-nested.json"
python3 -c 'import sys; p=sys.argv[1]; t=open(p).read(); b="# BEGIN agentic-workspace (nested)\n"; open(p,"w").write(t.replace(b, b+"/.claude/skills/explain/\n",1))' "$IH/.git/info/exclude"
ih_explain=$(explain_sig "$IH"); dry_ex=$(sh "$BOOT" "$IH" --update --nested --dry-run 2>&1)
out=$(sh "$BOOT" "$IH" --update --nested 2>&1); rc=$?
[ "$rc" -eq 0 ] && ih_clean && [ -n "$ih_explain" ] && [ "$(explain_sig "$IH")" = "$ih_explain" ] && [ ! -e "$IH/.claude/skills/explain/.gitignore" ] \
  && ! printf '%s\n%s\n' "$dry_ex" "$out" | grep -q 'explain' && grep -qx '/\.claude/skills/explain/' "$IH/.git/info/exclude" \
  && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "explain" in d["installed"]["skills"] and "explain" not in json.dumps(d.get("stale", [])), d' "$IH/workflow/.agentic-nested.json" \
  && ok "nested: --update (and --dry-run) leaves an earlier install's explain skill byte-identical, unflagged, unreported, still in installed and the exclude block, the host clean" \
  || bad "nested --update touched, flagged or exposed the old explain skill (rc=$rc) -- $(printf '%s\n%s\n' "$dry_ex" "$out" | grep explain) $(cd "$IH" && git status --porcelain)"
if [ "$rc" -eq 0 ] && ih_clean && [ ! -e "$IH/workflow/workflow" ] && ! grep -rqF "workflow/workflow/" "$IH/.claude/skills" "$IH/workflow/CLAUDE.workspace.md" \
    && [ "$(grep -cx '# BEGIN agentic-workspace (nested)' "$IH/.git/info/exclude")" -eq 1 ] && [ "$(grep -cx '<!-- BEGIN agentic-workspace (nested) -->' "$IH/CLAUDE.local.md")" -eq 1 ] \
    && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); c=d["commit_convention"]; assert c["confirmed"] is True and c["coauthor_trailers"] == "forbidden" and d["renames"]["skills"] == {"commit": "wf-commit", "design-cowork": "wf-design-cowork"}, d' "$IH/workflow/.agentic-nested.json" >/dev/null 2>&1; then
  ok "--update --nested keeps the confirmed convention and the renames, the host stays clean, no workflow/workflow/, one exclude block"
else bad "--update --nested lost state or left a footprint (rc=$rc) -- $out"; fi
# The nested settings.local.json carries the resume hook, command rewritten to the nested engine path (v61: no PreCompact).
if python3 - "$IH/.claude/settings.local.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
resume = 'cd "$CLAUDE_PROJECT_DIR" && python3 workflow/scripts/workflow.py compact-resume || true'
assert d["hooks"] == {"SessionStart": [{"matcher": "compact", "hooks": [{"type": "command", "command": resume, "timeout": 15}]}]}, d["hooks"]
assert d["autoCompactWindow"] == 500000, d
PY
then ok "nested: settings.local.json carries only the resume hook with the workflow/scripts/workflow.py command path and window 500000, and --update --nested kept exactly one"; else bad "nested settings.local.json hooks wrong"; fi
# v61 (P37.S1): --update --nested on a v60-shaped host (no reference/ files) adds them in the renamed dir, host clean.
rm -rf "$IH/.claude/skills/wf-design-cowork/reference" "$IH/.claude/skills/do-whole-phase/reference"
out=$(sh "$BOOT" "$IH" --update --nested 2>&1); rc=$?
[ "$rc" -eq 0 ] && skill_tree_ok "$IH/.claude/skills" nested commit=wf-commit design-cowork=wf-design-cowork && ih_clean \
  && printf '%s\n' "$out" | grep -qx '    + \.claude/skills/wf-design-cowork/reference/shape\.md' \
  && ok "nested: --update --nested adds the reference files to a v60-shaped host, in the renamed dir, and the host stays clean" || bad "nested --update did not restore the reference files (rc=$rc) -- $out"
lset_a=$(sha "$IH/.claude/settings.local.json")
sh "$BOOT" "$IH" --update --nested >/dev/null 2>&1
[ "$(sha "$IH/.claude/settings.local.json")" = "$lset_a" ] && ih_clean \
  && ok "nested: a second --update --nested leaves settings.local.json byte-identical" || bad "nested --update rewrote settings.local.json"
# v61: a v60-shaped settings.local.json (our compact-gate beside a foreign PreCompact handler, window 450000 (v66-v81),
# our resume handler removed) loses exactly ours, keeps theirs, regains the resume hook, moves to 500000, lists both.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["hooks"]["PreCompact"]=[{"matcher":"auto","hooks":[{"type":"command","command":"echo foreign-nested"},{"type":"command","command":"cd \"$CLAUDE_PROJECT_DIR\" && python3 workflow/scripts/workflow.py compact-gate || true","timeout":15}]}]; d["hooks"]["Stop"]=[{"hooks":[{"type":"command","command":"echo stop"}]}]; d["hooks"]["SessionStart"][0]["hooks"]=[]; d["autoCompactWindow"]=450000; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$IH/.claude/settings.local.json"
out=$(sh "$BOOT" "$IH" --update --nested 2>&1)
if python3 - "$IH/.claude/settings.local.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
h = d["hooks"]
assert h["PreCompact"] == [{"matcher": "auto", "hooks": [{"type": "command", "command": "echo foreign-nested"}]}], h["PreCompact"]
assert [x["command"] for g in h["SessionStart"] for x in g["hooks"]] == ['cd "$CLAUDE_PROJECT_DIR" && python3 workflow/scripts/workflow.py compact-resume || true'], h["SessionStart"]
assert h["Stop"] == [{"hooks": [{"type": "command", "command": "echo stop"}]}]
assert d["autoCompactWindow"] == 500000, d
PY
then printf '%s\n' "$out" | grep -q '^  removed: .claude/settings.local.json hooks.PreCompact compact-gate (retired in v61)$' \
  && printf '%s\n' "$out" | grep -q '^  changed: .claude/settings.local.json autoCompactWindow 450000 -> 500000 ' && ih_clean \
  && ok "nested: --update --nested on a v60-shaped settings.local.json removes only our compact-gate, keeps the foreign hooks, re-adds the resume hook, sets 500000 and lists both" \
  || bad "nested --update did not report the settings changes -- $out"
else bad "nested present-file hooks merge wrong -- $out"; fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["autoCompactWindow"]=400000; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$IH/.claude/settings.local.json"
sh "$BOOT" "$IH" --update --nested >/dev/null 2>&1
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["autoCompactWindow"] == 400000' "$IH/.claude/settings.local.json" \
  && ok "nested: --update --nested never overwrites an autoCompactWindow the adopter chose (400000)" || bad "nested --update overwrote the adopter's autoCompactWindow"
# 500000 window (v82): the 300000 window v56 and v61-v65 shipped (a v65-shaped nested file) moves to 500000 too, listed.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["autoCompactWindow"]=300000; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$IH/.claude/settings.local.json"
out=$(sh "$BOOT" "$IH" --update --nested 2>&1)
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["autoCompactWindow"] == 500000' "$IH/.claude/settings.local.json" \
  && printf '%s\n' "$out" | grep -q '^  changed: .claude/settings.local.json autoCompactWindow 300000 -> 500000 (today.s default; set it back if you chose 300000)$' \
  && ok "nested: --update --nested moves a v65-shaped 300000 window to 500000 and lists it" || bad "nested --update did not move the 300000 window -- $out"
out=$(sh "$BOOT" "$IH" --nested --into-existing 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "mutually exclusive" && ok "--nested --into-existing is rejected" || bad "--nested --into-existing was accepted (rc=$rc) -- $out"
# v53 (P32.S5): a host that already has its own .claude/agents/Explore.md gets ours renamed like any clash.
IX="$NI/explore-host"
mkdir -p "$IX/.claude/agents" && ( cd "$IX" && { git init -q -b main . 2>/dev/null || git init -q .; } && git config user.email smoke@example.invalid && git config user.name smoke \
  && printf -- '---\nname: Explore\ndescription: the host explore agent\n---\n\nHost rules.\n' > .claude/agents/Explore.md && git add -A && git commit -qm "chore: host explore" ) >/dev/null 2>&1 \
  || bad "nested install: could not build the Explore-clash host fixture"
ix_explore=$(sha "$IX/.claude/agents/Explore.md"); out=$(sh "$BOOT" "$IX" --nested 2>&1); rc=$?
python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["renames"]["agents"]; assert r.get("Explore") == "wf-Explore", r' "$IX/workflow/.agentic-nested.json" >/dev/null 2>&1 \
  && [ "$rc" -eq 0 ] && grep -qx "name: wf-Explore" "$IX/.claude/agents/wf-Explore.md" && [ "$(sha "$IX/.claude/agents/Explore.md")" = "$ix_explore" ] \
  && grep -rq 'subagent_type: wf-Explore' "$IX/.claude/skills/do-next-slice" "$IX/.claude/agents/slice-executor.md" \
  && ( cd "$IX" && python3 workflow/scripts/workflow.py sync-agents --check >/dev/null 2>&1 ) \
  && ok "a host with its own Explore.md: ours installs as wf-Explore (marker rename + name:), the host's is byte-identical, the executors and skill call wf-Explore" \
  || bad "the Explore clash was not renamed cleanly (rc=$rc) -- $out"
echo "NOTE: wf-Explore occurrences: slice-executor=$(grep -o 'wf-Explore' "$IX/.claude/agents/slice-executor.md" | wc -l | tr -d ' ')"
# v66: a nested --update from a v65 marker. The host holds v65's two executors as v65's nested install wrote
# them (nested_rewrite of tests/fixtures/v65, rebuilt here from the installer's own rewrite patterns), one of
# them renamed wf-slice-executor-high by an old clash and one patched by sync-agents: both list stale.
IV="$NI/v65-host"
mkdir -p "$IV" && ( cd "$IV" && { git init -q -b main . 2>/dev/null || git init -q .; } && git config user.email smoke@example.invalid && git config user.name smoke \
  && printf 'host\n' > README.md && git add -A && git commit -qm "chore: init" ) >/dev/null 2>&1 && sh "$BOOT" "$IV" --nested >/dev/null 2>&1 \
  || bad "nested v65 probe: could not build the host"
python3 - "$REPO_ROOT" "$IV" <<'PY' || bad "nested v65 probe: could not plant the v65 executors"
import json, re, sys
from pathlib import Path
repo, host = Path(sys.argv[1]), Path(sys.argv[2])
src = (repo / "installer/main.py").read_text()
ns = {"re": re}
for name in ("NESTED_DIR", "NESTED_CONTRACT", "NESTED_ENGINE_RE", "NESTED_PATH_RE", "NESTED_CONTRACT_REF_RE", "NESTED_PROTECT_RE"):
    exec(re.search(r"(?ms)^" + name + r" = .*?(?=^\S)", src).group(0), ns)
def rewrite(text, agents):  # nested_rewrite for these texts: paths, the contract, then agent renames outside workflow.py commands
    text = ns["NESTED_ENGINE_RE"].sub(f"{ns['NESTED_DIR']}/scripts/workflow.py", text)
    text = ns["NESTED_PATH_RE"].sub(lambda m: f"{ns['NESTED_DIR']}/{m.group(0)}", text)
    text = ns["NESTED_CONTRACT_REF_RE"].sub(f"`{ns['NESTED_DIR']}/{ns['NESTED_CONTRACT']}`", text)
    parts = ns["NESTED_PROTECT_RE"].split(text)
    for i in range(0, len(parts), 2):
        for x, y in agents.items():
            parts[i] = re.sub(r"(?<![\w-])" + re.escape(x) + r"(?![\w-])", y, parts[i])
    return "".join(parts)
agents_dir = host / ".claude/agents"
(agents_dir / "slice-executor.md").unlink()
renames = {"slice-executor-high": "wf-slice-executor-high"}
mid = rewrite((repo / "tests/fixtures/v65/slice-executor-mid.md").read_text(), renames)
(agents_dir / "slice-executor-mid.md").write_text(mid.replace("\nmodel: sonnet\n", "\nmodel: haiku\n", 1))
(agents_dir / "wf-slice-executor-high.md").write_text(rewrite((repo / "tests/fixtures/v65/slice-executor-high.md").read_text(), renames))
marker = host / "workflow/.agentic-nested.json"
m = json.loads(marker.read_text())
m["installed"]["agents"] = sorted([a for a in m["installed"]["agents"] if a != "slice-executor"] + ["slice-executor-mid", "wf-slice-executor-high"])
m["renames"]["agents"] = dict(m["renames"].get("agents") or {}, **renames)
marker.write_text(json.dumps(m, indent=2) + "\n")
PY
iv_out=$(sh "$BOOT" "$IV" --update --nested 2>&1); iv_rc=$?
[ "$iv_rc" -eq 0 ] && printf '%s\n' "$iv_out" | grep -qx '    - \.claude/agents/slice-executor-mid\.md  (unchanged since v65 (its model/effort lines aside))' \
  && printf '%s\n' "$iv_out" | grep -qx '    - \.claude/agents/wf-slice-executor-high\.md  (unchanged since v65 (its model/effort lines aside))' \
  && [ -f "$IV/.claude/agents/slice-executor.md" ] && grep -qx 'name: slice-executor' "$IV/.claude/agents/slice-executor.md" \
  && [ -z "$(cd "$IV" && git status --porcelain --untracked-files=all)" ] \
  && ok "nested --update from a v65 marker lists both old executors stale (a renamed copy and a sync-agents-patched one) and installs slice-executor.md, the host clean" \
  || bad "nested --update from a v65 marker wrong (rc=$iv_rc) -- $iv_out"
iv_out=$(sh "$BOOT" "$IV" --update --nested 2>&1)
printf '%s\n' "$iv_out" | grep -qx '    - \.claude/agents/wf-slice-executor-high\.md  (unchanged since v65 (its model/effort lines aside))' \
  && python3 -c 'import json,sys; r=json.load(open(sys.argv[1]))["renames"]["agents"]; assert r.get("slice-executor-high") == "wf-slice-executor-high", r' "$IV/workflow/.agentic-nested.json" \
  && ok "a second nested --update still reads the renamed old executor as stale: the marker keeps a retired copy's rename while the file exists" \
  || bad "a second nested --update lost the retired rename -- $iv_out"
IT="$NI/tracked"
mkdir -p "$IT" && ( cd "$IT" && { git init -q -b main . 2>/dev/null || git init -q .; } && git config user.email smoke@example.invalid && git config user.name smoke \
  && printf 'team notes\n' > CLAUDE.local.md && git add -A && git commit -qm "chore: team local notes" ) >/dev/null 2>&1 || bad "nested install: could not build the tracked-target fixture"
it_sig() { ( cd "$IT" && find . -path ./.git/objects -prune -o -print | LC_ALL=C sort; cat .git/info/exclude 2>/dev/null ) | sha_stdin; }
it_before=$(it_sig); out=$(sh "$BOOT" "$IT" --nested 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q "  - CLAUDE.local.md" && [ ! -e "$IT/workflow" ] && [ "$(it_sig)" = "$it_before" ] \
  && ok "a host that tracks CLAUDE.local.md is refused, naming it, with nothing written" || bad "a tracked CLAUDE.local.md was not refused cleanly (rc=$rc) -- $out"
# P28.F1: a tracked .gitignore negation outranks info/exclude. Our skill dirs hide themselves (a per-dir
# .gitignore of *); any other target a host .gitignore re-includes refuses the install before any write.
ign_host() { mkdir -p "$1" && ( cd "$1" && { git init -q -b main . 2>/dev/null || git init -q .; } && git config user.email smoke@example.invalid \
  && git config user.name smoke && printf '%b' "$2" > .gitignore && printf 'notes\n' > README.md && git add -f .gitignore README.md \
  && git commit -qm "chore: init" ) >/dev/null 2>&1 || bad "nested install: could not build the $1 fixture"; }
ign_sig() { ( cd "$1" && find . -path ./.git/objects -prune -o -print | LC_ALL=C sort; cat .git/info/exclude 2>/dev/null ) | sha_stdin; }
IG="$NI/ign-skills"; ign_host "$IG" '.claude/*\n!.claude/skills/\n!.claude/skills/**\n'; out=$(sh "$BOOT" "$IG" --nested 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ -z "$(cd "$IG" && git status --porcelain --untracked-files=all)" ] && [ "$(cat "$IG/.claude/skills/commit/.gitignore")" = "*" ] \
  && ok "a host .gitignore re-including .claude/skills/** still installs clean: each skill dir hides itself with a .gitignore of *" || bad "a !.claude/skills/** host was not installed clean (rc=$rc) -- $(cd "$IG" && git status --porcelain) $out"
IE="$NI/ign-claude"; ign_host "$IE" '!CLAUDE*.md\n'; ie_before=$(ign_sig "$IE"); out=$(sh "$BOOT" "$IE" --nested 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "  - CLAUDE.local.md: re-included by .gitignore:1:!CLAUDE*.md" && [ ! -e "$IE/workflow" ] && [ "$(ign_sig "$IE")" = "$ie_before" ] \
  && ok "a host whose .gitignore re-includes CLAUDE*.md is refused, naming CLAUDE.local.md and the deciding line, with nothing written" || bad "a !CLAUDE*.md host was not refused cleanly (rc=$rc) -- $out"
IA="$NI/ign-allow"; ign_host "$IA" '*\n!*/\n!*.md\n'; ia_before=$(ign_sig "$IA"); out=$(sh "$BOOT" "$IA" --nested 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "  - workflow/: re-included by .gitignore:2:!*/" && [ ! -e "$IA/workflow" ] && [ "$(ign_sig "$IA")" = "$ia_before" ] \
  && ok "an allowlist host (* / !*/ / !*.md) is refused, naming workflow/ and the deciding line, with nothing written" || bad "an allowlist host was not refused cleanly (rc=$rc) -- $out"

# ---------------------------------------------------------------------------
echo "== Test 16: P29 nested by default -- a bare install nests (a new dir is git init-ed with a confirmed convention), a bare --update detects either layout, a bare install over an at-root workspace refuses, and contradictory flags refuse =="
newtmp ND
tree_sig() { ( cd "$1" && find . -path ./.git/objects -prune -o -print | LC_ALL=C sort; find . -path ./.git -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 cat ) | sha_stdin; }
# (a) a new, non-existent dir: git init-ed as the host, nested install, convention confirmed, status clean, no UNCONFIRMED.
NA="$ND/new/proj"; out=$(sh "$BOOT" "$NA" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -d "$NA/.git" ] && [ -d "$NA/workflow/.git" ] && [ ! -e "$NA/CLAUDE.md" ] \
    && python3 -c 'import json,sys; c=json.load(open(sys.argv[1]))["commit_convention"]; assert c["confirmed"] is True and c["coauthor_trailers"] == "allowed" and c["inferred"] is None and c["text"], c' "$NA/workflow/.agentic-nested.json" \
    && [ -z "$(cd "$NA" && git status --porcelain --untracked-files=all)" ] \
    && nxa=$(cd "$NA" && python3 workflow/scripts/workflow.py next 2>&1) && ! printf '%s\n' "$nxa" | grep -q "UNCONFIRMED"; then
  ok "a bare install into a new dir git-inits it and nests: workflow/.git, a confirmed convention (trailers allowed), a clean host status, next without UNCONFIRMED"
else bad "a bare install into a new dir did not init + nest cleanly (rc=$rc) -- $out $(cd "$NA" 2>/dev/null && git status --porcelain --untracked-files=all)"; fi
# (b) an existing git repo with one commit: nested, and its status stays clean.
NB="$ND/repo"; mkdir -p "$NB" && ( cd "$NB" && { git init -q -b main . 2>/dev/null || git init -q .; } && git config user.email smoke@example.invalid \
  && git config user.name smoke && printf 'print("app")\n' > app.py && git add -A && git commit -qm "feat: app" ) >/dev/null 2>&1 || bad "P29 probe: could not build the repo fixture"
nb_head=$(cd "$NB" && git rev-parse HEAD); out=$(sh "$BOOT" "$NB" 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ -f "$NB/workflow/.agentic-nested.json" ] && [ ! -e "$NB/CLAUDE.md" ] && [ ! -e "$NB/scripts" ] \
  && [ -z "$(cd "$NB" && git status --porcelain --untracked-files=all)" ] && [ "$(cd "$NB" && git rev-parse HEAD)" = "$nb_head" ] \
  && ok "a bare install into an existing git repo installs nested and leaves its status and HEAD unchanged" || bad "a bare install into a git repo did not nest cleanly (rc=$rc) -- $out"
# (c) a bare --update on that nested host detects it; --update --nested still works.
out=$(sh "$BOOT" "$NB" --update 2>&1); rc=$?; out2=$(sh "$BOOT" "$NB" --update --nested 2>&1); rc2=$?
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q "^Update complete (--update) at .* (nested, detected)$" && [ "$rc2" -eq 0 ] \
  && [ ! -e "$NB/workflow/workflow" ] && [ -z "$(cd "$NB" && git status --porcelain --untracked-files=all)" ] \
  && ok "a bare --update refreshes the nested install and says so (nested, detected); --update --nested still works" || bad "bare --update on a nested host failed (rc=$rc/$rc2) -- $out $out2"
# (d) a bare --update on an at-root install stays at-root and refreshes its machinery.
NR="$ND/atroot"; sh "$BOOT" "$NR" --at-root --name "At root" --summary "at-root probe" >/dev/null 2>&1 || bad "P29 probe: --at-root install failed"
printf 'stale\n' >> "$NR/.claude/skills/commit/SKILL.md"; out=$(sh "$BOOT" "$NR" --update 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$NR/workflow" ] && printf '%s\n' "$out" | grep -q "^Update complete (--update) at " && ! printf '%s\n' "$out" | grep -q "nested" \
  && diff -q "$SRC/claude/skills/commit/SKILL.md" "$NR/.claude/skills/commit/SKILL.md" >/dev/null \
  && ok "a bare --update on an at-root install stays at-root (no workflow/) and refreshes its machinery" || bad "bare --update on an at-root install misrouted (rc=$rc) -- $out"
# (e) a bare install over that at-root workspace refuses and writes nothing.
nr_before=$(tree_sig "$NR"); out=$(sh "$BOOT" "$NR" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q "already holds an at-root agentic workspace: use --update" && [ "$(tree_sig "$NR")" = "$nr_before" ] \
  && [ ! -e "$NR/workflow" ] && [ ! -e "$NR/.git" ] \
  && ok "a bare install over an at-root workspace exits 1 pointing to --update, the tree unchanged" || bad "a bare install over an at-root workspace was not refused cleanly (rc=$rc) -- $out"
# (f) contradictory flags, and a non-empty non-git dir, each exit 1.
nb_sig=$(tree_sig "$NB"); out=$(sh "$BOOT" "$NB" --update --at-root 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q -- "--at-root given, but .* holds a nested install" && [ "$(tree_sig "$NB")" = "$nb_sig" ] \
  && ok "--update --at-root on a nested host exits 1 and writes nothing" || bad "--update --at-root on a nested host was not refused (rc=$rc) -- $out"
out=$(sh "$BOOT" "$ND/flags" --at-root --nested 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q -- "--at-root and --nested are mutually exclusive" && [ ! -e "$ND/flags" ] \
  && ok "--at-root --nested exits 1" || bad "--at-root --nested was accepted (rc=$rc) -- $out"
out=$(sh "$BOOT" "$ND/flags" --force-empty-ok 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q -- "--force-empty-ok applies to the at-root install; add --at-root" && [ ! -e "$ND/flags" ] \
  && ok "--force-empty-ok without --at-root exits 1" || bad "--force-empty-ok without --at-root was accepted (rc=$rc) -- $out"
NN="$ND/plain"; mkdir -p "$NN" && printf 'notes\n' > "$NN/notes.txt"; out=$(sh "$BOOT" "$NN" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -q "is not a git repo and is not empty: run git init there first" && [ ! -e "$NN/.git" ] && [ ! -e "$NN/workflow" ] \
  && ok "a bare install into a non-empty non-git dir exits 1 and writes nothing (no .git, no workflow/)" || bad "a non-empty non-git dir was not refused cleanly (rc=$rc) -- $out"

# ---------------------------------------------------------------------------
echo "== Test 17: multi-repo host -- a fresh install over a folder of repos makes the host (one empty commit, the repo registry with per-repo conventions, the repos hidden; with no git identity it prints the commands), phase-scope reads each repo on its own, a worktree set refuses to tear down what it did not stamp and then retires clean, and --to-multi-repo converts a nested install without loss =="
# Identity comes from the environment of one call (mr), never from a git config.
mr() { env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid "$@"; }
mr_repo() { mkdir -p "$1" && ( cd "$1" && mr git init -q . && mr git symbolic-ref HEAD refs/heads/main && printf '%s\n' "$2" > "$2.txt" \
  && mr git add -A && mr git commit -qm "feat: $2" ) >/dev/null 2>&1 || bad "multi-repo probe: could not build the $2 repo"; }
# A tree's listing, its non-.git file contents and every repo's HEAD and status in it: a refusal or a dry run leaves it unchanged.
mr_sig() { ( cd "$1" && find . -name .git -prune -print -o -print | LC_ALL=C sort; find . -name .git -prune -o -type f -print0 | LC_ALL=C sort -z | xargs -0 cat; \
  find . -name .git -prune -print | while read -r g; do git -C "$(dirname "$g")" rev-parse HEAD 2>&1; git -C "$(dirname "$g")" status --porcelain 2>&1; done ) | sha_stdin; }
pjget() { python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d = d[k]
print(d)' "$1" "$2"; }
# (a) a fresh install over a folder holding only repos makes the host: its own .git, one empty commit, a registry, the repos hidden.
newtmp MR; MH="$MR/host"; mr_repo "$MH/alpha" alpha; mr_repo "$MH/beta" beta
hw() { ( cd "$MH" && mr python3 workflow/scripts/workflow.py "$@" ); }
out=$(mr sh "$BOOT" "$MH" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$MH" rev-list --count HEAD)" = 1 ] && [ "$(git -C "$MH" log -1 --format=%s)" = "chore: start the host history" ] \
    && [ -z "$(git -C "$MH" status --porcelain --untracked-files=all)" ] && grep -qx '/alpha/' "$MH/.git/info/exclude" && grep -qx '/beta/' "$MH/.git/info/exclude" \
    && python3 -c 'import json,sys; r = json.load(open(sys.argv[1]))["repos"]; assert [x["name"] for x in r] == ["alpha", "beta"], r; assert all(x["commit_convention"]["confirmed"] is False for x in r), r' "$MH/workflow/.agentic-nested.json" \
    && hw validate >/dev/null 2>&1 && hw next 2>&1 | grep -q "^repo_conventions=.*UNCONFIRMED"; then
  ok "a fresh install over a folder of two repos makes the host: its own .git with exactly one empty commit, both repos registered with unconfirmed conventions and hidden by the exclude block, a clean host status, validate passing, next flagging the repo conventions"
else bad "a fresh multi-repo install did not make the host (rc=$rc) -- $out $(git -C "$MH" log --format=%s 2>&1 | head -3)"; fi
# (b) with no git identity the install still exits 0, keeps the .git it made, commits nothing and prints the two commands.
newtmp MN; newtmp MNH; MO="$MN/host"; mr_repo "$MO/alpha" alpha; mr_repo "$MO/beta" beta
printf '[user]\n\tuseConfigOnly = true\n' > "$MNH/gitconfig"
out=$( unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL; export HOME="$MNH" GIT_CONFIG_GLOBAL="$MNH/gitconfig" GIT_CONFIG_SYSTEM=/dev/null; sh "$BOOT" "$MO" 2>&1 ); rc=$?
if [ "$rc" -eq 0 ] && [ -d "$MO/.git" ] && [ "$(git -C "$MO" rev-list --count --all)" = 0 ] \
    && printf '%s\n' "$out" | grep -qF 'git config --global user.name' && printf '%s\n' "$out" | grep -qF 'commit --allow-empty -m "chore: start the host history"'; then
  ok "with no git identity the multi-repo install exits 0, keeps the .git it made, makes no commit and prints the identity and empty-commit commands"
else bad "the no-identity multi-repo install did not degrade cleanly (rc=$rc) -- $out"; fi
# (c) phase-scope reads each repo on its own, from the anchor stamped at new-phase.
hw new-phase --phase P1 --name "Multi" --objective "probe the host" >/dev/null 2>&1 || bad "multi-repo probe: new-phase failed"
printf 'one\n' > "$MH/alpha/one.txt" && mr git -C "$MH/alpha" add one.txt >/dev/null 2>&1 && mr git -C "$MH/alpha" commit -qm "feat: one" >/dev/null 2>&1 || bad "multi-repo probe: could not commit in alpha"
sc=$(hw phase-scope P1 2>&1); sc_rc=$?; a_head=$(git -C "$MH/alpha" rev-parse --short HEAD)
[ "$sc_rc" -eq 0 ] && printf '%s\n' "$sc" | grep -q "^repo=alpha path=alpha/ .*head=$a_head .*commits=1$" && printf '%s\n' "$sc" | grep -qx '    A alpha/one.txt' \
  && printf '%s\n' "$sc" | grep -q "^repo=beta path=beta/ commits=0 " \
  && ok "phase-scope prints one block per repo: alpha holds its commit and file, beta shows no commits" || bad "multi-repo phase-scope wrong (rc=$sc_rc) -- $sc"
# (d) a worktree set: parallel-start --repo cuts a worktree per repo; teardown refuses a dirty repo worktree and a hand-made one it did not stamp, then retires the set.
git -C "$MH/workflow" add -A >/dev/null 2>&1 && mr git -C "$MH/workflow" commit -qm "chore: install and create the phase" >/dev/null 2>&1 || bad "multi-repo probe: could not commit the nested repo"
ps_out=$(hw parallel-start P1 --host-branch hb --repo alpha=feat/a --repo beta=feat/b --repo-base alpha=main --repo-base beta=main 2>&1); ps_rc=$?
PJ="$MH/workflow/works/phases/active/P1/phase.json"; WT=$(pjget "$PJ" execution.host_worktree); PB=$(pjget "$PJ" execution.branch)
wl() { git -C "$MH/alpha" worktree list; git -C "$MH/beta" worktree list; git -C "$MH" worktree list; git -C "$MH/workflow" worktree list; }
[ "$ps_rc" -eq 0 ] && [ -f "$WT/alpha/.git" ] && [ -f "$WT/beta/.git" ] && [ "$(pjget "$PJ" execution.repos.beta.branch)" = "feat/b" ] \
  && ok "parallel-start --repo cuts a worktree per repo inside the host worktree and stamps each in execution.repos" || bad "parallel-start --repo did not cut the set (rc=$ps_rc) -- $ps_out"
wl_before=$(wl); printf 'dirty\n' > "$WT/alpha/dirty.txt"
td_out=$(hw parallel-teardown P1 2>&1); td_rc=$?
[ "$td_rc" -ne 0 ] && [ "$(wl)" = "$wl_before" ] && [ -f "$WT/alpha/dirty.txt" ] \
  && ok "parallel-teardown refuses a repo worktree with uncommitted work and removes nothing" || bad "teardown did not refuse a dirty repo worktree (rc=$td_rc) -- $td_out"
rm -f "$WT/alpha/dirty.txt"
printf '/vendor/\n' >> "$MH/.git/info/exclude"   # hidden from the host worktree's status, so only the stamp can tell it from the set's own
mr git -C "$MH/alpha" worktree add -q --detach "$WT/vendor" >/dev/null 2>&1 && printf 'wip\n' > "$WT/vendor/wip.txt" || bad "multi-repo probe: could not make the hand-made worktree"
wl_before=$(wl); val_out=$(hw validate 2>&1); val_rc=$?; td_out=$(hw parallel-teardown P1 --discard-ignored 2>&1); td_rc=$?
[ "$val_rc" -eq 0 ] && printf '%s\n' "$val_out" | grep -q "^warning: .*/vendor" && [ "$td_rc" -ne 0 ] && [ "$(wl)" = "$wl_before" ] && [ -f "$WT/vendor/wip.txt" ] \
  && [ "$(pjget "$PJ" execution.repos.alpha.worktree)" != None ] \
  && ok "a hand-made worktree in the host worktree: validate warns (rc 0), teardown refuses even with --discard-ignored, its uncommitted file and every worktree list untouched" \
  || bad "the hand-made worktree was not warned about and refused (validate rc=$val_rc, teardown rc=$td_rc) -- $val_out $td_out"
{ mr git -C "$MH/alpha" worktree remove --force "$WT/vendor" && printf 'b\n' > "$WT/beta/b2.txt" && mr git -C "$WT/beta" add b2.txt \
  && mr git -C "$WT/beta" commit -qm "feat: beta work" && mr git -C "$WT/workflow" commit -q --allow-empty -m "chore(works): slice work" \
  && mr git -C "$MH/workflow" merge -q --no-ff -m "merge: the phase" "$PB"; } >/dev/null 2>&1 || bad "multi-repo probe: could not integrate the set"
td_out=$(hw parallel-teardown P1 --discard-ignored 2>&1); td_rc=$?
if [ "$td_rc" -eq 0 ] && [ ! -e "$WT" ] && [ -z "$(git -C "$MH/alpha" branch --list feat/a)" ] && [ -n "$(git -C "$MH/beta" branch --list feat/b)" ] \
    && [ "$(git -C "$MH/alpha" worktree list | wc -l | tr -d ' ')" = 1 ] && [ "$(git -C "$MH/beta" worktree list | wc -l | tr -d ' ')" = 1 ] \
    && [ "$(pjget "$PJ" execution.repos.alpha.worktree)" = None ] && [ "$(pjget "$PJ" execution.repos.beta.worktree)" = None ] && hw validate >/dev/null 2>&1; then
  ok "with the hand-made worktree gone, teardown removes the repo worktrees, nulls each stamp, deletes the created branch with no commits and keeps the one with a commit; validate passes"
else bad "the set did not retire cleanly (rc=$td_rc) -- $td_out"; fi
# (d2) a repo added mid-phase, from inside the set, is stamped on the phase branch only; the default stream's parallel-status must still list it.
{ hw new-phase --phase P2 --name "Mid" --objective "add a repo mid-phase" && git -C "$MH/workflow" add -A && mr git -C "$MH/workflow" commit -qm "chore: create the second phase" \
  && hw parallel-start P2 --host-branch hb2 --repo alpha=feat/a2 --repo-base alpha=main; } >/dev/null 2>&1 || bad "multi-repo probe: could not cut the second set"
PJ2="$MH/workflow/works/phases/active/P2/phase.json"; WT2=$(pjget "$PJ2" execution.host_worktree)
add_out=$( cd "$WT2" && mr python3 workflow/scripts/workflow.py parallel-add-repo P2 --repo beta=feat/b2 --repo-base main 2>&1 ); add_rc=$?
st_out=$(hw parallel-status 2>&1); st_rc=$?
[ "$add_rc" -eq 0 ] && ! pjget "$PJ2" execution.repos.beta >/dev/null 2>&1 && [ "$st_rc" -eq 0 ] && printf '%s\n' "$st_out" | grep -q '^  source=branch phase/P2' \
  && printf '%s\n' "$st_out" | grep -q '^  repo beta: branch=feat/b2 (created) ' \
  && ok "a repo added mid-phase (stamped on the phase branch only) is listed by the default stream's parallel-status, which reads the set's repos from the branch it reports" \
  || bad "the default stream's parallel-status lost the repo added mid-phase (add rc=$add_rc, status rc=$st_rc) -- $add_out $st_out"
# (e) --to-multi-repo: a per-repo nested install R beside a plain repo S becomes a multi-repo host at their parent, losslessly.
newtmp MC; MX="$MC/C"; MXR="$MX/R"; mr_repo "$MXR" R; mr_repo "$MX/S" S
mr sh "$BOOT" "$MXR" >/dev/null 2>&1 || bad "multi-repo probe: nested install of R failed"
rw() { ( cd "$MXR" && mr python3 workflow/scripts/workflow.py "$@" ); }
{ rw nested-convention --confirm --text "Conventional Commits, scope required" --trailers forbidden && rw new-phase --phase P1 --name "First" --objective "convert me"; } >/dev/null 2>&1 \
  || bad "multi-repo probe: R convention / new-phase failed"
printf 'two\n' > "$MXR/two.txt" && mr git -C "$MXR" add two.txt >/dev/null 2>&1 && mr git -C "$MXR" commit -qm "feat: two" >/dev/null 2>&1 && printf 'mine\n' > "$MXR/notes.txt" \
  && git -C "$MXR/workflow" add -A >/dev/null 2>&1 && mr git -C "$MXR/workflow" commit -qm "chore: install and create the phase" >/dev/null 2>&1 || bad "multi-repo probe: could not build R's history"
cp "$MXR/workflow/.agentic-nested.json" "$MC/old-marker.json"; scope_before=$(rw phase-scope P1 2>&1); sig=$(mr_sig "$MC")
out=$(mr sh "$BOOT" --to-multi-repo "$MXR" --dry-run 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$(mr_sig "$MC")" = "$sig" ] && [ ! -e "$MX/.git" ] && [ ! -e "$MX/workflow" ] \
  && ok "--to-multi-repo --dry-run exits 0 and writes nothing" || bad "--to-multi-repo --dry-run wrote or failed (rc=$rc) -- $out"
printf 'uncommitted\n' > "$MXR/workflow/scratch.md"; sig=$(mr_sig "$MC")
out=$(mr sh "$BOOT" --to-multi-repo "$MXR" 2>&1); rc=$?
[ "$rc" -eq 1 ] && [ "$(mr_sig "$MC")" = "$sig" ] && [ ! -e "$MX/.git" ] \
  && ok "--to-multi-repo on a nested repo with uncommitted work exits 1 and leaves the tree unchanged" || bad "--to-multi-repo did not refuse a dirty nested repo (rc=$rc) -- $out"
rm -f "$MXR/workflow/scratch.md"
out=$(mr sh "$BOOT" --to-multi-repo "$MXR" 2>&1); rc=$?
scope_after=$(cd "$MX" && mr python3 workflow/scripts/workflow.py phase-scope P1 --repo R 2>&1); sc_rc=$?
mk_out=$(python3 - "$MX/workflow/.agentic-nested.json" "$MC/old-marker.json" "$scope_before" "$scope_after" 2>&1 <<'PY'
import json, re, sys
new, old = (json.load(open(p)) for p in sys.argv[1:3])
def scope(text):  # the range and the files, whichever mode printed them (file names relative to the repo)
    return [re.search(r"\bbase=([0-9a-f]{7})", text).group(1), re.search(r"\bhead=([0-9a-f]{7})", text).group(1),
            re.search(r"\bcommits=(\d+)", text).group(1), sorted(re.findall(r"^\s+([AMDR]) (?:R/)?(\S+)$", text, re.M))]
assert scope(sys.argv[3]) == scope(sys.argv[4]), (scope(sys.argv[3]), scope(sys.argv[4]))
conv = {r["name"]: r["commit_convention"] for r in new["repos"]}
assert conv["R"] == old["commit_convention"], conv["R"]
assert conv["S"]["confirmed"] is False, conv["S"]
assert new["commit_convention"]["confirmed"] is False and new["commit_convention"]["inferred"] is None, new["commit_convention"]
assert len(new["converted_from"]) == 1, new.get("converted_from")
PY
); mk_rc=$?
if [ "$rc" -eq 0 ] && [ "$(git -C "$MX" rev-list --count HEAD)" = 1 ] && [ "$(git -C "$MX" log -1 --format=%s)" = "chore: start the host history" ] \
    && [ -f "$MX/workflow/.agentic-nested.json" ] && [ ! -e "$MXR/workflow" ] && [ "$mk_rc" -eq 0 ] && [ "$sc_rc" -eq 0 ] \
    && [ "$(git -C "$MXR" status --porcelain)" = "?? notes.txt" ] && (cd "$MX" && mr python3 workflow/scripts/workflow.py validate >/dev/null 2>&1); then
  ok "--to-multi-repo makes the parent a host: one empty host commit, the nested repo moved up, R's confirmed convention carried over and S unconfirmed, converted_from recorded, phase-scope P1 --repo R equal to the one before, R left with only its untracked file, validate passing"
else bad "--to-multi-repo did not convert cleanly (rc=$rc, scope rc=$sc_rc) -- $mk_out $out"; fi

# ---------------------------------------------------------------------------
echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL RETROFIT SMOKE TESTS PASSED"
  exit 0
else
  echo "$FAILS CHECK(S) FAILED"
  exit 1
fi
