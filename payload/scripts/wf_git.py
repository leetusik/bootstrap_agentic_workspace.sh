"""Git-facing commands: pull requests (pr-*), the parallel worktrees (parallel-*, phase reopen), the nested repo
registry and conventions (nested-*), and phase scope. Imports only wf_store."""
from __future__ import annotations

import argparse
import json
import os
import posixpath
import re
import shlex
import shutil
import subprocess
from pathlib import Path
from urllib.parse import urlparse

from wf_store import (  # noqa: E402
    _branch_exists, _drive_review_slices, _ensure_worktrees_excluded, _git, _git_available,
    _git_operation_in_progress, _git_work_tree_root, _main_host_checkout, _one_line, _parallel_branch_merged,
    _parse_worktree_list, _phase_json_at_ref, _phases_at_ref, _repo_path_problem, _repo_prefix, _require_git_repo,
    _rev_parse, _slices_at_ref, _with_host_anchors, _with_repo_anchors, _worktree_entries, acceptance_gate_is_open,
    ACTIVE, all_active_phases, append_event, ARCHIVED, archived_phase_ids, BUSY_PHASE_STATUSES, current_stream,
    explain_phase, explain_unit, GATE_EXEMPT_ADDED_PREFIXES, GENERATED_FILES, git_current_branch, HOST_ANCHOR_KEYS,
    HOST_ROOT, MAIN_HOST, NESTED, NESTED_HOST_BRANCH_ARG, NESTED_HOST_BRANCH_REQUIRED, NESTED_MARKER,
    nested_marker_problems, NESTED_REPO_NAME, nested_repo_path, nested_repos, NESTED_SET_NEEDS_HOST_BRANCH,
    now_iso, operator_wait_target, phase_acceptance, phase_dirs, phase_execution, phase_pinned, read_json,
    rebuild_index_and_state, REPO_ANCHOR_KEYS, require_phase, resolve_current, ROOT, shown, slugify,
    STAMP_WORKS_FILES, status_box, stream_phases, WORKFLOW_CMD, WORKS, WORKTREES_DIR, write_json,
)


def _phase_branch(phase_id: str, name: str, slug_override=None) -> str:
    """`phase/P<N>-<slug>` -- the stream key every other part of parallel mode reads."""
    slug = slugify(slug_override or name, fallback=phase_id.lower())
    if len(slug) > 40:  # branch names stay short enough to type and to read in `git branch`
        slug = slug[:40].rstrip("_-.") or phase_id.lower()
    return f"phase/{phase_id}-{slug}"


def parallel_start(args: argparse.Namespace) -> None:
    """Move a planned phase into its own worktree: stamp it, commit the stamp, cut branch + worktree.

    This is the single place the engine makes a git commit, and it is deliberate. The stamp must
    exist on BOTH the default branch (so this stream's pointer skips the phase) and the phase
    branch (so the worktree session claims the stream), and the branch has to be cut from a commit
    that already contains it. Since v43 running here is the default and this command is the
    opt-in: it runs when the operator asks for a worktree (the do-* skills run it on the
    `worktree` mode word, never on their own), or straight from the operator's hand. It does not
    demand a clean tree -- the operator asks for a worktree mid-stride, not at a quiet point:
    `git add -- <paths>` then `git commit --only -- <paths>` makes the one fixed-message commit
    exact whatever else is dirty or staged -- only the phase folder plus the regenerated works/
    files go in, everything else stays behind in this checkout, and the worktree is cut from that
    commit ("start from the latest commit"). Stamping and asking the operator to commit cannot
    achieve that by construction; this can.

    In a nested personal install (P35) the phase gets a worktree PAIR instead -- see
    `_parallel_start_nested`; `--host-branch` is required there and refused at root. v86 (§9.4): an
    explain phase (`## Explain` in intent.md) may omit it -- its host worktree is cut DETACHED at the
    host base (`execution.host_branch` null), since an explain makes no host commit; `--host-branch`
    is still honoured for it, a non-explain phase still needs it, and `--repo` never goes without it.
    """
    host_branch = getattr(args, "host_branch", None)
    host_base = getattr(args, "host_base", None)
    repo_args = getattr(args, "repo", None) or []
    repo_base_args = getattr(args, "repo_base", None) or []
    if NESTED is None:
        if host_branch is not None or host_base is not None:
            raise SystemExit("--host-branch and --host-base are for a nested personal install only (they name the host repo's branch and base); "
                             "at root the phase branch is the only branch -- nothing was written")
    else:
        host_branch = (host_branch or "").strip() or None
        if host_branch is None and (repo_args or repo_base_args):
            raise SystemExit(NESTED_SET_NEEDS_HOST_BRANCH)
    set_repos = []
    if repo_args or repo_base_args:  # P40.S6: a worktree set's repos, multi-repo hosts only
        if NESTED is None:
            raise SystemExit("--repo and --repo-base are for a multi-repo host only (a nested install whose registry lists repos); "
                             "at root the phase branch is the only branch -- nothing was written")
        repos = nested_repos()
        if not repos:
            raise SystemExit("--repo and --repo-base are for a multi-repo host only; this nested install registers no repos (the host is the one repo, "
                             f"and the pair is all there is; register repos with {WORKFLOW_CMD} nested-repos --add <path>) -- nothing was written")
        set_repos = _parse_set_repo_args(repo_args, repo_base_args, repos)
    pdir = require_phase(args.phase)
    if NESTED is not None and host_branch is None and not explain_phase(pdir):
        raise SystemExit(NESTED_HOST_BRANCH_REQUIRED)  # v86: below require_phase, so an explain phase may go detached
    data = read_json(pdir / "phase.json")
    if data.get("status") != "planned":
        raise SystemExit(f"phase {args.phase} is {data.get('status')!r}; a phase enters its worktree before it starts (parallel-start needs status 'planned') -- a phase already in flight finishes on this stream")
    if phase_pinned(data):
        raise SystemExit(f"phase {args.phase} carries v42's legacy pin to the default stream (execution.mode=default, written by v42's old skip command or phase new --on-main); it was pinned deliberately, so un-pin it by hand: delete the execution block from {shown(pdir)}/phase.json first")
    if data.get("execution") is not None:
        raise SystemExit(f"phase {args.phase} already carries an execution block: {json.dumps(data['execution'], ensure_ascii=False)}")
    _require_git_repo()
    phases = all_active_phases()
    stream = current_stream(phases)
    if stream:
        raise SystemExit(f"this checkout is on parallel stream {stream}; run parallel-start from the default stream")
    busy = _git_operation_in_progress()
    if busy:
        raise SystemExit(f"a {busy} is in progress in this checkout; finish or abort it first -- the stamp commit must be an ordinary commit on the default branch")
    branch = _phase_branch(args.phase, data.get("name") or args.phase, args.slug)
    if _branch_exists(branch):
        raise SystemExit(f"branch already exists: {branch} (pass --slug to pick another name)")
    for p in phases:
        execution = phase_execution(p)
        if execution and execution.get("branch") == branch:
            raise SystemExit(f"branch {branch} is already stamped on phase {p['id']}")
    if NESTED is not None:
        _parallel_start_nested(args, pdir, data, branch, host_branch, host_base, set_repos)
        return
    if args.worktree:
        worktree = Path(os.path.abspath(str(Path(args.worktree).expanduser())))
        if not worktree.parent.exists():
            raise SystemExit(f"worktree parent directory does not exist: {worktree.parent}")
    else:
        worktree = ROOT / WORKTREES_DIR / branch.split("/", 1)[1]  # P<N>-<slug>: the branch's own tail
    if worktree.exists():
        raise SystemExit(f"worktree path already exists: {worktree} (pass --worktree to pick another path)")
    # Every guard is above this line. The exclude line is not repo content and is idempotent, so
    # it goes first; the parent is created only for the default home (an override keeps its guard).
    _ensure_worktrees_excluded()
    if not args.worktree:
        worktree.parent.mkdir(parents=True, exist_ok=True)

    # base_branch (P35.S7, additive): the branch the stamp commit lands on, so a worktree checkout's
    # Streams view can read the default stream's row from it.
    data["execution"] = {"mode": "parallel", "branch": branch, "worktree": str(worktree), "base_branch": git_current_branch()}
    write_json(pdir / "phase.json", data)
    append_event("phase_parallel_started", phase=args.phase, branch=branch, worktree=str(worktree))
    rebuild_index_and_state()
    stamp_paths = [str(pdir.relative_to(ROOT)), *STAMP_WORKS_FILES]
    _git(["add", "--", *stamp_paths])
    _git(["commit", "--only", "-m", f"chore(works): opt {args.phase} into parallel execution", "--", *stamp_paths])
    proc = _git(["worktree", "add", "-b", branch, str(worktree), "HEAD"], check=False)
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip() or f"exit {proc.returncode}"
        raise SystemExit(
            f"git worktree add failed: {detail}\n"
            f"the stamp for {args.phase} is already committed on this branch; fix the cause and finish by hand: "
            f"git worktree add -b {branch} {worktree} HEAD")
    print(f"phase {args.phase} now runs in its own worktree")
    print(f"branch={branch}")
    print(f"worktree={worktree}")
    print(f"stamp committed here: chore(works): opt {args.phase} into parallel execution -- only {shown(pdir)}/ plus the regenerated works/ files "
          f"(a phase not yet committed goes in whole); everything else dirty or staged stayed behind in this checkout, uncommitted")
    print(f"the worktree starts from that commit (HEAD); {WORKTREES_DIR}/ is excluded via the repo's .git/info/exclude")
    print(f"next: enter the worktree in this session (Claude Code: EnterWorktree with path={worktree}) or open a session there, run next, and drive the phase from that checkout")
    print(f"this stream's pointer now skips {args.phase}; after the branch is merged back, run: {WORKFLOW_CMD} parallel-teardown {args.phase}")


def _resolve_host_base(host: Path, explicit):
    """`(ref, sha)` for the host worktree's base (P35, Decision 19), resolved inside the host repo
    with no fetch: `--host-base` when given; else `origin/HEAD`'s target, else `init.defaultBranch`
    when that branch exists locally, else a local `main`, then `master`. Refuses (nothing written)
    when nothing resolves to a commit."""
    def local_branch(name):
        return bool(name) and _git(["rev-parse", "--verify", "--quiet", f"refs/heads/{name}"], cwd=host, check=False).returncode == 0

    if explicit is not None:
        ref = explicit.strip()
        sha = _rev_parse(ref, cwd=host) if ref else None
        if not sha:
            raise SystemExit(f"--host-base {explicit!r} does not resolve to a commit in the host repo {host} "
                             f"(the engine never fetches: fetch first if the ref is remote) -- nothing was written")
        return ref, sha
    ref = None
    proc = _git(["symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD"], cwd=host, check=False)
    if proc.returncode == 0 and proc.stdout.strip():
        ref = proc.stdout.strip()
    if ref is None:
        configured = _git(["config", "--get", "init.defaultBranch"], cwd=host, check=False).stdout.strip()
        if local_branch(configured):
            ref = configured
    if ref is None:
        ref = next((cand for cand in ("main", "master") if local_branch(cand)), None)
    sha = _rev_parse(ref, cwd=host) if ref else None
    if not sha:
        tried = f"{ref!r} does not resolve to a commit" if ref else "no origin/HEAD, no local init.defaultBranch, main or master"
        raise SystemExit(f"cannot resolve the host's default branch for the host worktree's base ({tried}); "
                         f"pass --host-base <ref> (e.g. --host-base HEAD, or another phase's host branch to stack on it) -- nothing was written")
    return ref, sha


def _parse_set_repo_args(repo_args: list, base_args: list, repos: list) -> list:
    """`parallel-start --repo <name>=<branch> ... --repo-base <name>=<ref> ...` (P40.S6, S2 §15) ->
    `[(registry entry, branch, base ref or None)]` in `--repo` order. Refuses, nothing written: a
    malformed value (the branch is required: the engine never invents a name), a name the registry
    does not list, a duplicate `--repo` or `--repo-base`, a `--repo-base` naming no `--repo`."""
    refused = "parallel-start: refused -- nothing was written"
    registry = {r["name"]: r for r in repos}
    wanted = {}
    for raw in repo_args:
        name, sep, value = raw.partition("=")
        name, value = name.strip(), value.strip()
        if not sep or not name or not value:
            raise SystemExit(f"{refused}: --repo {raw!r} needs the form <name>=<branch>; the branch is required -- name it by that repo's "
                             f"convention ({WORKFLOW_CMD} nested-convention --repo <name>) and let the operator confirm it")
        if name not in registry:
            raise SystemExit(f"{refused}: no registered repo is named {name} (registered: {', '.join(registry)})")
        if name in wanted:
            raise SystemExit(f"{refused}: --repo {name} is given twice (one branch per repo)")
        wanted[name] = value
    bases = {}
    for raw in base_args:
        name, sep, value = raw.partition("=")
        name, value = name.strip(), value.strip()
        if not sep or not name or not value:
            raise SystemExit(f"{refused}: --repo-base {raw!r} needs the form <name>=<ref>")
        if name not in wanted:
            raise SystemExit(f"{refused}: --repo-base {name}={value} names a repo not given with --repo (add --repo {name}=<branch>)")
        if name in bases:
            raise SystemExit(f"{refused}: --repo-base {name} is given twice")
        bases[name] = value
    return [(registry[name], value, bases.get(name)) for name, value in wanted.items()]


def _set_repo_plan(repo: dict, branch: str, base_arg, host: Path, host_wt: Path, adopt: bool = False, single_base: bool = False):
    """One repo of a worktree set, checked and planned (P40.S6, S2 §15): `(plan, [])`, or `(None,
    problems)` -- every problem for this repo, so the caller can print one combined refusal before it
    writes anything. Each `git -C` runs against the repo's MAIN checkout (`nested_repo_path`), behind
    `_git_work_tree_root`. The guards: a valid branch name; the branch checked out nowhere; the base
    resolving locally (`base_arg`, else the registry's `default_branch` as `refs/heads/<D>`; never
    fetched); the target `<host_wt>/<path>` absent and not registered; `<path>/` ignored by the host
    (else the worktree shows as untracked in the host worktree and blocks its removal). Reuse is the
    host branch's (P35 Decision 22): an existing branch checked out nowhere is reused, anchored at
    merge-base(base, branch). `plan` is what `_stamp_set_repo` stamps and the worktree step runs.
    Shared with `parallel-add-repo` (S7), which passes the live host worktree as both `host` and
    `host_wt` and `single_base` (its `--repo-base REF` names no repo). With `adopt` (S7, OQ3) the
    target must instead be an EXISTING worktree of this repo, its own work tree root, on `branch`
    (not detached); the branch may be held by no OTHER worktree; `branch_created` is False (the
    branch is the operator's, teardown keeps it) and the anchor is merge-base(base, branch)."""
    name, rel = repo["name"], repo["path"]
    main = nested_repo_path(repo)
    target = host_wt / rel
    label = f"repo {name}"

    def base_flag(ref):
        return f"--repo-base {ref}" if single_base else f"--repo-base {name}={ref}"
    if not _git_work_tree_root(main):
        return None, [f"{label}: its main checkout {main} is not a git work tree root (missing, or a plain directory); fix the registry "
                      f"({WORKFLOW_CMD} nested-repos) first"]
    problems = []
    if branch.startswith("-") or _git(["check-ref-format", "--branch", branch], cwd=main, check=False).returncode != 0:
        problems.append(f"{label}: --repo {name}={branch}: {branch!r} is not a valid branch name in {name}")
        branch_ok = False
    else:
        branch_ok = True
    entries = _worktree_entries(cwd=main)
    target_real = os.path.realpath(str(target))
    if branch_ok:
        # --adopt: the adopted worktree itself holds the branch; only ANOTHER holder is refused
        holder = next((path for path, ref in entries if ref == f"refs/heads/{branch}" and not (adopt and os.path.realpath(path) == target_real)), None)
        if holder:
            problems.append(f"{label}: branch {branch} is checked out in {holder}; a branch lives in one worktree at a time, so pick another "
                            f"branch or switch that checkout off it")
    if adopt:
        problems += _adopt_target_problems(label, name, main, target, branch, entries)
    elif os.path.lexists(str(target)):
        problems.append(f"{label}: the target path {target} already exists")
    elif target_real in {os.path.realpath(path) for path, _ref in entries}:
        problems.append(f"{label}: {target} is still registered as a git worktree of {name} (a stale entry); run git -C {main} worktree prune first")
    if _git(["check-ignore", "-q", f"{rel}/"], cwd=host, check=False).returncode != 0:
        problems.append(f"{label}: {rel}/ is not ignored by the host, so its worktree would show as untracked in the host worktree and block "
                        f"that worktree's removal; add /{rel}/ to the host's .git/info/exclude")
    default = repo.get("default_branch")
    if base_arg is not None:
        base, base_from = base_arg, "repo-base"
        base_sha = _rev_parse(base_arg, cwd=main)
        if not base_sha:
            problems.append(f"{label}: {base_flag(base_arg)} does not resolve to a commit in {name} (the engine never fetches: fetch first if the ref is remote)")
    elif default:
        base, base_from = default, "default"
        base_sha = _rev_parse(f"refs/heads/{default}", cwd=main)
        if not base_sha:
            problems.append(f"{label}: its default_branch {default} is not a local branch in {main} (the engine never fetches); create or fetch it there, "
                            f"or pass {base_flag('<ref>')}")
    else:
        base, base_from, base_sha = None, None, None
        problems.append(f"{label}: no {base_flag('<ref>')} and no default_branch in the registry; pass {base_flag('<ref>')}")
    branch_exists = branch_ok and _git(["rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"], cwd=main, check=False).returncode == 0
    branch_created = False if adopt else not branch_exists
    if adopt and not branch_exists and not problems:
        problems.append(f"{label}: --adopt: branch {branch} has no commit yet in {name}; commit on it first (an adopted branch is anchored at its merge-base with the base)")
    anchor = base_sha
    if base_sha and branch_exists and not branch_created:
        proc = _git(["merge-base", base_sha, f"refs/heads/{branch}"], cwd=main, check=False)
        anchor = proc.stdout.strip()
        if proc.returncode != 0 or not anchor:
            problems.append(f"{label}: branch {branch} shares no history with the base {base} ({base_sha}); pass another {base_flag('<ref>')}")
    if problems:
        return None, problems
    return {"name": name, "path": rel, "main": main, "target": target, "branch": branch, "base": base, "base_sha": base_sha,
            "base_from": base_from, "branch_created": branch_created, "anchor": anchor, "adopted": adopt}, []


def _adopt_target_problems(label: str, name: str, main: Path, target: Path, branch: str, entries: list) -> list:
    """`parallel-add-repo --adopt`'s target rows (P40.S7, S2 §15 and §25): `<host-wt>/<path>` must
    exist, be its own work tree root (`git -C` on a plain dir answers for the host worktree), be one
    of the repo's registered worktrees (`git -C <main> worktree list --porcelain`), and have its HEAD
    on `branch`. One row for the first that fails: each later check presumes the earlier ones."""
    hint = f"--adopt stamps a worktree of {name} that already sits there"
    if not os.path.lexists(str(target)):
        return [f"{label}: --adopt: the target {target} does not exist; {hint} (drop --adopt to cut a new one)"]
    if not _git_work_tree_root(target):
        return [f"{label}: --adopt: {target} is not a git work tree root (a plain directory, or inside another repo); {hint}"]
    ref = next((ref for path, ref in entries if os.path.realpath(path) == os.path.realpath(str(target))), False)
    if ref is False:
        return [f"{label}: --adopt: {target} is a git work tree, but not a worktree of {name} (git -C {main} worktree list does not list it); {hint}"]
    if ref is None:
        return [f"{label}: --adopt: {target} has a detached HEAD; check out {branch} there first (git -C {target} switch {branch})"]
    if ref != f"refs/heads/{branch}":
        on = ref[len("refs/heads/"):] if ref.startswith("refs/heads/") else ref
        return [f"{label}: --adopt: {target} is on {on}, not {branch}; adopt it as --repo {name}={on}, or check out {branch} there first"]
    return []


def _stamp_set_repo(data: dict, plan: dict) -> dict:
    """Stamp one planned repo into phase `data` (P40.S6, S2 §18): `execution.repos.<name>` = {worktree,
    branch, base, base_sha, branch_created}, and the re-stamped `repo_anchors.<name>`: `created` = the
    plan's anchor (the base for a created branch, merge-base(base, branch) for a reused one), `branch`
    = the branch, the review keys kept. `data["execution"]` must already exist. THE one stamp writer,
    shared by `parallel-start --repo` and `parallel-add-repo` (S7)."""
    execution = data["execution"]
    repos = execution.get("repos") if isinstance(execution.get("repos"), dict) else {}
    repos[plan["name"]] = {"worktree": str(plan["target"]), "branch": plan["branch"], "base": plan["base"],
                           "base_sha": plan["base_sha"], "branch_created": plan["branch_created"]}
    execution["repos"] = repos
    anchors = data.get("repo_anchors") if isinstance(data.get("repo_anchors"), dict) else {}
    prev = anchors.get(plan["name"]) if isinstance(anchors.get(plan["name"]), dict) else {}
    entry = {key: prev.get(key) for key in REPO_ANCHOR_KEYS}
    entry.update(created=plan["anchor"], branch=plan["branch"])
    return _with_repo_anchors(data, {plan["name"]: entry})


def _set_repo_add_cmd(plan: dict) -> list:
    """The `git -C <main> worktree add ...` that cuts one planned repo's worktree."""
    add = (["worktree", "add", "-b", plan["branch"], str(plan["target"]), plan["base_sha"]] if plan["branch_created"]
           else ["worktree", "add", str(plan["target"]), plan["branch"]])
    return ["git", "-C", str(plan["main"]), *add]


def _set_repo_line(plan: dict, by: str = "parallel-start") -> str:
    """parallel-start's (and parallel-add-repo's, `by`) one output line for a repo of the set."""
    if plan.get("adopted"):  # P40.S7: --adopt
        how = "adopted: the operator's own worktree and branch, branch_created=false, so teardown keeps the branch"
        anchor = "merge-base of the base and the adopted branch"
    else:
        how = f"created by {by}" if plan["branch_created"] else "reused: it existed and was not checked out"
        anchor = "the base" if plan["branch_created"] else "merge-base of the base and the reused branch"
    src = ("--repo-base" if plan["base_from"] == "repo-base"
           else f"local -- fetch in {plan['name']} first if your custom branches from a fresh default")
    return (f"repo {plan['name']}: worktree={plan['target']} branch={plan['branch']} ({how}) base={plan['base']} ({plan['base_sha']}, {src}) "
            f"repo_anchors.{plan['name']}.created={plan['anchor']} ({anchor})")


def _parallel_start_nested(args: argparse.Namespace, pdir: Path, data: dict, branch: str, host_branch, host_base_arg, set_repos=(),
                           on_stamp=None, stamp_message=None) -> tuple:
    """`parallel-start` in a nested personal install (P35): a host worktree with the nested worktree inside.

    The pair is `<host>/.claude/worktrees/P<N>-<slug>` on `host_branch` (the operator names it, by the
    host's custom), with `<host-wt>/workflow` on `phase/P<N>-<slug>` in the nested repo, which owns the
    state and the stream key. Order (P35.S2 (a)): every guard first; the host's common exclude; the
    execution block plus the re-stamped `host_anchors.created`, rebuilt; the nested stamp commit; the
    host worktree; the nested worktree; the copied `CLAUDE.local.md`. Nothing is ever created under
    `<host-wt>/.claude/` (Claude Code reads skills, agents and settings.local.json through from the main
    checkout), and nothing is fetched. A failure after the stamp commit prints the exact remaining
    commands. `execution.worktree` is the NESTED worktree, so removal stays in the repo that owns it.

    P40.S6: on a multi-repo host, `set_repos` (`[(registry entry, branch, base ref)]` from `--repo` /
    `--repo-base`) makes the pair a SET: every repo's guards run after the host's, in one combined
    refusal; the stamp adds `execution.repos` and re-stamps each named repo's `repo_anchors` through
    `_stamp_set_repo`; each repo worktree is cut at `<host-wt>/<path>` after the nested worktree.
    Without `set_repos` every step and line is exactly the pair's.

    v86 (§9.4): `host_branch` None (an explain phase, never a set: the caller refused both other
    cases) cuts the host worktree DETACHED at the resolved host base (`git worktree add --detach`):
    no branch to name, create, reuse or integrate. The stamp carries `host_branch: null` and
    `host_branch_created: false`; `host_anchors.created` is the base; everything else is the pair's.

    P52 (`phase reopen`): `on_stamp(data, host_wt, nested_wt)` runs once every guard has passed and
    before the stamp is written, so a reopen's verdict lands in the same stamp commit; `stamp_message`
    replaces the commit subject.
    Returns `(host_wt, nested_wt)`."""
    host = HOST_ROOT
    detached = host_branch is None
    if host is None or not _git_available(cwd=host):
        raise SystemExit(f"the nested install's host {host} is not a git work tree; parallel-start cuts a host worktree, so it needs one -- nothing was written")
    busy = _git_operation_in_progress(cwd=host)
    if busy:
        raise SystemExit(f"a {busy} is in progress in the host checkout {host}; finish or abort it first -- nothing was written")
    if not detached and (host_branch.startswith("-") or _git(["check-ref-format", "--branch", host_branch], cwd=host, check=False).returncode != 0):
        raise SystemExit(f"--host-branch {host_branch!r} is not a valid branch name in the host repo -- nothing was written")
    host_entries = _worktree_entries(cwd=host)
    holder = None if detached else next((path for path, ref in host_entries if ref == f"refs/heads/{host_branch}"), None)
    if holder:
        raise SystemExit(f"host branch {host_branch} is checked out in {holder}; a branch lives in one worktree at a time, so pick another --host-branch "
                         f"or switch that checkout off it -- nothing was written")
    host_branch_created = (not detached) and _git(["rev-parse", "--verify", "--quiet", f"refs/heads/{host_branch}"], cwd=host, check=False).returncode != 0
    rel = Path(os.path.relpath(ROOT, host))
    if args.worktree:
        host_wt = Path(os.path.abspath(str(Path(args.worktree).expanduser())))
        if not host_wt.parent.exists():
            raise SystemExit(f"worktree parent directory does not exist: {host_wt.parent}")
    else:
        host_wt = host / WORKTREES_DIR / branch.split("/", 1)[1]  # P<N>-<slug>: the phase branch's own tail
    nested_wt = host_wt / rel
    if host_wt.exists():
        raise SystemExit(f"host worktree path already exists: {host_wt} (pass --slug or --worktree to pick another path) -- nothing was written")
    registered = {os.path.realpath(path) for path, _ref in host_entries} | {os.path.realpath(path) for path, _ref in _worktree_entries()}
    for path in (host_wt, nested_wt):
        if os.path.realpath(str(path)) in registered:
            raise SystemExit(f"{path} is still registered as a git worktree (a stale entry); run `git worktree prune` in that repo first -- nothing was written")
    base_ref, base_sha = _resolve_host_base(host, host_base_arg)
    if detached or host_branch_created:
        anchor = base_sha
    else:
        proc = _git(["merge-base", base_sha, f"refs/heads/{host_branch}"], cwd=host, check=False)
        anchor = proc.stdout.strip()
        if proc.returncode != 0 or not anchor:
            raise SystemExit(f"host branch {host_branch} shares no history with the base {base_ref} ({base_sha}); pass another --host-base -- nothing was written")
    base_branch = git_current_branch()
    plans, problems = [], []
    for repo, repo_branch, repo_base in set_repos:  # P40.S6: every repo's guards, one combined refusal
        plan, repo_problems = _set_repo_plan(repo, repo_branch, repo_base, host, host_wt)
        problems += repo_problems
        if plan:
            plans.append(plan)
    if problems:
        raise SystemExit(f"parallel-start {args.phase} refused -- nothing was written:\n" + "\n".join(f"{i}. {p}" for i, p in enumerate(problems, 1)))

    # Every guard is above this line. The exclude line is not repo content and is idempotent.
    _ensure_worktrees_excluded(cwd=host)
    if not args.worktree:
        host_wt.parent.mkdir(parents=True, exist_ok=True)
    if on_stamp is not None:  # P52: phase reopen's verdict, in the same stamp commit
        on_stamp(data, host_wt, nested_wt)
    data["execution"] = {
        "mode": "parallel", "branch": branch, "worktree": str(nested_wt),
        "host_worktree": str(host_wt), "host_branch": host_branch, "host_base": base_ref, "host_base_sha": base_sha,
        "host_branch_created": host_branch_created, "base_branch": base_branch,
    }
    # phase scope's base must be where the host worktree starts, not the host HEAD at phase new
    # (P35.S2 (f)); stamped before the commit so both branches carry it.
    data = _with_host_anchors(data, {"created": anchor})
    for plan in plans:  # P40.S6: execution.repos + the repo_anchors re-stamp, before the commit like the host's
        data = _stamp_set_repo(data, plan)
    write_json(pdir / "phase.json", data)
    if plans:
        append_event("phase_parallel_started", phase=args.phase, branch=branch, worktree=str(nested_wt),
                     host_branch=host_branch, host_worktree=str(host_wt), repos={p["name"]: p["branch"] for p in plans})
    else:
        append_event("phase_parallel_started", phase=args.phase, branch=branch, worktree=str(nested_wt),
                     host_branch=host_branch, host_worktree=str(host_wt))
    rebuild_index_and_state()
    stamp_paths = [str(pdir.relative_to(ROOT)), *STAMP_WORKS_FILES]
    subject = stamp_message or f"chore(works): opt {args.phase} into parallel execution"
    _git(["add", "--", *stamp_paths])
    _git(["commit", "--only", "-m", subject, "--", *stamp_paths])

    q = shlex.quote
    host_add = (["worktree", "add", "--detach", str(host_wt), base_sha] if detached
                else ["worktree", "add", "-b", host_branch, str(host_wt), base_sha] if host_branch_created
                else ["worktree", "add", str(host_wt), host_branch])
    steps = [
        (["git", "-C", str(host), *host_add], host),
        (["git", "-C", str(ROOT), "worktree", "add", "-b", branch, str(nested_wt), "HEAD"], ROOT),
    ]
    steps += [(_set_repo_add_cmd(plan), plan["main"]) for plan in plans]  # P40.S6: repo worktrees, inside the host worktree
    local_md = host / "CLAUDE.local.md"
    copy_cmd = f"cp {q(str(local_md))} {q(str(host_wt / 'CLAUDE.local.md'))}"

    def remaining(i):
        cmds = [" ".join(q(part) for part in cmd) for cmd, _cwd in steps[i:]]
        if local_md.is_file():
            cmds.append(copy_cmd)
        return "\n".join(f"  {c}" for c in cmds)

    for i, (cmd, cwd) in enumerate(steps):
        proc = _git(cmd[3:], cwd=cwd, check=False)
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip() or f"exit {proc.returncode}"
            undo = (f"\nor give up on the pair: git -C {q(str(host))} worktree remove {q(str(host_wt))}, then un-stamp {args.phase} by hand "
                    f"(delete the execution block from {shown(pdir)}/phase.json and commit)" if i == 1 else "")
            raise SystemExit(
                f"{' '.join(cmd[3:5])} failed: {detail}\n"
                f"the stamp for {args.phase} is already committed in the nested repo; fix the cause and finish by hand, in this order:\n"
                f"{remaining(i)}{undo}")
    copied = False
    if local_md.is_file():
        try:
            shutil.copyfile(local_md, host_wt / "CLAUDE.local.md")
            copied = True
        except OSError as exc:
            raise SystemExit(f"copying CLAUDE.local.md failed: {exc}\nboth worktrees exist; without the copy a session there loads no workspace contract. Finish by hand:\n  {copy_cmd}")
    print(f"phase {args.phase} now runs in its own worktree pair (nested install)")
    print(f"branch={branch}")
    print(f"worktree={nested_wt}")
    print(f"host_worktree={host_wt}")
    if detached:
        print(f"host_branch=- (detached host worktree at the base: an explain phase makes no host commit, so it has no host branch)")
    else:
        print(f"host_branch={host_branch} ({'created by parallel-start' if host_branch_created else 'reused: it existed and was not checked out'})")
    print(f"host_base={base_ref} ({base_sha})")
    print(f"host_anchors.created={anchor} ({'the base' if detached or host_branch_created else 'merge-base of the base and the reused branch'}) -- phase scope's base")
    for plan in plans:
        print(_set_repo_line(plan))
    if nested_repos():  # P40.S6: multi-repo only
        outside = [r["name"] for r in nested_repos() if r["name"] not in {p["name"] for p in plans}]
        if outside:
            print(f"not in this set: {', '.join(outside)} -- inside the set phase scope skips them, never reading their main checkouts")
    print(f"stamp committed in the nested repo: {subject} -- only {shown(pdir)}/ plus the regenerated works/ files; "
          f"everything else dirty or staged stayed behind, uncommitted")
    print(f"the nested worktree starts from that commit (HEAD); /{WORKTREES_DIR}/ is excluded via the host's .git/info/exclude")
    print("CLAUDE.local.md copied into the host worktree" if copied else f"note: no {local_md} to copy -- a session in the host worktree loads no workspace contract")
    print(f"next: enter the host worktree in this session (Claude Code: EnterWorktree with path={host_wt}) or open a session there, run "
          f"{WORKFLOW_CMD} next (it prints stream={branch}), and drive the phase from that checkout")
    if detached:
        print(f"there: no product commits -- the host worktree is detached and read-only by intent (an explain reads the host code at {base_sha[:12]}); "
              f"workflow commits go to git -C {rel.as_posix()} (the nested worktree, on {branch})")
        print(f"this stream's pointer now skips {args.phase}; the host side has no branch, so there is nothing to integrate there -- merge {branch} in the nested repo")
        return host_wt, nested_wt
    if plans:
        print(f"there: product commits go to each repo's branch in its worktree (git -C <repo path>); workflow commits go to git -C {rel.as_posix()} "
              f"(the nested worktree, on {branch}); {host_branch} carries only the host's own files")
    else:
        print(f"there: product commits go to {host_branch} in the host worktree; workflow commits go to git -C {rel.as_posix()} (the nested worktree, on {branch})")
    print(f"this stream's pointer now skips {args.phase}; the host branch is integrated by the host's own custom (nested-convention), never merged by the engine")
    return host_wt, nested_wt


