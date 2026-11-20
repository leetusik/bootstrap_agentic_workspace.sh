#!/usr/bin/env python3
"""The Claude Code adapter: `python3 <this file> <route|sync-agents|meter|compact-resume> ...`.

- route: the executor route table (the engine defaults overlaid by the workspace's executors.toml) and one
  dispatch's row, model, effort and agent file;
- sync-agents: writes the rows that own an agent file into its frontmatter;
- meter: what a phase cost, metered from Claude Code's transcripts, and each slice's verdict read from its
  result.md (its `status:` line) or slice.json;
- compact-resume: the SessionStart hook (matcher compact), which prints the engine's resume card with the
  session's running spans.

It reads the workspace through the engine beside it (../../scripts/: workflow.py and its modules), imported
in-process, and runs every command through workflow.run (the id normalising and, in a linked checkout, the
cloud boundary). The engine never imports this folder."""
from __future__ import annotations

import argparse
import bisect
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

sys.dont_write_bytecode = True  # never a __pycache__/ beside the engine or here
ADAPTER = Path(__file__).resolve()
sys.path.insert(0, str(ADAPTER.parents[2] / "scripts"))
import workflow  # noqa: E402 -- the engine: it finds the workspace (or exits 2 with one line) and binds its seams
from wf_store import (  # noqa: E402
    _meter_ts, _one_line, _walk_to_state, ACTIVE, all_events, append_event, ARCHIVED,
    archived_phase_ids, cmd_next, ENGINE, HOST_ROOT, id_sort_key, MAIN_HOST, NESTED, PHASE_ID_PATTERN,
    PHASE_ID_RE, read_json, require_phase, require_slice, resume_card, ROOT, shown, SLICE_SUFFIX_PATTERN,
    write_text,
)
from wf_design import (  # noqa: E402
    DESIGN_ROOT_REL,
)

ADAPTER_REL = "adapters/claude_code/adapter.py"  # where the installer emits this file, under the workspace
# The executor agent files Claude Code loads: the main host checkout's `.claude/agents` when nested (Claude Code
# finds agents walking up from the session's cwd, the host root; a phase worktree pair has none of its own), the
# workspace's otherwise. executors.toml stays at ROOT either way.
CLAUDE_AGENTS = (MAIN_HOST or HOST_ROOT or ROOT) / ".claude" / "agents"


def _adapter_cmd() -> str:
    """The command this adapter's printed hints use: `python3 <this file>` relative to the host (nested) or the
    workspace, as the engine's WORKFLOW_CMD is; absolute when this file sits outside both."""
    for base in (HOST_ROOT, ROOT):
        if base is not None:
            try:
                return f"python3 {ADAPTER.relative_to(Path(base).resolve()).as_posix()}"
            except ValueError:
                continue
    return f"python3 {ADAPTER}"


ADAPTER_CMD = _adapter_cmd()


RETIRED_EXECUTOR_TIERS = ("low",)  # [claude.low]: dropped in workspace v23, still refused with its migration
# [claude.cheap]: the Haiku row for docs and qa, retired in workspace v83 (those slices run on the mid row);
# refused with its migration. The meter still reads old spans as `cheap` (METER_ROUTES).
RETIRED_ROUTES = ("cheap",)
# The executor route table (workspace v53): ONE table, owned here, that the orchestrator dispatches
# from. A row is a (model, effort) pair the dispatch passes per call; `route` prints the
# resolved row for a slice and `sync-agents` writes the rows that own an agent file into that
# file's frontmatter, which is only the fallback. Each row is overridable, key by key, under
# [claude.<row>] in the repo-root executors.toml. There is no Haiku slice row: v83 retired `cheap`
# (docs and qa rated low ran on Haiku); every slice rated low runs on the mid row.
# `explore` is the read-only lookup agent (.claude/agents/Explore.md), not a slice route.
# `design` is the design subagent's own row (.claude/agents/design-drafter.md, workspace v60): never
# a slice's route -- only `route --drafter` dispatches on it.
# `critic` and `judge` (workspace v60) are the design critic's two modes: `critic` owns
# .claude/agents/design-critic.md and judges each drafted round; `judge` runs that same file in judge
# mode, with its model passed per call, and rules only on the items the critic escalated. Neither is a
# slice route; `route --critic` / `--judge` dispatch them. Either may run on the drafter's model:
# the operator dropped the different-model rule for the judge in workspace v66 and for the critic in v75.
# `reader` (P51) owns .claude/agents/pr-reader.md, the fresh-eyes PR reader: it reads a PR as a
# teammate would (the product diff, the body and details files, the team-rule files, the size count)
# and writes one findings file. Not a slice route; `route --reader` dispatches it.
# `code` owns .claude/agents/code-reader.md, the blind code reader: it reads one code change cold (the
# diff over the product pathspec and the files at head, never the workspace's records), reproduces each
# suspicion with a throwaway script and writes one findings file. Not a slice route; `route --code`
# dispatches it. Its own row, so the operator can repoint it without moving the reader row.
# One executor (workspace v66): the three slice rows -- high, research and mid -- all run the
# one `slice-executor` file, whose frontmatter carries the mid row (the default route). The two
# executor tiers of v23-v65 (slice-executor-mid / -high, split because the Agent tool could not set
# effort per dispatch before Claude Code 2.1.292) are retired, and so is the `tier` they carried:
# a dispatch names its row (`route=`), and the verdict records it (`route:`).
# Only the rows that own their file (FILE_ROWS: mid, design, critic, reader, code, explore) are written into
# frontmatter, so only they accept a full model id or "inherit"; every other row (high, research,
# judge) runs a file another row owns with its model passed per call, and the Agent tool's
# `model` is an enum, so those rows take an alias only.
# effort = "" is the escape hatch for a model that rejects the parameter: no effort line in the
# agent file and no per-dispatch effort. The named modes of v29-v52 (a top-level
# `mode` key) are retired; read_executors_toml refuses one.
# The defaults are the operator's own routes (workspace v80, v83): every opus row at high, mid on opus at
# medium, haiku at xhigh for explore only.
EXECUTOR_ROUTES = ("high", "research", "design", "critic", "judge", "reader", "code", "mid", "explore")  # print order
# v88 (P47-p5.S4): a per-page design round's spans carry `pass: frame | page <slug> | join` (drafter) or
# `scope: page | cross` (critic) in their prompt; the meter labels them apart so the means estimate a round.
# They run the design / critic rows: no route row of their own.
METER_PASS_ROUTES = ("design-frame", "design-page", "design-join", "critic-page", "critic-cross")
METER_ROUTES = EXECUTOR_ROUTES + METER_PASS_ROUTES + RETIRED_ROUTES  # the meter's order: history still holds cheap spans
ROUTE_DEFAULTS = {
    "high": {"model": "opus", "effort": "high"},
    "research": {"model": "opus", "effort": "high"},
    "design": {"model": "fable", "effort": "high"},
    "critic": {"model": "opus", "effort": "high"},
    "judge": {"model": "opus", "effort": "high"},
    "reader": {"model": "opus", "effort": "high"},
    "code": {"model": "opus", "effort": "high"},
    "mid": {"model": "opus", "effort": "medium"},
    "explore": {"model": "haiku", "effort": "xhigh"},
}
# The agent file each row dispatches to (canonical name; `installed_agent_name` applies a nested
# rename). The design row owns design-drafter and follows no other row, so one [claude.design]
# override governs it alone (before v60 it followed the high row). The critic row owns
# design-critic; the judge row runs that same file in judge mode. The reader row owns pr-reader, the
# code row code-reader.
SLICE_AGENT = "slice-executor"
ROUTE_AGENT = {"high": SLICE_AGENT, "research": SLICE_AGENT, "design": "design-drafter", "critic": "design-critic",
               "judge": "design-critic", "reader": "pr-reader", "code": "code-reader", "mid": SLICE_AGENT,
               "explore": "Explore"}
# The rows that own their agent file: sync-agents writes each one's resolved model/effort into its
# frontmatter, so only these accept a full model id or "inherit".
FILE_ROWS = ("mid", "design", "critic", "reader", "code", "explore")
# The executor pair v66 retired (last shipped in v65): old transcripts still name them, so the meter
# keeps reading them (`_meter_route`, `_meter_collect`'s canon map).
RETIRED_AGENTS = ("slice-executor-high", "slice-executor-mid")
# (label, canonical agent name, row) for the six agent files sync-agents manages, in print order.
MANAGED_AGENT_FILES = (
    ("slice-executor", ROUTE_AGENT["mid"], "mid"),
    ("design-drafter", ROUTE_AGENT["design"], "design"),
    ("design-critic", ROUTE_AGENT["critic"], "critic"),
    ("pr-reader", ROUTE_AGENT["reader"], "reader"),
    ("code-reader", ROUTE_AGENT["code"], "code"),
    ("Explore", ROUTE_AGENT["explore"], "explore"),
)
AGENT_MODEL_ALIASES = ("opus", "sonnet", "haiku", "fable")  # the Agent tool's `model` enum
EFFORT_LEVELS = ("low", "medium", "high", "xhigh", "max")  # the Agent tool's `effort` enum
# Commit attribution follows the model a slice actually ran on; anything else prints verbatim.
MODEL_ATTRIBUTION = {"opus": "Claude Opus 5.5", "sonnet": "Claude Sonnet 5.5",
                     "haiku": "Claude Haiku 5.5", "fable": "Claude Fable 5.2"}
# A loopback ANTHROPIC_BASE_URL is a local proxy (ocx's Kiro sidecar listens on 127.0.0.1:10100)
# that serves no Haiku 5.5: there the explore row falls back to EXPLORE_PROXY_MODEL, printed as a
# `fallback=` line by route.
LOOPBACK_HOSTS = ("127.0.0.1", "localhost", "::1")
EXPLORE_PROXY_MODEL = "sonnet"
# The same proxy serves no Fable either. The judge row (Opus @ high by default, so this never fires
# at the default) does NOT fall back: a judge is the stronger second opinion, so a substitute would be
# a weaker one. Only when an operator overrides the judge row to Fable and runs behind a loopback proxy
# does `route --judge` print a `skip=yes` line instead: the orchestrator dispatches no judge
# and the escalated items reach the operator marked low confidence.
JUDGE_PROXY_SKIP_FAMILY = "fable"
# The drafter must run, so a Fable design dispatch behind that proxy falls back to DESIGN_PROXY_MODEL
# (a `fallback=` line), whether Fable came from [claude.design] or from the phase's `Drafter:` line.
DESIGN_PROXY_MODEL = "opus"
# The phase's drafter (v96): a `Drafter: <alias>` line under intent.md's `## Design Style`, recorded at
# /create-phase (or with DECOMP's style question) from the orchestrator's suggestion and the operator's
# answer. `route --drafter --phase <P>` dispatches every drafter pass of that phase's jobs on it,
# the effort staying the design row's; no line is the design row. `opus` or `fable` only (passed per dispatch as
# an Agent-tool alias, and the two a design drafter is offered). The engine reads no markdown structure (headings
# and fences take too many forms to read safely): a line anywhere in intent.md that STARTS with the label counts,
# after list, quote, bold and table markup (`- **Drafter:** fable`, `> Drafter = fable`, `| Drafter | fable |`,
# `Drafter model: fable`); prose that only mentions the drafter is not a label line. The value must be exactly
# one of the two (`fable | opus` is refused), and two label lines that disagree are refused.
DRAFTER_CHOICES = ("opus", "fable")
DRAFTER_LINE_RE = re.compile(r"drafter(?:\s+model)?\s*[:=|]\s*(.*)$", re.IGNORECASE)


