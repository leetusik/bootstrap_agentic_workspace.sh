#!/usr/bin/env python3
"""The workflow engine: `python3 <this file> <command> ...`. This file is the entry: the parser and the dispatch.

The engine is flat modules beside this file, each importing only the ones listed above it:
- wf_store.py: where the state is (the finder), paths, ids, events, phases, slices, the notebook, next, review,
  the acceptance gate, check and archive;
- wf_git.py: pull requests, the parallel worktrees, the repo registry and phase scope;
- wf_design.py, wf_agenda.py (agenda and deferred jobs), wf_cloud.py: the named parts, each its own file;
- wf_adapter.py: the Claude Code side (executor routes, sync-agents, the dispatch meter, the compaction hook).
wf_store imports none of the others: it calls them through its SEAMS, bound at the end of this file."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Never leave scripts/__pycache__/ beside the engine: a Python with no pycache_prefix writes one there on the first
# import of the modules below (an install's git status, a plugin's folder). Set before they are imported.
sys.dont_write_bytecode = True
_HERE = str(Path(__file__).resolve().parent)
if sys.path[:1] != [_HERE]:
    sys.path.insert(0, _HERE)  # the modules sit beside this file, however it was started (a path, runpy, importlib)

import wf_store  # noqa: E402 -- first: it finds the workspace, or exits 2 with one line
import wf_git  # noqa: E402
import wf_design  # noqa: E402
import wf_agenda  # noqa: E402
import wf_adapter  # noqa: E402
import wf_cloud  # noqa: E402
from wf_store import (  # noqa: E402
    cmd_check, cmd_gate, cmd_next, cmd_parallel_plan, cmd_phase_archive, cmd_set_slice_status, DEPENDS_ON_HELP,
    finish_slice, NESTED, NESTED_MARKER, NESTED_PROBLEMS, new_phase, new_slice, normalize_id_args,
    ONE_LINE_USAGE_COMMANDS, PAGE_BYTES, PHASE_ARG_HELP, phase_section, review_phase,
    REVIEW_VERDICTS, ROOT, rotate_backlog, set_phase_status, set_slice_deps, shown, SLICE_STOP_KINDS, start_slice,
    WORKFLOW_CMD,
)
from wf_git import (  # noqa: E402
    cmd_close, cmd_nested_convention, cmd_nested_repos, cmd_pr_branch, cmd_pr_check, cmd_pr_record, cmd_pr_rules_decide,
    cmd_pr_sync, cmd_pr_team, cmd_reopen_phase, parallel_add_repo, parallel_gate, parallel_merge_finish,
    parallel_start, parallel_status, parallel_teardown, phase_scope, PR_OWNERSHIP_MODES, PR_RULE_CHOICES,
)
from wf_agenda import (  # noqa: E402
    add_agenda_parsers, AGENDA_ID_HELP, cmd_deferred,
)
from wf_design import (  # noqa: E402
    add_design_parsers,
)
from wf_adapter import (  # noqa: E402
    add_adapter_parsers, cmd_compact_resume,
)
from wf_cloud import (  # noqa: E402
    add_cloud_parsers, cloud_link_file, CLOUD_OWN, cloud_refusal, cloud_run, mark_committed,
)


def build_parser() -> argparse.ArgumentParser:
    """Every command's parser. main() parses its argv with it; the agenda inbox applier (cloud mode) parses each
    entry's command with a fresh one, in-process, without main()'s boundary."""
    parser = argparse.ArgumentParser(description="Manage the agentic workflow state.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    def verbs(name: str, help: str):  # a verb's sub-verbs: main() names the command `<verb> <sub-verb>`
        return sub.add_parser(name, help=help).add_subparsers(dest="verb", required=True).add_parser

    p = sub.add_parser("check", help="Rebuild the generated files (works/backlog.md, state.json, index.json, the dashboards, each phase.md's ## Slices block), then validate the workflow state; exit 1 on an invalid record. --no-rebuild validates only (CI, read-only callers)")
    p.add_argument("--no-rebuild", action="store_true", dest="no_rebuild", help="validate only: write nothing")
    p.set_defaults(func=cmd_check)

    add_adapter_parsers(sub)  # sync-agents, executor-route, record-dispatch, dispatch-summary

    p = sub.add_parser("next", help="Print the current phase/slice selection (plus explain_unit=<document|book|chapter> on an explain phase, and on the default stream merge_ready=<P>:<branch> for a parallel phase done with a passing review on its branch but not merged yet); when the phase's notebook is over 40,960 B, also notebook_over_budget= with up to 3 notebook_move= commands to run before the next dispatch (required form), or none when nothing can move (advisory form); for a phase with a pr block, one pr_branch=<repo|host|root>:<branch> base=<base> url=<url|none> per recorded branch, pr_waived=<note> when waived, and pr_draft=due while the phase is at its review (its REVIEW slice in_progress, in_review or pending, the phase in_review, or its acceptance gate open) with a branch unopened: the drafts open when the review would pass. In a linked checkout it first applies the web's pending agenda changes (one inbox <entry>: line each) and prints store=cloud server=<server> project=<id> after the nested lines, then commits_waiting=<ids|none>: the done slices whose commit mark-committed has not recorded, in finish order")
    p.add_argument("--card", action="store_true", help="print the resume card instead: the pointer, the next action or the typed stop, the open gates, the running spans (from the newest session's subagents/*.meta.json) and the slice's file paths, computed from state, at most 2,048 bytes -- what compact-resume prints after a compaction")
    p.set_defaults(func=cmd_next)

    p = sub.add_parser("compact-resume", help="The SessionStart hook (matcher compact): after a compaction, print compaction=done source=compact and the resume card (next --card; the running spans from the hook's transcript_path session), falling back to the plain pointer on any error; never fails, always exits 0")
    p.set_defaults(func=cmd_compact_resume)

    p = sub.add_parser("deferred", help="Rebuild and print deferred jobs dashboard summary")
    p.set_defaults(func=cmd_deferred)

    phase = verbs("phase", "Make, move, archive or read a phase: new, status, archive, rotate, reopen, scope, rounds")
    p = phase("new", help="Create a new phase with DECOMP and REVIEW slices")
    p.add_argument("--phase", help="the phase id; omit it and the engine mints one (P46-k2: the next number and a random tail), printed on the created line. "
                   "Given, any shape (P46-k2, P12 or P-7kq2; 46-k2, 12 and 7kq2 are read as those); refused when it exists active or archived")
    p.add_argument("--name", required=True)
    p.add_argument("--objective", required=True)
    p.add_argument("--order", type=float, help="sort position among phases; a fractional value (e.g. 4.5) inserts between two neighbors without renumbering")
    p.add_argument("--on-main", action="store_true", dest="on_main",
                   help="no-op since v43 (the default stream is the default); accepted so v42 habits and scripts keep working")
    p.add_argument("--agenda", metavar="ITEM", help="link the new phase to this agenda item (" + AGENDA_ID_HELP + "); stored as `agenda` in phase.json; refused, nothing written, when it names no item")
    p.set_defaults(func=new_phase)

    p = phase("status", help="Set any valid phase status")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("status")
    p.set_defaults(func=set_phase_status)

    p = phase("archive", help="Archive one review-passed phase (<P>), or with --all every active phase, only when every one is done (the last review slice complete); --force is for exceptional cleanup of an unfinished phase")
    p.add_argument("phase", nargs="?", default=None, help=PHASE_ARG_HELP + "; omit it with --all")
    p.add_argument("--all", action="store_true", dest="all_phases", help="archive every active phase at once")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=cmd_phase_archive)

    p = phase("rotate", help="The step of /rotate-backlog: the first line is rotate=<refused|archive>. archive: archive every currently-done phase that is cleanly archivable (whole phases, the partial phase archive --all) and rebuild. refused (writes nothing, non-zero exit) on a parallel stream")
    p.add_argument("--archive-only", action="store_true", dest="archive_only",
                   help="archive only: the sweep of every currently-done phase and its report, with no rotate= line (unchanged since v51)")
    p.set_defaults(func=rotate_backlog)

    p = phase("reopen", help="Reopen a DONE phase whose PR is still open, on the operator's word (a change request after the phase was done, the team's or the operator's): status in_progress, review changes_requested with --note, its REVIEW slice changes_requested, a required acceptance gate re-opened (a waived one stays waived); completed_at and the pr block kept. Nested: the phase's own worktree pair, the host worktree ON its existing PR branch (reused, never a second PR), the nested side on phase/P<N>-<slug> (or -reopen<k> when taken), the verdict in the same stamp commit; a multi-repo host's set takes each repo's open PR branch. Root: in place, in the checkout that holds the PR branch (it carries the phase's record), with no worktree and no commit. Refused, nothing written: an archived phase, a phase not done, every PR merged (pr sync first), an empty --note, a parallel stream, a git operation in progress, a PR branch checked out elsewhere (the host's main checkout: switch it off). Prints reopened=<P> branch=<label> worktree=<path>. Never pushes, merges or calls gh. Orchestrator command -- executors never run it")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--note", required=True, help="whose change request it is and what it asks: \"team-reported: <what>\" or \"operator-reported: <what>\" (recorded as the review note; must not be empty)")
    p.add_argument("--slug", default=None, help="nested only: the nested phase branch's slug (default: the phase name's; phase/<phase>-<slug>, with -reopen<k> appended when that branch exists)")
    p.add_argument("--worktree", default=None, help="nested only: the host worktree's path (default: <host>/.claude/worktrees/P<N>-<slug>)")
    p.add_argument("--branch", default=None, help="the open PR branch that takes the fixes, when the phase has several open PRs in one repo (a split) and no single top of the stack")
    p.add_argument("--host-branch", default=None, help="multi-repo host only: the host worktree's branch (it carries no product), when no earlier worktree run of this phase recorded one")
    p.set_defaults(func=cmd_reopen_phase)

    p = phase("scope", help="Read-only: the phase's boundary from git -- creation commit, base..head range, the pathspec= line it read with (works/ and docs/ excluded at root, the nested workflow folder in a nested install; one per repo and the host's on a multi-repo host; paste-ready after -- in a git command run from the folder it was read in) and the product files it changed; advisory, exit 0 without git. --pathspec prints only the pathspec line(s), with no phase needed")
    p.add_argument("phase", nargs="?", default=None, help=PHASE_ARG_HELP + "; omit it only with --pathspec")
    p.add_argument("--pathspec", action="store_true", help="print only the product pathspec line(s) (the JSON with --json), the same value phase scope <P> reads with; needs no phase (/read-code, outside a phase)")
    p.add_argument("--base", default=None, help="use this ref as the range base verbatim (skips creation-commit / merge-base detection)")
    p.add_argument("--head", default=None, help="use this ref as the range head (default: HEAD, or the commit that recorded a passing review on a done phase)")
    p.add_argument("--json", action="store_true", help="print the same answer as one JSON object")
    p.add_argument("--repo", action="append", default=None, metavar="NAME", help="multi-repo host only: measure only this registered repo (repeatable); with exactly one --repo, --base/--head set that repo's range instead of the host's")
    p.set_defaults(func=phase_scope)

    p = phase("rounds", help="Print the rounds a phase's open slices run in, as the engine determines them from the declarations (v77), and any middle slice still undeclared, as advice; read-only")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.set_defaults(func=cmd_parallel_plan)

    slice_ = verbs("slice", "Make or move a slice: new, start, finish, status (a pending stop is typed), deps")
    p = slice_("new", help="Create a new slice folder with slice.json")
    p.add_argument("--phase", required=True, help=PHASE_ARG_HELP)
    p.add_argument("--slice", required=True, help="the slice id (P46-k2.S1, or 46.S1 while one phase is numbered 46), or its bare suffix (S1)")
    p.add_argument("--name", required=True)
    p.add_argument("--kind", default="implementation", help="one of implementation, review, decomposition, research, fix, docs, qa, co-work; another kind is made with one advice: line and routes on the high row. research is findings-only: no product code, findings land in phase.md, and it always routes to the research row")
    p.add_argument("--risk", default="high", help="low (the mid row for implementation, fix, docs and qa -- the default since v46, real code included) or high (the high row: only for a named trigger -- open design, a core invariant, an unlocated root cause, a wide blast radius -- or a fix to mid-row work); unset or unrecognized values route to high; kind decomposition, review, co-work and research route by kind whatever this says; `executor-route <slice>` prints the decision")
    p.add_argument("--order", type=float, help="sort position within the phase; a fractional value (e.g. 4.5) inserts between two neighbors without renumbering (default: 10 past the last non-review slice)")
    p.add_argument("--depends-on", action="append", metavar="ID|none", help=DEPENDS_ON_HELP)
    p.set_defaults(func=new_slice)

    p = slice_("start", help="Mark a slice in_progress")
    p.add_argument("slice")
    p.set_defaults(func=start_slice)

    p = slice_("finish", help="Mark a slice done; a decomposition that leaves an undeclared middle slice prints advice: lines naming it")
    p.add_argument("slice")
    p.add_argument("--outcome", help="one line recorded in slice.json and rendered in the phase's generated ## Slices table")
    p.set_defaults(func=finish_slice)

    p = slice_("status", help="Set any valid slice status; a pending stop needs --stop-kind and --on-words (stored in slice.json as pending: {kind, on_words, since}, printed by next and the resume card, cleared when the slice leaves pending) and is refused without them")
    p.add_argument("slice")
    p.add_argument("status")
    p.add_argument("--stop-kind", dest="stop_kind", choices=SLICE_STOP_KINDS,
                   help="pending only: what kind of stop this is -- " + "; ".join(f"{k} = {v}" for k, v in SLICE_STOP_KINDS.items()))
    p.add_argument("--on-words", dest="on_words", help="pending only: what the operator's words on return will do (one line)")
    p.set_defaults(func=cmd_set_slice_status)

    p = slice_("deps", help="Declare an existing slice's dependencies (v77), under slice new --depends-on's rules; a decomposition that leaves a middle slice undeclared is told so at its finish")
    p.add_argument("slice")
    p.add_argument("--depends-on", action="append", required=True, metavar="ID|none", help=DEPENDS_ON_HELP)
    p.set_defaults(func=set_slice_deps)

    p = sub.add_parser("mark-committed", help="A linked checkout only (refused in local mode, nothing written): record that each named done slice's commit is in, as committed_at in its slice.json -- run it after the slice's product commit(s), or right after its finish when it changed no product file (review records a passing REVIEW itself). next lists the done slices without it in commits_waiting=, the record git's uncommitted slice.json gives in local mode. Leaving done clears it. All or nothing: a slice not done refuses the call")
    p.add_argument("mark_slices", nargs="+", metavar="slice")
    p.set_defaults(func=mark_committed)

    p = sub.add_parser("review", help="Record a phase review verdict (pass/changes_requested/blocked). A pass is refused while the acceptance gate is required and not cleared, or undeclared; a pass with a recorded PR branch unopened, or no branch while phase scope lists product files, prints advice: pr_draft=due (unless the PR is waived)")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--verdict", required=True, choices=sorted(REVIEW_VERDICTS))
    p.add_argument("--reviewer", default=None)
    p.add_argument("--note", default=None)
    p.set_defaults(func=review_phase)

    p = sub.add_parser("gate", help="The operator acceptance gate: declare it (require, or waive --note), open it at the review (open --walkthrough), clear it with the operator's literal words (clear --words), or show it (bare). Orchestrator/operator command -- executors never run it")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("action", nargs="?", choices=("require", "waive", "open", "clear"), help="require: review --verdict pass refuses until the gate is opened and cleared; waive: not operator-visible (--note says why); open: record --walkthrough and set the phase pending; clear: stamp cleared_at and the operator's --words, the phase back to in_progress")
    p.add_argument("--walkthrough", default=None, help="with open: the concrete script the operator runs (URLs to open, actions to try, in the operator runtime)")
    p.add_argument("--words", default=None, help="with clear, required: the operator's literal words of acceptance, recorded in phase.json (a sign-off is their words)")
    p.add_argument("--note", default=None, help="mandatory with waive (why); optional with clear (what the operator reported)")
    p.set_defaults(func=cmd_gate)

    p = sub.add_parser("close", help="Walk an accepted phase's close in its fixed order -- gate, reread, pass, ready, ci, land, sync, merge, teardown, check, commit: one step=<name> state=done|due|skipped|stop line each, then stop=<name> do=<what> or close=done. Reads its PRs read-only (gh pr view, gh pr checks) and records what it read; runs the engine's own steps (the pass, merge-finish, teardown, check); never pushes, merges, flips a PR Ready or writes to GitHub. Re-run it after each stop. Refused, nothing written: a required gate not cleared with the operator's words, or a waived or legacy gate's phase with no pass")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--dry-run", action="store_true", dest="dry_run", help="read and print the steps; write nothing and run no engine step")
    p.set_defaults(func=cmd_close)

    worktree = verbs("worktree", "Run a phase in its own worktree set: start, add-repo, status, gate, merge-finish, teardown")
    p = worktree("start", help="Ask for a worktree: move a planned phase out of the default stream into its own -- stamp it, commit the stamp (phase folder + works/ files only; a dirty tree is fine), cut phase/P<N>-<slug> and .claude/worktrees/P<N>-<slug>")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--worktree", default=None, help="worktree path (default: <repo>/.claude/worktrees/P<N>-<slug>, which EnterWorktree can enter in the same session; elsewhere means opening a second session there)")
    p.add_argument("--slug", default=None, help="branch slug override (default: slugified phase name); branch is phase/<phase>-<slug>")
    p.add_argument("--host-branch", default=None, help="nested install only, and required there except for an explain phase (## Explain in intent.md), whose host worktree is then cut detached at the host base with no host branch (v86: an explain makes no host commit; --repo still needs it): the host repo's branch for this phase's product commits, named by the host's convention (no workspace IDs); reused when it exists and no host worktree has it checked out. In nested the pair is <host>/.claude/worktrees/P<N>-<slug> on this branch, with the nested worktree inside it (--worktree overrides the host worktree's path)")
    p.add_argument("--host-base", default=None, help="nested install only: the host ref the host branch starts from (default: origin/HEAD, else init.defaultBranch if it exists locally, else main, then master; never fetched)")
    p.add_argument("--repo", action="append", default=None, metavar="NAME=BRANCH", help="multi-repo host only, repeatable: also cut a worktree for registered repo NAME at <host worktree>/<its path> on BRANCH (required, named by that repo's convention: repo convention --repo NAME); reused when it exists and is checked out nowhere. A registered repo not named here is not in this set: inside it, phase scope skips it")
    p.add_argument("--repo-base", action="append", default=None, dest="repo_base", metavar="NAME=REF", help="multi-repo host only, repeatable: the ref repo NAME's branch starts from (default: its registry default_branch as a local branch; never fetched); NAME must also be given with --repo")
    p.set_defaults(func=parallel_start)

    p = worktree("add-repo", help="Multi-repo host only, run INSIDE a phase's worktree set: add one registered repo mid-phase -- cut its worktree at <host worktree>/<its path> on BRANCH, or with --adopt stamp the worktree of it already there -- and commit the stamp on the phase branch")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--repo", required=True, metavar="NAME=BRANCH", help="the registered repo (in this set's registry) and its branch, named by that repo's convention (repo convention --repo NAME); without --adopt, reused when it exists and is checked out nowhere")
    p.add_argument("--repo-base", default=None, dest="repo_base", metavar="REF", help="the ref the branch starts from (default: the registry default_branch as a local branch; never fetched); with --adopt, what its anchor is the merge-base with")
    p.add_argument("--adopt", action="store_true", help="stamp the existing worktree of NAME at <host worktree>/<its path> (registered in that repo, HEAD on BRANCH) instead of cutting one; its branch stays the operator's (branch_created=false), so teardown keeps it")
    p.set_defaults(func=parallel_add_repo)

    p = worktree("status", help="Read-only cross-stream view: this checkout's pointer plus every parallel phase's branch-side slice state (never writes anything)")
    p.set_defaults(func=parallel_status)

    p = worktree("gate", help="Advice, read-only: is this parallel phase's branch mergeable now (branch done+pass, default stream quiet -- or, v86, exemption=phase-folder-only: its diff since the merge-base touches only its phase folder, the generated works/ files and added works/deferred/open/ and works/agenda/ paths)? Prints GATE OPEN, or GATE CLOSED reason=<reasons>; exits 0 either way")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--branch-ref", default=None, help="git ref holding the phase branch's state (default: the phase's stamped execution.branch; e.g. HEAD or origin/phase/P2-x in CI)")
    p.add_argument("--main-ref", default=None, help="git ref holding the default stream's state (default: this working tree; e.g. origin/main when running from a PR checkout)")
    p.set_defaults(func=parallel_gate)

    p = worktree("merge-finish", help="Run on the default stream right after merging a phase branch: regenerate the generated files and name each merged phase whose branch and worktree are left to tear down")
    p.set_defaults(func=parallel_merge_finish)

    p = worktree("teardown", help="Retire a merged parallel phase's worktree set and branch, and clear its execution block; run from the default stream")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--discard-ignored", action="store_true", help="nested install only: delete the ignored, worktree-only files the paired teardown lists (it refuses without this flag)")
    p.set_defaults(func=parallel_teardown)

    repo = sub.add_parser("repo", help="Nested personal install only: the multi-repo host's registry of product repos and their commit customs -- list (bare), add, remove, rules, detect-rules, map-anchors, convention; writes only .agentic-nested.json; refuses outside a nested install")
    repo.set_defaults(func=cmd_nested_repos, verb="list", add=None, remove=None, rules=None, detect_rules=None, map_anchors=None)
    repo = repo.add_subparsers(dest="verb").add_parser
    repo("list", help="Show the registry: name, path, the branch checked out now, default branch, convention state, rules count")
    p = repo("add", help="Register the git repo whose work tree root is PATH (relative to the host root), under the host; its rules files are detected and its convention inherits the host's; on a single-repo install only when the host tracks no files")
    p.add_argument("add", metavar="PATH")
    p.add_argument("--name", default=None, help="the repo's name in the registry (default: the path's last segment; [A-Za-z0-9._-]+)")
    p.add_argument("--default-branch", default=None, dest="default_branch", help="the repo's integration branch (default: its origin/HEAD target, else none)")
    repo("remove", help="Drop a repo from the registry (its files are untouched); refused while an active phase holds repo_anchors.NAME").add_argument("remove", metavar="NAME")
    p = repo("rules", help="Set a repo's rules files by hand")
    p.add_argument("rules", metavar="NAME")
    p.add_argument("--set", required=True, metavar="A,B,C", help="the comma-separated repo-relative paths of the repo's own rules files (empty clears them)")
    repo("detect-rules", help="Re-detect a repo's rules files: every tracked AGENTS.md / CLAUDE.md, plus .agents/skills/*/SKILL.md").add_argument("detect_rules", metavar="NAME")
    repo("map-anchors", help="Converted install: move every phase's host_anchors (shas that are commits of repo NAME) to repo_anchors.NAME, and every null pr.branches[].repo to NAME when the marker's converted_from names it, active and archived phases alike; skips phases in flight on their own branch; a re-run maps nothing; writes phase.json files only").add_argument("map_anchors", metavar="NAME")
    p = repo("convention", help="Show the host repo's conventions for commits, branches and pull requests (bare), or record the operator's confirmation of them -- the text and whether Claude Co-Authored-By trailers are allowed in host commits (--confirm --text ... --trailers allowed|forbidden); refuses outside a nested install")
    p.add_argument("--confirm", action="store_true", help="record the operator-confirmed conventions (needs --text and --trailers)")
    p.add_argument("--text", default=None, help="the host's conventions as the operator confirmed them: commit subjects and trailers; branch naming and base (e.g. from fresh main); PR shape (one per ticket or per phase) and who merges")
    p.add_argument("--trailers", default=None, choices=("allowed", "forbidden"), help="may Claude Co-Authored-By trailers appear in host product commits")
    p.add_argument("--repo", default=None, metavar="NAME", help="multi-repo host only: show one registered repo's effective conventions (the host-level ones, the rules for every repo, composed with its own), or with --confirm record its own; without --repo, --confirm records the host-level ones")
    p.add_argument("--inherit", action="store_true", help="with --repo: set that repo's own conventions back to null, so it inherits the host-level ones")
    p.set_defaults(func=cmd_nested_convention)


    pr = verbs("pr", "Branch, record and track a phase's pull requests: branch, record, sync, team, check, rules")
    p = pr("branch", help="Cut or record the phase's PR branch in one repo's checkout (the host for a single-repo host or a root install; the registered repo's for a multi-repo host) and record it in phase.json's pr block (added to a phase from before P51): the branch already checked out there is only recorded; --base on an already-recorded branch re-records its base with no switch, checked out or not (a stacked PR retargeted after its lower PR merged); an unrecorded existing branch that is not checked out is refused (git switch to it, then re-run); otherwise git switch --no-track -c <branch> <base>, refused while tracked changes would ride along. Prints pr_branch=<repo|host|root>:<branch> base=<base>. Never pushes. Orchestrator command -- executors never run it")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--repo", default=None, metavar="NAME", help="multi-repo host only, and required there: the registered repo whose checkout holds the branch")
    p.add_argument("--name", required=True, help="the branch, named by the host's convention for branches (repo convention), with no workspace IDs; never the base or default branch itself")
    p.add_argument("--base", default=None, help="the PR's base branch: recorded as the branch NAME gh pr create --base takes (a remote-tracking ref such as origin/main records main; a sha or a tag is refused); default: the repo's default branch -- the registry's default_branch, else origin/HEAD's target, else main. The branch is cut from it, and pr check diffs against origin/<base> when that exists, else the local <base> (diff_base=); never fetched")
    p.set_defaults(func=cmd_pr_branch)

    p = pr("record", help="Record the draft PR opened when the review passed (pr skill: Open the drafts) on a recorded PR branch (--url: sets url and opened_at, and reads the draft's state -- head, updated_at, the comment count -- with gh pr view, read-only; re-run on the same URL after a fix round's push re-records it), or waive the phase's PR (--waive --note: a phase with no product change worth a PR); refuses an unrecorded branch. review --verdict pass prints advice: pr_draft=due until one of the two. Orchestrator command -- executors never run it")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--repo", default=None, metavar="NAME", help="multi-repo host only: the registered repo of the branch")
    p.add_argument("--branch", default=None, help="the recorded branch (may be omitted when exactly one recorded branch matches)")
    p.add_argument("--url", default=None, help="the draft PR's http(s) URL, as gh pr create printed it")
    p.add_argument("--waive", action="store_true", help="waive the phase's PR as a whole instead; needs --note")
    p.add_argument("--note", default=None, help="mandatory with --waive: why this phase needs no PR")
    p.set_defaults(func=cmd_pr_record)

    p = pr("sync", help="Read each recorded draft PR's lifecycle from GitHub and record it on its branch entry -- the engine's only network read besides pr team, read-only: gh pr view <url> --json state,isDraft,mergedAt,baseRefName,headRefOid,reviewDecision,updatedAt,comments. Records state (draft|ready|merged|closed), synced_at, merged_at, and ready_at the first time it reads ready or merged (never cleared). Prints pr_sync=<label> state=<s> base=<b> head=<sha7> review=<decision|none> merged_at=<ts|none> per URL, then unchanged_since_draft=yes|no|unknown pr=<label> against the state pr record --url read (pr_sync=<label> state=unopened for a branch with no URL), plus an advisory pr_sync_base= line when GitHub's base differs from the record (never re-recorded here). All or nothing: gh missing, unauthenticated, offline or answering oddly writes nothing and exits non-zero naming the fix. Only state=merged takes the PR out of next's pr_open= lines. Orchestrator command -- executors never run it")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("--repo", default=None, metavar="NAME", help="multi-repo host only: read only this registered repo's PR(s)")
    p.add_argument("--branch", default=None, help="read only this recorded branch's PR")
    p.set_defaults(func=cmd_pr_sync)

    p = pr("team", help="Bare, read-only: detect whether a repo's PRs are a solo owner's or a team's -- the collaborators API where it answers (gh api, a GET needing write access; a refusal or no gh reads unavailable) and the distinct non-bot commit authors on the default branch; prints pr_team=<label> recorded=<solo|team|none> detected=<solo|team|unknown> evidence=\"<collaborators: N (logins)|unavailable>; authors: M\" (team when either shows more than one person). --record solo|team --evidence \"...\": record it (after the operator's word) in the PR rules record's ownership list -- the nested marker's pr_rules key, or at root works/pr-rules.json -- replacing that repo's earlier record. --record is an orchestrator command -- executors never run it")
    p.add_argument("--repo", default=None, metavar="NAME", help="multi-repo host only, and required there: the registered repo")
    p.add_argument("--record", default=None, choices=PR_OWNERSHIP_MODES, help="record the repo as solo (the close merges) or team (the close waits on the team's merge)")
    p.add_argument("--evidence", default=None, help="mandatory with --record: what showed it (the detection's evidence, the operator's word)")
    p.set_defaults(func=cmd_pr_team)

    p = pr("check", help="Read-only: measure each recorded PR branch and its body, one key=value per line -- diff_base= (origin/<base> when that remote-tracking ref exists, else the local <base>), size= (git diff --numstat <diff_base>...<branch> minus linguist-generated paths, lockfiles and whole-file deletions; binary rows excluded and counted), size_status=info (no default limit: the count is information) or, with a team's --limit <n>, size_status=ok|over plus size_over= (a warning), body= and the budgets first_screen=/1500, visible=/3500, whole=/6000 (topics/pr-body[-<repo>].md, or --body), leak= (phase or slice IDs, workflow/ paths, workspace file names: a fail) and leak_warn= (orchestrator, executor, phase notebook, slice), headings= against the repo's PR template's H2s in order, else Summary, Review, What is changed, Why, Related issue (template=), pr_rules=<n> decided, and pr_check=pass|warn|fail: a missing body is never a pass (body=missing is a warning; a missing --body file a fail). Exit 1 on a fail, else 0. With no recorded branch, measures the checked-out branch against the default base. By hand, outside a phase: pr check --body <file> [--base <branch>] [--branch <b>] measures the checked-out branch (or --branch) against --base, else the default branch, and checks that body. On a multi-repo host each line starts repo=<name>")
    p.add_argument("phase", nargs="?", default=None, help=PHASE_ARG_HELP + "; omit it only with --body, for the by-hand route outside a phase")
    p.add_argument("--repo", default=None, metavar="NAME", help="multi-repo host only: check only this registered repo's branch(es); without it every recorded branch is checked in turn (by hand: the repo whose branch is measured, required there)")
    p.add_argument("--branch", default=None, help="check only this recorded branch (a stack records several per repo); by hand, the branch to measure instead of the checked-out one")
    p.add_argument("--body", default=None, help="check this body file instead of the phase's topics/pr-body[-<repo>].md; a missing --body file is a fail, a missing default body is a warning (body=missing): a missing body is never a pass")
    p.add_argument("--base", default=None, help="by hand only (no phase): the branch to measure against, as its name (origin/main reads as main; a sha or a tag is refused); default: the repo's default branch, resolved as pr branch does")
    p.add_argument("--limit", default=None, metavar="N", help="the team's own PR size limit in changed lines, when their rules state one (read live by the pr skill); either route. Over it: size_status=over, a size_over= line and a warning, answered by a split or a named exception in ## Review. Without it there is no limit: size_status=info. A positive whole number; 0 or a non-integer is refused")
    p.set_defaults(func=cmd_pr_check)

    p = pr("rules", help="Show (bare) or record (--rule --choice) one team PR rule conflict the operator decided -- whether the team's rule or ours applies -- in the nested marker's pr_rules key, or at root in works/pr-rules.json; a decision on the same rule (and repo) replaces the earlier one. The team's rules themselves are read live by the pr skill, never recorded. Orchestrator (update-workspace) command -- executors never run it")
    p.add_argument("--rule", default=None, help="what the team rule says, in one line (e.g. \"PR template headings: Summary, What is changed, Why, Related issue\")")
    p.add_argument("--choice", default=None, choices=PR_RULE_CHOICES, help="team: the team's rule wins; ours: the workspace's rule applies")
    p.add_argument("--note", default=None, help="optional: the operator's reason")
    p.add_argument("--repo", default=None, metavar="NAME", help="multi-repo host only: the decision concerns this registered repo's rule (default: every repo)")
    p.set_defaults(func=cmd_pr_rules_decide)

    p = sub.add_parser("section", help="Read or write ONE `## ` section of a phase's phase.md, or one entry of it: no name = the index (a line per heading with its bytes; with its budget and over/long flags, then the move commands, when a section is over its budget or holds long entries), a name prints that section (paged: --page N), --list its entries, --entry K one entry; --replace / --append write one section (stdin or --file; a heading the notebook lacks is created before ## Now), --entry K --replace / --remove write one entry, --resolve OQ<n> --pointer <ref> collapses an Operator Questions entry, --to-topic <slug> moves entries verbatim to topics/<slug>.md behind one gist line each, --topic <slug> reads that file; every other byte of the notebook stays identical",
                       description="phase.md is an index: read one section or one entry, write one section or one entry, never the whole file. Put the section name BEFORE the flags: section P1 Now --replace --file now.md. Names match case-insensitively (Now, Decisions, 'Operator Questions', 'Notes for later slices', Objective, Slices, or any heading); a write to a heading the notebook lacks creates it at the end, before ## Now. Slices is generated and refused. Operator Questions and an older notebook's Doc impact are append-only by custom, and Decisions keeps every decision: a --replace or --remove there is written with one advice: line (--resolve collapses an answered question). "
                                   "Entries are a section's column-0 list items (- , * , + , 1. , 1) ) with their continuation and nested lines: --list numbers them (position, own label, bytes, flags long/nested/pointer, lead), and --entry K names one by position, OQ<n> or a unique case-insensitive piece of its first line. --entry K --replace swaps that entry alone (text without a marker keeps the old one); --entry K --remove deletes a consumed one. "
                                   "--to-topic <slug> [--entry K] [--gist TEXT] [--dry-run] moves the section's entries (or K's, where ranges and lists like 1-8,10 work) to topics/<slug>.md: each is appended there as a `## <Section> <label>` block byte for byte and verified, then replaced in phase.md by one pointer line, `<marker><gist> → [topics/<slug>.md](topics/<slug>.md) § <block>`, its gist a verbatim excerpt of at most 160 characters; Decisions, Notes for later slices, Objective and custom sections only, never the slug breakdown, and a gist under 24 characters of plain text (a bare link) is refused. --topic <slug> [<block>] reads a topic: its index of blocks with bytes, or one block. "
                                   "Budgets: the index prints each section's bytes; when one is over its budget (Decisions 12 KB, Operator Questions 8 KB, Notes for later slices 6 KB, Now 2 KB, Objective 2 KB, any other 6 KB; none for Slices and Doc impact, which still count to the 40 KB total) or holds long entries (over 512 B or nested, named in movable sections only), every line shows bytes, budget, flags (over, long:N) and the heading last, then the total, then one `move: section <P> \"<Section>\" --to-topic <slug> --entry <ranges>` per section. "
                                   "Paging: a section or topic block over 24 KB prints page 1 of it; --page N prints page N. Pages break only between entries (an entry bigger than a page gets its own page) and open with `<!-- page i of n · <Section> · entries a–b of m · next: ... --page i+1 -->` (`last page` on the last); drop those header lines, concatenate the pages, and you have the section byte for byte.")
    p.add_argument("phase", help=PHASE_ARG_HELP)
    p.add_argument("name", nargs="*", help="section heading (quote it when it has spaces); omit for the index")
    p.add_argument("--replace", action="store_true", help="replace the section's body (the heading and the rest of the file are kept byte-identical); a heading the notebook lacks is created")
    p.add_argument("--append", action="store_true", help="add text at the end of the section; a heading the notebook lacks is created")
    p.add_argument("--resolve", metavar="OQ<n>", help="collapse that Operator Questions entry to one line")
    p.add_argument("--pointer", help="with --resolve: where the answer landed (a Decisions line, a deferred job, a slice)")
    p.add_argument("--file", help="read the new text from this file (default: stdin)")
    p.add_argument("--list", action="store_true", help="with a section name: one line per entry (position, own label, bytes, flags long/nested/pointer, its lead cut at 80 characters)")
    p.add_argument("--entry", metavar="K", help="one entry of the section: its position (1-based), OQ<n>, or a unique case-insensitive piece of its first line; alone it prints that entry, with --replace / --remove it writes only it, with --to-topic it may also be ranges and lists (1-8,10)")
    p.add_argument("--remove", action="store_true", help="with --entry K: delete that entry and its trailing blank lines (in Decisions, Operator Questions and an older notebook's Doc impact with one advice: line; never in Slices)")
    p.add_argument("--to-topic", metavar="SLUG", dest="to_topic", help="move the section's entries (or --entry K's) verbatim to topics/SLUG.md, verify them there, then leave one pointer line each carrying a verbatim gist; Decisions, Notes for later slices, Objective and custom sections; the slug breakdown is refused")
    p.add_argument("--gist", help="with --to-topic and exactly one entry: the pointer line's gist (default: derived, a verbatim excerpt of at most 160 characters)")
    p.add_argument("--dry-run", action="store_true", dest="dry_run", help="with --to-topic: print the pointer lines and the bytes saved, and write nothing")
    p.add_argument("--topic", metavar="SLUG", help="read topics/SLUG.md beside phase.md instead: no name prints its index (its ## blocks with bytes), a name prints that block (paged like a section)")
    p.add_argument("--page", type=int, metavar="N", help=f"with a section or topic block name: print page N of it ({PAGE_BYTES // 1024} KB pages that break only between entries, each opening with a `<!-- page i of n ... -->` header); a plain read over {PAGE_BYTES // 1024} KB prints page 1; refused with any write flag, --list or --entry")
    p.set_defaults(func=phase_section)

    add_design_parsers(sub)  # design-init ... design-migrate

    add_agenda_parsers(sub)  # defer-job, promote-deferred, drop-deferred, agenda, agenda-*

    add_cloud_parsers(sub)  # link, unlink, sync
    return parser


def main(argv=None) -> int:
    parser = build_parser()
    tokens = sys.argv[1:] if argv is None else list(argv)
    one_line_cmd = tokens[0] if tokens and tokens[0] in ONE_LINE_USAGE_COMMANDS else None
    if one_line_cmd:  # leftovers (an unknown option, an extra positional) are the top parser's error: one line too
        parser.error = lambda message: parser.exit(2, f"{parser.prog} {one_line_cmd}: error: {message}\n")
    args = parser.parse_args(argv)
    if getattr(args, "verb", None):  # `phase new`, `slice status`: the name every check below reads
        args.cmd = f"{args.cmd} {args.verb}"
    if NESTED is not None and NESTED_PROBLEMS and args.cmd not in ("check", "compact-resume"):  # the hook fails open
        # Never fall back to at-root mode on a broken marker: refuse, and let check list it all.
        raise SystemExit(f"{shown(ROOT / NESTED_MARKER)} is malformed, so this nested install cannot run {args.cmd}: "
                         f"{'; '.join(NESTED_PROBLEMS)} -- fix the file (run: {WORKFLOW_CMD} check --no-rebuild)")
    if not cloud_link_file().exists() or args.cmd in CLOUD_OWN:
        # local mode: no link, so the command runs exactly as before; link, unlink and sync each take the lock
        # themselves and never run the begin step. Every typed phase / deferred-id / slice argument becomes its
        # stored id here, once.
        normalize_id_args(args)
        result = args.func(args)
    else:  # cloud mode: a pull before the command, its batches after it; a stream command is refused first
        refused = cloud_refusal(args)
        if refused:
            raise SystemExit(refused)
        result = cloud_run(args, tokens)  # the ids are resolved inside, against the pulled tree
    if isinstance(result, tuple):
        return 0
    return 0 if result is None else int(result or 0)



# The seams: each module's SEAMS names what it calls in a module above it; bound here, once every module and the
# parser exist, before any command runs.
for _module in (wf_store, wf_git, wf_design, wf_agenda, wf_adapter, wf_cloud):
    for _owner, _names in getattr(_module, "SEAMS", {}).items():
        for _name in _names:
            setattr(_module, _name, globals()[_name] if _owner == "workflow" else getattr(sys.modules[_owner], _name))

if __name__ == "__main__":
    raise SystemExit(main())