# --- reopen a done phase whose PR is still open (P52) -----------------------------------------------
# A change request after the phase is done and its PR is open, the team's (a team repo leaves the PR open at
# the close) or the operator's (a waived gate's close, a red CI, a request after Ready). The operator's word
# reopens the SAME phase: `in_progress` + `changes_requested`, a required gate
# re-opened, and its fix round runs on the existing PR branch -- never a second PR, never a force-push.
# Nested: its own worktree pair, the host worktree ON that branch, so a phase running at the time never
# waits. At root the PR branch carries the phase's record itself, so the reopen runs IN PLACE in the
# checkout that holds it (see `_reopen_root`). Local only: no push, merge, force-push or gh call.

REOPEN_REFUSED = "nothing was written"


def _reopen_refuse(phase_id: str, why: str) -> None:
    raise SystemExit(f"phase reopen {phase_id}: refused -- {why} -- {REOPEN_REFUSED}")


def _reopen_pick(phase_id: str, entries: list, branch_arg) -> list:
    """The open PR entry per repo the reopen works on: the only one; else `--branch`'s; else the unique
    top of a stack (an entry no other open entry of that repo is based on). Refuses an ambiguous repo."""
    by_repo = {}
    for e in entries:
        by_repo.setdefault(e.get("repo"), []).append(e)
    picked = []
    for repo, group in by_repo.items():
        if branch_arg:
            hit = [e for e in group if e.get("branch") == branch_arg]
            if hit:
                picked.append(hit[0])
                continue
            if len(by_repo) == 1:
                _reopen_refuse(phase_id, f"--branch {branch_arg} names no open PR of {phase_id} "
                                         f"(open: {', '.join(_pr_label(e) for e in group)})")
        if len(group) == 1:
            picked.append(group[0])
            continue
        bases = {e.get("base") for e in group}
        tops = [e for e in group if e.get("branch") not in bases]
        if len(tops) == 1:
            picked.append(tops[0])
            continue
        _reopen_refuse(phase_id, f"{len(group)} open PRs in {repo or _pr_one_repo()} ({', '.join(_pr_label(e) for e in group)}) and no single "
                                 f"top of a stack; name the one whose branch takes the fixes with --branch <b>")
    return picked


def _reopen_apply(pdir: Path, data: dict, note: str) -> dict:
    """The reopen's verdict, as `review-phase --verdict changes_requested` records it: `status` ->
    in_progress, `review` = changes_requested with the note, the REVIEW slice(s) driven the same way, and
    a REQUIRED gate re-opened (walkthrough, requested_at, cleared_at -> null; `required` and the operator's
    note survive). A waived gate stays waived. `completed_at`, the `pr` block and the anchors are kept. Writes the slice files and their events; the caller writes phase.json."""
    old_status = data.get("status")
    data["review"] = {"status": "changes_requested", "reviewed_at": now_iso(), "reviewer": None, "note": note,
                      "fix_passes": 1}  # the reopen is the change request that opens this cycle's one fix pass
    acceptance = phase_acceptance(data)
    gate = "none"
    if acceptance is not None:
        if acceptance.get("required") is True:
            acceptance.update({"walkthrough": None, "requested_at": None, "cleared_at": None})
            gate = "reopened"
        elif acceptance.get("required") is False:
            gate = "waived"
    data["status"] = "in_progress"
    driven = _drive_review_slices(pdir, "changes_requested")
    return {"old_status": old_status, "gate": gate, "slices": driven, "note": note}


def _reopen_read_hint(note: str) -> str:
    """What the fix round reads first, by whose request the reopen note says it is (P52 F4)."""
    who = note.strip().lower()
    team = "the team's review (gh pr view <n> --json reviews,comments)"
    operator = f"the operator's request (the reopen note {note.strip()!r}, plus any PR comment or failing check it points at)"
    if who.startswith("team-reported:"):
        return f"read {team}"
    if who.startswith("operator-reported:"):
        return f"read {operator}"
    return "read the change request: a team's review (gh pr view <n> --json reviews,comments), or an operator's request (the reopen note, plus any PR comment or failing check it points at)"


def _reopen_report(phase_id: str, label: str, where, outcome: dict) -> None:
    slices = ", ".join(f"{sid} {old} -> changes_requested" for sid, old in outcome["slices"]) or "no REVIEW slice"
    gate = {"reopened": "the required acceptance gate is re-opened (walkthrough, requested_at, cleared_at reset)",
            "waived": "the waived acceptance gate stays waived", "none": "no acceptance gate block"}[outcome["gate"]]
    print(f"reopened={phase_id} branch={label} worktree={where}")
    print(f"phase {phase_id}: {outcome['old_status']} -> in_progress, review changes_requested ({slices}); {gate}; "
          f"completed_at and the pr block kept")
    print(f"next: the fix round in that checkout, on {label} -- {_reopen_read_hint(outcome.get('note') or '')}, cut fix slices "
          f"({WORKFLOW_CMD} slice new --phase {phase_id} --slice {phase_id}.F<n> --kind fix), then the re-review; at its would-pass push the fixes "
          f"(git push, never --force) and replace the body (pr-check, then gh pr edit <n> --body-file <body>), never a second PR; then the gate if "
          f"required and the close again: the pr skill's reference/reopen.md")


def cmd_reopen_phase(args: argparse.Namespace) -> None:
    """`phase reopen <P> --note "team-reported: <what>"|"operator-reported: <what>" [--slug <s>] [--worktree <path>] [--branch <b>]
    [--host-branch <name>]` (P52): reopen a DONE phase whose PR is still open, on the operator's word, for
    a change request after the pass, the team's or the operator's.

    Guards, all before any write, each naming itself: the phase is active (an archived one is refused as
    archived), `done`, has an open PR (`_pr_open_entries`: every PR merged is refused, naming pr-sync),
    a non-empty note, runs from the default stream with no git operation in progress, and its PR branch is
    free (checked out in no worktree; the host's main checkout holding it is told how to switch off it).

    Nested (the main case): `_parallel_start_nested` on the recorded host branch (reused, anchored at the
    merge-base of the recorded base and the branch), the reopen's verdict applied inside its stamp commit
    (`on_stamp`). The nested side gets `phase/P<N>-<slug>`, or
    `-reopen<k>` when that name is taken (never a merged branch). An `execution` block left by an earlier,
    torn-down run is replaced (its facts go into the `phase_reopened` event); one still holding a worktree,
    or v42's pin, is refused. A multi-repo host builds the set from each repo's open PR branch.

    Root: `_reopen_root`, in place. Never pushes, merges, force-pushes or calls gh."""
    phase_id = args.phase
    note = (args.note or "").strip()
    pdir = ACTIVE / phase_id
    if not (pdir / "phase.json").exists():
        if phase_id in archived_phase_ids():
            _reopen_refuse(phase_id, f"{phase_id} is archived; a reopen works on an active phase only (an archived phase's PR merged, or "
                                     f"its hold was forced) -- a new change request (the team's or the operator's) becomes a new phase (create-phase)")
        raise SystemExit(f"phase not found: {phase_id}")
    data = read_json(pdir / "phase.json")
    if data.get("status") != "done":
        _reopen_refuse(phase_id, f"{phase_id} is {data.get('status')!r}, not 'done'; a phase still in flight takes the change request in its "
                                 f"own fix round ({WORKFLOW_CMD} review-phase {phase_id} --verdict changes_requested)"
                       + ("" if NESTED is not None else f" -- at root a phase's record is only as current as this checkout's branch: if {phase_id} "
                                                        f"is done on its PR branch, run phase reopen where that branch is checked out"))
    entries = _pr_open_entries(data)
    if not entries:
        block = phase_pr(data)
        if block is not None and isinstance(block.get("waived"), dict):
            why = "its PR is waived, so there is no PR to reopen"
        elif block is not None and any(e.get("url") for e in block["branches"]):
            why = (f"every recorded PR reads state=merged ({', '.join(_pr_label(e) for e in block['branches'] if e.get('url'))}); "
                   f"merged state is only as fresh as the last sync -- refresh it with {WORKFLOW_CMD} pr-sync {phase_id}, and a change "
                   f"request on merged work is a new phase")
        else:
            why = "it records no opened PR (no pr branch entry with a URL)"
        _reopen_refuse(phase_id, why)
    if not note:
        _reopen_refuse(phase_id, "--note is empty; say whose change request it is and what it asks: --note \"team-reported: <what>\" or --note \"operator-reported: <what>\"")
    _require_git_repo()
    phases = all_active_phases()
    stream = current_stream(phases)
    old = data.get("execution")
    own_branch = (phase_execution(data) or {}).get("branch")
    if stream and not (NESTED is None and stream == own_branch):
        _reopen_refuse(phase_id, f"this checkout is on parallel stream {stream}; run phase reopen from the default stream")
    busy = _git_operation_in_progress()
    if busy:
        _reopen_refuse(phase_id, f"a {busy} is in progress in this checkout; finish or abort it first")
    picked = _reopen_pick(phase_id, entries, getattr(args, "branch", None))
    if NESTED is None:
        _reopen_root(args, pdir, data, picked, note, stream)
        return
    if getattr(args, "host_branch", None) and not nested_repos():
        _reopen_refuse(phase_id, "--host-branch is for a multi-repo host only; a single-repo host's worktree goes on the PR branch itself")
    if phase_pinned(data):
        _reopen_refuse(phase_id, f"{phase_id} carries v42's legacy pin to the default stream (execution.mode=default); un-pin it by hand: "
                                 f"delete the execution block from {shown(pdir)}/phase.json first")
    if old is not None and phase_execution(data) is None:
        _reopen_refuse(phase_id, f"{phase_id} carries an execution block that is not a parallel stamp: {json.dumps(old, ensure_ascii=False)}")
    if old is not None and (old.get("worktree") is not None or old.get("host_worktree") is not None):
        _reopen_refuse(phase_id, f"{phase_id}'s earlier worktree pair is still stamped (worktree={old.get('host_worktree') or old.get('worktree')}); "
                                 f"finish its integration and {WORKFLOW_CMD} parallel-teardown {phase_id} first, then re-run")
    host = HOST_ROOT
    if host is None or not _git_available(cwd=host):
        _reopen_refuse(phase_id, f"the nested install's host {host} is not a git work tree")
    repos = nested_repos()
    set_repos, host_branch, host_base = [], None, None
    if repos:
        registry = {r["name"]: r for r in repos}
        for e in picked:
            repo = registry.get(e.get("repo"))
            if repo is None:
                _reopen_refuse(phase_id, f"{_pr_label(e)} names no registered repo")
            main = nested_repo_path(repo)
            base = _pr_diff_ref(main, e.get("base"))[1]
            if not base:
                _reopen_refuse(phase_id, f"{_pr_label(e)}: its recorded base {e.get('base')} is neither origin/{e.get('base')} nor a local branch in "
                                         f"{main} (the engine never fetches)")
            set_repos.append((repo, e["branch"], base))
        host_branch = (getattr(args, "host_branch", None) or (old or {}).get("host_branch") or "").strip() or None
        if host_branch is None:
            _reopen_refuse(phase_id, "a multi-repo host's worktree needs a host branch (it carries no product), and no earlier run of this phase "
                                     "recorded one; name it by the host's custom: --host-branch <name>")
    else:
        entry = picked[0]
        host_branch = entry["branch"]
        host_base = _pr_diff_ref(host, entry.get("base"))[1]
        if not host_base:
            _reopen_refuse(phase_id, f"{_pr_label(entry)}: its recorded base {entry.get('base')} is neither origin/{entry.get('base')} nor a local "
                                     f"branch in the host {host} (the engine never fetches: fetch first)")
    checks = [(host, b) for b in ([host_branch] if not repos else [])] + [(nested_repo_path(r), b) for r, b, _base in set_repos]
    for path, b in checks:
        if not _rev_parse(f"refs/heads/{b}", cwd=path):
            remote = _rev_parse(f"refs/remotes/origin/{b}", cwd=path)
            _reopen_refuse(phase_id, f"the PR branch {b} is not a local branch in {path}" + (
                f"; it exists as origin/{b} -- create it there first: git -C {path} branch {b} origin/{b}" if remote else
                " (the engine never fetches and never invents the branch: fetch it first)"))
        holder = next((p for p, ref in _worktree_entries(cwd=path) if ref == f"refs/heads/{b}"), None)
        if holder:
            if os.path.realpath(holder) == os.path.realpath(str(path)):
                default = _repo_default_branch(path) or "<default>"
                _reopen_refuse(phase_id, f"the PR branch {b} is checked out in the main checkout {path}; a branch lives in one worktree at a time, "
                                         f"so switch that checkout off it first (the engine never switches it for you): git -C {path} switch {default}")
            _reopen_refuse(phase_id, f"the PR branch {b} is checked out in {holder}; a branch lives in one worktree at a time -- run the fix round "
                                     f"there, or switch that checkout off it first")
    branch = _phase_branch(phase_id, data.get("name") or phase_id, args.slug)
    taken = lambda b: _branch_exists(b) or any((phase_execution(p) or {}).get("branch") == b for p in phases if p.get("id") != phase_id)  # noqa: E731
    if taken(branch):
        if args.slug:
            _reopen_refuse(phase_id, f"branch {branch} already exists or is stamped on another phase (pass another --slug)")
        branch = next((f"{branch}-reopen{k}" for k in range(2, 100) if not taken(f"{branch}-reopen{k}")), None)
        if branch is None:
            _reopen_refuse(phase_id, "no free phase branch name; pass --slug <s>")
    labels = ",".join(_pr_label(e) for e in picked)
    outcome = {}

    def on_stamp(stamped: dict, host_wt: Path, nested_wt: Path) -> None:
        outcome.update(_reopen_apply(pdir, stamped, note))
        append_event("phase_reopened", phase=phase_id, note=note, branch=labels, worktree=str(host_wt), nested_branch=branch,
                     previous_execution=old)

    host_wt, _nested_wt = _parallel_start_nested(args, pdir, data, branch, host_branch, host_base, set_repos, on_stamp=on_stamp,
                                                 stamp_message=f"chore(works): reopen {phase_id} in its own worktree")
    if old is not None:
        print(f"replaced the earlier run's execution block (branch={old.get('branch')}, worktree=null); its facts are in the phase_reopened event")
    _reopen_report(phase_id, labels, host_wt, outcome)


def _reopen_root(args: argparse.Namespace, pdir: Path, data: dict, picked: list, note: str, stream) -> None:
    """The root shape of `phase reopen` (P52, decided in S3): IN PLACE, in the checkout that holds the PR
    branch. At root the PR branch carries the product AND the phase's record (pr-branch switched the
    checkout to it, and the slice commits landed there), so a done record with an open PR exists only
    where that branch -- or one stacked on it -- is checked out. A worktree on the PR branch would need the
    reopen's stamp on a second branch, forking the phase's record into a conflict at the next stack merge,
    and a local integration the open PR forbids. So: no worktree, no stamp, no commit (like review-phase);
    the transition is written here and the fix round commits on the PR branch. A phase running in this
    checkout on another branch keeps running: cut a worktree on the PR branch by hand and reopen there."""
    phase_id = args.phase
    if args.worktree or args.slug or getattr(args, "host_branch", None):
        _reopen_refuse(phase_id, "--worktree, --slug and --host-branch are for a nested install; at root the reopen runs in place, in the "
                                 "checkout that holds the PR branch (no worktree is cut)")
    entry = picked[0]
    branch = entry["branch"]
    current = git_current_branch()
    if current != branch:
        holder = next((p for p, ref in _worktree_entries() if ref == f"refs/heads/{branch}"), None)
        if holder:
            _reopen_refuse(phase_id, f"at root the reopen runs in place on the PR branch, and {branch} is checked out in {holder}: run it there "
                                     f"(cd {holder} && {WORKFLOW_CMD} phase reopen {phase_id} --note \"...\")")
        q = shlex.quote
        # a sibling of the repo, never inside it: a worktree under the repo shows as untracked there unless excluded
        wt = ROOT.parent / f"{ROOT.name}-{slugify(branch.replace('/', '-'), fallback=phase_id.lower())}"
        _reopen_refuse(phase_id, f"at root the PR branch carries {phase_id}'s record, so the reopen runs in place where {branch} is checked out, "
                                 f"and this checkout is on {current or 'a detached HEAD'}. Either switch here at a slice boundary "
                                 f"(git switch {branch}), or, so a phase running here never waits, check it out beside this one and reopen there: "
                                 f"git worktree add {q(str(wt))} {branch} && cd {q(str(wt))} && {WORKFLOW_CMD} phase reopen {phase_id} --note \"...\"")
    outcome = _reopen_apply(pdir, data, note)
    write_json(pdir / "phase.json", data)
    append_event("phase_reopened", phase=phase_id, note=note, branch=_pr_label(entry), worktree=str(ROOT), nested_branch=None,
                 previous_execution=data.get("execution"))
    rebuild_index_and_state()
    print(f"reopen: in place -- at root {branch} carries {phase_id}'s record and this checkout is on it"
          + (f" (the phase's own stream {stream})" if stream else "")
          + "; no worktree was cut and nothing was committed (commit the phase folder and works/ with the round's first commit)")
    _reopen_report(phase_id, _pr_label(entry), ROOT, outcome)


def parallel_add_repo(args: argparse.Namespace) -> None:
    """`parallel-add-repo <P> --repo <name>=<branch> [--repo-base <ref>] [--adopt]` (P40.S7, S2 §15,
    §18, §25): add one registered repo to a phase's worktree set MID-PHASE, run from INSIDE that set.

    Not a re-run of `parallel-start`: mid-phase the phase's `phase.json` advances on its phase branch,
    so the stamp is written and committed HERE, in the set's nested worktree, never on the default
    stream (a default-stream stamp would diverge from the branch copy and conflict at merge). Create
    mode cuts `<host-wt>/<path>` (S6's guards, `_set_repo_plan`); `--adopt` (OQ3) stamps a worktree of
    the repo already sitting there, on `<branch>` -- glide P29's hand-made ones -- so teardown knows
    it; it keeps the operator's branch (`branch_created: false`) and cuts nothing. Order: every guard
    (nothing written on a refusal) -> the stamp (`_stamp_set_repo`: `execution.repos.<n>` plus the
    `repo_anchors` re-stamp) -> the nested commit `chore(works): add <repo> to <P>'s worktree set`
    (`--only` phase.json plus the regenerated works/ files: mid-phase the phase folder may hold the
    running slice's uncommitted files, which stay behind) -> create mode's `worktree add`; a failure
    after the commit prints the remaining command. Refused at root, on a single-repo nested install,
    outside a set, for another phase, for a name the SET's registry lacks, for a repo already stamped."""
    q = shlex.quote
    if NESTED is None:
        raise SystemExit("parallel-add-repo is for a multi-repo host only (a nested install whose registry lists repos), run inside a phase's worktree set; "
                         "at root the phase branch is the only branch -- nothing was written")
    repos = nested_repos()
    if not repos:
        raise SystemExit("parallel-add-repo is for a multi-repo host only; this nested install registers no repos (the host is the one repo, "
                         f"and the pair is all there is; register repos with {WORKFLOW_CMD} nested-repos --add <path>) -- nothing was written")
    if not _in_worktree_set():
        raise SystemExit(f"parallel-add-repo runs inside the phase's worktree set (its host worktree, under {HOST_ROOT}/{WORKTREES_DIR}/), never on the "
                         f"default stream: mid-phase the phase's phase.json advances on its phase branch, so a stamp written here would diverge from the "
                         f"branch copy and conflict at merge. Open a session in the set and run it there; a phase with no set yet takes its repos at the "
                         f"start: {WORKFLOW_CMD} parallel-start {args.phase} --host-branch <name> --repo <name>=<branch> -- nothing was written")
    _require_git_repo()
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    execution = phase_execution(data)
    phases = all_active_phases()
    stream = current_stream(phases)

    def same(a, b):
        return isinstance(a, str) and os.path.realpath(a) == os.path.realpath(str(b))

    if not (execution and stream and execution.get("branch") == stream and same(execution.get("worktree"), ROOT)
            and same(execution.get("host_worktree"), HOST_ROOT)):
        mine = next((p.get("id") for p in phases if stream and (phase_execution(p) or {}).get("branch") == stream), None)
        where = f"this set runs {mine}, on {stream}" if mine else "this checkout is on no phase's stream"
        raise SystemExit(f"phase {args.phase} is not this worktree set's phase ({where}); run parallel-add-repo inside {args.phase}'s own set "
                         f"-- nothing was written")
    name, sep, branch = (args.repo or "").partition("=")
    name, branch = name.strip(), branch.strip()
    refused = f"parallel-add-repo {args.phase} refused -- nothing was written"
    if not sep or not name or not branch:
        raise SystemExit(f"{refused}: --repo {args.repo!r} needs the form <name>=<branch>; the branch is required -- name it by that repo's "
                         f"convention ({WORKFLOW_CMD} nested-convention --repo <name>) and let the operator confirm it")
    registry = {r["name"]: r for r in repos}
    rel = Path(os.path.relpath(ROOT, HOST_ROOT)).as_posix()
    base_branch = execution.get("base_branch") or "<the default branch>"
    if name not in registry:
        raise SystemExit(f"{refused}: no repo named {name} is registered in this set's registry (the marker this nested worktree tracks on {stream}; "
                         f"registered: {', '.join(registry)}). Register it on the default stream ({WORKFLOW_CMD} nested-repos --add <path>, in the "
                         f"main host checkout {MAIN_HOST}), commit it there, then merge that into this phase branch: git -C {rel} merge --no-ff {base_branch}")
    stamped = execution.get("repos") if isinstance(execution.get("repos"), dict) else {}
    if name in stamped:
        prev = stamped[name] if isinstance(stamped[name], dict) else {}
        if prev.get("worktree"):
            raise SystemExit(f"{refused}: repo {name} is already in {args.phase}'s worktree set (worktree={prev.get('worktree')}, "
                             f"branch={prev.get('branch')}); one stamp per repo")
        raise SystemExit(f"{refused}: repo {name} is already stamped in {args.phase}'s worktree set and its worktree was torn down "
                         f"(branch={prev.get('branch')}, worktree=null); one stamp per repo, including a torn-down one, so the stamp stays as history")
    busy = _git_operation_in_progress()
    if busy:
        raise SystemExit(f"{refused}: a {busy} is in progress in the nested worktree {ROOT}; finish or abort it first -- the stamp commit must be an "
                         f"ordinary commit on {stream}")
    plan, problems = _set_repo_plan(registry[name], branch, args.repo_base, HOST_ROOT, HOST_ROOT, adopt=args.adopt, single_base=True)
    if problems:
        raise SystemExit(f"{refused}:\n" + "\n".join(f"{i}. {p}" for i, p in enumerate(problems, 1)))

    # Every guard is above this line.
    data = _stamp_set_repo(data, plan)
    write_json(pdir / "phase.json", data)
    append_event("phase_parallel_repo_added", phase=args.phase, repo=name, branch=branch, worktree=str(plan["target"]), adopted=bool(args.adopt))
    rebuild_index_and_state()
    message = f"chore(works): add {name} to {args.phase}'s worktree set"
    stamp_paths = [str((pdir / "phase.json").relative_to(ROOT)), *STAMP_WORKS_FILES]
    _git(["add", "--", *stamp_paths])
    _git(["commit", "--only", "-m", message, "--", *stamp_paths])
    commit = (_rev_parse("HEAD") or "HEAD")[:7]
    if not args.adopt:
        cmd = _set_repo_add_cmd(plan)
        proc = _git(cmd[3:], cwd=plan["main"], check=False)
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip() or f"exit {proc.returncode}"
            raise SystemExit(
                f"git worktree add failed: {detail}\n"
                f"the stamp for {name} is already committed in the nested worktree ({commit} {message}); fix the cause and finish by hand:\n"
                f"  {' '.join(q(part) for part in cmd)}\n"
                f"or drop {name} from the set: git -C {q(rel)} revert --no-edit {commit}")
    print(f"repo {name} {'adopted into' if args.adopt else 'added to'} {args.phase}'s worktree set")
    print(_set_repo_line(plan, by="parallel-add-repo"))
    if args.adopt:
        log = _git(["log", "--oneline", f"{plan['base_sha']}..refs/heads/{branch}"], cwd=plan["main"], check=False).stdout.splitlines()
        print(f"commits on {branch} beyond the base {plan['base']}: {len(log)} -- they come into {args.phase}'s scope (phase scope reads {name} "
              f"from {plan['anchor'][:7]})")
        for line in log[:5]:
            print(f"  {line}")
        if len(log) > 5:
            print(f"  ... {len(log) - 5} more: git -C {q(str(plan['target']))} log --oneline {plan['base_sha'][:7]}..{branch}")
    print(f"stamp committed in the nested worktree, on {stream}: {commit} {message} -- only {shown(pdir)}/phase.json plus the regenerated "
          f"works/ files; everything else dirty or staged stayed behind, uncommitted")
    print(f"there: product commits for {name} go to {branch} in its worktree (git -C {plan['path']}); phase scope now reads {name} from it")


def parallel_teardown(args: argparse.Namespace) -> None:
    """Retire a merged parallel phase's worktree and branch, from the default stream.

    Refuses while the branch is unmerged (merging is a separate step). Keeps `mode`/`branch`
    as history and only nulls `worktree`, which is informational anyway.

    In a nested personal install (P35) the phase has a worktree PAIR -- see `_parallel_teardown_nested`;
    `--discard-ignored` belongs to it and is refused at root.
    """
    discard_ignored = getattr(args, "discard_ignored", False)
    if NESTED is None and discard_ignored:
        raise SystemExit("--discard-ignored is for a nested personal install's paired teardown only; "
                         "at root, teardown removes the worktree as it always has -- nothing was removed")
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    execution = phase_execution(data)
    if not execution:
        raise SystemExit(f"phase {args.phase} is not running in its own worktree (no parallel execution block)")
    branch = execution.get("branch")
    if not branch:
        raise SystemExit(f"phase {args.phase} has a parallel execution block with no branch; fix phase.json first")
    _require_git_repo()
    if git_current_branch() == branch:
        raise SystemExit(f"this checkout is on {branch}; run parallel-teardown from the default stream (a worktree cannot remove itself)")
    branch_exists = _branch_exists(branch)
    if branch_exists and _git(["merge-base", "--is-ancestor", branch, "HEAD"], check=False).returncode != 0:
        raise SystemExit(f"branch {branch} is not merged into HEAD; merge it first, then run: {WORKFLOW_CMD} parallel-teardown {args.phase}")
    if NESTED is not None:
        _parallel_teardown_nested(args, pdir, data, execution, branch, branch_exists, discard_ignored)
        return
    removed = []
    worktree = execution.get("worktree")
    if worktree and Path(worktree).exists():
        proc = _git(["worktree", "remove", str(worktree)], check=False)
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip() or f"exit {proc.returncode}"
            raise SystemExit(f"git worktree remove {worktree} failed: {detail}\nclean up that checkout (uncommitted work?) or drop it with `git worktree remove --force {worktree}`, then re-run")
        removed.append(f"worktree {worktree}")
    else:
        _git(["worktree", "prune"], check=False)
    if branch_exists:
        _git(["branch", "-d", branch])  # -d refuses an unmerged branch: a free second check
        removed.append(f"branch {branch}")
    data["execution"]["worktree"] = None
    write_json(pdir / "phase.json", data)
    append_event("phase_parallel_torndown", phase=args.phase, branch=branch)
    rebuild_index_and_state()
    print(f"phase {args.phase} parallel checkout retired")
    for item in removed:
        print(f"removed {item}")
    if not removed:
        print("nothing to remove (worktree and branch were already gone)")
    print(f"execution.worktree=null; mode/branch kept as history (branch={branch})")
    print("phase.json changed -- commit it with the rest of the merge cleanup")


def _ignored_worktree_files(path, skip=()) -> list:
    """The ignored, worktree-only files and directories in the checkout at `path`, as git lists them
    (`ls-files --others --ignored --exclude-standard --directory`), minus the entries in `skip`.
    `git worktree remove` deletes these without asking, so the paired teardown lists them first.
    git also lists a directory holding only ignored entries beside those entries; the directory
    line is dropped then, so each path is named once."""
    proc = _git(["ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--directory"], cwd=path)
    entries = [entry for entry in proc.stdout.split("\0") if entry and entry not in skip]
    return [entry for entry in entries
            if not (entry.endswith("/") and any(other != entry and other.startswith(entry) for other in entries))]


def _detached_orphans(worktree, base_sha):
    """`(short HEAD, count)` when the checkout at `worktree` is detached with commits beyond `base_sha`
    that no branch, tag or remote ref holds -- removing it would orphan them -- else None. The host
    worktree's orphan rule (P35), shared with each repo worktree of a set (P40.S8)."""
    if _git(["symbolic-ref", "-q", "HEAD"], cwd=worktree, check=False).returncode == 0:
        return None
    keep = [base_sha] if base_sha else []
    proc = _git(["rev-list", "--count", "HEAD", "--not", *keep, "--branches", "--tags", "--remotes"], cwd=worktree, check=False)
    orphans = int(proc.stdout.strip() or 0) if proc.returncode == 0 else 0
    if not orphans:
        return None
    return _git(["rev-parse", "--short", "HEAD"], cwd=worktree, check=False).stdout.strip(), orphans


def _unstamped_worktrees(host_wt, execution: dict) -> list:
    """P40.S8 (S2 §19's scan): every git work tree inside the host worktree `host_wt` that the phase's
    stamp does not name, as `[{"path", "main", "name", "branch", "standalone"}]` sorted by path; [] when
    there is none, or when git cannot run (it never raises: `validate` calls it too). Removing the host
    worktree would delete such a tree with everything in it, uncommitted work included, so
    `parallel-teardown` refuses each one always (`--discard-ignored` never covers it) and `validate`
    warns. Shared by both, and it runs in single-repo nested installs too. The union of two sources:

    * the host worktree's ignored entries (`ls-files --others --ignored --directory`), minus the nested
      worktree, each walked for a `.git` file or dir: the entry itself, else each of its subdirectories
      -- two levels at most, enough for a repo at `<path>` or `<dir>/<path>`; symlinks never followed
      (an UNignored one shows as untracked and is already refused as the host worktree's uncommitted work);
    * every registered repo's `git worktree list` paths under the host worktree that exist on disk
      (multi-repo only; a stale registration holds no files).

    Excluded: the nested worktree and every stamped `execution.repos.<n>.worktree`. Per tree: `main` is
    the checkout it belongs to (`git -C <main> worktree remove <path>`), `name` the registry name when
    that is a registered repo, `branch` its branch (None when detached), and `standalone` marks a
    repository of its own (a `.git` directory), which no `worktree remove` applies to."""
    host_wt = Path(host_wt)
    host_real = os.path.realpath(str(host_wt))
    repos = execution.get("repos") if isinstance(execution.get("repos"), dict) else {}
    exclude = {os.path.realpath(value["worktree"]) for value in repos.values()
               if isinstance(value, dict) and isinstance(value.get("worktree"), str)}
    if isinstance(execution.get("worktree"), str):
        exclude.add(os.path.realpath(execution["worktree"]))
    nested_rel = f"{Path(os.path.relpath(ROOT, HOST_ROOT)).as_posix()}/" if HOST_ROOT is not None else None
    found = {}

    def add(path, **known):
        real = os.path.realpath(str(path))
        if real in exclude or not real.startswith(host_real + os.sep):
            return
        entry = found.setdefault(real, {"path": str(path), "main": None, "name": None, "branch": None, "standalone": False})
        entry.update({key: value for key, value in known.items() if value is not None})

    proc = _repo_git(host_wt, "ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--directory")
    if proc is not None and proc.returncode == 0:
        for entry in proc.stdout.split("\0"):
            if not entry.endswith("/") or entry == nested_rel:
                continue
            top = host_wt / entry.rstrip("/")
            if top.is_symlink() or not top.is_dir():
                continue
            if os.path.lexists(str(top / ".git")):
                add(top)
                continue
            try:
                children = sorted(child for child in top.iterdir() if child.is_dir() and not child.is_symlink())
            except OSError:
                continue
            for child in children:
                if os.path.lexists(str(child / ".git")):
                    add(child)
    mains = {}
    for repo in nested_repos():
        if not (isinstance(repo, dict) and isinstance(repo.get("path"), str)):
            continue
        main = nested_repo_path(repo)
        if not _git_work_tree_root(main):
            continue
        mains[os.path.realpath(str(main))] = repo.get("name")
        listing = _repo_git(main, "worktree", "list", "--porcelain")
        if listing is None or listing.returncode != 0:
            continue
        for path, ref in _parse_worktree_list(listing.stdout):
            if os.path.lexists(path):
                branch = ref[len("refs/heads/"):] if ref and ref.startswith("refs/heads/") else None
                add(path, main=main, name=repo.get("name"), branch=branch)
    for entry in found.values():
        if entry["main"] is not None:
            continue
        path = Path(entry["path"])
        main = _main_host_checkout(path)
        if (path / ".git").is_dir() or os.path.realpath(str(main)) == os.path.realpath(str(path)):
            entry["standalone"] = True
            continue
        entry["main"] = main
        entry["name"] = mains.get(os.path.realpath(str(main)))
        head = _repo_git(path, "symbolic-ref", "-q", "--short", "HEAD")
        entry["branch"] = (head.stdout.strip() or None) if head is not None and head.returncode == 0 else None
    return sorted(found.values(), key=lambda entry: entry["path"])