def read_executors_toml() -> dict:
    """{(row, key): value} from the repo-root executors.toml: the per-row overrides of the route table.

    Strict subset of TOML -- [claude.<row>] tables (a row of EXECUTOR_ROUTES) holding model/effort
    keys with double-quoted string values; '#' comments and blanks ignored. Anything else is an
    error naming its line, so a typo surfaces instead of silently keeping a default. A retired shape
    (the v29-v52 `mode` key, [claude.low], [codex.*]) is refused with its migration."""
    path = ROOT / "executors.toml"
    values: dict = {}
    if not path.exists():
        return values
    section = None
    rows = ", ".join(sorted(EXECUTOR_ROUTES))
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if re.match(r"^mode\s*=", line):
            raise SystemExit(
                f"executors.toml line {n}: the economy/flex presets were retired in workspace v53 — delete this line; "
                "the route table replaces them (flex was xhigh on both executor rows: set effort = \"xhigh\" under [claude.mid] "
                f"and [claude.high] to keep it); run: {ADAPTER_CMD} route"
            )
        if re.match(r"^\[\s*codex\s*\.\s*[^\]]*\]\s*(?:#.*)?$", line):
            raise SystemExit(
                f"executors.toml line {n}: Codex support was removed in workspace v31 — "
                "this workspace ships Claude Code only, so drop this section"
            )
        m = re.match(r"^\[\s*claude\s*\.\s*([^\]\s]*)\s*\]\s*(?:#.*)?$", line)
        if m:
            name = m.group(1)
            if name in RETIRED_ROUTES:
                raise SystemExit(
                    f"executors.toml line {n}: the {name} row was retired in workspace v83 — docs and qa slices "
                    "rated low now run on the mid row; drop this section (to change their model, set [claude.mid])"
                )
            if name in RETIRED_EXECUTOR_TIERS:
                raise SystemExit(
                    f"executors.toml line {n}: the {name} executor tier was retired in workspace v23 — "
                    "drop this section or move its settings to [claude.mid]"
                )
            if name not in EXECUTOR_ROUTES:
                raise SystemExit(f"executors.toml line {n}: unknown route {name} (valid: {rows})")
            section = name
            continue
        m = re.match(r'^(model|effort)\s*=\s*"([^"]*)"\s*(?:#.*)?$', line)
        if m:
            key, value = m.group(1), m.group(2)
            if section is None:
                raise SystemExit(f"executors.toml line {n}: key outside a section — put it under [claude.<row>] ({rows})")
            if (section, key) in values:
                raise SystemExit(f"executors.toml line {n}: duplicate {key} for [claude.{section}]")
            if key == "model" and not value:
                raise SystemExit(f"executors.toml line {n}: [claude.{section}] model must not be empty (efforts may be empty; models may not)")
            if key == "effort" and value and value not in EFFORT_LEVELS:
                raise SystemExit(
                    f"executors.toml line {n}: [claude.{section}] effort must be one of {', '.join(EFFORT_LEVELS)} "
                    f"— or \"\" to write no effort line (got {value!r})"
                )
            if key == "model" and section == "high" and value not in AGENT_MODEL_ALIASES:
                raise SystemExit(
                    f"executors.toml line {n}: [claude.high] model {value!r}: since v66 one executor file carries the mid row; "
                    f"the high row is passed per dispatch, so use an alias ({', '.join(AGENT_MODEL_ALIASES)}); "
                    "a full model id or inherit belongs under [claude.mid], which slice-executor.md carries"
                )
            if key == "model" and section not in FILE_ROWS and value not in AGENT_MODEL_ALIASES:
                raise SystemExit(
                    f"executors.toml line {n}: [claude.{section}] model {value!r}: route {section} dispatches to another row's "
                    f"agent file, so its model must be an Agent-tool alias ({', '.join(AGENT_MODEL_ALIASES)}); a full model id "
                    f"or inherit works only on {', '.join(r for r in EXECUTOR_ROUTES if r in FILE_ROWS)}, whose agent files carry it"
                )
            values[(section, key)] = value
            continue
        if re.match(r"^(model|effort)\s*=", line):
            raise SystemExit(f'executors.toml line {n}: values must be double-quoted TOML strings, e.g. model = "sonnet" under [claude.<row>]')
        raise SystemExit(f"executors.toml line {n}: cannot parse {line!r} (expected [claude.<row>] with row one of {rows}, or model/effort = \"...\")")
    return values


def resolve_routes(overrides=None) -> dict:
    """{row: {model, effort, model_source, effort_source}} in EXECUTOR_ROUTES order: the engine
    defaults overlaid key by key with executors.toml. A source is `default` or `executors.toml`."""
    if overrides is None:
        overrides = read_executors_toml()
    resolved: dict = {}
    for row in EXECUTOR_ROUTES:
        entry: dict = {}
        for key in ("model", "effort"):
            if (row, key) in overrides:
                entry[key], entry[f"{key}_source"] = overrides[(row, key)], "executors.toml"
            else:
                entry[key], entry[f"{key}_source"] = ROUTE_DEFAULTS[row][key], "default"
        resolved[row] = entry
    return resolved


def route_overrides(routes: dict) -> list:
    """`override=` lines for the rows executors.toml sets: what each pins against the engine default,
    or that it repeats the default (and so would stop following a later one). /update-workspace shows
    them to the operator, who decides whether to drop each [claude.<row>] table."""
    def pair(model, effort):
        return f"{model}@{effort or '(no effort)'}"
    lines = []
    for row in EXECUTOR_ROUTES:
        entry, default = routes[row], ROUTE_DEFAULTS[row]
        if "executors.toml" not in (entry["model_source"], entry["effort_source"]):
            continue
        if (entry["model"], entry["effort"]) == (default["model"], default["effort"]):
            lines.append(f"override={row} {pair(entry['model'], entry['effort'])} same as the default "
                         f"(drop [claude.{row}] to follow later defaults)")
        else:
            lines.append(f"override={row} {pair(entry['model'], entry['effort'])} "
                         f"(default {pair(default['model'], default['effort'])})")
    return lines


def route_source(entry: dict) -> str:
    """One source for a resolved row, or `model <s> / effort <s>` when its two keys differ."""
    if entry["model_source"] == entry["effort_source"]:
        return entry["model_source"]
    return f"model {entry['model_source']} / effort {entry['effort_source']}"


def _patched_agent_md(text: str, model: str, effort: str) -> str:
    """Rewrite only the model:/effort: frontmatter lines of a .claude agent file. Every other line
    is kept verbatim -- `name:` included, which for a renamed agent in a nested install is its
    installed name (the `subagent_type`), so sync-agents never undoes a rename."""
    if not text.startswith("---\n"):
        raise SystemExit("agent file has no frontmatter")
    end = text.find("\n---\n", 4)
    if end == -1:
        raise SystemExit("agent file frontmatter is unterminated")
    lines = [l for l in text[4:end].split("\n") if not l.startswith("model:") and not l.startswith("effort:")]
    insert_at = next((i for i, l in enumerate(lines) if l.startswith("permissionMode:")), len(lines))
    lines[insert_at:insert_at] = [f"model: {model}"] + ([f"effort: {effort}"] if effort else [])
    return "---\n" + "\n".join(lines) + text[end:]


def installed_agent_name(name: str) -> str:
    """The name a managed agent is installed under: its canonical name, or -- in a nested install
    whose host already has an agent of that name -- the rename the installer recorded in
    `.agentic-nested.json` `renames.agents`. The installed file is `<installed name>.md` and its `name:`
    frontmatter (the `subagent_type`) is the installed name too; the installer writes both."""
    if NESTED is None:
        return name
    renames = NESTED.get("renames")
    table = renames.get("agents") if isinstance(renames, dict) else None
    installed = table.get(name) if isinstance(table, dict) else None
    return installed if isinstance(installed, str) and installed else name


def executor_agent_files(routes: dict) -> list:
    """(label, path, model, effort) for the 6 managed agent files (MANAGED_AGENT_FILES): slice-executor
    from the mid row (the default route; high and research pass their model and effort per
    dispatch), design-drafter from its own design row, design-critic from the critic row, pr-reader
    from the reader row, code-reader from the code row and Explore
    from the explore row. high, research and judge own no file. Labels stay canonical;
    paths resolve through the nested rename map (`installed_agent_name`)."""
    return [
        (label, CLAUDE_AGENTS / f"{installed_agent_name(agent)}.md", routes[row]["model"], routes[row]["effort"])
        for label, agent, row in MANAGED_AGENT_FILES
    ]


def executor_agent_drift(routes: dict) -> tuple:
    """([(path, desired text)] for agent files that disagree with the routes, [missing paths]); writes nothing."""
    changed, missing = [], []
    for _label, path, model, effort in executor_agent_files(routes):
        if not path.exists():
            missing.append(path)
            continue
        current = path.read_text(encoding="utf-8")
        desired = _patched_agent_md(current, model, effort)
        if desired != current:
            changed.append((path, desired))
    return changed, missing


def sync_agents(args: argparse.Namespace) -> None:
    """Write the resolved route table into the six managed agent files' model/effort frontmatter:
    slice-executor from the mid row (high and research run it with their model and effort
    passed per dispatch), design-drafter from the design row, design-critic
    from the critic row (the judge row borrows that file, its model passed per call), pr-reader from
    the reader row, code-reader from the code row, Explore from
    the explore row (--check: report drift, write nothing, exit 1 when out of sync)."""
    overrides = read_executors_toml()
    routes = resolve_routes(overrides)
    config_present = (ROOT / "executors.toml").exists()
    legacy_env = ROOT / ".env"
    if legacy_env.exists() and "SLICE_EXECUTOR" in legacy_env.read_text(encoding="utf-8"):
        print("warning: .env holds SLICE_EXECUTOR_* keys, but executor config moved to executors.toml in v8 — .env is no longer read")
    drift, missing_paths = executor_agent_drift(routes)
    if not args.check:
        for path, desired in drift:
            write_text(path, desired)
    # Agent files live in the host when nested, so they are named from there (identical at root).
    changed = [shown(path) for path, _ in drift]
    missing = [shown(path) for path in missing_paths]
    for row in EXECUTOR_ROUTES:
        entry = routes[row]
        value = f"{entry['model']} @ {entry['effort'] or '(no effort line)'}"
        print(f"{row:<9} {value:<16} ({route_source(entry)})")
    print(f"config source: {f'executors.toml ({len(overrides)} override(s))' if config_present else 'defaults (no executors.toml)'}")
    for m in missing:
        print(f"missing agent file: {m}")
    if args.check:
        if changed or missing:
            print("out of sync with executors.toml/defaults:")
            for c in changed:
                print(f"- {c}")
            raise SystemExit(1)
        print("agent files in sync with executors.toml/defaults")
        return
    if changed:
        append_event("agents_synced", changed=changed, config_present=config_present)
        print("updated:")
        for c in changed:
            print(f"- {c}")
    else:
        print("already in sync; nothing written")
    if missing:
        raise SystemExit(1)


