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
# invariants (v36's doctrine, since lighter-rules on playwright-cli: the agent's own
# browser driven from the shell, installed, started and closed by the agent with no
# prompt (the shipped settings allow it), Claude in Chrome named once and only on the
# operator's request, in the contract, the executor body and the design/review skills),
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
# safe teardown, the lossless --to-multi-repo conversion), the P50 loop phases (the charter gate, the
# budget stop, park don't halt, the bounded rollup, the tick's resume states), the v61 skill
# directories (cores of 8 KB or less plus their reference files, on fresh, retrofit, --update and
# nested installs, a renamed skill included), the P51 PR rule v1 invariants (the pr block, pr-branch / pr-record /
# pr-check and the pass guard, validate and next, the drafts opening with no stop (no park rule: a REVIEW stop halts a run), the pr skill and
# pr-reader, the team-rule banner, the symlinked .claude/skills exclude, the root linguist-generated lines, the _is_ancestor
# regression; zero GitHub writes: a local bare origin and a stub gh), the P52 PR lifecycle invariants (pr-sync, pr-team,
# pr_open= and the archive hold, D120, pr_stack= and the base re-record, reopen-phase nested, root and multi-repo; a stub gh that
# only ever sees reads), the P66 agenda invariants (A<n>-<tail> ids, transitions all or none, the open order,
# links and the derived In progress, works/agenda.md and the index keys, validate, a two-branch merge, the gate's
# exemption for an added item), and the v31 Codex-removal negatives. Re-runnable; self-cleaning.
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
assert len(skills) == 21, len(skills)

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
# lighter-rules: do-next-slice is one slice of do-whole-phase's loop and ships no reference of its own;
# it reads do-whole-phase's by path, so no reference ships twice.
assert not any(k.startswith(".claude/skills/do-next-slice/reference/") for k in LIVE), "do-next-slice ships a reference copy"
assert ".claude/skills/do-whole-phase/SKILL.md" in LIVE[".claude/skills/do-next-slice/SKILL.md"]
for name in ("design-cowork", "do-whole-phase"):
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
model_invocable = {"design-cowork", "create-phase"}  # the pr skill carries the marker too: callers read it by path
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
                 "Say nothing about worktrees", "Relay that hint; never act on it", "## The QA-sweep route"):
    assert required in create_phase, required
# lighter-rules: doc consolidation is retired, so the docs-phase route is gone.
for gone in ("## The docs-phase route", "docs-debt", "--consolidates", "## Doc impact"):
    assert gone not in create_phase, gone
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
# Explain phases: the route lives in create-phase, the three references ship in do-whole-phase only
# (do-next-slice reads them there), and the review pointer is one fixed string everywhere.
assert "## The explain route" in create_phase and "## Explain" in create_phase
for ref in ("explain-decomposition.md", "explain-chapter.md", "explain-review.md"):
    assert f".claude/skills/do-whole-phase/reference/{ref}" in LIVE and f".claude/skills/do-next-slice/reference/{ref}" not in LIVE, ref
POINTER = "not written — run /knowledge:explain P<N> for a document, or ask it for a book"
for rel in ("claude/skills/do-whole-phase/playbooks/review.md", "claude/skills/review-phase/SKILL.md"):
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
# An explain is written from the code and the phases' records, with no research run (plugin 0.10.0+).
# The route keeps the heading, the literal unit and phases fields the plugin's readiness check reads, and
# the must-cover field; it writes no run: or mode: line, and it has a research route. A chapter's critic is
# the plugin's, on the other model family (sonnet for an Opus writer), never same-model: accepted; an
# explain executor dispatches no agent; the workspace's own explain-critic stays retired.
assert "must-cover" in create_phase and "0.10.0" in create_phase and "**A confirmed proposal.**" in create_phase
assert "- **unit**:" in create_phase and "- **phases**:" in create_phase and "- phases: P30, P33-n3" in create_phase
assert "**no `run:` line and no `mode:` line**" in create_phase
assert "- run: full" not in create_phase and "- mode: codebase" not in create_phase
assert "## The research route" in create_phase and "Research: <subject>" in create_phase
assert "--kind research --risk high" in create_phase and "**If the request carries a `Research: <subject>` block**" in create_phase
_chapter = (root / "payload/claude/skills/do-whole-phase/reference/explain-chapter.md").read_text(encoding="utf-8")
assert "knowledge:explain-critic" in _chapter and "kind: chapter" in _chapter and "trace-<key>.md" in _chapter
assert "**`model: sonnet`** when span 1 ran on an Opus model" in _chapter and "`model: opus`" in _chapter
assert "answers-<key>.md" in _chapter and "scratch: works/" not in _chapter
_decomp = (root / "payload/claude/skills/do-whole-phase/reference/explain-decomposition.md").read_text(encoding="utf-8")
assert "installed_plugins.json" in _decomp and "pages/.gitignore" in _decomp and "**0.10.0 or later**" in _decomp
assert "and dispatch no agent, `Explore` included" in (root / "payload/claude/skills/do-whole-phase/playbooks/explain.md").read_text(encoding="utf-8")
# Nothing that ships keeps the retired research machinery.
for p in [*(root / "payload").rglob("*.md"), root / "installer/payloads/doc_bodies/operations.md", root / "README.en.md"]:
    _t = p.read_text(encoding="utf-8")
    for gone in ("knowledge:web-researcher", "knowledge:code-researcher", "knowledge:gap-reviewer",
                 "knowledge:verifier", "no-research", "D0b: the preflight", "STOPPED: evidence gate",
                 "*Explain: permissions and the search cap*"):
        assert gone not in _t, (str(p), gone)
assert "**The explain carve-out" in (root / "payload/claude/skills/do-whole-phase/playbooks/explain.md").read_text(encoding="utf-8")
assert not (root / "payload/claude/agents/explain-critic.md").exists()
# v86 (P-mtrt.S3): every explain unit is a phase, created AND run after one confirmation. The route
# refuses from a phase worktree and for a book or chapter in a public project, keeps a literal `unit`
# line (absent reads as a 0.6.0 book, which still STOPs after creation), cites plugin sections with
# their headings, and declares the gate per unit; the contract carries both exceptions.
for required in ("every unit is a phase", "one confirmation", "Explain — confirm once; then it runs to publish.",
                 "start an explain from the main checkout", "`visibility: private` is absolute",
                 "The literal `unit` line", "**The required set, per unit:**", "- worktree: yes",
                 "- outline sign-off: off", "parallel-start <P>` (nested: with no `--host-branch`",
                 "in **`auto`**", "--stop-kind decision", "operator-action", "**with no `unit` line**",
                 "§9.2 *The evidence for a book (an explain phase)*", "§3.2 *Permissions, and the payload builder*",
                 "**The acceptance gate, per unit:**", "**An explain phase is the one exception:**"):
    assert required in create_phase, required
for gone in ("A single chapter is not a phase", "**A book is a phase, and this route makes one.**"):
    assert gone not in create_phase, gone
_d = (root / "payload/claude/skills/do-whole-phase/reference/decomposition.md").read_text(encoding="utf-8")
assert "declares by its unit" in _d and "explain chapter: published private; a v2 is cheap" in _d
assert "always takes `--require` (the operator reads the book)" not in _d
# v86 (P-mtrt.S5): the three explain references branch per unit. A document or chapter's DECOMP leads
# the research into `doc/` and cuts one S1; the evidence gate is a typed stop; the gate waives per unit;
# S1's critic is `kind: document` (none under quick); the review proves a document private on its own
# route and falls back to an API read-back; the merge back is pointed to, not restated.
_review = (root / "payload/claude/skills/do-whole-phase/reference/explain-review.md").read_text(encoding="utf-8")
for _txt, _pins in (
    (_decomp, ("## A document or a chapter", "works/phases/active/P<N>/doc/", "doc/pages/.gitignore",
               "--kind implementation --risk high --order 10", "## Run stops (every unit)",
               "feedback re-runs DECOMP from the dossier", "explain document: published private; a v2 is cheap",
               "outline sign-off: on", "under `## The book`", "§3.4 *D1: the evidence*", "`## Drawn from`")),
    (_chapter, ("## A document or a chapter: its one write slice", "mode: critique · kind: document",
                "`doc/answers.md`", "works/phases/active/P<N>/doc/body.md")),
    (_review, ("## Plan a document's or a chapter's review", "/api/documents/by-path/<rel_path>",
               "/app/orgs/<org>/<project>/<slug>", "**Otherwise, the API read-back,**", "A chapter's order check",
               "§8 *D9: the report*", "§9.1 *The book suggestion*", "(*An explain phase merges back by itself*)",
               "`book/research/answers-<key>.md`", "every `## Gaps` line of `doc/evidence.md`")),
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
for name in ("do-whole-phase",):
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
        "Mockup: requested",
        "design-only, no mockup: the operator signed each job on its canvas",
        # v43: a phase runs on this checkout unless the operator asks for a worktree;
        # the do-* skills never start one on their own initiative, and a hint is relayed,
        # not acted on. Merged back locally; the branch review records its two gate
        # sections as tagged notes.
        "unless the operator asked for a worktree", "parallel-start <P>", "EnterWorktree",
        "`parallel-start` on your own initiative", "## Gate sections (written at merge)", "git merge --no-ff",
        # v35: just-in-time reads and the bounded notebook.
        "finish-slice <slice_id> --outcome", "bounded phase notebook",
        "verdict block", "just in time",
        # v36: the research kind routes high by KIND (the DECOMP2 sequel lives in playbooks/decompose.md).
        "`research` and review always",
        # The entry-level notebook: the orchestrator reads it through phase-section only, runs the
        # required step's notebook_move= lines before the next dispatch, and keeps the breakdown in a topic.
        "never with `Read`, `Edit` or `Write`", "`notebook_over_budget=`",
        "run each `notebook_move=` line under it, prefixed `python3 scripts/workflow.py`",
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
    for required in ("--kind fix --risk <low|high>`",
                     "work the mid row got wrong never goes back to it"):
        assert required in body, (name, required)
    for gone in ("one-line/few-line", "one-line, or few-line"):
        assert gone not in body, (name, gone)

# The multi-phase skill is retired: one session per phase. /do-whole-phases ships no more, and
# do-whole-phase says where the next phase starts.
assert "do-whole-phases" not in skills, sorted(skills)
assert not any(k.startswith(".claude/skills/do-whole-phases/") for k in LIVE), "do-whole-phases still ships"
_dwp = (root / "payload/claude/skills/do-whole-phase/SKILL.md").read_text(encoding="utf-8")
assert "**one session per phase.**" in _dwp and "do-whole-phases" not in _dwp

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
assert "`finish-slice <P>.DECOMP` refuses while a middle slice is undeclared" in decomp
_pbd = (root / "payload/claude/skills/do-whole-phase/playbooks/decompose.md").read_text(encoding="utf-8")
for required in ("their sets (files, regenerated files, numbered sequences, runtime resources) are disjoint",
                 "never on `DECOMP2`, `REVIEW` or a `co-work` slice"):
    assert required in _pbd, ("decompose.md", required)
_rel = ".claude/skills/do-whole-phase/reference/explain-decomposition.md"
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
    # v36: the doctrine names an instrument. lighter-rules: the instrument is playwright-cli,
    # the agent's own browser it installs, restarts and closes itself; only what it cannot have stops.
    "**With what — the instrument.**",
    "Drive that browser with **`playwright-cli`** (`@playwright/cli`),",
    "**The browser is never a blocker: the agent runs it whole.**",
    "`npm install -g @playwright/cli@0.1.25`",
    "`playwright-cli install-browser chrome-for-testing`",
    "`playwright-cli kill-all`",
    "`playwright-cli state-save <file>`",
    "Only what the agent cannot have stops a run: a credential, a sign-in, a paid account.",
    "**How to call it.** Call it plainly",
    "send a password's `fill` output to `/dev/null`",
    # v37: what the doctrine rejects is the pre-written suite, not the library --
    # what differs is who picks the next action.
    "in place of a pre-written assertion suite",
    "**Why the executor drives, and not a pre-written suite.**",
    "deciding every check in advance",
    "**`playwright-cli`** is the instrument, the agent's own",
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
for rel in ("claude/skills/do-whole-phase/reference/decomposition.md", "claude/skills/do-whole-phase/playbooks/decompose.md"):
    _t = (root / "payload" / rel).read_text(encoding="utf-8")
    for gone in ("one job per surface", "a wave of about 3–4 jobs", "each slice's jobs with their critique level"):
        assert gone not in _t, (rel, gone)
_t = (root / "payload/claude/skills/do-whole-phase/playbooks/decompose.md").read_text(encoding="utf-8")
assert "each co-work slice's one job with its critique level" in _t and "co-work slice's jobs with their critique levels" not in _t
_t = (root / "payload/claude/skills/do-whole-phase/SKILL.md").read_text(encoding="utf-8")
assert "stops `pending` once per round" in _t and "once per wave" not in _t
assert "is its spans:** one drafter per job at once" not in skill_dir_text("do-whole-phase")
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
                 "### Page rules (`pass: page <slug>`)", "### Join rules (`pass: join`)",
                 # P47-p5.F1: the frame's fixture covers every entity a page shows, lists or links to; an entity
                 # it lacks is a frame gap; the join opens each in-round entity's own drawn item.
                 "every named entity a page shows, lists or links to (every row's destination, every linked item)",
                 "an entity the fixture lacks included", "a link to an entity of this round opens that entity's own drawn item"):
    assert required in drafter, required
assert "the shared fixture (every entity a page shows, lists or links to, with its figures)" in design, "drafting.md frame pass: fixture coverage"
# P47-p5.F2: drafting.md states the shipped critique default and the one measured round, defers the
# critic row's effort to executor-route, and no shipped file names a phase-internal round or an
# xhigh critic row (D-q0ba).
for required in ("**The level is `off` unless the operator asks for a critic**",
                 "**One measured round, not a norm**", "16 spans, $71.50, 3 h 43 min wall clock",
                 "cost $19.90, 28 % of the round", "cost $28.60", "`executor-route --critic` and `--judge` print"):
    assert required in design, ("drafting.md critique default / cost", required)
for _f in sorted((root / "payload").rglob("*")):
    if _f.is_file() and _f.suffix in (".md", ".py", ".toml", ".json", ".yml"):
        _t = _f.read_text(encoding="utf-8")
        for gone in ("live per-page round", "that phase's review", "`xhigh` by default since v66", "Opus @ xhigh by default"):
            assert gone not in _t, (str(_f), gone)
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
                 "They are `high`-confidence facts either way, never argued away by taste.",
                 # P47-p5.F1: the page critic names an entity outside the fixture; the cross critic checks coverage.
                 "an entity outside the fixture included, is a Part 1 must-fix**",
                 "**fixture coverage**: every link to an entity of this round lands on that entity's own drawn item"):
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
_w = " ".join((root / "payload/claude/skills/do-whole-phase/reference/worktree.md").read_text(encoding="utf-8").split())
_c = (root / "payload/claude/skills/do-whole-phase/SKILL.md").read_text(encoding="utf-8")
assert "**One exception: an explain phase (v86).**" in _w
assert "merge_ready=" in _w and "merge_ready=" in _c and "(an explain: its confirmation asked)" in _c
_ww = " ".join((root / "payload/claude/skills/do-whole-phase/reference/worktree.md").read_text(encoding="utf-8").split())
for required in ("**An explain phase merges back by itself, with no stop.**", "**When the automatic merge cannot run**",
                 "**The closing report** of an explain run comes last", "`parallel-teardown <P> --discard-ignored`"):
    assert required in _ww, required

# v32 review procedure: the gate stages, the returned walkthrough, and the two
# workflow commands a review slice must never run.
review = (root / "payload/claude/skills/review-phase/SKILL.md").read_text()
for required in ("## The review, in order", "`walkthrough`", "`## Operator Runtime`", "`## Regression Checklist`",
                 # v36: the review opens the product with the prescribed instrument (lighter-rules:
                 # playwright-cli, against no pre-written suite, its procedure by reference).
                 "**Drive it with `playwright-cli`**",
                 "in place of a pre-written assertion suite", "with the same instrument",
                 "The procedure in full: `design-cowork`'s `reference/build.md`.",
                 # v41: the review reviews the boundary of the phase, never the whole system --
                 # phase-scope is its input, and stage 4 re-runs the checklist inside it.
                 "## The boundary", "phase-scope <P>",
                 # v42: a branch review records its two gate sections as tagged notes, and
                 # the mockup qualifier applies only where the operator asked for one.
                 "## Gate sections (written at merge)", "a phase in which the operator asked for one",
                 "Re-run the checklist lines inside the boundary",
                 "an operator-created QA phase, never by a review",
                 # P42.S4 (v71): a finding is a whole problem class, so one round finds every case.
                 "**A finding is a problem class, not an instance.**",
                 # The entry-level notebook: a decision is present as a gist line plus its topic, and a
                 # dangling pointer is a lost decision.
                 "A decision counts as present when its gist line is in `## Decisions` and its detail is in the linked topic",
                 "A dangling-pointer warning from `validate`"):
    assert required in review, required
# P42.S4 (v71): a second failure of the same rules stops for the operator instead of another fix round,
# in both loops' review references (separate files, so each exact path is read).
assert "**Stop instead of another round.**" in (root / "payload/claude/skills/do-whole-phase/reference/review.md").read_text(encoding="utf-8")
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
# v36: one seed field records the agent's instrument (lighter-rules: playwright-cli), and a
# saved sign-in the agent state-loads; the Chrome deviceId field is retired.
assert "- Browser instrument for the agent: playwright-cli (`@playwright/cli`" in ops
assert "- Saved sign-in: <path of a `playwright-cli state-save` file the operator makes once" in ops
assert "deviceId" not in ops and "Claude in Chrome" not in ops
for gone in ("Aside", "aside repl", "aside mcp", "aside account"):
    assert gone not in ops, gone
qa = (root / "installer/payloads/doc_bodies/qa.md").read_text()
assert "## Regression Checklist" in qa
assert "- [ ] <surface>: <one observable behaviour> (P<N>)" in qa
# v41: the seed says the list is re-run inside the phase's boundary, never whole by a review.
assert "phase-scope <P>" in qa and "re-runs the whole list" not in qa

# v66: one executor, slice-executor, replaces the mid/high pair; its frontmatter carries the mid row.
# lighter-rules: the executor is a card of at most 3,072 B (the floor, the playbook map, done means
# proven, the notebook, the verdict); how each kind of work goes lives in one playbook per kind under
# .claude/skills/do-whole-phase/playbooks/ (1-3 KB each), opened only for that kind. The engine reads
# the card's frontmatter (sync-agents, executor-route), so that stays pinned.
assert not (root / "payload/claude/agents/slice-executor-mid.md").exists()
assert not (root / "payload/claude/agents/slice-executor-high.md").exists()
body = (root / "payload/claude/agents/slice-executor.md").read_text(encoding="utf-8")
fm = body.split("---\n", 2)[1]
assert "name: slice-executor\n" in fm and "model: opus\n" in fm and "effort: medium\n" in fm, fm
assert "permissionMode: bypassPermissions\n" in fm, fm
# The browser is playwright-cli over Bash, so the executor carries no Chrome tools; Agent stays (the review's code reader).
assert "tools: Read, Edit, Write, Glob, Grep, Bash, WebSearch, WebFetch, Agent\n" in fm, fm
assert len(body.encode("utf-8")) <= 3072, f"the executor card is {len(body.encode('utf-8'))} B, over its 3,072 B cap"
for gone in ("Codex", ".agents/", ".codex/", "AGENTS.md", "## Doc impact", "docs phase", "slice-executor-mid", "- `tier`"):
    assert gone not in body, gone
for required in ("The contract's four invariants hold", "You never commit or push",
                 "`done` | `escalate` | `needs_operator`", "`blocked`", "- `route`, `model`, `effort`:",
                 "Only the mid and screen rows escalate", "Stop the servers, containers and browsers you started",
                 "`playwright-cli`", "leave it when the slice needs to", "`## Wave`", "`phase-section`"):
    assert required in body, required
# Every playbook the card's map names exists and is 1-3 KB, every kind of the engine's closed set has
# one, and no playbook sits unnamed; the folder is inside a skill, so it ships and is managed like one.
_pb_dir = root / "payload/claude/skills/do-whole-phase/playbooks"
_map = body.split("## Your playbook", 1)[1].split("\n## ", 1)[0]
_named = sorted(set(re.findall(r"`([a-z][a-z-]*\.md)`", _map)) - {"plan.md", "intent.md"})
for _n in _named:
    assert (_pb_dir / _n).is_file(), f"the card names a missing playbook: {_n}"
    assert 1024 <= len((_pb_dir / _n).read_bytes()) <= 3072, (_n, len((_pb_dir / _n).read_bytes()))
assert sorted(p.name for p in _pb_dir.glob("*.md")) == _named, ("a playbook the card never names", _named)
_kinds = re.search(r"^SLICE_KINDS = \{(.*)\}$", (root / "payload/scripts/workflow.py").read_text(encoding="utf-8"), re.M).group(1)
for _k in re.findall(r'"([a-z-]+)"', _kinds):
    assert re.search(r"(?<![\w-])" + re.escape(_k) + r"(?![\w-])", _map), f"kind {_k} has no playbook in the card's map"
assert (root / "payload/claude/skills/design-cowork/reference/mockup.md").is_file()
_pb = {p.stem: p.read_text(encoding="utf-8") for p in _pb_dir.glob("*.md")}
for _stem, _required in (
    ("feature", ("you saw fail first", "`playwright-cli`", "`doc-new-version`")),
    ("fix", ("**problem class**", "Every case of the class")),
    ("investigation", ("**write no product code.**", "**where the next slice reads them**", "`DECOMP2`")),
    ("review", ("`phase-scope <P>`", "`subagent_type: code-reader`", "never the plan, a result or the notebook",
                "in the same span", "**Carve-out.** Never edit source.")),
    ("verify", ("`npm install -g @playwright/cli@0.1.25`", "`playwright-cli install-browser chrome-for-testing`",
                "Only what you cannot have (a credential, a sign-in, a paid account) is `needs_operator`.", "Stop what you start")),
    ("decompose", ("**Finish line first:**", "no QA slice by default", "`new-slice", "parallel-plan <P>", "`spends money: no`",
                   "each co-work slice's one job with its critique level", "A fractional `--order`")),
    ("wave", ("**Write no `phase.md`.**", "**Run no engine command that writes**", "`deferred: whole-tree`")),
    ("cycle", ("binds **absolutely**", "`need_scope: spend`", "`item_verdict: fail`", "never repeat a filing")),
    ("explain", ("**The explain carve-out.**", "and dispatch no agent, `Explore` included")),
):
    for _r in _required:
        assert _r in _pb[_stem], (_stem, _r)
# lighter-rules: the phase-flow skills are short playbooks. Each folder's shipped bytes (explain references
# aside, which are the explain phase's) stay under its cap, and the set under 85,000 B; no shipped skill file
# is a byte copy of another (a reference ships once).
_caps = {"do-whole-phase": 49000, "do-next-slice": 2500, "create-phase": 12500, "review-phase": 12000,
         "read-code": 3600, "executor-route": 1500, "commit": 2800}
_size = lambda n: sum(len(v.encode("utf-8")) for k, v in LIVE.items()
                      if k.startswith(f".claude/skills/{n}/") and not k.rsplit("/", 1)[1].startswith("explain-"))
for _n, _cap in _caps.items():
    assert _size(_n) <= _cap, (_n, _size(_n), _cap)
assert sum(_size(_n) for _n in _caps) <= 85000, sum(_size(_n) for _n in _caps)
_seen = {}
for _k, _v in LIVE.items():
    if _k.startswith(".claude/skills/"):
        assert _v not in _seen, ("a skill file shipped twice", _seen.get(_v), _k)
        _seen[_v] = _k
# The review has one source: review-phase holds the procedure, its executor dispatches the blind code reader
# itself and stops what the phase left running; the orchestrator's side points at it and dispatches no reader.
_rv = (root / "payload/claude/skills/review-phase/SKILL.md").read_text(encoding="utf-8")
_ro = (root / "payload/claude/skills/do-whole-phase/reference/review.md").read_text(encoding="utf-8")
for _r in ("**The code reader is yours to dispatch**", "`subagent_type: code-reader`", "Never the plan, a result, the notebook or a phase id.",
           "**Nothing the phase started is left running.**", "**One review per phase**", "Run the walkthrough"):
    assert _r in _rv, _r
assert "dispatched by the review executor itself" in _ro and "`review-phase` skill" in _ro
for _gone in ("## The code reader, before the review", "executor-route --code"):
    assert _gone not in _ro, _gone
# Doc consolidation is retired: no phase-flow skill asks for a Doc impact note or a docs phase.
for _n in _caps:
    _txt = "\n".join(v for k, v in LIVE.items() if k.startswith(f".claude/skills/{_n}/") and "/explain-" not in k)
    for _gone in ("docs phase", "docs-phase", "docs-debt", "doc_impact", "doc_versions", "Doc impact list"):
        assert _gone not in _txt.replace("Ask for no `## Doc impact` note and no docs phase.", ""), (_n, _gone)
# Nothing but the six shipped agents sits in payload/claude/agents/ (every .md there becomes an agent).
assert sorted(p.name for p in (root / "payload/claude/agents").iterdir()) == sorted(
    k.rsplit("/", 1)[1] for k in collect_live_payloads() if k.startswith(".claude/agents/")), "a non-agent file in payload/claude/agents/"
# The readers are cards: the code reader stays blind, reproduces first, states problems never fixes, and
# is dispatched by the review's executor; the pr-reader runs on request only.
_cr = (root / "payload/claude/agents/code-reader.md").read_text(encoding="utf-8")
assert len(_cr.encode("utf-8")) <= 3072, len(_cr.encode("utf-8"))
for _r in ("**Blind by design.**", "**Reproduce before you report.**", "**State a problem and its effect, never a fix.**",
           "**One findings file**", "Dispatched once per phase by the review's executor"):
    assert _r in _cr, _r
_prr = (root / "payload/claude/agents/pr-reader.md").read_text(encoding="utf-8")
assert len(_prr.encode("utf-8")) <= 2048, len(_prr.encode("utf-8"))
assert "run on request only: when the operator asks, or for a team repo with PR rules" in _prr
assert "You run on request only" in _prr and "never a fix" in _prr

# lighter-rules: no shipped agent carries the Claude in Chrome tools (the browser is playwright-cli
# over Bash), and the shipped sources name Claude in Chrome exactly once: the line saying it is used
# only when the operator asks an agent to use their own browser. Its retired machinery is gone.
for _f in sorted((root / "payload/claude/agents").glob("*.md")):
    _fm = _f.read_text().split("---\n", 2)[1]
    assert "mcp__claude-in-chrome" not in _fm, _f.name
_cic = []
for _base in ("payload", "installer/payloads", "docs", "README.md", "README.en.md"):
    _b = root / _base
    for _f in ([_b] if _b.is_file() else sorted(_b.rglob("*"))):
        if _f.is_file():
            _t = _f.read_text(encoding="utf-8", errors="replace")
            _cic += [(str(_f.relative_to(root)), ln) for ln in _t.splitlines() if re.search(r"claude.in.chrome", ln, re.I)]
            for _gone in ("deviceId", "select_browser", "list_connected_browsers", "**third** halt", "third halt"):
                assert _gone not in _t, (str(_f.relative_to(root)), _gone)
assert len(_cic) == 1 and _cic[0][0] == "payload/contract.md" \
    and "Claude in Chrome is used only when the operator asks an agent to use their own browser" in _cic[0][1], _cic
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
# lighter-rules: the explain review reads the book in playwright-cli, signed in from a saved state file.
_er = (root / "payload/claude/skills/do-whole-phase/reference/explain-review.md").read_text(encoding="utf-8")
assert "**The instrument** is `playwright-cli`, the agent's own browser" in _er
assert "`state-load`s the manifest's saved sign-in file" in _er

# v53 (P32.S3): the Explore agent's final body, and no Agent tool on it (it never nests).
explore = (root / "payload/claude/agents/Explore.md").read_text()
explore_fm = explore.split("---\n", 2)[1]
assert "tools: Read, Grep, Glob\n" in explore_fm and "omitClaudeMd: true\n" in explore_fm
assert "Agent" not in [ln for ln in explore_fm.splitlines() if ln.startswith("tools:")][0]
for required in ("not read / possibly stale", "Never recommend, judge, decide, edit or run anything",
                 "needs judgment"):
    assert required in explore, required

# One contract file now, so nothing to compare it against: assert the whole text.
# lighter-rules cut the contract to one screen (<= 4,096 B, <= 60 lines): the operator's four
# invariants, the named principles, the correction ladder, a rule table whose every row names its
# enforcer, and pointers. The process rules it used to carry live in the skills, the executor card and
# `workflow.py --help`, and are asserted there.
claude = (root / "payload/contract.md").read_text()
for required in (
    # The four invariants the operator signed (2026-11-20), each exactly once.
    "**Nothing is pushed, merged or paid for without the operator's word.**",
    "**A sign-off is the operator's literal words**",
    "**The operator's own work is never touched:**",
    "**Reports are truthful:**",
    # The named principles the operator steers with, and the correction ladder.
    "**Prove it works:**", "**Subtract before you add:**", "**Settle by a run:**", "**Finish line first:**",
    "**Stop what you start:**", "**Take your own recommendation:**", "**Ask, don't archive:**",
    "**The correction ladder:** fix a repeated mistake in product code first, then a type or lint, then a test or check, and only last in a rule file.",
    # The rule table, its operator-facing rows and the browser line (Claude in Chrome named once).
    "| Rule | Enforced by |", "`accept-gate <P> --clear`", "`## Operator Questions`",
    "Real-browser checks run on `playwright-cli`, the agent's own headless browser.",
    "Claude in Chrome is used only when the operator asks an agent to use their own browser.",
    # The pointers: commands, playbooks, the code reader among the agents, the three skills named.
    "`python3 scripts/workflow.py --help`", "`.claude/skills/`", "`.claude/agents/slice-executor.md`", "`code-reader`",
    "`create-phase`", "`design-cowork`", "`type(scope): summary`",
):
    assert claude.count(required) == 1, required
assert "never fan out slices" not in claude, "the contract still forbids fanning out slices"
# Subtract before you add: the shipped CLAUDE.md is this file byte for byte, and it stays on one screen.
assert len((root / "payload/contract.md").read_bytes()) <= 4096, "the contract is over its 4,096 B cap"
assert len(claude.splitlines()) <= 60, "the contract is over 60 lines"
# Doc consolidation is retired: the contract asks for no Doc impact note and no docs phase.
for gone in ("## Doc impact", "docs phase", "Docs are versioned durable truth", "doc-new-version"):
    assert gone not in claude, gone
# Every rule-table row names its enforcer: a cited engine command, settings rule, CI step or smoke check.
_rows = [ln for ln in claude.splitlines() if ln.startswith("| ") and not ln.startswith("| Rule")]
assert len(_rows) >= 10 and all(ln.count(" | ") == 1 and ln.split(" | ")[1].strip(" |") for ln in _rows), _rows
# Workspace sync: every skill step that commits workflow state skips that commit in a linked checkout,
# and the stream and agenda skills say what a linked checkout does.
cloud_skip = ("In a linked checkout (`next` prints `store=cloud`), skip this commit: hi2vi's revisions"
              " are the workflow's history. Product commits are unchanged.")
for rel in ("commit/SKILL.md", "create-phase/SKILL.md", "run-loop/SKILL.md", "rotate-backlog/SKILL.md",
            "do-whole-phase/reference/verdicts.md", "do-whole-phase/reference/wave.md"):
    assert cloud_skip in (root / "payload/claude/skills" / rel).read_text(), f"{rel}: the cloud-mode commit skip"
# A linked checkout's waiting-commit record: every place that defines "a done slice whose slice.json is
# uncommitted is a commit that waits" (and every commit step that closes one) names its linked form.
cloud_waits = ("In a linked checkout, a done slice whose commit waits is one `next` lists in `commits_waiting=`;"
               " run `mark-committed <slice>` after its product commit (with no product change, right after its finish).")
for rel, n in (("commit/SKILL.md", 1), ("run-loop/SKILL.md", 1), ("run-loop/reference/checkpoint.md", 1),
               ("rotate-backlog/SKILL.md", 1),
               ("do-whole-phase/reference/verdicts.md", 1), ("do-whole-phase/reference/wave.md", 1)):
    assert (root / "payload/claude/skills" / rel).read_text().count(cloud_waits) == n, f"{rel}: the linked waiting-commit sentence x{n}"
# update-workspace never stages the truth set of a linked checkout: its clean check and its commit name the update's own paths.
uw = (root / "payload/claude/skills/update-workspace/SKILL.md").read_text()
for pin in ("`git -C workflow status --porcelain -- . ':(exclude)works' ':(exclude)docs'`",
            "`git -C workflow add -A -- . ':(exclude)works' ':(exclude)docs' && git -C workflow add -A -- works/templates works/.workspace-version.json`"):
    assert pin in uw, f"update-workspace: the linked-checkout pin {pin}"
assert "A linked checkout (`next` prints `store=cloud`) refuses `parallel-start`" in (root / "payload/claude/skills/parallel-phase/SKILL.md").read_text()
assert "In a linked checkout, changes made on the web arrive as inbox entries" in (root / "payload/claude/skills/agenda/SKILL.md").read_text()
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
for gone in ("design exception", "never approval", "no other pending gate"):
    assert gone not in claude, gone
for gone in ("Codex", "AGENTS.md", ".agents/", ".codex/"):
    assert gone not in claude, gone
# v61 (P37.S9): Compact Instructions keep the resume card and carry no re-read instruction.
compact = claude.split("## Compact Instructions", 1)[1]
assert "resume card" in compact and "never re-dispatch a running executor" in compact
assert "re-read" not in compact, "Compact Instructions carry a re-read instruction"
PY
then ok "21 Claude skills and their invocation metadata; the v61 skill directories (cores of 8,192 B or less, every reference a core names shipped and none orphaned, the shared do-* reference one source); the prose invariants of the do-*, create-phase, design-cowork (the one drafter tool and its legacy rule, styles, the schema-2 canvas loop with one connected canvas per round and opt-in critique, mockups on request, the playwright-cli instrument), parallel-phase (worktree only when asked, hints relayed) and review-phase skills and of both executor bodies; the v71 wave protocol (do-whole-phase's reference/wave.md, DECOMP's disjoint-sets rule, the executor's wave section, the contract's reversal of "never fan out slices"); the one-screen contract (at most 4,096 B and 60 lines: the four invariants once each, the named principles, the correction ladder, a rule table whose every row names its enforcer, the playwright-cli line with Claude in Chrome named once, no doc-consolidation duty); the seed docs; and the v31 Codex-removal negatives"; else bad "Claude skill inventory or metadata, a do-*/create-phase/design-cowork/parallel-phase/review-phase prose invariant, an executor-body invariant, a one-screen contract pin, a seed-doc invariant, or a Codex-removal negative failed"; fi

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
for rule in ("Bash(playwright-cli:*)", "Bash(npm install -g @playwright/cli:*)", "Bash(npm i -g @playwright/cli:*)"):
    assert rule in allow, rule
assert allow[0] == "Bash(make:*)", allow
assert d.get("env", {}).get("FOO") == "bar", "unrelated key lost"
PY
then ok "settings.json additively merged (custom perm + env survive; the playwright-cli and its npm install rules added)"; else bad "settings.json merge incorrect"; fi
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
[ "$(find "$R/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "21" ] \
  && ok "retrofit installs the 21-skill Claude inventory" || bad "retrofit skill inventory incomplete"
skill_tree_ok "$R/.claude/skills" exact \
  && ok "retrofit installs every skill as its whole directory: each core's reference files, none orphaned, the shared do-* copy identical" || bad "retrofit skill directories incomplete (core + reference/)"
grep -qF "Nothing is pushed, merged or paid for without the operator's word." "$R/CLAUDE.workspace.md" && grep -qF '| Rule | Enforced by |' "$R/CLAUDE.workspace.md" \
  && grep -qF 'product visual design follows `design-cowork`' "$R/CLAUDE.workspace.md" \
  && ok "retrofit sidecar carries the contract: the invariants, the rule table and the design-cowork pointer" || bad "retrofit sidecar contract is incomplete"

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
# lighter-rules: the agent's browser runs with no prompt -- the CLI and its self-install are allowed.
python3 -c 'import json,sys; a=json.load(open(sys.argv[1]))["permissions"]["allow"]; assert all(r in a for r in ("Bash(playwright-cli:*)","Bash(npm install -g @playwright/cli:*)","Bash(npm i -g @playwright/cli:*)")), a' "$F/.claude/settings.json" \
  && ok "a fresh at-root install allows Bash(playwright-cli:*) and both npm install rules" || bad "fresh install settings.json lacks the playwright-cli allow rules"
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
[ -f "$F/.claude/skills/read-code/SKILL.md" ] && [ -f "$F/.claude/agents/code-reader.md" ] && grep -q '`code-reader`' "$F/CLAUDE.md" \
  && ok "fresh install ships the read-code skill and the code-reader agent, and its contract points at the code-reader" || bad "fresh install missing the read-code skill, the code-reader agent or the contract's pointer to it"
[ "$(find "$F/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')" = "21" ] \
  && ok "fresh install has the 21 Claude skills" || bad "fresh skill inventory incomplete"
skill_tree_ok "$F/.claude/skills" exact \
  && ok "fresh install ships every skill as its whole directory: each core's reference files, none orphaned" || bad "fresh install skill directories incomplete (core + reference/)"
[ ! -f "$F/AGENTS.md" ] && [ ! -d "$F/.agents" ] && [ ! -d "$F/.codex" ] \
  && ok "fresh install is Codex-free (no AGENTS.md, no .agents/, no .codex/)" || bad "fresh install still ships Codex machinery"
[ -f "$F/.claude/agents/slice-executor.md" ] && [ ! -e "$F/.claude/agents/slice-executor-mid.md" ] && [ ! -e "$F/.claude/agents/slice-executor-high.md" ] \
  && ok "fresh install ships the one slice-executor (v66), not the retired mid/high pair" || bad "fresh install: slice-executor.md missing or the retired pair present"
# lighter-rules: the executor's kind playbooks ship inside the do-whole-phase skill (never under .claude/agents/,
# where every .md becomes an agent), and .claude/agents/ holds exactly the six shipped agents.
[ -f "$F/.claude/skills/do-whole-phase/playbooks/feature.md" ] && [ -f "$F/.claude/skills/do-whole-phase/playbooks/review.md" ] \
  && [ "$(cd "$F/.claude/agents" && LC_ALL=C ls | tr '\n' ' ')" = "Explore.md code-reader.md design-critic.md design-drafter.md pr-reader.md slice-executor.md " ] \
  && ok "fresh install ships the kind playbooks under .claude/skills/do-whole-phase/playbooks/ and only the six agents in .claude/agents/" \
  || bad "fresh install: playbooks missing, or a file other than the six agents in .claude/agents/ ($(ls "$F/.claude/agents" | tr '\n' ' '))"
# lighter-rules: on a fresh install too, the phase-flow skills (explain references aside) stay under 85,000 B
# and no skill file is a byte copy of another (do-next-slice reads do-whole-phase's references by path).
if python3 - "$F/.claude/skills" <<'PY'
import sys
from pathlib import Path
base = Path(sys.argv[1])
size = lambda n: sum(len(p.read_bytes()) for p in (base / n).rglob("*") if p.is_file() and not p.name.startswith(("explain-", ".")))
total = sum(size(n) for n in ("do-whole-phase", "do-next-slice", "create-phase", "review-phase", "read-code", "executor-route", "commit"))
assert total <= 85000, total
seen = {}
for p in sorted(base.rglob("*")):
    if p.is_file() and not p.name.startswith("."):
        b = p.read_bytes()
        assert b not in seen, ("shipped twice", seen.get(b), str(p))
        seen[b] = str(p)
PY
then ok "fresh install: the phase-flow skills total at most 85,000 B and no skill file ships twice"; else bad "fresh install: the phase-flow skills are over 85,000 B or a skill file ships twice"; fi
grep -q '^model: opus$' "$F/.claude/agents/slice-executor.md" && grep -q '^effort: medium$' "$F/.claude/agents/slice-executor.md" \
  && grep -q '^name: slice-executor$' "$F/.claude/agents/slice-executor.md" \
  && grep -q '^model: fable$' "$F/.claude/agents/design-drafter.md" && grep -q '^effort: high$' "$F/.claude/agents/design-drafter.md" \
  && [ -f "$F/.claude/agents/Explore.md" ] && grep -q '^model: haiku$' "$F/.claude/agents/Explore.md" \
  && grep -q '^effort: xhigh$' "$F/.claude/agents/Explore.md" && grep -qx 'tools: Read, Grep, Glob' "$F/.claude/agents/Explore.md" \
  && ok "fresh install follows the route defaults: slice-executor carries mid opus@medium, design-drafter fable@high, explore haiku@xhigh" || bad "fresh install agent files do not follow the route defaults"
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
  && grep -q '^model: fable$' "$F/.claude/agents/design-drafter.md" && grep -q '^effort: high$' "$F/.claude/agents/design-drafter.md" \
  && grep -q '^model: haiku$' "$F/.claude/agents/Explore.md" && grep -q '^effort: xhigh$' "$F/.claude/agents/Explore.md" \
  && grep -q '^model: opus$' "$F/.claude/agents/design-critic.md" && grep -q '^effort: high$' "$F/.claude/agents/design-critic.md" \
  && ok "no executors.toml: sync-agents writes the route defaults (slice-executor mid opus@medium, design-drafter fable@high, design-critic opus@high, Explore haiku@xhigh)" \
  || bad "the route defaults matrix is wrong"
printf '[claude.high]\nmodel = "fable"\n' > "$F/executors.toml"
sa_out=$( cd "$F" && python3 scripts/workflow.py sync-agents 2>&1 ); er_out=$(er P1.DECOMP)
printf '%s\n' "$sa_out" | grep -q 'already in sync; nothing written' && grep -q '^model: opus$' "$F/.claude/agents/slice-executor.md" \
  && grep -q '^model: fable$' "$F/.claude/agents/design-drafter.md" \
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
  && printf '%s\n' "$er_out" | grep -qE '^design +design-drafter +fable +high +default$' \
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
  && printf '%s\n' "$er_out" | grep -qx 'model=fable' && printf '%s\n' "$er_out" | grep -qx 'effort=high' \
  && ok "executor-route --drafter names design-drafter on its own design row (no tier= line, fable@high)" || bad "executor-route --drafter wrong: $er_out"
# v96: a phase's `Drafter:` line under intent.md's ## Design Style picks the drafter's model at the design row's
# effort; no line is the design row; behind a loopback proxy (no Fable) a Fable drafter falls back to opus.
cp "$F/works/phases/active/P1/intent.md" "$F/intent.bak"
er_out=$(er --drafter --phase P1)
printf '%s\n' "$er_out" | grep -qx 'model=fable' && printf '%s\n' "$er_out" | grep -qx 'drafter_source=design row' \
  && ok "executor-route --drafter --phase on a phase naming no drafter is the design row (fable)" || bad "executor-route --drafter --phase default wrong: $er_out"
printf '\n## Design Style\n\nbuild-after: one flow.\nMockup: on request\nDrafter: opus\n' >> "$F/works/phases/active/P1/intent.md"
er_out=$(er --drafter --phase P1)
printf '%s\n' "$er_out" | grep -qx 'model=opus' && printf '%s\n' "$er_out" | grep -qx 'drafter_source=phase P1 Drafter: opus' \
  && ok "a phase's Drafter: opus keeps Opus against the Fable default" || bad "executor-route --drafter --phase opus wrong: $er_out"
cp "$F/intent.bak" "$F/works/phases/active/P1/intent.md"
printf '\n## Design Style\n\nbuild-after: one flow.\nMockup: on request\nDrafter: fable\n' >> "$F/works/phases/active/P1/intent.md"
er_out=$(er --drafter --phase P1)
printf '%s\n' "$er_out" | grep -qx 'model=fable' && printf '%s\n' "$er_out" | grep -qx 'effort=high' \
  && printf '%s\n' "$er_out" | grep -qx 'attribution=Claude Fable 5.2' && printf '%s\n' "$er_out" | grep -qx 'drafter_source=phase P1 Drafter: fable' \
  && ok "a phase's Drafter: fable dispatches the drafter on fable at the design row's effort" || bad "executor-route --drafter --phase fable wrong: $er_out"
er_out=$( cd "$F" && env -u CLAUDE_CODE_EFFORT_LEVEL -u CLAUDE_CODE_SUBAGENT_MODEL_FORCE ANTHROPIC_BASE_URL=http://127.0.0.1:10100 python3 scripts/workflow.py executor-route --drafter --phase P1 2>&1 )
printf '%s\n' "$er_out" | grep -qx 'model=opus' && printf '%s\n' "$er_out" | grep -q '^fallback=design model fable -> opus ' \
  && ok "behind a loopback proxy a Fable drafter falls back to opus" || bad "executor-route --drafter proxy fallback wrong: $er_out"
er_c=$(er --critic --phase P1); er_crc=$?
[ "$er_crc" -ne 0 ] && printf '%s\n' "$er_c" | grep -q 'goes with --drafter only' \
  && ok "--phase without --drafter is refused" || bad "executor-route --critic --phase not refused (rc=$er_crc): $er_c"
sed 's/^Drafter: fable$/**Drafter:** fable/' "$F/works/phases/active/P1/intent.md" > "$F/intent.tmp" && mv "$F/intent.tmp" "$F/works/phases/active/P1/intent.md"
er_out=$(er --drafter --phase P1)
printf '%s\n' "$er_out" | grep -qx 'model=fable' \
  && ok "a bold **Drafter:** label is read, never dropped for its form" || bad "executor-route --drafter dropped a bold Drafter: line: $er_out"
sed 's/^\*\*Drafter:\*\* fable$/Drafter: haiku/' "$F/works/phases/active/P1/intent.md" > "$F/intent.tmp" && mv "$F/intent.tmp" "$F/works/phases/active/P1/intent.md"
er_out=$(er --drafter --phase P1); er_rc=$?
[ "$er_rc" -ne 0 ] && printf '%s\n' "$er_out" | grep -q "names the drafter 'haiku'" \
  && ok "a Drafter: other than fable or opus is refused" || bad "executor-route --drafter accepted Drafter: haiku (rc=$er_rc): $er_out"
{ cat "$F/intent.bak"; printf '\n### Design style notes\n\nfrom the brief.\n\n## Design Style\n\nDrafter: fable\n'; } > "$F/works/phases/active/P1/intent.md"
er_out=$(er --drafter --phase P1)
printf '%s\n' "$er_out" | grep -qx 'model=fable' \
  && ok "an earlier '### Design style' subsection never hides the real section's Drafter: line" || bad "executor-route --drafter lost the real Design Style section: $er_out"
mv "$F/intent.bak" "$F/works/phases/active/P1/intent.md"
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
grep -q 'never a session-\$ figure' "$SRC/claude/skills/do-whole-phase/reference/decomposition.md" \
  && grep -q 'spends money:' "$SRC/claude/skills/do-whole-phase/playbooks/decompose.md" && ! grep -q '\$ per span' "$SRC/claude/skills/do-whole-phase/playbooks/decompose.md" \
  && grep -q 'a DECOMP estimates time from these' "$SRC/scripts/workflow.py" \
  && ok "a DECOMP estimates time only and writes a per-slice spends-money line (the orchestrator reference, the decompose playbook, the [means] header)" || bad "the DECOMP time-only / spends-money wording is missing or a session-\$ estimate remains"
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
rm -f "$F/.claude/skills/design-cowork/reference/shape.md"
# lighter-rules: do-next-slice ships no reference of its own after v100; a copy left at a retired path is the
# workspace's (RETIRED_FILES), so an edited one reads "differs from what v100 shipped", never "not shipped".
mkdir -p "$F/.claude/skills/do-next-slice/reference" && printf 'my edit\n' > "$F/.claude/skills/do-next-slice/reference/review.md"
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
skill_tree_ok "$F/.claude/skills" exact \
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
         'AGENTS\.workspace\.md  (differs from what v30 shipped)' '\.claude/skills/executor-mode/SKILL\.md  (differs from what v52 shipped)' \
         '\.claude/skills/do-next-slice/reference/review\.md  (differs from what v100 shipped)'; do
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
# lighter-rules: an --update of an adopter whose allow list predates the browser rules (its own entry
# first) adds the three playwright-cli rules and keeps the adopter's entry.
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["permissions"]["allow"]=["Bash(make:*)"]+[x for x in d["permissions"]["allow"] if "playwright" not in x]; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$F/.claude/settings.json"
sh "$BOOT" "$F" --update >/dev/null 2>&1
python3 -c 'import json,sys; a=json.load(open(sys.argv[1]))["permissions"]["allow"]; assert a[0]=="Bash(make:*)" and all(r in a for r in ("Bash(playwright-cli:*)","Bash(npm install -g @playwright/cli:*)","Bash(npm i -g @playwright/cli:*)")), a' "$F/.claude/settings.json" \
  && ok "--update adds the playwright-cli allow rules to an adopter's settings.json and keeps its own entry" || bad "--update did not carry the playwright-cli allow rules"
cp "$SRC/claude/settings.json" "$F/.claude/settings.json"   # drop the probe's foreign handler before the Test 6 diff
rm -f "$F/.github/workflows/workspace-ci.yml" "$F/.gitattributes"
sh "$BOOT" "$F" --update >/dev/null 2>&1   # restore both verbatim for the Test 6 diff
[ ! -f "$F/.claude/agents/phase-reviewer.md" ] && ok "phase-reviewer retired (absent on fresh install)" || bad "phase-reviewer should be retired but is present"
[ -d "$F/.claude/skills/do-whole-phase" ] && ok "fresh install keeps do-whole-phase" || bad "do-whole-phase skill missing"
[ ! -e "$F/.claude/skills/do-whole-phases" ] && ok "fresh install ships no do-whole-phases skill (one session per phase)" || bad "fresh install still ships the do-whole-phases skill"
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
[ "$nskill" -eq 21 ] && ok "dual-apply covers all 21 skill bodies" || bad "expected 21 SKILL.md files to diff, found $nskill"
for rel in $skill_rels; do
  diff -q "$SRC/${rel#.}" "$F/$rel" >/dev/null \
    && ok "dual-apply: $rel" \
    || bad "DRIFT: $rel differs from the bootstrap-embedded copy"
done
DUAL_FIXED=".claude/agents/slice-executor.md
.claude/agents/design-drafter.md
.claude/agents/design-critic.md
.claude/agents/pr-reader.md
.claude/agents/code-reader.md
.claude/agents/Explore.md
.claude/settings.json
executors.toml
works/templates/deferred_brief.md
works/templates/intent.md
works/templates/phase.md
works/templates/charter.md
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
grep -q 'Rebuilt at' "$F/works/backlog.md" "$F/works/deferred.md" "$F/works/agenda.md" \
  && bad "a markdown dashboard still carries a Rebuilt at timestamp" || ok "no Rebuilt at timestamp in any markdown dashboard (backlog, deferred, agenda)"
# The churn this removes: repeated `next` calls must not dirty the three dashboards.
( cd "$F" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
    && git -c user.email=smoke@example.invalid -c user.name=smoke commit -qm "smoke baseline" >/dev/null 2>&1 )
( cd "$F" && python3 scripts/workflow.py next >/dev/null 2>&1; python3 scripts/workflow.py next >/dev/null 2>&1 )
tracked=$( cd "$F" && git ls-files works/backlog.md works/deferred.md works/agenda.md | wc -l | tr -d ' ' )
dirty=$( cd "$F" && git status --short -- works/backlog.md works/deferred.md works/agenda.md )
[ "$tracked" = "3" ] && [ -z "$dirty" ] \
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
outside=$(printf '%s\n' $conflicted | grep -vxE 'works/(state\.json|index\.json|backlog\.md|deferred\.md|agenda\.md)')
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
echo "== Test 10i: agenda -- items, ids, transitions, order, links, the generated page, validate, two branches (the gate's exemption for an added item: Test 12) =="
# A fresh --at-root install. Items live in works/agenda/<AID>/agenda.json; works/agenda.md, index.json's
# agenda keys and the backlog's count are generated from them; an item never moves `next`.
newtmp AGW; AG="$AGW/ws"
sh "$BOOT" "$AG" --at-root --name "Agenda" --summary "agenda probe" >/dev/null 2>&1 || bad "agenda probe: fresh install failed"
ag() { ( cd "$AG" && python3 scripts/workflow.py "$@" ); }
ag_tree() { ( cd "$AG" && find works -type f ! -name '*.md' ! -name index.json ! -name state.json | LC_ALL=C sort | while read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done ); }
ag_items() { ( cd "$AG/works/agenda" && for f in */agenda.json; do printf '%s %s\n' "$f" "$(sha "$f")"; done ); }
ag_key() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], "<absent>"))' "$AG/works/agenda/$1/agenda.json" "$2"; }
ag_order() { ag agenda --json | python3 -c 'import json,sys; print(" ".join(i["id"] for i in json.load(sys.stdin)))'; }
tail_re='([a-hjkmnp-tv-z][0-9a-hjkmnp-tv-z]|[0-9][a-hjkmnp-tv-z])'
# (a) the generated page and the index, before any item and after: stable bytes, the keys, the backlog line.
pg0=$(sha "$AG/works/agenda.md" 2>/dev/null); rm -f "$AG/works/agenda.md"; sleep 1  # a stamp would move with the clock
ag rebuild >/dev/null 2>&1; pg1=$(sha "$AG/works/agenda.md" 2>/dev/null)
ag_idx() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(not ("agenda_counts" in d and "agenda" in d))' "$AG/works/index.json"; }
[ -n "$pg0" ] && [ "$pg0" = "$pg1" ] && ag_idx && grep -qxF -e '- Open agenda items: `0`' "$AG/works/backlog.md" \
  && ok "a fresh install has works/agenda.md with no item, byte-identical across rebuilds; index.json has agenda_counts and agenda; backlog.md says Open agenda items: 0" \
  || bad "the empty agenda page or index keys missing -- [$pg0] [$pg1] $(grep -F 'agenda' "$AG/works/backlog.md")"
# (b) ids: A1-<tail> first, its own number sequence, an explicit tailed id once, brief forms.
a1=$(ag agenda-add --title "first" 2>&1 | sed -n 's/^added \(A[^:]*\):.*/\1/p')
a2=$(ag agenda-add --title "second" 2>&1 | sed -n 's/^added \(A[^:]*\):.*/\1/p')
p1=$(ag new-phase --name "Plain" --objective probe 2>&1 | sed -n 's/^created phase \(P[^:]*\):.*/\1/p')
d1=$(ag defer-job --title plain --reason r --trigger t --source manual 2>&1 | sed -n 's/^created deferred job \(D[^:]*\):.*/\1/p')
ex1=$(ag agenda-add --id A13-n1 --title "thirteen" 2>&1); ex2=$(ag agenda-add --id A13-n1 --title "again" 2>&1); ex2_rc=$?
ag agenda-edit 1 --title "first, by 1" >/dev/null 2>&1; ag agenda-edit A2 --title "second, by A2" >/dev/null 2>&1
printf '%s\n' "$a1" | grep -qxE "A1-$tail_re" && printf '%s\n' "$a2" | grep -qxE "A2-$tail_re" \
  && printf '%s\n' "$p1" | grep -qxE "P1-$tail_re" && printf '%s\n' "$d1" | grep -qxE "D1-$tail_re" \
  && [ "$ex1" = "added A13-n1: thirteen" ] && [ "$ex2_rc" -ne 0 ] && [ "$(printf '%s\n' "$ex2" | wc -l | tr -d ' ')" = 1 ] \
  && [ "$(ag_key "$a1" title)" = "first, by 1" ] && [ "$(ag_key "$a2" title)" = "second, by A2" ] \
  && ok "agenda-add mints A1-<tail> then A2-<tail> and spends no phase or deferred number (P1-, D1- next); --id A13-n1 is taken once and refused in one line after; 1 and A2 name their items" \
  || bad "agenda ids wrong -- $a1 / $a2 / $p1 / $d1 / $ex1 / $ex2"
# (c) transitions: defer, solve with an outcome, reopen, drop with a reason, reopen (both cleared);
# a refused transition is one line and non-zero; a bulk call with one bad id writes nothing.
st=""
for step in "agenda-defer $a2" "agenda-solve $a2 --outcome shipped" "agenda-reopen $a2" "agenda-drop $a2 --reason dup" "agenda-reopen $a2"; do
  ag $step >/dev/null 2>&1 || st="$st [refused: $step]"
  st="$st $(ag_key "$a2" status)/$(ag_key "$a2" outcome)/$(ag_key "$a2" reason)"
done
rf=$(ag agenda-reopen "$a1" 2>&1); rf_rc=$?
tr0=$(ag_tree); bk=$(ag agenda-defer A13 A99-zz 2>&1); bk_rc=$?; tr1=$(ag_tree)
[ "$st" = " deferred/None/None solved/shipped/None open/None/None dropped/None/dup open/None/None" ] \
  && [ "$rf_rc" -ne 0 ] && [ "$(printf '%s\n' "$rf" | wc -l | tr -d ' ')" = 1 ] \
  && [ "$bk_rc" -ne 0 ] && [ "$tr0" = "$tr1" ] && [ "$(ag_key A13-n1 status)" = open ] \
  && ok "defer, solve --outcome, reopen, drop --reason, reopen (outcome and reason cleared); reopening an Open item is refused in one line; agenda-defer A13 A99-zz changes nothing" \
  || bad "agenda transitions wrong -- $st / $rf / $bk"
uo=$(ag agenda-add --title x --bogus 2>&1); uo_rc=$?; tr2=$(ag_tree)
[ "$uo_rc" -eq 2 ] && [ "$(printf '%s\n' "$uo" | wc -l | tr -d ' ')" = 1 ] && [ "$tr1" = "$tr2" ] \
  && ok "an unknown option on an agenda command (agenda-add --bogus) is one line, exit 2, nothing written" \
  || bad "an unknown agenda option is not one line and exit 2 (rc=$uo_rc) -- $uo"
# (d) order: the newest item first, a reopened item last, a move rewrites only the moved item's file.
o1=$(ag_order); it0=$(ag_items); ag agenda-move A13 --last >/dev/null 2>&1; it1=$(ag_items)
moved=$(diff <(printf '%s\n' "$it0") <(printf '%s\n' "$it1") | sed -n 's/^> \([^/]*\)\/.*/\1/p' | tr '\n' ' ')
[ "$o1" = "A13-n1 $a1 $a2" ] && [ "$moved" = "A13-n1 " ] && [ "$(ag_order)" = "$a1 $a2 A13-n1" ] \
  && ok "a new item lists first and a reopened one last ($o1); agenda-move --last rewrites only the moved item's agenda.json" \
  || bad "agenda order wrong -- $o1 / moved: $moved / $(ag_order)"
# (e) links: new-phase --agenda links and the item reads In progress; a second item cannot take that phase;
# no agenda command changes `next`; agenda-delete clears the link and the phase stays, with no agenda key.
p2=$(ag new-phase --name "Linked" --objective probe --agenda 1 2>&1 | sed -n 's/^created phase \(P[^:]*\):.*/\1/p')
nx1=$(ag next 2>&1); lk=$(ag agenda-link 2 --phase "$p2" 2>&1); lk_rc=$?
shown=$(ag agenda 2>&1 | grep "^$a1 ")
ag agenda-add --title "noise" >/dev/null 2>&1; ag agenda-defer 14 >/dev/null 2>&1; ag agenda-move A13 --first >/dev/null 2>&1; nx2=$(ag next 2>&1)
dl=$(ag agenda-delete "$a1" 2>&1); dl_rc=$?; nx3=$(ag next 2>&1)
pj="$AG/works/phases/active/$p2/phase.json"
[ -n "$p2" ] && [ "$lk_rc" -ne 0 ] && printf '%s\n' "$shown" | grep -q 'In progress' \
  && [ "$nx1" = "$nx2" ] && [ "$nx2" = "$nx3" ] \
  && [ "$dl_rc" -eq 0 ] && [ -f "$pj" ] && ! grep -q '"agenda"' "$pj" && [ ! -d "$AG/works/agenda/$a1" ] \
  && ok "new-phase --agenda links $p2 and $a1 reads In progress; a second item cannot take it ($lk); agenda commands leave next unchanged; agenda-delete clears the link and the phase stays with no agenda key" \
  || bad "agenda links wrong -- $p2 / $lk / $shown / $dl / next changed: $([ "$nx1" = "$nx2" ] && [ "$nx2" = "$nx3" ] && echo no || echo yes)"
grep -qxF -e '- Open agenda items: `2`' "$AG/works/backlog.md" && [ "$(sha "$AG/works/agenda.md")" != "$pg0" ] \
  && ok "the backlog counts Open and In progress items, never Deferred ones (2), and works/agenda.md follows the items" \
  || bad "the backlog count or the agenda page did not follow -- $(grep -F 'agenda' "$AG/works/backlog.md")"
# (f) validate: a `Z` stamp (JavaScript's toISOString form) passes on every Python, 3.9 and 3.10 included
# (the engine reads its own stamp form, never fromisoformat); a dangling link is a warning (validate passes);
# a corrupt agenda.json leaves rebuild at 0 and fails validate, naming the folder.
z_dir=$(cd "$AG/works/agenda" && ls -d A*-* | grep -vx 'A13-n1' | head -n 1)
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["changed_at"]="2026-11-17T10:00:00.123Z"; open(p,"w").write(json.dumps(d, indent=2)+"\n")' "$AG/works/agenda/$z_dir/agenda.json"
z_val=$(ag validate 2>&1); z_rc=$?
[ -n "$z_dir" ] && [ "$z_rc" -eq 0 ] && ! printf '%s\n' "$z_val" | grep -q "agenda/$z_dir" \
  && ok "an agenda item whose changed_at ends in Z (2026-11-17T10:00:00.123Z) passes validate on $(python3 -V 2>&1)" \
  || bad "a Z changed_at failed validate on $(python3 -V 2>&1) -- $z_dir / $z_rc -- $(printf '%s\n' "$z_val" | grep -i agenda)"
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["agenda"]="A77-zz"; open(p,"w").write(json.dumps(d, indent=2)+"\n")' "$pj"
v1=$(ag validate 2>&1); v1_rc=$?
printf '{' > "$AG/works/agenda/A13-n1/agenda.json"
rb=$(ag rebuild 2>&1); rb_rc=$?; v2=$(ag validate 2>&1); v2_rc=$?
[ "$v1_rc" -eq 0 ] && printf '%s\n' "$v1" | grep -q "^warning: .*$p2.*A77-zz" \
  && [ "$rb_rc" -eq 0 ] && [ "$v2_rc" -ne 0 ] && printf '%s\n' "$v2" | grep -q 'works/agenda/A13-n1' \
  && ok "a dangling agenda link is a validate warning (exit 0); a corrupt agenda.json leaves rebuild at 0 and fails validate naming works/agenda/A13-n1" \
  || bad "agenda validate wrong -- $v1_rc / $rb_rc / $v2_rc -- $(printf '%s\n' "$v1" "$v2" | grep -i agenda)"
# A hand-edited field can hold any JSON value: a list-valued status leaves rebuild and next at 0 (no traceback)
# and fails validate, naming the folder and the key.
ls_dir=$(cd "$AG/works/agenda" && ls -d A*-* | grep -vx 'A13-n1' | head -n 1)
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["status"]=[1]; open(p,"w").write(json.dumps(d, indent=2)+"\n")' "$AG/works/agenda/$ls_dir/agenda.json"
ls_rb=$(ag rebuild 2>&1); ls_rb_rc=$?; ls_nx=$(ag next 2>&1); ls_nx_rc=$?; ls_v=$(ag validate 2>&1); ls_v_rc=$?
[ -n "$ls_dir" ] && [ "$ls_rb_rc" -eq 0 ] && [ "$ls_nx_rc" -eq 0 ] && [ "$ls_v_rc" -ne 0 ] \
  && printf '%s\n' "$ls_v" | grep -q "works/agenda/$ls_dir: status \[1\]" && ! printf '%s\n' "$ls_rb" "$ls_nx" "$ls_v" | grep -q Traceback \
  && ok "a list-valued agenda status leaves rebuild and next at exit 0 and fails validate naming works/agenda/$ls_dir" \
  || bad "a list-valued agenda status broke a read or passed validate -- $ls_dir / $ls_rb_rc / $ls_nx_rc / $ls_v_rc -- $(printf '%s\n' "$ls_rb" "$ls_nx" "$ls_v" | grep -iE 'agenda|Traceback|Error' | tail -3)"
# The same item is refused as unusable, in one line naming its file and agenda-delete, never "reopen it first" (which
# would be refused too); nothing is written. A13-n1 goes first: every agenda command reads every item.
rm -rf "$AG/works/agenda/A13-n1"; ls_t0=$(ag_tree); ls_df=$(ag agenda-defer "$ls_dir" 2>&1); ls_df_rc=$?
[ -n "$ls_dir" ] && [ "$ls_df_rc" -eq 1 ] && [ "$(printf '%s\n' "$ls_df" | wc -l | tr -d ' ')" = 1 ] \
  && printf '%s\n' "$ls_df" | grep -qF "works/agenda/$ls_dir/agenda.json" && printf '%s\n' "$ls_df" | grep -qF "agenda-delete $ls_dir" \
  && ! printf '%s\n' "$ls_df" | grep -q reopen && [ "$(ag_tree)" = "$ls_t0" ] \
  && ok "agenda-defer of an item with a list-valued status is refused in one line naming works/agenda/$ls_dir/agenda.json and agenda-delete, not reopen; nothing written" \
  || bad "an unusable agenda status is refused without its file or way out -- rc=$ls_df_rc -- $(printf '%s\n' "$ls_df" | head -2 | cut -c1-240)"
# (g) two branches each add an item: the merge conflicts in generated files only, and either side + rebuild lists both.
newtmp AGB; AB="$AGB/ws"; sh "$BOOT" "$AB" --at-root --name "Agenda" --summary "agenda branches" >/dev/null 2>&1 || bad "agenda probe: second install failed"
ab() { ( cd "$AB" && python3 scripts/workflow.py "$@" ); }
abg() { git -C "$AB" -c user.email=smoke@example.invalid -c user.name=smoke "$@"; }
( abg init -q && abg add -A && abg commit -qm base \
  && abg checkout -q -b one && ab agenda-add --id A1-ab --title one && abg add -A && abg commit -qm one \
  && abg checkout -q - && abg checkout -q -b two && ab agenda-add --id A1-ac --title two && abg add -A && abg commit -qm two ) >/dev/null 2>&1 \
  || bad "agenda two-branch probe: setup failed"
abg merge -q --no-edit one >/dev/null 2>&1; ab_conf=$(abg diff --name-only --diff-filter=U | tr '\n' ' ')
ab_out=$(printf '%s\n' $ab_conf | grep -vxE 'works/(state\.json|index\.json|backlog\.md|deferred\.md|agenda\.md)')
( for f in $ab_conf; do abg checkout --theirs -- "$f" || exit 1; done; ab rebuild && abg add -A && abg commit -qm merge ) >/dev/null 2>&1
ab_val=$(ab validate 2>&1); ab_rc=$?
[ -n "$ab_conf" ] && [ -z "$ab_out" ] && [ "$ab_rc" -eq 0 ] && [ -z "$(abg status --porcelain)" ] \
  && [ "$(ab agenda 2>&1 | grep -cE '^A1-a[bc] ')" = 2 ] && grep -q 'A1-ab' "$AB/works/agenda.md" && grep -q 'A1-ac' "$AB/works/agenda.md" \
  && ok "two branches each add an item (A1-ab, A1-ac) and merge with conflicts only in generated files ($ab_conf); either side + rebuild lists both, valid and clean" \
  || bad "agenda two-branch merge wrong -- conflicted: $ab_conf / outside: $ab_out / $ab_val"

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
# F2: it prints the pathspec it read with, paste-ready after `--` (a guessed `.` would list works/), the same in
# --json and from the phase-less `phase-scope --pathspec` that /read-code runs.
p3_spec=$(printf '%s\n' "$scope_out" | sed -n 's/^pathspec=//p')
p3_diff=$( cd "$F" && eval "git diff --name-only $p3_created^ HEAD -- $p3_spec" 2>&1 )
p3_json=$( cd "$F" && python3 scripts/workflow.py phase-scope P3 --json 2>/dev/null | python3 -c 'import json, shlex, sys; print(json.load(sys.stdin)["pathspec"] == shlex.split(sys.argv[1]))' "$p3_spec" 2>&1 )
[ "$p3_spec" = ". ':!works' ':!docs'" ] && [ "$p3_diff" = "src/probe.py" ] && [ "$p3_json" = True ] \
  && [ "$( cd "$F" && python3 scripts/workflow.py phase-scope --pathspec 2>&1 )" = "pathspec=$p3_spec" ] \
  && ok "phase-scope prints pathspec=, which pasted after -- lists only the product file; --json and phase-scope --pathspec carry the same value" \
  || bad "phase-scope pathspec= missing or wrong (spec=$p3_spec json=$p3_json) -- $p3_diff"
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
# (a) the stamp commit is exactly the phase folder + (a subset of) the six works files
stamp_files=$( cd "$W" && git show --name-only --format= HEAD )
if python3 - "$stamp_files" <<'PY'
import sys
files = set(sys.argv[1].split())
six = {"works/state.json", "works/index.json", "works/backlog.md", "works/deferred.md", "works/agenda.md", "works/events.jsonl"}
phase = {f for f in files if f.startswith("works/phases/active/P1/")}
assert "works/phases/active/P1/phase.json" in phase and "works/index.json" in files, files
assert files == phase | (files & six), files
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
# P66: a branch that only adds an agenda item (plus the regenerated works/ files) keeps the exemption.
( cd "$wt" && git checkout -q -b probe/agenda && python3 scripts/workflow.py agenda-add --title "gate probe" && git add -A works \
    && git commit -qm "probe: an agenda item" && git checkout -q phase/P1-worktree_probe ) >/dev/null 2>&1 || bad "P66 probe: could not cut the agenda branch"
g_out=$( cd "$W" && python3 scripts/workflow.py parallel-gate P1 --branch-ref probe/agenda 2>&1 ); g_rc=$?
[ "$g_rc" -eq 0 ] && printf '%s\n' "$g_out" | grep -q "^exemption=phase-folder-only (" \
  && ok "a branch that only adds an agenda item keeps the exemption: the gate opens on a busy default stream" \
  || bad "an added agenda item lost the exemption (rc=$g_rc) -- $g_out"
# P66: a phase created inside the worktree is that stream's own (the default side does not hold it): it unlinks there.
# (on the phase branch itself, where the stream is; the probe's files are then dropped from the clean worktree).
born_out=$( cd "$wt" && aid=$(python3 scripts/workflow.py agenda-add --title "born probe" | sed -n 's/^added \([^:]*\):.*/\1/p') \
    && python3 scripts/workflow.py new-phase --phase P9 --name "Born here" --objective "made in the worktree" --agenda "$aid" >/dev/null 2>&1 \
    && python3 scripts/workflow.py agenda-unlink --phase P9 2>&1; rc=$?; git checkout -q -- works && git clean -fdq works; exit $rc ); born_rc=$?
[ "$born_rc" -eq 0 ] && printf '%s\n' "$born_out" | grep -q "^unlinked P9 from A" \
  && ok "a phase created inside the worktree is that stream's own: agenda-unlink applies there" \
  || bad "the worktree refused its own new phase's link (rc=$born_rc) -- $born_out"
# P66: a phase that was there at the cut stays another stream's after the default side removes it (ownership is
# read from the cut, never from the default side as it is now): the worktree refuses, writes nothing, names no command.
# Its own small fixture: this test's P2 was never committed before P1's cut.
newtmp GW
sh "$BOOT" "$GW" --at-root --name "Gone" --summary "gone probe" >/dev/null 2>&1 || bad "P66 gone probe: fresh install failed"
gone_out=$( cd "$GW" && git init -q -b main . && git config user.email smoke@example.invalid && git config user.name smoke \
    && python3 scripts/workflow.py new-phase --phase P1 --name "Par" --objective "o" >/dev/null 2>&1 \
    && python3 scripts/workflow.py new-phase --phase P2 --name "Gone" --objective "o" >/dev/null 2>&1 \
    && git add -A >/dev/null 2>&1 && git commit -qm "baseline" && python3 scripts/workflow.py parallel-start P1 >/dev/null 2>&1 \
    && git rm -rq works/phases/active/P2 && python3 scripts/workflow.py rebuild >/dev/null 2>&1 && git add -A && git commit -qm "drop P2" \
    && cd .claude/worktrees/P1-par && aid=$(python3 scripts/workflow.py agenda-add --title "gone probe" | sed -n 's/^added \([^:]*\):.*/\1/p') \
    && { python3 scripts/workflow.py agenda-link "$aid" --phase P2 2>&1; rc=$?; git diff --quiet -- works/phases/active/P2 || rc=99; exit $rc; } ); gone_rc=$?
[ "$gone_rc" -eq 1 ] && printf '%s\n' "$gone_out" | grep -q "^agenda-link refused, nothing was written: P2 has been removed from the default checkout" \
  && ! printf '%s\n' "$gone_out" | grep -q "workflow.py agenda-" \
  && ok "a phase there at the cut and removed on the default side since stays another stream's: the worktree refuses its link" \
  || bad "the worktree took a link into a phase the default side removed after the cut (rc=$gone_rc) -- $gone_out"
# P66: a workspace installed --at-root in a subfolder of its repo reads the cut from the repo's top (git ls-tree takes
# its path relative to the working directory unless --full-tree): its worktree refuses a link into a phase of the cut.
newtmp GS
subf_out=$( cd "$GS" && git init -q -b main . && git config user.email smoke@example.invalid && git config user.name smoke \
    && echo product > README && git add README && git commit -qm "product" && sh "$BOOT" "$GS/sub" --at-root --name "Sub" --summary "subfolder probe" >/dev/null 2>&1 \
    && cd sub && python3 scripts/workflow.py new-phase --phase P1 --name "Par" --objective "o" >/dev/null 2>&1 \
    && python3 scripts/workflow.py new-phase --phase P2 --name "Stay" --objective "o" >/dev/null 2>&1 \
    && git add -A >/dev/null 2>&1 && git commit -qm "baseline" && python3 scripts/workflow.py parallel-start P1 >/dev/null 2>&1 \
    && cd .claude/worktrees/P1-par/sub && aid=$(python3 scripts/workflow.py agenda-add --title "subfolder probe" | sed -n 's/^added \([^:]*\):.*/\1/p') \
    && { python3 scripts/workflow.py agenda-link "$aid" --phase P2 2>&1; rc=$?; git diff --quiet -- works/phases/active/P2 || rc=99; exit $rc; } ); subf_rc=$?
[ "$subf_rc" -eq 1 ] && printf '%s\n' "$subf_out" | grep -q "^agenda-link refused, nothing was written: P2 runs on the default stream; in the default checkout (.*/sub, branch main) run: " \
  && ok "a workspace in a subfolder of its repo reads the cut from the repo's top: its worktree refuses a link into a phase of the cut" \
  || bad "a subfolder workspace's worktree took a link into a phase of the cut (rc=$subf_rc) -- $subf_out"
( cd "$W" && git branch -q -D probe/extra probe/agenda && python3 scripts/workflow.py set-phase-status P2 planned >/dev/null 2>&1 ) || bad "v86 probe: could not reset the probe"
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
# list exempts a Page from check=unlinked-page; check=token-drift and check=transition-all warn; v90 (P47-p5.F3):
# a calc(var()) radius is token-derived (silent) and a padding px only an fs- token holds gets no suggestion.
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
(project / "frame.css").write_text(":root { --ink: #1a1a1a; --radius-md: 6px; --space-4: 16px; --fs-14: 14px; }\n")
(project / "ListRow.dc.html").write_text(head + '<style>.row { color: #1A1A1A; border: 1px solid var(--ink); padding: 16px; '
    'border-radius: 50%; transition: all .2s; } .cap { border-radius: calc(var(--radius-md) - 1px); padding: 14px; } '
    '[data-proto="state-bar"] { background: #ff0000; }</style>\n<p class="row">row</p>\n')
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
    && ! printf '%s\n' "$ex" | grep -Fq -e '#ff0000' -e '50%' -e 'calc(' -e 'fs-14' \
    && printf '%s\n' "$ex" | grep -Fq 'ListRow.dc.html: transition: all (check=transition-all)'; then
  ok "join.json's unrelated list exempts a Page from check=unlinked-page (a reached one warns); check=token-drift names raw values a token names, allowing 1px borders, %, [data-proto] chrome and a calc(var()) radius and suggesting no cross-role token; check=transition-all warns"
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
printf '%s\n' "$scope_out" | grep -qx "pathspec=. ':(exclude)workflow'" && [ "$(nw phase-scope --pathspec 2>&1)" = "pathspec=. ':(exclude)workflow'" ] \
  && ok "nested phase-scope and phase-scope --pathspec print the host pathspec: the nested workflow/ folder excluded, the host's docs/ kept" \
  || bad "nested pathspec= line missing or wrong -- $scope_out"
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
mkdir -p "$NH/.claude/agents" && cp "$SRC/claude/agents/slice-executor.md" "$SRC/claude/agents/design-critic.md" "$SRC/claude/agents/pr-reader.md" "$SRC/claude/agents/code-reader.md" "$SRC/claude/agents/Explore.md" "$NH/.claude/agents/" \
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
  && ok "nested: the clashing design-cowork installs as wf-design-cowork with its reference/ files, the do-whole-phase references ship, the host's own design-cowork is untouched, and the host stays clean" \
  || bad "nested: a renamed split skill or its reference files were not installed cleanly -- $(cd "$IH" && git status --porcelain)"
left=$(cd "$IH" && grep -rlF "python3 scripts/workflow.py" .claude CLAUDE.local.md workflow/CLAUDE.workspace.md workflow/works/templates 2>/dev/null)
[ -z "$left" ] && grep -rqF "python3 workflow/scripts/workflow.py" "$IH/.claude/skills/do-whole-phase" "$IH/.claude/settings.local.json" \
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
a = d["permissions"]["allow"]
assert all(r in a for r in ("Bash(playwright-cli:*)", "Bash(npm install -g @playwright/cli:*)", "Bash(npm i -g @playwright/cli:*)")), a
PY
then ok "nested: settings.local.json carries only the resume hook with the workflow/scripts/workflow.py command path and window 500000, allows playwright-cli and its npm install, and --update --nested kept exactly one"; else bad "nested settings.local.json hooks wrong"; fi
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
  && grep -rq 'subagent_type: wf-Explore' "$IX/.claude/skills/do-whole-phase" "$IX/.claude/agents/slice-executor.md" \
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
# lighter-rules: a bare host session finds each repo's verification skill through the block it loads at start,
# and the block still imports the contract on a line of its own (Claude Code expands an @ import only there).
grep -qF -- '- To verify a change in a repo, use that repo'"'"'s verification skill under `<repo>/.claude/skills/` (its run script)' "$MH/CLAUDE.local.md" \
  && [ "$(grep -cx '@workflow/CLAUDE.workspace.md' "$MH/CLAUDE.local.md")" -eq 1 ] && ! grep -qF "Commit Convention" "$MH/CLAUDE.local.md" \
  && ok "a multi-repo host's CLAUDE.local.md points a bare session at each repo's verification skill and still imports the contract on its own line" \
  || bad "a multi-repo host's CLAUDE.local.md lacks the verification-skill line or the contract import line"
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
printf '%s\n' "$sc" | grep -qx 'repo=alpha pathspec=.' && printf '%s\n' "$sc" | grep -qx 'repo=beta pathspec=.' \
  && printf '%s\n' "$sc" | grep -qx "repo=. (host) pathspec=. ':(exclude)workflow' ':(exclude)alpha' ':(exclude)beta'" \
  && ok "multi-repo phase-scope prints one pathspec per repo and the host's, which excludes workflow/ and every repo folder" \
  || bad "multi-repo pathspec lines missing or wrong -- $sc"
# (c2) pr-check on a multi-repo host never passes a repo with no body: alpha's lines say body=missing and warn; with no
# branch recorded and no --repo nothing is measured, which warns too.
pc_a=$(hw pr-check P1 --repo alpha 2>&1); pc_a_rc=$?; pc_n=$(hw pr-check P1 2>&1); pc_n_rc=$?
[ "$pc_a_rc" -eq 0 ] && printf '%s\n' "$pc_a" | grep -qx 'repo=alpha pr_check=alpha:main base=main' && printf '%s\n' "$pc_a" | grep -q '^repo=alpha body=missing (topics/pr-body-alpha.md)$' \
  && printf '%s\n' "$pc_a" | grep -qx 'pr_check=warn' && [ "$pc_n_rc" -eq 0 ] && printf '%s\n' "$pc_n" | grep -q '^pr_branches=none recorded' && printf '%s\n' "$pc_n" | grep -qx 'pr_check=warn' \
  && ok "multi-repo pr-check: a repo with no topics/pr-body-<repo>.md prints repo=<name> body=missing and pr_check=warn; no recorded branch and no --repo warns too, never pass" \
  || bad "multi-repo pr-check missing-body verdict wrong (rc $pc_a_rc/$pc_n_rc) -- $pc_a / $pc_n"
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
# P1 records a PR branch and R records solo, both with repo null (a per-repo install's only legal value), which the host must name R.
printf 'two\n' > "$MXR/two.txt" && mr git -C "$MXR" add two.txt >/dev/null 2>&1 && mr git -C "$MXR" commit -qm "feat: two" >/dev/null 2>&1 \
  && rw pr-branch P1 --name feat/convert >/dev/null 2>&1 && rw pr-team --record solo --evidence "operator: solo" >/dev/null 2>&1 \
  && printf 'mine\n' > "$MXR/notes.txt" \
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
pr_repo=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["pr"]["branches"][0]["repo"])' "$MX/workflow/works/phases/active/P1/phase.json" 2>&1)
again=$(cd "$MX" && mr python3 workflow/scripts/workflow.py nested-repos --map-anchors R 2>&1)
[ "$rc" -eq 0 ] && [ "$pr_repo" = R ] && printf '%s\n' "$again" | grep -q -- "-- nothing written$" \
  && ok "--to-multi-repo names R in P1's PR record (repo null before) ahead of the closing validate, and a second --map-anchors R writes nothing" \
  || bad "--to-multi-repo left P1's PR record unmapped (rc=$rc, repo=$pr_repo) -- again: $again"
# R's solo record (repo null on the per-repo install = R) must name R on the host, where null means every repo.
t_s=$(cd "$MX" && mr python3 workflow/scripts/workflow.py pr-team --repo S 2>&1); t_r=$(cd "$MX" && mr python3 workflow/scripts/workflow.py pr-team --repo R 2>&1)
printf '%s\n' "$t_s" | grep -q "^pr_team=S recorded=none " && printf '%s\n' "$t_r" | grep -q "^pr_team=R recorded=solo " \
  && ok "--to-multi-repo names R in R's own pr-team record: R still reads solo, S (never recorded) reads none" \
  || bad "--to-multi-repo let R's solo record answer for S -- S: $t_s / R: $t_r"

# ---------------------------------------------------------------------------
echo "== Test 18: P50 loop phases -- the charter gate, the budget stop, park don't halt, the bounded rollup, the tick's resume states, the run-loop core cap =="
# Tiny and core only (the operator's five); the rest is proven live. A fresh --at-root install in git, a
# fake CLAUDE_CONFIG_DIR inside the test's tmp dir (never the real one), no transcripts, so every cycle
# meters `assumed` at per_cycle_usd.
lp_t0=$(date +%s)
newtmp LPW; LP="$LPW/ws"; LPCC="$LPW/cc"; LPX="$LPCC/projects/fixture"; mkdir -p "$LPCC/sessions" "$LPX"
sh "$BOOT" "$LP" --at-root --name "Loop" --summary "loop" >/dev/null 2>&1 || bad "loop probe: the fresh install failed"
lw() { ( cd "$LP" && CLAUDE_CONFIG_DIR="$LPCC" python3 scripts/workflow.py "$@" ); }
lgc() { ( cd "$LP" && git add -A && git commit -qm "$1" ) >/dev/null 2>&1 || bad "loop probe: commit $1 failed"; }
# The identity lives in the repo's config, not on lgc's commits alone: the engine commits too (parallel-start's
# stamp in (h)), and a CI runner has no global identity to fall back on.
( cd "$LP" && git init -q . && git config user.email smoke@example.invalid && git config user.name smoke ) >/dev/null 2>&1; lgc baseline
LPP="$LP/works/phases/active/P1"; LPC="$LPP/loop/charter"
# lp_fill <src> <dst> <total_usd>: fill every UNFILLED section of the charter and set the bounds.
lp_fill() { python3 - "$1" "$2" "$3" <<'PY'
import json, sys
src, dst, total = sys.argv[1], sys.argv[2], float(sys.argv[3])
text = "\n".join(l for l in open(src).read().split("\n") if "UNFILLED" not in l)
text = text.replace("## Objective\n", "## Objective\n\nScore toy items.\n").replace("## One cycle\n", "## One cycle\n\nRun the toy scorer.\n")
bounds = {"cadence": {"min_gap_minutes": 0}, "budget": {"per_cycle_usd": 1.0, "per_day_usd": 1000.0, "total_usd": total, "max_cycles": None},
          "stops": {"max_consecutive_failures": 2}, "spend_covered": [], "stages": {"screen": "screen"}, "checkpoint_every": 1000,
          "digest_every_hours": 100000, "keep_cycles": 2, "cycle_timeout_minutes": 120, "outputs": []}
i = text.index("```json"); j = text.index("```", i + 7)
open(dst, "w").write(text[:i] + "```json\n" + json.dumps(bounds, indent=2) + "\n" + text[j:])
PY
}
# lp_cycle <key> <verdict> [close args]: start -> plan -> result -> close, one cycle.
lp_cycle() { local k=$1 v=$2 out sid; shift 2
  out=$(lw loop-cycle-start P1 --key "$k" --title "item $k" 2>&1) || { printf 'start refused: %s\n' "$out"; return 1; }
  sid=$(printf '%s\n' "$out" | sed -n 's/^cycle=//p')
  printf 'plan\n' > "$LPP/slices/$sid/plan.md"; printf -- '- status: done\n- item_verdict: %s\n' "$v" > "$LPP/slices/$sid/result.md"
  lw loop-cycle-close "$sid" --verdict "$v" --summary "toy $v" --transcripts "$LPX" "$@" 2>&1; }
lp_tick() { lw loop-tick P1 --transcripts "$LPX" 2>&1; }
lp_field() { python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d = (d or {}).get(k) if isinstance(d, dict) else None
print(d)' "$LPP/phase.json" "$1"; }
lw new-phase --phase P1 --name "Toy loop" --objective "score toy items" --loop >/dev/null 2>&1 || bad "loop probe: new-phase --loop failed"
lw start-slice P1.DECOMP >/dev/null 2>&1 && lw finish-slice P1.DECOMP --outcome "cut" >/dev/null 2>&1 || bad "loop probe: DECOMP did not finish"
# (a) the charter gate: no cycle before a signature, no signature over an UNFILLED line, no cycle once the signed file changed.
s_out=$(lw loop-cycle-start P1 --key a --title A 2>&1); s_rc=$?
g_out=$(lw loop-sign P1 --words "sign it" 2>&1); g_rc=$?
lp_fill "$LPC/v1.md" "$LPC/v1.md" 2.0; cp "$LPC/v1.md" "$LPW/v1.signed"
lw loop-sign P1 --words "sign it" >/dev/null 2>&1 || bad "loop probe: loop-sign of a filled charter failed"
printf '\nedited after signing\n' >> "$LPC/v1.md"
e_out=$(lw loop-cycle-start P1 --key a --title A 2>&1); e_rc=$?
cp "$LPW/v1.signed" "$LPC/v1.md"
[ "$s_rc" -ne 0 ] && printf '%s\n' "$s_out" | grep -q 'no signed charter' && [ "$g_rc" -ne 0 ] && printf '%s\n' "$g_out" | grep -q 'UNFILLED' \
  && [ "$e_rc" -ne 0 ] && printf '%s\n' "$e_out" | grep -q 'has changed since it was signed' && [ ! -d "$LPP/slices/P1.C1" ] \
  && ok "the charter gate: loop-cycle-start refuses an unsigned charter, loop-sign refuses one with UNFILLED left, and loop-cycle-start refuses again once the signed file is edited (no cycle folder made)" \
  || bad "the charter gate leaked (start rc=$s_rc, sign rc=$g_rc, edited rc=$e_rc) -- $s_out | $g_out | $e_out"
lgc signed; lw loop-claim P1 >/dev/null 2>&1 || bad "loop probe: loop-claim failed"
# (b) the budget stop: total_usd 2 at 1 per assumed cycle -- the second close halts budget-total, the phase goes pending,
# next waits on it, resume is refused, and signing v2 with a higher total lifts it.
lp_cycle a fail >/dev/null || bad "loop probe: cycle a failed"
c_out=$(lp_cycle b fail); w_out=$(lw next 2>&1)
r_out=$(lw loop-control P1 resume --words "go on" 2>&1); r_rc=$?
lp_fill "$LPC/v1.md" "$LPC/v2.md" 50.0; v_out=$(lw loop-sign P1 --version 2 --words "raise it" 2>&1); v_rc=$?
if printf '%s\n' "$c_out" | grep -q '^halted reason=budget-total ' && printf '%s\n' "$c_out" | grep -q 'usd_source=assumed' \
    && printf '%s\n' "$w_out" | grep -q '^WAITING ON OPERATOR: phase P1 is pending' && printf '%s\n' "$w_out" | grep -q '^on_words=sign charter v2 with a higher bound' \
    && [ "$r_rc" -ne 0 ] && printf '%s\n' "$r_out" | grep -q 'lifted only by a new charter' \
    && [ "$v_rc" -eq 0 ] && printf '%s\n' "$v_out" | grep -q 'lifted the budget-total halt' \
    && [ "$(lp_field status)" = in_progress ] && [ "$(lp_field loop.status)" = running ] && lp_tick | grep -qx 'action=start'; then
  ok "the budget stop: the close that reaches total_usd (assumed cycles) halts budget-total and the phase goes pending, next prints the WAITING block with its on_words, loop-control resume is refused, and loop-sign of v2 with a higher total lifts it (phase in_progress, tick start)"
else bad "the budget stop went wrong (resume rc=$r_rc, sign v2 rc=$v_rc) -- $c_out | $w_out | $r_out | $v_out"; fi
# (c) park, don't halt: a parked close leaves the loop running and the tick starts the next; two error closes in a row halt it.
p_out=$(lp_cycle c parked --question "keep c?" --on-words "requeue c"); p_tick=$(lp_tick)
lp_cycle d error >/dev/null; f_out=$(lp_cycle e error)
if printf '%s\n' "$p_out" | grep -q '^parked: key=c' && ! printf '%s\n' "$p_out" | grep -q '^halted' && printf '%s\n' "$p_tick" | grep -qx 'status=running' \
    && printf '%s\n' "$p_tick" | grep -qx 'action=start' && printf '%s\n' "$f_out" | grep -q '^halted reason=failures ' && [ "$(lp_field loop.halt.reason)" = failures ]; then
  ok "park, don't halt: a parked close leaves the loop running and the tick says start; max_consecutive_failures (2) error closes in a row halt it with failures"
else bad "park/failures wrong -- $p_out | $p_tick | $f_out"; fi
lw loop-control P1 resume --words "go on" >/dev/null 2>&1 || bad "loop probe: resume after failures was refused"
# (d) the bounded rollup: keep_cycles + 3 cycles, each committed, leave keep_cycles closed folders; the global
# works/events.jsonl stays flat over the last 3; ## Slices shows the rollup row.
lgc resumed
for k in f g; do lp_cycle "$k" fail >/dev/null; lgc "$k"; done
ev_before=$(wc -l < "$LP/works/events.jsonl" | tr -d ' ')
for k in h i j; do lp_cycle "$k" fail >/dev/null; lgc "$k"; done
ev_after=$(wc -l < "$LP/works/events.jsonl" | tr -d ' '); left=$(ls -d "$LPP"/slices/P1.C* 2>/dev/null | wc -l | tr -d ' ')
if [ "$left" = 2 ] && [ "$ev_before" = "$ev_after" ] && grep -q '^| `C1–C8` | rolled up (8) → `loop/ledger.jsonl`' "$LPP/phase.md" \
    && [ -d "$LPP/slices/P1.C9" ] && [ -d "$LPP/slices/P1.C10" ]; then
  ok "the bounded rollup: after keep_cycles + 3 committed cycles exactly keep_cycles (2) closed cycle folders remain, the global events.jsonl line count is flat over the last 3 cycles ($ev_after), and ## Slices shows the C1–C8 rollup row"
else bad "the rollup did not bound the state (folders=$left, events $ev_before -> $ev_after) -- $(grep -n 'rolled' "$LPP/phase.md")"; fi
# (e) the tick's resume states with a cycle in flight: a verdict on disk -> close; a plan with no span -> dispatch;
# a span whose session is a live process in the registry -> wait; the same once it is dead -> dispatch attempt=2.
k_out=$(lw loop-cycle-start P1 --key k --title "item k" 2>&1); ksid=$(printf '%s\n' "$k_out" | sed -n 's/^cycle=//p')
t_plan=$(lp_tick); printf 'plan\n' > "$LPP/slices/$ksid/plan.md"; t_disp=$(lp_tick)
sleep 300 & lp_pid=$!
python3 - "$LPCC" "$LPX" "$lp_pid" "$ksid" "$LP" <<'PY'
import json, os, subprocess, sys, time
cc, proj, pid, sid, root = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
start = " ".join(subprocess.run(["ps", "-o", "lstart=", "-p", str(pid)], capture_output=True, text=True,
                                env={**os.environ, "LC_ALL": "C", "TZ": "UTC"}).stdout.split())
json.dump({"pid": pid, "sessionId": "sess-live", "cwd": root, "procStart": start}, open(f"{cc}/sessions/{pid}.json", "w"))
d = f"{proj}/sess-live/subagents"; os.makedirs(d, exist_ok=True)
t = time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime())
open(f"{d}/agent-a1.jsonl", "w").write(json.dumps({"type": "user", "isSidechain": True, "timestamp": t,
    "message": {"role": "user", "content": f"slice: {sid}\nslice folder: x\n"}}) + "\n")
json.dump({"agentType": "slice-executor", "description": sid}, open(f"{d}/agent-a1.meta.json", "w"))
PY
t_wait=$(lp_tick); kill "$lp_pid" 2>/dev/null; wait "$lp_pid" 2>/dev/null; t_dead=$(lp_tick)
printf -- '- status: done\n- item_verdict: fail\n' > "$LPP/slices/$ksid/result.md"; t_close=$(lp_tick)
if [ -n "$ksid" ] && printf '%s\n' "$t_plan" | grep -qx 'action=plan' && printf '%s\n' "$t_disp" | grep -qx 'action=dispatch' \
    && printf '%s\n' "$t_disp" | grep -qx 'attempt=1' && printf '%s\n' "$t_wait" | grep -qx 'action=wait' && printf '%s\n' "$t_wait" | grep -qx 'span=a1' \
    && printf '%s\n' "$t_dead" | grep -qx 'action=dispatch' && printf '%s\n' "$t_dead" | grep -qx 'attempt=2' && printf '%s\n' "$t_close" | grep -qx 'action=close'; then
  ok "the tick resumes from disk with a cycle in flight: no plan.md -> plan, a plan with no span -> dispatch attempt=1, a span whose session is a live process -> wait, the same once it is killed -> dispatch attempt=2, a verdict in result.md -> close"
else bad "the tick's resume states are wrong -- plan: $t_plan | dispatch: $t_disp | wait: $t_wait | dead: $t_dead | close: $t_close"; fi
# (f) P50-fr.F1: the engine numbers the retry and routes it -- the dead span's re-dispatch records attempt 2 on high,
# executor-route prints high with no --retry, and the close's ledger line reads the closing attempt's row.
rm -f "$LPP/slices/$ksid/result.md"; r_disp=$(lw loop-cycle-dispatch "$ksid" --transcripts "$LPX" 2>&1); r_route=$(lw executor-route "$ksid" 2>&1)
printf -- '- status: done\n- item_verdict: fail\n' > "$LPP/slices/$ksid/result.md"; lw loop-cycle-close "$ksid" --verdict fail --summary "toy fail" --transcripts "$LPX" >/dev/null 2>&1
r_line=$(tail -1 "$LPP/loop/ledger.jsonl")
if printf '%s\n' "$r_disp" | grep -q "attempt=2 " && printf '%s\n' "$r_disp" | grep -qx 'route=high stage_route=screen' \
    && printf '%s\n' "$r_route" | grep -qx 'route=high' && printf '%s\n' "$r_route" | grep -qx 'attempt=2' \
    && printf '%s\n' "$r_line" | grep -q '"route": "high", "stage_route": "screen", "attempt": 2'; then
  ok "a retry after a dead span: loop-cycle-dispatch records attempt 2 on the high row, executor-route prints high with no --retry, and the close's ledger line reads route=high stage_route=screen"
else bad "the retry's attempt or row is wrong -- dispatch: $r_disp | route: $r_route | ledger: $r_line"; fi
# (g) P50-fr.F2: no resume runs past a charter-level stop (here the signed charter edited under a pause: the
# resume halts on charter instead), and the final review refuses a pass while a parked item (c) is open.
lw loop-control P1 pause >/dev/null 2>&1; cp "$LPC/v2.md" "$LPW/v2.signed"; printf '\nedited\n' >> "$LPC/v2.md"
g_res=$(lw loop-control P1 resume 2>&1); g_tick=$(lp_tick); cp "$LPW/v2.signed" "$LPC/v2.md"
g_ok=$(lw loop-control P1 resume --words "go on" 2>&1); lw loop-control P1 stop --words "stop" >/dev/null 2>&1
g_rev=$(lw review-phase P1 --verdict pass 2>&1); g_rc=$?
if printf '%s\n' "$g_res" | grep -q '^not resumed P1: the loop was paused, but a charter-level stop holds -- halted reason=charter ' \
    && printf '%s\n' "$g_tick" | grep -qx 'reason=charter' && printf '%s\n' "$g_ok" | grep -q '^resumed P1: halted -> running' \
    && [ "$g_rc" -ne 0 ] && printf '%s\n' "$g_rev" | grep -q 'parked item(s) still open: c .*loop-unpark' && [ "$(lp_field status)" != done ]; then
  ok "no resume past a charter-level stop: a paused loop whose signed charter changed halts on charter (not resumed), resumes once restored, and review-phase refuses the pass while parked key c is open"
else bad "a resume ran past a charter-level stop or the review passed over an open parked item -- $g_res | $g_tick | $g_ok | $g_rev"; fi
# (h) P50-fr.F4: one stream predicate. P1 runs on the default stream; from another phase's worktree the operator's
# words queue in the default checkout's control.json and write nothing there, every other loop writer refuses,
# and the reads name the live loop.
lw new-phase --phase P2 --name "Side" --objective "side work" >/dev/null 2>&1; lgc "loop probe: P2"
lw parallel-start P2 >/dev/null 2>&1 || bad "loop probe: parallel-start P2 failed"
LPWT=$(ls -d "$LP"/.claude/worktrees/P2-* 2>/dev/null | head -1)
hw() { ( cd "$LPWT" && CLAUDE_CONFIG_DIR="$LPCC" python3 scripts/workflow.py "$@" ) 2>&1; }
h_next=$(hw next); h_stat=$(hw loop-status P1 | head -1)
h_mid=$(git -C "$LPWT" status --porcelain)
h_pause=$(hw loop-control P1 pause); h_add=$(hw loop-queue P1 add --key z --title Z); h_add_rc=$?
h_after=$(git -C "$LPWT" status --porcelain)
h_req=$(python3 -c 'import json,sys; print(",".join(r["action"] for r in json.load(open(sys.argv[1]))["requests"]))' "$LPP/loop/control.json" 2>&1)
lw loop-control P1 apply >/dev/null 2>&1
if [ -n "$LPWT" ] && printf '%s\n' "$h_pause" | grep -q "^queued pause for P1 in .*/ws/works/phases/active/P1/loop/control.json " && [ "$h_req" = pause ] \
    && [ "$h_add_rc" -ne 0 ] && printf '%s\n' "$h_add" | grep -q "runs only on the loop's own stream (the default stream" \
    && [ "$h_mid" = "$h_after" ] \
    && printf '%s\n' "$h_stat" | grep -q "source=default checkout .*/ws/works/phases/active/P1$" && printf '%s\n' "$h_next" | grep -q '^loops_elsewhere=P1:stopped:'; then
  ok "a default-stream loop from another phase's worktree: pause queues in the default checkout's control.json writing nothing there, loop-queue add refuses, loop-status reads the live loop and next lists it as loops_elsewhere"
else bad "a default-stream loop addressed from a worktree wrote the stale copy or read it -- pause: $h_pause | add: $h_add | requests: $h_req | status: $h_stat | next: $(printf '%s\n' "$h_next" | grep loops_) | worktree: [$h_mid] -> [$h_after]"; fi
lw validate >/dev/null 2>&1 && ok "validate passes on the loop install after every probe" || bad "validate failed on the loop install -- $(lw validate 2>&1 | tail -5)"
# the run-loop core stays a do-* sized core: <= 16 KB, its resume line inside the first 16 KB.
python3 - "$REPO_ROOT/payload/claude/skills/run-loop/SKILL.md" <<'PY' && ok "run-loop/SKILL.md stays <= 16 KB with its resume line inside the first 16 KB" || bad "run-loop/SKILL.md is over 16 KB or its resume line moved past the first 16 KB"
import sys
raw = open(sys.argv[1], "rb").read()
assert len(raw) <= 16384, len(raw)
line = "**Resume (after a compaction or a restart):**".encode()
i = raw.find(line)
assert i >= 0 and raw.find(b"\n", i) <= 16384, i
PY
echo "loop test runtime: $(( $(date +%s) - lp_t0 ))s"

# ---------------------------------------------------------------------------
echo "== Test 19: P51 PR rule v1 -- the pr block and its commands, pr-check's size/budgets/leaks/headings, the pass guard, validate and next, the drafts opening with no stop (a REVIEW stop halts a run), the pr skill and pr-reader, the team-rule banner, the symlinked skills exclude, the root linguist lines, the _is_ancestor regression; zero GitHub writes =="
# Tiny and core only. Every remote is local (a bare origin) and gh is a stub on PATH: nothing reaches GitHub.
pr_t0=$(date +%s)
newtmp PRW; PRR="$PRW/ws"
sh "$BOOT" "$PRR" --at-root --name "PR" --summary "pr" > "$PRW/install.txt" 2>&1 || bad "pr probe: the fresh install failed"
pw() { ( cd "$PRR" && python3 scripts/workflow.py "$@" ); }
pgit() { git -C "$PRR" "$@"; }
pj() { python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d = d.get(k) if isinstance(d, dict) else (d[int(k)] if isinstance(d, list) and len(d) > int(k) else None)
print(json.dumps(d, sort_keys=True))' "$PRR/works/phases/active/$1/phase.json" "$2"; }
{ pgit init -q . && pgit symbolic-ref HEAD refs/heads/main; } >/dev/null 2>&1
pgit config user.email smoke@example.invalid; pgit config user.name smoke
mkdir -p "$PRR/src" "$PRR/tests" "$PRR/gen"; printf 'gen/** linguist-generated=true\n' >> "$PRR/.gitattributes"
seq 1 50 | sed 's/^/old /' > "$PRR/src/old.py"; printf 'a\nb\nc\n' > "$PRR/src/app.py"; printf '{}\n' > "$PRR/package-lock.json"
( cd "$PRR" && git add -A && git commit -qm baseline ) >/dev/null 2>&1 || bad "pr probe: baseline commit failed"
# (a) a fresh at-root install marks the workspace's state linguist-generated (S11), and prints the team-rule line.
grep -qx 'works/\*\* linguist-generated=true' "$PRR/.gitattributes" && grep -qx 'docs/index.json linguist-generated=true' "$PRR/.gitattributes" \
  && grep -q "team PR rules: none on file -- the pr skill's default template (Summary · Review · What is changed · Why · Related issue) applies" "$PRW/install.txt" \
  && ok "a fresh at-root install marks works/** and the workspace's docs/ paths linguist-generated and prints the bare team-rule line" \
  || bad "fresh at-root install: no linguist-generated lines or no team-rule line -- $(grep -n 'linguist\|team PR' "$PRR/.gitattributes" "$PRW/install.txt")"
# (1) new-phase stamps the empty pr block.
pw new-phase --phase P1 --name "PR probe" --objective "toy" >/dev/null 2>&1 && ( cd "$PRR" && git add -A && git commit -qm p1 ) >/dev/null 2>&1
[ "$(pj P1 pr)" = '{"branches": [], "waived": null}' ] && ok "new-phase stamps pr = {branches: [], waived: null}" || bad "new-phase pr block wrong: $(pj P1 pr)"
# (2) pr-branch: three refusals leave phase.json byte-identical; then it cuts and records the branch.
pgit branch feat/other main
h0=$(sha "$PRR/works/phases/active/P1/phase.json")
pw pr-branch P1 --name feat/other > "$PRW/r1.txt" 2>&1; r1=$?
pw pr-branch P1 --name main > "$PRW/r2.txt" 2>&1; r2=$?
echo dirty >> "$PRR/src/app.py"; pw pr-branch P1 --name feat/b > "$PRW/r3.txt" 2>&1; r3=$?; pgit checkout -q -- src/app.py
h1=$(sha "$PRR/works/phases/active/P1/phase.json")
b_out=$(pw pr-branch P1 --name feat/a 2>&1); b_rc=$?
[ "$r1" -eq 1 ] && grep -q "already exists .* is not checked out there" "$PRW/r1.txt" && [ "$r2" -eq 1 ] && grep -q "that is the base or default branch itself" "$PRW/r2.txt" \
  && [ "$r3" -eq 1 ] && grep -q "uncommitted tracked changes a switch would carry onto feat/b: src/app.py" "$PRW/r3.txt" && [ "$h0" = "$h1" ] \
  && [ "$b_rc" -eq 0 ] && printf '%s\n' "$b_out" | grep -qx 'pr_branch=root:feat/a base=main' && [ "$(pgit branch --show-current)" = feat/a ] \
  && [ "$(pj P1 pr.branches.0.branch)" = '"feat/a"' ] && [ "$(pj P1 pr.branches.0.url)" = null ] \
  && ok "pr-branch refuses an existing unchecked-out branch, the default branch and a dirty tracked tree (phase.json byte-identical), then cuts feat/a from main and records it" \
  || bad "pr-branch wrong (rc $r1/$r2/$r3/$b_rc, sha $h0 -> $h1) -- $(cat "$PRW/r1.txt" "$PRW/r2.txt" "$PRW/r3.txt") / $b_out"
# (3) pr-check size: a generated file, a lockfile, a deletion and a binary are excluded; test lines count.
seq 1 30 > "$PRR/gen/out.txt"; printf '{"a":1}\n' > "$PRR/package-lock.json"; pgit rm -q src/old.py; printf '\000\001\002bin' > "$PRR/src/logo.bin"
seq 1 20 | sed 's/^/assert /' > "$PRR/tests/test_app.py"; printf 'd\ne\n' >> "$PRR/src/app.py"
( cd "$PRR" && git add gen src tests package-lock.json && git commit -qm "feat: toy" ) >/dev/null 2>&1 || bad "pr probe: product commit failed"
c_out=$(pw pr-check P1 2>&1); c_rc=$?
[ "$c_rc" -eq 0 ] && printf '%s\n' "$c_out" | grep -qx 'size=22 size_status=info' \
  && printf '%s\n' "$c_out" | grep -qx 'size_excluded=4 files (generated 1, lockfiles 1, deleted 1, binary 1; counted 2 files)' \
  && printf '%s\n' "$c_out" | grep -qx 'pr_check=root:feat/a base=main' && printf '%s\n' "$c_out" | grep -q '^body=missing (topics/pr-body.md)$' \
  && printf '%s\n' "$c_out" | grep -qx 'pr_check=warn' \
  && ok "pr-check size excludes the generated file, the lockfile, the deletion and the binary (size_excluded=4) and counts the test lines; at root the label is root:, and a missing default body is body=missing and pr_check=warn (exit 0), never pass" || bad "pr-check size or missing-body verdict wrong (rc=$c_rc) -- $c_out"
# (4)(5) bodies: the three budgets, the leaks, the warn, the passes, and the headings (default order, then a team template).
python3 - "$PRW" <<'PY'
import sys
d = sys.argv[1]
def body(review="Check the parser.", changed="The parser reads two more lines.", why="It needed them.", extra="", order=None):
    secs = {"Summary": "Adds two lines to the toy app.", "Review": review, "What is changed": changed, "Why": why, "Related issue": "None."}
    return "".join(f"## {h}\n\n{secs[h]}\n\n" for h in (order or list(secs))) + extra
bodies = {"ok": body(), "first": body(review="word " * 320), "visible": body(changed="word " * 720),
          "whole": body(extra="<!--\n" + "word " * 1300 + "\n-->\n"), "phase": body(why="It was planned in P51."),
          "path": body(why="See workflow/docs/current/qa.md."), "warn": body(why="One slice was enough."),
          "pass": body(why="The S3 bucket p95 latency dropped."),
          "order": body(order=["Summary", "Review", "Why", "What is changed", "Related issue"]),
          "missing": body(order=["Summary", "Review", "What is changed", "Why"])}
for k, v in bodies.items():
    open(f"{d}/body-{k}.md", "w").write(v)
PY
pcb() { pw pr-check P1 --body "$PRW/body-$1.md" > "$PRW/check-$1.txt" 2>&1; printf '%s' "$?"; }
pcl() { grep -qx "$2" "$PRW/check-$1.txt"; }
if [ "$(pcb ok)" = 0 ] && pcl ok 'pr_check=pass' && pcl ok 'headings=ok' && pcl ok 'leaks=none' \
    && [ "$(pcb first)" = 1 ] && pcl first 'first_screen=[0-9]*/1500 over' && [ "$(pcb visible)" = 1 ] && pcl visible 'visible=[0-9]*/3500 over' && pcl visible 'first_screen=[0-9]*/1500 ok' \
    && [ "$(pcb whole)" = 1 ] && pcl whole 'whole=[0-9]*/6000 over' && pcl whole 'visible=[0-9]*/3500 ok' \
    && [ "$(pcb phase)" = 1 ] && grep -q '^leak=phase_id:P51 ' "$PRW/check-phase.txt" && [ "$(pcb path)" = 1 ] && grep -q '^leak=workflow_path:workflow/ ' "$PRW/check-path.txt" \
    && [ "$(pcb warn)" = 0 ] && grep -q '^leak_warn=slice x1 ' "$PRW/check-warn.txt" && pcl warn 'pr_check=warn' \
    && [ "$(pcb pass)" = 0 ] && pcl pass 'leaks=none' && pcl pass 'pr_check=pass' \
    && [ "$(pcb order)" = 1 ] && pcl order 'headings=order:Why' && [ "$(pcb missing)" = 1 ] && pcl missing 'headings=missing:Related issue'; then
  ok "pr-check bodies: each of the three budgets fails over and passes within; P51 and workflow/ fail; 'slice' alone warns (exit 0); 'S3 bucket' and 'p95' pass; out-of-order and missing headings fail against the default order"
else bad "pr-check body checks wrong -- $(for k in ok first visible whole phase path warn pass order missing; do printf '[%s] %s ' "$k" "$(grep -E 'first_screen|visible=|whole=|leak|headings|pr_check=' "$PRW/check-$k.txt" | tr '\n' ' ')"; done)"; fi
mkdir -p "$PRR/.github"; printf '## Summary\n\n## What is changed\n\n## Why\n\n## Related issue\n' > "$PRR/.github/pull_request_template.md"
if [ "$(pcb ok)" = 0 ] && pcl ok 'template=.github/pull_request_template.md' && [ "$(pcb order)" = 1 ] && pcl order 'headings=order:Why' \
    && [ "$(pcb missing)" = 1 ] && pcl missing 'headings=missing:Related issue' && pcl missing 'template=.github/pull_request_template.md'; then
  ok "pr-check headings: out-of-order and missing headings fail against the team's template too, and a body keeping its order passes"
else bad "pr-check template headings wrong -- $(cat "$PRW/check-ok.txt" "$PRW/check-order.txt" "$PRW/check-missing.txt")"; fi
rm -f "$PRR/.github/pull_request_template.md"
# (F2) a missing --body file fails; by hand (no phase) a clean --body passes against the default branch; no phase and no
# --body is refused in one line naming both forms, writing nothing. Size has no default limit (D4 amended): a big branch with a
# clean body is info and passes; only a team's --limit warns (over), on either route; a 0 or non-integer limit is refused.
pw pr-check P1 --body "$PRW/no-such-body.md" > "$PRW/check-nobody.txt" 2>&1; a4=$?
pw pr-check --body "$PRW/body-ok.md" > "$PRW/check-hand.txt" 2>&1; a6=$?
e0=$(sha "$PRR/works/events.jsonl"); pw pr-check > "$PRW/check-none.txt" 2>&1; a7=$?; e1=$(sha "$PRR/works/events.jsonl")
{ pgit switch -qc feat/big && seq 1 1100 > "$PRR/src/big.py" && pgit add src/big.py && pgit commit -qm "feat: big" && pgit switch -q feat/a; } >/dev/null 2>&1
pw pr-check --body "$PRW/body-ok.md" --branch feat/big > "$PRW/check-big.txt" 2>&1; a8=$?
pw pr-check --body "$PRW/body-ok.md" --branch feat/big --limit 400 > "$PRW/check-lim.txt" 2>&1; a9=$?
pw pr-check P1 --body "$PRW/body-ok.md" --limit 400 > "$PRW/check-limok.txt" 2>&1; a10=$?
pw pr-check P1 --body "$PRW/body-ok.md" --limit 10 > "$PRW/check-limph.txt" 2>&1; a11=$?
pw pr-check P1 --body "$PRW/body-ok.md" --limit 0 > "$PRW/check-lim0.txt" 2>&1; a12=$?
pw pr-check --body "$PRW/body-ok.md" --limit 4k > "$PRW/check-limx.txt" 2>&1; a13=$?
if [ "$a4" = 1 ] && pcl nobody "body=missing ($PRW/no-such-body.md)" && pcl nobody 'pr_check=fail' \
    && [ "$a6" = 0 ] && pcl hand 'pr_check=root:feat/a base=main' && pcl hand 'note=by hand (no phase) -- measured feat/a against the default branch main' \
    && pcl hand 'size=22 size_status=info' && pcl hand 'headings=ok' && pcl hand 'pr_check=pass' \
    && [ "$a7" -ne 0 ] && [ "$(wc -l < "$PRW/check-none.txt" | tr -d ' ')" = 1 ] && grep -q 'pr-check <P>' "$PRW/check-none.txt" && grep -q 'pr-check --body <file>' "$PRW/check-none.txt" && [ "$e0" = "$e1" ] \
    && [ "$a8" = 0 ] && grep -q '^size=1[0-9][0-9][0-9] size_status=info$' "$PRW/check-big.txt" && pcl big 'pr_check=pass' && ! grep -qE '^size_over=|target=|flag=' "$PRW/check-big.txt" \
    && [ "$a9" = 0 ] && grep -q '^size=1[0-9][0-9][0-9] limit=400 size_status=over$' "$PRW/check-lim.txt" && grep -q '^size_over=[0-9]* changed lines over the team' "$PRW/check-lim.txt" && pcl lim 'pr_check=warn' \
    && [ "$a10" = 0 ] && pcl limok 'size=22 limit=400 size_status=ok' && pcl limok 'pr_check=pass' \
    && [ "$a11" = 0 ] && pcl limph 'size=22 limit=10 size_status=over' && pcl limph 'size_over=12 changed lines over the team'"'"'s limit of 10 -- split this branch (a stack or a series: the pr skill'"'"'s reference/split.md) or name the exception in ## Review' && pcl limph 'pr_check=warn' \
    && [ "$a12" = 1 ] && [ "$(wc -l < "$PRW/check-lim0.txt" | tr -d ' ')" = 1 ] && grep -q '^pr-check --limit 0: refused' "$PRW/check-lim0.txt" \
    && [ "$a13" = 1 ] && [ "$(wc -l < "$PRW/check-limx.txt" | tr -d ' ')" = 1 ] && grep -q '^pr-check --limit 4k: refused' "$PRW/check-limx.txt"; then
  ok "pr-check: a missing --body file fails (exit 1); by hand with no phase, a clean --body on feat/a passes against the default branch main; no phase and no --body is refused in one line naming both forms, writing nothing; with no team limit a 1,000-line branch is size_status=info and passes; a team --limit warns over it (by hand and in a phase, with size_over=) and is ok within it; --limit 0 and 4k are refused in one line"
else bad "pr-check missing --body / by-hand route / size limit wrong (rc $a4/$a6/$a7/$a8/$a9/$a10/$a11/$a12/$a13) -- $(cat "$PRW/check-nobody.txt" "$PRW/check-hand.txt" "$PRW/check-none.txt" "$PRW/check-big.txt" "$PRW/check-lim.txt" "$PRW/check-limok.txt" "$PRW/check-limph.txt" "$PRW/check-lim0.txt" "$PRW/check-limx.txt")"; fi
# (6a) the drafts open when the review passes, with no stop (F3): while the REVIEW runs with a branch unopened, next prints
# pr_draft=due and run-phases targets the REVIEW (no parked= line); the pass guard refuses, writing nothing; a REVIEW stop
# (pending/decision on a waived gate, or an open failure's operator-action) halts a run like any stop -- no park rule; while
# the REVIEW is pending, next prints no pr_draft=due (D120, P52).
{ pw finish-slice P1.DECOMP --outcome cut && pw accept-gate P1 --waive --note toy && pw start-slice P1.REVIEW \
  && : > "$PRR/works/phases/active/P1/slices/P1.REVIEW/result.md"; } >/dev/null 2>&1 \
  || bad "pr probe: could not bring P1 to its review"
P1D="$PRR/works/phases/active/P1"; gsig() { cat "$P1D/phase.json" "$PRR/works/events.jsonl" "$P1D/slices/P1.REVIEW/slice.json" | sha_stdin; }
run=$(pw run-phases P1 2>&1); plain=$(pw next 2>&1); g0=$(gsig)
g_out=$(pw review-phase P1 --verdict pass 2>&1); g_rc=$?; g1=$(gsig)
if printf '%s\n' "$run" | grep -qx 'target_phase=P1' && printf '%s\n' "$run" | grep -qx 'target_slice=P1.REVIEW' && ! printf '%s\n' "$run" | grep -q '^parked=\|^halt=' \
    && printf '%s\n' "$plain" | grep -q '^pr_draft=due -- when the review would pass: open the draft(s) (pr skill: Open the drafts' \
    && printf '%s\n' "$plain" | grep -qx 'pr_branch=root:feat/a base=main url=none'; then
  ok "while a waived gate's REVIEW runs with a branch unopened, next prints pr_branch= and pr_draft=due, and run-phases targets the REVIEW with no parked= line"
else bad "the drafts' due line or the run target wrong -- run: $run / next: $plain"; fi
[ "$g_rc" -ne 0 ] && printf '%s\n' "$g_out" | grep -q 'root:feat/a (base main) has no draft PR' && printf '%s\n' "$g_out" | grep -qx 'nothing was written' && [ "$g0" = "$g1" ] \
    && printf '%s\n' "$g_out" | grep -q 'the draft opens when the review passes (pr skill: Open the drafts)' && ! printf '%s\n' "$g_out" | grep -q "operator's .push" \
  && ok "the pass guard refuses an unopened recorded branch, names the draft opening when the review passes, and writes nothing (phase.json, events.jsonl, the REVIEW's slice.json unchanged)" || bad "pass guard (a) wrong (rc=$g_rc, $g0 -> $g1) -- $g_out"
pw set-slice-status P1.REVIEW pending --stop-kind decision --on-words "an answer resumes it" >/dev/null 2>&1; run_d=$(pw run-phases P1 2>&1)
pw set-slice-status P1.REVIEW in_progress >/dev/null 2>&1
pw set-slice-status P1.REVIEW pending --stop-kind operator-action --on-words "gh auth login resumes the open" >/dev/null 2>&1; run_o=$(pw run-phases P1 2>&1); nx_o=$(pw next 2>&1)
pw set-slice-status P1.REVIEW in_progress >/dev/null 2>&1
u_out=$(pw pr-record P1 --url https://github.com/example/toy/pull/1 2>&1); run_u=$(pw run-phases P1 2>&1); nx_u=$(pw next 2>&1)
if printf '%s\n' "$run_d" | grep -qx 'halt=P1.REVIEW status=pending' && printf '%s\n' "$run_d" | grep -qx 'stop_kind=decision' && printf '%s\n' "$run_d" | grep -qx 'halt_reason=slice P1.REVIEW is pending -- the whole run stops here: report it, start nothing past it' \
    && printf '%s\n' "$run_o" | grep -qx 'halt=P1.REVIEW status=pending' && printf '%s\n' "$run_o" | grep -qx 'stop_kind=operator-action' && ! printf '%s\n' "$nx_o" | grep -q '^pr_draft=' \
    && ! printf '%s\n%s\n%s\n' "$run_d" "$run_o" "$run_u" | grep -q '^parked=' && printf '%s\n' "$run_u" | grep -qx 'target_slice=P1.REVIEW' \
    && printf '%s\n' "$nx_u" | grep -qx 'pr_branch=root:feat/a base=main url=https://github.com/example/toy/pull/1' && ! printf '%s\n' "$nx_u" | grep -q '^pr_draft=\|^pr_push='; then
  ok "a REVIEW stop on a waived gate (decision, or an open failure's operator-action) halts run-phases like any stop, never parked, and next prints no pr_draft=due while the REVIEW is pending (D120; it prints while in_progress and in_review); once pr-record --url ran, next prints the url and no due line"
else bad "REVIEW stop / url wrong -- decision: $run_d / operator-action: $run_o / url: $run_u / next: $nx_u"; fi
{ pw set-slice-status P1.REVIEW in_progress && pw review-phase P1 --verdict pass; } > "$PRW/pass1.txt" 2>&1 \
  && grep -q '^phase P1 review: pass' "$PRW/pass1.txt" && ok "pr-record --url clears the guard: the pass records" || bad "pass after pr-record --url refused -- $(cat "$PRW/pass1.txt")"
( cd "$PRR" && git add -A && git commit -qm "p1 done" ) >/dev/null 2>&1
# (6b) an empty block with committed product files refuses; pr-branch records the checked-out branch; --waive clears it.
pw new-phase --phase P2 --name "PR probe 2" --objective "toy" >/dev/null 2>&1; ( cd "$PRR" && git add -A && git commit -qm p2 && git switch -qc feat/c \
  && echo more >> src/app.py && git add src && git commit -qm "feat: more" ) >/dev/null 2>&1
{ pw finish-slice P2.DECOMP --outcome cut && pw accept-gate P2 --waive --note toy && pw start-slice P2.REVIEW && : > "$PRR/works/phases/active/P2/slices/P2.REVIEW/result.md"; } >/dev/null 2>&1
e_out=$(pw review-phase P2 --verdict pass 2>&1); e_rc=$?
k_out=$(pw pr-branch P2 --name feat/c 2>&1); pw set-slice-status P2.REVIEW in_review >/dev/null 2>&1; nx2=$(pw next 2>&1)
pw pr-record P2 --waive --note "toy change" >/dev/null 2>&1; nx3=$(pw next 2>&1); w_out=$(pw review-phase P2 --verdict pass 2>&1); w_rc=$?
if [ "$e_rc" -ne 0 ] && printf '%s\n' "$e_out" | grep -q 'changed 1 product file(s) (phase-scope P2) but records no PR branch' \
    && printf '%s\n' "$k_out" | grep -q '^pr-branch: feat/c recorded (already checked out)' && printf '%s\n' "$nx2" | grep -q '^pr_draft=due ' \
    && printf '%s\n' "$nx3" | grep -qx 'pr_waived=toy change' && [ "$w_rc" -eq 0 ] && printf '%s\n' "$w_out" | grep -q '^pr: waived (toy change) -- pass recorded without a draft PR'; then
  ok "an empty pr block with committed product files refuses the pass; pr-branch records a checked-out branch; next prints pr_draft=due (REVIEW in_review) then pr_waived=; --waive clears the guard"
else bad "pass guard (b) / waive wrong (rc $e_rc/$w_rc) -- $e_out / $k_out / $nx2 / $nx3 / $w_out"; fi
( cd "$PRR" && git add -A && git commit -qm "p2 done" ) >/dev/null 2>&1
# (6c) an uncleared required gate still refuses with the PR waived, and still parks a run as before; (6d) a phase with
# no pr block (an older phase) passes as before and prints no pr line.
{ pw new-phase --phase P3 --name "PR probe 3" --objective "toy" && pw finish-slice P3.DECOMP --outcome cut && pw accept-gate P3 --require \
  && pw start-slice P3.REVIEW && : > "$PRR/works/phases/active/P3/slices/P3.REVIEW/result.md" && pw pr-record P3 --waive --note "toy"; } >/dev/null 2>&1
q_out=$(pw review-phase P3 --verdict pass 2>&1); q_rc=$?
pw accept-gate P3 --open --walkthrough "probe" >/dev/null 2>&1; run3=$(pw run-phases P3 2>&1)
[ "$q_rc" -ne 0 ] && printf '%s\n' "$q_out" | grep -q 'accept-gate' && printf '%s\n' "$run3" | grep -q '^parked=P3 since=.* -- acceptance gate open' \
  && ok "an uncleared required acceptance gate still refuses the pass with the PR waived, and its open gate parks a run as before" || bad "required gate with a waived PR wrong (rc=$q_rc) -- $q_out / $run3"
{ pw accept-gate P3 --clear && pw review-phase P3 --verdict pass; } >/dev/null 2>&1
{ pw new-phase --phase P4 --name "Old phase" --objective "toy" && python3 - "$PRR/works/phases/active/P4/phase.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d.pop("pr"); json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
} >/dev/null 2>&1
( cd "$PRR" && git add -A && git commit -qm p4 && echo again >> src/app.py && git add src && git commit -qm "feat: again" ) >/dev/null 2>&1
{ pw finish-slice P4.DECOMP --outcome cut && pw accept-gate P4 --waive --note toy && pw start-slice P4.REVIEW && : > "$PRR/works/phases/active/P4/slices/P4.REVIEW/result.md"; } >/dev/null 2>&1
nx4=$(pw next 2>&1); o_out=$(pw review-phase P4 --verdict pass 2>&1); o_rc=$?
[ "$o_rc" -eq 0 ] && ! printf '%s\n' "$nx4" | grep '^pr_' | grep -qv '^pr_open=P1 ' && ! printf '%s\n' "$o_out" | grep -q '^pr' \
  && ok "a phase with no pr block (created before P51) passes as before, and next prints no pr line for it (P52: only the other phase's pr_open= line)" || bad "an older phase changed (rc=$o_rc) -- $nx4 / $o_out"
# (7) validate flags a malformed pr block (an unknown key, a duplicate pair, a bad URL, a repo at root) and a malformed pr_rules.
cp "$P1D/phase.json" "$PRW/p1.json"
pr_bad() { python3 - "$P1D/phase.json" "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); b = d["pr"]; e = b["branches"][0]
kind = sys.argv[2]
if kind == "key": b["extra"] = 1
elif kind == "dup": b["branches"].append(dict(e))
elif kind == "url": e["url"] = "ftp://example/x"
elif kind == "repo": e["repo"] = "nosuch"
json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
pw validate > "$PRW/val-$1.txt" 2>&1; v=$?; cp "$PRW/p1.json" "$P1D/phase.json"; printf '%s' "$v"; }
vk=$(pr_bad key); vd=$(pr_bad dup); vu=$(pr_bad url); vr=$(pr_bad repo)
printf '{"decided": [{"rule": "x"}]}\n' > "$PRR/works/pr-rules.json"; pw validate > "$PRW/val-rules.txt" 2>&1; vp=$?; rm -f "$PRR/works/pr-rules.json"
if [ "$vk" != 0 ] && [ "$vd" != 0 ] && [ "$vu" != 0 ] && [ "$vr" != 0 ] && [ "$vp" -ne 0 ] && grep -q 'pr: unknown field(s) extra' "$PRW/val-key.txt" \
    && grep -q 'root:feat/a is recorded twice' "$PRW/val-dup.txt" && grep -q "url 'ftp://example/x' must be null or an http(s) URL" "$PRW/val-url.txt" \
    && grep -q "repo 'nosuch': this install has no repos registry" "$PRW/val-repo.txt" && grep -q 'pr-rules.json: pr_rules.decided\[0\]: missing field' "$PRW/val-rules.txt" && pw validate >/dev/null 2>&1; then
  ok "validate flags a malformed pr block (unknown key, duplicate pair, non-http(s) URL, a repo with no registry) and a malformed pr_rules, and passes once restored"
else bad "validate missed a malformed pr block or pr_rules (rc $vk/$vd/$vu/$vr/$vp) -- $(cat "$PRW"/val-*.txt | grep -i 'pr' | head -8)"; fi
# (8 stub) the pr skill's two push commands, taken from its text, run against a local bare origin and a stub gh:
# a --draft create with --body-file; a stub draft refusal is exactly one create call and a stop for the operator's plain|waive
# (reference/open.md; never an automatic retry), and only on plain the same create runs without --draft and with no --reviewer.
newtmp GHS; git init -q --bare "$GHS/origin.git"; pgit remote add origin "$GHS/origin.git"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/gh.log"\ncase "$*" in *--draft*) [ -n "${GH_STUB_REFUSE_DRAFT:-}" ] && { echo "Draft pull requests are not supported in this repository" >&2; exit 1; };; esac\necho https://github.com/example/toy/pull/9\n' "$GHS" > "$GHS/gh"; chmod +x "$GHS/gh"
pr_cmds=$(python3 - "$SRC/claude/skills/pr/SKILL.md" <<'PY'
import re, sys
t = open(sys.argv[1]).read().split("## Open the drafts, when the review passes", 1)[1]
push = re.search(r"^1\. `(git push [^`]+)`", t, re.M).group(1); create = re.search(r"^2\. `(gh pr create [^`]+)`", t, re.M).group(1)
for c in (push, create):
    print(c.replace("<b>", "feat/c").replace("<base>", "main").replace('"<title>"', '"Toy change"').replace("<body>", "BODY"))
PY
)
pr_gitpush=$(printf '%s\n' "$pr_cmds" | sed -n 1p); pr_create=$(printf '%s\n' "$pr_cmds" | sed -n 2p | sed "s|BODY|$PRW/body-ok.md|")
( cd "$PRR" && eval "$pr_gitpush" ) >/dev/null 2>&1; s_push=$?
( cd "$PRR" && export PATH="$GHS:$PATH" && eval "$pr_create" ) >/dev/null 2>&1; s_create=$?
( cd "$PRR" && export PATH="$GHS:$PATH" GH_STUB_REFUSE_DRAFT=1 && eval "$pr_create" ) >/dev/null 2>&1; s_refused=$?; n_refused=$(wc -l < "$GHS/gh.log" | tr -d ' ')
( cd "$PRR" && export PATH="$GHS:$PATH" GH_STUB_REFUSE_DRAFT=1 && eval "$(printf '%s' "$pr_create" | sed 's/ --draft//')" ) >/dev/null 2>&1; s_plain=$?
if [ "$s_push" -eq 0 ] && git -C "$GHS/origin.git" rev-parse --verify --quiet refs/heads/feat/c >/dev/null && [ "$s_create" -eq 0 ] && [ "$s_refused" -ne 0 ] && [ "$n_refused" = 2 ] && [ "$s_plain" -eq 0 ] \
    && [ "$(sed -n 1p "$GHS/gh.log")" = "pr create --draft --base main --head feat/c --title Toy change --body-file $PRW/body-ok.md" ] \
    && [ "$(wc -l < "$GHS/gh.log" | tr -d ' ')" = 3 ] && sed -n 3p "$GHS/gh.log" | grep -q -- '--body-file' && ! sed -n 3p "$GHS/gh.log" | grep -q -- '--draft' && ! grep -q -- '--reviewer' "$GHS/gh.log" \
    && python3 - "$SRC/claude/skills/pr" <<'PY'
import sys
from pathlib import Path
d = Path(sys.argv[1]); core = (d / "SKILL.md").read_text(); ref = (d / "reference/open.md").read_text(); flat = lambda s: " ".join(s.split())
for t in (core, ref): assert "retry **once**" not in t and "retries once" not in t
for s in ("**If GitHub refuses the draft**", "never retry it as a plain PR, which notifies people: stop for the operator's `plain` or `waive` (`reference/open.md`)."): assert s in core, s
for s in ("Set the `REVIEW` slice `pending --stop-kind decision --on-words \"plain opens it as a plain PR (ready for review at once: it requests code-owner reviews and notifies watchers; no reviewers are requested); waive records pr-record --waive and the pass\"`",
          "attempt no second one before the operator's word", "**`plain`:** the same `gh pr create` without `--draft`, and no `--reviewer`.",
          "**`waive`:** `python3 scripts/workflow.py pr-record <P> --waive --note", "Drafts already opened stay open. On `plain`, the open continues bottom-up from the refused one"):
    assert flat(s) in flat(ref), s
PY
then
  ok "the pr skill's push commands push to the (local) origin and create a --draft PR with --body-file on a stub gh; a stub draft refusal is one create call and a stop for plain|waive (no automatic retry); plain creates without --draft and no --reviewer"
else bad "pr skill push commands or refused-draft stop wrong (push $s_push, create $s_create, refused $s_refused/$n_refused, plain $s_plain) -- $pr_cmds / $(cat "$GHS/gh.log" 2>/dev/null)"; fi
# (S7) the pr skill: its name, an allowed-tools list with no remote write and no recording command, its two references, its core size.
python3 - "$SRC/claude/skills/pr" <<'PY' && ok "the pr skill: name: pr, no git push / gh pr create|comment|edit|ready|merge / pr-record / pr-branch / pr-sync / --record / bare Bash in allowed-tools (gh pr checks and the bare pr-team read allowed), its core names exactly reference/body.md, close.md, open.md, reopen.md, split.md and stack.md (all shipped), core <= 8,192 B" || bad "the pr skill's frontmatter, references or core size changed"
import re, sys
from pathlib import Path
d = Path(sys.argv[1]); core = (d / "SKILL.md").read_bytes(); text = core.decode()
fm = text.split("---\n", 2)[1]
assert re.search(r"^name: pr$", fm, re.M)
tools = re.search(r"^allowed-tools: (.*)$", fm, re.M).group(1)
for gone in ("git push", "gh pr create", "gh pr comment", "gh pr edit", "gh pr ready", "gh pr merge", "pr-record", "pr-branch", "pr-sync", "--record"):
    assert gone not in tools, gone
tl = [t.strip() for t in tools.split(",")]
assert "Bash" not in tl, "bare Bash"
assert "Bash(gh pr checks:*)" in tl and "Bash(python3 scripts/workflow.py pr-team)" in tl, tl
assert set(re.findall(r"`reference/([\w.-]+\.md)`", text)) == {"body.md", "close.md", "open.md", "reopen.md", "split.md", "stack.md"} == {p.name for p in (d / "reference").glob("*.md")}
assert len(core) <= 8192, len(core)
PY
# (S8) pr-reader: the reader row's dispatch lines; the agent installs fresh and comes back on --update.
r_out=$(pw executor-route --reader 2>&1)
printf '%s\n' "$r_out" | grep -qx 'subagent_type=pr-reader' && printf '%s\n' "$r_out" | grep -qx 'model=opus' && printf '%s\n' "$r_out" | grep -qx 'effort=high' \
  && [ -f "$PRR/.claude/agents/pr-reader.md" ] && grep -qx 'name: pr-reader' "$PRR/.claude/agents/pr-reader.md" \
  && ok "executor-route --reader prints subagent_type=pr-reader, model=opus and effort=high, and a fresh install ships .claude/agents/pr-reader.md" || bad "pr-reader route or fresh install wrong -- $r_out"
# code-reader: the code row's dispatch lines; the agent installs fresh.
c_out=$(pw executor-route --code 2>&1)
printf '%s\n' "$c_out" | grep -qx 'route=code' && printf '%s\n' "$c_out" | grep -qx 'subagent_type=code-reader' && printf '%s\n' "$c_out" | grep -qx 'model=opus' && printf '%s\n' "$c_out" | grep -qx 'effort=high' \
  && [ -f "$PRR/.claude/agents/code-reader.md" ] && grep -qx 'name: code-reader' "$PRR/.claude/agents/code-reader.md" \
  && ok "executor-route --code prints route=code, subagent_type=code-reader, model=opus and effort=high, and a fresh install ships .claude/agents/code-reader.md" || bad "code-reader route or fresh install wrong -- $c_out"
# (S11) at-root --update appends the linguist lines once, then counts .gitattributes unchanged; it restores pr-reader.md.
grep -v 'linguist-generated=true' "$PRR/.gitattributes" > "$PRW/ga" && cp "$PRW/ga" "$PRR/.gitattributes" && rm -f "$PRR/.claude/agents/pr-reader.md"
( cd "$PRR" && git add -A && git commit -qm "strip" ) >/dev/null 2>&1
( cd "$PRR" && sh "$BOOT" . --update ) > "$PRW/u1.txt" 2>&1; ( cd "$PRR" && sh "$BOOT" . --update ) > "$PRW/u2.txt" 2>&1
if grep -q '^  merged (additive): .*\.gitattributes' "$PRW/u1.txt" && grep -q '+ \.claude/agents/pr-reader\.md' "$PRW/u1.txt" && [ -f "$PRR/.claude/agents/pr-reader.md" ] \
    && ! grep -q '^  merged (additive): .*\.gitattributes' "$PRW/u2.txt" && [ "$(grep -c 'linguist-generated=true' "$PRR/.gitattributes")" = 4 ] \
    && grep -q "team PR rules: none on file" "$PRW/u1.txt"; then
  ok "an at-root --update appends the four linguist-generated lines once (merged (additive), then unchanged), restores pr-reader.md and prints the team-rule line"
else bad "at-root --update linguist lines or pr-reader wrong -- $(grep -n 'merged\|added\|pr-reader\|team PR' "$PRW/u1.txt" "$PRW/u2.txt") / $(grep -c 'linguist-generated=true' "$PRR/.gitattributes")"; fi
# (S10) nested banners: a bare host's team-rule line; a team-template host (a 4-heading template, a PR agent skill, .claude/skills
# a symlink to .agents/skills) gets the conflict line, the resolved-path exclude lines and the note, with a clean status.
newtmp PRH; for h in bare team; do mkdir -p "$PRH/$h" && ( cd "$PRH/$h" && git init -q . && git symbolic-ref HEAD refs/heads/main \
  && git config user.email smoke@example.invalid && git config user.name smoke && echo hi > README.md ) >/dev/null 2>&1; done
( cd "$PRH/team" && mkdir -p .github .agents/skills/create-pull-request .claude && printf '## Summary\n\n## What is changed\n\n## Why\n\n## Related issue\n' > .github/pull_request_template.md \
  && printf -- '---\nname: create-pull-request\ndescription: Open a pull request with the team template.\n---\nUse the template.\n' > .agents/skills/create-pull-request/SKILL.md \
  && ln -s ../.agents/skills .claude/skills ) >/dev/null 2>&1
for h in bare team; do ( cd "$PRH/$h" && git add -A && git commit -qm "chore: init" && sh "$BOOT" . ) > "$PRH/$h.txt" 2>&1; done
if grep -q "team PR rules: none on file -- the pr skill's default template (Summary · Review · What is changed · Why · Related issue) applies" "$PRH/bare.txt" \
    && grep -q "team PR rules: .*\.agents/skills/create-pull-request/SKILL.md, .github/pull_request_template.md" "$PRH/team.txt" \
    && grep -q "PR-rules conflict: headings -- the team's template has no ## Review; ours adds ## Review after ## Summary" "$PRH/team.txt" \
    && grep -q "note: .claude/skills is a symlink" "$PRH/team.txt" && grep -qx '/.agents/skills/pr/' "$PRH/team/.git/info/exclude" \
    && [ -f "$PRH/team/.agents/skills/pr/SKILL.md" ] && [ -z "$(git -C "$PRH/team" status --porcelain)" ] && [ -f "$PRH/team/.claude/agents/pr-reader.md" ]; then
  ok "nested banners: a bare host's 'none on file' line; a team-template host's team-rule and ## Review conflict lines, and its symlinked .claude/skills gets resolved-path exclude lines, the note and a clean git status"
else bad "nested team-rule banner or symlink exclude wrong -- $(grep -n 'PR rules\|PR-rules\|note:' "$PRH/bare.txt" "$PRH/team.txt") / $(git -C "$PRH/team" status --porcelain)"; fi
# (9) the regression S6 fixed: a nested phase whose host branch left the default branch (merge-base != anchor != HEAD) gets a
# phase-scope and a passing review, no TypeError (a duplicate _is_ancestor shadowed P40's); no top-level def is defined twice.
BH="$PRH/bare"; bw() { ( cd "$BH" && python3 workflow/scripts/workflow.py "$@" ); }
( cd "$BH" && git switch -qc feat/toy && echo b > b.txt && git add b.txt && git commit -qm "feat: b" ) >/dev/null 2>&1
bw new-phase --phase P1 --name toy --objective toy >/dev/null 2>&1; ( cd "$BH" && echo c > c.txt && git add c.txt && git commit -qm "feat: c" ) >/dev/null 2>&1
s_out=$(bw phase-scope P1 2>&1); s_rc=$?
{ bw finish-slice P1.DECOMP --outcome cut && bw accept-gate P1 --waive --note toy && bw start-slice P1.REVIEW && : > "$BH/workflow/works/phases/active/P1/slices/P1.REVIEW/result.md" \
  && bw pr-branch P1 --name feat/toy && bw pr-record P1 --url https://github.com/example/toy/pull/2; } >/dev/null 2>&1
v_out=$(bw review-phase P1 --verdict pass 2>&1); v_rc=$?
if [ "$s_rc" -eq 0 ] && printf '%s\n' "$s_out" | grep -q '^product_files=1 ' && [ "$v_rc" -eq 0 ] && printf '%s\n' "$v_out" | grep -q '^phase P1 review: pass' \
    && ! printf '%s\n%s\n' "$s_out" "$v_out" | grep -q TypeError \
    && python3 - "$SRC/scripts/workflow.py" <<'PY'
import ast, collections, sys
names = collections.Counter(n.name for n in ast.parse(open(sys.argv[1]).read()).body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)))
assert not [k for k, v in names.items() if v > 1], [k for k, v in names.items() if v > 1]
PY
then ok "a nested phase whose host branch left main gets its phase-scope and a passing review (no _is_ancestor TypeError), and no engine function is defined twice"
else bad "the _is_ancestor regression is back (scope rc=$s_rc, review rc=$v_rc) -- $s_out / $v_out"; fi
# (S13) on a nested host with an origin, a PR base is recorded as the branch name gh pr create --base takes, and pr-check
# diffs origin/<base>: the default records main (not origin/main); --base origin/main records main; a stack part's base stays
# feat/o; a sha is refused; an old record holding base=origin/main reads as main; a base with no remote ref diffs the local branch.
newtmp PRO; git init -q --bare "$PRO/origin.git"; NH="$PRO/host"; mkdir -p "$NH"; ngit() { git -C "$NH" "$@"; }
nw() { ( cd "$NH" && python3 workflow/scripts/workflow.py "$@" ); }
{ ngit init -q . && ngit symbolic-ref HEAD refs/heads/main && ngit config user.email smoke@example.invalid && ngit config user.name smoke \
  && echo a > "$NH/app.txt" && ngit add app.txt && ngit commit -qm "chore: init" && ngit remote add origin "$PRO/origin.git" \
  && ngit push -q origin main && ngit remote set-head origin main && ( cd "$NH" && sh "$BOOT" . ) \
  && git -C "$NH/workflow" config user.email smoke@example.invalid && git -C "$NH/workflow" config user.name smoke \
  && nw new-phase --phase P1 --name base --objective toy; } >/dev/null 2>&1 || bad "pr base probe: the nested host with an origin failed to set up"
o1=$(nw pr-branch P1 --name feat/o 2>&1); { echo b >> "$NH/app.txt" && ngit commit -qam "feat: b"; } >/dev/null 2>&1
o2=$(nw pr-branch P1 --name feat/p --base origin/main 2>&1); ngit switch -q feat/o
o3=$(nw pr-branch P1 --name feat/q --base feat/o 2>&1); ngit switch -q feat/o
nw pr-branch P1 --name feat/s --base "$(ngit rev-parse main)" > "$PRO/o4.txt" 2>&1; o4=$?
oc1=$(nw pr-check P1 --branch feat/o 2>&1); oc3=$(nw pr-check P1 --branch feat/q 2>&1)
python3 - "$NH/workflow/works/phases/active/P1/phase.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["pr"]["branches"][0]["base"] = "origin/main"; json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
oc_old=$(nw pr-check P1 --branch feat/o 2>&1); o_nx=$(nw next 2>&1); o_val=$(nw validate 2>&1); o_vrc=$?
if printf '%s\n' "$o1" | grep -qx 'pr_branch=host:feat/o base=main' && printf '%s\n' "$o2" | grep -qx 'pr_branch=host:feat/p base=main' \
    && printf '%s\n' "$o3" | grep -qx 'pr_branch=host:feat/q base=feat/o' && [ "$o4" -eq 1 ] && grep -q 'a PR base must be a branch' "$PRO/o4.txt" \
    && printf '%s\n' "$oc1" | grep -qx 'pr_check=host:feat/o base=main' && printf '%s\n' "$oc1" | grep -qx 'diff_base=origin/main' \
    && printf '%s\n' "$oc1" | grep -qx 'size=1 size_status=info' && printf '%s\n' "$oc3" | grep -qx 'diff_base=feat/o' \
    && printf '%s\n' "$oc1" | grep -q '^body=missing (topics/pr-body.md)$' && printf '%s\n' "$oc1" | grep -qx 'pr_check=warn' \
    && printf '%s\n' "$oc_old" | grep -qx 'pr_check=host:feat/o base=main' && printf '%s\n' "$oc_old" | grep -qx 'diff_base=origin/main' \
    && printf '%s\n' "$o_nx" | grep -qx 'pr_branch=host:feat/o base=main url=none' && [ "$o_vrc" -eq 0 ]; then
  ok "with an origin, pr-branch records the PR base as a branch name (default main, --base origin/main as main, a stack part's feat/o) and refuses a sha; pr-check prints diff_base=origin/main, or the local branch with no remote ref; an old base=origin/main record reads as main; a nested host keeps host: and a missing default body warns, never passes"
else bad "PR base as a branch name wrong (sha rc $o4, validate rc $o_vrc) -- $o1 / $o2 / $o3 / $(cat "$PRO/o4.txt") / $oc1 / $oc3 / $oc_old / $(printf '%s\n' "$o_nx" | grep pr_) / $(printf '%s\n' "$o_val" | tail -3)"; fi
# (S9) the PR rule's wiring phrases in the contract and the shipped skills, and the negatives they replaced.
python3 - "$REPO_ROOT" <<'PY' && ok "the PR rule's wiring: the contract's push invariant and its draft-PR row, review-phase's PR step, both review.md's reader and the drafts opening when the review passes, verdicts/decomposition/create-phase/executor/parallel-phase/do-whole-phases/pr lines, and the retired no-branch/no-push and push-stop lines; the close and reopen references route a change request after the pass to reopen-phase (P52 F1)" || bad "a PR-rule wiring phrase moved or a retired line is back"
import sys
from pathlib import Path
root = Path(sys.argv[1]); sys.path.insert(0, str(root / "installer"))
from build import collect_live_payloads
L = collect_live_payloads()
sk = lambda n: "\n".join(v for k, v in sorted(L.items()) if k.startswith(f".claude/skills/{n}/"))
flat = lambda s: " ".join(s.split())
both = lambda ref: [L[f".claude/skills/do-whole-phase/reference/{ref}"]]  # lighter-rules: do-next-slice ships no copy
push_stop = ["`push` stop", "push stop", "On the operator's `push`", "on the operator's `push`", "say `push`", "pr_push=waiting", "PR_PUSH_WAITING"]
checks = [
    ([(root / "payload/contract.md").read_text()], ["**Nothing is pushed, merged or paid for without the operator's word.**", "| A product phase passes with its draft PR open | `review-phase --verdict pass` refuses a PR branch with no draft PR"],
     ["Create no branch unless asked", "Never push unasked", "push only on the operator's word", "Ready and merge are the operator's"] + push_stop),
    ([sk("review-phase")], ["## The PR step — one body per recorded branch", "**Writing the body is a review lens.**", "**Return `pr_bodies`**"], push_stop),
    (both("review.md"), ["open the drafts by the `pr` skill's *Open the drafts*", "with no stop and no word", "read each PR's CI before the gate",
                         "`executor-route --reader`", "--stop-kind operator-action --on-words \"<what fixing it resumes>\"",
                         "a refused draft is never retried as a plain PR", "The engine refuses the pass until every recorded branch has its URL"],
     push_stop + ["push opens the draft PR(s); the pass is recorded after"]),
    (both("verdicts.md"), ["**The only pushes are the draft opening when the review passes**", "**the close's solo landing, and a fix round's or a stack merge's `git push` to an open PR's branch**"],
     ["do not branch unless the operator asks", "Do not branch unless the operator asks", "**The only push is the draft opening", "Never force-push, request reviewers, merge a team repo's PR or flip one Ready"] + push_stop),
    (both("review.md"), ["run the close's step A", "record the pass **without re-dispatching the review**", "then its step B",
                         "**After the phase is done**", "always `reopen-phase <P> --note \"team-reported: <what>\"`"], ["Ready and merge stay the operator's"]),
    ([sk("review-phase")], ["**A reopened phase's re-review**", "or `operator-reported: …`, from `reopen-phase`"], []),
    ([sk("rotate-backlog")], ["**First, sync the open PRs (both paths).**"], []),
    ([L[".claude/skills/pr/reference/close.md"]], ["**Pass recorded or not.**", "always goes through `reopen-phase`", "never `review-phase`, which the engine refuses",
                                                   "--note \"operator-reported: CI red: <checks>\"", "**A change asked for after Ready**"], []),
    ([L[".claude/skills/pr/reference/reopen.md"]], ["**One rule.**", "`git -C <host> switch <default>`", "No worktree is cut or claimed", "`git worktree add <sibling> <branch>`",
                                                    "**At root, commit the reopen with the fix round's first commit**"], ["## Team-reported changes after the phase is done"]),
    ([L["scripts/workflow.py"]], ["a change request (the team's or the operator's) reopens it on the PR branch", "--note is empty; say whose change request it is and what it asks"], ["a team's change request reopens it in its own worktree", "say what the team asked for"]),
    # P52 F4: the reopen names both reporters everywhere it ships (help, docstring, re-review, pr core, review.md, READMEs).
    ([L["scripts/workflow.py"]], ["(a change request after the phase was done, the team's or the operator's)", 'help="whose change request it is and what it asks: \\"team-reported: <what>\\" or \\"operator-reported: <what>\\" (recorded as the review note'],
     ["a team asked for changes after the phase was done", "what the team asked for:", "a team's new change request becomes a new phase", "# A team asks for changes after the phase is done"]),
    ([(root / "payload/claude/skills/do-whole-phase/playbooks/review.md").read_text()], ["(its review note reads `team-reported: …` or `operator-reported: …`): the request is the claims to verify"],
     ["(its review note reads `team-reported: …`): the team's review comments"]),
    ([sk("pr")], ["**Changes after the phase is done**: `reference/reopen.md`"], ["**Team changes after the phase is done**"]),
    (both("review.md"), [], ["or a team's review after a reopen)"]),
    ([(root / "README.en.md").read_text(encoding="utf-8")], ["(the team's review, or your own) reopens the same"], ["fix\n   slice in the same phase"]),
    ([(root / "README.md").read_text(encoding="utf-8")], ["(팀 리뷰든 내 요청이든) 같은 phase를 열린 PR 위에서 다시 엽니다"], ["같은 phase의 fix slice"]),
    ([sk("archive-phase")], ["**A phase with an open PR is held too:**"], []),
    ([sk("create-phase")], ["**One question rides on that confirmation, never a stop of its own:**"], []),
    ([flat(sk("parallel-phase"))], ["### A reopened phase — a change request on its open PR", "`--note \"operator-reported: <what>\"`", "Then `pr-sync <P>` there (the default branch's record is stale)"], ["### A reopened phase — a team's changes on its open PR"]),
    (both("decomposition.md"), ["--base <that branch>"], []),
    (both("decomposition.md"), ["**Record the phase's PR branches** (PR rule v1)", "**Size never splits a phase:**"], []),
    ([sk("create-phase")], ["`Branches:` line", "Never split a phase for size"], push_stop),
    ([(root / "payload/claude/skills/do-whole-phase/playbooks/review.md").read_text()], ["`pr_bodies`", "Never run `review-phase`, `accept-gate` or `defer-job`, and never push."], push_stop),
    ([flat(sk("parallel-phase"))], ["This skill carries no second PR procedure."], ["1. **Push the branch.**", "**Open the PR.**"] + push_stop),
    ([sk("update-workspace")], ["the phase's draft PR opens when the review passes and closes on the operator's `accept` (`pr` skill: Ready, then a solo repo's merge by its own landing custom, never a team's); merging it on GitHub is the remote variant"], ["push → PR → CI is the remote variant"] + push_stop),
    ([sk("pr")], ["## Open the drafts, when the review passes", "opened as drafts when the review passes, closed on the operator's accept.\"", "`git push -u origin <b>`, never `--force`."], push_stop),
    ([sk("commit")], ["A phase's pushes are the `pr` skill's, never this skill's: the draft opening when its review passes, the close's solo landing, and a fix round's or a stack merge's push to an open PR's branch."], push_stop + ["A phase's one push is"]),
    ([(root / "README.en.md").read_text(encoding="utf-8")], ["and your `accept` closes it (Ready, then a solo repo's merge by its landing custom; a team repo's merge is the team's)"], ["(Ready and merge are yours)"]),
    ([(root / "README.md").read_text(encoding="utf-8")], ["여러분이 `accept`하면 close가 그 PR을 Ready로 바꿉니다"], ["(Ready와 merge는 여러분 몫입니다)"]),
    ([L["scripts/workflow.py"]], ["pr_draft=due -- when the review would pass", "the draft opens when the review passes (pr skill: Open the drafts)"],
     ["pr_push_parked", "_pr_push_stop_why", "PR push stop", "the operator's push opens"] + push_stop),
]
for texts, required, gone in checks:
    for t in texts:
        for r in required:
            assert r in t, r
        for g in gone:
            assert g not in t, g
PY
echo "pr rule test runtime: $(( $(date +%s) - pr_t0 ))s"

# ---------------------------------------------------------------------------
echo "== Test 20: P52 PR lifecycle after the draft -- pr-sync (all or nothing, ready_at once), pr-team (solo/team/unknown, --record), pr_open= on every next path and the card, the archive hold (merged releases it, --force bypasses, rotate still proposes the docs), pr_stack= (moved/merged by ancestry or record, active or archived/gone) and the base re-record, reopen-phase (nested worktree on the PR branch, its refusals, -reopen2, root in place, root phase-scope ending at pass 2), review-phase refusing a change request on a done phase with an open PR, and a multi-repo host's --repo; zero GitHub writes =="
# Every remote is a local bare repo and gh is a stub on PATH that answers canned files, logs every call and refuses any write.
lc_t0=$(date +%s)
newtmp QW; QW=$(cd "$QW" && pwd -P); QG="$QW/gh"; mkdir -p "$QG"   # the engine prints resolved paths (macOS: /private/var)
cat > "$QG/gh" <<'STUB'
#!/bin/sh
# A stub gh: canned answers from its own folder, every call logged, every write refused. Nothing reaches GitHub.
D=$(cd "$(dirname "$0")" && pwd); printf '%s\n' "$*" >> "$D/gh.log"
[ -f "$D/fail" ] && { cat "$D/fail" >&2; exit 1; }
case "$1 $2" in
  "pr view") n=$(basename "$3"); [ -f "$D/pr-$n.json" ] || { echo "GraphQL: Could not resolve to a PullRequest with the number of $n." >&2; exit 1; }; cat "$D/pr-$n.json";;
  "pr checks") cat "$D/checks.txt" 2>/dev/null; exit "$(cat "$D/checks.rc" 2>/dev/null || echo 0)";;
  api\ *) for a in "$@"; do case "$a" in -X|--method|-f|-F|--field|--raw-field) echo "stub: a write refused" >&2; exit 9;; esac; done
    [ -f "$D/collab-403" ] && { echo "gh: Must have push access to view repository collaborators. (HTTP 403)" >&2; exit 1; }; cat "$D/collab.txt" 2>/dev/null;;
  *) echo "stub: refused $*" >&2; exit 9;;
esac
STUB
chmod +x "$QG/gh"
qpr() { printf '{"state":"%s","isDraft":%s,"mergedAt":%s,"baseRefName":"%s","headRefOid":"0123456789abcdef0123456789abcdef01234567","reviewDecision":%s}\n' "$2" "$3" "$4" "${5:-main}" "${6:-null}" > "$QG/pr-$1.json"; }
# --- the nested host: a toy product with a local bare origin, its install committed ---
git init -q --bare "$QW/origin.git"; QH="$QW/host"; mkdir -p "$QH"
qw() { ( cd "$QH" && PATH="$QG:$PATH" python3 workflow/scripts/workflow.py "$@" ); }
qg() { git -C "$QH" "$@"; }; qn() { git -C "$QH/workflow" "$@"; }
qj() { python3 -c 'import json,sys
d = json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d = d.get(k) if isinstance(d, dict) else (d[int(k)] if isinstance(d, list) and len(d) > int(k) else None)
print(json.dumps(d, sort_keys=True))' "$QH/workflow/works/phases/active/$1/phase.json" "$2"; }
qsig() { { qn rev-parse HEAD; qn status --porcelain; cat "$QH/workflow/works/events.jsonl"; } | sha_stdin; }
{ qg init -q . && qg symbolic-ref HEAD refs/heads/main && qg config user.email smoke@example.invalid && qg config user.name smoke \
  && echo a > "$QH/app.txt" && qg add app.txt && qg commit -qm "chore: init" && qg remote add origin "$QW/origin.git" && qg push -q origin main \
  && qg remote set-head origin main && ( cd "$QH" && sh "$BOOT" . ) && qn config user.email smoke@example.invalid && qn config user.name smoke \
  && qw nested-convention --confirm --text "type(scope): summary" --trailers forbidden && qn add -A && qn commit -qm "chore: install"; } > "$QW/setup.txt" 2>&1 \
  || bad "lifecycle probe: the nested host failed to set up -- $(tail -3 "$QW/setup.txt")"
# a waived-gate phase cut to its review: qnew <P>; driven to done: qpass <P>
qnew() { qw new-phase --phase "$1" --name "$1 toy" --objective toy && qw accept-gate "$1" --waive --note toy && qw set-slice-status "$1.DECOMP" done; }
qpass() { { qw set-slice-status "$1.REVIEW" in_progress && : > "$QH/workflow/works/phases/active/$1/slices/$1.REVIEW/result.md" && qw review-phase "$1" --verdict pass \
  && qn add -A && qn commit -qm "chore: $1 done"; } > "$QW/pass-$1.txt" 2>&1 || bad "lifecycle probe: $1 did not pass -- $(tail -3 "$QW/pass-$1.txt")"; }
# P1: a required-gate phase done with its draft recorded the P51 way (a URL, no lifecycle state).
{ qw new-phase --phase P1 --name "Toy" --objective toy && qw accept-gate P1 --require && qw set-slice-status P1.DECOMP done \
  && qw pr-branch P1 --name feat/one && echo one >> "$QH/app.txt" && qg commit -qam "feat: one" && qg push -q -u origin feat/one \
  && qw pr-record P1 --url https://github.com/acme/toy/pull/1 && qw set-slice-status P1.REVIEW in_progress \
  && : > "$QH/workflow/works/phases/active/P1/slices/P1.REVIEW/result.md" && qw accept-gate P1 --open --walkthrough probe && qw accept-gate P1 --clear \
  && qw review-phase P1 --verdict pass && qn add -A && qn commit -qm "chore: P1 done"; } > "$QW/p1.txt" 2>&1 || bad "lifecycle probe: P1 failed -- $(tail -3 "$QW/p1.txt")"
P1J="$QH/workflow/works/phases/active/P1/phase.json"; QEV="$QH/workflow/works/events.jsonl"
# (1) a P51-era entry validates and reads unsynced: the close is due; no active phase, so the line is on the no-phase path and the card.
q_val=$(qw validate 2>&1); q_vrc=$?; q_nx=$(qw next 2>&1); q_card=$(qw next --card 2>&1)
if [ "$q_vrc" -eq 0 ] && printf '%s\n' "$q_nx" | grep -qx 'pr_open=P1 host:feat/one state=unsynced url=https://github.com/acme/toy/pull/1 -- the close is due (pr skill; pr-sync P1 first)' \
    && printf '%s\n' "$q_nx" | grep -q '^no active slice' && printf '%s\n' "$q_card" | grep -qx 'pr_open: P1 host:feat/one state=unsynced (close due)'; then
  ok "a P51-era pr entry (a URL, no lifecycle state) validates and reads state=unsynced: next's no-active-phase path and the resume card print pr_open= with the close due"
else bad "P51-era entry / pr_open= on the no-phase path wrong (validate rc=$q_vrc) -- $q_val / $q_nx / $q_card"; fi
# (2) pr-sync: gh unauthenticated and an unknown PR each exit 1 writing nothing; a draft, then ready (ready_at stamped), then a
# second ready sync keeps ready_at.
s0=$(cat "$P1J" "$QEV" | sha_stdin)
echo "gh: To get started with GitHub CLI, please run:  gh auth login" > "$QG/fail"; q_a=$(qw pr-sync P1 2>&1); q_arc=$?; rm -f "$QG/fail"
q_u=$(qw pr-sync P1 2>&1); q_urc=$?; s1=$(cat "$P1J" "$QEV" | sha_stdin)
qpr 1 OPEN true null; q_d=$(qw pr-sync P1 2>&1); q_dst=$(qj P1 pr.branches.0.state); q_dra=$(qj P1 pr.branches.0.ready_at)
qpr 1 OPEN false null main '"REVIEW_REQUIRED"'; q_r=$(qw pr-sync P1 2>&1); q_rst=$(qj P1 pr.branches.0.state); q_rra=$(qj P1 pr.branches.0.ready_at)
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["pr"]["branches"][0]["ready_at"]="2026-01-01T00:00:00Z"; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$P1J"
qw pr-sync P1 >/dev/null 2>&1; q_rra2=$(qj P1 pr.branches.0.ready_at)
if [ "$q_arc" -eq 1 ] && printf '%s\n' "$q_a" | grep -q 'gh is not authenticated .*nothing was written$' && [ "$q_urc" -eq 1 ] && printf '%s\n' "$q_u" | grep -q 'Could not resolve.*nothing was written$' && [ "$s0" = "$s1" ] \
    && printf '%s\n' "$q_d" | grep -qx 'pr_sync=host:feat/one state=draft base=main head=0123456 review=none merged_at=none' && [ "$q_dst" = '"draft"' ] && [ "$q_dra" = null ] \
    && printf '%s\n' "$q_r" | grep -qx 'pr_sync=host:feat/one state=ready base=main head=0123456 review=REVIEW_REQUIRED merged_at=none' && [ "$q_rst" = '"ready"' ] && [ "$q_rra" != null ] \
    && [ "$q_rra2" = '"2026-01-01T00:00:00Z"' ]; then
  ok "pr-sync: gh unauthenticated and an unknown PR exit 1 naming the cause and write nothing (phase.json and events.jsonl unchanged); a draft records state=draft with no ready_at, Ready stamps ready_at, and a later sync never re-stamps it"
else bad "pr-sync lifecycle wrong (rc $q_arc/$q_urc, unchanged=$([ "$s0" = "$s1" ] && echo y)) -- $q_a / $q_u / $q_d / $q_r / ready_at $q_dra $q_rra $q_rra2"; fi
# (3) pr-team, bare: solo (one collaborator), team (two, a bot dropped), solo again on a 403 (authors only); --record needs
# --evidence, records, then a re-record replaces; validate refuses a malformed ownership record.
qg remote set-url origin https://github.com/acme/toy.git
printf 'leetusik\n' > "$QG/collab.txt"; q_t1=$(qw pr-team 2>&1)
printf 'leetusik\nalice\nrenovate[bot]\n' > "$QG/collab.txt"; q_t2=$(qw pr-team 2>&1)
: > "$QG/collab-403"; q_t3=$(qw pr-team 2>&1); rm -f "$QG/collab-403"; qg remote set-url origin "$QW/origin.git"
qw pr-team --record solo > "$QW/t-noev.txt" 2>&1; q_t4=$?
q_t5=$(qw pr-team --record solo --evidence "one login" 2>&1); q_t6=$(qw pr-team --record team --evidence "two logins" 2>&1)
QMK="$QH/workflow/.agentic-nested.json"; q_own=$(python3 -c 'import json,sys; o=json.load(open(sys.argv[1]))["pr_rules"]["ownership"]; print(len(o), o[0]["mode"], o[0]["repo"])' "$QMK")
cp "$QMK" "$QW/marker.bak"; python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["pr_rules"]["ownership"][0]["mode"]="duo"; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$QMK"
qw validate > "$QW/val-own.txt" 2>&1; q_t7=$?; cp "$QW/marker.bak" "$QMK"
if printf '%s\n' "$q_t1" | grep -qx 'pr_team=host recorded=none detected=solo evidence="collaborators: 1 (leetusik); authors: 1"' \
    && printf '%s\n' "$q_t2" | grep -qx 'pr_team=host recorded=none detected=team evidence="collaborators: 2 (alice, leetusik); authors: 1"' \
    && printf '%s\n' "$q_t3" | grep -qx 'pr_team=host recorded=none detected=solo evidence="collaborators: unavailable; authors: 1"' \
    && [ "$q_t4" -eq 1 ] && grep -q 'needs --evidence.*nothing was written' "$QW/t-noev.txt" && printf '%s\n' "$q_t5" | grep -q '^pr-team: recorded -- host is solo' \
    && printf '%s\n' "$q_t6" | grep -q '^pr-team: replaced -- host is team' && [ "$q_own" = "1 team None" ] && [ "$q_t7" -ne 0 ] && grep -q 'duo' "$QW/val-own.txt" && qw validate >/dev/null 2>&1; then
  ok "pr-team: detects solo (one collaborator), team (two, a [bot] dropped) and solo from authors when collaborators answer 403; --record without --evidence writes nothing, records solo, then team replaces it (one ownership entry); validate refuses mode duo and passes restored"
else bad "pr-team wrong (noev rc $q_t4, validate rc $q_t7, ownership '$q_own') -- $q_t1 / $q_t2 / $q_t3 / $q_t5 / $q_t6 / $(cat "$QW/val-own.txt" | tail -3)"; fi
# (4) the archive hold: P2 holds two PRs (a split); a sync whose second read fails writes nothing; archive-phase refuses while they
# are unsynced; once both read merged the hold is released. P3's closed PR holds archiving, and rotate-backlog still proposes P3's docs.
{ qnew P2 && qg switch -q main && qw pr-branch P2 --name feat/two && echo two > "$QH/two.txt" && qg add two.txt && qg commit -qm "feat: two" && qg push -q -u origin feat/two \
  && qw pr-branch P2 --name feat/three --base feat/two && echo three > "$QH/three.txt" && qg add three.txt && qg commit -qm "feat: three" && qg push -q -u origin feat/three \
  && qw pr-record P2 --branch feat/two --url https://github.com/acme/toy/pull/2 && qw pr-record P2 --branch feat/three --url https://github.com/acme/toy/pull/3; } > "$QW/p2.txt" 2>&1 \
  || bad "lifecycle probe: P2 failed -- $(tail -3 "$QW/p2.txt")"
qpass P2; P2J="$QH/workflow/works/phases/active/P2/phase.json"
qpr 2 MERGED false '"2026-11-05T08:00:00Z"'; s0=$(cat "$P2J" "$QEV" | sha_stdin); q_h1=$(qw pr-sync P2 2>&1); q_h1rc=$?; s1=$(cat "$P2J" "$QEV" | sha_stdin)
q_h2=$(qw archive-phase P2 2>&1); q_h2rc=$?
qpr 3 MERGED false '"2026-11-05T09:00:00Z"' feat/two; qw pr-sync P2 >/dev/null 2>&1; q_h3=$(qw archive-phase P2 2>&1); q_h3rc=$?
{ qnew P3 && qg switch -q main && qw pr-branch P3 --name feat/four && echo four > "$QH/four.txt" && qg add four.txt && qg commit -qm "feat: four" && qg push -q -u origin feat/four \
  && qw pr-record P3 --url https://github.com/acme/toy/pull/4 && echo "- operations: a toy note" | qw phase-section P3 "Doc impact" --append; } > "$QW/p3.txt" 2>&1 || bad "lifecycle probe: P3 failed -- $(tail -3 "$QW/p3.txt")"
qpass P3; qpr 4 CLOSED false null; qw pr-sync P3 >/dev/null 2>&1
q_h4=$(qw next 2>&1); q_h5=$(qw archive-phase P3 2>&1); q_h5rc=$?; q_h6=$(qw rotate-backlog 2>&1); q_h6rc=$?
if [ "$q_h1rc" -eq 1 ] && printf '%s\n' "$q_h1" | grep -q '^pr-sync: host:feat/three .*nothing was written$' && [ "$s0" = "$s1" ] \
    && [ "$q_h2rc" -ne 0 ] && printf '%s\n' "$q_h2" | grep -q 'PR host:feat/two is unsynced, not merged' && [ "$q_h3rc" -eq 0 ] && printf '%s\n' "$q_h3" | grep -q '^archived phase P2' \
    && printf '%s\n' "$q_h4" | grep -qx 'pr_open=P3 host:feat/four state=closed url=https://github.com/acme/toy/pull/4 -- closed without merging: it holds archiving -- reopen it on GitHub and pr-sync P3, or archive-phase P3 --force' \
    && [ "$q_h5rc" -ne 0 ] && printf '%s\n' "$q_h5" | grep -q 'PR host:feat/four is closed, not merged' && printf '%s\n' "$q_h5" | grep -q 'archive-phase P3 --force is the way out' \
    && [ "$q_h6rc" -eq 0 ] && printf '%s\n' "$q_h6" | grep -qx 'docs_phase_proposal=P3' && [ -d "$QH/workflow/works/phases/active/P3" ] && [ -d "$QH/workflow/works/phases/active/P1" ]; then
  ok "the archive hold: a split's sync whose second read fails writes nothing; archive-phase refuses unsynced PRs and archives once pr-sync reads both merged; a closed PR prints its pr_open= hint and holds archiving (naming --force); rotate-backlog still proposes the held phase's docs and archives neither held phase"
else bad "archive hold wrong (rc $q_h1rc/$q_h2rc/$q_h3rc/$q_h5rc/$q_h6rc) -- $q_h1 / $q_h2 / $q_h3 / $(printf '%s\n' "$q_h4" | grep pr_) / $q_h5 / $q_h6"; fi
q_f=$(qw archive-phase P3 --force 2>&1)
printf '%s\n' "$q_f" | grep -q '^archived phase P3' && [ ! -d "$QH/workflow/works/phases/active/P3" ] && ok "archive-phase --force bypasses the PR hold (and the doc debt)" || bad "archive-phase --force did not archive the held phase -- $q_f"
# (5) pr_open= on the plain pointer and WAITING paths, then pr_stack=: P5 stacked on P4's feat/lo. A teammate's push to the lower
# branch reads lower=moved; its steps, run as printed, clear it. A true --no-ff landing of feat/lo reads lower=merged by ancestry.
{ qw new-phase --phase P4 --name lower --objective toy && qg switch -q main && qw pr-branch P4 --name feat/lo && echo lo > "$QH/lo.txt" && qg add lo.txt && qg commit -qm "feat: lo" && qg push -q -u origin feat/lo \
  && qw pr-record P4 --url https://github.com/acme/toy/pull/5 && qw new-phase --phase P5 --name upper --objective toy && qw pr-branch P5 --name feat/up --base feat/lo \
  && echo up > "$QH/up.txt" && qg add up.txt && qg commit -qm "feat: up" && qg push -q -u origin feat/up && qw pr-record P5 --url https://github.com/acme/toy/pull/6 \
  && qn add -A && qn commit -qm "chore: the stack"; } > "$QW/p45.txt" 2>&1 || bad "lifecycle probe: P4/P5 failed -- $(tail -3 "$QW/p45.txt")"
q_p1=$(qw next 2>&1); qw set-slice-status P4.DECOMP pending --stop-kind decision --on-words "an answer resumes it" >/dev/null 2>&1; q_p2=$(qw next 2>&1); q_p2c=$(qw next --card 2>&1)
qw set-slice-status P4.DECOMP in_progress >/dev/null 2>&1
newtmp QCL; { git clone -q -b main "$QW/origin.git" "$QCL/c" && git -C "$QCL/c" switch -q feat/lo && echo fix >> "$QCL/c/lo.txt" \
  && git -C "$QCL/c" -c user.email=mate@example.invalid -c user.name=mate commit -qam "fix: lo" && git -C "$QCL/c" push -q && qg fetch -q origin; } >/dev/null 2>&1
q_mv=$(qw next 2>&1 | grep '^pr_stack='); ( eval "${q_mv#* -- }" ) >/dev/null 2>&1; q_mvrc=$?; q_mv2=$(qw next 2>&1 | grep -c '^pr_stack=')
{ qg switch -q main && qg merge -q --no-ff feat/lo -m "merge feat/lo" && qg push -q origin main; } >/dev/null 2>&1
q_mg=$(qw next 2>&1 | grep '^pr_stack='); q_mgc=$(qw next --card 2>&1 | grep '^pr_stack:')
if printf '%s\n' "$q_p1" | grep -q '^pr_open=P1 host:feat/one state=ready ' && printf '%s\n' "$q_p1" | grep -qx 'current_slice=P4.DECOMP' \
    && printf '%s\n' "$q_p2" | grep -q '^pr_open=P1 host:feat/one state=ready ' && printf '%s\n' "$q_p2" | grep -q '^WAITING ON OPERATOR' && printf '%s\n' "$q_p2c" | grep -q '^pr_open: P1 host:feat/one state=ready' \
    && [ "$q_mv" = "pr_stack=P5 host:feat/up base=feat/lo lower=moved -- git -C $QH merge --no-ff origin/feat/lo; git -C $QH push" ] && [ "$q_mvrc" -eq 0 ] && [ "$q_mv2" = 0 ] \
    && [ "$q_mg" = "pr_stack=P5 host:feat/up base=feat/lo lower=merged -- git -C $QH fetch origin; git -C $QH switch feat/up; git -C $QH merge --no-ff origin/main; git -C $QH push; gh pr edit 6 --base main; python3 workflow/scripts/workflow.py pr-branch P5 --name feat/up --base main" ] \
    && [ "$q_mgc" = 'pr_stack: P5 host:feat/up base=feat/lo lower=merged (`next` prints the steps)' ]; then
  ok "pr_open= prints on next's plain pointer and WAITING paths and the card; pr_stack= reads a teammate's push to the lower branch as lower=moved, whose printed steps (merge, never rebase; push, never --force) clear it, and a true --no-ff landing as lower=merged with the fetch/switch/merge/push/gh pr edit/re-record steps, in next and the card"
else bad "pr_open= paths or pr_stack= moved/merged wrong (steps rc $q_mvrc, after $q_mv2) -- $(printf '%s\n' "$q_p1" "$q_p2" | grep 'pr_\|WAITING\|current_slice') / $q_mv / $q_mg / $q_mgc"; fi
# (6) the base re-record on a not-checked-out branch with a dirty tree: HEAD, branch and status untouched, lifecycle fields kept, no line after.
qpr 6 OPEN true null feat/lo; qw pr-sync P5 >/dev/null 2>&1; echo dirty >> "$QH/app.txt"
q_h0=$(qg rev-parse HEAD); q_s0=$(qg status --porcelain); q_b0=$(qg branch --show-current)
q_rr=$(qw pr-branch P5 --name feat/up --base main 2>&1); q_rrc=$?
q_same=$([ "$q_h0" = "$(qg rev-parse HEAD)" ] && [ "$q_s0" = "$(qg status --porcelain)" ] && [ "$q_b0" = "$(qg branch --show-current)" ] && echo y)
q_rrs=$(qj P5 pr.branches.0.state); q_rrn=$(qw next 2>&1 | grep -c '^pr_stack='); qg checkout -q -- app.txt
[ "$q_rrc" -eq 0 ] && printf '%s\n' "$q_rr" | grep -qx 'pr_branch=host:feat/up base=main' && printf '%s\n' "$q_rr" | grep -q '^pr-branch: feat/up base re-recorded from feat/lo -- no switch; nothing moved' \
  && [ "$q_same" = y ] && [ "$q_rrs" = '"draft"' ] && [ "$(qj P5 pr.branches.0.base)" = '"main"' ] && [ "$q_rrn" = 0 ] \
  && ok "pr-branch --base on a recorded branch that is not checked out, over a dirty tree, re-records the base only (HEAD, branch and status untouched, state=draft kept), and no pr_stack= line follows" \
  || bad "the base re-record wrong (rc $q_rrc, untouched '$q_same', state $q_rrs, lines $q_rrn) -- $q_rr"
# (7) a squash landing has no ancestry: no line until the lower PR's record reads merged, active and then archived; a vanished
# lower branch reads lower=gone, and an entry with no URL drops the gh step.
{ qnew P6 && qw pr-branch P6 --name feat/l2 && echo l2 > "$QH/l2.txt" && qg add l2.txt && qg commit -qm "feat: l2" && qg push -q -u origin feat/l2 && qw pr-record P6 --url https://github.com/acme/toy/pull/7 \
  && qw new-phase --phase P7 --name u2 --objective toy && qw pr-branch P7 --name feat/u2 --base feat/l2 && echo u2 > "$QH/u2.txt" && qg add u2.txt && qg commit -qm "feat: u2" && qg push -q -u origin feat/u2 \
  && qw pr-record P7 --url https://github.com/acme/toy/pull/8 && qg switch -q main && qg merge -q --squash feat/l2 && qg commit -qm "feat: l2 (squash)" && qg push -q origin main \
  && qn add -A && qn commit -qm "chore: P6 P7"; } > "$QW/p67.txt" 2>&1 || bad "lifecycle probe: P6/P7 failed -- $(tail -3 "$QW/p67.txt")"
q_sq0=$(qw next 2>&1 | grep -c '^pr_stack=P7'); qpass P6; qpr 7 MERGED false '"2026-11-05T10:00:00Z"'; qw pr-sync P6 >/dev/null 2>&1
q_sq1=$(qw next 2>&1 | grep '^pr_stack=P7'); qw archive-phase P6 >/dev/null 2>&1; q_sq2=$(qw next 2>&1 | grep '^pr_stack=P7')
{ qw new-phase --phase P8 --name u3 --objective toy && qg switch -q -c feat/l3 && qw pr-branch P8 --name feat/u3 --base feat/l3 && qg branch -q -D feat/l3; } > "$QW/p8.txt" 2>&1 || bad "lifecycle probe: P8 failed -- $(tail -3 "$QW/p8.txt")"
q_gone=$(qw next 2>&1 | grep '^pr_stack=P8')
q_sqx="pr_stack=P7 host:feat/u2 base=feat/l2 lower=merged -- git -C $QH fetch origin; git -C $QH switch feat/u2; git -C $QH merge --no-ff origin/main; git -C $QH push; gh pr edit 8 --base main; python3 workflow/scripts/workflow.py pr-branch P7 --name feat/u2 --base main"
[ "$q_sq0" = 0 ] && [ "$q_sq1" = "$q_sqx" ] && [ "$q_sq2" = "$q_sqx" ] && [ ! -d "$QH/workflow/works/phases/active/P6" ] \
  && [ "$q_gone" = "pr_stack=P8 host:feat/u3 base=feat/l3 lower=gone -- git -C $QH fetch origin; git -C $QH merge --no-ff origin/main; git -C $QH push; python3 workflow/scripts/workflow.py pr-branch P8 --name feat/u3 --base main" ] \
  && ok "pr_stack=: a squash landing prints nothing until the lower PR's record reads merged, then lower=merged from the active record and, archived, from the archived one; a vanished lower branch reads lower=gone, and with no URL the gh pr edit step is dropped" \
  || bad "pr_stack= squash/record/gone wrong (no-record lines $q_sq0) -- $q_sq1 / $q_sq2 / $q_gone"
qg switch -q main; qn add -A; qn commit -qm "chore: before the reopen" >/dev/null 2>&1
# (8) the nested reopen's refusals, each writing nothing: review-phase changes_requested on a done phase with an open PR, an empty
# note, a phase not done, an archived phase, the host's main checkout holding the PR branch, and every PR recorded merged.
r0=$(qsig)
q_c1=$(qw review-phase P1 --verdict changes_requested --note x 2>&1); q_c1rc=$?
q_c2=$(qw reopen-phase P1 --note "  " 2>&1); q_c2rc=$?
q_c3=$(qw reopen-phase P4 --note "team-reported: x" 2>&1); q_c3rc=$?
q_c4=$(qw reopen-phase P3 --note "team-reported: x" 2>&1); q_c4rc=$?
qg switch -q feat/one; q_c5=$(qw reopen-phase P1 --note "team-reported: x" 2>&1); q_c5rc=$?; qg switch -q main
cp "$P1J" "$QW/p1.bak"; python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["pr"]["branches"][0]["state"]="merged"; json.dump(d,open(sys.argv[1],"w"),indent=2)' "$P1J"
q_c6=$(qw reopen-phase P1 --note "team-reported: x" 2>&1); q_c6rc=$?; cp "$QW/p1.bak" "$P1J"; r1=$(qsig)
if [ "$q_c1rc" -ne 0 ] && printf '%s\n' "$q_c1" | grep -q 'P1 is done and its PR is still open .*reopen-phase P1' && [ "$q_c2rc" -ne 0 ] && printf '%s\n' "$q_c2" | grep -q -- '--note is empty.*operator-reported: <what>' \
    && [ "$q_c3rc" -ne 0 ] && printf '%s\n' "$q_c3" | grep -q "P4 is 'planned', not 'done'" && [ "$q_c4rc" -ne 0 ] && printf '%s\n' "$q_c4" | grep -q 'P3 is archived' \
    && [ "$q_c5rc" -ne 0 ] && printf '%s\n' "$q_c5" | grep -q "checked out in the main checkout .* switch main" && [ "$q_c6rc" -ne 0 ] && printf '%s\n' "$q_c6" | grep -q 'every recorded PR reads state=merged .*pr-sync P1' \
    && [ "$(printf '%s\n' "$q_c1" "$q_c2" "$q_c3" "$q_c4" "$q_c5" "$q_c6" | grep -c 'nothing was written')" = 6 ] && [ "$r0" = "$r1" ] && [ "$(qj P1 status)" = '"done"' ]; then
  ok "reopen-phase refuses an empty note, a phase not done, an archived phase, the host's main checkout holding the PR branch and every PR recorded merged, and review-phase refuses changes_requested on a done phase with an open PR pointing at reopen-phase; each writes nothing (nested HEAD, status and events unchanged)"
else bad "the reopen refusals wrong (rc $q_c1rc/$q_c2rc/$q_c3rc/$q_c4rc/$q_c5rc/$q_c6rc, unchanged=$([ "$r0" = "$r1" ] && echo y)) -- $q_c1 / $q_c2 / $q_c3 / $q_c4 / $q_c5 / $q_c6"; fi
# (9) the nested reopen: one stamp commit, the worktree pair on the PR branch, next in both checkouts, a refusal from the phase's
# own stream, the fix and the pass there with phase-scope covering it, host main untouched; a still-stamped pair refuses a second
# reopen until the teardown, and a stale branch name gives -reopen2.
q_m0=$(qg rev-parse main); q_n0=$(qn rev-list --count HEAD)
q_ro=$(qw reopen-phase P1 --note "team-reported: rename the toy flag" 2>&1); q_rorc=$?
QWT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["execution"]["host_worktree"] or "")' "$P1J" 2>/dev/null)
qwt() { ( cd "$QWT" && PATH="$QG:$PATH" python3 workflow/scripts/workflow.py "$@" ); }
git -C "$QWT/workflow" config user.email smoke@example.invalid; git -C "$QWT/workflow" config user.name smoke
q_dn=$(qw next 2>&1); q_wn=$(qwt next 2>&1); q_ws=$(qwt reopen-phase P1 --note "team-reported: again" 2>&1); q_wsrc=$?
{ qwt set-slice-status P1.REVIEW in_progress && echo fix > "$QWT/fix.py" && git -C "$QWT" add fix.py && git -C "$QWT" commit -qm "fix: rename" \
  && qwt accept-gate P1 --open --walkthrough again && qwt accept-gate P1 --clear && qwt review-phase P1 --verdict pass && git -C "$QWT/workflow" add -A && git -C "$QWT/workflow" commit -qm "chore: P1 re-pass"; } > "$QW/repass.txt" 2>&1
q_rprc=$?; q_sc=$(qwt phase-scope P1 2>&1)
if [ "$q_rorc" -eq 0 ] && printf '%s\n' "$q_ro" | grep -qx "reopened=P1 branch=host:feat/one worktree=$QH/.claude/worktrees/P1-toy" && [ "$(( $(qn rev-list --count HEAD) - q_n0 ))" = 1 ] \
    && [ "$(qn log -1 --format=%s)" = "chore(works): reopen P1 in its own worktree" ] && [ "$(git -C "$QWT" branch --show-current)" = feat/one ] \
    && [ "$(qj P1 review.status)" = '"changes_requested"' ] && [ "$(qj P1 review.note)" = '"team-reported: rename the toy flag"' ] && [ "$(qj P1 review.fix_passes)" = 1 ] \
    && printf '%s\n' "$q_dn" | grep -q '^parallel_phases_elsewhere=P1:phase/P1-toy ' && printf '%s\n' "$q_wn" | grep -qx 'current_phase=P1' && printf '%s\n' "$q_wn" | grep -qx 'current_slice=P1.REVIEW' \
    && [ "$q_wsrc" -ne 0 ] && printf '%s\n' "$q_ws" | grep -q "P1 is 'in_progress', not 'done'" \
    && [ "$q_rprc" -eq 0 ] && grep -q '^phase P1 review: pass' "$QW/repass.txt" && printf '%s\n' "$q_sc" | grep -qx '  A fix.py' && printf '%s\n' "$q_sc" | grep -qx '  M app.txt' \
    && [ "$q_m0" = "$(qg rev-parse main)" ]; then
  ok "reopen-phase on a nested install: one stamp commit, a worktree pair on the PR branch feat/one, the review changes_requested with the team's note; the default stream lists it elsewhere, the worktree's next selects P1.REVIEW and refuses a second reopen there; the fix and the pass land in the worktree, phase-scope covers fix.py, and host main is untouched"
else bad "the nested reopen wrong (rc $q_rorc/$q_wsrc/$q_rprc) -- $q_ro / $(printf '%s\n' "$q_dn" | grep parallel_) / $(printf '%s\n' "$q_wn" | grep current_) / $q_ws / $(tail -3 "$QW/repass.txt") / $q_sc"; fi
{ qn add -A && qn commit -qm "chore: rebuild"; qn merge -q --no-ff -m "merge(P1): Toy" phase/P1-toy || { qn checkout -q --theirs works/backlog.md && qn add -A && qn commit -qm "merge(P1): Toy"; }; \
  qw parallel-merge-finish && qn add -A && qn commit -qm "chore: integrated"; } > "$QW/merge.txt" 2>&1
q_st=$(qw reopen-phase P1 --note "team-reported: again" 2>&1); q_strc=$?
{ qw parallel-teardown P1 && qn add -A && qn commit -qm "chore: teardown" && qn branch phase/P1-toy; } > "$QW/teardown.txt" 2>&1
q_r2=$(qw reopen-phase P1 --note "operator-reported: again" 2>&1); q_r2rc=$?
if [ "$(qj P1 status)" != null ] && [ "$q_strc" -ne 0 ] && printf '%s\n' "$q_st" | grep -q 'parallel-teardown P1 first' \
    && [ "$q_r2rc" -eq 0 ] && printf '%s\n' "$q_r2" | grep -qx 'branch=phase/P1-toy-reopen2' && printf '%s\n' "$q_r2" | grep -q '^reopened=P1 branch=host:feat/one ' \
    && printf '%s\n' "$q_r2" | grep -q "^next: .* -- read the operator's request (the reopen note 'operator-reported: again', plus any PR comment or failing check it points at), cut fix slices" \
    && ! printf '%s\n' "$q_r2" | grep -q "team's review" && printf '%s\n' "$q_ro" | grep -q "^next: .* -- read the team's review (gh pr view <n> --json reviews,comments), cut fix slices" \
    && [ "$q_m0" = "$(qg rev-parse main)" ] && ! git -C "$QH" merge-base --is-ancestor feat/one main; then
  ok "after the integration a still-stamped pair refuses a second reopen (parallel-teardown first); after the teardown, with the old phase branch still present, the second reopen (operator-reported) cuts phase/P1-toy-reopen2 and its next: line reads the operator's request, never the team's review (the first, team-reported, reads the team's); host main never moved and feat/one is not in it"
else bad "the still-stamped refusal or -reopen2 wrong (rc $q_strc/$q_r2rc) -- $q_st / $q_r2 / $(tail -3 "$QW/merge.txt") / $(tail -3 "$QW/teardown.txt")"; fi
# (10) root: pr-team reads unknown with no origin and no commits; the reopen refuses --worktree, a checkout off the PR branch and a
# side branch, then runs in place on feat/toy; with the reopen committed beside the fix, phase-scope ends at the second pass.
newtmp QRW; QRW=$(cd "$QRW" && pwd -P); QR="$QRW/ws"; mkdir -p "$QR"; git init -q --bare "$QRW/origin.git"
qr() { ( cd "$QR" && PATH="$QG:$PATH" python3 scripts/workflow.py "$@" ); }; qrg() { git -C "$QR" "$@"; }
{ qrg init -q . && qrg symbolic-ref HEAD refs/heads/main && qrg config user.email smoke@example.invalid && qrg config user.name smoke && sh "$BOOT" "$QR" --at-root --name R --summary r; } > "$QRW/install.txt" 2>&1
q_ru=$(qr pr-team 2>&1)
{ echo a > "$QR/app.py" && qrg add -A && qrg commit -qm baseline && qrg remote add origin "$QRW/origin.git" \
  && qr new-phase --phase P1 --name toy --objective toy && qr accept-gate P1 --require && qr set-slice-status P1.DECOMP done && qrg add -A && qrg commit -qm p1 && qrg push -q origin main \
  && qr pr-branch P1 --name feat/toy && echo b >> "$QR/app.py" && qrg commit -qam "feat: toy" && qr pr-record P1 --url https://github.com/acme/r/pull/7 \
  && qr set-slice-status P1.REVIEW in_progress && : > "$QR/works/phases/active/P1/slices/P1.REVIEW/result.md" && qr accept-gate P1 --open --walkthrough w && qr accept-gate P1 --clear \
  && qr review-phase P1 --verdict pass && qrg add -A && qrg commit -qm "p1 done" && qrg push -q -u origin feat/toy; } > "$QRW/setup.txt" 2>&1 || bad "root reopen probe: setup failed -- $(tail -3 "$QRW/setup.txt")"
q_ro1=$(qr next 2>&1 | grep '^pr_open='); q_rw=$(qr reopen-phase P1 --note "team-reported: x" --worktree "$QRW/wt" 2>&1); q_rwrc=$?
qrg switch -q main; q_rm=$(qr reopen-phase P1 --note "team-reported: x" 2>&1); q_rmrc=$?; qrg switch -q feat/toy
qrg switch -q -c feat/side; q_rs=$(qr reopen-phase P1 --note "team-reported: x" 2>&1); q_rsrc=$?; qrg switch -q feat/toy
q_ri=$(qr reopen-phase P1 --note "team-reported: rename" 2>&1); q_rirc=$?; q_rin=$(qr next 2>&1)
{ echo fix > "$QR/fix.py" && qrg add -A && qrg commit -qm "fix: rename" && qr set-slice-status P1.REVIEW in_progress && qr accept-gate P1 --open --walkthrough w \
  && qr accept-gate P1 --clear && qr review-phase P1 --verdict pass && qrg add -A && qrg commit -qm "p1 pass 2" && echo later > "$QR/later.py" && qrg add later.py && qrg commit -qm "feat: later"; } > "$QRW/fix.txt" 2>&1
q_rsc=$(qr phase-scope P1 2>&1); q_rp2=$(qrg rev-parse HEAD~1)
if printf '%s\n' "$q_ru" | grep -qx 'pr_team=root recorded=none detected=unknown evidence="collaborators: unavailable; authors: unavailable"' \
    && [ "$q_ro1" = 'pr_open=P1 root:feat/toy state=unsynced url=https://github.com/acme/r/pull/7 -- the close is due (pr skill; pr-sync P1 first)' ] \
    && [ "$q_rwrc" -ne 0 ] && printf '%s\n' "$q_rw" | grep -q 'at root the reopen runs in place' && [ "$q_rmrc" -ne 0 ] && printf '%s\n' "$q_rm" | grep -q "P1 is 'planned', not 'done'.* at root a phase's record is only as current as this checkout's branch" \
    && [ "$q_rsrc" -ne 0 ] && printf '%s\n' "$q_rs" | grep -q 'this checkout is on feat/side. Either switch here at a slice boundary (git switch feat/toy)' \
    && [ "$q_rirc" -eq 0 ] && printf '%s\n' "$q_ri" | grep -qx "reopened=P1 branch=root:feat/toy worktree=$QR" && printf '%s\n' "$q_rin" | grep -qx 'current_slice=P1.REVIEW' \
    && printf '%s\n' "$q_rsc" | grep -q "^head=$q_rp2 " && printf '%s\n' "$q_rsc" | grep -qx '  A fix.py' && ! printf '%s\n' "$q_rsc" | grep -q 'later.py' \
    && [ "$(qrg rev-parse main)" = "$(qrg rev-parse origin/main)" ]; then
  ok "root: pr-team reads unknown with no origin and no commits; reopen-phase refuses --worktree, the default branch (P1 planned there) and a side branch (naming git switch feat/toy), then reopens in place on feat/toy; with the reopen committed beside the fix, phase-scope ends at the second pass (fix.py in, a later commit out)"
else bad "the root reopen wrong (rc $q_rwrc/$q_rmrc/$q_rsrc/$q_rirc) -- $q_ru / $q_ro1 / $q_rw / $q_rm / $q_rs / $q_ri / $(printf '%s\n' "$q_rsc" | grep 'head=\|^  ') / pass2=$q_rp2"; fi
# (11) a multi-repo host: pr-sync --repo reads one repo's PR; pr-team needs --repo there; the pr_stack= steps carry --repo; the
# reopen needs --host-branch and builds its set from the open PR branches.
newtmp QMW; QMW=$(cd "$QMW" && pwd -P); QM="$QMW/host"; mkdir -p "$QM"
for r in api web; do git init -q --bare "$QMW/$r.git"; mkdir -p "$QM/$r"; ( cd "$QM/$r" && git init -q . && git symbolic-ref HEAD refs/heads/main && git config user.email smoke@example.invalid \
  && git config user.name smoke && echo "$r" > "$r.txt" && git add -A && git commit -qm "feat: $r" && git remote add origin "$QMW/$r.git" && git push -q origin main && git remote set-head origin main ) >/dev/null 2>&1; done
qm() { ( cd "$QM" && PATH="$QG:$PATH" python3 workflow/scripts/workflow.py "$@" ); }
{ env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid sh "$BOOT" "$QM" \
  && git -C "$QM" config user.email smoke@example.invalid && git -C "$QM" config user.name smoke && git -C "$QM/workflow" config user.email smoke@example.invalid && git -C "$QM/workflow" config user.name smoke \
  && qm new-phase --phase P1 --name multi --objective toy && qm accept-gate P1 --waive --note toy && qm set-slice-status P1.DECOMP done \
  && qm pr-branch P1 --repo api --name feat/api && echo x >> "$QM/api/api.txt" && git -C "$QM/api" commit -qam "feat: x" && git -C "$QM/api" push -q -u origin feat/api \
  && qm pr-branch P1 --repo web --name feat/web && echo y >> "$QM/web/web.txt" && git -C "$QM/web" commit -qam "feat: y" && git -C "$QM/web" push -q -u origin feat/web \
  && qm pr-record P1 --repo api --url https://github.com/acme/api/pull/11 && qm pr-record P1 --repo web --url https://github.com/acme/web/pull/21 \
  && qm set-slice-status P1.REVIEW in_progress && : > "$QM/workflow/works/phases/active/P1/slices/P1.REVIEW/result.md" && qm review-phase P1 --verdict pass \
  && git -C "$QM/workflow" add -A && git -C "$QM/workflow" commit -qm "P1 done"; } > "$QMW/setup.txt" 2>&1 || bad "multi-repo lifecycle probe: setup failed -- $(tail -3 "$QMW/setup.txt")"
mv "$QG/gh.log" "$QG/gh.log.nested" 2>/dev/null
qpr 11 OPEN false null; q_ms=$(qm pr-sync P1 --repo api 2>&1); q_msrc=$?; q_mslog=$(cat "$QG/gh.log" 2>/dev/null)
q_mt0=$(qm pr-team 2>&1); q_mt0rc=$?; q_mt=$(qm pr-team --repo api 2>&1); q_mtr=$(qm pr-team --record solo --repo api --evidence "one author" 2>&1); q_mo=$(qm next 2>&1 | grep '^pr_open=P1 api:')
{ qm new-phase --phase P2 --name up --objective toy && qm pr-branch P2 --repo api --name feat/api2 --base feat/api && echo z >> "$QM/api/api.txt" && git -C "$QM/api" commit -qam "feat: z" \
  && git -C "$QM/api" push -q -u origin feat/api2 && qm pr-record P2 --repo api --url https://github.com/acme/api/pull/12 && git -C "$QM/api" switch -q main \
  && git -C "$QM/api" merge -q --no-ff feat/api -m "merge feat/api" && git -C "$QM/api" push -q origin main && git -C "$QM/web" switch -q main \
  && git -C "$QM/workflow" add -A && git -C "$QM/workflow" commit -qm "P2"; } > "$QMW/p2.txt" 2>&1 || bad "multi-repo lifecycle probe: P2 failed -- $(tail -3 "$QMW/p2.txt")"
q_mst=$(qm next 2>&1 | grep '^pr_stack=')
q_mr0=$(qm reopen-phase P1 --note "team-reported: x" 2>&1); q_mr0rc=$?
q_mr=$(qm reopen-phase P1 --note "team-reported: x" --host-branch hostfix 2>&1); q_mrrc=$?
if [ "$q_msrc" -eq 0 ] && printf '%s\n' "$q_ms" | grep -qx 'pr_sync=api:feat/api state=ready base=main head=0123456 review=none merged_at=none' && ! printf '%s\n' "$q_ms" | grep -q 'web:' \
    && [ "$q_mslog" = "pr view https://github.com/acme/api/pull/11 --json state,isDraft,mergedAt,baseRefName,headRefOid,reviewDecision" ] \
    && [ "$q_mt0rc" -ne 0 ] && printf '%s\n' "$q_mt0" | grep -q 'needs --repo <name> (registered: api, web)' && printf '%s\n' "$q_mt" | grep -q '^pr_team=api recorded=none detected=solo ' \
    && printf '%s\n' "$q_mtr" | grep -q '^pr-team: recorded -- api is solo' && printf '%s\n' "$q_mo" | grep -q "the close's merge is due" \
    && [ "$q_mst" = "pr_stack=P2 api:feat/api2 base=feat/api lower=merged -- git -C $QM/api fetch origin; git -C $QM/api switch feat/api2; git -C $QM/api merge --no-ff origin/main; git -C $QM/api push; gh pr edit 12 --base main; python3 workflow/scripts/workflow.py pr-branch P2 --repo api --name feat/api2 --base main" ] \
    && [ "$q_mr0rc" -ne 0 ] && printf '%s\n' "$q_mr0" | grep -q -- '--host-branch <name> -- nothing was written' \
    && [ "$q_mrrc" -eq 0 ] && printf '%s\n' "$q_mr" | grep -qx "reopened=P1 branch=api:feat/api,web:feat/web worktree=$QM/.claude/worktrees/P1-multi"; then
  ok "multi-repo: pr-sync --repo api reads only api's PR (one gh call); pr-team needs --repo, reads api: and records it solo (its pr_open= hint then says the merge is due); the pr_stack= steps run in the api checkout and re-record with --repo api; the reopen refuses with no --host-branch, then builds the set api:feat/api,web:feat/web"
else bad "multi-repo lifecycle wrong (rc $q_msrc/$q_mt0rc/$q_mr0rc/$q_mrrc) -- $q_ms / log: $q_mslog / $q_mt0 / $q_mt / $q_mtr / $q_mo / $q_mst / $q_mr0 / $q_mr"; fi
# (12) zero GitHub writes: every call the stub saw is a read (pr view, the collaborators GET).
cat "$QG/gh.log.nested" "$QG/gh.log" 2>/dev/null > "$QG/gh.all"
q_w=$(grep -cvE '^(pr view https://github\.com/[^ ]+ --json [a-zA-Z,]+|api repos/[^ ]+/collaborators --paginate --jq \.\[\]\.login)$' "$QG/gh.all")
[ "$q_w" = 0 ] && [ "$(grep -c '' "$QG/gh.all")" -gt 10 ] && ok "zero GitHub writes: every one of the $(grep -c '' "$QG/gh.all") calls the stub gh saw is a read (pr view --json, the collaborators GET)" \
  || bad "the stub gh saw a call that is not a read -- $(grep -vE '^(pr view |api repos/)' "$QG/gh.all" | head -3)"
echo "pr lifecycle test runtime: $(( $(date +%s) - lc_t0 ))s"

# The engine counts a review cycle's fix passes: the first changes_requested prints the fix-slice hint and no count,
# a blocked verdict adds nothing, the second prints fix_passes=2 and the stop in place of the hint, and a pass
# ends the cycle (the next change request counts one again). The reopen above starts its cycle at one.
qr new-phase --phase P9 --name count --objective count >/dev/null 2>&1
fp1=$(qr review-phase P9 --verdict changes_requested --note one 2>&1)
fpb=$(qr review-phase P9 --verdict blocked --note wait 2>&1)
fp2=$(qr review-phase P9 --verdict changes_requested --note two 2>&1)
fpn() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["review"].get("fix_passes"))' "$QR/works/phases/active/P9/phase.json"; }
fp2n=$(fpn); qr accept-gate P9 --waive --note probe >/dev/null 2>&1; fpp=$(qr review-phase P9 --verdict pass 2>&1); fppn=$(fpn)
fp3=$(qr review-phase P9 --verdict changes_requested --note three 2>&1); fp3n=$(fpn)
if ! printf '%s\n' "$fp1$fpb" | grep -q 'fix_passes=' && printf '%s\n' "$fp1" | grep -q '^create fix slices' \
    && printf '%s\n' "$fp2" | grep -q "^fix_passes=2: the one fix pass already ran -- a further fix needs the operator's word" \
    && printf '%s\n' "$fp2" | grep -q 'set-slice-status P9.REVIEW pending --stop-kind decision' \
    && ! printf '%s\n' "$fp2" | grep -q '^create fix slices' && [ "$fp2n" = 2 ] \
    && ! printf '%s\n' "$fp3" | grep -q 'fix_passes=' && printf '%s\n' "$fp3" | grep -q '^create fix slices' && [ "$fp3n" = 1 ]; then
  ok "review-phase counts the cycle's fix passes: the hint and no count on the first changes_requested, fix_passes=2 with the stop in its place on the second, a blocked verdict adds none, a pass clears it"
else bad "the fix-pass count is wrong ($fp2n/$fppn/$fp3n) -- $fp1 / $fpb / $fp2 / $fpp / $fp3"; fi

# ---------------------------------------------------------------------------
echo "== Test 21: cloud mode at the command boundary -- inert without .hi2vi/link.json (no socket opened, no .hi2vi written); with a link, against a local fake hi2vi: one batch after a command (its own files origin command, an agent's result.md origin carried, the P9 records, both headers, the key only as a Bearer), equal content sends nothing, an archive goes as move ops and events.jsonl only as appends, a cloud-only change is pulled at the next command and the generated files rebuilt =="
cl_t0=$(date +%s)
newtmp CLW; CL="$CLW/host"; CLX="$CLW/xdg"; CL_OUT="$CLW/out.txt"; : > "$CL_OUT"
cl() { ( cd "$CL" && XDG_CONFIG_HOME="$CLX" python3 workflow/scripts/workflow.py "$@" ) 2>&1 | tee -a "$CL_OUT"; }
# One engine command under a socket guard: any connect (or urlopen) ends the process with 97.
cl_nosock() { ( cd "$CL" && XDG_CONFIG_HOME="$CLX" python3 - "$@" <<'PY'
import os, runpy, socket, sys, urllib.request
def guard(*a, **k):
    sys.stderr.write("SOCKET-OPENED\n")
    os._exit(97)
socket.socket.connect = guard
socket.create_connection = guard
urllib.request.urlopen = guard
urllib.request.OpenerDirector.open = guard
sys.argv = ["workflow/scripts/workflow.py"] + sys.argv[1:]
runpy.run_path("workflow/scripts/workflow.py", run_name="__main__")
PY
); }
{ env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid sh "$BOOT" "$CL" \
  && git -C "$CL" config user.email smoke@example.invalid && git -C "$CL" config user.name smoke \
  && git -C "$CL/workflow" config user.email smoke@example.invalid && git -C "$CL/workflow" config user.name smoke; } > "$CLW/setup.txt" 2>&1 \
  || bad "cloud probe: the install failed -- $(tail -3 "$CLW/setup.txt")"
# (a) local mode: no link file, so no command opens a socket or writes .hi2vi/ (byte-equal: the whole suite).
cl_in=""
for c in "next" "new-phase --phase P1 --name One --objective toy" "new-phase --phase P2 --name Two --objective toy" \
    "defer-job --title a --reason r --trigger t --source manual" "agenda-add --title x" "rebuild" "validate" "next --card"; do
  # shellcheck disable=SC2086
  cl_nosock $c > "$CLW/nosock.txt" 2>&1; [ "$?" = 97 ] && cl_in="$cl_in [$c: $(tail -1 "$CLW/nosock.txt")]"
done
[ -z "$cl_in" ] && [ ! -e "$CL/workflow/.hi2vi" ] && [ -d "$CL/workflow/works/phases/active/P2" ] \
  && ok "local mode: with no .hi2vi/link.json, next, new-phase, defer-job, agenda-add, rebuild, validate and next --card open no socket and write no .hi2vi/" \
  || bad "local mode reached the network or wrote .hi2vi/ --$cl_in $(ls -a "$CL/workflow/.hi2vi" 2>/dev/null)"
# (b) link the checkout by hand to a fake hi2vi on a free port (the link command itself is not part of this check).
CLK="cloud-smoke-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
printf '%s\n' "$CLK" > "$CLW/key"; chmod 600 "$CLW/key"
python3 "$REPO_ROOT/tests/fake_hi2vi.py" --dir "$CLW/fake" --port-file "$CLW/port" --key-file "$CLW/key" \
  --project proj-1 --org org-1 --lifetime 600 > "$CLW/fake.txt" 2>&1 &
CL_PID=$!
for _ in $(seq 1 100); do [ -s "$CLW/port" ] && break; sleep 0.1; done
CLS="http://127.0.0.1:$(cat "$CLW/port" 2>/dev/null)"
mkdir -p "$CL/workflow/.hi2vi" "$CLX/hi2vi" && chmod 700 "$CLX/hi2vi"
python3 - "$CL/workflow/.hi2vi/link.json" "$CLX/hi2vi/workspace-keys.json" "$CLS" "$CLW/key" <<'PY' || bad "cloud probe: could not write the link"
import json, os, sys
link, keys, server, keyfile = sys.argv[1:]
with open(link, "w") as f:
    json.dump({"schema": 1, "server": server, "org_id": "org-1", "project_id": "proj-1", "linked_at": "2026-11-18T00:00:00Z"}, f)
with open(keyfile) as f:
    key = f.read().strip()
fd = os.open(keys, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump({server: {"proj-1": {"key": key, "org_id": "org-1", "saved_at": "2026-11-18T00:00:00Z"}}}, f)
PY
cl_mark() { if [ -f "$CLW/fake/requests.jsonl" ]; then grep -c '' "$CLW/fake/requests.jsonl"; else echo 0; fi; }
# cl_check <mark> <check> [args]: one named assertion over the fake's requests since <mark>, its state and base.json.
cl_check() { python3 - "$CLW/fake/requests.jsonl" "$CLS" "$CL/workflow" "$@" <<'PY'
import http.client, json, sys
from pathlib import Path
from urllib.parse import urlparse
log, server, root, mark, check, extra = sys.argv[1], sys.argv[2], Path(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6:]
lines = Path(log).read_text().splitlines() if Path(log).exists() else []
R = [json.loads(l) for l in lines[mark:]]
C = [r for r in R if r["path"].endswith("/commit")]
ops = [op for c in C for op in c["batch"]["ops"]]
u = urlparse(server)
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("GET", "/_fake/state")
S = json.loads(conn.getresponse().read())
base = json.loads((root / ".hi2vi/base.json").read_text()) if (root / ".hi2vi/base.json").exists() else {}
live = {p: f for p, f in S["files"].items() if not f["deleted"]}
def need(cond, why):
    if not cond:
        print(why)
        sys.exit(1)
need(R and all(r["checkout"] and (r["engine"] or "").startswith("v") and r["auth"] == "ok" for r in R),
     f"a request lacked X-Hi2vi-Checkout, X-Hi2vi-Engine: v<NN> or the Bearer key: {R[:1]}")
need(all(op["op"] != "put" or op["path"] != "works/events.jsonl" for op in ops), "works/events.jsonl went as a put")
if check == "first":
    need(len(C) == 1 and C[0]["status"] == 200, f"one batch expected, got {[c['status'] for c in C]}")
    need(all(op["origin"] == "carried" for op in ops), "a first sync's files are carried")
    need(all(op["op"] in ("put", "append") and op.get("base_rev") is None for op in ops), "a first sync only adds")
    need(any(op["op"] == "append" and op["path"] == "works/events.jsonl" for op in ops), "events.jsonl not sent as an append")
    need(not any(p.startswith(("works/templates/", "docs/current/")) or p in ("works/state.json", "works/index.json",
         "works/backlog.md", "works/.workspace-version.json") for p in live), f"a non-truth file reached the cloud: {sorted(live)}")
    need("works/phases/active/P2/phase.json" in live and "docs/index.json" in live, "a truth file is missing in the cloud")
    need(C[0]["batch"]["derived"] == ["works/index.json", "works/state.json"], f"the P9 records: {C[0]['batch']['derived']}")
    need(base.get("head") == S["head"] == 1 and set(base.get("files", {})) == set(live), "base.json does not match the cloud")
elif check == "carried":
    need(len(C) == 1 and C[0]["status"] == 200 and C[0]["batch"]["command"].startswith("defer-job "), "one defer-job batch expected")
    by = {(op["op"], op.get("path")): op for op in ops}
    res = by.get(("put", "works/phases/active/P1/slices/P1.DECOMP/result.md"))
    need(res is not None and res["origin"] == "carried" and res["base_rev"] is None, f"result.md: {res}")
    dj = [op for op in ops if op.get("path", "").endswith("/deferred.json")]
    need(dj and all(op["op"] == "put" and op["origin"] == "command" for op in dj), f"deferred.json: {dj}")
    ev = by.get(("append", "works/events.jsonl"))
    need(ev is not None and ev["origin"] == "command" and ev["lines"] >= 1, f"events: {ev}")
    need(C[0]["batch"]["derived"] == ["works/index.json", "works/state.json"], "the P9 records")
    need(base.get("head") == S["head"] and all(base["files"][p]["rev"] == live[p]["rev"] for p in live), "base.json not updated on 200")
elif check == "noop":
    need(not C and len([r for r in R if r["path"].endswith("/head")]) >= 2, f"equal content sent {len(C)} batch(es)")
elif check == "archive":
    need(len(C) == 1 and C[0]["status"] == 200, "one archive batch expected")
    mv = [op for op in ops if op["op"] == "move"]
    need(mv and all(op["from"].startswith("works/phases/active/P1/") and op["to"].startswith("works/phases/archived/") for op in mv), f"moves: {mv}")
    need(not [op for op in ops if op["op"] == "delete"], f"deletes sent: {[op for op in ops if op['op'] == 'delete']}")
    need(any(op["from"].endswith("/P1.DECOMP/result.md") for op in mv), "the carried result.md did not move")
    need([op["op"] for op in ops if op.get("path") == "works/events.jsonl"] == ["append"], "events.jsonl not one append")
    need(not [p for p in live if p.startswith("works/phases/active/P1/")], "P1 still live in the cloud")
elif check == "pulled":
    need(any(r["path"].endswith("/manifest") for r in R), "no manifest was read")
    need(any("works/phases/active/P2/phase.json" in (r.get("paths") or []) for r in R), "phase.json was not fetched")
    need(base.get("head") == S["head"], f"base head {base.get('head')} != cloud head {S['head']}")
    need(json.loads((root / "works/phases/active/P2/phase.json").read_text())["name"] == "Two, renamed in hi2vi", "disk not pulled")
print("ok")
PY
}
cl_m=$(cl_mark); cl next >/dev/null; cl_r=$(cl_check "$cl_m" first)
[ "$cl_r" = ok ] && ok "linked: the first command sends the truth set as one carried batch (works/events.jsonl as an append, never generated files, templates or the version marker), with the two P9 records; every request carries X-Hi2vi-Checkout, X-Hi2vi-Engine: v<NN> and the Bearer key; base.json holds the cloud's head" \
  || bad "linked first batch wrong -- $cl_r"
# (c) an agent writes result.md with plain file I/O; the next command's batch carries it.
printf 'an agent wrote this\n' > "$CL/workflow/works/phases/active/P1/slices/P1.DECOMP/result.md"
cl_m=$(cl_mark); cl defer-job --title b --reason r --trigger t --source manual >/dev/null; cl_r=$(cl_check "$cl_m" carried)
[ "$cl_r" = ok ] && ok "an agent-written result.md rides defer-job's one batch with origin carried, beside the command's deferred.json (origin command) and its events.jsonl lines (an append), and base.json takes the revisions on 200" \
  || bad "the carried batch wrong -- $cl_r"
# (d) equal content: the same bytes rewritten, then a rebuild and a read: no batch, base.json unchanged.
cl_b0=$(sha "$CL/workflow/.hi2vi/base.json"); sleep 1
printf 'an agent wrote this\n' > "$CL/workflow/works/phases/active/P1/slices/P1.DECOMP/result.md"
cl_m=$(cl_mark); cl rebuild >/dev/null; cl next >/dev/null; cl_r=$(cl_check "$cl_m" noop)
[ "$cl_r" = ok ] && [ "$cl_b0" = "$(sha "$CL/workflow/.hi2vi/base.json")" ] \
  && ok "equal content is a no-op: result.md rewritten with its own bytes, then rebuild and next, send no batch and leave base.json byte-equal" \
  || bad "equal content sent a batch or moved base.json -- $cl_r"
# (e) an archive's folder move: move ops paired by sha, no delete, events.jsonl one append.
cl_m=$(cl_mark); cl archive-phase P1 --force >/dev/null; cl_r=$(cl_check "$cl_m" archive)
[ "$cl_r" = ok ] && ok "archive-phase's folder move goes as move ops paired by sha (no delete, the carried result.md moved too) and works/events.jsonl as one append, never a revisioned put" \
  || bad "the archive batch wrong -- $cl_r"
# (f) a change made only in the cloud (another checkout renames P2) is pulled at the next command, and the
# generated files are rebuilt after the pull: docs is a read that renders nothing, so only the pull's rebuild can.
python3 - "$CLS" "$CL/workflow/works/phases/active/P2/phase.json" <<'PY' || bad "cloud probe: the fake write failed"
import http.client, json, sys
from urllib.parse import urlparse
data = json.load(open(sys.argv[2]))
data["name"] = "Two, renamed in hi2vi"
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("POST", "/_fake/write", json.dumps({"path": "works/phases/active/P2/phase.json",
             "content": json.dumps(data, ensure_ascii=False, indent=2) + "\n"}), {"Content-Type": "application/json"})
assert conn.getresponse().status == 200
PY
cl_m=$(cl_mark); cl docs >/dev/null; cl_r=$(cl_check "$cl_m" pulled)
[ "$cl_r" = ok ] && grep -qF 'Two, renamed in hi2vi' "$CL/workflow/works/backlog.md" \
  && grep -qF 'Two, renamed in hi2vi' "$CL/workflow/works/index.json" \
  && ok "a cloud-only change is pulled at the next command's begin step (manifest, fetch, base.json at the cloud's head) and backlog.md and index.json are rebuilt from it" \
  || bad "the cloud-only change was not pulled and rebuilt -- $cl_r / $(grep -F 'Two' "$CL/workflow/works/backlog.md" | head -2)"
# (g) the key never reaches the tree, the command output or the fake's request log.
if grep -rqF "$CLK" "$CL" "$CL_OUT" "$CLW/fake" 2>/dev/null; then bad "the workspace key leaked into the tree, the output or the request log"
else ok "the workspace key appears nowhere in the checkout, the commands' output or the fake's request log"; fi
kill "$CL_PID" 2>/dev/null; wait "$CL_PID" 2>/dev/null
echo "cloud mode test runtime: $(( $(date +%s) - cl_t0 ))s"

# ---------------------------------------------------------------------------
echo "== Test 22: cloud mode's safety half, against the local fake hi2vi -- offline a command is refused with the one P8 line and the tree unchanged, and compact-resume fails open; a lost commit answer is resent with the same batch_id and lands once; a batch never sent goes at the next command; a command that dies midway leaves the journal running and the next command refuses naming sync; a pull killed at any step of an append-only file's merge (the event log, a loop's ledger and checkpoints, a local order of its own) leaves each line in hi2vi once; a stale write (409) keeps the disk, writes nothing in hi2vi and exits 1, then the mismatch refuses with nothing changed; two engine processes in one checkout are serialized by .hi2vi/lock; a change over 8,000,000 B goes as several batches, and one file too big for any batch is refused; every failure inside the boundary is one line, never a traceback (a cut or malformed answer, a commit answer cut mid-body, a fetch that does not decode, a write error during a pull), and the hook's note; compact-resume stays inside the hook's 15 s on a slow, dripping or slow-but-moving server; a request fails only when it stalls: a slow but moving pull, push and pushing resend each finish past 10 s, a stalled or dripping server ends an ordinary command in one line in bounded time, a 409 whose body stalls keeps its batch (never 0 conflicts), and no late timer turns a whole answer into a failure; every wait is judged, the set-up included: behind an HTTPS proxy that answers its CONNECT late or drips it, the hook keeps its 9 s and an ordinary command ends in one line; over TLS a byte counts as it crosses the socket and the handshake still verifies; a key holding a control character is refused unquoted =="
sf_t0=$(date +%s)
newtmp SFW; SF="$SFW/host"; SFX="$SFW/xdg"; SF_OUT="$SFW/out.txt"; : > "$SF_OUT"
sf() { ( cd "$SF" && XDG_CONFIG_HOME="$SFX" python3 workflow/scripts/workflow.py "$@" ) 2>&1 | tee -a "$SF_OUT"; return "${PIPESTATUS[0]}"; }
# sf_crash kill|raise|pull <args>: the command, with defer-job made to die after it wrote its files (os._exit, or a
# raise), or (pull) the process killed when a pull has written its files but not yet base.json.
sf_crash() { _m=$1; shift; ( cd "$SF" && XDG_CONFIG_HOME="$SFX" python3 - "$_m" "$@" <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("workflow_engine", "workflow/scripts/workflow.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["workflow_engine"] = mod
spec.loader.exec_module(mod)
mode, real = sys.argv[1], mod.defer_job
def crash(args):
    real(args)
    if mode == "kill":
        os._exit(9)
    raise RuntimeError("a crash in the middle of the command")
mod.defer_job = crash
if mode == "pull":
    mod.CloudSession.save_base = lambda self: os._exit(9)
sys.exit(mod.main(sys.argv[2:]))
PY
) >> "$SF_OUT" 2>&1; }
# The whole workflow tree's sha list (.git aside), to prove a refusal changed nothing.
sf_tree() { python3 - "$SF/workflow" <<'PY'
import hashlib, os, sys
root = sys.argv[1]
for d, dirs, files in sorted(os.walk(root)):
    dirs[:] = sorted(x for x in dirs if not (d == root and x == ".git"))
    for f in sorted(files):
        p = os.path.join(d, f)
        print(os.path.relpath(p, root), hashlib.sha256(open(p, "rb").read()).hexdigest())
PY
}
{ env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid sh "$BOOT" "$SF" \
  && ( cd "$SF" && python3 workflow/scripts/workflow.py new-phase --phase P1 --name One --objective toy ); } > "$SFW/setup.txt" 2>&1 \
  || bad "cloud safety probe: the install failed -- $(tail -3 "$SFW/setup.txt")"
SFK="cloud-smoke-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
printf '%s\n' "$SFK" > "$SFW/key"; chmod 600 "$SFW/key"
python3 "$REPO_ROOT/tests/fake_hi2vi.py" --dir "$SFW/fake" --port-file "$SFW/port" --key-file "$SFW/key" \
  --project proj-1 --org org-1 --lifetime 600 > "$SFW/fake.txt" 2>&1 &
SF_PID=$!
for _ in $(seq 1 100); do [ -s "$SFW/port" ] && break; sleep 0.1; done
SFS="http://127.0.0.1:$(cat "$SFW/port" 2>/dev/null)"
mkdir -p "$SF/workflow/.hi2vi" "$SFX/hi2vi" && chmod 700 "$SFX/hi2vi"
python3 - "$SF/workflow/.hi2vi/link.json" "$SFX/hi2vi/workspace-keys.json" "$SFS" "$SFW/key" <<'PY' || bad "cloud safety probe: could not write the link"
import json, os, sys
link, keys, server, keyfile = sys.argv[1:]
with open(link, "w") as f:
    json.dump({"schema": 1, "server": server, "org_id": "org-1", "project_id": "proj-1", "linked_at": "2026-11-18T00:00:00Z"}, f)
with open(keyfile) as f:
    key = f.read().strip()
fd = os.open(keys, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    json.dump({server: {"proj-1": {"key": key}}}, f)
PY
sf_ctl() { python3 - "$SFS" "$1" <<'PY'
import http.client, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("POST", "/_fake/control", sys.argv[2], {"Content-Type": "application/json"})
assert conn.getresponse().status == 200
PY
}
# sf_put <path> <file>: another checkout writes <file>'s text to <path> in hi2vi.
sf_put() { python3 - "$SFS" "$1" "$2" <<'PY' || bad "cloud safety probe: the fake write failed"
import http.client, json, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("POST", "/_fake/write", json.dumps({"path": sys.argv[2], "content": open(sys.argv[3]).read()}), {"Content-Type": "application/json"})
assert conn.getresponse().status == 200
PY
}
sf_mark() { if [ -f "$SFW/fake/requests.jsonl" ]; then grep -c '' "$SFW/fake/requests.jsonl"; else echo 0; fi; }
# sf_check <mark> <check> [args]: one named assertion over the fake's requests since <mark>, its records, base.json,
# the journal and the disk.
sf_check() { python3 - "$SFW/fake/requests.jsonl" "$SFS" "$SF/workflow" "$@" <<'PY'
import base64, hashlib, http.client, json, sys
from pathlib import Path
from urllib.parse import urlparse, quote
log, server, root, mark, check, extra = sys.argv[1], sys.argv[2], Path(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6:]
R = [json.loads(l) for l in (Path(log).read_text().splitlines() if Path(log).exists() else [])[mark:]]
C = [r for r in R if r["path"].endswith("/commit")]
u = urlparse(server)
def get(path):
    conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
    conn.request("GET", path)
    resp = conn.getresponse()
    return resp.status, json.loads(resp.read())
S = get("/_fake/state")[1]
base = json.loads((root / ".hi2vi/base.json").read_text()) if (root / ".hi2vi/base.json").exists() else {}
journal = json.loads((root / ".hi2vi/journal.json").read_text()) if (root / ".hi2vi/journal.json").exists() else None
live = {p: f for p, f in S["files"].items() if not f["deleted"]}
def sha(p):
    return hashlib.sha256((root / p).read_bytes()).hexdigest()
def need(cond, why):
    if not cond:
        print(why)
        sys.exit(1)
def synced():
    """base.json, hi2vi and the disk agree: the head, every record's rev, every file's sha, the event log's bytes."""
    outbox = root / ".hi2vi/outbox"
    need(journal is None and (not outbox.exists() or not any(outbox.iterdir())), f"the journal or the outbox is left: {journal}")
    need(base.get("head") == S["head"], f"base head {base.get('head')} != hi2vi head {S['head']}")
    need(set(base["files"]) == set(live), f"base and hi2vi hold different paths: {sorted(set(base['files']) ^ set(live))[:4]}")
    for p, f in live.items():
        need(base["files"][p]["rev"] == f["rev"], f"{p}: base rev {base['files'][p]['rev']} != hi2vi rev {f['rev']}")
        need((root / p).is_file() and sha(p) == f["sha256"], f"{p}: the disk differs from hi2vi")
if check == "first":
    need(len(C) == 1 and C[0]["status"] == 200, f"one first batch expected: {[c['status'] for c in C]}")
    synced()
elif check == "lost":  # extra: revisions before the command
    need(len(C) == 1 and str(C[0]["status"]).startswith("drop-after"), f"the commit's answer was not lost: {[c['status'] for c in C]}")
    need(journal is not None and journal.get("state") == "pushing" and journal.get("batches") == [C[0]["batch"]["batch_id"]],
         f"the journal does not name the lost batch: {journal}")
    need(S["revisions"] > int(extra[0]), "the batch did not land in hi2vi")
elif check == "unsent":  # extra: revisions before the command
    need(len(C) == 1 and C[0]["status"] == "drop-before", f"the commit was not dropped: {[c['status'] for c in C]}")
    need(journal is not None and journal.get("state") == "pushing" and journal.get("batches") == [C[0]["batch"]["batch_id"]],
         f"the journal does not name the unsent batch: {journal}")
    need(S["revisions"] == int(extra[0]), "a dropped batch landed")
elif check == "resent":  # extra: the batch id, revisions after it landed (or before, for a batch never applied), replay
    bid, revs, replay = extra[0], int(extra[1]), extra[2] == "replay"
    need(C and C[0]["batch"]["batch_id"] == bid and C[0]["status"] == 200 and C[0]["batch"]["replay"] == replay,
         f"the next command did not resend batch {bid} first: {[(c['batch']['batch_id'], c['status'], c['batch']['replay']) for c in C]}")
    need((S["revisions"] == revs) if replay else (S["revisions"] > revs), f"the batch landed twice or never: {S['revisions']} vs {revs}")
    synced()
elif check == "interrupted":  # extra: the crash's class or -
    need(journal is not None and journal.get("state") == "running" and journal.get("command", "").startswith("defer-job"),
         f"the journal is not running defer-job: {journal}")
    need((journal.get("crashed") == extra[0]) if extra[0] != "-" else "crashed" not in journal, f"crashed: {journal.get('crashed')}")
    need(not C, "a crashed command sent a batch")
elif check == "stale":  # extra: the path, revisions and head before, the cloud's content
    path, revs, head, cloud = extra[0], int(extra[1]), int(extra[2]), extra[3]
    need(len(C) == 1 and C[0]["status"] == 409, f"one refused batch expected: {[c['status'] for c in C]}")
    need(S["head"] == head + 1 and S["revisions"] == revs + 1, f"hi2vi wrote more than the other checkout's change: {S['head']} {S['revisions']}")
    content = base64.b64decode(get("/_fake/file?path=" + quote(path))[1]["content"]).decode()
    need(content == cloud, "hi2vi's copy is not the other checkout's")
    need("changed here" in (root / path).read_text(), "the disk lost this checkout's change")
    need(base["files"][path]["sha256"] != sha(path), "base.json no longer names the unsent change")
    need(journal is None, f"a refused batch left the journal: {journal}")
elif check == "serialized":
    need(len(C) == 2 and all(c["status"] == 200 and not c["batch"]["replay"] for c in C), f"two landed batches expected: {[(c['status'], c['batch']['replay']) for c in C]}")
    heads = [r for r in R if r["path"].endswith("/head")]
    need(len(heads) == 2, f"each process asks head once: {len(heads)}")
    dj = sorted(p for p in live if p.endswith("/deferred.json"))
    need(dj == sorted(str(p.relative_to(root)) for p in (root / "works/deferred/open").glob("*/deferred.json")), "hi2vi lacks a deferred job")
    synced()
elif check == "split":  # extra: the number of big files
    need(len(C) >= 2 and all(c["status"] == 200 for c in C), f"several landed batches expected: {[(c['status'], c.get('bytes')) for c in C]}")
    need(all(0 < c["bytes"] < 8_000_000 for c in C), f"a batch over 8,000,000 B: {[c.get('bytes') for c in C]}")
    need(len({c["batch"]["batch_id"] for c in C}) == len(C), "two batches shared a batch_id")
    need(len([p for p in live if "/topics/big-" in p]) == int(extra[0]), "a big file is missing in hi2vi")
    synced()
elif check == "toobig":
    need(not C, f"a batch was sent: {[(c['status'], c.get('bytes')) for c in C]}")
    need(journal is None, f"the journal is left: {journal}")
elif check == "synced":
    synced()
elif check == "once":  # extra: the append-only paths (comma-separated), their usd total or -, then marks each once in hi2vi
    import collections
    need(journal is None and base.get("head") == S["head"], f"not settled: journal {journal}, base head {base.get('head')} vs {S['head']}")
    cloud_lines, usd = [], 0.0
    for p in extra[0].split(","):
        c = base64.b64decode(get("/_fake/file?path=" + quote(p))[1]["content"]).decode().splitlines()
        d = (root / p).read_text().splitlines()
        twice = sorted(l for l, n in collections.Counter(c).items() if n > 1)
        need(not twice, f"{p}: hi2vi holds {len(twice)} line(s) twice, first {twice[:1]}")
        need(collections.Counter(c) == collections.Counter(d), f"{p}: the disk's lines and hi2vi's differ")
        cloud_lines += c
        usd += sum(json.loads(l).get("usd", 0) for l in c if p.endswith(("/ledger.jsonl", "/checkpoints.jsonl")))
    for mark in extra[2:]:
        n = sum(mark in l for l in cloud_lines)
        need(n == 1, f"{mark}: {n} line(s) in hi2vi, not 1")
    need(extra[1] == "-" or abs(usd - float(extra[1])) < 1e-9, f"hi2vi's loop spend is {usd}, not {extra[1]}")
print("ok")
PY
}
sf_revs() { python3 - "$SFS" "$1" <<'PY'
import http.client, json, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("GET", "/_fake/state")
print(json.loads(conn.getresponse().read())[sys.argv[2]])
PY
}
sf_m=$(sf_mark); sf next >/dev/null; sf_r=$(sf_check "$sf_m" first)
[ "$sf_r" = ok ] || bad "cloud safety probe: the first sync failed -- $sf_r"
# (a) offline: the begin step's P1 fails, so the command never runs: exit 1, one line, the tree unchanged.
sf_ctl '{"offline": true}'
sf_t1=$(sf_tree); sf defer-job --title off --reason r --trigger t --source manual > "$SFW/a.txt"; sf_rc=$?; sf_t2=$(sf_tree)
[ "$sf_rc" = 1 ] && [ "$(grep -c '' "$SFW/a.txt")" = 1 ] && [ "$sf_t1" = "$sf_t2" ] \
  && grep -qE '^hi2vi is not reachable at http://127\.0\.0\.1:[0-9]+ \(.+\): in cloud mode nothing runs offline, and nothing was changed\.$' "$SFW/a.txt" \
  && ok "offline: defer-job is refused before it runs with exit 1 and P8's one line, and the workflow tree's sha list is equal before and after" \
  || bad "offline refusal wrong -- rc=$sf_rc $(head -3 "$SFW/a.txt") $(diff <(echo "$sf_t1") <(echo "$sf_t2") | head -3)"
echo '{}' | sf compact-resume > "$SFW/a2.txt"; sf_rc=$?
[ "$sf_rc" = 0 ] && grep -q '^compaction=done' "$SFW/a2.txt" && grep -qE '^note: hi2vi is not reachable at ' "$SFW/a2.txt" \
  && ok "offline: compact-resume (the session hook) fails open: exit 0, the resume card from the disk, P8's line as a note" \
  || bad "compact-resume offline did not fail open -- rc=$sf_rc $(head -3 "$SFW/a2.txt")"
sf_ctl '{"offline": false}'
# (b) a crash after the push landed and before the base was updated (the answer lost): the next command resends the
# same batch_id first, hi2vi answers it once (a replay), and base.json, hi2vi and the disk agree.
sf_ctl '{"commit": "drop-after"}'; sf_v=$(sf_revs revisions); sf_m=$(sf_mark)
sf defer-job --title lost --reason r --trigger t --source manual > "$SFW/b.txt"; sf_rc=$?
sf_r=$(sf_check "$sf_m" lost "$sf_v"); sf_bid=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["batches"][0])' "$SF/workflow/.hi2vi/journal.json" 2>/dev/null)
sf_v=$(sf_revs revisions); sf_m=$(sf_mark); sf next > "$SFW/b2.txt"; sf_rc2=$?; sf_r2=$(sf_check "$sf_m" resent "$sf_bid" "$sf_v" replay)
[ "$sf_rc" = 1 ] && tail -1 "$SFW/b.txt" | grep -q '^this change is on disk but not in hi2vi (hi2vi unreachable: .*): run sync$' \
  && [ "$sf_r" = ok ] && [ "$sf_rc2" = 0 ] && [ "$sf_r2" = ok ] \
  && ok "a lost commit answer: the command exits 1 (on disk but not in hi2vi), the journal names the batch, the next command resends the same batch_id, hi2vi replays it (the revisions land once) and the base catches up" \
  || bad "the lost-answer row wrong -- rc=$sf_rc/$sf_rc2 $sf_r / $sf_r2 / $(tail -1 "$SFW/b.txt")"
# (c) a crash before the push landed (the batch never applied): the next command sends it, and it lands now.
sf_ctl '{"commit": "drop-before"}'; sf_v=$(sf_revs revisions); sf_m=$(sf_mark)
sf defer-job --title unsent --reason r --trigger t --source manual > "$SFW/c.txt"; sf_rc=$?
sf_r=$(sf_check "$sf_m" unsent "$sf_v"); sf_bid=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["batches"][0])' "$SF/workflow/.hi2vi/journal.json" 2>/dev/null)
sf_m=$(sf_mark); sf next > "$SFW/c2.txt"; sf_rc2=$?; sf_r2=$(sf_check "$sf_m" resent "$sf_bid" "$sf_v" first)
[ "$sf_rc" = 1 ] && [ "$sf_r" = ok ] && [ "$sf_rc2" = 0 ] && [ "$sf_r2" = ok ] \
  && ok "a batch that never landed: the journal keeps it, the next command sends that batch_id and it lands once" \
  || bad "the unsent row wrong -- rc=$sf_rc/$sf_rc2 $sf_r / $sf_r2"
# (d) a crash during the command (a hard exit, then a raise): the journal stays running, and the next command refuses
# with one line naming sync and changes nothing. (sync is the way out; here the journal is removed by hand instead.)
sf_m=$(sf_mark); sf_crash kill defer-job --title killed --reason r --trigger t --source manual; sf_rc=$?
sf_r=$(sf_check "$sf_m" interrupted -)
sf_t1=$(sf_tree); sf next > "$SFW/d.txt"; sf_rc2=$?; sf_t2=$(sf_tree)
[ "$sf_rc" = 9 ] && [ "$sf_r" = ok ] && [ "$sf_rc2" = 1 ] && [ "$(grep -c '' "$SFW/d.txt")" = 1 ] && [ "$sf_t1" = "$sf_t2" ] \
  && grep -qE '^the last command here \(defer-job --title killed .*\) stopped before it finished: [0-9]+ file\(s\) changed by it are on disk but not in hi2vi \(interrupted\): run sync to see them \(nothing was changed\)$' "$SFW/d.txt" \
  && ok "a command killed midway leaves the journal running; the next command is refused with one line naming sync, and the tree is unchanged" \
  || bad "the interrupted row (kill) wrong -- rc=$sf_rc/$sf_rc2 $sf_r / $(head -2 "$SFW/d.txt")"
rm -f "$SF/workflow/.hi2vi/journal.json"; sf next >/dev/null
sf_m=$(sf_mark); sf_crash raise defer-job --title raised --reason r --trigger t --source manual; sf_rc=$?
sf_r=$(sf_check "$sf_m" interrupted RuntimeError); sf next > "$SFW/d2.txt"; sf_rc2=$?
[ "$sf_rc" = 1 ] && [ "$sf_r" = ok ] && [ "$sf_rc2" = 1 ] && grep -qF 'stopped before it finished, RuntimeError: ' "$SFW/d2.txt" \
  && ok "a command that raises (not a refusal) sends nothing, its journal names the crash, and the next command refuses naming it and sync" \
  || bad "the interrupted row (raise) wrong -- rc=$sf_rc/$sf_rc2 $sf_r / $(head -2 "$SFW/d2.txt")"
rm -f "$SF/workflow/.hi2vi/journal.json"; sf next >/dev/null
# The crash table's last row: killed during a pull, after the file was written and before base.json was. The disk's
# sha equals hi2vi's, which reads as the same: the next command is not refused and the base is fixed.
printf 'renamed in hi2vi\n' > "$SFW/pulled.md"; sf_put works/phases/active/P1/intent.md "$SFW/pulled.md"
sf_crash pull next; sf_rc=$?
cmp -s "$SFW/pulled.md" "$SF/workflow/works/phases/active/P1/intent.md"; sf_w=$?
sf_m=$(sf_mark); sf next > "$SFW/d3.txt"; sf_rc2=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 9 ] && [ "$sf_w" = 0 ] && [ "$sf_rc2" = 0 ] && [ "$sf_r" = ok ] \
  && ok "a pull killed after its write and before base.json: the next command reads the file as the same (no mismatch) and the base catches up" \
  || bad "the pull-crash row wrong -- rc=$sf_rc/$sf_rc2 written=$sf_w $sf_r / $(tail -1 "$SFW/d3.txt")"
# The crash table's append rows. A pull merges another checkout's new lines into an append-only file (the event log, a
# loop's ledger and checkpoints) around the lines this checkout has not sent yet, so the merged file differs from
# hi2vi's and never reads as the same. Killed at any step of that pull, the next command sends only this checkout's own
# lines: hi2vi holds each line exactly once, and a loop's spend is counted once.
# sf_kill fetch|write|wrote|base <path> <args>: the command, killed (os._exit) once the pull has fetched <path>, just
# before or just after the pull writes it, or once base.json is saved (before the generated files are rebuilt).
sf_kill() { _s=$1; _f=$2; shift 2; ( cd "$SF" && XDG_CONFIG_HOME="$SFX" python3 - "$_s" "$_f" "$@" <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("workflow_engine", "workflow/scripts/workflow.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["workflow_engine"] = mod
spec.loader.exec_module(mod)
step, target = sys.argv[1], sys.argv[2]
real_write, real_fetch = mod._cloud_write_bytes, mod.CloudSession.fetch
def write(path, data):
    hit = str(path).endswith("/" + target)
    if hit and step == "write":
        os._exit(9)
    real_write(path, data)
    if hit and step == "wrote":
        os._exit(9)
def fetch(self, paths):
    got = real_fetch(self, paths)
    if step == "fetch" and target in got:
        os._exit(9)
    return got
mod._cloud_write_bytes, mod.CloudSession.fetch = write, fetch
if step == "base":
    mod.cloud_rebuild = lambda rels: os._exit(9)
sys.exit(mod.main(sys.argv[3:]))
PY
) >> "$SF_OUT" 2>&1; }
# sf_add <path> <line>...: another checkout appends these lines to <path> in hi2vi.
sf_add() { python3 - "$SFS" "$@" <<'PY' || bad "cloud safety probe: the fake append failed"
import http.client, json, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("POST", "/_fake/write", json.dumps({"path": sys.argv[2], "lines": sys.argv[3:]}), {"Content-Type": "application/json"})
assert conn.getresponse().status == 200
PY
}
sf_ev=works/events.jsonl; sf_bad=""
for sf_step in fetch write wrote base; do
  printf '{"type": "smoke_local", "mark": "local-%s"}\n' "$sf_step" >> "$SF/workflow/$sf_ev"
  sf_add "$sf_ev" "{\"type\": \"agenda_added\", \"agenda\": \"cloud-$sf_step\"}"
  sf_kill "$sf_step" "$sf_ev" next; sf_rc=$?
  sf_m=$(sf_mark); sf next >/dev/null; sf_rc2=$?; sf_r=$(sf_check "$sf_m" once "$sf_ev" - "\"local-$sf_step\"" "\"cloud-$sf_step\"")
  { [ "$sf_rc" = 9 ] && [ "$sf_rc2" = 0 ] && [ "$sf_r" = ok ]; } || sf_bad="$sf_bad [$sf_step: rc=$sf_rc/$sf_rc2 $sf_r]"
done
[ -z "$sf_bad" ] \
  && ok "a pull merging another checkout's event line around a local one, killed after the fetch, before the write, after the write (before base.json) or after base.json: the next command sends only the local line, and hi2vi holds each line once" \
  || bad "an append pull killed midway re-sent hi2vi's own lines --$sf_bad"
sf_add "$sf_ev" '{"type": "agenda_added", "agenda": "cloud-alone"}'
sf_kill wrote "$sf_ev" next; sf_rc=$?
sf_m=$(sf_mark); sf next >/dev/null; sf_rc2=$?; sf_r=$(sf_check "$sf_m" once "$sf_ev" - '"cloud-alone"'); sf_r2=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 9 ] && [ "$sf_rc2" = 0 ] && [ "$sf_r" = ok ] && [ "$sf_r2" = ok ] \
  && ok "an append pull with nothing local past the offset, killed after its write: the file equals hi2vi's, reads as the same, and the base catches up" \
  || bad "the plain append pull-crash row wrong -- rc=$sf_rc/$sf_rc2 $sf_r / $sf_r2"
# A loop's ledger and checkpoints, pulled together (checkpoints.jsonl is written first): killed once both are written,
# then once only the first is, the loop spend summed from hi2vi's lines stays the sum of each line once.
sf_lp=works/phases/active/P1/loop; mkdir -p "$SF/workflow/$sf_lp"
printf '{"cycle": "C1", "usd": 1.5}\n' > "$SF/workflow/$sf_lp/ledger.jsonl"
printf '{"slice": "P1.K1", "usd": 0.25}\n' > "$SF/workflow/$sf_lp/checkpoints.jsonl"
sf next >/dev/null; sf_bad=""
for sf_row in "ledger:C2:2:C3:4:K2:0.5:8.25" "checkpoints:K3:0.125:C4:8:K4:1:17.375"; do
  IFS=: read -r sf_t sf_l sf_lu sf_c sf_cu sf_k sf_ku sf_sum <<< "$sf_row"
  if [ "$sf_t" = ledger ]; then printf '{"cycle": "%s", "usd": %s}\n' "$sf_l" "$sf_lu" >> "$SF/workflow/$sf_lp/ledger.jsonl"
  else printf '{"slice": "P1.%s", "usd": %s}\n' "$sf_l" "$sf_lu" >> "$SF/workflow/$sf_lp/checkpoints.jsonl"; fi
  sf_add "$sf_lp/ledger.jsonl" "{\"cycle\": \"$sf_c\", \"usd\": $sf_cu}"
  sf_add "$sf_lp/checkpoints.jsonl" "{\"slice\": \"P1.$sf_k\", \"usd\": $sf_ku}"
  sf_kill wrote "$sf_lp/$sf_t.jsonl" next; sf_rc=$?
  sf_m=$(sf_mark); sf next >/dev/null; sf_rc2=$?
  sf_r=$(sf_check "$sf_m" once "$sf_lp/ledger.jsonl,$sf_lp/checkpoints.jsonl" "$sf_sum" "$sf_l" "$sf_c" "P1.$sf_k")
  { [ "$sf_rc" = 9 ] && [ "$sf_rc2" = 0 ] && [ "$sf_r" = ok ]; } || sf_bad="$sf_bad [$sf_t: rc=$sf_rc/$sf_rc2 $sf_r]"
done
[ -z "$sf_bad" ] \
  && ok "a loop's ledger and checkpoints pulled with a local line past the offset, killed after both writes or after the first: hi2vi holds each line once and the loop spend is unchanged by the crash" \
  || bad "an append pull killed midway double-counted a loop's lines --$sf_bad"
# A local order that already differs from hi2vi's (another checkout's line landed between this checkout's pull and its
# push): the file never equals hi2vi's again, so a pull killed after its write must still send nothing of hi2vi's.
printf '{"type": "smoke_local", "mark": "local-race"}\n' >> "$SF/workflow/$sf_ev"
sf_ctl "$(python3 -c 'import json, sys; print(json.dumps({"race": {"path": sys.argv[1], "lines": [json.dumps({"type": "agenda_added", "agenda": "cloud-race"})]}}))' "$sf_ev")"
sf next >/dev/null; sf next >/dev/null
sf_ord=$(python3 - "$SFS" "$SF/workflow" "$sf_ev" <<'PY'
import base64, http.client, json, sys
from pathlib import Path
from urllib.parse import urlparse, quote
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("GET", "/_fake/file?path=" + quote(sys.argv[3]))
c = base64.b64decode(json.loads(conn.getresponse().read())["content"])
d = (Path(sys.argv[2]) / sys.argv[3]).read_bytes()
print("differs" if c != d and sorted(c.splitlines()) == sorted(d.splitlines()) else "same")
PY
)
sf_add "$sf_ev" '{"type": "agenda_added", "agenda": "cloud-order"}'
sf_kill wrote "$sf_ev" next; sf_rc=$?
sf_m=$(sf_mark); sf next >/dev/null; sf_rc2=$?; sf_r=$(sf_check "$sf_m" once "$sf_ev" - '"cloud-order"' '"cloud-race"' '"local-race"')
[ "$sf_ord" = differs ] && [ "$sf_rc" = 9 ] && [ "$sf_rc2" = 0 ] && [ "$sf_r" = ok ] \
  && ok "an event log whose order already differs from hi2vi's, its pull killed after the write: the next command sends nothing of hi2vi's, each line once" \
  || bad "the differing-order append pull-crash row wrong -- order=$sf_ord rc=$sf_rc/$sf_rc2 $sf_r"
sf sync --keep cloud "$sf_ev" >/dev/null; sf_m=$(sf_mark); sf next >/dev/null; sf_rc=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_r" = ok ] || bad "the event log did not settle on hi2vi's order after sync --keep cloud -- rc=$sf_rc $sf_r"
# (e) a stale write: another checkout changes the same file between this command's begin and its commit. hi2vi refuses
# the whole batch (409), the disk keeps this checkout's change, exit 1 though next succeeded; then the begin step's
# mismatch refuses with nothing changed, until the two sides agree.
sf_p=works/phases/active/P1/intent.md; printf 'changed here\n' >> "$SF/workflow/$sf_p"
sf_ctl "{\"race\": {\"path\": \"$sf_p\", \"content\": \"changed in hi2vi by another checkout\\n\"}}"
sf_v=$(sf_revs revisions); sf_h=$(sf_revs head); sf_m=$(sf_mark)
sf next > "$SFW/e.txt"; sf_rc=$?; sf_r=$(sf_check "$sf_m" stale "$sf_p" "$sf_v" "$sf_h" "changed in hi2vi by another checkout
")
[ "$sf_rc" = 1 ] && [ "$(tail -1 "$SFW/e.txt")" = "this change is on disk but not in hi2vi (1 conflict(s)): run sync" ] && [ "$sf_r" = ok ] \
  && ok "a stale write is refused: 409, nothing of the batch written in hi2vi, the disk keeps the change, base.json still names it, no journal left, and exit 1 though next itself succeeded" \
  || bad "the stale write wrong -- rc=$sf_rc $sf_r / $(tail -1 "$SFW/e.txt")"
sf_t1=$(sf_tree); sf next > "$SFW/e2.txt"; sf_rc=$?; sf_t2=$(sf_tree)
[ "$sf_rc" = 1 ] && [ "$(cat "$SFW/e2.txt")" = "1 files differ between this checkout and hi2vi: run sync to see them (nothing was changed)" ] && [ "$sf_t1" = "$sf_t2" ] \
  && ok "then the begin step's mismatch: the next command is refused with one line naming sync, and the tree is unchanged" \
  || bad "the mismatch refusal wrong -- rc=$sf_rc $(head -2 "$SFW/e2.txt")"
sf_put "$sf_p" "$SF/workflow/$sf_p"
sf_m=$(sf_mark); sf next >/dev/null; sf_rc=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_r" = ok ] || bad "equal content on both sides did not clear the mismatch -- rc=$sf_rc $sf_r"
# (f) two engine processes in one checkout at once. The fake holds the first two head requests until both arrive (or
# 3 s pass), so without the lock both would begin at the same head and base and race (a double push of the event
# lines, a lost base). The lock serializes them: each batch lands once and base.json, hi2vi and the disk agree.
sf_ctl '{"gate": {"route": "head", "count": 2, "timeout": 3}}'; sf_m=$(sf_mark)
sf defer-job --title one --reason r --trigger t --source manual > "$SFW/f1.txt" & sf_p1=$!
sf defer-job --title two --reason r --trigger t --source manual > "$SFW/f2.txt" & sf_p2=$!
wait "$sf_p1"; sf_rc=$?; wait "$sf_p2"; sf_rc2=$?
sf_ctl '{"gate": null}'; sf_r=$(sf_check "$sf_m" serialized)
[ "$sf_rc" = 0 ] && [ "$sf_rc2" = 0 ] && [ "$sf_r" = ok ] \
  && ok "two defer-job processes at once in one checkout are serialized by .hi2vi/lock: two batches, none resent, both jobs in hi2vi, and the event log, every rev and base.json's head agree" \
  || bad "two engine processes were not serialized -- rc=$sf_rc/$sf_rc2 $sf_r / $(tail -1 "$SFW/f1.txt") / $(tail -1 "$SFW/f2.txt")"
# compact-resume while another process holds the lock: it waits a bounded time, then fails open with the line as a note.
python3 -c 'import fcntl, os, sys, time
fd = os.open(sys.argv[1], os.O_RDWR | os.O_CREAT); fcntl.flock(fd, fcntl.LOCK_EX); open(sys.argv[2], "w").close(); time.sleep(20)' \
  "$SF/workflow/.hi2vi/lock" "$SFW/held" & sf_hp=$!
for _ in $(seq 1 100); do [ -e "$SFW/held" ] && break; sleep 0.1; done
sf_s=$(date +%s); echo '{}' | sf compact-resume > "$SFW/f3.txt"; sf_rc=$?; sf_s=$(( $(date +%s) - sf_s ))
kill "$sf_hp" 2>/dev/null; wait "$sf_hp" 2>/dev/null
[ "$sf_rc" = 0 ] && [ "$sf_s" -lt 15 ] && grep -q '^compaction=done' "$SFW/f3.txt" && grep -qF "note: another engine command has held this checkout's lock" "$SFW/f3.txt" \
  && ok "compact-resume with the lock held elsewhere waits a bounded time (${sf_s}s), then fails open: exit 0, the card, the lock line as a note" \
  || bad "compact-resume did not fail open on a held lock -- rc=$sf_rc ${sf_s}s $(head -3 "$SFW/f3.txt")"
# (g) a change over the server's limit goes as several batches in order, each under 8,000,000 B as sent with its own
# batch_id; one file too big for any batch is refused before anything is sent.
mkdir -p "$SF/workflow/works/phases/active/P1/topics"
for i in 1 2 3; do python3 -c 'import sys; open(sys.argv[1], "w").write(("line of a big topic %s\n" % sys.argv[2]) * 140000)' \
  "$SF/workflow/works/phases/active/P1/topics/big-$i.md" "$i"; done
sf_m=$(sf_mark); sf next >/dev/null; sf_rc=$?; sf_r=$(sf_check "$sf_m" split 3)
[ "$sf_rc" = 0 ] && [ "$sf_r" = ok ] \
  && ok "a 9 MB change goes as several batches in order, each under 8,000,000 B as sent with its own batch_id, and all of it lands" \
  || bad "the big change was not split -- rc=$sf_rc $sf_r"
python3 -c 'import sys; open(sys.argv[1], "w").write("x" * 8100000)' "$SF/workflow/works/phases/active/P1/topics/huge.md"
sf_m=$(sf_mark); sf next > "$SFW/g.txt"; sf_rc=$?; sf_r=$(sf_check "$sf_m" toobig)
[ "$sf_rc" = 1 ] && [ "$sf_r" = ok ] && tail -1 "$SFW/g.txt" | grep -qE "^works/phases/active/P1/topics/huge\.md is [0-9,]+ bytes as sent, over hi2vi's 8,000,000-byte batch limit: it is on disk but not in hi2vi" \
  && ok "one file too big for any batch is refused with one line naming it, exit 1, nothing sent" \
  || bad "the too-big file was not refused -- rc=$sf_rc $sf_r / $(tail -1 "$SFW/g.txt")"
rm -f "$SF/workflow/works/phases/active/P1/topics/huge.md"
sf_m=$(sf_mark); sf next >/dev/null; sf_rc=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_r" = ok ] || bad "the checkout did not settle after the too-big file left -- rc=$sf_rc $sf_r"
# (i) every failure inside the boundary ends in one line, never a traceback: a cut or malformed answer (http.client's
# IncompleteRead, BadStatusLine, LineTooLong) refuses the command with P8's line and the tree unchanged, and the
# session hook still prints its card with the line as a note.
sf_no_tb() { ! grep -q '^Traceback' "$1"; }
for sf_how in truncate:IncompleteRead status:BadStatusLine longline:LineTooLong; do
  sf_ctl "{\"break\": {\"route\": \"head\", \"how\": \"${sf_how%%:*}\"}}"
  sf_t1=$(sf_tree); sf next > "$SFW/i.txt"; sf_rc=$?; sf_t2=$(sf_tree)
  echo '{}' | sf compact-resume > "$SFW/i2.txt"; sf_rc2=$?
  sf_ctl '{"break": null}'
  [ "$sf_rc" = 1 ] && [ "$(grep -c '' "$SFW/i.txt")" = 1 ] && [ "$sf_t1" = "$sf_t2" ] \
    && grep -qE "^hi2vi is not reachable at http://127\.0\.0\.1:[0-9]+ \(${sf_how#*:}.*\): in cloud mode nothing runs offline, and nothing was changed\.$" "$SFW/i.txt" \
    && [ "$sf_rc2" = 0 ] && grep -q '^compaction=done' "$SFW/i2.txt" && grep -qE "^note: hi2vi is not reachable at .*\(${sf_how#*:}" "$SFW/i2.txt" && sf_no_tb "$SFW/i2.txt" \
    && ok "an answer cut or malformed at the begin step (${sf_how#*:}): the command is refused with P8's one line and the tree unchanged, and compact-resume prints its card with the line as a note, exit 0" \
    || bad "a ${sf_how#*:} at the begin step was not one line -- rc=$sf_rc/$sf_rc2 $(head -2 "$SFW/i.txt") / $(tail -2 "$SFW/i2.txt")"
done
# The answers that were already one line stay so: a proxy's 502 in front of a stopped API, a body that is not JSON.
sf_bad=""
for sf_how in "bad-gateway:^hi2vi is not reachable at .* \(HTTP 502 on head\): in cloud mode nothing runs offline, and nothing was changed\.$" \
              "garbage:^hi2vi answered for project None, not proj-1: this checkout's link is broken, and nothing was changed$"; do
  sf_ctl "{\"break\": {\"route\": \"head\", \"how\": \"${sf_how%%:*}\"}}"
  sf next > "$SFW/i0.txt"; sf_rc=$?; sf_ctl '{"break": null}'
  { [ "$sf_rc" = 1 ] && [ "$(grep -c '' "$SFW/i0.txt")" = 1 ] && grep -qE "${sf_how#*:}" "$SFW/i0.txt"; } || sf_bad="$sf_bad [${sf_how%%:*}: rc=$sf_rc $(head -1 "$SFW/i0.txt")]"
done
[ -z "$sf_bad" ] && ok "a 502 from a proxy and a body that is not JSON still end in their one line, exit 1" || bad "a 502 or a non-JSON answer --$sf_bad"
# A commit answer cut mid-body is a lost answer: one line, the journal keeps the batch, the next command resends it.
sf_ctl '{"break": {"route": "commit", "how": "truncate"}}'
sf defer-job --title cut --reason r --trigger t --source manual > "$SFW/i3.txt"; sf_rc=$?
sf_ctl '{"break": null}'; sf_m=$(sf_mark); sf next >/dev/null; sf_rc2=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 1 ] && sf_no_tb "$SFW/i3.txt" && [ "$(tail -1 "$SFW/i3.txt")" != "" ] \
  && tail -1 "$SFW/i3.txt" | grep -q '^this change is on disk but not in hi2vi (hi2vi unreachable: IncompleteRead(.*)): run sync$' \
  && [ "$sf_rc2" = 0 ] && [ "$sf_r" = ok ] \
  && ok "a commit answer cut mid-body: the command exits 1 with the one on-disk line, and the next command resends the batch and settles" \
  || bad "a cut commit answer wrong -- rc=$sf_rc/$sf_rc2 $sf_r / $(tail -2 "$SFW/i3.txt")"
# A fetch whose base64 does not decode stops the pull before anything is written.
printf 'pulled as base64\n' > "$SFW/b64.md"; sf_put works/phases/active/P1/topics/b64.md "$SFW/b64.md"
sf_ctl '{"break": {"route": "fetch", "how": "badbase64"}}'
sf_t1=$(sf_tree); sf next > "$SFW/i4.txt"; sf_rc=$?; sf_t2=$(sf_tree)
echo '{}' | sf compact-resume > "$SFW/i5.txt"; sf_rc2=$?
sf_ctl '{"break": null}'; sf_m=$(sf_mark); sf next >/dev/null; sf_rc3=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 1 ] && [ "$(grep -c '' "$SFW/i4.txt")" = 1 ] && [ "$sf_t1" = "$sf_t2" ] \
  && grep -qE '^hi2vi is not reachable at .* \(a fetched file did not decode as base64: works/phases/active/P1/topics/b64\.md\): in cloud mode nothing runs offline, and nothing was changed\.$' "$SFW/i4.txt" \
  && [ "$sf_rc2" = 0 ] && grep -q '^compaction=done' "$SFW/i5.txt" && grep -q '^note: hi2vi is not reachable at .*did not decode as base64' "$SFW/i5.txt" \
  && [ "$sf_rc3" = 0 ] && [ "$sf_r" = ok ] \
  && ok "a fetch whose base64 does not decode: one line naming the file, nothing written, the hook's note; the next good answer pulls it" \
  || bad "bad base64 in a fetch wrong -- rc=$sf_rc/$sf_rc2/$sf_rc3 $sf_r / $(head -2 "$SFW/i4.txt") / $(tail -1 "$SFW/i5.txt")"
# A write error during the pull (a file stands where hi2vi's folder goes): one line naming the path; the file pulled
# before it is on disk and recorded in base.json with the head kept, and once the way is clear the pull resumes.
printf 'pulled first\n' > "$SFW/pa.md"; printf 'pulled second\n' > "$SFW/pb.md"
sf_put works/phases/active/P1/topics/a-first.md "$SFW/pa.md"; sf_put works/phases/active/P1/topics/blocked/b.md "$SFW/pb.md"
printf 'in the way\n' > "$SF/workflow/works/phases/active/P1/topics/blocked"
sf_h0=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["head"])' "$SF/workflow/.hi2vi/base.json")
sf next > "$SFW/i6.txt"; sf_rc=$?
sf_rec=$(python3 - "$SF/workflow" "$sf_h0" <<'PY'
import hashlib, json, sys
from pathlib import Path
root, h0 = Path(sys.argv[1]), int(sys.argv[2])
base = json.loads((root / ".hi2vi/base.json").read_text())
a = "works/phases/active/P1/topics/a-first.md"
ok = (base["head"] == h0 and base["files"].get(a, {}).get("sha256") == hashlib.sha256((root / a).read_bytes()).hexdigest()
      and "works/phases/active/P1/topics/blocked/b.md" not in base["files"] and not (root / ".hi2vi/journal.json").exists())
print("ok" if ok else f"base {base['head']} vs {h0}: {base['files'].get(a)}")
PY
)
echo '{}' | sf compact-resume > "$SFW/i7.txt"; sf_rc2=$?
rm -f "$SF/workflow/works/phases/active/P1/topics/blocked"; sf_m=$(sf_mark); sf next >/dev/null; sf_rc3=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 1 ] && [ "$(grep -c '' "$SFW/i6.txt")" = 1 ] && [ "$sf_rec" = ok ] \
  && grep -qE '^works/phases/active/P1/topics/blocked/b\.md could not be written here from hi2vi \([A-Za-z]+Error: .*\): 1 pulled path\(s\) landed before it and are recorded in \.hi2vi/base\.json; fix it, then run the command again \(the pull resumes from there\)$' "$SFW/i6.txt" \
  && [ "$sf_rc2" = 0 ] && grep -q '^compaction=done' "$SFW/i7.txt" && grep -q '^note: works/phases/active/P1/topics/blocked/b\.md could not be written' "$SFW/i7.txt" \
  && [ "$sf_rc3" = 0 ] && [ "$sf_r" = ok ] \
  && ok "a write error during a pull: one line naming the path, what landed before it recorded in base.json (the head kept, no journal), the hook's note; then the pull resumes and settles" \
  || bad "a write error during a pull wrong -- rc=$sf_rc/$sf_rc2/$sf_rc3 $sf_rec $sf_r / $(head -2 "$SFW/i6.txt") / $(tail -1 "$SFW/i7.txt")"
# The session hook's budget: a slow but answering server (5 s per answer, a pull waiting: head, manifest and fetch
# would take 15 s), then one that sends a byte a second (no socket read ever times out). compact-resume stays inside
# the hook's 15 s timeout (its cloud time is held to 9 s) and prints its card with the line as a note.
printf 'pulled slowly\n' > "$SFW/slow.md"; sf_put works/phases/active/P1/topics/slow.md "$SFW/slow.md"
for sf_sw in "slow:5:answers each request 5 s late" "drip:1:sends its answers a byte a second"; do
  sf_k=${sf_sw%%:*}; sf_n=${sf_sw#*:}; sf_lbl=${sf_n#*:}; sf_n=${sf_n%%:*}
  sf_ctl "{\"$sf_k\": $sf_n}"
  sf_s=$(date +%s); echo '{}' | sf compact-resume > "$SFW/i8.txt"; sf_rc=$?; sf_s=$(( $(date +%s) - sf_s ))
  sf_ctl "{\"$sf_k\": 0}"
  [ "$sf_rc" = 0 ] && [ "$sf_s" -lt 15 ] && grep -q '^compaction=done' "$SFW/i8.txt" && grep -qF "note: hi2vi is not reachable at $SFS (the session hook's 9 s for hi2vi ran out)" "$SFW/i8.txt" \
    && ok "compact-resume on a server that $sf_lbl ends in ${sf_s}s, inside the hook's 15 s: exit 0, the card, the budget's line as a note" \
    || bad "compact-resume on a server that $sf_lbl -- rc=$sf_rc ${sf_s}s $(tail -2 "$SFW/i8.txt")"
done
sleep 2; sf_m=$(sf_mark); sf next >/dev/null; sf_rc=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_r" = ok ] || bad "the checkout did not settle after the slow server -- rc=$sf_rc $sf_r"
# A request fails when it stalls, never while its bytes still move. On a steady slow link (the fake reads and sends at
# 48,000 B/s) a 624 KB file takes about 13 s to pull and as long to push: a limit on the whole request would refuse
# each. The session hook still stops at its 9 s with the note; an ordinary command pulls and pushes it whole, and a
# batch left `pushing` is resent at the begin step over the same link.
sf_big() { python3 -c 'import sys; open(sys.argv[1], "w").write((sys.argv[2] + " of a slow transfer\n") * 24000)' "$1" "$2"; }
sf_big "$SFW/slowpull.md" pulled; sf_put works/phases/active/P1/topics/slow-pull.md "$SFW/slowpull.md"
sf_ctl '{"rate": 48000}'
sf_s=$(date +%s); echo '{}' | sf compact-resume > "$SFW/s1.txt"; sf_rc=$?; sf_s=$(( $(date +%s) - sf_s ))
[ "$sf_rc" = 0 ] && [ "$sf_s" -lt 15 ] && grep -q '^compaction=done' "$SFW/s1.txt" && grep -qF "note: hi2vi is not reachable at $SFS (the session hook's 9 s for hi2vi ran out)" "$SFW/s1.txt" \
  && ok "compact-resume with a 624 KB pull waiting on a slow link ends in ${sf_s}s, inside the hook's 15 s: exit 0, the card, the budget's line as a note" \
  || bad "compact-resume on a slow link -- rc=$sf_rc ${sf_s}s $(tail -2 "$SFW/s1.txt")"
sf_s=$(date +%s); sf_m=$(sf_mark); sf next > "$SFW/s2.txt"; sf_rc=$?; sf_s=$(( $(date +%s) - sf_s )); sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_s" -gt 10 ] && [ "$sf_r" = ok ] && sf_no_tb "$SFW/s2.txt" \
  && ok "a slow but moving pull finishes: a 624 KB file at 48,000 B/s takes ${sf_s}s, over 10 s, and lands whole (exit 0, base, hi2vi and the disk agree)" \
  || bad "a slow but moving pull was refused -- rc=$sf_rc ${sf_s}s $sf_r / $(grep -m1 'hi2vi' "$SFW/s2.txt")"
sf_big "$SF/workflow/works/phases/active/P1/topics/slow-push.md" pushed
sf_s=$(date +%s); sf_m=$(sf_mark); sf next > "$SFW/s3.txt"; sf_rc=$?; sf_s=$(( $(date +%s) - sf_s )); sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_s" -gt 10 ] && [ "$sf_r" = ok ] && sf_no_tb "$SFW/s3.txt" \
  && ok "a slow but moving push finishes: a 624 KB change at 48,000 B/s takes ${sf_s}s, over 10 s, and lands once" \
  || bad "a slow but moving push was refused -- rc=$sf_rc ${sf_s}s $sf_r / $(tail -1 "$SFW/s3.txt")"
sf_ctl '{"rate": 0, "commit": "drop-before"}'; sf_big "$SF/workflow/works/phases/active/P1/topics/slow-resend.md" resent
sf_v=$(sf_revs revisions); sf_m=$(sf_mark); sf next > "$SFW/s4.txt"; sf_rc=$?; sf_r=$(sf_check "$sf_m" unsent "$sf_v")
sf_bid=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["batches"][0])' "$SF/workflow/.hi2vi/journal.json" 2>/dev/null)
sf_ctl '{"rate": 48000}'
sf_s=$(date +%s); sf_m=$(sf_mark); sf next > "$SFW/s5.txt"; sf_rc2=$?; sf_s=$(( $(date +%s) - sf_s )); sf_r2=$(sf_check "$sf_m" resent "$sf_bid" "$sf_v" first)
sf_ctl '{"rate": 0}'
[ "$sf_rc" = 1 ] && [ "$sf_r" = ok ] && [ "$sf_rc2" = 0 ] && [ "$sf_s" -gt 10 ] && [ "$sf_r2" = ok ] \
  && ok "a pushing batch resent at the begin step over a slow link (${sf_s}s, over 10 s) lands once" \
  || bad "a slow resend of a pushing batch -- rc=$sf_rc/$sf_rc2 ${sf_s}s $sf_r / $sf_r2 / $(tail -1 "$SFW/s5.txt")"
# A stalled server and a dripping one still end an ordinary command in one line, in bounded time: no byte for 10 s, or
# fewer than 1024 bytes in a 10 s window (a byte a second).
sf_bad=""
for sf_sw in "slow:12:no byte moved for 10 s" "drip:1:fewer than 1024 bytes moved in 10 s"; do
  sf_k=${sf_sw%%:*}; sf_n=${sf_sw#*:}; sf_why=${sf_n#*:}; sf_n=${sf_n%%:*}
  sf_ctl "{\"$sf_k\": $sf_n}"
  sf_t1=$(sf_tree); sf_s=$(date +%s); sf next > "$SFW/s6.txt"; sf_rc=$?; sf_s=$(( $(date +%s) - sf_s )); sf_t2=$(sf_tree)
  sf_ctl "{\"$sf_k\": 0}"
  { [ "$sf_rc" = 1 ] && [ "$sf_s" -le 22 ] && [ "$sf_t1" = "$sf_t2" ] && [ "$(grep -c '' "$SFW/s6.txt")" = 1 ] \
    && grep -qF "hi2vi is not reachable at $SFS ($sf_why): in cloud mode nothing runs offline, and nothing was changed." "$SFW/s6.txt"; } \
    || sf_bad="$sf_bad [$sf_k: rc=$sf_rc ${sf_s}s $(head -1 "$SFW/s6.txt")]"
done
[ -z "$sf_bad" ] && ok "a server that stalls (no byte for 10 s) or drips (a byte a second) ends an ordinary command in one line within 22 s, the tree unchanged" \
  || bad "a stalled or dripping server --$sf_bad"
sleep 2
# A 409 whose body stalls is no answer: it never reads as a batch with no conflicts. The journal keeps the batch; the
# next command resends it and meets hi2vi's whole 409 (1 conflict), then the mismatch waits for sync.
sf_p=works/phases/active/P1/topics/slow-pull.md; printf 'changed here\n' >> "$SF/workflow/$sf_p"
sf_ctl "{\"race\": {\"path\": \"$sf_p\", \"content\": \"changed in hi2vi by another checkout\\n\"}, \"break\": {\"route\": \"commit\", \"how\": \"hold\"}}"
sf next > "$SFW/s7.txt"; sf_rc=$?; sf_ctl '{"break": null}'
sf_j=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("state"))' "$SF/workflow/.hi2vi/journal.json" 2>/dev/null)
sf next > "$SFW/s8.txt"; sf_rc2=$?
[ "$sf_rc" = 1 ] && [ "$(tail -1 "$SFW/s7.txt")" = "this change is on disk but not in hi2vi (hi2vi unreachable: no byte moved for 10 s): run sync" ] \
  && [ "$sf_j" = pushing ] && [ "$sf_rc2" = 1 ] && grep -qF "(1 conflict(s)): run sync" "$SFW/s8.txt" && sf_no_tb "$SFW/s8.txt" \
  && ok "a 409 whose body stalls is one line and keeps the batch (never 0 conflicts); the resend meets hi2vi's whole 409 with its conflict" \
  || bad "a 409 with a stalled body -- rc=$sf_rc/$sf_rc2 journal=$sf_j $(tail -1 "$SFW/s7.txt") / $(tail -1 "$SFW/s8.txt")"
sf_put "$sf_p" "$SF/workflow/$sf_p"
sf_m=$(sf_mark); sf next >/dev/null; sf_rc=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_r" = ok ] || bad "the checkout did not settle after the stalled 409 -- rc=$sf_rc $sf_r"
# No timer can turn a whole answer into an unreachable one: with the limit at 1 s and 1.5 s spent after the answer is
# read (where a wall-clock alarm would land), the request still returns hi2vi's answer.
sf_late=$( cd "$SF" && XDG_CONFIG_HOME="$SFX" python3 - <<'PY' 2>&1
import importlib.util, sys, time
spec = importlib.util.spec_from_file_location("workflow_engine", "workflow/scripts/workflow.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["workflow_engine"] = mod
spec.loader.exec_module(mod)
mod.CLOUD_TIMEOUT = 1
real = mod.CloudLink._exchange
def late(self, *a, **k):
    answer = real(self, *a, **k)
    time.sleep(1.5)
    return answer
mod.CloudLink._exchange = late
try:
    status, payload = mod.CloudLink().call("GET", "head")
    print(f"answer {status} {isinstance(payload.get('head'), int)}")
except Exception as exc:
    print(f"{exc.__class__.__name__}: {exc}")
PY
)
[ "$sf_late" = "answer 200 True" ] && ok "an answer already read is never turned into unreachable by a late timer" || bad "a late timer turned a whole answer into a failure -- $sf_late"
# The connection's set-up is judged too. Behind an HTTPS proxy that answers its CONNECT 6 s late and then forwards
# nothing, or drips its CONNECT answer a byte every 2 s, the session hook still ends inside its 9 s with the note and an
# ordinary command in one line in about 10 s (the connect is one wait the idle limit bounds; then the floor judges each
# step of the tunnel and the TLS handshake, its window counted from the request's start and only the peer's bytes counted
# in it). The checkout points at an
# https hi2vi only the proxy could reach (never resolved here: urllib hands the name to the proxy); each command is
# cut at 40 s by pid, so a hang fails the row, not the suite.
cat > "$SFW/proxy.py" <<'PY'
import os, socket, sys, threading, time
port_file, mode = sys.argv[1], sys.argv[2]
def serve(c):
    try:
        c.recv(4096)
        if mode == "late":
            time.sleep(6)
            c.sendall(b"HTTP/1.1 200 Connection established\r\n\r\n")
            while c.recv(4096):
                pass
        else:
            c.sendall(b"HTTP/1.1 200 Connection established\r\n")
            while True:
                for b in b"X-Wait: y\r\n":
                    c.sendall(bytes([b]))
                    time.sleep(2)
    except OSError:
        pass
    finally:
        c.close()
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0))
s.listen(8)
with open(port_file + ".tmp", "w") as f:
    f.write(str(s.getsockname()[1]))
os.replace(port_file + ".tmp", port_file)
threading.Timer(300, lambda: os._exit(0)).start()
while True:
    c, _ = s.accept()
    threading.Thread(target=serve, args=(c,), daemon=True).start()
PY
# sf_capped <out> <proxy> <args>: one engine command behind HTTPS_PROXY, cut at 40 s; prints "<rc|killed> <seconds>".
sf_capped() { _out=$1; _px=$2; shift 2; ( cd "$SF" && XDG_CONFIG_HOME="$SFX" python3 - "$_out" "$_px" "$@" <<'PY'
import os, subprocess, sys, time
out, proxy, args = sys.argv[1], sys.argv[2], sys.argv[3:]
env = dict(os.environ, HTTPS_PROXY=proxy, https_proxy=proxy)
for k in ("NO_PROXY", "no_proxy", "ALL_PROXY", "all_proxy"):
    env.pop(k, None)
t = time.monotonic()
p = subprocess.Popen([sys.executable, "workflow/scripts/workflow.py"] + args, env=env, stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
try:
    data, _ = p.communicate(b"{}" if args[:1] == ["compact-resume"] else b"", timeout=40)
    rc = p.returncode
except subprocess.TimeoutExpired:
    p.kill()
    data, _ = p.communicate()
    rc = "killed"
open(out, "wb").write(data)
print(f"{rc} {time.monotonic() - t:.0f}")
PY
); }
sf_px_pids=()
for sf_k in late drip; do
  python3 "$SFW/proxy.py" "$SFW/px-$sf_k" "$sf_k" > /dev/null 2>&1 & sf_px_pids+=($!)
done
for _ in $(seq 1 50); do [ -s "$SFW/px-late" ] && [ -s "$SFW/px-drip" ] && break; sleep 0.1; done
cp "$SF/workflow/.hi2vi/link.json" "$SFW/link.bak"; cp "$SFX/hi2vi/workspace-keys.json" "$SFW/keys2.bak"
python3 - "$SF/workflow/.hi2vi/link.json" "$SFX/hi2vi/workspace-keys.json" <<'PY'
import json, sys
link, keys = sys.argv[1:]
d = json.load(open(link)); old = d["server"]; d["server"] = "https://hi2vi.invalid"; json.dump(d, open(link, "w"))
k = json.load(open(keys)); k["https://hi2vi.invalid"] = k[old]; json.dump(k, open(keys, "w"))
PY
sf_bad=""
for sf_k in late drip; do
  sf_px="http://127.0.0.1:$(cat "$SFW/px-$sf_k")"
  read -r sf_rc sf_s < <(sf_capped "$SFW/p-$sf_k-hook.txt" "$sf_px" compact-resume)
  { [ "$sf_rc" = 0 ] && [ "$sf_s" -le 11 ] && grep -q '^compaction=done' "$SFW/p-$sf_k-hook.txt" \
    && grep -qF "note: hi2vi is not reachable at https://hi2vi.invalid (the session hook's 9 s for hi2vi ran out)" "$SFW/p-$sf_k-hook.txt"; } \
    || sf_bad="$sf_bad [$sf_k hook: rc=$sf_rc ${sf_s}s $(tail -1 "$SFW/p-$sf_k-hook.txt")]"
  sf_t1=$(sf_tree); read -r sf_rc sf_s < <(sf_capped "$SFW/p-$sf_k-next.txt" "$sf_px" next); sf_t2=$(sf_tree)
  { [ "$sf_rc" = 1 ] && [ "$sf_s" -le 12 ] && [ "$sf_t1" = "$sf_t2" ] && [ "$(grep -c '' "$SFW/p-$sf_k-next.txt")" = 1 ] \
    && grep -qF "hi2vi is not reachable at https://hi2vi.invalid (fewer than 1024 bytes moved in 10 s): in cloud mode nothing runs offline, and nothing was changed." "$SFW/p-$sf_k-next.txt"; } \
    || sf_bad="$sf_bad [$sf_k next: rc=$sf_rc ${sf_s}s $(head -1 "$SFW/p-$sf_k-next.txt")]"
done
kill "${sf_px_pids[@]}" 2>/dev/null; wait "${sf_px_pids[@]}" 2>/dev/null
cp "$SFW/link.bak" "$SF/workflow/.hi2vi/link.json"; cp "$SFW/keys2.bak" "$SFX/hi2vi/workspace-keys.json"; chmod 600 "$SFX/hi2vi/workspace-keys.json"
# The set-up floor counts only the peer's bytes, whatever this machine's TLS library sends (a ClientHello is about
# 200 B on LibreSSL, over 1,500 B on OpenSSL 3.5). In-process, the limit at 2 s: a peer answers 39 B at 1.2 s and then
# swallows a 2,000 B ClientHello; the floor ends the set-up at 2 s (counting our own bytes, the idle limit at 3.2 s).
sf_own=$( cd "$SF" && python3 - <<'PY' 2>&1
import importlib.util, socket, sys, threading, time
spec = importlib.util.spec_from_file_location("workflow_engine", "workflow/scripts/workflow.py")
mod = importlib.util.module_from_spec(spec); sys.modules["workflow_engine"] = mod; spec.loader.exec_module(mod)
mod.CLOUD_TIMEOUT = 2
a, b = socket.socketpair()
def peer():
    time.sleep(1.2); b.sendall(b"HTTP/1.1 200 Connection established\r\n"[:37] + b"\r\n")
    while b.recv(65536): pass
threading.Thread(target=peer, daemon=True).start()
s, t = mod._CloudSocket(a, mod._CloudWire()), time.monotonic()
try:
    s.recv_into(bytearray(64)); s.sendall(b"x" * 2000); s.recv_into(bytearray(64)); print("no stall")
except mod._CloudStall as exc:
    print(f"{exc} {'early' if time.monotonic() - t < 2.8 else 'late'}")
PY
)
[ "$sf_own" = "fewer than 1024 bytes moved in 2 s early" ] || sf_bad="$sf_bad [own set-up bytes: $sf_own]"
[ -z "$sf_bad" ] && ok "behind an HTTPS proxy that answers CONNECT 6 s late then forwards nothing, or drips it, compact-resume ends inside its 9 s with the note and next in one line within 12 s, the tree unchanged; the set-up's floor counts only the peer's bytes" \
  || bad "a late or dripping HTTPS proxy --$sf_bad"
# Over TLS a byte counts as it crosses the socket, never a whole record at a time; the handshake keeps the context's
# verification. In-process, with the idle limit scaled to 2 s: a local TLS server behind a 4,000 B/s link sends a
# 17,000-byte answer, its first record 16 KiB (4 s on that link); a quick answer verifies its certificate (made here
# by openssl) and hostname, and an untrusted one is refused.
if command -v openssl >/dev/null 2>&1 && openssl req -x509 -newkey rsa:2048 -nodes -keyout "$SFW/tls.key" -out "$SFW/tls.crt" -days 2 \
     -subj /CN=localhost -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" > "$SFW/openssl.txt" 2>&1; then
  sf_tls=$( cd "$SF" && XDG_CONFIG_HOME="$SFX" python3 - "$SFW/tls.crt" "$SFW/tls.key" <<'PY' 2>&1
import importlib.util, json, socket, ssl, sys, threading, time
spec = importlib.util.spec_from_file_location("workflow_engine", "workflow/scripts/workflow.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["workflow_engine"] = mod
spec.loader.exec_module(mod)
mod.CLOUD_TIMEOUT, mod.CLOUD_FLOOR = 2, 1024
cert, key = sys.argv[1], sys.argv[2]
server_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
server_ctx.load_cert_chain(cert, key)
def listener():
    s = socket.socket()
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
    s.bind(("127.0.0.1", 0))
    s.listen(8)
    return s
def answer(c, body):
    c.sendall(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % len(body) + body)
def tls_origin(s):  # head: a quick answer; big: 17,000 bytes in one write (records of 16 KiB)
    while True:
        c, _ = s.accept()
        try:
            c = server_ctx.wrap_socket(c, server_side=True)
            line = c.recv(65536).split(b"\r\n")[0]
            answer(c, json.dumps({"x": "y" * 17000} if b"/big" in line else {"head": 1}).encode())
        except (OSError, ssl.SSLError):
            pass
        finally:
            c.close()
def link(up_port, rate):  # a slow link: each direction forwarded at <rate> bytes a second
    s = listener()
    def pump(a, b):
        try:
            while True:
                d = a.recv(max(1, rate // 20))
                if not d:
                    break
                b.sendall(d)
                time.sleep(len(d) / rate)
        except OSError:
            pass
        for x in (a, b):
            try:
                x.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
    def run():
        while True:
            c, _ = s.accept()
            u = socket.create_connection(("127.0.0.1", up_port))
            threading.Thread(target=pump, args=(c, u), daemon=True).start()
            threading.Thread(target=pump, args=(u, c), daemon=True).start()
    threading.Thread(target=run, daemon=True).start()
    return s.getsockname()[1]
def call(port, route):
    link_ = mod.CloudLink({"server": f"https://localhost:{port}", "project_id": "proj-1"}, "k-tls")
    t = time.monotonic()
    try:
        status, payload = link_.call("GET", route)
        return f"{status} {len(payload.get('x', ''))} {time.monotonic() - t:.1f}s"
    except Exception as exc:  # noqa: BLE001
        return f"{exc.__class__.__name__}: {str(exc)[:90]} {time.monotonic() - t:.1f}s"
origin = listener()
threading.Thread(target=tls_origin, args=(origin,), daemon=True).start()
slow = link(origin.getsockname()[1], 4000)
trusted = lambda: ssl.create_default_context(cafile=cert)
ssl._create_default_https_context = ssl.create_default_context
print("untrusted:", call(origin.getsockname()[1], "head"))
ssl._create_default_https_context = trusted
print("quick:", call(origin.getsockname()[1], "head"))
print("record:", call(slow, "big"))
PY
)
  printf '%s\n' "$sf_tls" | grep -q '^untrusted: CloudUnreachable: .*CERTIFICATE_VERIFY_FAILED' \
    && printf '%s\n' "$sf_tls" | grep -qE '^quick: 200 0 ' \
    && printf '%s\n' "$sf_tls" | grep -qE '^record: 200 17000 ([3-9]|1[0-9])\.[0-9]s$' \
    && ok "over TLS the handshake verifies its certificate (an untrusted one refused) and a 16 KiB record crossing a slow link counts byte by byte: 17,000 B at 4,000 B/s finish with the idle limit at 2 s ($(printf '%s' "$sf_tls" | tr '\n' ' '))" \
    || bad "TLS waits -- $(printf '%s' "$sf_tls" | tr '\n' ' ')"
else
  echo "note: no openssl to make a test certificate: the TLS row is skipped ($(tail -1 "$SFW/openssl.txt" 2>/dev/null))"
fi
# Any other failure inside the begin or the commit step (simulated: the step raises a RuntimeError) is one line too:
# before the command, it did not run (the hook prints its card and the note); after it, the change is on disk only, the
# journal stays running and names the failure, and the next command refuses naming sync.
sf_boom() { _s=$1; shift; ( cd "$SF" && XDG_CONFIG_HOME="$SFX" python3 - "$_s" "$@" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("workflow_engine", "workflow/scripts/workflow.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["workflow_engine"] = mod
spec.loader.exec_module(mod)
def boom(self, *a, **k):
    raise RuntimeError("a failure inside the step")
setattr(mod.CloudSession, sys.argv[1], boom)
sys.exit(mod.main(sys.argv[2:]))
PY
) 2>&1 | tee -a "$SF_OUT"; return "${PIPESTATUS[0]}"; }
sf_t1=$(sf_tree); sf_boom begin next > "$SFW/j.txt"; sf_rc=$?; sf_t2=$(sf_tree)
echo '{}' | sf_boom begin compact-resume > "$SFW/j2.txt"; sf_rc2=$?
sf_boom commit defer-job --title boom --reason r --trigger t --source manual > "$SFW/j3.txt"; sf_rc3=$?
sf next > "$SFW/j4.txt"; sf_rc4=$?
[ "$sf_rc" = 1 ] && [ "$(cat "$SFW/j.txt")" = "the step before the command stopped (RuntimeError: a failure inside the step), so the command did not run: run sync to see this checkout against hi2vi" ] \
  && [ "$sf_t1" = "$sf_t2" ] && [ "$sf_rc2" = 0 ] && grep -q '^compaction=done' "$SFW/j2.txt" && grep -q '^note: the step before the command stopped (RuntimeError' "$SFW/j2.txt" \
  && [ "$sf_rc3" = 1 ] && sf_no_tb "$SFW/j3.txt" && [ "$(tail -1 "$SFW/j3.txt")" = "this change is on disk but not in hi2vi (RuntimeError: a failure inside the step): run sync" ] \
  && [ "$sf_rc4" = 1 ] && grep -qF 'stopped before it finished, RuntimeError: ' "$SFW/j4.txt" \
  && ok "any other failure of the begin or the commit step is one line: the command did not run (the hook's note), or its change is on disk only with the journal naming it to the next command" \
  || bad "a non-cloud failure inside the boundary -- rc=$sf_rc/$sf_rc2/$sf_rc3/$sf_rc4 $(head -1 "$SFW/j.txt") / $(tail -1 "$SFW/j2.txt") / $(tail -1 "$SFW/j3.txt") / $(head -1 "$SFW/j4.txt")"
rm -f "$SF/workflow/.hi2vi/journal.json"; sf_m=$(sf_mark); sf next >/dev/null; sf_rc=$?; sf_r=$(sf_check "$sf_m" synced)
[ "$sf_rc" = 0 ] && [ "$sf_r" = ok ] || bad "the checkout did not settle after the simulated failure -- rc=$sf_rc $sf_r"
# A key in the key file that holds a control character is refused, and never quoted in the line.
sf_kf="$SFX/hi2vi/workspace-keys.json"; cp "$sf_kf" "$SFW/keys.bak"
python3 - "$sf_kf" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for projects in d.values():
    projects["proj-1"]["key"] += "\ntail"
json.dump(d, open(sys.argv[1], "w"))
PY
sf next > "$SFW/i9.txt"; sf_rc=$?; cp "$SFW/keys.bak" "$sf_kf"; chmod 600 "$sf_kf"
[ "$sf_rc" = 1 ] && [ "$(grep -c '' "$SFW/i9.txt")" = 1 ] && ! grep -qF "$SFK" "$SFW/i9.txt" && grep -q 'holds spaces or control characters' "$SFW/i9.txt" \
  && ok "a key file whose key holds a newline is refused with one line, and the key is not in it" \
  || bad "a key with a newline -- rc=$sf_rc $(head -2 "$SFW/i9.txt" | sed "s/$SFK/<key>/g")"
# (h) the key never reaches the tree (journal and outbox included), the output or the fake's request log.
if grep -rqF "$SFK" "$SF" "$SF_OUT" "$SFW/fake" 2>/dev/null; then bad "the workspace key leaked into the tree, the output or the request log"
else ok "the workspace key appears nowhere in the checkout (journal and outbox included), the output or the fake's request log"; fi
kill "$SF_PID" 2>/dev/null; wait "$SF_PID" 2>/dev/null
echo "cloud safety test runtime: $(( $(date +%s) - sf_t0 ))s"

# ---------------------------------------------------------------------------
echo "== Test 23: link, unlink and sync against the local fake hi2vi, with a scratch XDG_CONFIG_HOME -- the installer hides .hi2vi/ in the workflow repo (fresh and --update); link refuses http:// to a non-local host, an at-root install, uncommitted changes, another worktree, a phase in flight on a stream, a key file open to group or others, a wrong key and an already-linked checkout, each with nothing written; link reads the key from stdin, keeps it 0600 in a 0700 folder and uploads the truth set in batches under 8,000,000 B; next prints store=cloud and head sends X-Hi2vi-Base; parallel-start is refused in cloud mode with nothing written; a second checkout joins from an unused install (following fetch's rest) or an equal set, and a used one is refused with the list; a typed brief id is resolved after the pull (it names what another checkout made, on the first try, and a number shared once the pull lands is refused); sync pulls and pushes the clean changes, lists a stale write, shows its diff, refuses --keep with no path, on a folder and on a path on neither side, and resolves only on --keep local|cloud, lists an interrupted command's files and pushes none until --keep; unlink refuses on a mismatch, then leaves a local-mode tree that validates and opens no socket; unlink --from-disk runs offline; the key appears nowhere =="
lk_t0=$(date +%s)
newtmp LKW; LKX="$LKW/xdg"; LK_OUT="$LKW/out.txt"; : > "$LK_OUT"
LKA="$LKW/a"; LKB="$LKW/b"; LKC="$LKW/c"; LKR="$LKW/root"
# lk <host> <args>: one engine command in that host's nested workspace, with the scratch XDG; stdin passes through.
lk() { _h=$1; shift; ( cd "$_h" && XDG_CONFIG_HOME="$LKX" python3 workflow/scripts/workflow.py "$@" ) 2>&1 | tee -a "$LK_OUT"; return "${PIPESTATUS[0]}"; }
# lk_nosock <engine> <args>: the same under a socket guard (any connect or urlopen ends the process with 97).
lk_nosock() { _e=$1; shift; ( cd "$(dirname "$(dirname "$_e")")" && XDG_CONFIG_HOME="$LKX" python3 - "$_e" "$@" <<'PY'
import os, runpy, socket, sys, urllib.request
def guard(*a, **k):
    sys.stderr.write("SOCKET-OPENED\n")
    os._exit(97)
socket.socket.connect = guard
socket.create_connection = guard
urllib.request.urlopen = guard
urllib.request.OpenerDirector.open = guard
sys.argv = sys.argv[1:]
runpy.run_path(sys.argv[0], run_name="__main__")
PY
) 2>&1 | tee -a "$LK_OUT"; return "${PIPESTATUS[0]}"; }
lk_install() { { env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid sh "$BOOT" "$@" \
  && git -C "$1/workflow" config user.email smoke@example.invalid && git -C "$1/workflow" config user.name smoke \
  && git -C "$1/workflow" add -A && git -C "$1/workflow" commit -qm install; } > "$1.setup.txt" 2>&1 || bad "link probe: the install of $1 failed -- $(tail -3 "$1.setup.txt")"; }
lk_commit() { git -C "$1/workflow" add -A && git -C "$1/workflow" commit -qm "$2" >/dev/null; }
# The whole workflow tree's sha list (.git aside) plus the XDG folder's, to prove a refusal wrote nothing.
lk_tree() { python3 - "$1" "$LKX" <<'PY'
import hashlib, os, sys
for root in sys.argv[1:]:
    for d, dirs, files in sorted(os.walk(root)):
        dirs[:] = sorted(x for x in dirs if not (d == root and x == ".git"))
        for f in sorted(files):
            p = os.path.join(d, f)
            print(os.path.relpath(p, root), oct(os.stat(p).st_mode), hashlib.sha256(open(p, "rb").read()).hexdigest())
PY
}
lk_install "$LKA"; lk_install "$LKB"; lk_install "$LKC"
{ env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid sh "$BOOT" "$LKR" --at-root --name Root --summary root; } > "$LKW/root.setup.txt" 2>&1 \
  || bad "link probe: the at-root install failed -- $(tail -3 "$LKW/root.setup.txt")"
LKK="link-smoke-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"; LKO="other-secret-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
printf '%s\n' "$LKK" > "$LKW/key"; chmod 600 "$LKW/key"
python3 "$REPO_ROOT/tests/fake_hi2vi.py" --dir "$LKW/fake" --port-file "$LKW/port" --key-file "$LKW/key" \
  --project proj-1 --org org-1 --lifetime 900 > "$LKW/fake.txt" 2>&1 &
LK_PID=$!
for _ in $(seq 1 100); do [ -s "$LKW/port" ] && break; sleep 0.1; done
LKS="http://127.0.0.1:$(cat "$LKW/port" 2>/dev/null)"; LKU="$LKS/projects/proj-1"
lk_mark() { if [ -f "$LKW/fake/requests.jsonl" ]; then grep -c '' "$LKW/fake/requests.jsonl"; else echo 0; fi; }
lk_ctl() { python3 - "$LKS" "$1" <<'PY'
import http.client, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("POST", "/_fake/control", sys.argv[2], {"Content-Type": "application/json"})
assert conn.getresponse().status == 200
PY
}
lk_put() { python3 - "$LKS" "$1" "$2" <<'PY' || bad "link probe: the fake write failed"
import http.client, json, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("POST", "/_fake/write", json.dumps({"path": sys.argv[2], "content": sys.argv[3]}), {"Content-Type": "application/json"})
assert conn.getresponse().status == 200
PY
}
# lk_check <workflow dir> <mark> <check> [args]: one named assertion over the fake's requests since <mark>, its
# records, the checkout's base.json and journal, and its disk.
lk_check() { python3 - "$LKW/fake/requests.jsonl" "$LKS" "$@" <<'PY'
import base64, hashlib, http.client, json, sys
from pathlib import Path
from urllib.parse import urlparse, quote
log, server, root, mark, check, extra = sys.argv[1], sys.argv[2], Path(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6:]
R = [json.loads(l) for l in (Path(log).read_text().splitlines() if Path(log).exists() else [])[mark:]]
C = [r for r in R if r["path"].endswith("/commit")]
u = urlparse(server)
def get(path):
    conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
    conn.request("GET", path)
    resp = conn.getresponse()
    return resp.status, json.loads(resp.read())
S = get("/_fake/state")[1]
live = {p: f for p, f in S["files"].items() if not f["deleted"]}
hi = root / ".hi2vi"
base = json.loads((hi / "base.json").read_text()) if (hi / "base.json").exists() else {}
journal = json.loads((hi / "journal.json").read_text()) if (hi / "journal.json").exists() else None
def sha(p):
    return hashlib.sha256((root / p).read_bytes()).hexdigest()
def cloud(p):
    return base64.b64decode(get("/_fake/file?path=" + quote(p))[1]["content"]).decode()
def need(cond, why):
    if not cond:
        print(why)
        sys.exit(1)
def synced():
    need(journal is None, f"the journal is left: {journal}")
    need(base.get("head") == S["head"], f"base head {base.get('head')} != hi2vi head {S['head']}")
    need(set(base["files"]) == set(live), f"base and hi2vi hold different paths: {sorted(set(base['files']) ^ set(live))[:4]}")
    for p, f in live.items():
        need(base["files"][p]["rev"] == f["rev"] and (root / p).is_file() and sha(p) == f["sha256"], f"{p}: base, disk and hi2vi disagree")
if check == "nothing":  # a refusal: no request reached the fake
    need(not R, f"a refused link reached hi2vi: {[r['path'] for r in R]}")
elif check == "upload":
    need(len(C) >= 2 and all(c["status"] == 200 for c in C), f"several landed batches expected: {[(c['status'], c.get('bytes')) for c in C]}")
    need(all(0 < c["bytes"] < 8_000_000 for c in C), f"a batch over 8,000,000 B: {[c.get('bytes') for c in C]}")
    need(all(c["batch"]["command"].startswith("link ") for c in C), "the upload's batches do not name link")
    ops = [op for c in C for op in c["batch"]["ops"]]
    need(all(op["op"] in ("put", "append") and op.get("base_rev") is None for op in ops), "the first upload only adds")
    need(len([p for p in live if "/topics/big-" in p]) == 3 and "works/phases/active/P1/phase.json" in live, "a file is missing in hi2vi")
    link = json.loads((hi / "link.json").read_text())
    need(link.get("server") == server and link.get("org_id") == "org-1" and link.get("project_id") == "proj-1" and "key" not in link,
         f"link.json: {link}")
    synced()
elif check == "next":  # extra: the line next printed
    heads = [r for r in R if r["path"].endswith("/head")]
    need(heads and all(r.get("base") == str(base.get("head")) for r in heads), f"head did not send X-Hi2vi-Base {base.get('head')}: {[r.get('base') for r in heads]}")
    need(extra[0] == f"store=cloud server={server} project=proj-1", f"next's store line: {extra[0]!r}")
elif check == "join":  # extra: page (the fetch followed rest)
    fetches = [r for r in R if r["path"].endswith("/fetch")]
    need(not C or all(c["status"] == 200 for c in C), "a join's batch failed")
    need(len(fetches) >= 2 and any(r.get("rest") for r in fetches), f"the join did not follow rest: {[(len(r['paths']), r.get('rest')) for r in fetches]}")
    synced()
elif check == "synced":
    synced()
elif check == "stale":  # extra: path, the cloud's content, revisions before
    path, content = extra[0], extra[1]
    need(all(op.get("path") != path for c in C for op in c["batch"]["ops"]), "sync sent the stale path")
    need(cloud(path) == content, "hi2vi's copy changed")
    need("changed here" in (root / path).read_text(), "the disk lost this checkout's change")
elif check == "clean":  # extra: the pulled path, the pushed path
    need((root / extra[0]).is_file() and extra[0] in live and sha(extra[0]) == live[extra[0]]["sha256"], "the clean cloud change was not pulled")
    need(extra[1] in live and sha(extra[1]) == live[extra[1]]["sha256"], "the clean local change was not pushed")
elif check == "kept-local":  # extra: path
    need(len(C) == 1 and C[0]["status"] == 200 and C[0]["batch"]["command"] == f"sync --keep local {extra[0]}", f"one keep batch expected: {[(c['status'], c['batch'].get('command')) for c in C]}")
    need(cloud(extra[0]) == (root / extra[0]).read_text(), "hi2vi does not hold the disk's copy")
elif check == "kept-cloud":  # extra: path, content
    need(not C, "keep cloud sent a batch")
    need((root / extra[0]).read_text() == extra[1] == cloud(extra[0]), "the disk does not hold hi2vi's copy")
elif check == "interrupted":  # extra: revisions before
    need(not C and S["revisions"] == int(extra[0]), "sync pushed an interrupted command's changes")
    need(journal is not None and journal.get("state") == "running", f"the journal is not running: {journal}")
elif check == "kept-append":
    ops = [op for c in C for op in c["batch"]["ops"] if op.get("path") == "works/events.jsonl"]
    need(len(C) == 1 and C[0]["status"] == 200 and [op["op"] for op in ops] == ["append"], f"events.jsonl kept as {[op['op'] for op in ops]}")
elif check == "revs":  # extra: revisions before (unchanged)
    need(S["revisions"] == int(extra[0]) and not C, "a refused sync changed hi2vi")
elif check == "quiet":  # a refusal or a read after a pull: no batch sent, the pull recorded, no journal left
    need(not C, f"a batch was sent: {[c['batch'].get('command') for c in C]}")
    synced()
print("ok")
PY
}
lk_revs() { python3 - "$LKS" <<'PY'
import http.client, json, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("GET", "/_fake/state")
print(json.loads(conn.getresponse().read())["revisions"])
PY
}
# (h) the installer hides .hi2vi/ in the workflow repo's own info/exclude, on a fresh install and on --update.
lk_ex="$LKB/workflow/.git/info/exclude"; grep -qx '/.hi2vi/' "$LKA/workflow/.git/info/exclude"; lk_rc=$?
grep -vx '/.hi2vi/' "$lk_ex" > "$LKW/ex"; cat "$LKW/ex" > "$lk_ex"; grep -qx '/.hi2vi/' "$lk_ex"; lk_rc2=$?
sh "$BOOT" "$LKB" --update > "$LKW/update.txt" 2>&1; lk_rc3=$?; ( lk_commit "$LKB" update ) 2>/dev/null
[ "$lk_rc" = 0 ] && [ "$lk_rc2" = 1 ] && [ "$lk_rc3" = 0 ] && grep -qx '/.hi2vi/' "$lk_ex" \
  && ok "the installer hides .hi2vi/ in the workflow repo's own info/exclude, on a fresh install and on --update" \
  || bad "the .hi2vi/ exclude is missing -- fresh=$lk_rc stripped=$lk_rc2 update=$lk_rc3 $(tail -2 "$LKW/update.txt")"
# A phase with three 3 MB topics in A (committed): the first upload must split.
( lk "$LKA" new-phase --phase P1 --name One --objective toy >/dev/null ) && mkdir -p "$LKA/workflow/works/phases/active/P1/topics"
for i in 1 2 3; do python3 -c 'import sys; open(sys.argv[1], "w").write(("line of a big topic %s\n" % sys.argv[2]) * 140000)' \
  "$LKA/workflow/works/phases/active/P1/topics/big-$i.md" "$i"; done
lk_commit "$LKA" phase
# (a) the refusals, each one line with nothing written: no request, the tree and the XDG folder unchanged.
lk_ref() {  # lk_ref <label> <expected line ERE> <host> <engine> <args...>: run under the socket guard, key on stdin
  _l=$1; _x=$2; _h=$3; shift 3; _t1=$(lk_tree "$_h"); _m=$(lk_mark)
  printf '%s\n' "$LKK" | lk_nosock "$@" > "$LKW/ref.txt"; _rc=$?
  _t2=$(lk_tree "$_h"); _r=$(lk_check "$_h" "$_m" nothing)
  [ "$_rc" = 1 ] && [ "$(grep -v '^Paste a workspace key' "$LKW/ref.txt" | grep -c '')" = 1 ] && grep -qE "$_x" "$LKW/ref.txt" && [ "$_t1" = "$_t2" ] && [ "$_r" = ok ] \
    && [ ! -e "$_h/.hi2vi" ] && ! grep -qF "$LKK" "$LKW/ref.txt" \
    && ok "link refuses $_l with one line, opens no socket and writes nothing" \
    || bad "link did not refuse $_l cleanly -- rc=$_rc $_r $(head -2 "$LKW/ref.txt") $(diff <(echo "$_t1") <(echo "$_t2") | head -3)"
}
lk_ref "http:// to a non-local host" '^hi2vi server http://hi2vi\.example must be https://' "$LKA/workflow" "$LKA/workflow/scripts/workflow.py" link http://hi2vi.example/projects/proj-1
lk_ref "an at-root install" '^link refuses an at-root install' "$LKR" "$LKR/scripts/workflow.py" link "$LKU"
printf 'not committed\n' > "$LKA/workflow/works/phases/active/P1/topics/loose.md"
lk_ref "uncommitted changes in the workflow repo" '^link refuses a workflow repo with uncommitted changes \(1 path\(s\), first works/phases/active/P1/topics/loose\.md\)' "$LKA/workflow" "$LKA/workflow/scripts/workflow.py" link "$LKU"
rm -f "$LKA/workflow/works/phases/active/P1/topics/loose.md"
git -C "$LKA/workflow" worktree add -q "$LKW/wt" -b side >/dev/null 2>&1
lk_ref "while the workflow repo has another worktree" '^link refuses while the workflow repo has another worktree' "$LKA/workflow" "$LKA/workflow/scripts/workflow.py" link "$LKU"
git -C "$LKA/workflow" worktree remove "$LKW/wt" >/dev/null 2>&1; git -C "$LKA/workflow" branch -q -D side >/dev/null 2>&1
( lk "$LKC" new-phase --phase P1 --name Other --objective toy >/dev/null ) && lk_commit "$LKC" phase
python3 - "$LKC/workflow/works/phases/active/P1/phase.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["execution"] = {"mode": "parallel", "branch": "phase/P1-other", "worktree": None}
open(sys.argv[1], "w").write(json.dumps(d, indent=2) + "\n")
PY
lk_commit "$LKC" stamp
lk_ref "while a phase is in flight on its own stream" '^link refuses while a phase is in flight on its own stream \(P1\)' "$LKC/workflow" "$LKC/workflow/scripts/workflow.py" link "$LKU"
git -C "$LKC/workflow" reset -q --hard HEAD~1
mkdir -p "$LKX/hi2vi" && chmod 700 "$LKX/hi2vi" && printf '{"https://elsewhere.example": {"p": {"key": "%s"}}}\n' "$LKO" > "$LKX/hi2vi/workspace-keys.json" && chmod 644 "$LKX/hi2vi/workspace-keys.json"
lk_ref "a key file open to group or others (with the chmod fix, never the key)" "workspace-keys\.json can be read by group or others \(mode 0644\), and it holds workspace keys: run chmod 600 .*workspace-keys\.json, then run this again" "$LKA/workflow" "$LKA/workflow/scripts/workflow.py" link "$LKU"
grep -qF "$LKO" "$LKW/ref.txt" && bad "the 0644 refusal printed a key"
chmod 600 "$LKX/hi2vi/workspace-keys.json"
lk_t1=$(lk_tree "$LKA/workflow"); printf 'not-the-key\n' | lk "$LKA" link "$LKU" > "$LKW/a6.txt"; lk_rc=$?; lk_t2=$(lk_tree "$LKA/workflow")
[ "$lk_rc" = 1 ] && grep -qx "hi2vi refused this key (HTTP 401): make a workspace key under Keys on the project's page: nothing was written" "$LKW/a6.txt" && [ "$lk_t1" = "$lk_t2" ] && [ ! -e "$LKA/workflow/.hi2vi" ] \
  && ok "link refuses a key hi2vi does not take (401) with one line and writes nothing (no .hi2vi/, the key file unchanged)" \
  || bad "a wrong key was not refused cleanly -- rc=$lk_rc $(tail -2 "$LKW/a6.txt")"
# (b) the link: the key from stdin, kept owner-only beside the other server's; the truth set uploaded in batches.
lk_m=$(lk_mark); printf '%s\n' "$LKK" | lk "$LKA" link "$LKU" > "$LKW/b.txt"; lk_rc=$?; lk_r=$(lk_check "$LKA/workflow" "$lk_m" upload)
lk_modes=$(python3 -c 'import os, stat, sys; print("%o %o" % (stat.S_IMODE(os.stat(sys.argv[1]).st_mode), stat.S_IMODE(os.stat(sys.argv[2]).st_mode)))' "$LKX/hi2vi" "$LKX/hi2vi/workspace-keys.json")
lk_keys=$(python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(sorted(d), d[sys.argv[2]]["proj-1"]["key"] == sys.argv[3], d[sys.argv[2]]["proj-1"]["org_id"])' "$LKX/hi2vi/workspace-keys.json" "$LKS" "$LKK")
[ "$lk_rc" = 0 ] && [ "$lk_r" = ok ] && [ "$lk_modes" = "700 600" ] && [ "$lk_keys" = "['$LKS', 'https://elsewhere.example'] True org-1" ] \
  && grep -qxE "store=cloud server=$LKS project=proj-1 head=r[0-9]+" "$LKW/b.txt" && [ -z "$(git -C "$LKA/workflow" status --porcelain)" ] \
  && ok "link reads the key from stdin, verifies it by head, keeps it in a 0700 folder's 0600 file beside the other server's key, writes link.json without it and uploads the truth set as several batches under 8,000,000 B; the workflow repo stays clean (.hi2vi/ excluded)" \
  || bad "the link upload wrong -- rc=$lk_rc $lk_r modes=$lk_modes keys=$lk_keys $(tail -2 "$LKW/b.txt") $(git -C "$LKA/workflow" status --porcelain | head -3)"
lk_m=$(lk_mark); lk "$LKA" next > "$LKW/b2.txt"; lk_rc=$?; lk_r=$(lk_check "$LKA/workflow" "$lk_m" next "$(grep '^store=' "$LKW/b2.txt")")
[ "$lk_rc" = 0 ] && [ "$lk_r" = ok ] && ok "next prints store=cloud server=<server> project=<id> in a linked checkout, and its head request sends X-Hi2vi-Base: <synced head>" \
  || bad "next's store line or X-Hi2vi-Base wrong -- rc=$lk_rc $lk_r"
lk_ref "an already-linked checkout" '^this checkout is already linked \(store=cloud server=' "$LKB/workflow" "$LKA/workflow/scripts/workflow.py" link "$LKU"
# (f) O7: in cloud mode a stream command is refused with one line, before any request, with nothing written.
lk_t1=$(lk_tree "$LKA/workflow"); lk_m=$(lk_mark); lk_nosock "$LKA/workflow/scripts/workflow.py" parallel-start P1 --host-branch side > "$LKW/f.txt"; lk_rc=$?; lk_t2=$(lk_tree "$LKA/workflow")
[ "$lk_rc" = 1 ] && [ "$(grep -c '' "$LKW/f.txt")" = 1 ] && grep -q '^parallel-start is refused in cloud mode: ' "$LKW/f.txt" && [ "$lk_t1" = "$lk_t2" ] && [ "$(lk_check "$LKA/workflow" "$lk_m" nothing)" = ok ] \
  && [ -z "$(git -C "$LKA/workflow" branch --list 'phase/*')" ] \
  && ok "parallel-start in a linked checkout is refused with one line, no request, no branch and nothing written" \
  || bad "parallel-start was not refused in cloud mode -- rc=$lk_rc $(head -2 "$LKW/f.txt")"
lk_bad=""; lk_t1=$(lk_tree "$LKA/workflow"); lk_m=$(lk_mark)
for c in "parallel-gate P1" "parallel-teardown P1" "parallel-merge-finish" "parallel-consolidated P1" "reopen-phase P1 --note x" "loop-checkpoint P1 --landed"; do
  # shellcheck disable=SC2086
  lk_nosock "$LKA/workflow/scripts/workflow.py" $c > "$LKW/f2.txt"; lk_rc=$?
  { [ "$lk_rc" = 1 ] && [ "$(grep -c '' "$LKW/f2.txt")" = 1 ] && grep -q "^${c%% *}\( --landed\)\? is refused in cloud mode: " "$LKW/f2.txt"; } || lk_bad="$lk_bad [$c: rc=$lk_rc $(head -1 "$LKW/f2.txt")]"
done
lk_t2=$(lk_tree "$LKA/workflow")
[ -z "$lk_bad" ] && [ "$lk_t1" = "$lk_t2" ] && [ "$(lk_check "$LKA/workflow" "$lk_m" nothing)" = ok ] \
  && ok "the other stream commands (parallel-gate, -teardown, -merge-finish, -consolidated, reopen-phase, loop-checkpoint --landed) are refused in cloud mode with one line each, nothing written" \
  || bad "a stream command ran in cloud mode --$lk_bad"
# (c) a second checkout: an unused install joins (the fetch paged, following rest); a used one is refused with the list.
lk_ctl '{"fetch_page": 4000}'; lk_m=$(lk_mark); printf '%s\n' "$LKK" | lk "$LKB" link "$LKU" > "$LKW/c.txt"; lk_rc=$?; lk_r=$(lk_check "$LKB/workflow" "$lk_m" join)
lk_ctl '{"fetch_page": null}'
[ "$lk_rc" = 0 ] && [ "$lk_r" = ok ] && grep -q "^linked: joined hi2vi's workspace ([0-9]* file(s) taken from hi2vi, this unused install's seed files replaced)" "$LKW/c.txt" \
  && [ -f "$LKB/workflow/works/phases/active/P1/topics/big-2.md" ] && grep -qF 'One' "$LKB/workflow/works/backlog.md" \
  && ok "a second checkout joins from an unused install: its seed files give way, every file is taken from hi2vi (fetch pages followed through rest) and the generated files are rebuilt" \
  || bad "the unused install did not join -- rc=$lk_rc $lk_r $(tail -3 "$LKW/c.txt")"
lk_t1=$(lk_tree "$LKC/workflow"); lk_m=$(lk_mark); printf '%s\n' "$LKK" | lk "$LKC" link "$LKU" > "$LKW/c2.txt"; lk_rc=$?; lk_t2=$(lk_tree "$LKC/workflow")
[ "$lk_rc" = 1 ] && grep -q "^link refuses: hi2vi already holds this project's workspace (r[0-9]*), and [0-9]* path(s) here differ from it" "$LKW/c2.txt" \
  && grep -qx 'differs  works/phases/active/P1/phase.json' "$LKW/c2.txt" && [ "$lk_t1" = "$lk_t2" ] && [ ! -e "$LKC/workflow/.hi2vi" ] \
  && ok "a used checkout is refused at the join with the list of differing paths, and nothing is written" \
  || bad "a used checkout's join was not refused with the list -- rc=$lk_rc $(head -4 "$LKW/c2.txt")"
lk_nosock "$LKB/workflow/scripts/workflow.py" unlink --from-disk > "$LKW/c3.txt"; lk_rc=$?
[ "$lk_rc" = 0 ] && [ ! -e "$LKB/workflow/.hi2vi" ] && grep -q '^unlinked from the disk, offline: changes made in hi2vi after r[0-9]* are not on this disk' "$LKW/c3.txt" \
  && grep -qx 'local mode: the files on disk are the truth again; commit them (git -C workflow add -A && git -C workflow commit)' "$LKW/c3.txt" \
  && ok "unlink --from-disk runs offline (no socket), removes .hi2vi/ and says what the disk cannot hold" \
  || bad "unlink --from-disk wrong -- rc=$lk_rc $(head -3 "$LKW/c3.txt")"
lk_commit "$LKB" unlinked; lk_m=$(lk_mark); printf '%s\n' "$LKK" | lk "$LKB" link "$LKU" > "$LKW/c4.txt"; lk_rc=$?; lk_r=$(lk_check "$LKB/workflow" "$lk_m" synced)
[ "$lk_rc" = 0 ] && [ "$lk_r" = ok ] && grep -q "^linked: joined hi2vi's workspace (0 file(s) taken from hi2vi)" "$LKW/c4.txt" \
  && ok "a checkout whose files equal hi2vi's joins with nothing taken" || bad "an equal set did not join -- rc=$lk_rc $lk_r $(tail -2 "$LKW/c4.txt")"
# A typed id is resolved after the begin step's pull: a brief id names what another checkout made since this one
# last pulled, on the first try (A makes each record, then B's very next command names it by its brief form).
lk_bad=""
lk_brief() {  # lk_brief <A's command> <B's command> <B's expected line ERE>
  _a=$1; _b=$2; _x=$3
  # shellcheck disable=SC2086
  lk "$LKA" $_a > "$LKW/br-a.txt" || lk_bad="$lk_bad [A: $_a: $(tail -1 "$LKW/br-a.txt")]"
  # shellcheck disable=SC2086
  lk "$LKB" $_b > "$LKW/br-b.txt"; _rc=$?
  { [ "$_rc" = 0 ] && grep -qE "$_x" "$LKW/br-b.txt"; } || lk_bad="$lk_bad [B: $_b: rc=$_rc $(head -1 "$LKW/br-b.txt")]"
}
lk_brief "new-phase --phase 7-ab --name Brief --objective toy" "phase-section 7" '^ +[0-9]+  Objective$'
lk_brief "new-slice --phase P7-ab --slice P7-ab.S1 --name s" "executor-route 7.S1" '^slice=P7-ab\.S1$'
lk_brief "defer-job --id 7-cd --title brief --reason r --trigger t --source manual" "drop-deferred 7 --reason r" '^dropped D7-cd: '
lk_brief "agenda-add --id 7-ef --title brief" "agenda-solve 7 --outcome done" '^solved A7-ef'
[ -z "$lk_bad" ] \
  && ok "in a linked checkout a brief id names what another checkout made since the last pull, on the first try: a phase number (phase-section 7), a slice's brief phase part (executor-route 7.S1), a deferred job's number (drop-deferred 7) and an agenda item's (agenda-solve 7)" \
  || bad "a brief id was resolved against the stale disk, before the pull --$lk_bad"
# A number unique on B's stale disk but shared once the pull lands is refused with the list, one line; the
# refusal still runs the commit step (no journal left, the pull recorded, nothing sent), and the full id runs.
( lk "$LKA" new-phase --phase 7-zz --name Twin --objective toy >/dev/null )
lk_m=$(lk_mark); lk "$LKB" phase-section 7 > "$LKW/br-c.txt"; lk_rc=$?; lk_r=$(lk_check "$LKB/workflow" "$lk_m" quiet)
lk_m=$(lk_mark); lk "$LKB" phase-section 7-zz > "$LKW/br-d.txt"; lk_rc2=$?; lk_r2=$(lk_check "$LKB/workflow" "$lk_m" quiet)
lk "$LKA" executor-route 7-ab.S1 > "$LKW/br-e.txt"; lk_rc3=$?
[ "$lk_rc" = 1 ] && [ "$(grep -c '' "$LKW/br-c.txt")" = 1 ] && grep -qx "'7' names 2 phases numbered 7: P7-ab, P7-zz -- type the tail (e.g. P7-ab or 7-ab)" "$LKW/br-c.txt" \
  && [ "$lk_r" = ok ] && [ "$lk_rc2" = 0 ] && grep -qE '^ +[0-9]+  Objective$' "$LKW/br-d.txt" && [ "$lk_r2" = ok ] \
  && [ "$lk_rc3" = 0 ] && grep -qx 'slice=P7-ab.S1' "$LKW/br-e.txt" \
  && ok "a brief id unique on the stale disk but shared after the pull is refused with the list in one line, exit 1; the commit step still runs (no journal left, the pull recorded, nothing sent); the full id then runs, and a tailed brief id of a record on the disk still resolves" \
  || bad "a number shared after the pull was not refused cleanly -- rc=$lk_rc/$lk_rc2/$lk_rc3 $lk_r / $lk_r2 $(head -2 "$LKW/br-c.txt")"
# (d) sync in A: a stale write (409) beside a clean change on each side.
lk_p=works/phases/active/P1/intent.md; printf 'changed here\n' >> "$LKA/workflow/$lk_p"
lk_ctl "{\"race\": {\"path\": \"$lk_p\", \"content\": \"changed in hi2vi by another checkout\\n\"}}"
lk "$LKA" next > "$LKW/d0.txt"; lk_rc0=$?
lk_put works/phases/active/P1/topics/cloud.md 'written in hi2vi
'; printf 'written here\n' > "$LKA/workflow/works/phases/active/P1/topics/local.md"
lk_v=$(lk_revs); lk_m=$(lk_mark); lk "$LKA" sync > "$LKW/d.txt"; lk_rc=$?
lk_r=$(lk_check "$LKA/workflow" "$lk_m" clean works/phases/active/P1/topics/cloud.md works/phases/active/P1/topics/local.md)
lk_r2=$(lk_check "$LKA/workflow" "$lk_m" stale "$lk_p" 'changed in hi2vi by another checkout
' "$lk_v")
[ "$lk_rc0" = 1 ] && [ "$lk_rc" = 1 ] && [ "$lk_r" = ok ] && [ "$lk_r2" = ok ] \
  && grep -qE "^differs  $lk_p  here: changed since r[0-9]+ \(.+\)  hi2vi: r[0-9]+$" "$LKW/d.txt" && [ "$(grep -cE '^(differs|here only|cloud only|deleted|interrupted)' "$LKW/d.txt")" = 1 ] \
  && ok "sync pulls the clean hi2vi change, pushes the clean local one, and lists the stale write (differs, both sides' facts), resolving nothing: exit 1" \
  || bad "sync's list wrong -- rc=$lk_rc0/$lk_rc $lk_r / $lk_r2 / $(head -4 "$LKW/d.txt")"
lk "$LKA" sync --diff "$lk_p" > "$LKW/d2.txt"; lk_rc=$?
[ "$lk_rc" = 0 ] && grep -qx -- '-changed in hi2vi by another checkout' "$LKW/d2.txt" && grep -qx -- '+changed here' "$LKW/d2.txt" && grep -q "^--- hi2vi/$lk_p (r[0-9]*)" "$LKW/d2.txt" \
  && ok "sync --diff shows hi2vi's copy against the disk as a unified diff" || bad "sync --diff wrong -- rc=$lk_rc $(head -5 "$LKW/d2.txt")"
lk_v=$(lk_revs); lk_m=$(lk_mark); lk "$LKA" sync --keep local > "$LKW/d3.txt"; lk_rc=$?; lk_r=$(lk_check "$LKA/workflow" "$lk_m" revs "$lk_v")
lk "$LKA" next > "$LKW/d4.txt"; lk_rc2=$?
[ "$lk_rc" != 0 ] && [ "$(grep -c '' "$LKW/d3.txt")" = 1 ] && grep -q '^sync --keep needs at least one path' "$LKW/d3.txt" && [ "$lk_r" = ok ] \
  && [ "$lk_rc2" = 1 ] && grep -q '^1 files differ between this checkout and hi2vi: run sync' "$LKW/d4.txt" \
  && ok "sync --keep with no path is refused with one line and nothing sent; the stale write still stops the next command" \
  || bad "sync --keep without a path was not refused -- rc=$lk_rc/$lk_rc2 $lk_r $(head -2 "$LKW/d3.txt") / $(head -1 "$LKW/d4.txt")"
# --keep takes only a file on one side or the other: a folder, or a path on neither side, is refused with one line,
# nothing sent and nothing written (never "hi2vi holds it now", never a traceback); so is --diff on a folder.
lk_bad=""
for lk_args in "--keep local works/agenda" "--keep local works/no-such-file.md" "--keep cloud works/agenda" "--keep cloud works/no-such-file.md" "--diff works/agenda"; do
  lk_v=$(lk_revs); lk_m=$(lk_mark); lk_t1=$(lk_tree "$LKA/workflow")
  # shellcheck disable=SC2086
  lk "$LKA" sync $lk_args > "$LKW/d9.txt"; lk_rc=$?; lk_t2=$(lk_tree "$LKA/workflow"); lk_r=$(lk_check "$LKA/workflow" "$lk_m" revs "$lk_v")
  case "$lk_args" in *agenda) lk_want='^works/agenda is a folder: sync takes file paths, one by one as sync lists them \(nothing was changed\)$' ;;
    *) lk_want='^sync --keep refused: works/no-such-file\.md names no file here or in hi2vi; it takes the file paths sync lists \(nothing was changed\)$' ;; esac
  { [ "$lk_rc" = 1 ] && [ "$(grep -c '' "$LKW/d9.txt")" = 1 ] && grep -qE "$lk_want" "$LKW/d9.txt" && [ "$lk_r" = ok ] && [ "$lk_t1" = "$lk_t2" ]; } \
    || lk_bad="$lk_bad [sync $lk_args: rc=$lk_rc $lk_r $(head -1 "$LKW/d9.txt")]"
done
lk "$LKA" next > "$LKW/d4.txt"; lk_rc2=$?
[ -z "$lk_bad" ] && [ "$lk_rc2" = 1 ] && grep -q '^1 files differ between this checkout and hi2vi: run sync' "$LKW/d4.txt" \
  && ok "sync --keep local|cloud on a folder or on a path on neither side, and sync --diff on a folder, are refused with one line each, nothing sent, the tree unchanged; the stale write still waits" \
  || bad "sync --keep on a folder or an unknown path was not refused --$lk_bad rc=$lk_rc2 $(head -1 "$LKW/d4.txt")"
lk_m=$(lk_mark); lk "$LKA" sync --keep local "$lk_p" > "$LKW/d5.txt"; lk_rc=$?; lk_r=$(lk_check "$LKA/workflow" "$lk_m" kept-local "$lk_p")
lk_m=$(lk_mark); lk "$LKA" sync > "$LKW/d6.txt"; lk_rc2=$?; lk_r2=$(lk_check "$LKA/workflow" "$lk_m" synced)
lk "$LKA" sync --status > "$LKW/d7.txt"; lk_rc3=$?
[ "$lk_rc" = 0 ] && [ "$lk_r" = ok ] && [ "$lk_rc2" = 0 ] && [ "$lk_r2" = ok ] && grep -q '^in sync: ' "$LKW/d6.txt" && grep -qE '^in sync: head=r([0-9]+) base=r\1$' "$LKW/d5.txt" && [ "$lk_rc3" = 0 ] \
  && grep -qxE "store=cloud server=$LKS project=proj-1 head=r([0-9]+) base=r\1 here=0 differ=0 inbox=0" "$LKW/d7.txt" \
  && ok "sync --keep local <path> pushes the disk's copy over hi2vi's revision (recorded as that command); then sync is clean and sync --status reads head=base, here=0 differ=0" \
  || bad "sync --keep local wrong -- rc=$lk_rc/$lk_rc2/$lk_rc3 $lk_r / $lk_r2 / $(cat "$LKW/d7.txt")"
printf 'changed here again\n' >> "$LKA/workflow/$lk_p"
lk_ctl "{\"race\": {\"path\": \"$lk_p\", \"content\": \"hi2vi wins this one\\n\"}}"; lk "$LKA" next >/dev/null
lk_m=$(lk_mark); lk "$LKA" sync --keep cloud "$lk_p" > "$LKW/d8.txt"; lk_rc=$?; lk_r=$(lk_check "$LKA/workflow" "$lk_m" kept-cloud "$lk_p" 'hi2vi wins this one
')
lk_m=$(lk_mark); lk "$LKA" next >/dev/null; lk_rc2=$?; lk_r2=$(lk_check "$LKA/workflow" "$lk_m" synced)
[ "$lk_rc" = 0 ] && [ "$lk_r" = ok ] && [ "$lk_rc2" = 0 ] && [ "$lk_r2" = ok ] \
  && ok "sync --keep cloud <path> writes hi2vi's copy over the disk, and the next command runs synced" \
  || bad "sync --keep cloud wrong -- rc=$lk_rc/$lk_rc2 $lk_r / $lk_r2 $(tail -2 "$LKW/d8.txt")"
# An interrupted command: sync lists its files as interrupted and pushes none of them until --keep.
( cd "$LKA" && XDG_CONFIG_HOME="$LKX" python3 - defer-job --title killed --reason r --trigger t --source manual <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("workflow_engine", "workflow/scripts/workflow.py")
mod = importlib.util.module_from_spec(spec)
sys.modules["workflow_engine"] = mod
spec.loader.exec_module(mod)
real = mod.defer_job
def crash(args):
    real(args)
    os._exit(9)
mod.defer_job = crash
sys.exit(mod.main(sys.argv[1:]))
PY
) >> "$LK_OUT" 2>&1
lk_v=$(lk_revs); lk_m=$(lk_mark); lk "$LKA" sync > "$LKW/e.txt"; lk_rc=$?; lk_r=$(lk_check "$LKA/workflow" "$lk_m" interrupted "$lk_v")
lk_ip=$(grep '^interrupted  ' "$LKW/e.txt" | awk '{print $2}' | tr '\n' ' ')
[ "$lk_rc" = 1 ] && [ "$lk_r" = ok ] && echo "$lk_ip" | grep -q 'works/deferred/open/.*/deferred.json' \
  && ok "after a command killed midway, sync lists its files as interrupted and pushes none of them (the journal stays running)" \
  || bad "sync did not hold the interrupted files -- rc=$lk_rc $lk_r $(head -3 "$LKW/e.txt")"
# shellcheck disable=SC2086
lk_m=$(lk_mark); lk "$LKA" sync --keep local $lk_ip > "$LKW/e2.txt"; lk_rc=$?; lk_r0=$(lk_check "$LKA/workflow" "$lk_m" kept-append)
lk_m=$(lk_mark); lk "$LKA" next >/dev/null; lk_rc2=$?; lk_r=$(lk_check "$LKA/workflow" "$lk_m" synced)
[ "$lk_rc" = 0 ] && [ "$lk_rc2" = 0 ] && [ "$lk_r0" = ok ] && [ "$lk_r" = ok ] && grep -q '^the interrupted command (defer-job --title killed' "$LKW/e2.txt" \
  && ok "sync --keep local on the interrupted files pushes them (works/events.jsonl as its new lines, never a put), clears the journal, and the next command runs synced" \
  || bad "resolving the interrupted state wrong -- rc=$lk_rc/$lk_rc2 $lk_r0 / $lk_r $(head -3 "$LKW/e2.txt")"
# (e) unlink: refused on a mismatch (still linked), then the way back to local mode.
printf 'one more\n' >> "$LKA/workflow/$lk_p"
lk_ctl "{\"race\": {\"path\": \"$lk_p\", \"content\": \"and another\\n\"}}"; lk "$LKA" next >/dev/null
lk "$LKA" unlink > "$LKW/g.txt"; lk_rc=$?
[ "$lk_rc" = 1 ] && [ -f "$LKA/workflow/.hi2vi/link.json" ] && grep -q '^unlink refused, the checkout is still linked: 1 files differ between this checkout and hi2vi' "$LKW/g.txt" \
  && ok "unlink refuses on a mismatch with one line, and the checkout stays linked" || bad "unlink did not refuse on a mismatch -- rc=$lk_rc $(head -2 "$LKW/g.txt")"
lk "$LKA" sync --keep local "$lk_p" >/dev/null
lk_m=$(lk_mark); lk "$LKA" unlink > "$LKW/g2.txt"; lk_rc=$?
lk "$LKA" validate > "$LKW/g3.txt"; lk_rc2=$?
lk_in=""; for c in "next" "new-phase --phase P2 --name Two --objective toy" "defer-job --title local --reason r --trigger t --source manual" "rebuild"; do
  # shellcheck disable=SC2086
  lk_nosock "$LKA/workflow/scripts/workflow.py" $c > "$LKW/g4.txt"; [ "$?" = 97 ] && lk_in="$lk_in [$c]"
done
[ "$lk_rc" = 0 ] && [ ! -e "$LKA/workflow/.hi2vi" ] && grep -qx 'local mode: the files on disk are the truth again; commit them (git -C workflow add -A && git -C workflow commit)' "$LKW/g2.txt" \
  && [ "$lk_rc2" = 0 ] && [ -z "$lk_in" ] && [ -d "$LKA/workflow/works/phases/active/P2" ] && grep -qF "$LKS" "$LKX/hi2vi/workspace-keys.json" \
  && ok "unlink pulls and pushes, removes .hi2vi/ and prints the one-commit line; the tree validates, local commands open no socket, and the key stays in user config" \
  || bad "unlink wrong -- rc=$lk_rc/$lk_rc2 nosock:$lk_in $(head -3 "$LKW/g2.txt") / $(tail -2 "$LKW/g3.txt")"
# The key file's mode is checked at every linked command too (B is linked): 0644 refuses before any request.
chmod 644 "$LKX/hi2vi/workspace-keys.json"; lk_m=$(lk_mark); lk "$LKB" next > "$LKW/k.txt"; lk_rc=$?; chmod 600 "$LKX/hi2vi/workspace-keys.json"
[ "$lk_rc" = 1 ] && grep -q 'workspace-keys.json can be read by group or others (mode 0644)' "$LKW/k.txt" && [ "$(lk_check "$LKB/workflow" "$lk_m" nothing)" = ok ] \
  && ok "a linked command with the key file at 0644 is refused with the chmod fix, before any request" \
  || bad "a 0644 key file was used by a linked command -- rc=$lk_rc $(head -2 "$LKW/k.txt")"
# (g) the key never reaches a tree (.hi2vi/ included), the output, the events or the fake's request log.
if grep -rqF "$LKK" "$LKA" "$LKB" "$LKC" "$LKR" "$LK_OUT" "$LKW/fake" "$LKW"/*.txt 2>/dev/null; then bad "the workspace key leaked into a tree, the output or the request log"
else ok "the workspace key appears nowhere in the checkouts (.hi2vi/ and events included), the commands' output or the fake's request log"; fi
kill "$LK_PID" 2>/dev/null; wait "$LK_PID" 2>/dev/null
echo "link test runtime: $(( $(date +%s) - lk_t0 ))s"

# ---------------------------------------------------------------------------
echo "== Test 24: the web's agenda inbox, applied by a linked engine against the local fake hi2vi -- at next, sync and run-phases, entries oldest first, each run in-process as its agenda command: exit 0 applied, each in a batch of its own with exactly the files its command wrote; a refusal's one line sent verbatim with exit 1, a usage error's with exit 2; a brief id refused unrun with nothing written; an entry another checkout applied first is a 409, its change dropped here and hi2vi's copy pulled, never applied twice; a crash inside a command leaves the entry pending and the tree as it was; a delete clears its links in the same batch; the applier never deadlocks on .hi2vi/lock =="
ib_t0=$(date +%s)
newtmp IBW; IBX="$IBW/xdg"; IBA="$IBW/a"; IBL="$IBW/local"
# ib <host> <args>: one engine command in that host's nested workspace, with the scratch XDG, killed after 60 s
# (a deadlock on .hi2vi/lock would wait the lock's 120 s): exit 124 then.
ib() { _h=$1; shift; ( cd "$_h" && XDG_CONFIG_HOME="$IBX" python3 - "$@" <<'PY'
import subprocess, sys
try:
    sys.exit(subprocess.run([sys.executable, "workflow/scripts/workflow.py"] + sys.argv[1:], timeout=60).returncode)
except subprocess.TimeoutExpired:
    print("TIMEOUT after 60 s")
    sys.exit(124)
PY
) 2>&1; }
ib_install() { { env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid sh "$BOOT" "$1" \
  && git -C "$1/workflow" config user.email smoke@example.invalid && git -C "$1/workflow" config user.name smoke \
  && git -C "$1/workflow" add -A && git -C "$1/workflow" commit -qm install; } > "$1.setup.txt" 2>&1 || bad "inbox probe: the install of $1 failed -- $(tail -3 "$1.setup.txt")"; }
ib_install "$IBA"; ib_install "$IBL"
# A's workspace before the link: a phase and a deferred job, both linked to A1-k2; an Open A2-m3 and A4-n5.
{ ib "$IBA" new-phase --phase P1 --name One --objective toy && ib "$IBA" agenda-add --id A1-k2 --title one \
  && ib "$IBA" agenda-add --id A2-m3 --title two && ib "$IBA" agenda-add --id A4-n5 --title four \
  && ib "$IBA" agenda-link A1-k2 --phase P1 && ib "$IBA" defer-job --title job --reason r --trigger t --source manual --agenda A1-k2 \
  && git -C "$IBA/workflow" add -A && git -C "$IBA/workflow" commit -qm seed; } > "$IBW/seed.txt" 2>&1 || bad "inbox probe: the seed failed -- $(tail -3 "$IBW/seed.txt")"
IBK="inbox-smoke-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
printf '%s\n' "$IBK" > "$IBW/key"; chmod 600 "$IBW/key"
python3 "$REPO_ROOT/tests/fake_hi2vi.py" --dir "$IBW/fake" --port-file "$IBW/port" --key-file "$IBW/key" \
  --project proj-1 --org org-1 --lifetime 900 > "$IBW/fake.txt" 2>&1 &
IB_PID=$!
for _ in $(seq 1 100); do [ -s "$IBW/port" ] && break; sleep 0.1; done
IBS="http://127.0.0.1:$(cat "$IBW/port" 2>/dev/null)"
printf '%s\n' "$IBK" | ( cd "$IBA" && XDG_CONFIG_HOME="$IBX" python3 workflow/scripts/workflow.py link "$IBS/projects/proj-1" ) > "$IBW/link.txt" 2>&1 || bad "inbox probe: the link failed -- $(tail -2 "$IBW/link.txt")"
ib_mark() { if [ -f "$IBW/fake/requests.jsonl" ]; then grep -c '' "$IBW/fake/requests.jsonl"; else echo 0; fi; }
# ib_post <route> <json>: a test-only POST to the fake; prints the answer's id (an inbox entry's) when it has one.
ib_post() { python3 - "$IBS" "$1" "$2" <<'PY'
import http.client, json, sys
from urllib.parse import urlparse
u = urlparse(sys.argv[1])
conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("POST", sys.argv[2], sys.argv[3], {"Content-Type": "application/json"})
resp = conn.getresponse()
assert resp.status == 200, resp.status
print(json.loads(resp.read()).get("id") or "")
PY
}
ib_web() { ib_post /_fake/inbox "$1"; }
# The workflow tree's sha list (.git and .hi2vi aside): what a refusal or an undone crash must leave equal.
ib_tree() { python3 - "$1" <<'PY'
import hashlib, os, sys
root, rows = sys.argv[1], []
for d, dirs, files in os.walk(root):
    dirs[:] = [x for x in dirs if not (d == root and x in (".git", ".hi2vi"))]
    for f in files:
        p = os.path.join(d, f)
        rows.append(f"{os.path.relpath(p, root)} {hashlib.sha256(open(p, 'rb').read()).hexdigest()}")
print("\n".join(sorted(rows)))
PY
}
# ib_check <mark> <check> [args]: one named assertion over the fake's requests since <mark>, its records and
# inbox, and A's base, journal and disk.
ib_check() { python3 - "$IBW/fake/requests.jsonl" "$IBS" "$IBA/workflow" "$@" <<'PY'
import base64, hashlib, http.client, json, sys
from pathlib import Path
from urllib.parse import urlparse, quote
log, server, root, mark, check, extra = sys.argv[1], sys.argv[2], Path(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6:]
R = [json.loads(l) for l in Path(log).read_text().splitlines()[mark:]]
C = [r for r in R if r["path"].endswith("/commit")]
u = urlparse(server)
def get(path):
    conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
    conn.request("GET", path)
    resp = conn.getresponse()
    return resp.status, json.loads(resp.read())
S, I = get("/_fake/state")[1], {e["id"]: e for e in get("/_fake/inbox")[1]["entries"]}
live = {p: f for p, f in S["files"].items() if not f["deleted"]}
hi = root / ".hi2vi"
base = json.loads((hi / "base.json").read_text())
journal = json.loads((hi / "journal.json").read_text()) if (hi / "journal.json").exists() else None
def sha(p):
    return hashlib.sha256((root / p).read_bytes()).hexdigest()
def cloud(p):
    return base64.b64decode(get("/_fake/file?path=" + quote(p))[1]["content"]).decode()
def need(cond, why):
    if not cond:
        print(why)
        sys.exit(1)
def synced():
    need(journal is None, f"the journal is left: {journal}")
    need(base.get("head") == S["head"], f"base head {base.get('head')} != hi2vi head {S['head']}")
    need(set(base["files"]) == set(live), f"base and hi2vi hold different paths: {sorted(set(base['files']) ^ set(live))[:4]}")
    for p, f in live.items():
        need(base["files"][p]["rev"] == f["rev"] and (root / p).is_file() and sha(p) == f["sha256"], f"{p}: base, disk and hi2vi disagree")
def with_result(eid):
    return [c for c in C if any(r["id"] == eid for r in c["batch"]["inbox"])]
if check == "applied":  # extra: the entry ids, oldest first; each applied, alone in its own landed batch with its files
    ids = extra
    batches = [c for c in C if c["batch"]["inbox"]]
    need([c["batch"]["inbox"][0]["id"] for c in batches] == ids, f"batches in the wrong order or count: {[c['batch']['inbox'] for c in batches]}")
    for eid, c in zip(ids, batches):
        need(c["status"] == 200 and len(c["batch"]["inbox"]) == 1, f"{eid}: not alone in a landed batch: {c['status']} {c['batch']['inbox']}")
        need(c["batch"]["inbox"][0] == {"id": eid, "state": "applied", "exit": 0, "reason": None}, f"{eid}: result {c['batch']['inbox'][0]}")
        need(I[eid]["state"] == "applied" and I[eid]["batch_id"] == c["batch"]["batch_id"], f"{eid}: hi2vi holds {I[eid]['state']}")
        paths = sorted(op["path"] for op in c["batch"]["ops"])
        need(paths and all(p.startswith("works/agenda/") or p == "works/events.jsonl" for p in paths), f"{eid}: unrelated files ride its batch: {paths}")
        need(c["batch"]["command"].startswith("agenda-"), f"{eid}: the batch names {c['batch']['command']!r}")
    need(json.loads((root / "works/agenda/A3-x2/agenda.json").read_text())["title"] == "from the web", "A3-x2 is not on disk")
    need(json.loads((root / "works/agenda/A2-m3/agenda.json").read_text())["status"] == "deferred", "A2-m3 is not deferred")
    synced()
elif check == "refused":  # extra: <entry id> <exit> <reason>; the result alone in a batch with no file
    eid, code, reason = extra[0], int(extra[1]), extra[2]
    c = with_result(eid)
    need(len(c) == 1 and c[0]["status"] == 200 and not c[0]["batch"]["ops"], f"{eid}: batches {[(x['status'], x['batch']['ops']) for x in c]}")
    need(c[0]["batch"]["inbox"] == [{"id": eid, "state": "refused", "exit": code, "reason": reason}], f"{eid}: sent {c[0]['batch']['inbox']}")
    need(I[eid]["state"] == "refused" and I[eid]["reason"] == reason and I[eid]["exit"] == code, f"{eid}: hi2vi holds {I[eid]}")
    synced()
elif check == "taken":  # extra: <entry id> <path>: one 409 batch, the disk equal to hi2vi's copy, applied once (by the other)
    eid, path = extra
    c = with_result(eid)
    need(len(c) == 1 and c[0]["status"] == 409, f"{eid}: batches {[x['status'] for x in c]}")
    need(I[eid]["state"] == "applied" and I[eid]["by"] == "checkout other", f"{eid}: hi2vi holds {I[eid]}")
    need((root / path).read_text() == cloud(path), f"{path}: the disk is not hi2vi's copy")
    need("agenda_edited" not in (root / "works/events.jsonl").read_text(), "the dropped edit's event is still on disk")
    synced()
elif check == "pending":  # extra: <entry id>: no result was sent and the entry waits
    eid = extra[0]
    need(not with_result(eid) and I[eid]["state"] == "pending", f"{eid}: sent {len(with_result(eid))}, hi2vi holds {I[eid]['state']}")
    need(not any(c["batch"]["ops"] for c in C), f"a crashed entry's files were sent: {[c['batch']['ops'] for c in C]}")
    synced()
elif check == "delete":  # extra: <entry id>: one batch holds the delete, the cleared links and the result
    eid = extra[0]
    c = with_result(eid)
    need(len(c) == 1 and c[0]["status"] == 200, f"{eid}: batches {[x['status'] for x in c]}")
    ops = {(op["op"], op["path"]) for op in c[0]["batch"]["ops"]}
    jobs = [p for o, p in ops if p.startswith("works/deferred/open/") and p.endswith("/deferred.json")]
    need(("delete", "works/agenda/A1-k2/agenda.json") in ops and ("put", "works/phases/active/P1/phase.json") in ops
         and len(jobs) == 1, f"{eid}: the batch holds {sorted(ops)}")
    for p in ["works/phases/active/P1/phase.json"] + jobs:
        need("agenda" not in json.loads((root / p).read_text()) and "agenda" not in json.loads(cloud(p)), f"{p} keeps its link")
    need(not (root / "works/agenda/A1-k2").exists() and "works/agenda/A1-k2/agenda.json" not in live, "A1-k2 is still there")
    synced()
else:
    need(False, f"unknown check {check}")
print("ok")
PY
}
ib_lockfree() { python3 - "$IBA/workflow/.hi2vi/lock" <<'PY'
import fcntl, os, sys
fd = os.open(sys.argv[1], os.O_RDWR)
try:
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    print("free")
except OSError:
    print("held")
PY
}
# (a) next applies two web changes, oldest first, each alone in its batch, and still prints its pointer.
ib_e1=$(ib_web '{"kind": "add", "minted_id": "A3-x2", "items": ["A3-x2"], "fields": {"title": "from the web"}}')
ib_e2=$(ib_web '{"kind": "defer", "items": ["A2-m3"]}')
ib_m=$(ib_mark); ib "$IBA" next > "$IBW/a.txt"; ib_rc=$?; ib_r=$(ib_check "$ib_m" applied "$ib_e1" "$ib_e2")
[ "$ib_rc" = 0 ] && [ "$ib_r" = ok ] && grep -qx "inbox $ib_e1: applied (agenda-add A3-x2): added A3-x2: from the web" "$IBW/a.txt" \
  && grep -qx "inbox $ib_e2: applied (agenda-defer A2-m3): deferred A2-m3" "$IBW/a.txt" && grep -q '^store=cloud ' "$IBW/a.txt" \
  && [ "$(ib_lockfree)" = free ] \
  && ok "next applies the web's agenda changes oldest first, each alone in a landed batch with exactly its own files, then runs as always (no deadlock on .hi2vi/lock, the lock free after)" \
  || bad "next did not apply the inbox -- rc=$ib_rc $ib_r $(head -3 "$IBW/a.txt")"
# (b) a brief id is refused unrun: exit 2, its line verbatim, nothing written (A1-k2 stays Open).
ib_e3=$(ib_web '{"kind": "solve", "items": ["A1"]}')
ib_t1=$(ib_tree "$IBA/workflow"); ib_m=$(ib_mark); ib "$IBA" sync > "$IBW/b.txt"; ib_rc=$?; ib_t2=$(ib_tree "$IBA/workflow")
ib_line="workflow.py agenda-solve: error: A1 is not a full agenda id (like A7-m3): the inbox applies full ids only, so nothing ran"
ib_r=$(ib_check "$ib_m" refused "$ib_e3" 2 "$ib_line")
[ "$ib_rc" = 0 ] && [ "$ib_r" = ok ] && [ "$ib_t1" = "$ib_t2" ] && grep -qxF "inbox $ib_e3: refused, exit 2 (agenda-solve A1): $ib_line" "$IBW/b.txt" \
  && ok "a brief id in an inbox entry is refused unrun (exit 2, one line, nothing written, the result alone in a batch)" \
  || bad "a brief id was not refused unrun -- rc=$ib_rc $ib_r $(head -3 "$IBW/b.txt") $(diff <(echo "$ib_t1") <(echo "$ib_t2") | head -3)"
# (c) a refusal (exit 1) and a usage error (exit 2) reach the entry verbatim: the same line the engine prints.
ib_e4=$(ib_web '{"kind": "reopen", "items": ["A4-n5"]}')
ib_e5=$(ib_web '{"kind": "defer", "items": []}')
ib_l5=$(cd "$IBL" && python3 workflow/scripts/workflow.py agenda-defer 2>&1); ib_rc5=$?
ib_l4="A4-n5 is Open already"
ib_m=$(ib_mark); ib "$IBA" sync > "$IBW/c.txt"; ib_rc=$?
ib_r=$(ib_check "$ib_m" refused "$ib_e4" 1 "$ib_l4"); ib_r2=$(ib_check "$ib_m" refused "$ib_e5" 2 "$ib_l5")
[ "$ib_rc" = 0 ] && [ "$ib_rc5" = 2 ] && [ "$ib_r" = ok ] && [ "$ib_r2" = ok ] && grep -qxF "inbox $ib_e4: refused, exit 1 (agenda-reopen A4-n5): $ib_l4" "$IBW/c.txt" \
  && ok "a refused agenda command's one line reaches its entry verbatim with exit 1, and a usage error's (as the engine prints it) with exit 2" \
  || bad "a refusal's line did not reach its entry -- rc=$ib_rc/$ib_rc5 $ib_r / $ib_r2 $(head -3 "$IBW/c.txt")"
# (d) another checkout applies an entry first: A's batch is a 409, its change dropped, hi2vi's copy pulled, once.
ib_e6=$(ib_web '{"kind": "edit", "items": ["A3-x2"], "fields": {"title": "renamed"}}')
ib_other=$(python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); d.update(title="renamed", changed_at="2026-11-18T10:00:00+00:00"); print(json.dumps(d, indent=2))' "$IBA/workflow/works/agenda/A3-x2/agenda.json")
ib_post /_fake/control "$(python3 -c 'import json, sys; print(json.dumps({"inbox_race": sys.argv[1], "race": {"path": "works/agenda/A3-x2/agenda.json", "content": sys.argv[2] + "\n"}}))' "$ib_e6" "$ib_other")" > /dev/null
ib_m=$(ib_mark); ib "$IBA" sync > "$IBW/d.txt"; ib_rc=$?; ib_r=$(ib_check "$ib_m" taken "$ib_e6" works/agenda/A3-x2/agenda.json)
ib "$IBA" sync > "$IBW/d2.txt"; ib_rc2=$?
[ "$ib_rc" = 0 ] && [ "$ib_r" = ok ] && grep -qxF "inbox $ib_e6: not applied here (agenda-edit A3-x2): hi2vi holds it applied already (another checkout); this checkout's change was dropped and hi2vi's copy pulled" "$IBW/d.txt" \
  && [ "$ib_rc2" = 0 ] && ! grep -q "^inbox " "$IBW/d2.txt" \
  && ok "an entry another checkout applied first is a 409: this checkout's change is dropped and hi2vi's copy pulled, never applied twice" \
  || bad "an entry taken elsewhere was mishandled -- rc=$ib_rc/$ib_rc2 $ib_r $(head -3 "$IBW/d.txt")"
# (e) a crash inside a command (A1-k2's folder cannot be removed) leaves the entry pending and the tree as it was.
ib_e7=$(ib_web '{"kind": "delete", "items": ["A1-k2"]}')
chmod 555 "$IBA/workflow/works/agenda/A1-k2"
ib_t1=$(ib_tree "$IBA/workflow"); ib_m=$(ib_mark); ib "$IBA" next > "$IBW/e.txt"; ib_rc=$?; ib_t2=$(ib_tree "$IBA/workflow")
chmod 755 "$IBA/workflow/works/agenda/A1-k2"; ib_r=$(ib_check "$ib_m" pending "$ib_e7")
[ "$ib_rc" = 0 ] && [ "$ib_r" = ok ] && [ "$ib_t1" = "$ib_t2" ] \
  && grep -qxF "inbox $ib_e7: left pending (agenda-delete A1-k2): PermissionError inside the command; its changes were undone" "$IBW/e.txt" \
  && ok "a crash inside an agenda command leaves its entry pending (no result sent) and the tree as it was before that entry" \
  || bad "a crashed entry was not undone -- rc=$ib_rc $ib_r $(head -3 "$IBW/e.txt") $(diff <(echo "$ib_t1") <(echo "$ib_t2") | head -4)"
# (f) at run-phases the delete applies: its links cleared in the same batch as the item's removal and its result.
ib_m=$(ib_mark); ib "$IBA" run-phases > "$IBW/f.txt"; ib_rc=$?; ib_r=$(ib_check "$ib_m" delete "$ib_e7")
[ "$ib_rc" = 0 ] && [ "$ib_r" = ok ] && grep -q "^inbox $ib_e7: applied (agenda-delete A1-k2): deleted A1-k2: 2 links cleared" "$IBW/f.txt" \
  && ok "run-phases applies a web delete: the item's removal, its cleared links (a phase and a deferred job) and the result land in one batch" \
  || bad "a web delete did not clear its links in one batch -- rc=$ib_rc $ib_r $(head -3 "$IBW/f.txt")"
if grep -rqF "$IBK" "$IBA" "$IBW"/*.txt "$IBW/fake" 2>/dev/null; then bad "the workspace key leaked into the tree, the output or the request log"; fi
kill "$IB_PID" 2>/dev/null; wait "$IB_PID" 2>/dev/null
echo "inbox test runtime: $(( $(date +%s) - ib_t0 ))s"

echo "== Test 25: a linked checkout's waiting-commit record and update, against the local fake hi2vi -- next and run-phases print commits_waiting= (the done slices finished since the link with no committed_at, in finish order; none for one done before the link); mark-committed records it in slice.json (synced to hi2vi), refuses a slice not done and local mode with nothing written, and leaving done clears it; review-phase records a passing REVIEW itself; local mode prints no line and writes no field; --update on a linked checkout leaves changed works/ files unchanged and uncommitted and prints the update's own paths to stage, never add -A; --to-multi-repo refuses a linked install =="
wc_t0=$(date +%s)
newtmp WCW; WCX="$WCW/xdg"; WCA="$WCW/a"; WCL="$WCW/local"
wc() { _h=$1; shift; ( cd "$_h" && XDG_CONFIG_HOME="$WCX" python3 workflow/scripts/workflow.py "$@" ) 2>&1; }
wc_install() { { env GIT_AUTHOR_NAME=smoke GIT_AUTHOR_EMAIL=smoke@example.invalid GIT_COMMITTER_NAME=smoke GIT_COMMITTER_EMAIL=smoke@example.invalid sh "$BOOT" "$1" \
  && git -C "$1/workflow" config user.email smoke@example.invalid && git -C "$1/workflow" config user.name smoke \
  && git -C "$1/workflow" add -A && git -C "$1/workflow" commit -qm install; } > "$1.setup.txt" 2>&1 || bad "commit-record probe: the install of $1 failed -- $(tail -3 "$1.setup.txt")"; }
# wc_seed <host>: P1 with its DECOMP done (and committed, as every pre-link slice is) and two declared slices open.
wc_seed() { { wc "$1" new-phase --phase P1 --name One --objective toy && wc "$1" start-slice P1.DECOMP \
  && wc "$1" new-slice --phase P1 --slice P1.S1 --name one --depends-on none && wc "$1" new-slice --phase P1 --slice P1.S2 --name two --depends-on none \
  && wc "$1" finish-slice P1.DECOMP --outcome cut && git -C "$1/workflow" add -A && git -C "$1/workflow" commit -qm seed; } > "$1.seed.txt" 2>&1 \
  || bad "commit-record probe: the seed of $1 failed -- $(tail -3 "$1.seed.txt")"; }
wc_install "$WCA"; wc_install "$WCL"; wc_seed "$WCA"; wc_seed "$WCL"
WCK="record-smoke-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
printf '%s\n' "$WCK" > "$WCW/key"; chmod 600 "$WCW/key"
python3 "$REPO_ROOT/tests/fake_hi2vi.py" --dir "$WCW/fake" --port-file "$WCW/port" --key-file "$WCW/key" \
  --project proj-1 --org org-1 --lifetime 900 > "$WCW/fake.txt" 2>&1 &
WC_PID=$!
for _ in $(seq 1 100); do [ -s "$WCW/port" ] && break; sleep 0.1; done
WCS="http://127.0.0.1:$(cat "$WCW/port" 2>/dev/null)"
sleep 1  # a second boundary: the link's stamp falls after the seed's finish
printf '%s\n' "$WCK" | ( cd "$WCA" && XDG_CONFIG_HOME="$WCX" python3 workflow/scripts/workflow.py link "$WCS/projects/proj-1" ) > "$WCW/link.txt" 2>&1 || bad "commit-record probe: the link failed -- $(tail -2 "$WCW/link.txt")"
WCJ="$WCA/workflow/works/phases/active/P1/slices"
wc_has() { python3 -c 'import json, sys; print("yes" if "committed_at" in json.load(open(sys.argv[1])) else "no")' "$WCJ/$1/slice.json"; }
wc_cloud_has() { python3 - "$WCS" "$1" <<'PY'
import base64, http.client, json, sys
from urllib.parse import urlparse, quote
u = urlparse(sys.argv[1]); conn = http.client.HTTPConnection(u.hostname, u.port, timeout=10)
conn.request("GET", "/_fake/file?path=" + quote(sys.argv[2])); resp = conn.getresponse()
print("yes" if resp.status == 200 and "committed_at" in json.loads(base64.b64decode(json.loads(resp.read())["content"])) else "no")
PY
}
wc_tree() { ( cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | while read -r f; do printf '%s %s\n' "$f" "$(sha "$f")"; done ); }
# (a) the done-before-link DECOMP never waits; a slice finished since waits until mark-committed records it.
wc_n0=$(wc "$WCA" next | grep '^commits_waiting=')
wc "$WCA" start-slice P1.S1 >/dev/null; wc "$WCA" finish-slice P1.S1 --outcome one >/dev/null
wc_n1=$(wc "$WCA" next | grep '^commits_waiting='); wc_r1=$(wc "$WCA" run-phases | grep '^commits_waiting='); wc_h1=$(wc_has P1.S1)
wc_t1=$(wc_tree "$WCA/workflow/works"); wc_o2=$(wc "$WCA" mark-committed P1.S1 P1.S2); wc_rc2=$?; wc_t2=$(wc_tree "$WCA/workflow/works")
wc_o3=$(wc "$WCA" mark-committed 1.S1); wc_rc3=$?
wc_n3=$(wc "$WCA" next | grep '^commits_waiting=')
[ "$wc_n0" = "commits_waiting=none" ] && [ "$wc_n1" = "commits_waiting=P1.S1" ] && [ "$wc_r1" = "commits_waiting=P1.S1" ] && [ "$wc_h1" = no ] \
  && [ "$wc_rc2" = 1 ] && printf '%s\n' "$wc_o2" | grep -q "P1.S2 is todo, not done" && [ "$wc_t1" = "$wc_t2" ] \
  && [ "$wc_rc3" = 0 ] && printf '%s\n' "$wc_o3" | grep -q "^P1.S1: committed_at=" && [ "$wc_n3" = "commits_waiting=none" ] \
  && [ "$(wc_has P1.S1)" = yes ] && [ "$(wc_cloud_has works/phases/active/P1/slices/P1.S1/slice.json)" = yes ] \
  && ok "a linked checkout's waiting commit: next and run-phases list a slice finished since the link (not the DECOMP done before it) in commits_waiting=, mark-committed refuses a slice not done with nothing written, then records committed_at (synced to hi2vi) and the line reads none" \
  || bad "the linked waiting-commit record is wrong -- [$wc_n0] [$wc_n1] [$wc_r1] has=$wc_h1 rc=$wc_rc2/$wc_rc3 [$wc_n3] $(printf '%s' "$wc_o2" | head -2)"
# (b) leaving done clears the record (it waits again once done); a second finish keeps it; review-phase records a REVIEW.
wc "$WCA" set-slice-status P1.S1 in_progress >/dev/null; wc_h4=$(wc_has P1.S1); wc "$WCA" finish-slice P1.S1 --outcome again >/dev/null
wc_n4=$(wc "$WCA" next | grep '^commits_waiting='); wc "$WCA" mark-committed P1.S1 >/dev/null; wc "$WCA" finish-slice P1.S1 --outcome third >/dev/null
wc_n5=$(wc "$WCA" next | grep '^commits_waiting=')
{ wc "$WCA" start-slice P1.S2 && wc "$WCA" finish-slice P1.S2 --outcome two && wc "$WCA" mark-committed P1.S2 && wc "$WCA" accept-gate P1 --waive --note toy \
  && wc "$WCA" start-slice P1.REVIEW && wc "$WCA" review-phase P1 --verdict pass; } > "$WCW/review.txt" 2>&1; wc_rc6=$?
wc_n6=$(wc "$WCA" next | grep '^commits_waiting=')
[ "$wc_h4" = no ] && [ "$wc_n4" = "commits_waiting=P1.S1" ] && [ "$wc_n5" = "commits_waiting=none" ] && [ "$wc_rc6" = 0 ] \
  && [ "$wc_n6" = "commits_waiting=none" ] && [ "$(wc_has P1.REVIEW)" = yes ] \
  && ok "leaving done clears committed_at and the slice waits again once done; a second finish-slice keeps it; review-phase --verdict pass records the REVIEW's commit itself" \
  || bad "the record's lifecycle is wrong -- has=$wc_h4 [$wc_n4] [$wc_n5] rc=$wc_rc6 [$wc_n6] $(tail -2 "$WCW/review.txt")"
# (c) local mode: no line, no field; mark-committed is refused with nothing written.
wc "$WCL" start-slice P1.S1 >/dev/null; wc "$WCL" finish-slice P1.S1 --outcome one >/dev/null
wc_ln=$(wc "$WCL" next); wc_lr=$(wc "$WCL" run-phases)
wc_t7=$(wc_tree "$WCL/workflow"); wc_o7=$(wc "$WCL" mark-committed P1.S1); wc_rc7=$?; wc_t8=$(wc_tree "$WCL/workflow")
! printf '%s\n%s\n' "$wc_ln" "$wc_lr" | grep -q 'commits_waiting' && ! grep -rq committed_at "$WCL/workflow/works" \
  && [ "$wc_rc7" = 1 ] && printf '%s\n' "$wc_o7" | grep -q "^mark-committed is for a linked checkout" && [ "$wc_t7" = "$wc_t8" ] \
  && ok "local mode: next and run-phases print no commits_waiting= line, no slice.json gains committed_at, and mark-committed is refused with nothing written" \
  || bad "local mode leaked the linked record -- rc=$wc_rc7 $(printf '%s\n%s\n' "$wc_ln" "$wc_lr" | grep commits_waiting) $(grep -rl committed_at "$WCL/workflow/works" | head -2)"
# (d) --update on the linked checkout: changed works/ files stay as they are, uncommitted, with nothing staged; the report names the
# update's own paths to stage (never add -A), and those take no works/ or docs/ file but the templates and the version marker.
printf 'plan, edited after the last command\n' > "$WCJ/P1.S2/plan.md"; printf 'a topic\n' > "$WCA/workflow/works/phases/active/P1/topics-wc.md"
wc_s9=$(sha "$WCJ/P1.S2/plan.md"); wc_head=$(git -C "$WCA/workflow" rev-parse HEAD)
( cd "$WCA" && XDG_CONFIG_HOME="$WCX" sh "$BOOT" --update . ) > "$WCW/update.txt" 2>&1; wc_rc9=$?
wc_st9=$(git -C "$WCA/workflow" status --porcelain -- works/phases/active/P1)
git -C "$WCA/workflow" diff --cached --quiet; wc_cached=$?
wc_add=$(sed -n "s/^  linked to hi2vi: .*never add -A: //p" "$WCW/update.txt")
( cd "$WCA" && eval "$wc_add" ) > /dev/null 2>&1; wc_rc10=$?
wc_staged=$(git -C "$WCA/workflow" diff --cached --name-only | grep -E '^(works|docs)/' | grep -vE '^works/(templates/|\.workspace-version\.json$)')
git -C "$WCA/workflow" reset -q
[ "$wc_rc9" = 0 ] && [ "$(sha "$WCJ/P1.S2/plan.md")" = "$wc_s9" ] && [ "$(git -C "$WCA/workflow" rev-parse HEAD)" = "$wc_head" ] && [ "$wc_cached" = 0 ] \
  && printf '%s\n' "$wc_st9" | grep -q 'P1.S2/plan.md' && printf '%s\n' "$wc_st9" | grep -q 'topics-wc.md' \
  && [ -n "$wc_add" ] && [ "$wc_rc10" = 0 ] && [ -z "$wc_staged" ] && ! grep -q "add -A && git -C workflow commit" "$WCW/update.txt" \
  && ok "--update on a linked checkout exits 0, leaves changed works/ files unchanged and uncommitted with nothing staged, and its report's staging commands (never add -A) take no works/ or docs/ file but the templates and the version marker" \
  || bad "--update on a linked checkout went wrong -- rc=$wc_rc9/$wc_rc10 cached=$wc_cached staged=[$wc_staged] add=[$wc_add] $(tail -3 "$WCW/update.txt")"
# (e) --to-multi-repo refuses a linked install, naming unlink, with nothing written.
wc_t11=$(wc_tree "$WCA"); XDG_CONFIG_HOME="$WCX" sh "$BOOT" --to-multi-repo "$WCA" --dry-run > "$WCW/convert.txt" 2>&1; wc_rc11=$?; wc_t12=$(wc_tree "$WCA")
[ "$wc_rc11" != 0 ] && grep -q "is linked to hi2vi (cloud mode)" "$WCW/convert.txt" && grep -q "unlink" "$WCW/convert.txt" && [ "$wc_t11" = "$wc_t12" ] \
  && ok "--to-multi-repo refuses a linked install (its workflow repo is no backup), naming unlink, with nothing written" \
  || bad "--to-multi-repo did not refuse a linked install -- rc=$wc_rc11 $(head -4 "$WCW/convert.txt")"
if grep -rqF "$WCK" "$WCA" "$WCL" "$WCW"/*.txt "$WCW/fake" 2>/dev/null; then bad "the workspace key leaked into the tree, the output or the request log"; fi
kill "$WC_PID" 2>/dev/null; wait "$WC_PID" 2>/dev/null
echo "commit-record test runtime: $(( $(date +%s) - wc_t0 ))s"

# ---------------------------------------------------------------------------
echo
if [ "$FAILS" -eq 0 ]; then
  echo "ALL RETROFIT SMOKE TESTS PASSED"
  exit 0
else
  echo "$FAILS CHECK(S) FAILED"
  exit 1
fi