def _unstamped_refusal(phase_id: str, host_wt, found: list, execution: dict, branch: str, branch_exists: bool) -> str:
    """`parallel-teardown`'s refusal item for `_unstamped_worktrees` (P40.S8, S2 §19): each tree named,
    with its ways out -- removed by hand against its own repo after its branch is integrated, or, in a
    multi-repo host, adopted into the set (`parallel-add-repo --adopt`, from inside the set) when it
    sits at a registered repo's path and that repo is not stamped yet."""
    q = shlex.quote
    stamped = execution.get("repos") if isinstance(execution.get("repos"), dict) else {}
    registry = {repo.get("name"): repo for repo in nested_repos() if isinstance(repo, dict)}
    lines = [f"the host worktree {host_wt} holds {len(found)} git work tree(s) {phase_id}'s stamp does not name; removing the host worktree "
             f"would delete each with everything in it, uncommitted work included, so parallel-teardown refuses them always "
             f"(--discard-ignored does not cover them):"]
    for tree in found:
        path = tree["path"]
        if tree["standalone"]:
            lines.append(f"      {path}: a git repository of its own, not a worktree")
            lines.append(f"        move it out of the host worktree first (after pushing or integrating its work)")
            continue
        on = f"on {tree['branch']}" if tree["branch"] else "detached"
        lines.append(f"      {path}: a worktree of {tree['main']}, {on}")
        after = f"after integrating {tree['branch']}" if tree["branch"] else "after putting its commits on a branch"
        lines.append(f"        remove it by hand {after}: git -C {q(str(tree['main']))} worktree remove {q(path)}")
        repo = registry.get(tree["name"]) if tree["name"] else None
        if (repo is not None and tree["name"] not in stamped and isinstance(repo.get("path"), str)
                and os.path.realpath(path) == os.path.realpath(os.path.join(str(host_wt), repo["path"]))):
            lines.append(f"        or adopt it into the set, from inside the set: cd {q(str(host_wt))} && {WORKFLOW_CMD} parallel-add-repo {phase_id} "
                         f"--repo {tree['name']}={tree['branch'] or '<branch>'} --adopt (then merge the phase branch again and re-run this teardown)")
    if not branch_exists:
        lines.append(f"    note: the phase branch {branch} is gone, so a repo stamped on it after its last merge (parallel-add-repo) is missing from "
                     f"this copy of phase.json and is refused here as unstamped -- the safe outcome")
    return "\n".join(lines)


def _unstamped_set_warning(phase_id: str, execution: dict):
    """`validate`'s row for `_unstamped_worktrees` (P40.S8, S2 §18): the warning text, or None. Only for
    a LIVE host worktree (`host_worktree` set and on disk), nested only. A warning, never an error:
    `--update` runs `validate` with check=True after its writes, and glide's P29 trips it. The phase
    branch's stamp counts too: a mid-phase `parallel-add-repo` commits its stamp there only, so the
    default stream's copy lacks it until the merge (teardown runs after the merge and reads its own)."""
    host_wt = execution.get("host_worktree")
    if NESTED is None or not isinstance(host_wt, str) or not Path(host_wt).is_dir():
        return None
    found = _unstamped_worktrees(host_wt, execution)
    if found and isinstance(execution.get("branch"), str) and execution["branch"].strip():
        try:
            branch_copy = _phase_json_at_ref(f"refs/heads/{execution['branch']}", phase_id)
        except SystemExit:  # no git binary: keep what the local stamp says
            branch_copy = None
        repos = ((branch_copy or {}).get("execution") or {}).get("repos") if isinstance(branch_copy, dict) else None
        on_branch = {os.path.realpath(value["worktree"]) for value in (repos.values() if isinstance(repos, dict) else ())
                     if isinstance(value, dict) and isinstance(value.get("worktree"), str)}
        found = [tree for tree in found if os.path.realpath(tree["path"]) not in on_branch]
    if not found:
        return None
    listed = ", ".join(tree["path"] for tree in found)
    if nested_repos():
        return (f"{phase_id}'s host worktree holds git worktrees it did not stamp: {listed} -- parallel-teardown will refuse them; adopt them from "
                f"inside the set (parallel-add-repo {phase_id} --repo <name>=<branch> --adopt) or remove them by hand after integrating their branches")
    return (f"{phase_id}'s host worktree holds git worktrees it did not stamp: {listed} -- parallel-teardown will refuse them; remove them by hand "
            f"after integrating their branches (git -C <repo> worktree remove <path>)")


def _teardown_set_repos(execution: dict) -> list:
    """P40.S8: a worktree set's stamped repos as `parallel-teardown` handles them, one dict per
    `execution.repos.<name>` in stamp order: `name`; `wt`, the stamped worktree (None once torn down);
    `live` (on disk); `main`, its repo's MAIN checkout -- the registry path under the main host checkout,
    else (a name the registry dropped) the checkout a live worktree's common git dir names, else None;
    `entries`, `main`'s `worktree list`; and the stamp's `branch`, `base`, `base_sha`, `created`. [] when
    the block has no `repos`, as in every single-repo and at-root phase."""
    repos = execution.get("repos")
    if not isinstance(repos, dict):
        return []
    registry = {repo.get("name"): repo for repo in nested_repos() if isinstance(repo, dict)}
    out = []
    for name, value in repos.items():
        if not isinstance(value, dict):
            continue
        wt = value.get("worktree") if isinstance(value.get("worktree"), str) and value.get("worktree") else None
        live = bool(wt) and Path(wt).exists()
        main = None
        repo = registry.get(name)
        if repo is not None and isinstance(repo.get("path"), str) and _git_work_tree_root(nested_repo_path(repo)):
            main = nested_repo_path(repo)
        elif live and _git_work_tree_root(Path(wt)):
            candidate = _main_host_checkout(Path(wt))
            if os.path.realpath(str(candidate)) != os.path.realpath(wt):
                main = candidate
        listing = _repo_git(main, "worktree", "list", "--porcelain") if main is not None else None
        branch, sha = value.get("branch"), value.get("base_sha")
        out.append({"name": name, "wt": wt, "live": live, "main": main,
                    "entries": _parse_worktree_list(listing.stdout) if listing is not None and listing.returncode == 0 else [],
                    "branch": branch if isinstance(branch, str) and branch.strip() else None, "base": value.get("base"),
                    "base_sha": sha if isinstance(sha, str) and sha else None, "created": value.get("branch_created") is True})
    return out


def _set_repo_teardown_problems(repo: dict, ignored: list) -> list:
    """The guards on one live stamped repo worktree (P40.S8, S2 §19), the host worktree's own: it must be
    a worktree of its repo (else no `worktree remove` applies, and removing the host worktree would delete
    it); uncommitted work; a detached HEAD holding commits no ref keeps. Its ignored, worktree-only files
    are appended to `ignored`, for the one combined list `--discard-ignored` covers."""
    q = shlex.quote
    name, wt, main = repo["name"], repo["wt"], repo["main"]
    label = f"repo {name}"
    if not _git_work_tree_root(Path(wt)):
        return [f"{label}: its stamped worktree {wt} is not a git work tree root (its .git is gone, or it is a plain directory), so no git worktree "
                f"remove applies, and removing the host worktree would delete it with everything in it -- move what it holds out of the host "
                f"worktree, or delete it by hand, then re-run"]
    if main is None:
        return [f"{label}: its main checkout cannot be found (no registered repo is named {name}, and {wt} names no other checkout), so its "
                f"worktree cannot be removed against it -- re-register it ({WORKFLOW_CMD} nested-repos --add <path> --name {name}), then re-run"]
    if not any(os.path.realpath(path) == os.path.realpath(wt) for path, _ref in repo["entries"]):
        return [f"{label}: {wt} is a git work tree, but not a worktree of {name} (git -C {main} worktree list does not list it), so it cannot be "
                f"removed against {name}, and removing the host worktree would delete it -- move it out of the host worktree first, then re-run"]
    problems = []
    dirty = _git(["status", "--porcelain", "--untracked-files=normal"], cwd=wt).stdout.splitlines()
    if dirty:
        problems.append(f"{label}: its worktree {wt} has uncommitted work (commit it on {repo['branch']}, or move or discard it):\n"
                        + "\n".join(f"      {line}" for line in dirty))
    ignored += [(wt, entry) for entry in _ignored_worktree_files(wt)]
    orphan = _detached_orphans(wt, repo["base_sha"])
    if orphan:
        problems.append(f"{label}: its worktree {wt} is detached at {orphan[0]} with {orphan[1]} commit(s) beyond the base that no branch, tag or "
                        f"remote ref holds; removing it would orphan them -- put them on a branch first "
                        f"(git -C {q(wt)} switch -c <name>, or switch {repo['branch']} to them)")
    return problems


def _parallel_teardown_nested(args: argparse.Namespace, pdir: Path, data: dict, execution: dict,
                              branch: str, branch_exists: bool, discard_ignored: bool) -> None:
    """`parallel-teardown` in a nested personal install (P35): retire the host + nested worktree pair.

    Run from the default stream of the nested repo, after `phase/...` is merged there (the caller
    checked it). Order (P35.S2 (d), (e); Decisions 11, 19):

    1. every guard first, in one combined report, with nothing touched: uncommitted work in the
       nested worktree; ignored, worktree-only files in either worktree (`git worktree remove`
       deletes them silently, so they are listed and refused unless `--discard-ignored`); uncommitted
       work in the host worktree; a detached host worktree holding commits no ref keeps (orphaned
       at removal);
    2. the nested worktree, ALWAYS first -- removing the host worktree first exits 0 and silently
       deletes the nested worktree inside it, untracked state included;
    3. the host worktree;
    4. the host branch: deleted (`-D`; `-d` measures against HEAD) only when the engine created it
       and it has 0 commits beyond `host_base_sha`; otherwise kept -- it is the operator's, integrated
       by the host's own custom (Decision 18), and the engine never pushes, opens or merges it;
    5. the nested `phase/...` branch, as at root; a registration left in either repo is pruned.

    `worktree` and `host_worktree` become null; the other host keys and `base_branch` stay as
    history. A failure after the first removal prints the exact remaining commands; a re-run of
    this command resumes too, since every step skips what is already gone.

    A worktree SET (P40.S8, S2 §19) adds its repo half, gated on the stamp's `execution.repos`, so a
    single-repo pair runs exactly the steps above: each stamped repo worktree is guarded like the host
    worktree (uncommitted work, ignored files, detached orphans) and removed FIRST, before the nested
    worktree, with `git -C <main> worktree remove`, against its repo's main checkout (no `--force`: a
    plain remove deletes ignored files, as the host's does; the guards cover the rest); one gone from
    disk but still registered is pruned there before any branch step (a stale registration holds its
    branch). A repo branch is deleted (`-D`, against its `base_sha`) only when the set created it, it
    has 0 commits beyond `base_sha` and no other worktree holds it; reused and adopted branches are the
    operator's and stay. Each `execution.repos.<n>.worktree` becomes null with the host keys. In EVERY
    nested teardown, single-repo too, a git work tree inside the host worktree that the stamp does not
    name (`_unstamped_worktrees`) is refused, `--discard-ignored` or not: removing the host worktree
    would delete it with its uncommitted work. The stamp read is this copy of phase.json, merged from
    the phase branch, so a repo `parallel-add-repo` stamped after the last merge is refused as unstamped."""
    q = shlex.quote
    host = HOST_ROOT
    nested_wt = execution.get("worktree")
    host_wt = execution.get("host_worktree")
    host_branch = execution.get("host_branch")
    base_sha = execution.get("host_base_sha")
    created = execution.get("host_branch_created") is True
    nested_live = bool(nested_wt) and Path(nested_wt).exists()
    host_live = bool(host_wt) and Path(host_wt).exists()
    host_git = host is not None and _git_available(cwd=host)
    if (host_live or host_branch) and not host_git:
        raise SystemExit(f"the nested install's host {host} is not a git work tree; the paired teardown needs it to retire the host worktree "
                         f"and branch -- nothing was removed")
    set_repos = _teardown_set_repos(execution)  # P40.S8: [] unless a multi-repo set stamped repos

    # 1. Every guard, before anything is removed.
    problems, ignored = [], []
    unstamped = _unstamped_worktrees(host_wt, execution) if host_live else []
    if unstamped:
        problems.append(_unstamped_refusal(args.phase, host_wt, unstamped, execution, branch, branch_exists))
    for repo in set_repos:
        if repo["live"]:
            problems += _set_repo_teardown_problems(repo, ignored)
    if nested_live:
        dirty = _git(["status", "--porcelain", "--untracked-files=normal"], cwd=nested_wt).stdout.splitlines()
        if dirty:
            problems.append(f"the nested worktree {nested_wt} has uncommitted work (commit it on {branch} and merge again, or discard it):\n"
                            + "\n".join(f"      {line}" for line in dirty))
        ignored += [(nested_wt, entry) for entry in _ignored_worktree_files(nested_wt)]
    if host_live:
        rel = os.path.relpath(ROOT, host)
        skip = {"CLAUDE.local.md", f"{Path(rel).as_posix().rstrip('/')}/"}  # the engine's copy; the nested worktree (step 2)
        # P40.S8: never a git work tree as a plain ignored path -- the stamped repo worktrees are guarded
        # and removed on their own (step 1), the unstamped ones refused above
        skip |= {f"{Path(os.path.relpath(os.path.realpath(path), os.path.realpath(host_wt))).as_posix()}/"
                 for path in [repo["wt"] for repo in set_repos if repo["wt"]] + [tree["path"] for tree in unstamped]}
        ignored += [(host_wt, entry) for entry in _ignored_worktree_files(host_wt, skip)]
        dirty = _git(["status", "--porcelain", "--untracked-files=normal"], cwd=host_wt).stdout.splitlines()
        if dirty:
            problems.append(f"the host worktree {host_wt} has uncommitted work "
                            f"({f'commit it on {host_branch}' if host_branch else 'it is detached: put it on a branch'}, or move or discard it):\n"
                            + "\n".join(f"      {line}" for line in dirty))
        orphan = _detached_orphans(host_wt, base_sha)
        if orphan:
            problems.append(f"the host worktree {host_wt} is detached at {orphan[0]} with {orphan[1]} commit(s) beyond the base that no branch, tag or "
                            f"remote ref holds; removing it would orphan them -- put them on a branch first "
                            f"(git -C {q(host_wt)} switch -c <name>" + (f", or switch {host_branch} to them)" if host_branch else ")"))
    if ignored and not discard_ignored:
        problems.append("ignored, worktree-only files would be deleted with the worktrees (git worktree remove does not ask):\n"
                        + "\n".join(f"      {os.path.join(where, entry)}" for where, entry in ignored)
                        + f"\n    move them out first, or re-run with --discard-ignored to delete them: {WORKFLOW_CMD} parallel-teardown {args.phase} --discard-ignored")
    if problems:
        lines = [f"parallel-teardown {args.phase} refused -- nothing was removed:"]
        lines += [f"{i}. {problem}" for i, problem in enumerate(problems, 1)]
        raise SystemExit("\n".join(lines))

    # P40.S8: each repo branch's fate, decided before any removal like the host branch's below:
    # `(repo, delete, keep reason, exists)`. Deleted only when the set created it, it has 0 commits
    # beyond the stamped base_sha and no worktree but the stamped one (removed first) holds it.
    repo_fates = []
    for repo in set_repos:
        rbranch, main = repo["branch"], repo["main"]
        if not rbranch:
            continue
        if main is None:
            repo_fates.append((repo, False, f"its repo's main checkout cannot be found (no registered repo is named {repo['name']})", True))
            continue
        if _git(["rev-parse", "--verify", "--quiet", f"refs/heads/{rbranch}"], cwd=main, check=False).returncode != 0:
            repo_fates.append((repo, False, None, False))
            continue
        holders = [path for path, ref in repo["entries"] if ref == f"refs/heads/{rbranch}"
                   and not (repo["wt"] and os.path.realpath(path) == os.path.realpath(repo["wt"]))]
        ahead = None
        if repo["base_sha"]:
            proc = _git(["rev-list", "--count", f"{repo['base_sha']}..refs/heads/{rbranch}"], cwd=main, check=False)
            ahead = int(proc.stdout.strip()) if proc.returncode == 0 and proc.stdout.strip().isdigit() else None
        if holders:
            reason = f"it is checked out in {holders[0]}"
        elif not repo["created"]:
            reason = "branch_created is false: it existed before the set took it (reused, or adopted with parallel-add-repo --adopt), so it is the operator's"
        elif ahead is None:
            reason = f"its commits beyond the base {repo['base_sha']} could not be counted"
        elif ahead:
            reason = f"it has {ahead} commit(s) beyond its base {repo['base']} ({repo['base_sha'][:12]})"
        else:
            reason = None
        repo_fates.append((repo, reason is None, reason, True))

    # The host branch's fate is decided before any removal (its commits do not change).
    delete_host_branch, keep_reason = False, None
    host_branch_exists = bool(host_branch) and host_git and _git(
        ["rev-parse", "--verify", "--quiet", f"refs/heads/{host_branch}"], cwd=host, check=False).returncode == 0
    if host_branch_exists:
        holders = [path for path, ref in _worktree_entries(cwd=host) if ref == f"refs/heads/{host_branch}"
                   and not (host_wt and os.path.realpath(path) == os.path.realpath(host_wt))]
        ahead = None
        if base_sha:
            proc = _git(["rev-list", "--count", f"{base_sha}..refs/heads/{host_branch}"], cwd=host, check=False)
            ahead = int(proc.stdout.strip()) if proc.returncode == 0 and proc.stdout.strip().isdigit() else None
        if holders:
            keep_reason = f"it is checked out in {holders[0]}"
        elif not created:
            keep_reason = "it existed before parallel-start, which reused it"
        elif ahead is None:
            keep_reason = f"its commits beyond the base {base_sha} could not be counted"
        elif ahead:
            keep_reason = f"it has {ahead} commit(s) beyond its base {execution.get('host_base')} ({base_sha[:12]})"
        else:
            delete_host_branch = True

    # 2-5. The removals, nested half first. Each entry: (label, git args, cwd). A worktree already
    # gone from disk but still registered is pruned instead, before the branches: a stale
    # registration still holds its branch, so `branch -D`/`-d` would refuse.
    def registered(repo, path):
        return any(os.path.realpath(p) == os.path.realpath(path) for p, _ref in _worktree_entries(cwd=repo))

    steps = []
    for repo in set_repos:  # P40.S8: the repo worktrees first, each against its repo's main checkout
        if not repo["wt"] or repo["main"] is None:
            continue
        if repo["live"]:
            steps.append((f"repo {repo['name']} worktree {repo['wt']}", ["worktree", "remove", repo["wt"]], repo["main"]))
        elif registered(repo["main"], repo["wt"]):
            steps.append((f"the stale registration of {repo['wt']} (git worktree prune in {repo['main']})", ["worktree", "prune"], repo["main"]))
    if nested_live:
        steps.append((f"nested worktree {nested_wt}", ["worktree", "remove", str(nested_wt)], ROOT))
    elif nested_wt and registered(ROOT, nested_wt):
        steps.append((f"the stale registration of {nested_wt} (git worktree prune in {ROOT})", ["worktree", "prune"], ROOT))
    if host_live:
        steps.append((f"host worktree {host_wt}", ["worktree", "remove", str(host_wt)], host))
    elif host_wt and host_git and registered(host, host_wt):
        steps.append((f"the stale registration of {host_wt} (git worktree prune in {host})", ["worktree", "prune"], host))
    for repo, delete, _reason, _exists in repo_fates:
        if delete:
            steps.append((f"repo {repo['name']} branch {repo['branch']} (created for the set, no commits beyond its base)",
                          ["branch", "-D", repo["branch"]], repo["main"]))
    if delete_host_branch:
        steps.append((f"host branch {host_branch} (created by parallel-start, no commits beyond its base)",
                      ["branch", "-D", host_branch], host))
    if branch_exists:
        steps.append((f"branch {branch}", ["branch", "-d", branch], ROOT))  # -d refuses an unmerged branch: a free second check

    def command(git_args, cwd):
        return f"git -C {q(str(cwd))} " + " ".join(q(part) for part in git_args)

    null_fields = "execution.worktree and execution.host_worktree"
    repo_fields = [f"execution.repos.{repo['name']}.worktree" for repo in set_repos if repo["wt"]]
    if repo_fields:  # P40.S8: a set's repo worktrees are nulled with the host keys
        null_fields = ", ".join(["execution.worktree", "execution.host_worktree", *repo_fields[:-1]]) + f" and {repo_fields[-1]}"
    removed = []
    for i, (label, git_args, cwd) in enumerate(steps):
        proc = _git(git_args, cwd=cwd, check=False)
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip() or f"exit {proc.returncode}"
            done = "".join(f"\nremoved {item}" for item in removed) or "\nnothing was removed yet"
            rest = "\n".join(f"  {command(a, c)}" for _l, a, c in steps[i:])
            raise SystemExit(
                f"{command(git_args, cwd)} failed: {detail}{done}\n"
                f"fix the cause, then re-run {WORKFLOW_CMD} parallel-teardown {args.phase} (it resumes), or finish by hand, in this order:\n{rest}\n"
                f"  then set {null_fields} to null in {shown(pdir)}/phase.json")
        removed.append(label)

    pruned = []  # a registration a successful `worktree remove` still left behind
    left = [(repo["main"], repo["wt"]) for repo in set_repos if repo["main"] is not None]
    for repo, path in (*left, (ROOT, nested_wt), (host, host_wt)):
        if not path or (repo is host and not host_git):
            continue
        if registered(repo, path):
            _git(["worktree", "prune"], cwd=repo, check=False)
            pruned.append(str(repo))

    data["execution"]["worktree"] = None
    data["execution"]["host_worktree"] = None
    stamped_repos = data["execution"].get("repos")
    for value in (stamped_repos.values() if isinstance(stamped_repos, dict) else ()):
        if isinstance(value, dict):
            value["worktree"] = None
    write_json(pdir / "phase.json", data)
    event = {"repos": [repo["name"] for repo in set_repos]} if set_repos else {}
    append_event("phase_parallel_torndown", phase=args.phase, branch=branch, host_branch=host_branch, **event)
    rebuild_index_and_state()
    print(f"phase {args.phase} parallel checkout pair retired (nested install)")
    for item in removed:
        print(f"removed {item}")
    if not removed:
        print("nothing to remove (both worktrees and the branch were already gone)")
    for repo in pruned:
        print(f"pruned a stale worktree registration in {repo}")
    if ignored:
        print(f"deleted {len(ignored)} ignored, worktree-only path(s) with the worktrees (--discard-ignored)")
    kept_repo_branch = False
    for repo, delete, reason, exists in repo_fates:  # P40.S8
        if delete:
            continue
        if exists:
            kept_repo_branch = True
            print(f"kept repo {repo['name']}'s branch {repo['branch']}: {reason}")
        else:
            print(f"repo {repo['name']}'s branch {repo['branch']} is already gone; nothing to keep")
    if kept_repo_branch:
        print(f"each repo branch follows its repo's own custom (nested-convention --repo <name>): integrate it there; "
              f"the engine pushed, opened and merged nothing")
    if not host_branch:
        print("no host branch: the host worktree was detached (an explain phase), so there is no branch to keep or delete")
    if host_branch and not delete_host_branch:
        if host_branch_exists:
            print(f"kept host branch {host_branch}: {keep_reason}")
            print(f"the host side follows the host's own custom (nested-convention): the branch is yours for the PR; "
                  f"the engine pushed, opened and merged nothing")
        else:
            print(f"host branch {host_branch} is already gone; nothing to keep")
    print(f"execution.worktree=null, execution.host_worktree=null; mode/branch and host_branch/host_base/host_base_sha/"
          f"host_branch_created/base_branch kept as history (branch={branch}, host_branch={host_branch or '- (detached)'})")
    if set_repos:
        print(f"execution.repos.<name>.worktree=null for {', '.join(repo['name'] for repo in set_repos)}; branch/base/base_sha/branch_created "
              f"kept as history")
    print("phase.json changed -- commit it in the nested repo with the rest of the merge cleanup")


def _gate_exemption(phase_id: str, main_side: str, branch_ref: str) -> tuple:
    """(exempt, detail) for the quiet point's checked exemption (v86, §9.2).

    Reads `git diff --name-status <merge-base> <branch_ref>` -- what merging the branch into the
    default side would bring -- and is exempt only when every path is inside the phase's own folder,
    one of the STAMP_WORKS_FILES (generated, regenerated by parallel-merge-finish; events.jsonl merges
    as union), or ADDED under one of GATE_EXEMPT_ADDED_PREFIXES. `detail` is the path count when exempt, else
    the first offending path (or why git could not answer: then nothing is exempt)."""
    base = _git(["merge-base", main_side, branch_ref], check=False)
    if base.returncode != 0 or not base.stdout.strip():
        return False, f"(no merge-base between {main_side} and {branch_ref})"
    proc = _git(["diff", "--name-status", "--no-renames", "-z", base.stdout.strip(), branch_ref], check=False)
    if proc.returncode != 0:
        return False, f"(git diff {base.stdout.strip()[:12]}..{branch_ref} failed)"
    prefix = _repo_prefix()
    own = f"works/phases/active/{phase_id}/"
    fields = [f for f in proc.stdout.split("\0") if f]
    count = 0
    for status, path in zip(fields[0::2], fields[1::2]):
        count += 1
        rel = path[len(prefix):] if prefix and path.startswith(prefix) else (path if not prefix else None)
        if rel is not None and (rel.startswith(own) or rel in STAMP_WORKS_FILES
                                or (status == "A" and rel.startswith(GATE_EXEMPT_ADDED_PREFIXES))):
            continue
        return False, f"{path} ({status})"
    return True, f"{count} path{'' if count == 1 else 's'}"


def parallel_gate(args: argparse.Namespace) -> None:
    """The quiet-point gate: may this parallel phase's branch be merged into the default stream now?

    Two independent questions, both read at a git ref so no checkout has to be switched:

    * **branch side** -- the phase is `done` with a `pass` review *on its own branch*. Main's copy
      is stale before the merge, so it is never trusted here.
    * **main side** -- the default stream is quiet: every non-parallel active phase is `planned` or
      `done`. Merging into a live phase is what this gate exists to prevent. v86: a busy default
      stream is skipped when the branch's diff since its merge-base with the default side touches
      only its own phase folder, the generated works/ files, added deferred jobs and added agenda
      items (`_gate_exemption`, printed as `exemption=`): such a merge cannot collide with live work.

    Read-only and CI-shaped: `GATE OPEN` + exit 0, or `GATE CLOSED` + numbered reasons + exit 1.
    In a nested install (P35) both sides are read in the nested repo, which owns the state.
    """
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    execution = phase_execution(data)
    branch_ref = args.branch_ref or (execution or {}).get("branch")
    if not branch_ref:
        raise SystemExit(
            f"phase {args.phase} carries no parallel execution block in this checkout; "
            f"pass --branch-ref <ref> to name the phase branch explicitly")
    _require_git_repo()
    reasons: list = []
    notes: list = []
    print(f"phase={args.phase}")
    print(f"branch_ref={branch_ref}")

    branch_data = _phase_json_at_ref(branch_ref, args.phase)
    if branch_data is None:
        reasons.append(
            f"cannot read works/phases/active/{args.phase}/phase.json at {branch_ref} "
            f"(unknown ref, or the phase folder does not exist there)")
    else:
        branch_status = branch_data.get("status")
        branch_review = (branch_data.get("review") or {}).get("status")
        print(f"branch_phase_status={branch_status}")
        print(f"branch_review={branch_review}")
        if branch_status != "done":
            reasons.append(f"phase {args.phase} is {branch_status!r} on {branch_ref}, not 'done'; finish its slices and record the review first")
        if branch_review != "pass":
            reasons.append(f"phase {args.phase} review is {branch_review!r} on {branch_ref}, not 'pass'; record a passing review with review-phase on the branch")

    if args.main_ref:
        main_phases = _phases_at_ref(args.main_ref)
        if main_phases is None:
            reasons.append(f"cannot read the default stream's phase state at {args.main_ref} (unknown ref?)")
            main_phases = []
        source = main_side = args.main_ref
    else:
        # Without --main-ref the working tree stands in for main -- unless it IS the phase
        # branch: checked out by name (its worktree) or detached at its tip (how CI checks out a
        # PR). Then (v42) the local default branch stands in instead, so the gate can run from
        # the worktree before the session exits it; only when no default branch resolves is the
        # operator asked for --main-ref. Sharing a tip with main is normal right after the stamp
        # and does NOT count.
        current = git_current_branch()
        on_phase_branch = current is not None and current in {(execution or {}).get("branch"), branch_ref}
        detached_at_tip = current is None and _git(["rev-parse", "HEAD"], check=False).stdout.strip() == _git(["rev-parse", branch_ref], check=False).stdout.strip() != ""
        if on_phase_branch or detached_at_tip:
            default = _default_branch()
            if not default:
                raise SystemExit(
                    f"this checkout is the phase branch {branch_ref} itself and no default branch (origin/HEAD, main, master) resolves, "
                    f"so nothing can stand in for the default stream; pass --main-ref <ref> (e.g. --main-ref origin/main)")
            main_phases = _phases_at_ref(default)
            if main_phases is None:
                reasons.append(f"cannot read the default stream's phase state at {default} (unknown ref?)")
                main_phases = []
            source = f"{default} (local default branch; this checkout is the phase branch)"
            main_side = default
        else:
            main_phases = all_active_phases()
            source = "working tree"
            main_side = "HEAD"  # the working tree's own history: what a merge here would merge into
    print(f"main_state_source={source}")
    busy = []
    for p in main_phases:
        if p.get("id") == args.phase or phase_execution(p):
            continue  # parallel phases run on their own stream; they do not make main busy
        if p.get("status") in BUSY_PHASE_STATUSES:
            busy.append(f"the default stream is not quiet: phase {p.get('id')} is {p.get('status')!r} (finish or park it, then re-run the gate)")
    # v86 (§9.2): the checked exemption. Only the busy-default-stream reasons can be dropped, and only
    # when git shows the branch touches nothing the default stream could be holding; the branch-side
    # reasons (done, pass) never are. Decided by the diff, never by what kind of phase it is.
    exempt, detail = _gate_exemption(args.phase, main_side, branch_ref)
    print(f"exemption=phase-folder-only ({detail})" if exempt else f"exemption=none: {detail}")
    if busy and exempt:
        notes.append(f"{len(busy)} busy default-stream phase(s) skipped: the branch touches only its own phase folder, the generated works/ files"
                     + f" and added {' and '.join(GATE_EXEMPT_ADDED_PREFIXES)} paths, so its merge cannot collide with them")
    else:
        reasons.extend(busy)
    for n in notes:
        print(f"note: {n}")

    if reasons:
        print("GATE CLOSED")
        for i, reason in enumerate(reasons, 1):
            print(f"{i}. {reason}")
        raise SystemExit(1)
    print("GATE OPEN")
    print(f"next: merge {branch_ref} into the default stream, then run: {WORKFLOW_CMD} parallel-merge-finish")


def parallel_merge_finish(args: argparse.Namespace) -> None:
    """Run on the default stream right after a phase branch's merge: regenerate, then report what is left.

    The generated files (`works/state.json`, `works/index.json`, `works/backlog.md`,
    `works/deferred.md`, `works/agenda.md`, `docs/current/*.md`) are derived, never authored, so a merge conflict in
    them is resolved by taking either side and regenerating here -- which is why parallel mode
    needs no custom git merge driver (a driver would need per-clone `git config` and would not
    travel with the repo). Makes no commit: the regenerated files belong to the merge commit's
    cleanup, which the orchestrator owns. In a nested install (P35) it runs in the nested repo,
    where `phase/...` was merged (`git -C workflow merge`), and never touches the host repo: the
    host branch is integrated by the host's own custom, never by the engine.
    """
    git_ok = _git_available()
    if git_ok and _git(["rev-parse", "-q", "--verify", "MERGE_HEAD"], check=False).returncode == 0:
        raise SystemExit(
            "this checkout is mid-merge (MERGE_HEAD exists) -- finish the merge first, then re-run.\n"
            f"generated files ({', '.join(GENERATED_FILES)}) are regenerated by this command, so resolve any conflict in them by taking EITHER side.\n"
            f"then: {WORKFLOW_CMD} parallel-merge-finish")
    phases = all_active_phases()
    stream = current_stream(phases)
    if stream:
        print(f"warning: this checkout is on parallel stream {stream}; parallel-merge-finish belongs on the default stream, after the merge")
    rebuild_index_and_state()
    print(f"regenerated from the merged folders: {', '.join(GENERATED_FILES)}")
    for p in all_active_phases():
        execution = phase_execution(p)
        if not execution or p.get("status") != "done" or not _parallel_branch_merged(execution, git_ok):
            continue
        if execution.get("worktree") or (git_ok and execution.get("branch") and _branch_exists(execution["branch"])):
            print(f"- {p['id']} is merged: retire its branch + worktree: {WORKFLOW_CMD} parallel-teardown {p['id']}")
    print("no commit made -- commit the regenerated files with the merge cleanup")


def _parallel_verdict(phase_id: str, status, review, slices, merged, branch_gone: bool, own_stream: bool) -> str:
    """One line saying where a parallel phase stands, and what the operator does next.

    `merged` is None when the answer is unknown (this checkout is the phase's own stream, so it
    trivially contains its own branch); `branch_gone` means the branch was deleted, which implies
    the phase was merged first -- `parallel-teardown` refuses an unmerged branch.
    """
    return _parallel_verdict_pair(phase_id, status, review, slices, merged, branch_gone, own_stream)[1]


def _parallel_verdict_pair(phase_id: str, status, review, slices, merged, branch_gone: bool, own_stream: bool) -> tuple:
    """`(short, long)`: the cell `## Streams` shows, and the sentence `parallel-status` prints. One
    decision tree, so the dashboard and the command can never disagree about where a phase stands."""
    if status is None:
        return ("unknown", "unknown -- neither the phase branch nor a local copy could be read")
    slices = slices or []
    total = len(slices)
    done = sum(1 for s in slices if s.get("status") == "done")
    open_slice = next((s.get("id") for s in slices if s.get("status") != "done"), None)
    integrated = merged is True or branch_gone
    if status == "done" and review == "pass":
        if integrated:
            if not branch_gone:
                return ("merged", f"merged -- retire the branch and worktree: parallel-teardown {phase_id}")
            return ("torn down", f"merged and torn down -- nothing left but archiving ({phase_id} is archivable)")
        return ("ready to merge",
                f"ready to merge -- check the quiet point first: parallel-gate {phase_id} (from the default stream)")
    if status == "done":
        return ("review not passed", f"slices done but review is {review!r} -- record a passing review on its branch (review-phase {phase_id} --verdict pass)")
    if status == "pending":
        return ("pending", "waiting on the operator (phase is pending [~]) -- it halts only its own stream")
    if status == "blocked":
        return ("blocked", "blocked on its own stream -- resolve the impediment there")
    where = " on this checkout's own stream" if own_stream else " on its branch"
    tail = f"; current slice {open_slice}" if open_slice else ""
    return (f"in flight {done}/{total}", f"in flight{where} -- {done}/{total} slices done{tail}")