def _loopback_base_url():
    """ANTHROPIC_BASE_URL when its host is loopback (a local proxy such as ocx's Kiro sidecar), else None."""
    url = os.environ.get("ANTHROPIC_BASE_URL", "").strip()
    if not url:
        return None
    try:
        host = urlparse(url if "://" in url else f"http://{url}").hostname
    except ValueError:
        return None
    return url if host in LOOPBACK_HOSTS else None


def _route_fallback(row: str, routes: dict, proxy) -> tuple:
    """(model, effort, `fallback=` line or None) to dispatch one row under the environment: behind a
    loopback proxy (no Haiku 5.5, no Fable) the explore row takes EXPLORE_PROXY_MODEL and a Fable
    design row DESIGN_PROXY_MODEL."""
    model, effort = routes[row]["model"], routes[row]["effort"]
    if row == "design" and proxy is not None and model_family(model) == "fable":
        return DESIGN_PROXY_MODEL, effort, (f"fallback=design model {model} -> {DESIGN_PROXY_MODEL} "
                                            f"(loopback ANTHROPIC_BASE_URL {proxy}: ocx/Kiro serves no Fable)")
    if row != "explore" or proxy is None or model == EXPLORE_PROXY_MODEL:
        return model, effort, None
    return EXPLORE_PROXY_MODEL, effort, (f"fallback=explore model {model} -> {EXPLORE_PROXY_MODEL} "
                                         f"(loopback ANTHROPIC_BASE_URL {proxy}: ocx/Kiro serves no Haiku 5.5)")


def model_family(model: str):
    """The model family a row's model names, for the judge's proxy skip and the meter's routes: an
    alias is its own family; a full id names one (`claude-opus-5-5`, a provider id such as `us.anthropic.claude-opus-…`, a
    `[1m]` suffix -> opus). `inherit` and an id naming no family are None: unknown here."""
    m = (model or "").strip().lower()
    if m in AGENT_MODEL_ALIASES:
        return m
    found = re.search(r"(?<![a-z])(" + "|".join(AGENT_MODEL_ALIASES) + r")(?![a-z])", m)
    return found.group(1) if found else None


def phase_drafter(pdir: Path):
    """The model the phase's intent.md names on its `Drafter:` line (`opus` or `fable`; written under
    `## Design Style`), or None when no line names one. Never silently replaced by the default: a label line with
    another value, or two that disagree, is refused (DRAFTER_LINE_RE's comment has the forms read)."""
    intent = pdir / "intent.md"
    if not intent.is_file():
        return None
    hint = "; write one line `Drafter: fable` or `Drafter: opus` under ## Design Style, or delete it for the design row"
    found = []
    for line in intent.read_text(encoding="utf-8").split("\n"):
        bare = re.sub(r"^(?:>\s*)*(?:[-+*]\s+|\d+[.)]\s+)?", "", line.strip())
        bare = bare.replace("*", "").replace("`", "").strip()
        if bare.startswith("|"):
            bare = bare.strip("|").strip()
        m = DRAFTER_LINE_RE.match(bare)
        if not m:
            continue
        value = m.group(1).strip().rstrip("|").strip().lower()
        if value not in DRAFTER_CHOICES:
            raise SystemExit(f"route: {pdir.name}'s intent.md names the drafter {m.group(1).strip()!r}{hint}")
        found.append(value)
    if len(set(found)) > 1:
        raise SystemExit(f"route: {pdir.name}'s intent.md names two drafters ({', '.join(found)}){hint}")
    return found[0] if found else None


def _judge_proxy_skip(routes: dict, proxy):
    """The `skip=` line for a judge dispatch behind a loopback proxy that serves no Fable, else None."""
    if proxy is None or model_family(routes["judge"]["model"]) != JUDGE_PROXY_SKIP_FAMILY:
        return None
    return (f"skip=yes reason=loopback ANTHROPIC_BASE_URL {proxy} serves no Fable: dispatch no judge; "
            "the escalated items reach the operator marked low confidence")


def _route_env_warnings() -> list:
    """`warning=` lines for the environment variables that outrank a per-dispatch model or effort."""
    lines = []
    level = os.environ.get("CLAUDE_CODE_EFFORT_LEVEL", "").strip()
    if level:
        lines.append(f"warning=CLAUDE_CODE_EFFORT_LEVEL={level} is set and outranks every per-dispatch effort "
                     "(and every agent file's effort line); unset it for the route table's efforts to apply")
    force = os.environ.get("CLAUDE_CODE_SUBAGENT_MODEL_FORCE", "").strip()
    if force and force.lower() not in ("0", "false", "no"):
        lines.append(f"warning=CLAUDE_CODE_SUBAGENT_MODEL_FORCE={force} is set and overrides every model "
                     "(per-dispatch and frontmatter alike); unset it for the route table's models to apply")
    return lines


def slice_route(kind, risk, retry: bool) -> tuple:
    """(row, reason) for one dispatch: kind first, then risk, then attempt -- bump up, never down.
    A second attempt is always the high row; review, decomposition and co-work (the mockup span)
    route high by kind and research to the research row, whatever `risk` says; otherwise only a
    risk of exactly `low` reaches the mid row (implementation, fix, docs and qa; v83 retired the
    Haiku cheap row that docs and qa rated low ran on)."""
    if retry:
        return "high", "second attempt"
    if kind in ("review", "decomposition", "co-work"):
        return "high", f"kind {kind}"
    if kind == "research":
        return "research", "kind research"
    if risk != "low":
        return "high", f"risk {risk if risk not in (None, '') else 'unset'} (not low)"
    if kind in ("implementation", "fix", "docs", "qa"):
        return "mid", f"kind {kind} rated low"
    return "high", f"unknown kind {kind if kind not in (None, '') else 'unset'}"


def _dispatch_lines(row: str, routes: dict, proxy) -> tuple:
    """(the model..attribution lines for one dispatch on `row`, its fallback line or None)."""
    model, effort, fallback = _route_fallback(row, routes, proxy)
    lines = [
        f"model={model}",
        f"pass_model={'yes' if model in AGENT_MODEL_ALIASES else 'no'}",
        f"effort={effort}",
        f"pass_effort={'yes' if effort else 'no'}",
        f"attribution={MODEL_ATTRIBUTION.get(model, model)}",
    ]
    return lines, fallback


def cmd_executor_route(args: argparse.Namespace) -> None:
    """Print the deterministic routing decision the orchestrator dispatches from, one key=value per
    line: bare, the resolved route table and the agent files' sync state; with a slice id, that
    slice's route (--retry: its second attempt); --drafter / --critic / --judge / --reader / --code /
    --explore, the design subagent's (the design row), the design critic's two modes (the critic and
    judge rows, both running design-critic), the fresh-eyes PR reader's (the reader row, running
    pr-reader), the blind code reader's (the code row, running code-reader) and
    the lookup agent's (the explore row). Every form names the
    agent file it dispatches to as `subagent_type=`; the three slice rows all run slice-executor.

    The critic and the judge may share the drafter's model (v75). Behind a loopback proxy (no Fable)
    --judge on a Fable override prints
    `skip=yes reason=…` and exits 0: unlike a `fallback=` line, which names a substitute model to
    dispatch, `skip=` means dispatch nothing.
    Reads executors.toml (a malformed one errors here) and writes nothing."""
    forms = [f for f, on in (("<slice_id>", args.slice is not None), ("--drafter", args.drafter), ("--critic", args.critic),
                             ("--judge", args.judge), ("--reader", args.reader), ("--code", args.code),
                             ("--explore", args.explore)) if on]
    if len(forms) > 1:
        raise SystemExit(f"route: {' and '.join(forms)} are mutually exclusive; give at most one")
    if args.retry and args.slice is None:
        raise SystemExit("route: --retry needs a <slice_id> (a second attempt is a slice's)")
    if args.phase and not args.drafter:
        raise SystemExit("route: --phase reads the phase's drafter and goes with --drafter only")
    routes = resolve_routes()
    drafter = phase_drafter(require_phase(args.phase)) if args.phase else None
    if drafter:
        routes = {**routes, "design": {**routes["design"], "model": drafter}}
    proxy = _loopback_base_url()
    if args.slice is not None:
        sdir = require_slice(args.slice)
        sdata = read_json(sdir / "slice.json")
        kind, risk = sdata.get("kind"), sdata.get("risk")
        attempt = 2 if args.retry else 1
        row, reason = slice_route(kind, risk, args.retry)
        lines, fallback = _dispatch_lines(row, routes, proxy)
        print(f"slice={args.slice}")
        print(f"phase={args.slice.split('.', 1)[0]}")
        print(f"kind={kind if kind not in (None, '') else 'unset'}")
        print(f"risk={risk if risk not in (None, '') else 'unset'}")
        print(f"attempt={attempt}")
        print(f"route={row}")
        print(f"reason={reason}")
        print(f"subagent_type={installed_agent_name(ROUTE_AGENT[row])}")
        print("\n".join(lines))
        extra = [fallback] if fallback else []
    elif args.drafter or args.critic or args.judge or args.reader or args.code or args.explore:
        row = ("design" if args.drafter else "critic" if args.critic else "judge" if args.judge
               else "reader" if args.reader else "code" if args.code else "explore")
        agent = ROUTE_AGENT[row]
        skip = _judge_proxy_skip(routes, proxy) if row == "judge" else None
        lines, fallback = _dispatch_lines(row, routes, proxy)
        print(f"agent={agent}")
        print(f"route={row}")
        if args.drafter:
            print(f"drafter_source={'phase ' + args.phase + ' Drafter: ' + drafter if drafter else 'design row'}")
        print(f"subagent_type={installed_agent_name(agent)}")
        print("\n".join(lines))
        extra = [fallback] if fallback else []
        if skip:
            extra.append(skip)
    else:
        table = [("route", "agent", "model", "effort", "source")] + [
            (row, ROUTE_AGENT[row], routes[row]["model"], routes[row]["effort"] or "(no effort line)", route_source(routes[row]))
            for row in EXECUTOR_ROUTES
        ]
        widths = [max(len(r[i]) for r in table) for i in range(4)]
        for r in table:
            print("  ".join(c.ljust(w) for c, w in zip(r, widths)) + "  " + r[4])
        drift, missing = executor_agent_drift(routes)
        stale = [shown(path) for path, _ in drift] + [f"{shown(path)} (missing)" for path in missing]
        if stale:
            print(f"agent files: out of sync: {', '.join(stale)} (run: {ADAPTER_CMD} sync-agents)")
        else:
            print("agent files: in sync")
        extra = route_overrides(routes) + [f for f in (_route_fallback(row, routes, proxy)[2] for row in EXECUTOR_ROUTES) if f]
        judge_skip = _judge_proxy_skip(routes, proxy)
        if judge_skip:
            extra.append(judge_skip.replace("skip=yes ", "skip=judge ", 1))
        if proxy is None:
            extra.insert(0, "proxy=none")
        else:
            extra.insert(0, f"proxy={proxy} (loopback)")
    for line in extra + _route_env_warnings():
        print(line)