def parallel_status(args: argparse.Namespace) -> None:
    """Read-only cross-stream view: this checkout's pointer plus every parallel phase's real state.

    A parallel phase's slice progress lives on its own branch, so the default stream's copy of it
    stands still until the merge (`works/backlog.md` reads it from the branch too). This reads each phase's truth straight out of
    its branch with `git show` / `git ls-tree` -- no checkout switching, no fetching, and (unlike
    every other command here) no rebuild: nothing on disk is written.
    """
    phases = all_active_phases()
    stream = current_stream(phases)
    # The same in-memory pointer computation `rebuild_index_and_state` does, minus the writes.
    selectable = stream_phases(phases, stream)
    current_phase, current_slice, next_slice = resolve_current(selectable)
    waiting = operator_wait_target(selectable, current_phase, current_slice)
    print(f"stream={stream}" if stream else "stream=default")
    print(f"current_phase={current_phase or 'none'}")
    print(f"current_slice={current_slice or 'none'}")
    print(f"next_slice={next_slice or 'none'}")
    print(f"waiting_on_operator={waiting or 'none'}")
    print("(the pointer above is this stream's; each section below is read from that phase's own branch)")

    pinned = [p["id"] for p in phases if phase_pinned(p)]
    if pinned:
        print(f"pinned_to_default={','.join(pinned)}")
    parallel = [(p, phase_execution(p)) for p in phases if phase_execution(p)]
    if not parallel:
        print("no phase is in its own worktree right now -- every active phase runs on the default stream, which is where a phase runs unless asked otherwise")
        print(f"to run one in its own worktree instead, ask for it: {WORKFLOW_CMD} parallel-start <P>{NESTED_HOST_BRANCH_ARG}")
        return
    if not _git_available():
        raise SystemExit(
            "parallel-status reads each phase branch with git, but this workspace is not inside a git work tree "
            f"({len(parallel)} phase(s) are stamped for parallel execution)")
    print(f"parallel_phases={len(parallel)}")

    for phase, execution in parallel:
        pid = phase.get("id")
        branch = execution.get("branch")
        own_stream = bool(branch) and branch == stream
        note = None
        data = slices = None
        if own_stream:  # our own working tree is fresher than our own last commit
            source = "working tree (this checkout's own stream)"
            data, slices = phase, phase.get("slices", [])
        else:
            ref = None
            for candidate in ([branch, f"origin/{branch}"] if branch else []):
                data = _phase_json_at_ref(candidate, pid)
                if data is not None:
                    ref = candidate
                    break
            if ref:
                source = f"branch {ref}"
                slices = _slices_at_ref(ref, pid) or []
            else:  # torn down after the merge, or a clone that never fetched the branch
                source = "local copy"
                note = (f"(local copy; branch not found{': ' + branch if branch else ''}) -- "
                        f"merged and torn down, or never fetched in this clone")
                data, slices = phase, phase.get("slices", [])
        branch_gone = bool(branch) and not _branch_exists(branch)
        merged = None  # unknowable from the phase's own stream: HEAD *is* the branch there
        if branch and not branch_gone and not own_stream:
            merged = _git(["merge-base", "--is-ancestor", branch, "HEAD"], check=False).returncode == 0
        status = (data or {}).get("status")
        review = ((data or {}).get("review") or {}).get("status")
        worktree = execution.get("worktree")
        print()
        print(f"== {pid}: {phase.get('name', '')} ==")
        print(f"  branch={branch or '- (stamped parallel with no branch; fix phase.json)'}")
        print(f"  worktree={worktree or '- (plain clone, or already torn down)'}")
        if NESTED is not None:  # P35: the host half of the pair, as stamped at parallel-start
            detached = "host_branch" in execution and execution.get("host_branch") is None and "host_worktree" in execution
            if execution.get("host_branch") or detached:
                if detached:  # v86 (§9.4): an explain phase's pair
                    print("  host_branch=- (detached host worktree)")
                else:
                    print(f"  host_branch={execution['host_branch']}" + (" (created by parallel-start)" if execution.get("host_branch_created") else " (reused)"))
                print(f"  host_base={execution.get('host_base') or '-'} ({execution.get('host_base_sha') or '-'})")
                print(f"  host_worktree={execution.get('host_worktree') or '- (already torn down)'}")
            else:
                print("  host_branch=- (no host half stamped: an execution block written at root, before the nested pair)")
            # P40.F1: the set's repos come from the copy `data` came from -- a mid-phase `parallel-add-repo` commits its stamp
            # on the phase branch only, so the default stream's own copy lacks it until the merge. The local block is the
            # fallback only when no other copy was read (or the copy carries no execution block).
            copy_execution = data.get("execution") if isinstance(data, dict) else None
            set_repos = (copy_execution if isinstance(copy_execution, dict) else execution).get("repos")
            if isinstance(set_repos, dict):  # P40.S6: the worktree set's repos, one line each
                for name, value in set_repos.items():
                    value = value if isinstance(value, dict) else {}
                    # branch_created=false is all the stamp records of a branch that pre-existed: parallel-add-repo's reuse of an
                    # existing branch and --adopt of an existing worktree stamp identically, so the label names both
                    print(f"  repo {name}: branch={value.get('branch') or '-'} ({'created' if value.get('branch_created') else 'reused or adopted'}) "
                          f"base={value.get('base') or '-'} ({value.get('base_sha') or '-'}) worktree={value.get('worktree') or '- (torn down)'}")
        print(f"  source={source}")
        if note:
            print(f"  note: {note}")
        print(f"  status={status} review={review}" + ("" if merged is None else f" merged_into_HEAD={str(merged).lower()}"))
        if slices:
            width = max(len(str(s.get("id", ""))) for s in slices)
            print(f"  slices ({sum(1 for s in slices if s.get('status') == 'done')}/{len(slices)} done):")
            for s in slices:
                name = str(s.get("name", "")).replace("\n", " ")
                print(f"    [{status_box(s.get('status'))}] {str(s.get('id', '')):<{width}}  {str(s.get('status', '')):<17} {name}")
        else:
            print("  slices: none readable at that source")
        print(f"  verdict: {_parallel_verdict(pid, status, review, slices, merged, branch_gone, own_stream)}")


def merge_ready_line(stream, phases: list):
    """`merge_ready=<P>:<branch>, ...` on the default stream (v86, §9.5): every stamped phase whose
    branch copy is `done` with a `pass` review while this stream's copy is not `done` yet -- an
    integration nobody has run (an explain run that could not merge by itself leaves it so). Read at
    the branch ref, never trusted from the stale local copy. None on a phase stream or without git."""
    if stream or not _git_available():
        return None
    ready = []
    for p in phases:
        execution = phase_execution(p)
        branch = (execution or {}).get("branch")
        if not branch or p.get("status") == "done":
            continue
        branch_data = _phase_json_at_ref(branch, p["id"])
        if isinstance(branch_data, dict) and branch_data.get("status") == "done" and (branch_data.get("review") or {}).get("status") == "pass":
            ready.append(f"{p['id']}:{branch}")
    lines = []
    if ready:
        lines.append(f"merge_ready={', '.join(ready)} (done with a passing review on its branch, not merged here: "
                     f"whoever drives this stream merges it at a slice boundary, past {WORKFLOW_CMD} parallel-gate <P>)")
    return "\n".join(lines) or None


def explain_unit_lines(phase_id) -> list:
    """`explain_unit=<unit>` for an explain phase (v86), so the orchestrator picks the document, book
    or chapter branch of the explain references without re-reading intent.md; nothing otherwise."""
    pdir = ACTIVE / phase_id if phase_id else None
    unit = explain_unit(pdir) if pdir is not None and pdir.is_dir() else None
    return [f"explain_unit={unit}"] if unit else []


def parallel_start_hint(state: dict, index: dict) -> str:
    """The proactive opt-in suggestion for `next`, or None (restored in v43).

    A worktree is opt-in again, so the hint fires only where one actually buys something: on
    the default stream, when the current phase is in_progress and a LATER default-stream phase
    is still `planned` -- exactly the moment a second phase would otherwise queue behind a live
    one. Suggestion only, never a default: the ordinary one-phase-at-a-time run stays silent,
    and so does a worktree checkout. v42's trigger (every planned phase, because the worktree
    was the default) is gone with the default that justified it. In a nested install (P35) the
    printed command also carries `--host-branch <name>`, which the operator names.
    """
    if state.get("stream"):
        return None
    current = state.get("current_phase")
    phases = index.get("active_phases", [])  # already ordered by phase order
    ids = [p.get("id") for p in phases]
    if current not in ids:
        return None
    cur = phases[ids.index(current)]
    if cur.get("status") != "in_progress":
        return None
    waiting = next((p for p in phases[ids.index(current) + 1:] if p.get("status") == "planned" and not p.get("execution")), None)
    if not waiting:
        return None
    return (f"hint: {waiting['id']} is waiting behind {current} -- it can run in parallel on its own branch: "
            f"{WORKFLOW_CMD} parallel-start {waiting['id']}{NESTED_HOST_BRANCH_ARG}")


# ---------------------------------------------------------------------------
# phase scope: the phase's boundary, read from git (v41)
#
# The review (and a fidelity slice) re-runs the regression checklist only INSIDE the phase's
# boundary -- the product files the phase changed, the surfaces they feed. This command makes
# that boundary a mechanical read instead of a guess: creation commit, base..head range, files.
# Read-only and advisory everywhere: without git it explains itself and exits 0.
# ---------------------------------------------------------------------------

EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"  # `git hash-object -t tree /dev/null`
PRODUCT_PATHSPEC = [".", ":!works", ":!docs"]  # the product: everything but the workflow state and the docs
SCOPE_HINT = ("boundary: these files are what the phase changed; a checklist line whose surface "
              "none of them feed is outside this phase's boundary")


def _find_phase_dir(phase_id: str):
    """`(dir, archived)` for an active or archived phase; SystemExit when neither holds it.

    `require_phase` knows only `active/` on purpose (every state transition is an active-phase
    operation); the boundary of a done, archived phase is still a fair question -- a QA phase
    looks back at it -- so this lookup covers both."""
    if (ACTIVE / phase_id / "phase.json").exists():
        return ACTIVE / phase_id, False
    hits = []
    if ARCHIVED.exists():
        for d in sorted(ARCHIVED.iterdir()):
            pj = d / "phase.json"
            if not pj.is_file():
                continue
            try:
                if read_json(pj).get("id") == phase_id:
                    hits.append(d)
            except Exception:  # noqa: BLE001 - an unreadable archive entry is skipped, never fatal
                continue
    if hits:
        return hits[-1], True
    raise SystemExit(f"phase not found (active or archived): {phase_id}")


def _phase_creation_commit(phase_id: str, pdir: Path, archived: bool):
    """The sha that added the phase's `phase.json`, or None (uncommitted phase, or a shallow clone).

    Pathspecs are cwd-relative and `_git` runs at the workspace root, so no repo prefix here.
    Archiving is a pure rename, so `--follow` on the archived path walks back to the true
    creation commit; the plain active path is the fallback (git keeps a deleted path's history)."""
    active_rel = f"works/phases/active/{phase_id}/phase.json"
    if not archived:
        out = _git(["log", "--diff-filter=A", "--format=%H", "--", active_rel], check=False).stdout.split()
        return out[0] if out else None  # newest: right even if the id was ever reused
    archived_rel = f"{pdir.relative_to(ROOT).as_posix()}/phase.json"
    out = _git(["log", "--follow", "--diff-filter=A", "--format=%H", "--", archived_rel], check=False).stdout.split()
    if not out:
        out = _git(["log", "--diff-filter=A", "--format=%H", "--", active_rel], check=False).stdout.split()
    return out[-1] if out else None  # oldest: the creation, not the archive move


def _default_branch():
    """The default stream's branch: origin/HEAD's target, else a local main/master, else None."""
    proc = _git(["symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD"], check=False)
    if proc.returncode == 0 and proc.stdout.strip():
        return proc.stdout.strip()
    for cand in ("main", "master"):
        if _branch_exists(cand):
            return cand
    return None


def _diff_product_files(base: str, head: str, cwd=None, pathspec=PRODUCT_PATHSPEC) -> list:
    """`[{status, path[, from]}]` for the product files that differ between two commits."""
    proc = _git(["diff", "--name-status", "--relative", "-M", base, head, "--", *pathspec], cwd=cwd, check=False)
    files = []
    for line in proc.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        status = parts[0][:1]
        if status in ("R", "C") and len(parts) >= 3:
            files.append({"status": status, "path": parts[2], "from": parts[1]})
        else:
            files.append({"status": status, "path": parts[-1]})
    return files


def _status_product_files(cwd=None, pathspec=PRODUCT_PATHSPEC) -> list:
    """`[{status, path}]` for the uncommitted product changes in this checkout (untracked included).
    Porcelain paths are repo-root-relative, so the prefix of the directory measured is stripped."""
    proc = _git(["status", "--porcelain", "--untracked-files=all", "--", *pathspec], cwd=cwd, check=False)
    prefix = _repo_prefix() if cwd is None else _git(["rev-parse", "--show-prefix"], cwd=cwd, check=False).stdout.strip()
    files = []
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        code, path = line[:2], line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        if prefix and path.startswith(prefix):
            path = path[len(prefix):]
        status = "A" if code == "??" else (code.strip()[:1] or "M")
        files.append({"status": status, "path": path})
    return files


# ---------------------------------------------------------------------------
# P40: per-repo anchors and the base rule. A nested install's phase range is read from the product
# repo(s) the nested repo never sees: the host (single-repo) or each registered repo (multi-repo).
# ---------------------------------------------------------------------------

NOT_IN_SET = "not in this worktree set"


def _in_worktree_set() -> bool:
    """P40: True when this engine runs inside a parallel set -- HOST_ROOT is a host worktree, not the
    main host checkout (nested only; both resolved, since git may print a symlink-free path)."""
    if HOST_ROOT is None or MAIN_HOST is None:
        return False
    return os.path.realpath(str(HOST_ROOT)) != os.path.realpath(str(MAIN_HOST))


def _phase_repo_path(repo: dict, phase_data: dict):
    """`(path, None)` for where phase `phase_data` reads registered repo `repo`, or `(None, why)` when
    it cannot be read there. THE one resolver every per-repo anchor and scope read goes through. On
    the default stream it is the registry path under the main host checkout (`nested_repo_path`),
    guarded by `_git_work_tree_root` (on a plain dir `git -C` answers for the host). Inside a worktree
    set (P40.S6, S2 §17) it is the set's repo worktree, `HOST_ROOT / path`, when that is its own work
    tree root; otherwise the repo is NOT IN THIS SET and is skipped -- never read from the main
    checkout, whose HEAD and working tree are another stream's. `phase_data` is unused."""
    if _in_worktree_set():
        path = HOST_ROOT / repo["path"]
        if _git_work_tree_root(path):
            return path, None
        return None, f"{NOT_IN_SET} (its main checkout {nested_repo_path(repo)} is another stream's working state)"
    path = nested_repo_path(repo)
    if not path.exists():
        return None, f"{repo['path']}/ is missing from the host"
    if not _git_work_tree_root(path):
        return None, f"{repo['path']}/ is not a git work tree root"
    return path, None


def _repo_current_branch(path: Path):
    """The branch checked out in `path`, or None (detached HEAD, or git cannot say)."""
    proc = _git(["symbolic-ref", "-q", "--short", "HEAD"], cwd=path, check=False)
    return proc.stdout.strip() if proc.returncode == 0 and proc.stdout.strip() else None


def _is_ancestor(path: Path, older: str, newer: str) -> bool:
    return _git(["merge-base", "--is-ancestor", older, newer], cwd=path, check=False).returncode == 0


def _repo_default_branch(path: Path, configured=None):
    """D, the repo's integration branch NAME: the registry's `default_branch`, else `origin/HEAD`'s
    target, else a local `main`/`master`, else None."""
    if configured:
        return configured
    proc = _git(["symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD"], cwd=path, check=False)
    target = proc.stdout.strip() if proc.returncode == 0 else ""
    if target.startswith("origin/") and len(target) > len("origin/"):
        return target[len("origin/"):]
    for cand in ("main", "master"):
        if _git(["rev-parse", "--verify", "--quiet", f"refs/heads/{cand}"], cwd=path, check=False).returncode == 0:
            return cand
    return None


def _default_merge_base(path: Path, name: str, head: str):
    """merge-base(D, HEAD), D read as `origin/<name>` and as the local `<name>` (whichever exist):
    the newest of the two merge-bases, so a rebase onto a teammate's pushed commits and one onto a
    local-only default both count. None when neither ref exists or the histories are unrelated."""
    best = None
    for ref in (f"refs/remotes/origin/{name}", f"refs/heads/{name}"):
        if not _rev_parse(ref, cwd=path):
            continue
        proc = _git(["merge-base", ref, head], cwd=path, check=False)
        mb = proc.stdout.strip() if proc.returncode == 0 else ""
        if mb and (best is None or (mb != best and _is_ancestor(path, best, mb))):
            best = mb
    return best


def _patch_ids(path: Path, *revs: str) -> list:
    """`[(commit, patch-id)]`, newest first, for `git log -p <revs>` (merges skipped), via
    `git patch-id --stable`. Bytes in and out: a binary or non-UTF-8 diff must not break the read."""
    try:
        log = subprocess.run(["git", "log", "-p", "--no-color", "--no-ext-diff", "--no-merges", "--format=commit %H", *revs],
                             cwd=str(path), capture_output=True, timeout=120)
        if log.returncode != 0 or not log.stdout:
            return []
        pid = subprocess.run(["git", "patch-id", "--stable"], cwd=str(path), input=log.stdout, capture_output=True, timeout=120)
    except Exception:  # noqa: BLE001 - no patch-id means no recovered copy: the rule falls back to its note
        return []
    pairs = []
    for line in pid.stdout.decode("utf-8", "replace").splitlines():
        parts = line.split()
        if len(parts) == 2:
            pairs.append((parts[1], parts[0]))
    return pairs


def resolve_repo_base(path: Path, created, default_branch=None, label: str = "created", branch=None, hint: str = "--base <sha>") -> dict:
    """The base rule (P40 S1 §7; answers D35): where a repo's phase range starts. Returns
    `{"base", "rule", "kind", "note"}` -- `base` a commit sha, the empty tree, or None (unmeasurable);
    `rule` 1-5 (which step fired); `kind` the text phase scope prints in `base=... (...)`; `note` a
    caveat to print, or None. With D = `_repo_default_branch(path, default_branch)` and
    mb = merge-base(D, HEAD):

    1. `created` null -> the empty tree when the repo now has commits;
    2. no D, or mb == HEAD (the work sits on the default branch) -> `created`;
    3. mb an ancestor of `created` (the branch carried pre-phase commits) -> `created`;
    4. `created` an ancestor of mb (the branch was rebased onto, or merged with, a newer default) -> mb;
    5. neither (a rebase rewrote `created` itself) -> the commit in mb..HEAD whose `patch-id --stable`
       equals `created`'s, else mb with a note. A `created` that is a merge commit (no patch-id) or no
       longer exists (pruned) takes the note path. Never raises."""
    head = _rev_parse("HEAD", cwd=path)
    if not created:
        if head:
            return {"base": EMPTY_TREE, "rule": 1, "kind": f"the empty tree: {label} is null (no commit at phase new)", "note": None}
        return {"base": None, "rule": 1, "kind": None, "note": "no commit at phase new, and still none"}
    commit = _rev_parse(created, cwd=path)
    name = _repo_default_branch(path, default_branch)
    mb = _default_merge_base(path, name, head) if name and head else None
    if commit:
        if mb is None or mb == head:
            who = "host" if label.startswith("host_anchors") else "repo"
            return {"base": commit, "rule": 2, "kind": f"the {who} HEAD at phase new: {label}", "note": None}
        if mb == commit:  # P40.S6: a set's branch cut at (or reused from) its anchor -- rule 3's base, said plainly
            return {"base": commit, "rule": 3, "kind": f"{label}: where the branch leaves {name}", "note": None}
        if _is_ancestor(path, mb, commit):
            return {"base": commit, "rule": 3, "kind": f"{label}; the branch carried pre-phase commits", "note": None}
        if _is_ancestor(path, commit, mb):
            return {"base": mb, "rule": 4, "kind": f"merge-base with {name}: the branch moved past {label} {commit[:7]}, by a rebase onto or a merge of a newer {name}", "note": None}
    elif mb is None:
        return {"base": None, "rule": 5, "kind": None,
                "note": f"{label} {created} is not a commit here (rewritten and pruned?) and there is no default branch to fall back to"}
    if commit:
        own = dict(_patch_ids(path, "-1", commit)).get(commit)
        if own:
            copies = [c for c, p in _patch_ids(path, f"{mb}..{head}") if p == own]
            if copies:
                return {"base": copies[-1], "rule": 5, "kind": f"the rebased copy of {label} {commit[:7]}, matched by patch-id", "note": None}
    return {"base": mb, "rule": 5, "kind": f"merge-base with {name}: {label} {str(created)[:7]} was rewritten",
            "note": f"the phase's base commit was rewritten; the range may include pre-phase commits on {branch or 'HEAD'} -- pass {hint}"}


def _freeze_host_review_base(data: dict) -> None:
    """At a passing review: `host_anchors.review_base` = the base rule's answer, written ONLY when it
    differs from `created` (a rebased branch, D35) -- absent means `created`, so a non-rebased phase's
    phase.json is exactly today's. A stale one from an earlier pass is dropped when it no longer differs."""
    anchors = data.get("host_anchors")
    if HOST_ROOT is None or not isinstance(anchors, dict) or not anchors.get("created") or not _git_available(cwd=HOST_ROOT):
        return
    res = resolve_repo_base(HOST_ROOT, anchors["created"], None, "host_anchors.created")
    if res["base"] and res["rule"] in (4, 5) and res["base"] != EMPTY_TREE:
        anchors["review_base"] = res["base"]
    else:
        anchors.pop("review_base", None)


def _freeze_repo_anchors(data: dict) -> None:
    """At a passing review (multi-repo): per repo holding an anchor, `review_pass` = its HEAD and
    `review_base` = what the base rule resolves now, so both ends freeze (after the branch merges and
    is deleted the rule would otherwise drift). A repo that cannot be read keeps its entry as it is."""
    anchors = data.get("repo_anchors")
    if not isinstance(anchors, dict):
        return
    registry = {r["name"]: r for r in nested_repos()}
    for name, entry in anchors.items():
        repo = registry.get(name)
        if repo is None or not isinstance(entry, dict):
            continue
        path, _why = _phase_repo_path(repo, data)
        if path is None:
            continue
        res = resolve_repo_base(path, entry.get("created"), repo.get("default_branch"), f"repo_anchors.{name}.created")
        entry["review_pass"] = _rev_parse("HEAD", cwd=path)
        entry["review_base"] = res["base"] if res["base"] and res["base"] != EMPTY_TREE else None


def _repo_anchor_problems(p: dict, errors: list, warnings: list) -> None:
    """validate's `repo_anchors` rows (multi-repo only): a malformed block or entry is an error,
    mirroring `host_anchors`; an entry naming an unregistered repo is a warning (glide's P29 has no
    `repo_anchors`, so nothing here can fail its `--update`)."""
    anchors = p.get("repo_anchors")
    if not isinstance(anchors, dict):
        errors.append(f"phase {p['id']} has a non-object repo_anchors block: {anchors!r}")
        return
    registered = {r["name"] for r in nested_repos()}
    for name, entry in anchors.items():
        if not isinstance(entry, dict) or set(entry) != set(REPO_ANCHOR_KEYS):
            got = ", ".join(sorted(entry)) if isinstance(entry, dict) else repr(entry)
            errors.append(f"phase {p['id']} has a malformed repo_anchors.{name} ({got}); expected exactly the keys {', '.join(REPO_ANCHOR_KEYS)}")
        else:
            for key in ("created", "review_pass", "review_base"):
                value = entry[key]
                if value is not None and not (isinstance(value, str) and re.fullmatch(r"[0-9a-f]{7,64}", value)):
                    errors.append(f"phase {p['id']} has invalid repo_anchors.{name}.{key} {value!r}; expected a commit sha of {name} or null")
            if entry["branch"] is not None and not isinstance(entry["branch"], str):
                errors.append(f"phase {p['id']} has invalid repo_anchors.{name}.branch {entry['branch']!r}; expected a branch name or null")
        if name not in registered:
            warnings.append(f"phase {p['id']} holds repo_anchors.{name}, but no registered repo is named {name} -- phase scope skips it (re-register it with: {WORKFLOW_CMD} nested-repos --add <path> --name {name})")


def _phase_review_commit(phase_id: str, base: str, tip: str):
    """The commit in base..tip that recorded the phase's LAST passing review: the first commit of the
    final run of commits whose phase.json says `review.status == "pass"`.

    A done phase's boundary ends where its review was recorded, not at today's HEAD -- otherwise
    every later commit on the stream would leak into it. P52: a reopened phase (`phase reopen`)
    records `changes_requested` after its first pass and passes again after the fix round, so a
    non-pass record resets the run and the second pass ends the range; a phase passed once reads
    exactly as before. A commit whose phase.json cannot be read (the archive move) never resets it."""
    rng = tip if base == EMPTY_TREE else f"{base}..{tip}"
    proc = _git(["log", "--reverse", "--format=%H", rng, "--", f"works/phases/active/{phase_id}/phase.json"], check=False)
    start = None
    for sha in proc.stdout.split():
        data = _phase_json_at_ref(sha, phase_id)
        if not data:
            continue
        if (data.get("review") or {}).get("status") == "pass":
            start = start or sha
        else:
            start = None
    return start


def phase_scope(args: argparse.Namespace) -> None:
    """Read-only: the phase's boundary -- its creation commit, the base..head range and the
    product files that range changed (works/ and docs/ excluded) -- printed for the review and a
    fidelity slice to re-run the regression checklist inside.

    Default stream: base = the creation commit's parent (so a creation commit batched with product
    edits still counts), head = HEAD, or the commit that recorded a passing review on a done phase.
    Parallel mode: base = the merge-base with the default branch, measured on the phase branch.
    Advisory everywhere: no git means one explanatory line and exit 0; an uncommitted phase lists
    the working tree instead; `--base` / `--head` override either end verbatim.
    """
    if getattr(args, "pathspec", False):  # an in-engine caller builds its own Namespace
        _phase_scope_pathspec_only(args)
        return
    if not args.phase:
        raise SystemExit("phase scope: name the phase (phase scope <P>), or print the product pathspec alone with phase scope --pathspec")
    pdir, archived = _find_phase_dir(args.phase)
    data = read_json(pdir / "phase.json")
    spec = product_pathspec()  # at root; the nested readers take theirs from the same function
    out = {"phase": args.phase, "status": data.get("status"), "archived": archived, "mode": "default",
           "creation_commit": None, "base": None, "base_kind": None, "head": None, "head_kind": None,
           "range": None, "commits": 0, "pathspec": spec, "files": [], "uncommitted": [], "notes": [], "hint": SCOPE_HINT}

    def emit(lines):
        if args.json:
            print(json.dumps(out, indent=2, ensure_ascii=False))
        else:
            for ln in lines:
                print(ln)

    header = [f"phase={args.phase} status={data.get('status')} archived={str(archived).lower()}"]
    if NESTED is None and args.repo:
        raise SystemExit("phase scope --repo: refused -- a multi-repo host only; an at-root workspace's repo is its one product repo")
    if NESTED is not None:
        _phase_scope_nested(args, data, out, header, emit)
        return
    if not _git_available():
        out["mode"] = "no-git"
        out["hint"] = "phase scope: no git history readable here -- derive the boundary from the slices' result.md files"
        emit([out["hint"]])
        return

    creation = _phase_creation_commit(args.phase, pdir, archived)
    out["creation_commit"] = creation
    execution = phase_execution(data)
    tip, base, base_kind = "HEAD", None, None
    if args.base:
        base = _rev_parse(args.base)
        if not base:
            raise SystemExit(f"--base {args.base}: not a commit")
        base_kind = f"from --base {args.base}"
    elif execution and execution.get("branch"):
        out["mode"] = "parallel"
        branch = execution["branch"]
        default = _default_branch()
        if default is None:
            out["notes"].append("cannot find the default branch (no origin/HEAD, no main/master) -- measured from the creation commit; pass --base <ref> to narrow")
        else:
            if git_current_branch() == branch:
                ref = "HEAD"
            elif _branch_exists(branch):
                ref = branch
            elif _rev_parse(f"origin/{branch}"):
                ref = f"origin/{branch}"
            else:
                ref = None
                out["notes"].append(f"branch {branch} is gone (merged and torn down?) -- measured on this stream from the creation commit; concurrent default-stream work may appear; pass --base to narrow")
            if ref:
                mb = _git(["merge-base", default, ref], check=False)
                if mb.returncode == 0 and mb.stdout.strip():
                    base, tip, base_kind = mb.stdout.strip(), ref, f"merge-base with {default}"
                    if ref != "HEAD":
                        out["notes"].append(f"read from branch {ref}, not this checkout")
    if base is None:
        if creation is None:
            out["uncommitted"] = _status_product_files(pathspec=spec)
            lines = header + [f"mode={out['mode']}",
                              f"creation_commit=none (works/phases/active/{args.phase}/phase.json has no commit yet -- uncommitted phase, or a shallow clone)",
                              *pathspec_lines(spec),
                              f"uncommitted_product_files={len(out['uncommitted'])} (working tree; works/ and docs/ excluded)"]
            lines += [f"  {f['status']} {f['path']}" for f in out["uncommitted"]]
            lines += [f"note: {n}" for n in out["notes"]] + [SCOPE_HINT]
            emit(lines)
            return
        base = _rev_parse(f"{creation}^")
        if base:
            base_kind = "parent of the creation commit, so that commit's own product edits count"
        else:
            base, base_kind = EMPTY_TREE, "the empty tree: the creation commit has no readable parent (root commit, or a shallow clone)"
    if args.head:
        head = _rev_parse(args.head)
        if not head:
            raise SystemExit(f"--head {args.head}: not a commit")
        head_kind = f"from --head {args.head}"
    else:
        head, head_kind = None, None
        if (data.get("review") or {}).get("status") == "pass":
            head = _phase_review_commit(args.phase, base, tip)
            if head:
                head_kind = "the commit that recorded review.status=pass; pass --head HEAD to read to the tip"
        if not head:
            head, head_kind = _rev_parse(tip), f"the tip of {tip}"
    if not head:
        raise SystemExit(f"cannot resolve {tip} to a commit")
    rng = head if base == EMPTY_TREE else f"{base}..{head}"
    count = _git(["rev-list", "--count", rng], check=False).stdout.strip() or "0"
    files = _diff_product_files(base, head, pathspec=spec)
    uncommitted = _status_product_files(pathspec=spec) if head == _rev_parse("HEAD") else []
    out.update({"base": base, "base_kind": base_kind, "head": head, "head_kind": head_kind,
                "range": f"{base[:7]}..{head[:7]}", "commits": int(count), "files": files, "uncommitted": uncommitted})

    tally = {k: sum(1 for f in files if f["status"] == k) for k in ("A", "M", "D", "R")}
    subject = _git(["log", "-1", "--format=%s", creation], check=False).stdout.strip() if creation else ""
    lines = header + [f"mode={out['mode']}"]
    lines.append(f"creation_commit={creation}  {subject}" if creation else "creation_commit=none (measured from --base)")
    lines.append(f"base={base} ({base_kind})")
    lines.append(f"head={head} ({head_kind})")
    lines.append(f"range={out['range']} commits={count}")
    lines += pathspec_lines(spec)
    lines.append(f"product_files={len(files)} (added {tally['A']}, modified {tally['M']}, deleted {tally['D']}, renamed {tally['R']}; works/ and docs/ excluded)")
    for f in files:
        lines.append(f"  {f['status']} {f['from']} -> {f['path']}" if f.get("from") else f"  {f['status']} {f['path']}")
    if uncommitted:
        lines.append(f"uncommitted_product_files={len(uncommitted)} (working tree, not in the range above)")
        lines += [f"  {f['status']} {f['path']}" for f in uncommitted]
    lines += [f"note: {n}" for n in out["notes"]] + [SCOPE_HINT]
    emit(lines)


def _host_pathspec() -> list:
    """The host's product: everything but the nested workflow repo. Unlike at root, the host's own
    works/ or docs/ ARE product, so only the nested repo's folder is excluded."""
    return [".", f":(exclude){Path(os.path.relpath(ROOT, HOST_ROOT)).as_posix()}"]


REPO_PATHSPEC = ["."]  # a registered repo on a multi-repo host: the whole repo is product


def product_pathspec(repos=None) -> list:
    """THE pathspec phase scope reads product files with, for the folder it reads (the workspace root
    at root, the host root nested): at root `PRODUCT_PATHSPEC`, nested `_host_pathspec()`, and on a
    multi-repo host the host's own, with every registered repo's folder excluded too (each repo
    itself reads `REPO_PATHSPEC`). `phase scope` diffs with it and prints it, so the printed line is
    the one the file list was computed with (F2)."""
    if NESTED is None:
        return list(PRODUCT_PATHSPEC)
    return _host_pathspec() + [f":(exclude){r['path']}" for r in (repos or [])]


def pathspec_text(spec: list) -> str:
    """A pathspec as one POSIX-shell line, paste-ready after `--` (`shlex.join`: `:!` and `:(...)` quoted)."""
    return shlex.join(spec)


def pathspec_lines(spec, repos=None) -> list:
    """The `pathspec=` line(s) `phase scope` prints, the value being everything after `pathspec=`.
    `spec` is the pathspec the root or host read used (None: the host was not read, a `--repo`
    filter). At root and on a single-repo host (`repos` None) one line; on a multi-repo host one
    per repo read (`repo=<name> pathspec=.`, i.e. `REPO_PATHSPEC`) and then the host's
    (`repo=. (host) pathspec=...`), each relative to that repo's own folder."""
    if repos is None:
        return [f"pathspec={pathspec_text(spec)}"]
    lines = [f"repo={r['name']} pathspec={pathspec_text(REPO_PATHSPEC)}" for r in repos]
    if spec is not None:
        lines.append(f"repo=. (host) pathspec={pathspec_text(spec)}")
    return lines


def _phase_scope_pathspec_only(args: argparse.Namespace) -> None:
    """`phase scope --pathspec [<P>]`: print only the product pathspec, phase or no phase (`/read-code`
    runs outside one). The same functions `phase scope <P>` diffs with, so the same value."""
    if args.base or args.head:
        raise SystemExit("phase scope --pathspec: refused -- the pathspec has no range; drop --base/--head")
    repos = nested_repos() if NESTED is not None else []
    if args.repo and not repos:
        raise SystemExit("phase scope --repo: refused -- a multi-repo host only; drop --repo")
    wanted = list(dict.fromkeys(args.repo or []))
    names = [r["name"] for r in repos]
    unknown = [n for n in wanted if n not in names]
    if unknown:
        raise SystemExit(f"phase scope --repo: refused -- no registered repo is named {', '.join(unknown)} (registered: {', '.join(names)})")
    selected = [r for r in repos if not wanted or r["name"] in wanted]
    spec = None if wanted else product_pathspec(repos)
    out = {"mode": "default" if NESTED is None else ("nested-multi" if repos else "nested"), "pathspec": spec}
    if repos:
        out["repos"] = [{"name": r["name"], "path": r["path"], "pathspec": list(REPO_PATHSPEC)} for r in selected]
    lines = pathspec_lines(spec, selected if repos else None)
    if args.json:
        print(json.dumps(out, indent=2, ensure_ascii=False))
    else:
        for ln in lines:
            print(ln)


def _phase_scope_nested(args: argparse.Namespace, data: dict, out: dict, header: list, emit) -> None:
    """phase scope in a nested install: the same answer in the same format, read from the HOST repo.

    The nested repo holding works/ never sees the host's commits, so the range comes from the host
    anchors `phase new` and the passing review stamped into phase.json: base = `--base`, else
    `host_anchors.created` (the host HEAD at creation, so base..head with no `^`); head = `--head`,
    else `host_anchors.review_pass` once the review passed, else the host HEAD. A phase with no
    usable anchor lists the host working tree only, mirroring the uncommitted-phase path at root.

    P40: with no `--base` and no passing review, the base rule (`resolve_repo_base`) runs on the
    host; it changes the answer only for a rebased branch (rules 4-5, D35). A multi-repo host reads
    one range per registered repo instead (`_phase_scope_multi`)."""
    repos = nested_repos()
    if repos:
        _phase_scope_multi(args, data, out, header, emit, repos)
        return
    if args.repo:
        raise SystemExit("phase scope --repo: refused -- single-repo install: the host is the one repo; drop --repo")
    host = HOST_ROOT
    spec = product_pathspec()
    out["pathspec"] = spec
    nested_dir = spec[1].split(")", 1)[1]
    out["mode"] = "nested"
    if not _git_available(cwd=host):
        out["mode"] = "no-git"
        out["hint"] = f"phase scope: no git history readable in the host {host} -- derive the boundary from the slices' result.md files"
        emit([out["hint"]])
        return
    anchors = data.get("host_anchors") if isinstance(data.get("host_anchors"), dict) else {}
    created = anchors.get("created")
    out["creation_commit"] = created
    base = base_kind = None
    missing = None
    if args.base:
        base = _rev_parse(args.base, cwd=host)
        if not base:
            raise SystemExit(f"--base {args.base}: not a commit in the host repo {host}")
        base_kind = f"from --base {args.base}"
    elif created:
        passed = (data.get("review") or {}).get("status") == "pass"
        frozen = anchors.get("review_base") if passed else None
        if frozen:  # P40: the base the rule resolved at the passing review (written only when != created)
            base = _rev_parse(frozen, cwd=host)
            if base:
                base_kind = "the base the rule resolved when the review passed (the branch moved past the anchor, by a rebase onto or a merge of a newer default): phase.json host_anchors.review_base"
            else:
                out["notes"].append(f"host_anchors.review_base {frozen} is not a commit in the host repo -- measured from host_anchors.created instead")
        if base is None:
            base = _rev_parse(created, cwd=host)
            rule = None
            if not passed:
                # P40 (D35): the base rule. Rules 2-3 resolve to `created`, the output is exactly
                # today's; only a rebased branch (rules 4-5) moves the base.
                rule = resolve_repo_base(host, created, None, "host_anchors.created", _repo_current_branch(host), "--base <host-sha>")
            if rule is not None and rule["rule"] in (4, 5) and rule["base"]:
                base, base_kind = rule["base"], rule["kind"]
                if rule["note"]:
                    out["notes"].append(rule["note"])
            elif base:
                base_kind = "the host HEAD when the phase was created (or the host worktree's base after parallel-start): phase.json host_anchors.created"
            else:
                missing = f"host_anchors.created {created} is not a commit in the host repo (rewritten history, or a shallow clone)"
    elif "created" in anchors:  # recorded as null: the host had no commit yet when the phase was created
        if _rev_parse("HEAD", cwd=host):
            base, base_kind = EMPTY_TREE, "the empty tree: the host had no commit when the phase was created"
        else:
            missing = "the host had no commit when the phase was created, and still has none"
    else:
        missing = "phase.json carries no host_anchors.created (a phase created at root, or before the nested engine)"
    if base is None:
        out["uncommitted"] = _status_product_files(cwd=host, pathspec=spec)
        lines = header + [f"mode={out['mode']}",
                          f"creation_commit=none ({missing} -- pass --base <host-sha> to measure a range)",
                          *pathspec_lines(spec),
                          f"uncommitted_product_files={len(out['uncommitted'])} (host working tree; {nested_dir}/ excluded)"]
        lines += [f"  {f['status']} {f['path']}" for f in out["uncommitted"]]
        lines += [f"note: {n}" for n in out["notes"]] + [SCOPE_HINT]
        emit(lines)
        return
    host_head = _rev_parse("HEAD", cwd=host)
    if args.head:
        head = _rev_parse(args.head, cwd=host)
        if not head:
            raise SystemExit(f"--head {args.head}: not a commit in the host repo {host}")
        head_kind = f"from --head {args.head}"
    else:
        head, head_kind = None, None
        passed = anchors.get("review_pass")
        if (data.get("review") or {}).get("status") == "pass" and passed:
            head = _rev_parse(passed, cwd=host)
            if head:
                head_kind = "the host HEAD when the review passed: phase.json host_anchors.review_pass; pass --head HEAD to read to the tip"
            else:
                out["notes"].append(f"host_anchors.review_pass {passed} is not a commit in the host repo -- read to the host's tip instead")
        if not head:
            head, head_kind = host_head, "the tip of the host's HEAD"
    if not head:
        raise SystemExit(f"cannot resolve the host's HEAD to a commit in {host}")
    rng = head if base == EMPTY_TREE else f"{base}..{head}"
    count = _git(["rev-list", "--count", rng], cwd=host, check=False).stdout.strip() or "0"
    files = _diff_product_files(base, head, cwd=host, pathspec=spec)
    uncommitted = _status_product_files(cwd=host, pathspec=spec) if head == host_head else []
    out.update({"base": base, "base_kind": base_kind, "head": head, "head_kind": head_kind,
                "range": f"{base[:7]}..{head[:7]}", "commits": int(count), "files": files, "uncommitted": uncommitted})
    tally = {k: sum(1 for f in files if f["status"] == k) for k in ("A", "M", "D", "R")}
    lines = header + [f"mode={out['mode']}"]
    if created:
        lines.append(f"creation_commit={created}  (the host HEAD at phase new, or the host worktree's base after parallel-start)")
    elif "created" in anchors and not args.base:
        lines.append("creation_commit=none (the host had no commit at phase new)")
    else:
        lines.append("creation_commit=none (measured from --base)")
    lines.append(f"base={base} ({base_kind})")
    lines.append(f"head={head} ({head_kind})")
    lines.append(f"range={out['range']} commits={count}")
    lines += pathspec_lines(spec)
    lines.append(f"product_files={len(files)} (added {tally['A']}, modified {tally['M']}, deleted {tally['D']}, renamed {tally['R']}; read from the host repo, {nested_dir}/ excluded)")
    for f in files:
        lines.append(f"  {f['status']} {f['from']} -> {f['path']}" if f.get("from") else f"  {f['status']} {f['path']}")
    if uncommitted:
        lines.append(f"uncommitted_product_files={len(uncommitted)} (host working tree, not in the range above)")
        lines += [f"  {f['status']} {f['path']}" for f in uncommitted]
    lines += [f"note: {n}" for n in out["notes"]] + [SCOPE_HINT]
    emit(lines)


def _scope_file_lines(files: list, prefix: str = "", indent: str = "  ") -> list:
    return [f"{indent}{f['status']} {prefix}{f['from']} -> {prefix}{f['path']}" if f.get("from") else f"{indent}{f['status']} {prefix}{f['path']}"
            for f in files]


def _prefixed(files: list, prefix: str) -> list:
    """Scope file entries with `prefix` (`<repo path>/`) on every path, for the union and the JSON."""
    out = []
    for f in files:
        g = dict(f, path=prefix + f["path"])
        if f.get("from"):
            g["from"] = prefix + f["from"]
        out.append(g)
    return out


def _phase_scope_multi(args: argparse.Namespace, data: dict, out: dict, header: list, emit, repos: list) -> None:
    """phase scope on a multi-repo host (P40 S1 §8): the phase's boundary is its commits in EACH
    registered repo, so one block per repo, read through `_phase_repo_path`.

    Per repo: base = per-repo `--base` (with exactly one `--repo`), else `repo_anchors.<name>.review_base`
    once the review passed, else the base rule; head = per-repo `--head`, else `review_pass` once the
    review passed, else the repo's HEAD. A repo with no anchor prints `base=none` and its working tree
    only -- never the empty tree, which would list the whole repo. The host's own block (every registered
    path excluded from its pathspec) prints only when it has a product file; without `--repo`,
    `--base`/`--head` still mean the host."""
    host = HOST_ROOT
    names = [r["name"] for r in repos]
    wanted = list(dict.fromkeys(args.repo or []))
    unknown = [n for n in wanted if n not in names]
    if unknown:
        raise SystemExit(f"phase scope --repo: refused -- no registered repo is named {', '.join(unknown)} (registered: {', '.join(names)})")
    if wanted and (args.base or args.head) and len(wanted) != 1:
        raise SystemExit("phase scope: refused -- with --repo, --base/--head set ONE repo's range, so they need exactly one --repo "
                         f"(got {len(wanted)}: {', '.join(wanted)}); without --repo they set the host's range")
    per_repo_override = bool(wanted)
    selected = [r for r in repos if not wanted or r["name"] in wanted]
    passed = (data.get("review") or {}).get("status") == "pass"
    anchors = data.get("repo_anchors") if isinstance(data.get("repo_anchors"), dict) else {}
    out["mode"] = "nested-multi"
    blocks, union, union_unc, total_commits, touched = [], [], [], 0, 0

    for repo in selected:
        name, rel = repo["name"], repo["path"]
        prefix = f"{rel}/"
        entry = {"name": name, "path": rel, "branch": None, "base": None, "base_kind": None, "head": None, "head_kind": None,
                 "range": None, "commits": 0, "pathspec": list(REPO_PATHSPEC), "files": [], "uncommitted": [], "notes": []}
        out.setdefault("repos", []).append(entry)
        path, why = _phase_repo_path(repo, data)
        if path is None and why.startswith(NOT_IN_SET) and per_repo_override and (args.base or args.head):
            # P40.S6: the explicit override S2 §17 names -- `--repo <name> --base/--head` reads a repo
            # outside this set from its main checkout, said so in a note (Decision 27).
            main = nested_repo_path(repo)
            if _git_work_tree_root(main):
                path, why = main, None
                entry["notes"].append(f"{name}: read from its main checkout {main} ({NOT_IN_SET}): another stream's working state, "
                                      f"measured only because --repo {name} --base/--head asked for it")
        if path is None:
            if why.startswith(NOT_IN_SET):
                line = f"repo={name} path={prefix} {why} -- pass --repo {name} --base/--head to read it"
                entry["notes"].append(line)
                blocks.append([line])
                continue
            entry["notes"].append(f"{name} skipped: {why}")
            blocks.append([f"repo={name} path={prefix} skipped ({why})"])
            continue
        branch_now = _repo_current_branch(path)
        entry["branch"] = branch_now
        branch_txt = branch_now or "(detached)"
        anchor = anchors.get(name) if isinstance(anchors.get(name), dict) else None
        repo_head = _rev_parse("HEAD", cwd=path)
        base = base_kind = None
        why_none = None
        if per_repo_override and args.base:
            base = _rev_parse(args.base, cwd=path)
            if not base:
                raise SystemExit(f"--base {args.base}: not a commit in {name} ({path})")
            base_kind = f"from --base {args.base}"
        elif anchor is None:
            why_none = f"no repo_anchors.{name} -- pass --repo {name} --base <sha>"
        else:
            frozen = anchor.get("review_base") if passed else None
            if frozen:
                base = _rev_parse(frozen, cwd=path)
                if base:
                    base_kind = f"frozen at the passing review: repo_anchors.{name}.review_base"
                else:
                    entry["notes"].append(f"repo_anchors.{name}.review_base {frozen} is not a commit in {name} -- the base rule decides instead")
            if base is None:
                res = resolve_repo_base(path, anchor.get("created"), repo.get("default_branch"), f"repo_anchors.{name}.created",
                                        branch_now, f"--repo {name} --base <sha>")
                base, base_kind = res["base"], res["kind"]
                if res["note"] and base:
                    entry["notes"].append(f"{name}: {res['note']}")
                elif not base:
                    why_none = f"{res['note']} -- pass --repo {name} --base <sha>"
        if base is None:
            unc = _prefixed(_status_product_files(cwd=path, pathspec=REPO_PATHSPEC), prefix)
            entry["uncommitted"] = unc
            union_unc += unc
            touched += bool(unc)
            block = [f"repo={name} path={prefix} branch={branch_txt} base=none ({why_none})"]
            if unc:
                block.append(f"  uncommitted_product_files={len(unc)} (working tree)")
                block += _scope_file_lines(unc, indent="    ")
            blocks.append(block)
            out["notes"] += entry["notes"]
            continue
        if per_repo_override and args.head:
            head = _rev_parse(args.head, cwd=path)
            if not head:
                raise SystemExit(f"--head {args.head}: not a commit in {name} ({path})")
            head_kind = f"from --head {args.head}"
        else:
            head = head_kind = None
            frozen_head = anchor.get("review_pass") if (anchor and passed) else None
            if frozen_head:
                head = _rev_parse(frozen_head, cwd=path)
                if head:
                    head_kind = f"{name}'s HEAD when the review passed: repo_anchors.{name}.review_pass; pass --repo {name} --head HEAD to read to the tip"
                else:
                    entry["notes"].append(f"repo_anchors.{name}.review_pass {frozen_head} is not a commit in {name} -- read to its tip instead")
            if not head:
                head, head_kind = repo_head, f"the tip of {name}'s HEAD"
                recorded = anchor.get("branch") if anchor else None
                if recorded and branch_now != recorded:
                    entry["notes"].append(f"{name} is on {branch_txt}, the phase recorded {recorded} -- pass --repo {name} --head {recorded}")
        if not head:
            raise SystemExit(f"cannot resolve {name}'s HEAD to a commit in {path}")
        rng = head if base == EMPTY_TREE else f"{base}..{head}"
        count = int(_git(["rev-list", "--count", rng], cwd=path, check=False).stdout.strip() or "0")
        files = _diff_product_files(base, head, cwd=path, pathspec=REPO_PATHSPEC)
        uncommitted = _status_product_files(cwd=path, pathspec=REPO_PATHSPEC) if head == repo_head else []
        pfiles, punc = _prefixed(files, prefix), _prefixed(uncommitted, prefix)
        entry.update({"base": base, "base_kind": base_kind, "head": head, "head_kind": head_kind,
                      "range": f"{base[:7]}..{head[:7]}", "commits": count, "files": pfiles, "uncommitted": punc})
        union += pfiles
        union_unc += punc
        total_commits += count
        out["notes"] += entry["notes"]
        if not (count or files or uncommitted):
            blocks.append([f"repo={name} path={prefix} commits=0 product_files=0 (untouched)"])
            continue
        touched += 1
        tally = {k: sum(1 for f in files if f["status"] == k) for k in ("A", "M", "D", "R")}
        block = [f"repo={name} path={prefix} branch={branch_txt} base={base[:7]} ({base_kind}) head={head[:7]} ({head_kind}) commits={count}",
                 f"  product_files={len(files)} (added {tally['A']}, modified {tally['M']}, deleted {tally['D']}, renamed {tally['R']})"]
        block += _scope_file_lines(pfiles, indent="    ")
        if uncommitted:
            block.append(f"  uncommitted_product_files={len(uncommitted)} (working tree, not in the range above)")
            block += _scope_file_lines(punc, indent="    ")
        blocks.append(block)

    # The host's own block: never with a --repo filter; printed only when it has a product file
    # (a multi-repo host tracks nothing), or when --base/--head asked for its range.
    host_block = []
    host_anchors = data.get("host_anchors") if isinstance(data.get("host_anchors"), dict) else {}
    out["creation_commit"] = host_anchors.get("created")
    spec = None if wanted else product_pathspec(repos)  # every registered repo's folder excluded
    out["pathspec"] = spec
    if not wanted and host is not None and _git_available(cwd=host):
        base = base_kind = None
        if args.base:
            base = _rev_parse(args.base, cwd=host)
            if not base:
                raise SystemExit(f"--base {args.base}: not a commit in the host repo {host}")
            base_kind = f"from --base {args.base}"
        elif passed and host_anchors.get("review_base") and _rev_parse(host_anchors["review_base"], cwd=host):
            base, base_kind = _rev_parse(host_anchors["review_base"], cwd=host), "frozen at the passing review: host_anchors.review_base"
        elif "created" in host_anchors:
            res = resolve_repo_base(host, host_anchors.get("created"), None, "host_anchors.created", _repo_current_branch(host), "--base <host-sha>")
            base, base_kind = res["base"], res["kind"]
        host_head = _rev_parse("HEAD", cwd=host)
        head, head_kind = None, None
        if args.head:
            head = _rev_parse(args.head, cwd=host)
            if not head:
                raise SystemExit(f"--head {args.head}: not a commit in the host repo {host}")
            head_kind = f"from --head {args.head}"
        elif passed and host_anchors.get("review_pass"):
            head = _rev_parse(host_anchors["review_pass"], cwd=host)
            head_kind = "the host HEAD when the review passed: host_anchors.review_pass" if head else None
        if not head:
            head, head_kind = host_head, "the tip of the host's HEAD"
        files, count = [], 0
        if base and head:
            rng = head if base == EMPTY_TREE else f"{base}..{head}"
            count = int(_git(["rev-list", "--count", rng], cwd=host, check=False).stdout.strip() or "0")
            files = _diff_product_files(base, head, cwd=host, pathspec=spec)
            out.update({"base": base, "base_kind": base_kind, "head": head, "head_kind": head_kind, "range": f"{base[:7]}..{head[:7]}"})
        uncommitted = _status_product_files(cwd=host, pathspec=spec) if head == host_head else []
        union += files
        union_unc += uncommitted
        if files or uncommitted or args.base or args.head:
            total_commits += count
            tally = {k: sum(1 for f in files if f["status"] == k) for k in ("A", "M", "D", "R")}
            if base and head:
                host_block.append(f"repo=. (host) base={base[:7]} ({base_kind}) head={head[:7]} ({head_kind}) commits={count}")
            else:
                host_block.append("repo=. (host) base=none (no usable host_anchors.created -- pass --base <host-sha>)")
            host_block.append(f"  product_files={len(files)} (added {tally['A']}, modified {tally['M']}, deleted {tally['D']}, renamed {tally['R']}; "
                              f"{_nested_dir_name()}/ and the {len(repos)} repos excluded)")
            host_block += _scope_file_lines(files, indent="    ")
            if uncommitted:
                host_block.append(f"  uncommitted_product_files={len(uncommitted)} (host working tree, not in the range above)")
                host_block += _scope_file_lines(uncommitted, indent="    ")
            if files or uncommitted:
                out["notes"].append("the multi-repo host has product files of its own -- product belongs in the repos")

    out.update({"commits": total_commits, "files": union, "uncommitted": union_unc})
    lines = header + [f"mode=nested-multi repos={len(selected)} touched={touched}"]
    for block in blocks:
        lines += block
    lines += host_block
    if not union:
        lines.append(f"product_files=0 across {len(selected)} repos")
    lines += pathspec_lines(spec, selected)
    lines += [f"note: {n}" for n in out["notes"]] + [SCOPE_HINT]
    emit(lines)


# ---------------------------------------------------------------------------
# P51 (PR rule v1): one draft PR per repo branch per phase.
#
# phase.json's `pr` block records each repo branch the phase's product commits ride on, its base
# and, once the draft opened when the review passed (the `pr` skill's *Open the drafts*), its URL:
#
#     "pr": {"branches": [{"repo": null | "<repos-key name>", "branch": "<name>", "base": "<ref>",
#                          "url": null | "<url>", "recorded_at": "<iso>", "opened_at": null | "<iso>",
#                          # optional (P52), written only by pr-sync from GitHub; absent on a P51-era entry:
#                          "state": null | "draft|ready|merged|closed", "synced_at": null | "<iso>",
#                          "ready_at": null | "<iso>", "merged_at": null | "<iso>"}],
#            "waived": null | {"note": "<why>", "at": "<iso>"}}
#
# `repo` is null on a single-repo host and at root; on a multi-repo host it names a `repos` entry.
# `phase new` stamps an empty block on every phase; a phase created before P51 carries none, so
# nothing here reads or refuses it (the way a pre-v32 phase has no acceptance gate), until
# `pr-branch` records a branch and adds the block. `pr-branch` cuts or records a branch,
# `pr-record` stores the draft's URL (or waives the PR), `pr-check` measures a branch (size, body
# budgets, leaks, heading order), and `review-phase --verdict pass` refuses while a recorded branch
# has no URL, or while an empty block meets a phase that changed product files
# (`_require_pr_opened`, beside the acceptance gate's refusal). The operator's decided team-rule
# conflicts live in the nested marker's optional `pr_rules` key, or at root in works/pr-rules.json
# (`load_pr_rules`). The team's rules themselves are read live each time a body is written.
# ---------------------------------------------------------------------------

PR_BLOCK_KEYS = ("branches", "waived")
PR_BRANCH_KEYS = ("repo", "branch", "base", "url", "recorded_at", "opened_at")
# P52: the PR's lifecycle after the draft opened, read from GitHub by `pr-sync` (the engine's only network
# read) and by nothing else: an entry without them (P51-era, or never synced) reads `unsynced`. `state=merged`
# alone releases the archive hold (`_phase_blocker_kinds`' kind "pr"); `ready_at` is stamped once, never cleared.
PR_BRANCH_OPTIONAL_KEYS = ("state", "synced_at", "ready_at", "merged_at")
PR_STATES = ("draft", "ready", "merged", "closed")
PR_WAIVED_KEYS = ("note", "at")
# Size has no default limit (D4 as amended): pr-check prints the changed-line count as information, and
# only a team's own limit, read live from their rules and passed as `--limit <n>`, can make it warn.
PR_BODY_BUDGETS = (("first_screen", 1500), ("visible", 3500), ("whole", 6000))
PR_LOCKFILES = frozenset(("package-lock.json", "yarn.lock", "pnpm-lock.yaml", "poetry.lock", "uv.lock", "Pipfile.lock",
                          "Cargo.lock", "Gemfile.lock", "composer.lock", "go.sum"))
# A team's PR template, first hit wins: GitHub reads the file name case-insensitively in .github/, docs/
# and the root, then a lone file in .github/PULL_REQUEST_TEMPLATE/.
PR_TEMPLATE_DIRS = (".github", "docs", ".")
PR_TEMPLATE_NAME = "pull_request_template.md"
PR_TEMPLATE_MULTI_DIR = ".github/PULL_REQUEST_TEMPLATE"
PR_DEFAULT_HEADINGS = ("Summary", "Review", "What is changed", "Why", "Related issue")  # D3 as amended
PR_RULES_FILE = "pr-rules.json"  # root installs: works/pr-rules.json; nested: the marker's pr_rules key
PR_RULE_KEYS = ("rule", "choice", "note", "at")
PR_RULE_OPTIONAL_KEYS = ("repo",)  # a multi-repo host's decision about one repo's rule; absent or null = every repo
PR_RULE_CHOICES = ("team", "ours")
# P52: the record's optional `ownership` list -- one entry per repo, whether its PRs are a solo owner's (the
# close merges) or a team's (the close waits on their merge); written by `pr-team --record`, read by pr_team_mode.
PR_OWNERSHIP_KEYS = ("repo", "mode", "evidence", "at")
PR_OWNERSHIP_MODES = ("solo", "team")
PR_DRAFT_DUE = ("pr_draft=due -- when the review would pass: open the draft(s) (pr skill: Open the drafts, then pr-record --url), "
                "then the gate or the pass")


def new_pr_block() -> dict:
    """A fresh `pr` block: no branch recorded, not waived."""
    return {"branches": [], "waived": None}


def phase_pr(data):
    """The phase's `pr` block when it is readable, else None: absent (a phase from before P51) or
    malformed (validate's error). Read the block only through this helper."""
    if not isinstance(data, dict):
        return None
    block = data.get("pr")
    if not isinstance(block, dict) or not isinstance(block.get("branches"), list):
        return None
    if not all(isinstance(e, dict) for e in block["branches"]):
        return None
    if block.get("waived") is not None and not isinstance(block.get("waived"), dict):
        return None
    return block


def _pr_registry_names():
    """The multi-repo registry's names when the marker's `repos` key holds entries, else None."""
    if NESTED is None or not isinstance(NESTED.get("repos"), list) or not NESTED["repos"]:
        return None
    return [r.get("name") for r in NESTED["repos"] if isinstance(r, dict)]


def pr_block_problems(block, repo_names=None) -> list:
    """Every way a phase.json `pr` block breaks its shape (empty when well-formed): exactly
    PR_BLOCK_KEYS; each branch entry PR_BRANCH_KEYS (plus the optional PR_BRANCH_OPTIONAL_KEYS) with the right types, a unique
    (repo, branch) pair, and a `repo` naming a registry entry whenever the marker has `repos`
    (`repo_names`), null otherwise; `waived` null or exactly PR_WAIVED_KEYS with a note."""
    if not isinstance(block, dict):
        return [f"has a non-object pr block {block!r}; expected {{\"branches\": [...], \"waived\": null}}"]
    problems = []
    missing = [k for k in PR_BLOCK_KEYS if k not in block]
    unknown = sorted(str(k) for k in block if k not in PR_BLOCK_KEYS)
    if missing:
        problems.append(f"pr: missing field(s) {', '.join(missing)}")
    if unknown:
        problems.append(f"pr: unknown field(s) {', '.join(unknown)} (the block has exactly {', '.join(PR_BLOCK_KEYS)})")
    branches = block.get("branches", [])
    if not isinstance(branches, list):
        problems.append("pr.branches must be a list of branch entries")
        branches = []
    seen = set()
    for i, entry in enumerate(branches):
        label = f"pr.branches[{i}]"
        if not isinstance(entry, dict):
            problems.append(f"{label} is not an object")
            continue
        gone = [k for k in PR_BRANCH_KEYS if k not in entry]
        extra = sorted(str(k) for k in entry if k not in PR_BRANCH_KEYS + PR_BRANCH_OPTIONAL_KEYS)
        if gone:
            problems.append(f"{label}: missing field(s) {', '.join(gone)}")
        if extra:
            problems.append(f"{label}: unknown field(s) {', '.join(extra)} (an entry has exactly {', '.join(PR_BRANCH_KEYS)}, "
                            f"and optionally {', '.join(PR_BRANCH_OPTIONAL_KEYS)})")
        state = entry.get("state")
        if state is not None and state not in PR_STATES:
            problems.append(f"{label}.state {state!r} must be null or one of {', '.join(PR_STATES)}")
        for key in ("synced_at", "ready_at", "merged_at"):
            value = entry.get(key)
            if value is not None and not (isinstance(value, str) and value.strip()):
                problems.append(f"{label}.{key} must be null or a timestamp string")
        if state is not None and not entry.get("url"):
            problems.append(f"{label}: state is set but url is not (only pr-sync writes state, and it reads the recorded url)")
        repo = entry.get("repo")
        if repo is not None and not (isinstance(repo, str) and NESTED_REPO_NAME.fullmatch(repo)):
            problems.append(f"{label}.repo {repo!r} must be null or a registered repo's name")
        elif repo_names:
            if repo is None:
                problems.append(f"{label}.repo is null, but this multi-repo host registers repos ({', '.join(map(str, repo_names))}): name one")
            elif repo not in repo_names:
                problems.append(f"{label}.repo {repo!r} names no registered repo (registered: {', '.join(map(str, repo_names))})")
        elif repo is not None:
            problems.append(f"{label}.repo {repo!r}: this install has no repos registry, so repo is null (the host, or the root repo)")
        for key in ("branch", "base", "recorded_at"):
            value = entry.get(key)
            if key in entry and not (isinstance(value, str) and value.strip()):
                problems.append(f"{label}.{key} must be a non-empty string")
        branch = entry.get("branch")
        if isinstance(branch, str) and branch.strip() and re.search(r"\s", branch):
            problems.append(f"{label}.branch {branch!r} has whitespace")
        url = entry.get("url")
        if url is not None and not _pr_url_ok(url):
            problems.append(f"{label}.url {url!r} must be null or an http(s) URL")
        opened = entry.get("opened_at")
        if opened is not None and not (isinstance(opened, str) and opened.strip()):
            problems.append(f"{label}.opened_at must be null or a timestamp string")
        if (url is None) != (opened is None) and "url" in entry and "opened_at" in entry:
            problems.append(f"{label}: url and opened_at are set together (pr-record writes both)")
        key = (repo, branch)
        if isinstance(branch, str):
            if key in seen:
                problems.append(f"{label}: {repo or _pr_one_repo()}:{branch} is recorded twice")
            seen.add(key)
    waived = block.get("waived")
    if waived is not None:
        if not isinstance(waived, dict) or sorted(waived) != sorted(PR_WAIVED_KEYS):
            problems.append(f"pr.waived must be null or an object with exactly {', '.join(PR_WAIVED_KEYS)}")
        else:
            if not (isinstance(waived.get("note"), str) and waived["note"].strip()):
                problems.append("pr.waived.note must be a non-empty string (why the phase needs no PR)")
            if not (isinstance(waived.get("at"), str) and waived["at"].strip()):
                problems.append("pr.waived.at must be a timestamp string")
    return problems


def _pr_url_ok(url) -> bool:
    if not isinstance(url, str) or not url.strip() or re.search(r"\s", url):
        return False
    parsed = urlparse(url)
    return parsed.scheme in ("http", "https") and bool(parsed.netloc)


def _ensure_pr(data: dict) -> dict:
    """The phase's `pr` block, created on demand (how a phase from before P51 gets one), placed right
    after `acceptance` (else appended). SystemExit on a malformed block: never overwrite it silently."""
    block = phase_pr(data)
    if block is not None:
        return block
    if "pr" in data:
        problems = pr_block_problems(data["pr"], _pr_registry_names())
        raise SystemExit(f"phase {data.get('id')} has a malformed pr block ({'; '.join(problems) or 'unreadable'}); "
                         f"fix phase.json first (run: {WORKFLOW_CMD} check --no-rebuild) -- nothing was written")
    block = new_pr_block()
    ordered = {}
    for key, value in data.items():
        ordered[key] = value
        if key == "acceptance":
            ordered["pr"] = block
    ordered.setdefault("pr", block)
    data.clear()
    data.update(ordered)
    return block


def _pr_one_repo() -> str:
    """The label of the one repo a single-repo install has: `host` in a nested install (the host beside
    its nested workflow repo), `root` at root (one repo, no host/nested split). A multi-repo host labels
    each entry by its registered repo's name instead."""
    return "host" if NESTED is not None else "root"


def _pr_label(entry: dict) -> str:
    return f"{entry.get('repo') or _pr_one_repo()}:{entry.get('branch')}"


def _pr_target(data: dict, repo_arg, cmd: str) -> dict:
    """Where a PR command works: `{label, repo, path, default}`. A multi-repo host needs `--repo` (the
    registered repo's checkout, through `_phase_repo_path`); a single-repo nested host is HOST_ROOT
    and a root install is ROOT, both refusing `--repo`. `default` is the registry's default_branch."""
    repos = nested_repos()
    if repos:
        names = [r["name"] for r in repos]
        if not repo_arg:
            raise SystemExit(f"{cmd}: this multi-repo host needs --repo <name> (registered: {', '.join(names)}) -- nothing was written")
        repo = next((r for r in repos if r["name"] == repo_arg), None)
        if repo is None:
            raise SystemExit(f"{cmd} --repo {repo_arg}: no registered repo has that name (registered: {', '.join(names)}) -- nothing was written")
        path, why = _phase_repo_path(repo, data)
        if path is None:
            raise SystemExit(f"{cmd} --repo {repo_arg}: cannot be read here: {why} -- nothing was written")
        return {"label": repo_arg, "repo": repo_arg, "path": path, "default": repo.get("default_branch")}
    if repo_arg:
        raise SystemExit(f"{cmd} --repo: refused -- a multi-repo host only; a single-repo host or a root install has one repo: drop --repo")
    path = HOST_ROOT if NESTED is not None else ROOT
    if path is None or not _git_available(cwd=path):
        raise SystemExit(f"{cmd}: {path} is not inside a git work tree -- a PR branch needs one")
    return {"label": _pr_one_repo(), "repo": None, "path": path, "default": None}


def _pr_default_base(path: Path, configured=None):
    """The base a PR branch is recorded against when `--base` is not given: the repo's default branch
    NAME D (the registry's default_branch, else origin/HEAD's target, else main/master), what
    `gh pr create --base` takes, when `origin/D` or the local `D` exists. None when neither exists.
    Never fetched. A diff resolves the ref itself at check time (`_pr_diff_ref`)."""
    name = _repo_default_branch(path, configured) or "main"
    return name if _pr_diff_ref(path, name)[0] else None


def _pr_remotes(path: Path) -> list:
    """`git remote`'s names in `path`, longest first (so `a/b` matches before `a`)."""
    proc = _git(["remote"], cwd=path, check=False)
    names = [r.strip() for r in proc.stdout.splitlines() if r.strip()] if proc.returncode == 0 else []
    return sorted(names, key=len, reverse=True)


def _pr_ref_exists(path: Path, full: str) -> bool:
    return _git(["show-ref", "--verify", "--quiet", full], cwd=path, check=False).returncode == 0