_VERDICTS = ("done", "escalate", "needs_operator", "blocked")  # the verdict table's columns; anything else is `other`


def _slice_verdicts(phase=None, slice_id=None) -> dict:
    """{slice id: (kind, verdict, source)} of every active and archived slice (one phase's, or one slice): the
    verdict is the `status:` line of its result.md (the executor's verdict block), else its slice.json status."""
    out = {}
    for root in (ACTIVE, ARCHIVED):
        for sj in (sorted(root.glob("*/slices/*/slice.json")) if root.is_dir() else []):
            try:
                data = read_json(sj)
            except (OSError, ValueError):
                continue
            sid = data.get("id") if isinstance(data, dict) else None
            if not isinstance(sid, str) or (slice_id and sid != slice_id) or (phase and sid.split(".", 1)[0] != phase):
                continue
            verdict, source = None, "slice.json"
            result = sj.parent / "result.md"
            if result.is_file():
                found = [v.lower() for k, v in METER_VERDICT_RE.findall(result.read_text(encoding="utf-8", errors="replace"))
                         if k.lower() == "status"]
                if found:
                    verdict, source = found[0], "result.md"
            out[sid] = (data.get("kind") or "unset", verdict or str(data.get("status") or "?"), source)
    return out


def _verdict_table(verdicts: dict) -> dict:
    """{kind: {n, done, escalate, needs_operator, blocked, other}} over _slice_verdicts' values."""
    table: dict = {}
    for kind, verdict, _source in verdicts.values():
        row = table.setdefault(kind, {"n": 0, **{v: 0 for v in _VERDICTS}, "other": 0})
        row["n"] += 1
        row[verdict if verdict in _VERDICTS else "other"] += 1
    return dict(sorted(table.items()))


# ---------------------------------------------------------------------------------------------------
# The transcript meter (workspace v61). `meter` -- and nothing else: no hook, no other
# command -- reads Claude Code's own session transcripts, `<config>/projects/<slug>/<session>.jsonl`
# (the main thread) and `<session>/subagents/agent-*.jsonl` + `.meta.json` (one file per span), and
# meters what each actually processed:
# - a request is an assistant entry, counted ONCE per `message.id` (else `requestId`): Claude Code
#   writes one entry per content block, the usage repeating with a growing `output_tokens`, so the
#   entry with the largest output is kept (the first undercounts output ~20x);
# - most subagent requests never log a final usage (`stop_reason` stays null, `output_tokens` 2-20):
#   those are counted per group (`no_final`), their output and $ are FLOORS (marked `>=`, never
#   estimated), the main thread's share is an upper bound, and context and cache are exact;
# - `message.model == "<synthetic>"` is an API error, not a request; when its text or error names a
#   usage / rate limit it is a limit hit, and a span whose LAST assistant entry is one ended on it;
# - cache writes split by `usage.cache_creation` into 5 m and 1 h (the main thread writes 1 h,
#   subagents 5 m); no split counts as 5 m;
# - context = input + cache read + cache write per request: volume processed, not window size.
# Spans go to slices by their first prompt (a `slice:` line, then a known slice id, then a design
# round address through its round.json), then by time; main-thread requests go by time into slice
# windows from `slice_status_changed` -- a slice's window runs from the previous slice's finish to its
# own finish, so planning time counts toward the slice it plans.
#
# List prices in $/MTok per model id: (input, 5 m cache write, 1 h cache write, cache read, output).
# Source: https://platform.claude.com/docs/en/about-claude/pricing (fetched 2026-10-20). A model not
# listed is never guessed: it is shown unpriced as `?`.
PRICES = {
    "claude-fable-5-2": (8.0, 10.0, 16.0, 0.20, 40.0),  # v96: list price from the claude-api skill (cached 2026-11-03)
    "claude-fable-5-1": (10.0, 12.5, 20.0, 0.25, 50.0),
    "claude-fable-5": (10.0, 12.5, 20.0, 1.0, 50.0),
    "claude-opus-5-5": (4.0, 5.0, 8.0, 0.20, 20.0),
    "claude-opus-5": (5.0, 6.25, 10.0, 0.50, 25.0),
    "claude-sonnet-5-5": (2.0, 2.5, 4.0, 0.10, 10.0),
    "claude-sonnet-5": (2.0, 2.5, 4.0, 0.20, 10.0),
    "claude-haiku-5-5": (0.10, 0.125, 0.20, 0.01, 0.50),
    "claude-haiku-4-5": (1.0, 1.25, 2.0, 0.10, 5.0),
}
# Priced by prompt length (same source): a request whose prompt -- input + cache read + cache write --
# is over the threshold pays the second row, cache hit or not.
PRICES_LONG_PROMPT = {"claude-haiku-5-5": (100_000, (0.50, 0.625, 1.0, 0.05, 2.50))}
METER_PRICES_SOURCE = "https://platform.claude.com/docs/en/about-claude/pricing, fetched 2026-10-20"
# Composed from the id block's patterns, so a tailed `P46-k2.S1` and a v73 `P-7kq2.S1` attribute beside `P12.S1`.
METER_SLICE_ID_RE = re.compile(rf"\b{PHASE_ID_PATTERN}\.{SLICE_SUFFIX_PATTERN}\b")
METER_SLICE_LINE_RE = re.compile(rf"(?im)^[\s>*`-]*slice[`*]*\s*:\s*[`*]*({PHASE_ID_PATTERN}\.[A-Za-z][A-Za-z0-9]*)")
METER_ROUND_RE = re.compile(r"\b(\d{2}-[a-z0-9][a-z0-9-]*)/(\d{2}-[a-z0-9][a-z0-9-]*)\b")
METER_LIMIT_RE = re.compile(r"(?i)\b(usage|rate|spend|session|weekly|monthly|daily|5-hour)\b[^.\n]{0,24}\blimit|\blimit (reached|exceeded)")
METER_RESET_RE = re.compile(r"(?i)\bresets?\s+(?:at\s+)?([^·\n]+?)\s*(?:·|$)")
METER_VERDICT_RE = re.compile(r"(?im)^[\s>*-]*[`*_]*(status|verdict)[`*_]*\s*:\s*[`*_]*([a-z][a-z_]*)")
METER_JUDGE_RE = re.compile(r"(?im)^\s*mode\s*:\s*judge\b")
METER_PASS_RE = re.compile(r"(?im)^[\s>*-]*[`*_]*pass[`*_]*\s*:\s*[`*_]*(frame|page|join)\b")
METER_SCOPE_RE = re.compile(r"(?im)^[\s>*-]*[`*_]*scope[`*_]*\s*:\s*[`*_]*(page|cross)\b")


def _meter_price(model) -> "tuple | None":
    """The PRICES row for a transcript model id (a `[1m]` tag and a `-YYYYMMDD` date stripped), else None."""
    if not isinstance(model, str):
        return None
    mid = re.sub(r"-\d{8}$", "", re.sub(r"\[[^\]]*\]$", "", model.strip()))
    return PRICES.get(mid)


def _meter_new() -> dict:
    return {"requests": 0, "input": 0, "cache_read": 0, "cache_write_5m": 0, "cache_write_1h": 0,
            "output": 0, "cost": 0.0, "unpriced": 0, "limit_hits": 0, "no_final": 0}


def _meter_add(agg: dict, other: dict) -> dict:
    for k in agg:
        agg[k] += other.get(k, 0)
    return agg


def _meter_request(agg: dict, model, usage: dict, final: bool = True) -> None:
    """Add one deduplicated request's usage (and list-price cost) into `agg`. `final` = some entry of
    the request carried a stop_reason; without one its output (and so $) is a floor."""
    def num(v):
        return v if isinstance(v, (int, float)) else 0
    inp = num(usage.get("input_tokens"))
    cr = num(usage.get("cache_read_input_tokens"))
    cw = num(usage.get("cache_creation_input_tokens"))
    out = num(usage.get("output_tokens"))
    split = usage.get("cache_creation") if isinstance(usage.get("cache_creation"), dict) else {}
    w1h = num(split.get("ephemeral_1h_input_tokens"))
    w5 = num(split.get("ephemeral_5m_input_tokens"))
    w5 += max(cw - w1h - w5, 0)  # no split (or a short one): the rest is a 5 m write
    agg["requests"] += 1
    agg["no_final"] += 0 if final else 1
    agg["input"] += inp
    agg["cache_read"] += cr
    agg["cache_write_5m"] += w5
    agg["cache_write_1h"] += w1h
    agg["output"] += out
    price = _meter_price(model)
    if price is None:
        agg["unpriced"] += 1
        return
    long_prompt = PRICES_LONG_PROMPT.get(re.sub(r"-\d{8}$", "", re.sub(r"\[[^\]]*\]$", "", model.strip())))
    if long_prompt and inp + cr + w5 + w1h > long_prompt[0]:
        price = long_prompt[1]
    agg["cost"] += (inp * price[0] + w5 * price[1] + w1h * price[2] + cr * price[3] + out * price[4]) / 1e6


def _meter_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(x.get("text", "") for x in content if isinstance(x, dict) and x.get("type") == "text")
    return ""


def _meter_limit(entry: dict, text: str) -> bool:
    err = " ".join(str(entry.get(k) or "") for k in ("error", "apiError"))
    return bool(METER_LIMIT_RE.search(text)) or "limit" in err.lower()


def _meter_scan(path: Path, span: bool) -> dict:
    """One transcript file read once: its deduplicated requests and limit hits, and for a span its
    first prompt, resume count, final report and first / last timestamps. Unreadable lines are skipped."""
    reqs: dict = {}   # key -> [ts, model, usage, saw a stop_reason]
    limits: list = []  # (ts, reset text)
    out = {"reqs": reqs, "limits": limits, "prompt": None, "resumes": 0, "final": None, "first": None, "last": None,
           "last_limit": None, "models": {}}
    last_asst = None
    try:
        fh = path.open(encoding="utf-8", errors="replace")
    except OSError:
        return out
    with fh:
        for line in fh:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            kind = d.get("type")
            if kind not in ("assistant", "user"):
                continue
            if not span and d.get("isSidechain") is True:
                continue  # an older transcript's inline sidechain: never the main thread's
            ts = _meter_ts(d.get("timestamp"))
            if span and ts is not None:
                out["first"] = ts if out["first"] is None else min(out["first"], ts)
                out["last"] = ts if out["last"] is None else max(out["last"], ts)
            msg = d.get("message") if isinstance(d.get("message"), dict) else {}
            if kind == "user":
                if not span or d.get("isCompactSummary"):
                    continue
                content = msg.get("content")
                if isinstance(content, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in content):
                    continue
                origin = d.get("origin") if isinstance(d.get("origin"), dict) else {}
                if origin.get("kind") == "coordinator":
                    out["resumes"] += 1  # a SendMessage from the orchestrator continuing this span
                elif not d.get("isMeta") and _meter_text(content).strip():
                    if out["prompt"] is None:
                        out["prompt"] = _meter_text(content)
                    else:
                        out["resumes"] += 1
                continue
            model = msg.get("model")
            if model == "<synthetic>":
                text = _meter_text(msg.get("content"))
                hit = _meter_limit(d, text)
                if hit:
                    m = METER_RESET_RE.search(text)
                    limits.append((ts, m.group(1).strip() if m else None))
                last_asst = ("limit", limits[-1][1]) if hit else ("synthetic", None)
                continue
            last_asst = ("request", None)
            if span:
                for block in msg.get("content") or []:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "text" and block.get("text", "").strip():
                        out["final"] = block["text"]
                    elif block.get("type") == "tool_use" and block.get("name") == "SubagentHandback":
                        inp = block.get("input") if isinstance(block.get("input"), dict) else {}
                        if isinstance(inp.get("message"), str):
                            out["final"] = inp["message"]
            usage = msg.get("usage")
            if not isinstance(usage, dict):
                continue
            key = msg.get("id") or d.get("requestId") or d.get("uuid")
            prev = reqs.get(key)
            final = msg.get("stop_reason") is not None
            if prev is None:
                reqs[key] = [ts, model, usage, final]
            else:
                prev[3] = prev[3] or final
                if (usage.get("output_tokens") or 0) > (prev[2].get("output_tokens") or 0):
                    prev[2] = usage
    if last_asst and last_asst[0] == "limit":
        out["last_limit"] = last_asst[1] or ""
    for _ts, model, _u, _f in reqs.values():
        out["models"][model] = out["models"].get(model, 0) + 1
    return out


def _meter_session_range(path: Path) -> tuple:
    """(first, last) timestamp of a session file from its head and its tail -- never a full read."""
    first = last = None
    try:
        with path.open("rb") as fh:
            for _ in range(200):
                line = fh.readline()
                if not line:
                    break
                try:
                    first = _meter_ts(json.loads(line).get("timestamp"))
                except (ValueError, AttributeError):
                    continue
                if first is not None:
                    break
            size = path.stat().st_size
            fh.seek(max(0, size - 1_048_576))
            for line in reversed(fh.read().splitlines()):
                try:
                    last = _meter_ts(json.loads(line).get("timestamp"))
                except (ValueError, AttributeError):
                    continue
                if last is not None:
                    break
    except OSError:
        return None, None
    if last is None:
        try:
            last = path.stat().st_mtime
        except OSError:
            pass
    return first, last if last is not None else first


def _meter_project_dirs(explicit) -> tuple:
    """(project dirs to read, how they were found). `--transcripts` overrides discovery; otherwise the
    session root's slug under `${CLAUDE_CONFIG_DIR:-~/.claude}/projects/`, plus its worktree sessions'."""
    if explicit:
        return [Path(p).expanduser() for p in explicit], "--transcripts"
    base = Path(os.environ.get("CLAUDE_CONFIG_DIR") or "~/.claude").expanduser() / "projects"
    slug = re.sub(r"[^A-Za-z0-9]", "-", str(HOST_ROOT or ROOT))
    dirs = []
    if base.is_dir():
        for d in sorted(base.iterdir()):
            if d.is_dir() and (d.name == slug or d.name.startswith(slug + "--claude-worktrees-")):
                dirs.append(d)
    return dirs, str(base / slug)


def _meter_known_slices(events: list) -> tuple:
    """({slice id: kind or None}) from the phase folders (active and archived) and the events."""
    kinds: dict = {}
    for root in (ACTIVE, ARCHIVED):
        if not root.is_dir():
            continue
        for sj in root.glob("*/slices/*/slice.json"):
            try:
                kinds[sj.parent.name] = read_json(sj).get("kind")
            except (OSError, ValueError):
                kinds.setdefault(sj.parent.name, None)
    for ev in events:
        sid = ev.get("slice")
        if isinstance(sid, str) and sid:
            if kinds.get(sid) is None and ev.get("kind"):
                kinds[sid] = ev.get("kind")
            kinds.setdefault(sid, None)
    return kinds


class _MeterWindows:
    """Slice windows from `slice_status_changed`: each finished slice owns (previous finish, own finish];
    the first finished slice starts at its own start; after the last finish, the latest-started open
    slice owns the time. `at(t)` is the slice id, or None outside every window."""

    def __init__(self, events: list):
        st: dict = {}
        for ev in events:
            if ev.get("type") != "slice_status_changed" or not isinstance(ev.get("slice"), str):
                continue
            t = _meter_ts(ev.get("ts"))
            if t is None:
                continue
            s = st.setdefault(ev["slice"], {"start": None, "done": None, "status": None})
            if ev.get("new_status") == "in_progress" and s["start"] is None:
                s["start"] = t
            if ev.get("new_status") == "done":
                s["done"] = t
            s["status"] = ev.get("new_status")
        self.finished = sorted((s["done"], sid) for sid, s in st.items() if s["status"] == "done" and s["done"] is not None)
        self.ends = [f for f, _ in self.finished]
        self.open = sorted((s["start"], sid) for sid, s in st.items() if s["status"] != "done" and s["start"] is not None)
        self.first_start = None
        if self.finished:
            s0 = st[self.finished[0][1]]["start"]
            self.first_start = s0 if s0 is not None else self.finished[0][0]
        self.bounds: dict = {}
        prev = self.first_start
        for end, sid in self.finished:
            self.bounds[sid] = (prev, end)
            prev = end
        # The open slices that own the time after the last finish: those started since it (a slice
        # left open long before is stale), else every open one.
        last = self.ends[-1] if self.ends else float("-inf")
        self.current = [(start, sid) for start, sid in self.open if start >= last] or self.open
        for start, sid in self.current:
            self.bounds[sid] = (self.ends[-1] if self.ends else start, None)

    def at(self, t) -> "str | None":
        if t is None:
            return None
        i = bisect.bisect_left(self.ends, t)
        if i < len(self.ends):
            if i == 0 and self.first_start is not None and t < self.first_start:
                return None
            return self.finished[i][1]
        if not self.current:
            return None
        live = [sid for start, sid in self.current if start <= t]
        return live[-1] if live else self.current[0][1]  # before its slice start: planning it


def _meter_round_slice(job: str, rnd: str) -> "str | None":
    """The slice a design round belongs to: its round.json `slice`, else its job.json `slice`."""
    jobs = ROOT / DESIGN_ROOT_REL / "jobs" / job
    for path in (jobs / "rounds" / rnd / "round.json", jobs / "job.json"):
        try:
            sid = read_json(path).get("slice")
        except (OSError, ValueError, AttributeError):
            continue
        if isinstance(sid, str) and sid:
            return sid
    return None


def _meter_attribute(prompt: str, start, known: dict, windows: _MeterWindows) -> tuple:
    """(slice id or 'unattributed', how) for a span from its first prompt, then its start time."""
    prompt = prompt or ""
    m = METER_SLICE_LINE_RE.search(prompt)
    if m:
        return m.group(1), "slice-line"
    for sid in METER_SLICE_ID_RE.findall(prompt):
        if sid in known:
            return sid, "named"
    for job, rnd in METER_ROUND_RE.findall(prompt):
        sid = _meter_round_slice(job, rnd)
        if sid:
            return sid, "round"
    sid = windows.at(start)
    if sid:
        return sid, "window"
    return "unattributed", "none"


def _meter_slice_families() -> tuple:
    """(high row's model family, mid row's, high row's effort, mid row's) from the resolved route
    table, for reading `slice-executor` spans; the engine defaults when executors.toml cannot be read."""
    try:
        routes = resolve_routes()
    except (SystemExit, Exception):  # noqa: BLE001 - the meter reads history; a bad toml must not stop it
        routes = resolve_routes({})
    return (model_family(routes["high"]["model"]), model_family(routes["mid"]["model"]),
            routes["high"]["effort"], routes["mid"]["effort"])


def _meter_route(agent: str, prompt: str, model, kind, families=None, effort=None) -> str:
    """The route row a span most likely ran on, for the means: the agent type, the judge mode, the
    slice kind (research) and the model. Approximate by nature, and more so for the one
    `slice-executor` (v66), which every slice row runs: a research kind reads as research, review,
    decomposition and co-work as high (they route there by kind), a haiku model as cheap (the row v83
    retired: old spans keep the label), a model of
    the high row's family (and not the mid row's, `families`) as high; when the two rows share a family
    (opus at v80's defaults) the span's recorded effort tells them apart; anything else reads as mid.
    The retired pair (v23-v65, still in old transcripts) keeps its reading: slice-executor-high is
    research by kind, else high; slice-executor-mid is cheap on haiku, else mid. Other agents keep their name."""
    if agent == "design-drafter":  # v88: a per-page round's pass, from the prompt's `pass:` line
        found = METER_PASS_RE.search(prompt or "")
        return f"design-{found.group(1).lower()}" if found else "design"
    if agent == "design-critic":
        if METER_JUDGE_RE.search(prompt or ""):
            return "judge"
        found = METER_SCOPE_RE.search(prompt or "")
        return f"critic-{found.group(1).lower()}" if found else "critic"
    if agent == "pr-reader":
        return "reader"
    if agent == "code-reader":
        return "code"
    if agent == "Explore":
        return "explore"
    if agent == "slice-executor-high":
        return "research" if kind == "research" else "high"
    if agent == "slice-executor-mid":
        return "cheap" if isinstance(model, str) and "haiku" in model else "mid"
    if agent == SLICE_AGENT:
        if kind == "research":
            return "research"
        if kind in ("review", "decomposition", "co-work"):
            return "high"
        family = model_family(model) if isinstance(model, str) else None
        if family == "haiku":
            return "cheap"
        high, mid, high_effort, mid_effort = families if families is not None else _meter_slice_families()
        if not family or family != high:
            return "mid"
        if family != mid:
            return "high"
        return "high" if effort and effort == high_effort and effort != mid_effort else "mid"
    return agent or "?"