def _pr_remote_branch(path: Path, ref: str):
    """`<x>` when `ref` (`<remote>/<x>` or `refs/remotes/<remote>/<x>`) names a remote-tracking ref of a
    remote `git remote` lists (origin/HEAD read through to its target), else None."""
    rest = ref[len("refs/remotes/"):] if ref.startswith("refs/remotes/") else ref
    for remote in _pr_remotes(path):
        if rest.startswith(remote + "/") and len(rest) > len(remote) + 1 and _pr_ref_exists(path, f"refs/remotes/{rest}"):
            name = rest[len(remote) + 1:]
            if name == "HEAD":
                proc = _git(["symbolic-ref", "-q", "--short", f"refs/remotes/{rest}"], cwd=path, check=False)
                target = proc.stdout.strip() if proc.returncode == 0 else ""
                return target[len(remote) + 1:] if target.startswith(remote + "/") and len(target) > len(remote) + 1 else None
            return name
    return None


def _pr_base_branch(path: Path, ref: str):
    """`(name, None)` or `(None, why)`: an explicit `--base` as the branch NAME `gh pr create --base`
    takes. A local branch stays as given (even one literally named `origin/foo`); a remote-tracking
    ref (`refs/remotes/<remote>/<x>` for a listed remote) records `<x>`; a sha or a tag is refused."""
    ref = ref.strip()
    if ref.startswith("refs/heads/") and _pr_ref_exists(path, ref):
        return ref[len("refs/heads/"):], None
    if _pr_ref_exists(path, f"refs/heads/{ref}"):
        return ref, None
    name = _pr_remote_branch(path, ref)
    if name:
        return name, None
    if _rev_parse(ref, cwd=path):
        return None, f"{ref} is a commit or a tag, not a branch -- a PR base must be a branch"
    return None, f"{ref} is not a branch in {path}"


def _pr_read_base(path, base):
    """A recorded base read as its branch NAME: a record from before P51-b1.S13 may hold a remote-tracking
    ref (`origin/main`), normalized here the way `pr-branch` now writes it. Unchanged without a path."""
    if not isinstance(base, str) or path is None:
        return base
    if base.startswith("refs/heads/"):
        return base[len("refs/heads/"):]
    if _pr_ref_exists(path, f"refs/heads/{base}"):
        return base
    return _pr_remote_branch(path, base) or base


def _pr_diff_ref(path: Path, base):
    """`(full_ref, shown)` a diff of `base...branch` uses, resolved at check time: `origin/<base>` when
    that remote-tracking ref exists (what GitHub diffs the PR against), else the local `<base>`; an old
    record's own remote ref last. `(None, None)` when none exists."""
    if not isinstance(base, str) or not base.strip() or path is None:
        return None, None
    name = _pr_read_base(path, base)
    cands = [(f"refs/remotes/origin/{name}", f"origin/{name}"), (f"refs/heads/{name}", name)]
    if name != base:
        full = base if base.startswith("refs/") else f"refs/remotes/{base}"
        cands.append((full, base))
    for full, shown in cands:
        if _pr_ref_exists(path, full):
            return full, shown
    return None, None


def _pr_entry_path(entry: dict, data):
    """The checkout a recorded branch entry lives in (the host or root, or its registered repo), or None."""
    repo = entry.get("repo")
    if repo is None:
        return HOST_ROOT if NESTED is not None else ROOT
    reg = next((r for r in nested_repos() if r["name"] == repo), None)
    return _phase_repo_path(reg, data)[0] if reg else None


def _pr_shown_base(entry: dict, data):
    """An entry's base as printed: its branch name, an old record's remote prefix read away."""
    try:
        return _pr_read_base(_pr_entry_path(entry, data), entry.get("base"))
    except (OSError, SystemExit):
        return entry.get("base")


def _pr_branch_tip(path: Path, branch: str):
    """The ref holding `branch` in `path`: the local branch, else its origin copy, else None."""
    if _rev_parse(f"refs/heads/{branch}", cwd=path):
        return branch
    if _rev_parse(f"refs/remotes/origin/{branch}", cwd=path):
        return f"origin/{branch}"
    return None


def _pr_tracked_changes(path: Path, repo) -> list:
    """The tracked, uncommitted changes in `path` a branch switch would carry (untracked files belong to
    no branch). Product paths only: at root the workflow state (works/, docs/) is excluded, and a
    nested host excludes its nested workflow repo."""
    spec = REPO_PATHSPEC if repo is not None else product_pathspec()  # a single-repo host or root here
    proc = _git(["status", "--porcelain", "--untracked-files=no", "--", *spec], cwd=path, check=False)
    return [ln[3:] for ln in proc.stdout.splitlines() if len(ln) > 3]


def cmd_pr_branch(args: argparse.Namespace) -> None:
    """Cut or record the phase's PR branch in one repo's checkout, and record it in phase.json's `pr`
    block. The branch already checked out there is only recorded; `--base` on an already-recorded branch
    re-records its base with no switch (P52 stacking); an unrecorded existing branch that is not checked
    out is refused (switch to it, then re-run); otherwise `git switch --no-track -c <b> <base>`."""
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    branch = (args.name or "").strip()
    target = _pr_target(data, args.repo, "pr-branch")
    path, label = target["path"], f"{target['label']}:{branch}"
    if not branch or _git(["check-ref-format", "--branch", branch], cwd=path, check=False).returncode != 0:
        raise SystemExit(f"pr-branch --name {args.name!r}: not a valid branch name -- nothing was written")
    if "pr" in data and phase_pr(data) is None:
        _ensure_pr(data)  # raises: a malformed block is never overwritten
    if args.base:
        base, why = _pr_base_branch(path, args.base)
        if base is None:
            raise SystemExit(f"pr-branch --base {args.base.strip()}: {why} -- nothing was written")
        cut_from = args.base.strip()
    else:
        base = _pr_default_base(path, target["default"])
        if base is None:
            raise SystemExit(f"pr-branch: cannot find the default branch in {path} (no origin/HEAD, no main or master) -- "
                             f"pass --base <branch>; nothing was written")
        cut_from = _pr_diff_ref(path, base)[1]
    default_name = _repo_default_branch(path, target["default"])
    if branch in {base, args.base.strip() if args.base else base, default_name}:
        raise SystemExit(f"pr-branch --name {branch}: that is the base or default branch itself; a PR branch carries the phase's "
                         f"product commits on top of it -- name a new one (the host's convention for branches) -- nothing was written")
    held = phase_pr(data)
    recorded = next((e for e in held["branches"] if e.get("repo") == target["repo"] and e.get("branch") == branch), None) if held else None
    if args.base and recorded is not None:
        # P52 stacking: a recorded branch's base is re-recorded in place -- no switch, no dirty-tree check,
        # checked out or not (nothing moves in the checkout); the lifecycle fields describe the same PR and stay.
        old = recorded.get("base")
        old_shown = _pr_read_base(path, old)
        recorded["base"] = base
        write_json(pdir / "phase.json", data)
        append_event("pr_branch_recorded", phase=args.phase, repo=target["repo"], branch=branch, base=base, old_base=old,
                     created=False, rerecorded=True)
        rebuild_index_and_state()
        print(f"pr_branch={label} base={base}")
        print(f"pr-branch: {branch} base re-recorded from {old_shown}" + (" (unchanged)" if old_shown == base else "")
              + f" -- no switch; nothing moved in {path}")
        return
    current = _repo_current_branch(path)
    created = False
    if current != branch:
        if _git_operation_in_progress(cwd=path):
            raise SystemExit(f"pr-branch: {path} is mid-{_git_operation_in_progress(cwd=path)}; finish it first -- nothing was written")
        if _rev_parse(f"refs/heads/{branch}", cwd=path):
            raise SystemExit(f"pr-branch: branch {branch} already exists in {path} and is not checked out there; switch to it, then re-run "
                             f"to record it:\n  git -C {path} switch {branch}\n  {WORKFLOW_CMD} pr-branch {args.phase}"
                             f"{' --repo ' + target['repo'] if target['repo'] else ''} --name {branch}\nnothing was written")
        dirty = _pr_tracked_changes(path, target["repo"])
        if dirty:
            shown_files = ", ".join(dirty[:5]) + (f" (+{len(dirty) - 5} more)" if len(dirty) > 5 else "")
            raise SystemExit(f"pr-branch: {path} has uncommitted tracked changes a switch would carry onto {branch}: {shown_files}; "
                             f"commit or stash them first -- nothing was written")
        _git(["switch", "--no-track", "-c", branch, cut_from], cwd=path)
        created = True
    block = _ensure_pr(data)
    entry = next((e for e in block["branches"] if e.get("repo") == target["repo"] and e.get("branch") == branch), None)
    if entry is None:
        entry = {"repo": target["repo"], "branch": branch, "base": base, "url": None, "recorded_at": now_iso(), "opened_at": None}
        block["branches"].append(entry)
        how = "created and recorded" if created else "recorded (already checked out)"
    else:
        if args.base:
            entry["base"] = base
        how = "already recorded" + (" (base updated)" if args.base else "")
    write_json(pdir / "phase.json", data)
    append_event("pr_branch_recorded", phase=args.phase, repo=target["repo"], branch=branch, base=entry["base"], created=created)
    rebuild_index_and_state()
    print(f"pr_branch={label} base={entry['base']}")
    print(f"pr-branch: {branch} {how}" + (f" -- cut from {cut_from} with git switch --no-track -c" if created else "") + f" in {path}")


def cmd_pr_record(args: argparse.Namespace) -> None:
    """Record the draft PR opened when the review passed (`--url`, on the matching branch entry), or
    waive the phase's PR (`--waive --note`): a phase with no product change worth a PR."""
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    if args.waive:
        if args.url or args.branch or args.repo:
            raise SystemExit("pr-record --waive takes only --note: it waives the phase's PR as a whole -- nothing was written")
        if not (args.note or "").strip():
            raise SystemExit(f"pr-record {args.phase} --waive requires --note \"why this phase needs no PR\" -- nothing was written")
        block = _ensure_pr(data)
        block["waived"] = {"note": args.note.strip(), "at": now_iso()}
        write_json(pdir / "phase.json", data)
        append_event("pr_waived", phase=args.phase)
        rebuild_index_and_state()
        print(f"pr_waived={_one_line(args.note)}")
        print(f"pr-record: phase {args.phase}'s PR waived -- review-phase --verdict pass no longer waits on a draft PR")
        return
    if args.note:
        raise SystemExit("pr-record --note belongs to --waive -- nothing was written")
    if not _pr_url_ok(args.url):
        raise SystemExit(f"pr-record needs --url <the draft PR's http(s) URL> (or --waive --note \"why\"); got {args.url!r} -- nothing was written")
    repos = nested_repos()
    if args.repo and not repos:
        raise SystemExit("pr-record --repo: refused -- a multi-repo host only; a single-repo host or a root install has one repo: drop --repo")
    if "pr" in data and phase_pr(data) is None:
        _ensure_pr(data)  # raises on a malformed block
    block = phase_pr(data)
    entries = block["branches"] if block else []
    hits = [e for e in entries if (args.repo is None or e.get("repo") == args.repo) and (args.branch is None or e.get("branch") == args.branch)]
    recorded = ", ".join(_pr_label(e) for e in entries) or "none"
    if not hits:
        asked = f"{args.repo or _pr_one_repo()}:{args.branch}" if args.branch else (args.repo or "this phase")
        raise SystemExit(f"pr-record: no recorded PR branch matches {asked} (recorded: {recorded}); record it first: "
                         f"{WORKFLOW_CMD} pr-branch {args.phase}{' --repo <name>' if repos else ''} --name <branch> -- nothing was written")
    if len(hits) > 1:
        raise SystemExit(f"pr-record: {len(hits)} recorded branches match ({', '.join(_pr_label(e) for e in hits)}); name one with "
                         f"{'--repo and ' if repos else ''}--branch -- nothing was written")
    entry = hits[0]
    url = args.url.strip()
    if entry.get("url") != url or not entry.get("opened_at"):
        entry["opened_at"] = now_iso()
    if entry.get("url") != url:  # P52: a new PR -- the old one's synced lifecycle no longer describes it
        for key in PR_BRANCH_OPTIONAL_KEYS:
            entry.pop(key, None)
    entry["url"] = url
    write_json(pdir / "phase.json", data)
    append_event("pr_recorded", phase=args.phase, repo=entry.get("repo"), branch=entry.get("branch"), url=url)
    rebuild_index_and_state()
    print(f"pr_branch={_pr_label(entry)} base={_pr_shown_base(entry, data)} url={url}")
    left = [e for e in entries if not e.get("url")]
    if left:
        print(f"pr-record: {len(left)} recorded branch(es) still have no draft PR: {', '.join(_pr_label(e) for e in left)}")


def _phase_scope_product_files(phase_id: str):
    """The product files `phase scope <P>` lists in the phase's committed range (its JSON `files`, the
    union over repos on a multi-repo host), or None when it cannot answer. Uncommitted files do not
    count: a phase's product lands in commits before its pass, and an operator's stray working-tree
    file must never hold a review."""
    import contextlib
    import io
    ns = argparse.Namespace(phase=phase_id, base=None, head=None, json=True, repo=None, pathspec=False)
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            phase_scope(ns)
        out = json.loads(buf.getvalue())
    except (SystemExit, Exception):  # noqa: BLE001 - an unreadable scope is reported by the caller, never fatal here
        return None
    files = out.get("files") if isinstance(out, dict) else None
    return [f.get("path") for f in files if isinstance(f, dict)] if isinstance(files, list) else None


def _require_pr_opened(phase_id: str, data: dict) -> None:
    """Refuse a passing review while the phase's PR is not opened: (a) a recorded branch has no URL, or
    (b) the block records no branch while `phase scope` lists product files -- unless `pr.waived` is set.

    Called beside `_require_acceptance_cleared`, before `review_phase` writes anything; each refusal
    names only itself, and both must clear. A phase with no `pr` block (created before P51) is never
    refused; only `pass` is ever checked."""
    if "pr" not in data:
        return
    block = phase_pr(data)
    if block is None:
        print(f"pr: phase {phase_id} has a malformed pr block -- treated as absent (run: {WORKFLOW_CMD} check --no-rebuild)")
        return
    waived = block.get("waived")
    if isinstance(waived, dict):
        print(f"pr: waived ({_one_line(waived.get('note') or '')}) -- pass recorded without a draft PR")
        return
    multi = bool(nested_repos())
    repo_flag = " --repo <name>" if multi else ""
    missing = [e for e in block["branches"] if not e.get("url")]
    if missing:
        listed = "\n".join(f"  {_pr_label(e)} (base {_pr_shown_base(e, data)}) has no draft PR" for e in missing)
        raise SystemExit(
            f"phase {phase_id} records {len(missing)} PR branch(es) with no draft PR yet; a pass cannot be recorded until each is opened:\n"
            f"{listed}\n"
            f"  the draft opens when the review passes (pr skill: Open the drafts): push the branch, open it, then: {WORKFLOW_CMD} pr-record {phase_id}{repo_flag} --branch <branch> --url <url>\n"
            f"  or, for a phase with no product change worth a PR: {WORKFLOW_CMD} pr-record {phase_id} --waive --note \"why\"\n"
            f"nothing was written")
    if not block["branches"]:
        files = _phase_scope_product_files(phase_id)
        if files is None:
            print(f"pr: phase scope {phase_id} could not be read -- the no-branch check was skipped")
        elif files:
            raise SystemExit(
                f"phase {phase_id} changed {len(files)} product file(s) (phase scope {phase_id}) but records no PR branch; a pass cannot be recorded:\n"
                f"  record the branch its product commits are on: {WORKFLOW_CMD} pr-branch {phase_id}{repo_flag} --name <branch>\n"
                f"  then, once the draft opened when the review passed (pr skill: Open the drafts): {WORKFLOW_CMD} pr-record {phase_id}{repo_flag} --branch <branch> --url <url>\n"
                f"  or, for a phase with no product change worth a PR: {WORKFLOW_CMD} pr-record {phase_id} --waive --note \"why\"\n"
                f"nothing was written")


def _pr_draft_due(phase: dict) -> bool:
    """True while the phase is at its review: its REVIEW slice is in_progress or in_review, the phase is
    in_review, or its acceptance gate is open (`phase` may carry `slices`, as all_active_phases builds it). The
    drafts open when the review would pass, before the gate opens or the pass is recorded (P51-b1.F3). A REVIEW
    slice that is `pending` (e.g. a refused draft's plain|waive stop) is not due: its typed stop governs, and no
    replacement line prints (D120)."""
    if phase.get("status") == "in_review" or (phase.get("status") == "pending" and acceptance_gate_is_open(phase)):
        return True
    rid = f"{phase.get('id')}.REVIEW"
    slices = phase.get("slices")
    if isinstance(slices, list):
        review = next((s for s in slices if isinstance(s, dict) and s.get("id") == rid), None)
    else:
        sj = ACTIVE / str(phase.get("id")) / "slices" / rid / "slice.json"
        try:
            review = read_json(sj) if sj.is_file() else None
        except (OSError, ValueError):
            review = None
    return bool(review and review.get("status") in ("in_progress", "in_review"))


def pr_lines(phase: dict) -> list:
    """`next`'s PR lines for a phase with a `pr` block (silent without one): one `pr_branch=` per entry,
    `pr_waived=` when waived, and `pr_draft=due` while the phase is at its review with a branch unopened."""
    block = phase_pr(phase)
    if block is None:
        return []
    lines = [f"pr_branch={_pr_label(e)} base={_pr_shown_base(e, phase)} url={e.get('url') or 'none'}" for e in block["branches"]]
    waived = block.get("waived")
    if isinstance(waived, dict):
        lines.append(f"pr_waived={_one_line(waived.get('note') or '')}")
    elif any(not e.get("url") for e in block["branches"]) and _pr_draft_due(phase):
        lines.append(PR_DRAFT_DUE)
    return lines


def _pr_next_lines(phase_id) -> list:
    if not phase_id:
        return []
    try:
        return pr_lines(read_json(ACTIVE / phase_id / "phase.json"))
    except (OSError, ValueError, SystemExit):
        return []


# --- the PR after its draft opened (P52): pr-sync, pr-team, pr_open=, the archive hold -----------------
#
# `pr-sync` and `pr-team` are the engine's only network reads, both through the GitHub CLI and read-only
# (`gh pr view`, a GET `gh api`); the orchestrator runs them. Nothing else calls the network: `next`, the
# resume card and the archive hold read only what pr-sync last recorded on each branch entry.

PR_GH_TIMEOUT = 30  # seconds per gh call
PR_SYNC_FIELDS = "state,isDraft,mergedAt,baseRefName,headRefOid,reviewDecision"
PR_TEAM_SHOWN_LOGINS = 5


def _gh(argv: list, cwd=None):
    """`(stdout, None)` for a `gh <argv>` that exited 0, else `(None, why)` -- why naming the cause and the fix
    (install gh, gh auth login, the network). Never raises; never writes anything to GitHub (callers pass reads)."""
    exe = shutil.which("gh")
    if exe is None:
        return None, "gh (the GitHub CLI) is not installed or not on PATH -- install it (https://cli.github.com), then gh auth login"
    try:
        proc = subprocess.run([exe, *argv], cwd=str(cwd) if cwd else None, capture_output=True, text=True, timeout=PR_GH_TIMEOUT)
    except subprocess.TimeoutExpired:
        return None, f"gh {argv[0]} timed out after {PR_GH_TIMEOUT}s -- check the network, then re-run"
    except OSError as exc:
        return None, f"gh could not run ({_one_line(str(exc))}) -- reinstall it (https://cli.github.com)"
    if proc.returncode != 0:
        detail = _one_line((proc.stderr or proc.stdout or "").strip()) or f"exit {proc.returncode}"
        low = detail.lower()
        if "auth login" in low or "not logged" in low or "authentication" in low or "http 401" in low:
            return None, f"gh is not authenticated ({detail}) -- run gh auth login, then re-run"
        return None, f"gh {argv[0]} failed: {detail}"
    return proc.stdout, None


def _pr_gh_state(view: dict):
    """The lifecycle state for a `gh pr view --json` answer, or None when it is not one GitHub gives:
    MERGED -> merged, CLOSED -> closed, OPEN and isDraft -> draft, OPEN -> ready."""
    state = view.get("state")
    if state == "MERGED":
        return "merged"
    if state == "CLOSED":
        return "closed"
    if state == "OPEN":
        return "draft" if view.get("isDraft") is True else "ready"
    return None


def cmd_pr_sync(args: argparse.Namespace) -> None:
    """Read each recorded PR's lifecycle from GitHub (`gh pr view <url> --json ...`, read-only) and record it
    on its branch entry: state, synced_at, merged_at, and ready_at the first time it is seen ready or merged.
    All or nothing: any gh failure writes nothing and exits non-zero."""
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    repos = nested_repos()
    if args.repo and not repos:
        raise SystemExit("pr-sync --repo: refused -- a multi-repo host only; a single-repo host or a root install has one repo: drop --repo")
    if "pr" in data and phase_pr(data) is None:
        _ensure_pr(data)  # raises on a malformed block: never read or overwrite it
    block = phase_pr(data)
    entries = block["branches"] if block else []
    if not entries:
        print(f"pr_sync=none (phase {args.phase} records no PR branch) -- nothing to read")
        return
    hits = [e for e in entries if (args.repo is None or e.get("repo") == args.repo) and (args.branch is None or e.get("branch") == args.branch)]
    if not hits:
        asked = f"{args.repo or _pr_one_repo()}:{args.branch}" if args.branch else args.repo
        raise SystemExit(f"pr-sync: no recorded PR branch matches {asked} (recorded: {', '.join(_pr_label(e) for e in entries)}) -- nothing was written")
    read = []
    for entry in hits:
        if not entry.get("url"):
            continue
        out, why = _gh(["pr", "view", entry["url"], "--json", PR_SYNC_FIELDS], cwd=_pr_entry_path(entry, data))
        if why is None:
            try:
                view = json.loads(out)
            except ValueError:
                view = None
            state = _pr_gh_state(view) if isinstance(view, dict) else None
            if state is None:
                why = f"gh pr view answered something that is not a PR's state ({_one_line((out or '').strip())[:120] or 'empty'})"
        if why is not None:
            raise SystemExit(f"pr-sync: {_pr_label(entry)} ({entry['url']}): {why} -- nothing was written")
        read.append((entry, view, state))
    now = now_iso()
    lines = []
    for entry in hits:
        if not entry.get("url"):
            lines.append(f"pr_sync={_pr_label(entry)} state=unopened")
            continue
        _e, view, state = next(r for r in read if r[0] is entry)
        merged_at = view.get("mergedAt") if isinstance(view.get("mergedAt"), str) and view.get("mergedAt").strip() else None
        entry["state"] = state
        entry["synced_at"] = now
        if not entry.get("ready_at"):
            entry["ready_at"] = now if state in ("ready", "merged") else None
        entry["merged_at"] = merged_at
        gh_base = view.get("baseRefName") or "none"
        head = (view.get("headRefOid") or "")[:7] or "none"
        review = view.get("reviewDecision") or "none"
        lines.append(f"pr_sync={_pr_label(entry)} state={state} base={gh_base} head={head} review={review} merged_at={merged_at or 'none'}")
        recorded = _pr_shown_base(entry, data)
        if view.get("baseRefName") and view["baseRefName"] != recorded:
            lines.append(f"pr_sync_base={_pr_label(entry)} recorded={recorded} github={view['baseRefName']} -- GitHub's base differs from the "
                         f"record (advisory; nothing re-recorded): when GitHub's is right, {WORKFLOW_CMD} pr-branch {args.phase}"
                         f"{' --repo ' + entry['repo'] if entry.get('repo') else ''} --name {entry.get('branch')} --base {view['baseRefName']}")
    if read:
        write_json(pdir / "phase.json", data)
        append_event("pr_synced", phase=args.phase,
                     entries=[{"repo": e.get("repo"), "branch": e.get("branch"), "state": st} for e, _v, st in read])
        rebuild_index_and_state()
    for line in lines:
        print(line)


def _pr_origin_repo(path: Path):
    """`(host, "owner/repo")` parsed from the `origin` remote's URL (https, ssh or scp-like form), or None. No network."""
    proc = _git(["remote", "get-url", "origin"], cwd=path, check=False)
    url = proc.stdout.strip() if proc.returncode == 0 else ""
    m = (re.fullmatch(r"(?:https?|ssh|git)://(?:[^@/]+@)?([^/:]+)(?::\d+)?/([^/]+)/([^/]+?)(?:\.git)?/?", url)
         or re.fullmatch(r"(?:[^@/]+@)?([^/:]+):([^/]+)/([^/]+?)(?:\.git)?/?", url))
    return (m.group(1), f"{m.group(2)}/{m.group(3)}") if m else None