def _meter_verdict(agent: str, final) -> str:
    """The `status:` line (design spans: `verdict:` first) of a span's final report, else `?`."""
    found = {}
    for key, value in METER_VERDICT_RE.findall(final or ""):
        found.setdefault(key.lower(), value.lower())
    if agent.startswith("design-") and "verdict" in found:
        return found["verdict"]
    return found.get("status") or found.get("verdict") or "?"


def _meter_collect(dirs: list, known: dict, windows: "_MeterWindows", selected, lo, hi) -> dict:
    """Read the sessions overlapping [lo, hi] (None = unbounded) and meter them. `selected(slice)` says
    whether a slice is in the report; everything else is `before`, `after` or `other`."""
    canon = {installed_agent_name(a): a for a in (*ROUTE_AGENT.values(), *RETIRED_AGENTS)}
    canon.update({f"wf-{a}": a for a in RETIRED_AGENTS})  # a nested rename the marker no longer records
    families = _meter_slice_families()
    res = {"sessions": [], "main": {}, "spans": [], "outside": {}, "found": 0, "windows": windows, "kinds": known}
    for d in dirs:
        for path in sorted(d.glob("*.jsonl")):
            res["found"] += 1
            first, last = _meter_session_range(path)
            if first is None or (lo is not None and last is not None and last < lo) or (hi is not None and first > hi):
                continue
            sess = {"session": path.stem, "dir": d.name, "first": first, "last": last, "main": _meter_new(), "spans": 0}
            scan = _meter_scan(path, span=False)
            for ts, model, usage, final in scan["reqs"].values():
                if model == "<synthetic>":
                    continue
                one = _meter_new()
                _meter_request(one, model, usage, final)
                _meter_add(sess["main"], one)
                _meter_main_bucket(res, windows.at(ts), ts, selected, lo, hi, one)
            for ts, _reset in scan["limits"]:
                one = _meter_new()
                one["limit_hits"] = 1
                _meter_add(sess["main"], one)
                _meter_main_bucket(res, windows.at(ts), ts, selected, lo, hi, one)
            for jl in sorted((path.parent / path.stem / "subagents").glob("agent-*.jsonl")):
                meta = {}
                mp = jl.with_name(jl.name[:-len(".jsonl")] + ".meta.json")
                if mp.exists():
                    try:
                        meta = json.loads(mp.read_text(encoding="utf-8"))
                    except (OSError, ValueError):
                        meta = {}
                sp = _meter_scan(jl, span=True)
                agent = canon.get(meta.get("agentType"), meta.get("agentType") or "?")
                sid, how = _meter_attribute(sp["prompt"], sp["first"], known, windows)
                agg = _meter_new()
                for _ts, model, usage, final in sp["reqs"].values():
                    if model != "<synthetic>":
                        _meter_request(agg, model, usage, final)
                agg["limit_hits"] = len(sp["limits"])
                model = meta.get("model") or (max(sp["models"], key=sp["models"].get) if sp["models"] else None)
                if sp["last_limit"] is not None:
                    outcome = "limit"
                elif meta and meta.get("finished") is not True:
                    outcome = "running"
                else:
                    outcome = _meter_verdict(agent, sp["final"])
                minutes = round((sp["last"] - sp["first"]) / 60, 1) if sp["first"] is not None and sp["last"] is not None else None
                span = {"id": jl.stem[len("agent-"):], "session": path.stem, "agent": agent, "model": model,
                        "effort": meta.get("effort"), "route": _meter_route(agent, sp["prompt"], model, known.get(sid), families,
                                                                            meta.get("effort")),
                        "slice": sid, "attributed_by": how, "start": sp["first"], "minutes": minutes,
                        "resumes": sp["resumes"], "outcome": outcome, "reset": sp["last_limit"] or None,
                        "usage": agg}
                sess["spans"] += 1
                if selected(sid):
                    res["spans"].append(span)
            res["sessions"].append(sess)
    return res


def _meter_main_bucket(res: dict, sid, ts, selected, lo, hi, one: dict) -> None:
    """One main-thread request into its slice's row, else `before` / `after` the selected windows, or
    `other` (inside them, in another stream's slice)."""
    if sid is not None and selected(sid) and sid != "unattributed":
        _meter_add(res["main"].setdefault(sid, _meter_new()), one)
        return
    lo = lo if lo is not None else res["windows"].first_start
    where = "before" if (lo is not None and ts is not None and ts < lo) else "after" if (hi is None or ts is None or ts > hi) else "other"
    _meter_add(res["outside"].setdefault(where, _meter_new()), one)


def _meter_ctx(agg: dict) -> int:
    return agg["input"] + agg["cache_read"] + agg["cache_write_5m"] + agg["cache_write_1h"]


def _meter_tok(n) -> str:
    if n >= 1e6:
        return f"{n / 1e6:.2f}M"
    if n >= 1e3:
        return f"{n / 1e3:.1f}k"
    return str(int(n))


def _meter_cost(agg: dict) -> str:
    if agg["requests"] and agg["unpriced"] == agg["requests"]:
        return "?"
    return f"{agg['cost']:.2f}" + ("+?" if agg["unpriced"] else "")


def _meter_fl(agg: dict) -> str:
    """`>=` for a group with requests that never logged a final usage: its output and $ are floors."""
    return "≥" if agg.get("no_final") else ""


def _meter_out(agg: dict) -> str:
    return _meter_fl(agg) + _meter_tok(agg["output"])


def _meter_usd(agg: dict) -> str:
    c = _meter_cost(agg)
    return c if c.startswith("?") else _meter_fl(agg) + c


def _meter_flagged(agg: dict) -> dict:
    """A copy of a usage group for --json, with `output_floor` true when its output and $ are floors."""
    return {**agg, "output_floor": bool(agg.get("no_final"))}


def _meter_columns(rows: list) -> list:
    widths = [max(len(r[i]) for r in rows) for i in range(len(rows[0]))]
    return ["  ".join(c.ljust(w) if i == 0 else c.rjust(w) for i, (c, w) in enumerate(zip(r, widths))).rstrip() for r in rows]


def _meter_row(label: str, n, agg: dict, minutes=None, verdicts: str = "") -> list:
    return [label, "-" if n is None else str(n), str(agg["requests"]), _meter_tok(_meter_ctx(agg)), _meter_out(agg),
            _meter_usd(agg), "-" if minutes is None else f"{minutes:.1f}", str(agg["limit_hits"]), verdicts or "-"]


_METER_HEAD = ["row", "n", "requests", "context", "output", "$", "min", "limits", "verdicts"]


def _meter_report(res: dict, slices: list) -> dict:
    """The per-slice rows, the per-phase totals and the means, as plain data (the --json body)."""
    by_slice: dict = {}
    for sid in slices:
        by_slice[sid] = {"main": res["main"].get(sid, _meter_new()), "spans": [s for s in res["spans"] if s["slice"] == sid]}
    unattributed = [s for s in res["spans"] if s["slice"] not in by_slice]
    phases: dict = {}
    for sid, row in by_slice.items():
        ph = phases.setdefault(sid.split(".", 1)[0], {"main": _meter_new(), "by_agent": {}, "span_total": _meter_new()})
        _meter_add(ph["main"], row["main"])
        for s in row["spans"]:
            _meter_add(ph["by_agent"].setdefault(s["agent"], _meter_new()), s["usage"])
            _meter_add(ph["span_total"], s["usage"])
    for s in unattributed:
        ph = phases.setdefault("unattributed", {"main": _meter_new(), "by_agent": {}, "span_total": _meter_new()})
        _meter_add(ph["by_agent"].setdefault(s["agent"], _meter_new()), s["usage"])
        _meter_add(ph["span_total"], s["usage"])
    # means: per route (per span) and per slice kind (per slice, main thread included)
    routes: dict = {}
    for s in res["spans"]:
        r = routes.setdefault(s["route"], {"spans": 0, "minutes": 0.0, "cost": 0.0, "unpriced": 0})
        r["spans"] += 1
        r["minutes"] += s["minutes"] or 0.0
        r["cost"] += s["usage"]["cost"]
        r["unpriced"] += s["usage"]["unpriced"]
    kinds: dict = {}
    for sid, row in by_slice.items():
        if not row["spans"] and not row["main"]["requests"]:
            continue
        k = kinds.setdefault(res["kinds"].get(sid) or "unset", {"slices": 0, "spans": 0, "minutes": 0.0, "cost": 0.0})
        k["slices"] += 1
        k["spans"] += len(row["spans"])
        k["minutes"] += sum(s["minutes"] or 0.0 for s in row["spans"])
        k["cost"] += row["main"]["cost"] + sum(s["usage"]["cost"] for s in row["spans"])
    means = {
        "by_route": {r: {"spans": v["spans"], "min_per_span": round(v["minutes"] / v["spans"], 1),
                         "usd_per_span": round(v["cost"] / v["spans"], 2), "unpriced_requests": v["unpriced"]}
                     for r, v in sorted(routes.items(), key=lambda kv: (METER_ROUTES.index(kv[0]) if kv[0] in METER_ROUTES else 99, kv[0]))},
        "by_kind": {k: {"slices": v["slices"], "spans_per_slice": round(v["spans"] / v["slices"], 1),
                        "span_min_per_slice": round(v["minutes"] / v["slices"], 1), "usd_per_slice": round(v["cost"] / v["slices"], 2)}
                    for k, v in sorted(kinds.items())},
    }
    return {"slices": by_slice, "unattributed": unattributed, "phases": phases, "means": means}


def _meter_floor_note(res: dict):
    """The one `note=` line saying which requests never logged a final usage (None when none lack it)."""
    sp = [0, 0]
    for s in res["spans"]:
        sp[0] += s["usage"]["no_final"]
        sp[1] += s["usage"]["requests"]
    mn = [sum(v["no_final"] for v in res["main"].values()), sum(v["requests"] for v in res["main"].values())]
    if not sp[0] and not mn[0]:
        return None
    pct = f" ({100 * sp[0] / sp[1]:.0f}%)" if sp[1] else ""
    return (f"output_floor spans={sp[0]}/{sp[1]}{pct} main={mn[0]}/{mn[1]} — these requests never logged a final "
            "usage: their output and $ are floors (≥); context and cache are exact; the main thread's share is an upper bound")


def _meter_floor_json(res: dict) -> dict:
    sp_n = sum(s["usage"]["requests"] for s in res["spans"])
    sp_f = sum(s["usage"]["no_final"] for s in res["spans"])
    mn_n = sum(v["requests"] for v in res["main"].values())
    mn_f = sum(v["no_final"] for v in res["main"].values())
    return {"spans": {"requests": sp_n, "no_final": sp_f, "floor": sp_f > 0},
            "main": {"requests": mn_n, "no_final": mn_f, "floor": mn_f > 0},
            "note": _meter_floor_note(res)}


def _meter_print(res: dict, rep: dict, dirs: list) -> None:
    def hhmm(t):
        return datetime.fromtimestamp(t).astimezone().strftime("%Y-%m-%d %H:%M") if t else "-"
    print(f"transcripts={','.join(str(d) for d in dirs)}")
    print(f"sessions_read={len(res['sessions'])} of {res['found']}  spans={len(res['spans'])}")
    for s in res["sessions"]:
        m = s["main"]
        print(f"  session {s['session'][:8]} {hhmm(s['first'])} -> {hhmm(s['last'])}  main requests={m['requests']} "
              f"context={_meter_tok(_meter_ctx(m))} output={_meter_out(m)} ${_meter_usd(m)} limits={m['limit_hits']}  spans={s['spans']}")
    for pid, ph in rep["phases"].items():
        total = _meter_add(_meter_add(_meter_new(), ph["main"]), ph["span_total"])
        if not total["requests"] and not total["limit_hits"]:
            continue  # a phase none of the sessions read worked on
        rows = [["group", "requests", "context", "cache_read", "cache_write", "output", "$", "share"]]

        def line(label, agg):
            share = f"{100 * agg['cost'] / total['cost']:.0f}%" if total["cost"] else "-"
            if share != "-" and total["no_final"] and agg is not total:
                # the missing output sits in the spans: their share is a floor, the main thread's an upper bound
                share = ("≥" if agg["no_final"] else "≤" if agg is ph["main"] else "") + share
            return [label, str(agg["requests"]), _meter_tok(_meter_ctx(agg)), _meter_tok(agg["cache_read"]),
                    _meter_tok(agg["cache_write_5m"] + agg["cache_write_1h"]), _meter_out(agg), _meter_usd(agg), share]
        rows.append(line("main thread", ph["main"]))
        rows.append(line("spans", ph["span_total"]))
        for agent, agg in sorted(ph["by_agent"].items(), key=lambda kv: -kv[1]["cost"]):
            rows.append(line(f"  {agent}", agg))
        rows.append(line("total", total))
        print()
        print(f"[{pid}: main thread beside spans]")
        print("\n".join(_meter_columns(rows)))
    for sid, row in rep["slices"].items():
        if not row["spans"] and not row["main"]["requests"]:
            continue
        b = res["windows"].bounds.get(sid)
        window = f"  window {hhmm(b[0])} -> {hhmm(b[1]) if b[1] else 'open'}" if b else ""
        rows = [_METER_HEAD, _meter_row("main", None, row["main"])]
        groups: dict = {}
        for s in row["spans"]:
            label = s["agent"] + ("/judge" if s["route"] == "judge" else "")
            groups.setdefault(label, []).append(s)
        for label, spans in groups.items():
            agg = _meter_new()
            for s in spans:
                _meter_add(agg, s["usage"])
            outcomes: dict = {}
            for s in spans:
                outcomes[s["outcome"]] = outcomes.get(s["outcome"], 0) + 1
            verdicts = " ".join(f"{k}={v}" for k, v in sorted(outcomes.items()))
            resumes = sum(s["resumes"] for s in spans)
            if resumes:
                verdicts += f" resumes={resumes}"
            resets = [s["reset"] for s in spans if s["outcome"] == "limit" and s["reset"]]
            if resets:
                verdicts += f" (resets {resets[-1]})"
            rows.append(_meter_row(label, len(spans), agg, sum(s["minutes"] or 0.0 for s in spans), verdicts))
        print()
        print(f"[{sid}] {res['kinds'].get(sid) or ''}{window}")
        print("\n".join(_meter_columns(rows)))
    if rep["unattributed"]:
        print()
        print(f"[unattributed spans] {len(rep['unattributed'])}: " + ", ".join(f"{s['agent']} {s['id'][:8]}" for s in rep["unattributed"]))
    if res["outside"]:
        print()
        print("[main thread outside the selected windows, in the sessions read]")
        rows = [_METER_HEAD] + [_meter_row(k, None, v) for k, v in res["outside"].items()]
        print("\n".join(_meter_columns(rows)))
    means = rep["means"]
    if means["by_route"] or means["by_kind"]:
        print()
        print("[means] (metered; a DECOMP estimates time from these)")
        rows = [["route", "spans", "min/span", "$/span"]] + [
            [r, str(v["spans"]), f"{v['min_per_span']:.1f}", f"{v['usd_per_span']:.2f}" + ("+?" if v["unpriced_requests"] else "")]
            for r, v in means["by_route"].items()]
        print("\n".join(_meter_columns(rows)))
        rows = [["kind", "slices", "spans/slice", "span-min/slice", "$/slice"]] + [
            [k, str(v["slices"]), f"{v['spans_per_slice']:.1f}", f"{v['span_min_per_slice']:.1f}", f"{v['usd_per_slice']:.2f}"]
            for k, v in means["by_kind"].items()]
        print("\n".join(_meter_columns(rows)))
    print()
    floor = _meter_floor_note(res)
    if floor:
        print(f"note={floor}")
    for note in _METER_NOTES:
        print(f"note={note}")


_METER_NOTES = (
    "context = input + cache read + cache write per request (volume processed, not window size); "
    "one request per message id, its largest output kept; <synthetic> API errors are not requests",
    f"$ = list price per model (PRICES: {METER_PRICES_SOURCE}); ? = a model PRICES does not list, never guessed",
    "compaction summaries are not in the transcript and are not counted: a main thread that compacted cost "
    "somewhat more than shown",
    "min = a span's first to last entry, wall clock (a limit wait included); limits = usage-limit hits; "
    "running = a span whose .meta.json lacks finished: true",
)


def cmd_meter(args: argparse.Namespace) -> None:
    """What a phase really cost: the main thread beside its subagent spans, metered from Claude Code's
    transcripts (deduplicated, attributed to slices, priced at list price), then each slice's verdict read
    from its result.md or slice.json. Read-only; no transcripts found is one line, never a failure."""
    events = all_events()
    if args.phase is not None and not ((ACTIVE / args.phase).is_dir() or args.phase in archived_phase_ids()):
        raise SystemExit(f"meter: no such phase: {args.phase}")
    if args.slice is not None and not (ACTIVE / args.slice.split(".", 1)[0] / "slices" / args.slice).is_dir() \
            and not _slice_verdicts(slice_id=args.slice):
        raise SystemExit(f"meter: no such slice: {args.slice}")
    verdicts = _slice_verdicts(args.phase, args.slice)

    # --- metered, from the transcripts ---
    dirs, where = _meter_project_dirs(args.transcripts)
    dirs = [d for d in dirs if d.is_dir()]
    windows = _MeterWindows(events)
    known = _meter_known_slices(events)
    if args.slice is not None:
        slices = [args.slice]
    else:
        slices = [s for s in sorted(known, key=_meter_slice_order(windows)) if args.phase is None or s.split(".", 1)[0] == args.phase]
    selected_set = set(slices)
    lo = hi = None
    if args.phase is not None or args.slice is not None:
        bounds = [windows.bounds[s] for s in slices if s in windows.bounds]
        lo = min((b[0] for b in bounds if b[0] is not None), default=None)
        hi = None if any(b[1] is None for b in bounds) else max((b[1] for b in bounds), default=None)
        if not bounds:
            lo = hi = float("inf")  # never worked on: no session can overlap
    metered = None
    if dirs:
        everything = args.phase is None and args.slice is None
        res = _meter_collect(dirs, known, windows, lambda s: everything or s in selected_set or s == "unattributed", lo, hi)
        if args.phase is None and args.slice is None:
            slices = sorted(set(slices) | set(res["main"]) | {s["slice"] for s in res["spans"] if s["slice"] != "unattributed"},
                            key=_meter_slice_order(windows))
        rep = _meter_report(res, slices)
        metered = (res, rep)
    table = _verdict_table(verdicts)
    if args.json:
        body = {}
        if metered:
            res, rep = metered
            body["metered"] = {
                "transcripts": [str(d) for d in dirs], "sessions_found": res["found"],
                "sessions": [{k: v for k, v in s.items()} for s in res["sessions"]],
                "slices": {sid: {"main": _meter_flagged(row["main"]),
                                 "spans": [{**s, "usage": _meter_flagged(s["usage"])} for s in row["spans"]]}
                           for sid, row in rep["slices"].items()},
                "unattributed": [{**s, "usage": _meter_flagged(s["usage"])} for s in rep["unattributed"]],
                "phases": {pid: {"main": _meter_flagged(ph["main"]), "span_total": _meter_flagged(ph["span_total"]),
                                 "by_agent": {a: _meter_flagged(g) for a, g in ph["by_agent"].items()}}
                           for pid, ph in rep["phases"].items()},
                "outside": {k: _meter_flagged(v) for k, v in res["outside"].items()},
                "output_floor": _meter_floor_json(res),
                "means": rep["means"], "prices_source": METER_PRICES_SOURCE, "notes": list(_METER_NOTES)}
        else:
            body["metered"] = None
            body["transcripts"] = f"none found under {where}"
        body["verdicts"] = {"by_kind": table, "slices": {sid: {"kind": k, "verdict": v, "source": src}
                                                         for sid, (k, v, src) in sorted(verdicts.items())}}
        print(json.dumps(body, ensure_ascii=False, indent=2))
        return
    if metered:
        _meter_print(metered[0], metered[1], dirs)
    else:
        print(f"transcripts=none found under {where} (pass --transcripts <projects/slug dir>); verdicts only")
    print()
    print("[verdicts] (each slice's result.md status: line, else its slice.json status)")
    if args.slice is not None:
        for sid, (kind, verdict, source) in sorted(verdicts.items()):
            print(f"slice={sid} kind={kind} verdict={verdict} source={source}")
        return
    print(f"slices={len(verdicts)}")
    if table:
        cols = ["n", *_VERDICTS, "other"]
        rows = [["kind", *("needs_op" if c == "needs_operator" else c for c in cols)]]
        rows += [[kind, *(str(row[c]) for c in cols)] for kind, row in table.items()]
        print("\n".join(_meter_columns(rows)))


def _phase_created_records() -> list:
    """`[{id, created_at}]` of every active and archived phase: what `id_sort_key` needs to order minted ids
    (an archived phase is read from its `phase.json`); an unreadable file is skipped."""
    out = []
    for root in (ACTIVE, ARCHIVED):
        for pj in (root.glob("*/phase.json") if root.is_dir() else []):
            try:
                data = read_json(pj)
            except (OSError, ValueError):
                continue
            if isinstance(data, dict) and isinstance(data.get("id"), str):
                out.append({"id": data["id"], "created_at": data.get("created_at")})
    return out