def _pr_people(identities: list) -> int:
    """How many people a list of `(name, email)` identities is, merged loosely: two identities sharing a
    (case-folded) name or email are one person."""
    parent = list(range(len(identities)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    first = {}
    for i, (name, email) in enumerate(identities):
        for key in (("n", name.strip().casefold()), ("e", email.strip().casefold())):
            if not key[1]:
                continue
            if key in first:
                parent[find(i)] = find(first[key])
            else:
                first[key] = i
    return len({find(i) for i in range(len(identities))})


def _pr_is_bot(name: str, email: str) -> bool:
    """A service identity, never a person: a `[bot]` name or address, or a GitHub service address
    (`noreply@github.com`, `*@noreply.github.com`) that is not a user's `*@users.noreply.github.com`."""
    name, email = name.strip().casefold(), email.strip().casefold()
    if name.endswith("[bot]") or "[bot]@" in email:
        return True
    return email.endswith("noreply.github.com") and not email.endswith("@users.noreply.github.com") or email == "noreply@github.com"


def _pr_team_detect(target: dict) -> dict:
    """Read-only evidence for solo or team in one repo: the collaborators API where it answers (it needs
    write access, so a refusal or a missing gh makes it `unavailable`, never an error) and the distinct
    non-bot commit authors on the default branch. Detected `team` when either shows more than one
    person, `solo` when every source that answered shows exactly one, else `unknown`."""
    path = target["path"]
    logins = None
    origin = _pr_origin_repo(path)
    if origin is not None:
        host, slug = origin
        argv = ["api", f"repos/{slug}/collaborators", "--paginate", "--jq", ".[].login"]
        if host != "github.com":
            argv[1:1] = ["--hostname", host]
        out, why = _gh(argv, cwd=path)
        if why is None:
            logins = sorted({ln.strip() for ln in out.splitlines() if ln.strip() and not ln.strip().casefold().endswith("[bot]")}, key=str.casefold)
    authors = None
    default = _repo_default_branch(path, target.get("default"))
    ref = _pr_diff_ref(path, default)[0] if default else None
    if ref:
        proc = _git(["log", ref, "--format=%aN%x09%aE"], cwd=path, check=False)
        if proc.returncode == 0:
            idents = set()
            for ln in proc.stdout.splitlines():
                name, _tab, email = ln.partition("\t")
                if (name.strip() or email.strip()) and not _pr_is_bot(name, email):
                    idents.add((name, email))
            authors = _pr_people(sorted(idents)) if idents else None
    counts = [n for n in ((len(logins) if logins else None), authors) if n]
    detected = "team" if any(n > 1 for n in counts) else "solo" if counts else "unknown"
    if logins is not None:
        shown_logins = ", ".join(logins[:PR_TEAM_SHOWN_LOGINS]) + (f" +{len(logins) - PR_TEAM_SHOWN_LOGINS} more" if len(logins) > PR_TEAM_SHOWN_LOGINS else "")
        collab = f"collaborators: {len(logins)}" + (f" ({shown_logins})" if logins else "")
    else:
        collab = "collaborators: unavailable"
    return {"detected": detected, "evidence": f"{collab}; authors: {authors if authors else 'unavailable'}"}


def cmd_pr_team(args: argparse.Namespace) -> None:
    """Bare: detect, read-only, whether a repo's PRs are a solo owner's or a team's, beside what is recorded.
    `--record solo|team --evidence "..."` (the orchestrator's, after the operator's word): record it in the PR
    rules record's `ownership` list, replacing that repo's earlier record."""
    repos = nested_repos()
    if args.record is None:
        if args.evidence is not None:
            raise SystemExit("pr-team --evidence belongs to --record solo|team")
        target = _pr_target({}, args.repo, "pr-team")
        found = _pr_team_detect(target)
        recorded = pr_team_mode(target["repo"]) or "none"
        print(f"pr_team={target['label']} recorded={recorded} detected={found['detected']} evidence=\"{found['evidence']}\"")
        return
    if repos:
        names = [r["name"] for r in repos]
        if not args.repo:
            raise SystemExit(f"pr-team --record: this multi-repo host needs --repo <name> (registered: {', '.join(names)}) -- nothing was written")
        if args.repo not in names:
            raise SystemExit(f"pr-team --record --repo {args.repo}: no registered repo has that name (registered: {', '.join(names)}) -- nothing was written")
    elif args.repo:
        raise SystemExit("pr-team --repo: refused -- a multi-repo host only; a single-repo host or a root install has one repo: drop --repo")
    evidence = _one_line(args.evidence or "")
    if not evidence:
        raise SystemExit("pr-team --record needs --evidence \"<what showed it: the detection line, the operator's word>\" -- nothing was written")
    raw, where = _pr_rules_source()
    if raw == "unreadable" or (raw is not None and pr_rules_problems(raw)):
        raise SystemExit(f"pr-team --record: {where} is malformed; fix it first (run: {WORKFLOW_CMD} check --no-rebuild) -- nothing was written")
    record = dict(raw) if raw is not None else {"decided": []}
    repo = args.repo or None
    old = [o for o in (record.get("ownership") or []) if o.get("repo") == repo]
    entry = {"repo": repo, "mode": args.record, "evidence": evidence, "at": now_iso()}
    record["ownership"] = [o for o in (record.get("ownership") or []) if o.get("repo") != repo] + [entry]
    path = _pr_rules_write(record, "pr-team --record")
    append_event("pr_team_recorded", repo=repo, mode=args.record)
    label = repo or _pr_one_repo()
    print(f"pr_team={label} recorded={args.record} evidence=\"{evidence}\"")
    print(f"pr-team: {'replaced' if old else 'recorded'} -- {label} is {args.record} ({shown(path)})")


def _pr_open_entries(phase: dict) -> list:
    """A phase's recorded PRs that are still open business: the entries with a URL whose `state` is not
    merged, in an unwaived `pr` block. Empty for a phase without a block (pre-P51), a waived one, or all merged."""
    block = phase_pr(phase)
    if block is None or isinstance(block.get("waived"), dict):
        return []
    return [e for e in block["branches"] if e.get("url") and e.get("state") != "merged"]


def _pr_open_hint(phase_id: str, phase: dict, entry: dict, short: bool = False) -> str:
    """What to do about one open PR of a done phase, never from the network: the close (the pr skill's) is
    due on an accepted gate; a waived gate's draft waits on the operator's word `close`; a ready PR waits on
    the team's merge (a solo repo: the close's merge is due); a closed-unmerged one holds archiving."""
    state = entry.get("state")
    acceptance = phase_acceptance(phase)
    accepted = bool(acceptance and acceptance.get("required") is True and acceptance.get("cleared_at"))
    mode = pr_team_mode(entry.get("repo"))
    sync = f"pr-sync {phase_id}"
    if state == "closed":
        return ("closed unmerged; holds archiving" if short else
                f"closed without merging: it holds archiving -- reopen it on GitHub and {sync}, or phase archive {phase_id} --force")
    if state == "ready":
        if mode == "solo":
            return "solo: merge due" if short else f"solo repo: the close's merge is due (pr skill; {sync} first)"
        if short:
            return "awaiting the team's merge"
        return f"waiting on the team's merge ({sync} sees it land" + (")" if mode == "team" else "; solo or team unrecorded: pr-team)")
    # draft, or never synced
    if accepted:
        return "close due" if short else f"the close is due (pr skill; {sync} first)"
    return ("the operator's word close" if short else
            f"a waived-gate draft: the operator's word `close` runs the pr skill's close ({sync} first)")


def pr_open_items(phases: list) -> list:
    """`[(phase_id, phase, entry)]` for every done phase (phase.json data, as all_active_phases or read_json
    gives it) with an open PR (`_pr_open_entries`), in the order given."""
    items = []
    for phase in phases:
        if isinstance(phase, dict) and phase.get("status") == "done":
            items.extend((phase.get("id"), phase, e) for e in _pr_open_entries(phase))
    return items


def pr_open_lines(index: dict) -> list:
    """`next`'s `pr_open=<P> <label> state=<s|unsynced> url=<url> -- <hint>` lines, one per open PR of every
    done, unarchived active phase (read from index.json's active_phases and each phase.json). Never the network."""
    phases = []
    for p in index.get("active_phases", []):
        if p.get("status") != "done":
            continue
        try:
            phases.append(read_json(ROOT / p["path"] / "phase.json"))
        except (OSError, ValueError, KeyError):
            continue
    return [f"pr_open={pid} {_pr_label(e)} state={e.get('state') or 'unsynced'} url={e.get('url')} -- {_pr_open_hint(pid, ph, e)}"
            for pid, ph, e in pr_open_items(phases)]


# --- stacked PRs (P52): a phase's PR based on another open PR's branch ---------------------------

def _pr_archived_phase_data() -> list:
    """Every archived phase.json, read cheaply; an unreadable one is skipped, never fatal."""
    out = []
    if not ARCHIVED.is_dir():
        return out
    for d in sorted(ARCHIVED.iterdir()):
        try:
            data = read_json(d / "phase.json")
        except (OSError, ValueError):
            continue
        if isinstance(data, dict):
            out.append(data)
    return out


def _pr_lower_merged_record(phases: list, repo, branch: str) -> bool:
    """True when some phase's `pr` block (active or archived) records `(repo, branch)` with state=merged."""
    for data in phases:
        block = phase_pr(data)
        if block and any(e.get("repo") == repo and e.get("branch") == branch and e.get("state") == "merged"
                         for e in block["branches"]):
            return True
    return False


def _pr_checkout_of(path: Path, branch: str):
    """The worktree path holding `branch` checked out (from `git worktree list`), else None."""
    try:
        entries = _worktree_entries(cwd=path)
    except (SystemExit, OSError, Exception):  # noqa: BLE001 - a git error only drops the hint
        return None
    return next((Path(p) for p, ref in entries if ref == f"refs/heads/{branch}"), None)


def _pr_stack_check(phase_id: str, phase: dict, entry: dict, lower_phases) -> tuple:
    """`(lower, steps)` for one stacked entry needing action, else None: `merged` (a phase records the base
    branch merged, or its tip -- not the default tip itself -- is an ancestor of the default's tip), `gone`
    (no local or origin ref of the base), `moved` (the base's tip is not in the dependent branch). Local refs
    only, never the network. `lower_phases` is a zero-argument callable giving active + archived phase data."""
    branch = entry.get("branch")
    if not branch or entry.get("state") == "merged":
        return None
    path = _pr_entry_path(entry, phase)
    if path is None or not Path(path).is_dir() or not _git_available(cwd=path):
        return None
    repo = entry.get("repo")
    reg = next((r for r in nested_repos() if r.get("name") == repo), None) if repo else None
    default = _repo_default_branch(path, reg.get("default_branch") if reg else None)
    base = _pr_read_base(path, entry.get("base"))
    if not default or not isinstance(base, str) or not base or base == default:
        return None
    default_tip = next((r for r in (f"origin/{default}", default)
                        if _rev_parse(f"refs/{'remotes/' if r.startswith('origin/') else 'heads/'}{r}", cwd=path)), None)
    base_tip = _pr_branch_tip(path, base)
    merged = _pr_lower_merged_record(lower_phases(), repo, base)
    if not merged and base_tip and default_tip:
        merged = (_rev_parse(base_tip, cwd=path) != _rev_parse(default_tip, cwd=path)
                  and _is_ancestor(path, base_tip, default_tip))
    where = _pr_checkout_of(path, branch)
    git = f"git -C {where or path}"
    switch = "" if where else f"{git} switch {branch}; "
    repo_flag = f" --repo {repo}" if repo else ""
    if merged or base_tip is None:
        url = entry.get("url")
        steps = [f"git -C {where or path} fetch origin", f"{switch}{git} merge --no-ff origin/{default}", f"{git} push"]
        if url:
            m = re.search(r"/pull/(\d+)", url)
            steps.append(f"gh pr edit {m.group(1) if m else url} --base {default}")
        steps.append(f"{WORKFLOW_CMD} pr-branch {phase_id}{repo_flag} --name {branch} --base {default}")
        return ("merged" if merged else "gone"), "; ".join(steps)
    dep_tip = _pr_branch_tip(path, branch)
    if dep_tip is None:
        return None
    # moved: the base's origin copy or its local branch holds commits the dependent lacks; merge the origin
    # copy when it is the one ahead (a teammate's push), else the local branch (an unpushed lower fix)
    ahead = [ref for full, ref in ((f"refs/remotes/origin/{base}", f"origin/{base}"), (f"refs/heads/{base}", base))
             if _rev_parse(full, cwd=path) and not _is_ancestor(path, ref, dep_tip)]
    if not ahead:
        return None
    return "moved", f"{switch}{git} merge --no-ff {ahead[0]}; {git} push"


def pr_stack_items(phases: list) -> list:
    """`[(phase_id, entry, base, lower, steps)]` for every stacked PR entry (a URL or a branch, base not the
    repo's default) of every active phase given (done or not) whose lower PR merged, vanished or moved.
    A missing checkout, a git error or an unreadable phase skips that entry silently."""
    cache = {}

    def lower_phases():
        if "all" not in cache:
            cache["all"] = [p for p in phases if isinstance(p, dict)] + _pr_archived_phase_data()
        return cache["all"]

    items = []
    for phase in phases:
        block = phase_pr(phase)
        if block is None or isinstance(block.get("waived"), dict):
            continue
        for entry in block["branches"]:
            if not (entry.get("url") or entry.get("branch")):
                continue
            try:
                hit = _pr_stack_check(phase.get("id"), phase, entry, lower_phases)
            except Exception:  # noqa: BLE001 - one entry's git trouble never stops `next`
                hit = None
            if hit:
                items.append((phase.get("id"), entry, _pr_shown_base(entry, phase), hit[0], hit[1]))
    return items


def pr_stack_lines(index: dict) -> list:
    """`next`'s `pr_stack=<P> <label> base=<lower> lower=merged|gone|moved -- <steps>` lines, for every active
    phase in index.json (done or not). Merge, never rebase; never a force-push; never the network."""
    phases = []
    for p in index.get("active_phases", []):
        try:
            phases.append(read_json(ROOT / p["path"] / "phase.json"))
        except (OSError, ValueError, KeyError):
            continue
    return [f"pr_stack={pid} {_pr_label(e)} base={base} lower={lower} -- {steps}" for pid, e, base, lower, steps in pr_stack_items(phases)]


# --- the PR rules record (decided team-rule conflicts) ------------------------------------------

def pr_rules_problems(raw, label: str = "pr_rules") -> list:
    """Every way a PR rules record breaks its shape: `{"decided": [{"rule", "choice", "note", "at"[, "repo"]}]}`,
    `choice` team or ours, `rule` and `at` non-empty strings, `note` a string or null, `repo` null or a name;
    plus (P52) an optional `"ownership": [{"repo", "mode", "evidence", "at"}]`, `mode` solo or team, one per repo."""
    if not isinstance(raw, dict) or "decided" not in raw or any(k not in ("decided", "ownership") for k in raw):
        return [f"{label} must be an object with decided (a list of decisions) and optionally ownership (a list of solo/team records)"]
    decided = raw["decided"]
    if not isinstance(decided, list):
        return [f"{label}.decided must be a list of decisions"]
    problems = _pr_ownership_problems(raw["ownership"], f"{label}.ownership") if "ownership" in raw else []
    for i, entry in enumerate(decided):
        lab = f"{label}.decided[{i}]"
        if not isinstance(entry, dict):
            problems.append(f"{lab} is not an object")
            continue
        gone = [k for k in PR_RULE_KEYS if k not in entry]
        extra = sorted(str(k) for k in entry if k not in PR_RULE_KEYS + PR_RULE_OPTIONAL_KEYS)
        if gone:
            problems.append(f"{lab}: missing field(s) {', '.join(gone)}")
        if extra:
            problems.append(f"{lab}: unknown field(s) {', '.join(extra)} (a decision has {', '.join(PR_RULE_KEYS)}, and optionally repo)")
        for key in ("rule", "at"):
            if key in entry and not (isinstance(entry[key], str) and entry[key].strip()):
                problems.append(f"{lab}.{key} must be a non-empty string")
        if "choice" in entry and entry["choice"] not in PR_RULE_CHOICES:
            problems.append(f"{lab}.choice {entry['choice']!r} is not one of {', '.join(PR_RULE_CHOICES)}")
        if entry.get("note") is not None and not isinstance(entry.get("note"), str):
            problems.append(f"{lab}.note must be a string or null")
        repo = entry.get("repo")
        if repo is not None and not (isinstance(repo, str) and NESTED_REPO_NAME.fullmatch(repo)):
            problems.append(f"{lab}.repo {repo!r} must be null or a registered repo's name")
    return problems


def _pr_ownership_problems(ownership, label: str) -> list:
    """Every way the record's `ownership` list breaks its shape: entries of exactly PR_OWNERSHIP_KEYS, `mode`
    solo or team, `evidence` and `at` non-empty strings, `repo` null or a registered repo's name, one per repo."""
    if not isinstance(ownership, list):
        return [f"{label} must be a list of solo/team records"]
    problems, seen = [], set()
    names = _pr_registry_names()
    for i, entry in enumerate(ownership):
        lab = f"{label}[{i}]"
        if not isinstance(entry, dict):
            problems.append(f"{lab} is not an object")
            continue
        gone = [k for k in PR_OWNERSHIP_KEYS if k not in entry]
        extra = sorted(str(k) for k in entry if k not in PR_OWNERSHIP_KEYS)
        if gone:
            problems.append(f"{lab}: missing field(s) {', '.join(gone)}")
        if extra:
            problems.append(f"{lab}: unknown field(s) {', '.join(extra)} (a record has exactly {', '.join(PR_OWNERSHIP_KEYS)})")
        if "mode" in entry and entry["mode"] not in PR_OWNERSHIP_MODES:
            problems.append(f"{lab}.mode {entry['mode']!r} is not one of {', '.join(PR_OWNERSHIP_MODES)}")
        for key in ("evidence", "at"):
            if key in entry and not (isinstance(entry[key], str) and entry[key].strip()):
                problems.append(f"{lab}.{key} must be a non-empty string")
        repo = entry.get("repo")
        if repo is not None and not (isinstance(repo, str) and NESTED_REPO_NAME.fullmatch(repo)):
            problems.append(f"{lab}.repo {repo!r} must be null or a registered repo's name")
        elif repo is not None and names is None:
            problems.append(f"{lab}.repo {repo!r}: this install has no repos registry, so repo is null (the host, or the root repo)")
        elif repo is not None and repo not in names:
            problems.append(f"{lab}.repo {repo!r} names no registered repo (registered: {', '.join(map(str, names))})")
        if repo in seen:
            problems.append(f"{lab}: {repo or 'the repo'} is recorded twice (one record per repo; a re-record replaces it)")
        seen.add(repo)
    return problems


def _pr_rules_source():
    """`(raw, where)`: the nested marker's `pr_rules` value, or at root works/pr-rules.json's parsed
    content; raw is None when absent, and the string "unreadable" names a root file that is not JSON."""
    if NESTED is not None:
        return NESTED.get("pr_rules"), shown(ROOT / NESTED_MARKER)
    path = WORKS / PR_RULES_FILE
    if not path.is_file():
        return None, shown(path)
    try:
        return json.loads(path.read_text(encoding="utf-8")), shown(path)
    except (OSError, ValueError):
        return "unreadable", shown(path)


def load_pr_rules() -> list:
    """The operator's decided team-rule conflicts: the nested marker's `pr_rules.decided`, or at root
    works/pr-rules.json's. `[]` when absent or malformed (validate reports a malformed record). The team's
    rules themselves are never recorded: the `pr` skill reads them live from the repo each time."""
    raw, _where = _pr_rules_source()
    if raw is None or raw == "unreadable" or pr_rules_problems(raw):
        return []
    return list(raw["decided"])


def load_pr_ownership() -> list:
    """The record's `ownership` list (`pr-team --record`); `[]` when absent or the record is malformed."""
    raw, _where = _pr_rules_source()
    if raw is None or raw == "unreadable" or pr_rules_problems(raw):
        return []
    return list(raw.get("ownership") or [])


def pr_team_mode(repo=None):
    """"solo" or "team" as recorded for `repo` (None: a single-repo host's or a root install's one repo), else
    None (never recorded, or the record is malformed). A multi-repo host's null record answers for any repo it
    does not name. Read-only, no network: what `pr_open=`, the close and the stacking advice consult."""
    records = load_pr_ownership()
    hit = next((r for r in records if r.get("repo") == repo), None)
    if hit is None and repo is not None:
        hit = next((r for r in records if r.get("repo") is None), None)
    return hit.get("mode") if hit else None


def _pr_rules_write(record: dict, cmd: str):
    """Write the PR rules record where it lives (the nested marker's `pr_rules` key, or at root
    works/pr-rules.json) after checking it; SystemExit (nothing written) when it would be malformed.
    Returns the path written."""
    if NESTED is not None:
        path = ROOT / NESTED_MARKER
        marker = read_json(path)
        marker["pr_rules"] = record
        problems = nested_marker_problems(marker) + pr_rules_problems(record)
        if problems:
            raise SystemExit(f"{cmd}: refused -- the marker would be malformed: {'; '.join(problems)}")
        write_json(path, marker)
        return path
    problems = pr_rules_problems(record)
    if problems:
        raise SystemExit(f"{cmd}: refused -- the record would be malformed: {'; '.join(problems)}")
    path = WORKS / PR_RULES_FILE
    write_json(path, record)
    return path


def pr_rules_validate(errors: list) -> None:
    """validate's rows for the PR rules record, where one exists. Errors, never marker problems: a
    malformed record must not stop every other command, it only empties `load_pr_rules`."""
    raw, where = _pr_rules_source()
    if raw is None:
        return
    if raw == "unreadable":
        errors.append(f"{where} cannot be read as JSON")
        return
    errors.extend(f"{where}: {p}" for p in pr_rules_problems(raw))


def cmd_pr_rules_decide(args: argparse.Namespace) -> None:
    """Show (bare) or record (--rule --choice) one team-rule conflict the operator decided -- the record
    update-workspace and the installer keep; the team's rules themselves are read live, never stored."""
    repos = nested_repos()
    if args.repo is not None:
        if not repos:
            raise SystemExit("pr-rules-decide --repo: refused -- a multi-repo host only; drop --repo")
        if args.repo not in [r["name"] for r in repos]:
            raise SystemExit(f"pr-rules-decide --repo {args.repo}: no registered repo has that name")
    if args.rule is None:
        if args.choice is not None or args.note is not None or args.repo is not None:
            raise SystemExit("pr-rules-decide: --choice, --note and --repo belong to --rule \"<what>\"")
        decided = load_pr_rules()
        print(f"pr_rules={len(decided)} decided")
        for d in decided:
            print(f"  {d.get('repo') or 'every repo'}: {_one_line(d.get('rule'))} -> {d.get('choice')}"
                  + (f" ({_one_line(d.get('note'))})" if d.get("note") else "") + f" [{d.get('at')}]")
        return
    if not args.rule.strip() or args.choice is None:
        raise SystemExit("pr-rules-decide needs --rule \"<what the team rule says>\" and --choice team|ours")
    raw, where = _pr_rules_source()
    if raw == "unreadable" or (raw is not None and pr_rules_problems(raw)):
        raise SystemExit(f"pr-rules-decide: {where} is malformed; fix it first (run: {WORKFLOW_CMD} check --no-rebuild) -- nothing was written")
    record = dict(raw) if raw is not None else {"decided": []}  # keeps `ownership` (P52) as it stands
    record["decided"] = list(record["decided"])
    entry = {"rule": args.rule.strip(), "choice": args.choice, "note": (args.note or "").strip() or None, "at": now_iso()}
    if args.repo is not None:
        entry["repo"] = args.repo
    replaced = [d for d in record["decided"] if d.get("rule") == entry["rule"] and d.get("repo") == entry.get("repo")]
    record["decided"] = [d for d in record["decided"] if d not in replaced] + [entry]
    path = _pr_rules_write(record, "pr-rules-decide")
    append_event("pr_rule_decided", rule=entry["rule"], choice=entry["choice"], repo=entry.get("repo"))
    print(f"pr-rules-decide: {'replaced' if replaced else 'recorded'} -- {entry.get('repo') or 'every repo'}: {entry['rule']} -> {entry['choice']} ({shown(path)})")
    print(f"pr_rules={len(record['decided'])} decided")


# --- pr-check: size, body budgets, leaks and heading order --------------------------------------

_PR_FENCE_OPEN = re.compile(r"^ {0,3}(`{3,}|~{3,})\s*([^\s`]*)")
_PR_FENCE_CLOSE = re.compile(r"^ {0,3}(`{3,}|~{3,})\s*$")
_PR_H2 = re.compile(r"^ {0,3}##(?!#)[ \t]+(.*?)[ \t]*#*[ \t]*$")
_PR_COMMENT = re.compile(r"<!--.*?(?:-->|\Z)", re.S)
_PR_DETAILS_TAG = re.compile(r"<(/?)details\b[^>]*>", re.I)
_PR_IMAGE = re.compile(r"!\[([^\]]*)\]\([^)]*\)")
_PR_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_PR_TAG = re.compile(r"</?[A-Za-z][A-Za-z0-9-]*(?:\s[^<>]*)?/?>")
# Leaks fail the check. Phase ids are case-sensitive on purpose: a percentile written `p95` passes, while
# `P95`, or a version like `P5`, fails even inside a code span -- authors write those another way (pr skill).
# A bare `S<n>` counts only in an ID position (after "slice", or in a run like `S6-S12` / `S6, S7`), so an
# `S3 bucket` passes; `DECOMP` always counts; a bare `REVIEW` counts only with its phase prefix.
_PR_LEAKS = (
    ("slice_id", re.compile(r"\bP\d+(?:-[a-z0-9]+)?\.(?:S\d+|F\d+|C\d+|K\d+|DECOMP\d*|REVIEW)\b")),
    ("slice_id", re.compile(r"\bDECOMP\d*\b")),
    ("slice_id", re.compile(r"(?i:\bslices?)[ \t]+S\d+\b")),
    ("slice_id", re.compile(r"\bS\d+[ \t]*(?:[\u2013\u2014/,-]|\band\b|\bto\b)[ \t]*S\d+\b")),
    ("phase_id", re.compile(r"\bP\d+(?:-[a-z0-9]{2,4})?\b")),
    ("phase_id", re.compile(r"\bP-[a-z0-9]{4}\b")),
    ("workflow_path", re.compile(r"(?<![\w./-])workflow/")),
    ("workspace_file", re.compile(r"(?<![\w.-])(?:phase|result|plan|intent)\.md\b|(?<![\w.-])(?:slice|phase)\.json\b")),
)
# Workspace vocabulary: a warning, never a fail ("slice" is also an ordinary word, a Go slice).
_PR_LEAK_WARNINGS = (
    ("orchestrator", re.compile(r"\borchestrators?\b", re.I)),
    ("executor", re.compile(r"\bexecutors?\b", re.I)),
    ("phase notebook", re.compile(r"\bphase notebooks?\b", re.I)),
    ("slice", re.compile(r"\bslices?\b", re.I)),
)
PR_LEAKS_SHOWN = 10


def _pr_fenced(lines: list) -> list:
    """`[(line, in_fence, mermaid)]`: each line with whether it sits inside a fenced code block (the
    fence lines included) and whether that block is Mermaid source."""
    out, fence = [], None
    for ln in lines:
        if fence is None:
            m = _PR_FENCE_OPEN.match(ln)
            if m:
                fence = (m.group(1)[0], len(m.group(1)), m.group(2).lower().startswith("mermaid"))
                out.append((ln, True, fence[2]))
            else:
                out.append((ln, False, False))
            continue
        out.append((ln, True, fence[2]))
        m = _PR_FENCE_CLOSE.match(ln)
        if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1]:
            fence = None
    return out


def _pr_h2(text: str) -> list:
    """The H2 headings of a markdown text, in order: outside fenced code and HTML comments."""
    lines = _PR_COMMENT.sub("", text).split("\n")
    return [m.group(1) for ln, fenced, _mm in _pr_fenced(lines) if not fenced for m in [_PR_H2.match(ln)] if m]


def _pr_norm(heading: str) -> str:
    return " ".join(re.sub(r"[^\w\s]", " ", heading.lower()).split())


def _pr_drop_details(text: str) -> str:
    """`text` without its <details>...</details> blocks (nested ones included; an unclosed one runs to the end)."""
    out, depth, pos = [], 0, 0
    for m in _PR_DETAILS_TAG.finditer(text):
        if m.group(1):  # </details>
            if depth:
                depth -= 1
                if depth == 0:
                    pos = m.end()
            continue
        if depth == 0:
            out.append(text[pos:m.start()])
        depth += 1
    if depth == 0:
        out.append(text[pos:])
    return "".join(out)


def _pr_reading_chars(lines: list) -> int:
    """Reading chars of markdown lines (comments and Mermaid fences already gone): <details> blocks
    dropped, link and image URLs dropped (their text kept), HTML tags dropped (their text kept), and
    each whitespace run counted as one char."""
    text = _pr_drop_details("\n".join(lines))
    text = _PR_IMAGE.sub(r"\1", text)
    text = _PR_LINK.sub(r"\1", text)
    text = _PR_TAG.sub("", text)
    return len(" ".join(text.split()))


def pr_body_measure(text: str) -> dict:
    """The body's three budgeted counts: `whole` (raw source chars), `visible` (reading chars outside
    <details>) and `first_screen` (the visible reading chars before the first H2 after `## Review` -- the
    series line, Summary and Review; with no `## Review`, through the first H2 section)."""
    lines = [ln for ln, _fenced, mermaid in _pr_fenced(_PR_COMMENT.sub("", text).split("\n")) if not mermaid]
    heads = [i for i, (ln, fenced, _mm) in enumerate(_pr_fenced(lines)) if not fenced and _PR_H2.match(ln)]
    review = next((i for i in heads if _pr_norm(_PR_H2.match(lines[i]).group(1)) == "review"), None)
    after = [i for i in heads if i > (review if review is not None else (heads[0] if heads else len(lines)))]
    cut = after[0] if after else len(lines)
    return {"first_screen": _pr_reading_chars(lines[:cut]), "visible": _pr_reading_chars(lines), "whole": len(text)}


def pr_leaks(text: str, where: str) -> tuple:
    """`(fails, warns)`: each fail `(kind, match, where:line)`, each warning `(term, where:line)`."""
    fails, warns = [], []
    for n, line in enumerate(text.split("\n"), 1):
        taken = []
        for kind, rx in _PR_LEAKS:
            for m in rx.finditer(line):
                if any(m.start() < e and s < m.end() for s, e in taken):
                    continue
                taken.append((m.start(), m.end()))
                fails.append((kind, m.group(0), f"{where}:{n}"))
        for term, rx in _PR_LEAK_WARNINGS:
            for _m in rx.finditer(line):
                warns.append((term, f"{where}:{n}"))
    return fails, warns


def pr_team_template(path: Path):
    """`(relpath, [H2 headings])` of the repo's PR template, first hit wins (PR_TEMPLATE_DIRS, the file
    name read case-insensitively, then a lone file in .github/PULL_REQUEST_TEMPLATE/), or `(None, None)`.
    `(<dir>, None)` names a template directory holding several files: no single template applies."""
    for d in PR_TEMPLATE_DIRS:
        base = path / d
        try:
            names = sorted(os.listdir(base))
        except OSError:
            continue
        for name in names:
            if name.lower() == PR_TEMPLATE_NAME and (base / name).is_file():
                rel = name if d == "." else f"{d}/{name}"
                try:
                    return rel, _pr_h2((base / name).read_text(encoding="utf-8", errors="replace"))
                except OSError:
                    continue
    multi = path / PR_TEMPLATE_MULTI_DIR
    try:
        files = sorted(f for f in os.listdir(multi) if (multi / f).is_file() and not f.startswith("."))
    except OSError:
        files = []
    if len(files) == 1:
        return f"{PR_TEMPLATE_MULTI_DIR}/{files[0]}", _pr_h2((multi / files[0]).read_text(encoding="utf-8", errors="replace"))
    if len(files) > 1:
        return f"{PR_TEMPLATE_MULTI_DIR}/", None
    return None, None


def pr_heading_problems(body_heads: list, expected) -> list:
    """`missing:<h>` / `order:<h>` for each expected H2 the body lacks, or holds out of order; extra H2s
    anywhere are fine."""
    norm = [_pr_norm(h) for h in body_heads]
    problems, pos = [], -1
    for h in expected:
        n = _pr_norm(h)
        idx = next((i for i in range(pos + 1, len(norm)) if norm[i] == n), None)
        if idx is None:
            problems.append(f"{'order' if n in norm else 'missing'}:{h}")
        else:
            pos = idx
    return problems


def _pr_generated_paths(path: Path, tip: str, paths: list) -> set:
    """The paths `git check-attr linguist-generated` marks set or true, read at the branch tip's
    attributes (`--source`, git >= 2.40), else the working tree's."""
    if not paths:
        return set()
    stdin = "\0".join(paths) + "\0"
    for cmd in (["check-attr", "--source", tip, "-z", "--stdin", "linguist-generated"], ["check-attr", "-z", "--stdin", "linguist-generated"]):
        try:
            proc = subprocess.run(["git", *cmd], cwd=str(path), input=stdin, capture_output=True, text=True, timeout=60)
        except Exception:  # noqa: BLE001 - no attributes readable: nothing is excluded as generated
            return set()
        if proc.returncode == 0:
            break
    else:
        return set()
    toks = proc.stdout.split("\0")
    return {toks[i] for i in range(0, len(toks) - 2, 3) if toks[i + 2] in ("set", "true")}


def pr_size(path: Path, base: str, branch: str):
    """`(size, None)` or `(None, why)`: the changed hand-written lines (added + deleted) of
    `git diff --numstat <base>...<branch>`, excluding linguist-generated paths, lockfiles and whole-file
    deletions; binary rows are excluded and counted. Tests and migrations count."""
    tip = _pr_branch_tip(path, branch)
    if tip is None:
        return None, f"branch {branch} is not in {path} (no local branch, no origin/{branch})"
    if not _rev_parse(base, cwd=path):
        return None, f"base {base} is not a commit in {path}"
    rng = f"{base}...{tip}"
    num = _git(["diff", "--numstat", "-z", "-M", rng], cwd=path, check=False)
    if num.returncode != 0:
        return None, f"git diff {rng} failed: {(num.stderr or '').strip()}"
    deleted = set(t for t in _git(["diff", "--name-only", "-z", "-M", "--diff-filter=D", rng], cwd=path, check=False).stdout.split("\0") if t)
    rows, toks, i = [], num.stdout.split("\0"), 0
    while i < len(toks):
        tok = toks[i]
        i += 1
        if not tok:
            continue
        parts = tok.split("\t")
        if len(parts) < 3:
            continue
        added, removed, p = parts[0], parts[1], parts[2]
        if not p:  # a rename or copy: the old path, then the new one, as their own tokens
            p = toks[i + 1] if i + 1 < len(toks) else ""
            i += 2
        rows.append((added, removed, p))
    generated = _pr_generated_paths(path, tip, [p for _a, _r, p in rows])
    size = {"lines": 0, "files": 0, "generated": 0, "lockfiles": 0, "deleted": 0, "binary": 0, "tip": tip}
    for added, removed, p in rows:
        if p in deleted:
            size["deleted"] += 1
        elif p in generated:
            size["generated"] += 1
        elif posixpath.basename(p) in PR_LOCKFILES:
            size["lockfiles"] += 1
        elif added == "-" or removed == "-":
            size["binary"] += 1
        else:
            size["lines"] += int(added) + int(removed)
            size["files"] += 1
    return size, None


def _pr_where(path: Path, pdir) -> str:
    if pdir is None:
        return str(path)
    try:
        return path.resolve().relative_to(pdir.resolve()).as_posix()
    except ValueError:
        return str(path)


def _pr_check_one(pdir, data: dict, entry: dict, body_arg, limit=None) -> tuple:
    """`(lines, status)` for one recorded branch: size, body budgets, leaks, headings. status is
    pass, warn or fail. A missing body is never a pass: a missing `--body` file fails, a missing default
    body warns (the size read still runs). `pdir` is None on the by-hand route (no phase, `--body`).
    The size is information (`size_status=info`) unless the team set a limit (`limit`, from `--limit`):
    then it is `ok` within it, and `over` past it, a warning answered by a split or a named exception."""
    repo = entry.get("repo")
    lines = [f"pr_check={_pr_label(entry)} base={_pr_shown_base(entry, data)}"]
    if entry.get("note"):
        lines.append(f"note={entry['note']}")
    status = {"v": "pass"}

    def mark(level):
        order = ("pass", "warn", "fail")
        if order.index(level) > order.index(status["v"]):
            status["v"] = level

    if repo is not None:
        reg = next((r for r in nested_repos() if r["name"] == repo), None)
        path, why = _phase_repo_path(reg, data) if reg else (None, f"{repo} is not a registered repo")
    else:
        path, why = (HOST_ROOT if NESTED is not None else ROOT), None
    # Size: against origin/<base> when it exists (what GitHub diffs), else the local <base>
    if path is None:
        size, why_size = None, why
    else:
        diff_full, diff_shown = _pr_diff_ref(path, entry.get("base"))
        if diff_full is None:
            name = _pr_read_base(path, entry.get("base"))
            size, why_size = None, f"base {name} is neither origin/{name} nor a local branch in {path}"
        else:
            lines.append(f"diff_base={diff_shown}")
            size, why_size = pr_size(path, diff_full, entry.get("branch"))
    if size is None:
        lines.append(f"size=unknown ({why_size})")
        mark("warn")
    else:
        n = size["lines"]
        if limit is None:
            lines.append(f"size={n} size_status=info")
        else:
            lines.append(f"size={n} limit={limit} size_status={'ok' if n <= limit else 'over'}")
        excluded = size["generated"] + size["lockfiles"] + size["deleted"] + size["binary"]
        lines.append(f"size_excluded={excluded} files (generated {size['generated']}, lockfiles {size['lockfiles']}, "
                     f"deleted {size['deleted']}, binary {size['binary']}; counted {size['files']} files)")
        lines.append(f"size_binary={size['binary']}")
        if limit is not None and n > limit:
            lines.append(f"size_over={n - limit} changed lines over the team's limit of {limit} -- split this branch "
                         "(a stack or a series: the pr skill's reference/split.md) or name the exception in ## Review")
            mark("warn")
    # Body
    suffix = f"-{repo}" if repo else ""
    body = Path(body_arg) if body_arg else pdir / "topics" / f"pr-body{suffix}.md"
    details = pdir / "topics" / f"pr-details{suffix}.md" if pdir is not None else None
    text = None
    if not body.is_file():
        lines.append(f"body=missing ({_pr_where(body, pdir)})")
        mark("fail" if body_arg else "warn")  # never a pass: the pr skill loops until pass
    else:
        text = body.read_text(encoding="utf-8", errors="replace")
        lines.append(f"body={_pr_where(body, pdir)}")
        measured = pr_body_measure(text)
        for key, budget in PR_BODY_BUDGETS:
            over = measured[key] > budget
            lines.append(f"{key}={measured[key]}/{budget} {'over' if over else 'ok'}")
            if over:
                mark("fail")
    # Leaks: the body and the details file
    fails, warns = [], []
    for f in (body, details):
        if f is not None and f.is_file():
            got = pr_leaks(f.read_text(encoding="utf-8", errors="replace"), _pr_where(f, pdir))
            fails += got[0]
            warns += got[1]
    for kind, match, at in fails[:PR_LEAKS_SHOWN]:
        lines.append(f"leak={kind}:{match} ({at})")
    if len(fails) > PR_LEAKS_SHOWN:
        lines.append(f"leak=+{len(fails) - PR_LEAKS_SHOWN} more")
    if fails:
        mark("fail")
    terms = {}
    for term, at in warns:
        terms.setdefault(term, []).append(at)
    for term, ats in terms.items():
        lines.append(f"leak_warn={term} x{len(ats)} (first {ats[0]})")
        mark("warn")
    if not fails and not warns and (body.is_file() or (details is not None and details.is_file())):
        lines.append("leaks=none")
    # Headings
    if text is not None:
        rel, team = pr_team_template(path) if path is not None else (None, None)
        expected = team if team is not None else PR_DEFAULT_HEADINGS
        problems = pr_heading_problems(_pr_h2(text), expected)
        lines.append(f"headings={'ok' if not problems else ','.join(problems)}")
        lines.append(f"template={rel if team is not None else 'default'}" + (f" (ambiguous: {rel} holds several templates)" if rel and team is None else ""))
        if problems:
            mark("fail")
        if team is not None and "review" not in [_pr_norm(h) for h in _pr_h2(text)]:
            lines.append("review_heading=missing -- ours fills the team template's gap: add ## Review after its first heading")
            mark("warn")
    return lines, status["v"]


def cmd_pr_check(args: argparse.Namespace) -> int:
    """Read-only: measure each recorded PR branch (size, body budgets, leaks, heading order) and print
    key=value lines. Exit 1 on a fail; 0 on a pass or a warning. A missing body is never a pass. The size
    warns only past a team's limit (`--limit <n>`, either route); with none it is information. With no
    phase it is the by-hand route (`pr-check --body <file> [--base <b>] [--branch <b>]`): the checked-out
    branch (or `--branch`) against `--base`, else the repo's default branch."""
    args.limit = _pr_size_limit(args.limit)
    if not args.phase:
        return _pr_check_by_hand(args)
    if args.base:
        raise SystemExit(f"pr-check {args.phase} --base: refused -- --base belongs to the by-hand route (no phase); "
                         f"a phase's branch is measured against its recorded base (pr-branch {args.phase} --base <branch> records one)")
    pdir = require_phase(args.phase)
    data = read_json(pdir / "phase.json")
    repos = nested_repos()
    names = [r["name"] for r in repos]
    if args.repo and not repos:
        raise SystemExit("pr-check --repo: refused -- a multi-repo host only; a single-repo host or a root install has one repo: drop --repo")
    if args.repo and args.repo not in names:
        raise SystemExit(f"pr-check --repo {args.repo}: no registered repo has that name (registered: {', '.join(names)})")
    block = phase_pr(data)
    entries = [dict(e) for e in (block["branches"] if block else [])
               if (args.repo is None or e.get("repo") == args.repo) and (args.branch is None or e.get("branch") == args.branch)]
    if args.body and len({e.get("repo") for e in entries}) > 1:
        raise SystemExit("pr-check --body names one body, but several repos' branches match: add --repo <name>")
    if not entries:
        if repos and not args.repo:
            print(f"pr_branches=none recorded for phase {args.phase} -- record them (pr-branch {args.phase} --repo <name> --name <branch>) or pass --repo")
            print(f"pr_rules={len(load_pr_rules())} decided")
            print("pr_check=warn")  # nothing measured and no body checked: never a pass
            return 0
        target = _pr_target(data, args.repo, "pr-check")
        branch = args.branch or _repo_current_branch(target["path"])
        if not branch:
            raise SystemExit(f"pr-check: no recorded PR branch, and {target['path']} has no branch checked out (detached HEAD); pass --branch")
        base = _pr_default_base(target["path"], target["default"]) or "main"
        entries = [{"repo": target["repo"], "branch": branch, "base": base,
                    "note": f"no recorded PR branch -- measured {branch} against the default base {base}"}]
    return _pr_check_print(pdir, data, entries, args.body, bool(repos), args.limit)


def _pr_size_limit(raw):
    """`--limit`'s value: None when absent, else a positive whole number of changed lines (the team's
    own limit, read live from their rules); anything else is refused in one line."""
    if raw is None:
        return None
    text = str(raw).strip()
    if not text.isdigit() or int(text) <= 0:
        raise SystemExit(f"pr-check --limit {text or repr(raw)}: refused -- a team's size limit is a positive whole number "
                         "of changed lines; with no team limit, drop --limit (the size is then information)")
    return int(text)


def _pr_check_print(pdir, data: dict, entries: list, body_arg, multi: bool, limit=None) -> int:
    """Print each entry's pr-check lines, then `pr_rules=` and the worst `pr_check=`; the exit code."""
    worst = "pass"
    order = ("pass", "warn", "fail")
    for entry in entries:
        lines, status = _pr_check_one(pdir, data, entry, body_arg, limit)
        prefix = f"repo={entry['repo']} " if multi else ""
        for ln in lines:
            print(prefix + ln)
        if order.index(status) > order.index(worst):
            worst = status
    print(f"pr_rules={len(load_pr_rules())} decided")
    print(f"pr_check={worst}")
    return 1 if worst == "fail" else 0


def _pr_check_by_hand(args: argparse.Namespace) -> int:
    """`pr-check --body <file> [--base <b>] [--branch <b>] [--repo <name>]` with no phase: the pr skill's
    by-hand route (`/pr`, a change made outside a phase). Measures the checked-out branch (or `--branch`)
    against `--base` (a branch, recorded as its name, as `pr-branch` does), else the repo's default branch,
    and checks the body; there is no details file. Writes nothing."""
    if not args.body:
        raise SystemExit("pr-check: name a phase (pr-check <P> [--repo <name>] [--branch <b>] [--body <file>]) "
                         "or, by hand outside a phase, a body (pr-check --body <file> [--base <branch>] [--branch <b>])")
    target = _pr_target({}, args.repo, "pr-check")
    path = target["path"]
    branch = args.branch or _repo_current_branch(path)
    if not branch:
        raise SystemExit(f"pr-check --body: {path} has no branch checked out (detached HEAD); pass --branch")
    if args.base:
        base, why = _pr_base_branch(path, args.base)
        if base is None:
            raise SystemExit(f"pr-check --base {args.base.strip()}: {why}")
    else:
        base = _pr_default_base(path, target["default"]) or _repo_default_branch(path, target["default"]) or "main"
    entry = {"repo": target["repo"], "branch": branch, "base": base,
             "note": f"by hand (no phase) -- measured {branch} against {'--base' if args.base else 'the default branch'} {base}"}
    return _pr_check_print(None, {}, [entry], args.body, bool(nested_repos()), args.limit)


def nested_next_lines() -> list:
    """`next`'s nested-install lines: the host, and the host conventions' state (commits, branches, PRs) -- loud
    while it is unconfirmed, because the first product commit must wait for the operator. Empty
    at root, so an at-root `next` prints exactly what it always printed."""
    if NESTED is None:
        return []
    conv = NESTED.get("commit_convention") if isinstance(NESTED.get("commit_convention"), dict) else {}
    lines = [f"nested_host={HOST_ROOT}"]
    if conv.get("confirmed") is True:
        lines.append(f"host_commit_convention=confirmed (coauthor_trailers={conv.get('coauthor_trailers')}) "
                     f"-- follow it for host commits, branches and pull requests; read it with: {WORKFLOW_CMD} nested-convention")
    else:
        inferred = _one_line(conv.get("inferred")) if conv.get("inferred") else "nothing"
        lines.append(f"host_commit_convention=UNCONFIRMED (inferred: {inferred}) -- confirm the host's conventions (commits, branches and pull requests) with the operator before the first product commit, "
                     f"then: {WORKFLOW_CMD} nested-convention --confirm --text \"<conventions>\" --trailers allowed|forbidden")
    repos = nested_repos()
    if repos:  # P40 multi-repo: one summary line; a single-repo install prints exactly the two above
        lines.append(_repo_conventions_line(repos))
    return lines


def effective_repo_convention(repo: dict, host_conv=None) -> dict:
    """P40 (Decision 12): repo X's effective convention on a multi-repo host, where the top-level
    `commit_convention` is "the rules for every repo" and X's own (null = inherit) is more specific.

    - text: the host-level text, then X's own, each labelled (both shown);
    - confirmed: X's own `confirmed`, or the host-level one when X's convention is null;
    - trailers: `forbidden` if either forbids, else X's own when it records allowed/forbidden, else the host's.

    `state` is what `nested-repos`, `nested-convention` and `next`'s `repo_conventions=` all print:
    `UNCONFIRMED` whenever the effective `confirmed` is false (an inherited convention under an
    unconfirmed host included), else `inherited` for a null convention, else `confirmed`.
    `host_conv` defaults to the loaded marker's; `nested-convention --confirm` passes the one it just wrote."""
    if host_conv is None:
        host_conv = NESTED.get("commit_convention") if NESTED is not None else None
    host = host_conv if isinstance(host_conv, dict) else {}
    own = repo.get("commit_convention")
    host_trailers = host.get("coauthor_trailers") or "unknown"
    parts = [f"every repo: {host['text']}"] if host.get("text") else []
    if own is None:
        confirmed = host.get("confirmed") is True
        trailers = host_trailers
    else:
        confirmed = own.get("confirmed") is True
        own_trailers = own.get("coauthor_trailers")
        if "forbidden" in (host_trailers, own_trailers):
            trailers = "forbidden"
        else:
            trailers = own_trailers if own_trailers in ("allowed", "forbidden") else host_trailers
        if own.get("text"):
            parts.append(f"{repo['name']}: {own['text']}")
    state = "UNCONFIRMED" if not confirmed else ("inherited" if own is None else "confirmed")
    return {"state": state, "confirmed": confirmed, "coauthor_trailers": trailers, "text": "\n".join(parts) or None,
            "inferred": None if own is None else own.get("inferred"), "inherits": own is None}


def _repo_convention_lines(repo: dict, host_conv=None) -> list:
    """One registry entry's block in `nested-convention` (bare multi-repo, and `--repo`): its effective values."""
    eff = effective_repo_convention(repo, host_conv)
    lines = [f"repo={repo['name']} path={repo['path']}/ commit_convention={eff['state']} coauthor_trailers={eff['coauthor_trailers']}",
             "inferred:",
             "(inherits the host-level convention, the rules for every repo)" if eff["inherits"] else (eff["inferred"] or "(nothing inferred)"),
             "text:",
             eff["text"] or "(none -- not confirmed yet)"]
    if eff["state"] == "UNCONFIRMED" and eff["inherits"]:
        lines.append(f"{repo['name']} inherits the unconfirmed host-level conventions: confirm those (the rules for every repo) with the operator before its first product commit, "
                     f"then: {WORKFLOW_CMD} nested-convention --confirm --text \"<conventions>\" --trailers allowed|forbidden "
                     f"(or record {repo['name']}'s own: --confirm --repo {repo['name']} ...)")
    elif eff["state"] == "UNCONFIRMED":
        lines.append(f"confirm {repo['name']}'s conventions (commits, branches and pull requests) with the operator before its first product commit, "
                     f"then: {WORKFLOW_CMD} nested-convention --confirm --repo {repo['name']} --text \"<conventions>\" --trailers allowed|forbidden")
    return lines


def _repo_conventions_line(repos: list) -> str:
    """`next`'s one multi-repo summary line (S1 §5): the count by effective state with the UNCONFIRMED
    names and the command that confirms them, or that nothing needs confirming."""
    states = [(repo["name"], effective_repo_convention(repo)["state"]) for repo in repos]
    unconfirmed = [name for name, state in states if state == "UNCONFIRMED"]
    if not unconfirmed:
        return f"repo_conventions={len(repos)} (all confirmed or inherited) -- per repo: {WORKFLOW_CMD} nested-convention --repo <name>"
    confirmed = sum(1 for _, state in states if state == "confirmed")
    inherited = sum(1 for _, state in states if state == "inherited")
    return (f"repo_conventions={len(repos)} (confirmed {confirmed}, inherited {inherited}, UNCONFIRMED {len(unconfirmed)}: {', '.join(unconfirmed)}) "
            f"-- confirm each UNCONFIRMED repo's conventions before its first product commit: "
            f"{WORKFLOW_CMD} nested-convention --confirm --repo <name> --text \"<conventions>\" --trailers allowed|forbidden")


def _nested_convention_repo(args: argparse.Namespace, path: Path) -> None:
    """`nested-convention --repo <name>` on a multi-repo host (P40): show that repo's effective block,
    `--confirm` its own convention, or `--inherit` (set it back to null). Validate-then-write, one event."""
    repos = nested_repos()
    names = [repo["name"] for repo in repos]
    if args.repo not in names:
        raise SystemExit(f"nested-convention: refused -- no registered repo named {args.repo!r} (registered: {', '.join(names)}; "
                         f"list them with: {WORKFLOW_CMD} nested-repos)")
    if not (args.confirm or args.inherit):
        print("\n".join(_repo_convention_lines(repos[names.index(args.repo)])))
        return
    data = read_json(path)
    entries = data.get("repos") if isinstance(data.get("repos"), list) else []
    entry = next((e for e in entries if isinstance(e, dict) and e.get("name") == args.repo), None)
    if entry is None:  # the marker changed under us; never write a guess
        raise SystemExit(f"nested-convention: refused -- {shown(path)} no longer registers {args.repo!r}")
    previous = entry.get("commit_convention")
    if args.inherit:
        if previous is None:
            print(f"nested-convention: {args.repo} already inherits the host-level convention -- nothing written")
            print("\n".join(_repo_convention_lines(entry, data.get("commit_convention"))))
            return
        entry["commit_convention"] = None
    else:
        base = dict(previous) if isinstance(previous, dict) else {"inferred": None, "confirmed": False, "text": None, "coauthor_trailers": "unknown"}
        entry["commit_convention"] = dict(base, text=args.text, confirmed=True, coauthor_trailers=args.trailers)
    problems = nested_marker_problems(data)
    if problems:  # never write a marker validate would reject
        raise SystemExit(f"nested-convention: refused -- the result would be malformed: {'; '.join(problems)}")
    write_json(path, data)
    was_confirmed = isinstance(previous, dict) and previous.get("confirmed") is True
    if args.inherit:
        append_event("nested_convention_inherited", repo=args.repo, previously_confirmed=was_confirmed)
        print(f"nested-convention: {args.repo} now inherits the host-level convention (its own was {'confirmed' if was_confirmed else 'UNCONFIRMED'}) -- written to {shown(path)}")
    else:
        append_event("nested_convention_confirmed", repo=args.repo, coauthor_trailers=args.trailers, previously_confirmed=was_confirmed)
        print(f"nested-convention: {args.repo} confirmed{' (replacing the earlier confirmation)' if was_confirmed else ''} -- written to {shown(path)}")
    print("\n".join(_repo_convention_lines(entry, data.get("commit_convention"))))


def cmd_nested_convention(args: argparse.Namespace) -> None:
    """Show (bare) or record (--confirm) a nested install's host conventions for commits, branches and pull requests.

    The installer cannot ask (it runs non-interactively), so it records what it inferred from the
    host's git log and CONTRIBUTING with `confirmed: false`; the orchestrator asks the operator
    before the first product commit and records the answer here -- the convention text and whether
    Claude `Co-Authored-By` trailers are allowed in the host repo. Writes only `.agentic-nested.json`.

    On a multi-repo host (P40) the host-level convention is the rules for every repo, and each
    registered repo may carry its own (`--repo <name>`; `--inherit` sets it back to null); a repo's
    effective convention composes the two (`effective_repo_convention`)."""
    if NESTED is None:
        raise SystemExit(f"nested-convention: refused -- this is not a nested personal install (no {NESTED_MARKER} beside scripts/); "
                         "commits here follow the workspace's own Commit Convention")
    if args.inherit and args.confirm:
        raise SystemExit(f"nested-convention: --inherit and --confirm exclude each other: --inherit sets a repo's own convention back to null "
                         f"({WORKFLOW_CMD} nested-convention --repo <name> --inherit)")
    if args.inherit and args.repo is None:
        raise SystemExit(f"nested-convention: --inherit needs --repo <name> (the host-level convention has nothing to inherit from): "
                         f"{WORKFLOW_CMD} nested-convention --repo <name> --inherit")
    if (args.text is not None or args.trailers is not None) and not args.confirm:
        raise SystemExit(f"--text and --trailers belong to --confirm: {WORKFLOW_CMD} nested-convention --confirm --text \"...\" --trailers allowed|forbidden")
    if args.repo is not None and not nested_repos():
        raise SystemExit("nested-convention: refused -- single-repo install: the host is the one repo; drop --repo")
    path = ROOT / NESTED_MARKER
    if args.confirm:
        whose = f"{args.repo}'s" if args.repo is not None else "the host's"
        if not (args.text or "").strip():
            raise SystemExit(f"nested-convention --confirm needs --text \"<{whose} conventions for commits, branches and pull requests, as the operator confirmed them>\"")
        if args.trailers is None:
            raise SystemExit(f"nested-convention --confirm needs --trailers allowed|forbidden (may Claude Co-Authored-By trailers appear in {args.repo + ' commits' if args.repo is not None else 'host commits'}?)")
    if args.repo is not None:
        _nested_convention_repo(args, path)
        return
    if args.confirm:
        data = read_json(path)
        previous = dict(data["commit_convention"])
        data["commit_convention"] = dict(previous, text=args.text, confirmed=True, coauthor_trailers=args.trailers)
        problems = nested_marker_problems(data)
        if problems:  # cannot happen from a valid marker, but never write a marker validate would reject
            raise SystemExit(f"nested-convention: refused -- the result would be malformed: {'; '.join(problems)}")
        write_json(path, data)
        append_event("nested_convention_confirmed", coauthor_trailers=args.trailers, previously_confirmed=previous.get("confirmed") is True)
        print(f"nested-convention: confirmed{' (replacing the earlier confirmation)' if previous.get('confirmed') is True else ''} -- written to {shown(path)}")
        conv = data["commit_convention"]
    else:
        conv = NESTED["commit_convention"]
    repos = nested_repos()
    print(f"nested_host={HOST_ROOT}")
    if repos:  # P40 multi-repo: the host-level block is the rules for every repo
        print("scope=every repo")
    print(f"commit_convention={'confirmed' if conv.get('confirmed') is True else 'UNCONFIRMED'}")
    print(f"coauthor_trailers={conv.get('coauthor_trailers')}")
    print("inferred:")
    print(conv.get("inferred") or "(nothing inferred)")
    print("text:")
    print(conv.get("text") or "(none -- not confirmed yet)")
    if conv.get("confirmed") is not True:
        print(f"confirm the host's conventions (commits, branches and pull requests) with the operator before the first product commit, then: {WORKFLOW_CMD} nested-convention --confirm --text \"<conventions>\" --trailers allowed|forbidden")
    for repo in repos:
        print()
        print("\n".join(_repo_convention_lines(repo, conv)))


# P40: the multi-repo registry's helpers, its `validate` rows and the `nested-repos` command. Every
# path below resolves against the MAIN host checkout (`nested_repo_path`), and every per-repo git
# call is preceded by `_git_work_tree_root`, because `git -C` on a plain directory answers for the host.
NESTED_REPO_RULE_NAMES = ("AGENTS.md", "CLAUDE.md")


def _repo_git(path: Path, *cmd: str):
    """`git <cmd>` run in `path`; None when git cannot run at all (validate never fails on that)."""
    try:
        return subprocess.run(["git", *cmd], cwd=str(path), capture_output=True, text=True, timeout=60)
    except Exception:  # noqa: BLE001 - no git binary or a vanished dir: the caller skips the check
        return None


def _detect_repo_rules(path: Path) -> list:
    """A repo's own rules files, repo-relative and sorted: every tracked `AGENTS.md` / `CLAUDE.md` at
    any depth, plus `.agents/skills/*/SKILL.md`. Tracked files only (`ls-files`), so build output and
    ignored copies never count."""
    proc = _repo_git(path, "ls-files", "-z")
    if proc is None or proc.returncode != 0:
        return []
    found = []
    for f in proc.stdout.split("\0"):
        parts = f.split("/") if f else []
        if parts and (parts[-1] in NESTED_REPO_RULE_NAMES
                      or (len(parts) == 4 and parts[:2] == [".agents", "skills"] and parts[3] == "SKILL.md")):
            found.append(f)
    return sorted(found)


def _repo_origin_head(path: Path):
    """The branch a repo's `origin/HEAD` points at (`main`, `dev`, ...), or None."""
    proc = _repo_git(path, "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD")
    target = proc.stdout.strip() if proc is not None and proc.returncode == 0 else ""
    return target.split("/", 1)[1] if target.startswith("origin/") and len(target) > len("origin/") else None


def _host_tracked_count(host: Path):
    """How many files the host's git tracks; None when it cannot say (no git, not a work tree)."""
    proc = _repo_git(host, "ls-files", "-z")
    if proc is None or proc.returncode != 0:
        return None
    return len([f for f in proc.stdout.split("\0") if f])


def _nested_dir_name() -> str:
    """The nested workspace's dir, host-relative (normally `workflow`)."""
    return Path(os.path.relpath(ROOT, HOST_ROOT)).as_posix()


def _workspace_paths() -> list:
    """The host-side workspace files that must never be tracked inside a product repo: the nested
    dir, `CLAUDE.local.md`, `.claude/settings.local.json`, and the installed skill dirs and agent
    files the marker's `installed` names."""
    paths = [_nested_dir_name(), "CLAUDE.local.md", ".claude/settings.local.json"]
    inst = NESTED.get("installed") if isinstance(NESTED.get("installed"), dict) else {}
    paths += [f".claude/skills/{n}" for n in inst.get("skills") or []]
    paths += [f".claude/agents/{n}.md" for n in inst.get("agents") or []]
    return paths


def _unregistered_child_repos(host: Path, repos: list) -> list:
    """Depth-1 dirs of the host holding a `.git` (dir or file) that the registry does not list; the
    nested workspace's own dir is never one."""
    registered = {r["path"] for r in repos}
    skip = {_nested_dir_name().split("/", 1)[0]}
    try:
        children = sorted(e.name for e in host.iterdir() if e.is_dir() and not e.is_symlink() and os.path.lexists(e / ".git"))
    except OSError:
        return []
    return [c for c in children if c not in registered and c not in skip]


def nested_repo_checks(errors: list, warnings: list) -> None:
    """`validate`'s multi-repo rows (P40; D40's two ignore guarantees are the visible-repo and
    tracked-workspace-file errors). Called only when `nested_repos()` is non-empty, so a single-repo
    install never reaches it. Errors: a registered repo missing or not a git work tree root, visible
    to the host's git, or tracking a workspace file. Warnings (anything a live parallel set such as
    glide's P29 could trip, since the installer's `--update` runs validate with check=True): an
    unregistered depth-1 child repo, a missing rules file, a host that tracks files."""
    host = MAIN_HOST or HOST_ROOT
    repos = nested_repos()
    workspace = _workspace_paths()
    for repo in repos:
        name, rel = repo["name"], repo["path"]
        path = nested_repo_path(repo)
        if not path.exists():
            errors.append(f"nested install: repo {name} ({rel}/) is missing from the host {host} -- restore it or run: {WORKFLOW_CMD} nested-repos --remove {name}")
            continue
        if not _git_work_tree_root(path):
            errors.append(f"nested install: repo {name} ({rel}/) is not a git work tree root -- restore it or run: {WORKFLOW_CMD} nested-repos --remove {name}")
            continue
        ignored = _repo_git(host, "check-ignore", "-q", f"{rel}/")
        if ignored is not None and ignored.returncode == 1:
            errors.append(f"nested install: repo {name} ({rel}/) is visible to the host's git -- run the installer's --update to write its exclude line")
        tracked = _repo_git(path, "ls-files", "-z", "--", *workspace)
        if tracked is not None and tracked.returncode == 0:
            files = [f for f in tracked.stdout.split("\0") if f]
            hits = [w for w in workspace if any(f == w or f.startswith(w + "/") for f in files)]
            if hits:
                errors.append(f"nested install: repo {name} tracks workspace file(s) {', '.join(hits)} -- untrack them (git -C {rel} rm -r --cached -- {' '.join(hits)})")
        for rule in repo.get("rules") or []:
            if not os.path.lexists(path / rule):
                warnings.append(f"nested install: repo {name} rules file {rule} is missing")
    for child in _unregistered_child_repos(host, repos):
        warnings.append(f"nested install: {child}/ is a git repo the registry does not list ({WORKFLOW_CMD} nested-repos --add {child}, or ignore it)")
    count = _host_tracked_count(host)
    if count:
        warnings.append(f"nested install: the multi-repo host tracks {count} file(s); product belongs in the repos")


def _repo_branch_now(path: Path) -> str:
    if not path.exists():
        return "(missing)"
    if not _git_work_tree_root(path):
        return "(not a git work tree root)"
    proc = _repo_git(path, "symbolic-ref", "-q", "--short", "HEAD")
    return proc.stdout.strip() if proc is not None and proc.returncode == 0 and proc.stdout.strip() else "(detached)"


def _print_nested_repos(repos: list) -> None:
    host = MAIN_HOST or HOST_ROOT
    if not repos:
        print(f"repos=none -- a single-repo nested install: the host {HOST_ROOT} is the one product repo "
              f"(a host that tracks no files registers its repos with: {WORKFLOW_CMD} nested-repos --add <path>)")
        return
    print(f"nested_host={HOST_ROOT}")
    if host != HOST_ROOT:
        print(f"main_host={host} (registry paths resolve here, never in this worktree set)")
    print(f"repos={len(repos)}")
    for repo in repos:
        path = nested_repo_path(repo)
        print(f"repo={repo['name']} path={repo['path']}/ branch={_repo_branch_now(path)} "
              f"default_branch={repo.get('default_branch') or 'none'} convention={effective_repo_convention(repo)['state']} rules={len(repo.get('rules') or [])}")


def _repo_anchor_holders(name: str) -> list:
    """Active phases whose phase.json holds `repo_anchors.<name>` (their phase scope reads that repo).
    Read defensively: the key is written from P40.S5 on, and absent means no hold."""
    holders = []
    for d in phase_dirs():
        try:
            anchors = read_json(d / "phase.json").get("repo_anchors")
        except (OSError, ValueError):
            continue
        if isinstance(anchors, dict) and name in anchors:
            holders.append(d.name)
    return holders


def cmd_nested_repos(args: argparse.Namespace) -> None:
    """Show (bare) or edit a multi-repo host's registry of product repos: `--add`, `--remove`,
    `--rules --set`, `--detect-rules` (P40).

    The registry is the marker's optional `repos` list; a non-empty one makes the install multi-repo.
    `--add` on a single-repo install is allowed only when the host tracks no files: a host that is
    itself a product repo is not a multi-repo host. `--remove` is refused while an active phase holds
    the repo's anchors. Writes only `.agentic-nested.json` (validated first, as `nested-convention`
    does) plus one event per change; the exclude line and the CLAUDE.local.md block are the
    installer's `--update`."""
    if NESTED is None:
        raise SystemExit(f"nested-repos: refused -- this is not a nested personal install (no {NESTED_MARKER} beside scripts/); "
                         "an at-root workspace's repo is its one product repo")
    if args.set is not None and args.rules is None:
        raise SystemExit(f"--set belongs to --rules: {WORKFLOW_CMD} nested-repos --rules <name> --set a,b,c")
    if args.rules is not None and args.set is None:
        raise SystemExit(f"nested-repos --rules needs --set <comma-separated repo-relative paths> (or re-detect them: {WORKFLOW_CMD} nested-repos --detect-rules {args.rules})")
    if (args.name is not None or args.default_branch is not None) and args.add is None:
        raise SystemExit(f"--name and --default-branch belong to --add: {WORKFLOW_CMD} nested-repos --add <path> [--name N] [--default-branch B]")
    path = ROOT / NESTED_MARKER
    host = MAIN_HOST or HOST_ROOT
    current = nested_repos()
    if args.map_anchors is not None:
        _map_repo_anchors(args.map_anchors, current)
        return
    if args.add is None and args.remove is None and args.rules is None and args.detect_rules is None:
        _print_nested_repos(current)
        return
    data = read_json(path)
    repos = [dict(r) for r in data.get("repos") or []]
    if args.add is not None:
        raw = args.add
        rel = os.path.relpath(Path(raw).resolve(), host) if os.path.isabs(raw) else posixpath.normpath(raw.replace(os.sep, "/"))
        rel = Path(rel).as_posix()
        refused = "nested-repos --add: refused -- nothing was written"
        if not repos:
            count = _host_tracked_count(host)
            if count is None or count > 0:
                tracked = "is not a git work tree" if count is None else f"tracks {count} file(s)"
                raise SystemExit(f"{refused}: the host {host} {tracked}, so it is not a multi-repo host -- a host that is itself a product repo "
                                 "stays a single-repo nested install; only a host that tracks no files registers product repos")
        bad = _repo_path_problem(rel, host, _nested_dir_name())
        if bad:
            raise SystemExit(f"{refused}: path {rel!r} {bad}")
        holder = next((r for r in repos if r.get("path") == rel), None)
        if holder is not None:
            raise SystemExit(f"{refused}: {rel}/ is already registered as {holder.get('name')}")
        target = host / rel
        if not _git_work_tree_root(target):
            raise SystemExit(f"{refused}: {target} is not the root of a git work tree "
                             f"({'it does not exist' if not target.exists() else 'git there answers for an enclosing repo, or for none'})")
        name = args.name if args.name is not None else rel.rsplit("/", 1)[-1]
        if not NESTED_REPO_NAME.fullmatch(name):
            raise SystemExit(f"{refused}: name {name!r} must match [A-Za-z0-9._-]+ (pass --name)")
        if any(r.get("name") == name for r in repos):
            raise SystemExit(f"{refused}: the name {name} is already registered (pass another --name)")
        if args.default_branch is not None:
            check = _repo_git(target, "check-ref-format", "--branch", args.default_branch)
            if check is None or check.returncode != 0:
                raise SystemExit(f"{refused}: --default-branch {args.default_branch!r} is not a valid branch name")
            branch = args.default_branch
        else:
            branch = _repo_origin_head(target)
        entry = {"name": name, "path": rel, "default_branch": branch, "commit_convention": None, "rules": _detect_repo_rules(target)}
        repos.append(entry)
        _write_nested_repos(path, data, repos)
        append_event("nested_repo_added", name=name, path=rel, default_branch=branch, rules=entry["rules"], made_multi_repo=not current)
        print(f"nested-repos: added {name} ({rel}/){' -- this install is now multi-repo' if not current else ''} -- written to {shown(path)}")
        ignored = _repo_git(host, "check-ignore", "-q", f"{rel}/")
        visible = ignored is not None and ignored.returncode == 1
        print(f"next: run the installer's --update on this host: it writes the /{rel}/ exclude line and the multi-repo CLAUDE.local.md block"
              + (f"; until then check reports {name} as visible to the host's git" if visible else ""))
    elif args.remove is not None:
        name = args.remove
        entry = next((r for r in repos if r.get("name") == name), None)
        if entry is None:
            raise SystemExit(f"nested-repos --remove: refused -- no registered repo is named {name} "
                             f"(registered: {', '.join(r.get('name', '?') for r in repos) or 'none'}) -- nothing was written")
        holders = _repo_anchor_holders(name)
        if holders:
            raise SystemExit(f"nested-repos --remove: refused -- active phase(s) {', '.join(holders)} hold repo_anchors.{name} (their phase scope reads {entry['path']}/); "
                             "finish and archive them first, then re-run -- nothing was written")
        repos = [r for r in repos if r.get("name") != name]
        _write_nested_repos(path, data, repos)
        append_event("nested_repo_removed", name=name, path=entry["path"], made_single_repo=not repos)
        print(f"nested-repos: removed {name} ({entry['path']}/) from the registry -- written to {shown(path)}; the repo and its files are untouched"
              + ("; the registry is empty, so this is a single-repo nested install again" if not repos else ""))
    else:
        name = args.rules if args.rules is not None else args.detect_rules
        entry = next((r for r in repos if r.get("name") == name), None)
        verb = "--rules" if args.rules is not None else "--detect-rules"
        if entry is None:
            raise SystemExit(f"nested-repos {verb}: refused -- no registered repo is named {name} "
                             f"(registered: {', '.join(r.get('name', '?') for r in repos) or 'none'}) -- nothing was written")
        if args.rules is not None:
            rules = []
            for item in args.set.split(","):
                item = item.strip()
                if item and item not in rules:
                    rules.append(item)
        else:
            target = host / entry["path"]
            if not _git_work_tree_root(target):
                raise SystemExit(f"nested-repos --detect-rules: refused -- {target} is not the root of a git work tree -- nothing was written")
            rules = _detect_repo_rules(target)
        entry["rules"] = rules
        _write_nested_repos(path, data, repos)
        append_event("nested_repo_rules_set", name=name, rules=rules, detected=args.detect_rules is not None)
        print(f"nested-repos: {name} rules {'re-detected' if args.detect_rules is not None else 'set'} ({len(rules)}) -- written to {shown(path)}")
        for rule in rules:
            print(f"  {rule}")
    _print_nested_repos(repos)


def _map_repo_anchors(name: str, repos: list) -> None:
    """`nested-repos --map-anchors <repo>` (P40 S2 §22 step 7, §25): a converted install's phases
    carry `host_anchors` that are really commits of the old single repo, now registered as `<repo>`.
    Per phase, active and archived: `repo_anchors.<repo>` = {created, branch: null, review_pass,
    review_base} (review_base = the frozen `host_anchors.review_base` if any, else `created` once the
    review passed, which reproduces the old `created..review_pass` exactly), and `host_anchors`
    becomes {}. Skipped, untouched and said why: already mapped; in flight on its own branch (its
    truth lives there); no host_anchors shas; shas that are not commits in `<repo>` (glide's P29: the
    host's empty commit). Writes phase.json files only and never commits; a re-run maps nothing.

    P55 (v97): the same pass maps the PR records. A per-repo install records `pr.branches[].repo: null`
    (its one repo); a multi-repo host's validate wants a name. So, when the marker's `converted_from`
    names `<repo>` (the conversion's own repo, never a guess on any other host), every null `repo` in
    every phase becomes `<repo>`, nothing else in the record changes, and a phase in flight on its own
    branch is skipped the same way. The installer's --to-multi-repo runs this before its --update's
    closing validate."""
    refused = "nested-repos --map-anchors: refused -- nothing was written"
    repo = next((r for r in repos if r.get("name") == name), None)
    if repo is None:
        raise SystemExit(f"{refused}: no registered repo is named {name} (registered: {', '.join(r.get('name', '?') for r in repos) or 'none'})")
    rpath, why = _phase_repo_path(repo, {})
    if rpath is None:
        raise SystemExit(f"{refused}: {why}")
    converted = NESTED.get("converted_from") if NESTED is not None and isinstance(NESTED.get("converted_from"), list) else []
    pr_owner = any(isinstance(c, dict) and c.get("repo") == name for c in converted)
    pdirs = [(d, False) for d in phase_dirs()]
    if ARCHIVED.is_dir():
        pdirs += [(d, True) for d in sorted(ARCHIVED.iterdir()) if d.is_dir() and (d / "phase.json").is_file()]
    mapped, skipped, pr_mapped, pr_skipped = [], 0, [], 0
    for pdir, archived in pdirs:
        try:
            data = read_json(pdir / "phase.json")
        except (OSError, ValueError) as exc:
            print(f"{pdir.name}: skipped: phase.json cannot be read ({exc})")
            skipped += 1
            continue
        pid = f"{data.get('id', pdir.name)}{' (archived)' if archived else ''}"
        host = data.get("host_anchors") if isinstance(data.get("host_anchors"), dict) else {}
        shas = {k: v for k, v in host.items() if k in HOST_ANCHOR_KEYS and isinstance(v, str) and v}
        held = data.get("repo_anchors") if isinstance(data.get("repo_anchors"), dict) else {}
        execution = data.get("execution") if isinstance(data.get("execution"), dict) else {}
        in_flight = None
        if execution.get("worktree") or execution.get("host_worktree"):
            in_flight = (f"in flight on its own branch ({execution.get('branch') or execution.get('worktree')}): "
                         "its phase.json's truth lives there -- map it after it merges")
        reason = None
        if name in held:
            reason = f"already holds repo_anchors.{name}"
        elif in_flight:
            reason = in_flight
        elif not shas:
            reason = "holds no host_anchors shas"
        else:
            bad = [f"{k}={v[:7]}" for k, v in shas.items() if not _rev_parse(v, cwd=rpath)]
            if bad:
                reason = f"host_anchors {', '.join(bad)} not a commit in {name} (a host commit, or another repo's) -- left untouched"
        changed = False
        if reason:
            print(f"{pid}: skipped: {reason}")
            skipped += 1
        else:
            created, passed = shas.get("created"), shas.get("review_pass")
            entry = {"created": created, "branch": None, "review_pass": passed,
                     "review_base": shas.get("review_base") or (created if passed else None)}
            data["host_anchors"] = {}
            _with_repo_anchors(data, {name: entry})
            changed = True
            mapped.append(data.get("id", pdir.name))
            print(f"{pid}: mapped: repo_anchors.{name} = created {(created or 'null')[:7]}, review_pass {(passed or 'null')[:7]}, "
                  f"review_base {(entry['review_base'] or 'null')[:7]}; host_anchors = {{}}")
        pr = data.get("pr") if isinstance(data.get("pr"), dict) else {}
        branches = pr.get("branches") if isinstance(pr.get("branches"), list) else []
        nulls = [i for i, b in enumerate(branches) if isinstance(b, dict) and "repo" in b and b["repo"] is None]
        if nulls and (in_flight or not pr_owner):
            why = in_flight or (f"this host was not converted from {name} (converted_from names "
                                f"{', '.join(str(c.get('repo')) for c in converted if isinstance(c, dict)) or 'no repo'}), "
                                "so a null repo is not its to claim -- left untouched")
            print(f"{pid}: pr: skipped {len(nulls)} record(s) with repo null: {why}")
            pr_skipped += len(nulls)
        elif nulls:
            for i in nulls:
                branches[i]["repo"] = name
                print(f"{pid}: pr: mapped pr.branches[{i}].repo null -> {name} (branch {branches[i].get('branch')})")
            pr_mapped.append(data.get("id", pdir.name))
            changed = True
        if changed:
            write_json(pdir / "phase.json", data)
    if mapped:
        append_event("nested_repo_anchors_mapped", repo=name, phases=mapped)
    if pr_mapped:
        append_event("nested_repo_pr_mapped", repo=name, phases=pr_mapped)
    print(f"nested-repos --map-anchors {name}: mapped {len(mapped)}, skipped {skipped} of {len(pdirs)} phase(s); "
          f"pr records: mapped in {len(pr_mapped)} phase(s), skipped {pr_skipped}"
          + (" -- phase.json files written; commit them in the nested repo" if mapped or pr_mapped else " -- nothing written"))


def _write_nested_repos(path: Path, data: dict, repos: list) -> None:
    """Write the registry back through the same validate-then-write path `nested-convention` uses;
    an emptied registry drops the key, so the marker reads as the single-repo one it now is."""
    if repos:
        data["repos"] = repos
    else:
        data.pop("repos", None)
    problems = nested_marker_problems(data)
    if problems:  # never write a marker validate would reject
        raise SystemExit(f"nested-repos: refused -- the result would be malformed: {'; '.join(problems)}")
    write_json(path, data)