def _meter_slice_order(windows: "_MeterWindows"):
    """A sort key for slice ids: the phase by `id_sort_key` (numbers first, minted ids after by creation; a
    slice of no known phase last), then the order they were worked (window end, an open window last), then
    never-worked slices by name."""
    created = {p["id"]: p["created_at"] for p in _phase_created_records()}

    def key(sid: str) -> tuple:
        pid = sid.split(".", 1)[0] if "." in sid else ""
        b = windows.bounds.get(sid)
        when = (0, b[1]) if b and b[1] is not None else (1, b[0] or 0.0) if b else (2, 0.0)
        return (id_sort_key(pid, created.get(pid)) if PHASE_ID_RE.fullmatch(pid) else (3, "", ""), when, sid)
    return key


# The hook follows the session (P35): `$CLAUDE_PROJECT_DIR` stays at the main checkout after EnterWorktree, but
# the hook's stdin `cwd` follows the session into the worktree. So the hook first walks up from that `cwd` to the
# workspace that owns it, by the engine's state finder (`_walk_to_state`), and, when that is not this adapter's
# workspace, re-runs that workspace's own adapter (or this one pointed at it, when this one's engine is not pinned
# to its own workspace) with the same stdin and relays its output. The env var is the recursion guard; every
# failure falls back to answering here.
HOOK_REDIRECT_ENV = "AGENTIC_HOOK_REDIRECTED"
HOOK_REDIRECT_TIMEOUT = 12  # the hook's own timeout is 15 s


def _hook_owning_adapter(cwd: str):
    """(adapter, run_dir, state) for the workspace that owns `cwd` (itself included), found by the state finder's
    walk: its own installed adapter, else this one when its engine is not pinned to its own workspace -- or None."""
    start = Path(cwd).resolve()
    if not start.is_dir():
        return None
    found = _walk_to_state(start)
    if found is None:
        return None
    state, run_dir = found
    adapter = state / ADAPTER_REL
    if not adapter.is_file():
        if ENGINE.parent.parent == ROOT:  # an installed engine reads only its own workspace: it cannot answer there
            return None
        adapter = ADAPTER
    return adapter, run_dir, state


def _hook_stdin_or_redirect(subcommand: str):
    """Read the hook's stdin once. Return its text for this adapter to handle, or None when the adapter of the
    workspace that owns the hook's `cwd` is another copy and already answered (its stdout/stderr relayed
    unchanged). Never raises: a missing or bad `cwd`, no adapter, this workspace, the guard set, a timeout, an
    error or a non-zero exit all return the text, and the caller carries on as before."""
    try:
        raw = sys.stdin.read()
    except Exception:  # noqa: BLE001 - the hook never fails
        return ""
    try:
        if os.environ.get(HOOK_REDIRECT_ENV):
            return raw
        hook = json.loads(raw or "null")
        cwd = hook.get("cwd") if isinstance(hook, dict) else None
        if not isinstance(cwd, str) or not cwd.strip():
            return raw
        found = _hook_owning_adapter(cwd)
        if found is None or found[2].resolve() == ROOT.resolve():
            return raw
        adapter, run_dir, state = found
        proc = subprocess.run([sys.executable, str(adapter), subcommand], input=raw, capture_output=True, text=True,
                              cwd=str(run_dir), env={**os.environ, HOOK_REDIRECT_ENV: "1", "WORKFLOW_ROOT": str(state)},
                              timeout=HOOK_REDIRECT_TIMEOUT)
        if proc.returncode != 0:
            return raw
        sys.stdout.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        sys.stdout.flush()
        sys.stderr.flush()
        return None
    except Exception:  # noqa: BLE001 - fail open: this adapter answers instead
        return raw


def _card_session_dir(transcript_path=None):
    """The session folder whose `subagents/` the card reads: the hook's `transcript_path` minus `.jsonl`,
    or, on demand, the newest session found by the meter's discovery. None when there is none."""
    if isinstance(transcript_path, str) and transcript_path.strip():
        path = Path(transcript_path).expanduser()
        return path.with_suffix("") if path.suffix == ".jsonl" else None
    dirs, _where = _meter_project_dirs(None)
    newest, newest_t = None, None
    for d in dirs:
        for f in d.glob("*.jsonl"):
            try:
                t = f.stat().st_mtime
            except OSError:
                continue
            if newest_t is None or t > newest_t:
                newest, newest_t = f, t
    return newest.with_suffix("") if newest is not None else None


def _card_running_spans(session_dir):
    """['agentType: description', ...] for the session's spans whose `.meta.json` lacks `finished: true`,
    oldest first -- from those small files only, never a transcript read (that is `meter`'s).
    None when no session folder was found."""
    if session_dir is None:
        return None
    metas = []
    for meta in (Path(session_dir) / "subagents").glob("*.meta.json"):
        try:
            data = json.loads(meta.read_text(encoding="utf-8"))
            t = meta.stat().st_mtime
        except (OSError, ValueError):
            continue
        if isinstance(data, dict) and data.get("finished") is not True:
            metas.append((t, f"{data.get('agentType') or '?'}: {data.get('description') or '-'}"))
    return [name for _t, name in sorted(metas)]


def cmd_compact_resume(args: argparse.Namespace) -> None:
    """SessionStart hook (source `compact`): print the engine's resume card with the session's running spans; on
    any error, the plain pointer. Exit 0."""
    raw = _hook_stdin_or_redirect("compact-resume")
    if raw is None:  # the adapter of the workspace that owns the session's cwd answered
        return
    print("compaction=done source=compact")
    try:
        try:
            hook = json.loads(raw or "null")
        except ValueError:
            hook = None
        transcript = hook.get("transcript_path") if isinstance(hook, dict) else None
        try:
            spans = _card_running_spans(_card_session_dir(transcript if isinstance(transcript, str) and transcript.strip() else None))
        except Exception:  # noqa: BLE001 - spans are best-effort; the rest of the card still prints
            spans = None
        print(resume_card(spans, read_spans=True))
        return
    except BaseException:  # noqa: BLE001 - SystemExit included: fall back to the plain pointer
        pass
    try:
        cmd_next(argparse.Namespace(card=False))
    except BaseException as exc:  # noqa: BLE001 - the hook must never fail
        print(f"pointer unavailable: {_one_line(str(exc)) or type(exc).__name__}")


def build_parser() -> argparse.ArgumentParser:
    """The adapter's four commands."""
    parser = argparse.ArgumentParser(prog="adapter.py", description="The Claude Code adapter of the workflow engine.")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("sync-agents", help="Write the route table's rows (engine defaults overlaid by the repo-root executors.toml) into the model/effort frontmatter of the six managed agent files: slice-executor (the mid row; high and research run it with their model and effort passed per dispatch), design-drafter (its own design row), design-critic (the critic row; the judge row runs it with its model passed per call), pr-reader (the reader row), code-reader (the code row) and Explore (the explore row)")
    p.add_argument("--check", action="store_true", help="Report drift without writing; exit 1 if out of sync")
    p.set_defaults(func=sync_agents)

    p = sub.add_parser("route", help="Print the executor routing decision, one key=value per line, writing nothing: bare, the resolved route table (high, research, design, critic, judge, reader, code, mid, explore), the agent files' sync state and an override= line per row executors.toml sets (its value against the default); with a slice id, the route, subagent_type (slice-executor for every slice row), model, effort and attribution its dispatch uses (kind first, then risk, then attempt); --drafter / --critic / --judge / --reader / --code / --explore, a non-slice agent's dispatch; plus fallback=, skip= and warning= lines for the environment. The critic and the judge may share the design row's model (v75)")
    p.add_argument("slice", nargs="?", help="the slice to route; omit for the table")
    p.add_argument("--retry", action="store_true", help="the slice's second attempt (an escalation, a failed or empty return, a fix of mid-row work): always the high row")
    p.add_argument("--drafter", action="store_true", help="the design-drafter's dispatch (its own design row, [claude.design]; not a slice route)")
    p.add_argument("--phase", help="with --drafter: the phase whose intent.md `## Design Style` may name the drafter's model (`Drafter: fable`); its effort stays the design row's, and an absent line is the design row. Behind a loopback proxy (no Fable) a Fable drafter falls back to opus")
    p.add_argument("--critic", action="store_true", help="the design-critic's dispatch in critic mode (the critic row, [claude.critic]); it may share the drafter's model")
    p.add_argument("--judge", action="store_true", help="the design-critic's dispatch in judge mode (the judge row, [claude.judge], alias only); never refused for sharing the drafter's model; skip=yes only when the judge row is overridden to Fable behind a loopback proxy that serves no Fable")
    p.add_argument("--reader", action="store_true", help="the pr-reader's dispatch (the reader row, [claude.reader]): the fresh-eyes PR reader, which reads the product diff, the body and details files, the team-rule files and the pr check output only, and writes topics/pr-read.md")
    p.add_argument("--code", action="store_true", help="the code-reader's dispatch (the code row, [claude.code]): the blind code reader, which reads one code change cold (the diff over the product pathspec and the files at head, never the workspace's records), reproduces each suspicion and writes topics/code-read.md")
    p.add_argument("--explore", action="store_true", help="the read-only Explore lookup agent's dispatch (the explore row)")
    p.set_defaults(func=cmd_executor_route)

    p = sub.add_parser("meter", help="Read-only: what a phase really cost -- the main thread beside its subagent spans per slice and per phase (requests, context, output, list-price $, minutes, limit hits, verdicts) metered from Claude Code's transcripts, the means a DECOMP estimates time from, then each slice's verdict from its result.md (status:) or slice.json; no transcripts found prints one line and the verdicts")
    p.add_argument("--phase", help="one phase (a brief id: 46, P46 or 46-k2; P12; 7kq2 or P-7kq2): its slices, read from the sessions overlapping its slice windows")
    p.add_argument("--slice", help="one slice: its metered rows and its verdict")
    p.add_argument("--json", action="store_true", help="print everything as one JSON object")
    p.add_argument("--transcripts", action="append", metavar="DIR", help="read this projects/<slug> directory instead of discovering the session root's (repeatable)")
    p.set_defaults(func=cmd_meter)

    p = sub.add_parser("compact-resume", help="The SessionStart hook (matcher compact): after a compaction, print compaction=done source=compact and the engine's resume card with the running spans of the hook's transcript_path session, falling back to the plain pointer on any error; never fails, always exits 0")
    p.set_defaults(func=cmd_compact_resume)
    return parser


def main(argv=None) -> int:
    tokens = sys.argv[1:] if argv is None else list(argv)
    return workflow.run(build_parser().parse_args(tokens), tokens)


if __name__ == "__main__":
    raise SystemExit(main())
