#!/usr/bin/env python3
"""Assemble the single-file distributable bootstrap_agentic_workspace.sh from installer/.

The distributable is a build product: a self-contained POSIX-sh file at the repo
root that consumers `curl … | sh` (and /update-workspace clones + runs). It is
committed. This script reassembles it deterministically from source so editing a
shipped skill/agent/contract source under payload/ + rebuilding is the whole
workflow — no heredoc mirroring.

Source of truth:
  * payload/ (the shipped sources, embedded verbatim, killing the double-maintenance).
    Each sits at its EMIT path with the first component undotted, and the contract is
    payload/contract.md, so no source lives at a path Claude Code or GitHub would load
    in this repo (it is driven by a nested install, whose copies own .claude/):
      payload/scripts/workflow.py, payload/claude/skills/*/** (each skill's whole directory,
      plus the SHARED_SKILL_FILES copies), the payload/claude
      subagents, payload/claude/settings.json, payload/executors.toml,
      payload/works/templates/*, payload/github/workflows/workspace-ci.yml,
      payload/gitattributes, and the payload/contract.md contract body (header
      stripped, embedded once).
  * installer/payloads/  (fresh-install-only seeds, no payload/ counterpart):
      doc_bodies/<doc>.md, sentinel-templated (__PROJECT_NAME__ / __PROJECT_SUMMARY__
      substituted by main.py at install time).

Determinism: sorted directory walks, sorted dict keys, repr() literals (no
timestamps or randomness) => same inputs produce a byte-identical artifact.

Release (this repo only; adopters only ever see the stamped integer): a branch never
touches WORKSPACE_VERSION or CHANGELOG's numbered sections. Its release notes go in a
fragment, changelog.d/<slug>.md, and `--release` stamps the next version when the branch
lands on main (see changelog.d/README.md and CLAUDE.md).

Usage:
  python3 installer/build.py           # write ../bootstrap_agentic_workspace.sh
  python3 installer/build.py --check   # exit non-zero if the committed artifact drifts
  python3 installer/build.py --release # on main: fold changelog.d/ into v<N+1>, bump, rebuild
"""
from __future__ import annotations

import datetime
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent          # installer/
REPO = HERE.parent                              # repo root
ARTIFACT = REPO / "bootstrap_agentic_workspace.sh"
SRC = REPO / "payload"                          # the shipped sources (never live paths in this repo)

HEREDOC_DELIM = "INSTALLER_PY"                  # distinctive: no payload/body line may equal it
PAYLOAD_MARKER = "#@@GENERATED_PAYLOADS@@"      # in main.py — replaced by generated constants
BODY_MARKER = "#@@PYTHON_BODY@@\n"              # in wrapper.sh — replaced by the python body
EXPECTED_SKILL_COUNT = 18

# Release stamping (--release). The smoke suite reads the same two shapes (WORKSPACE_VERSION in
# installer/main.py, the numbered `## v<N> ` headings in CHANGELOG.md), so they are named once here.
CHANGELOG = REPO / "CHANGELOG.md"
MAIN_PY = HERE / "main.py"
FRAGMENT_DIR = REPO / "changelog.d"             # one fragment per branch; README.md is the format, never a fragment
FRAGMENT_README = "README.md"
RELEASE_BRANCH = "main"
VERSION_LINE_RE = re.compile(r"^WORKSPACE_VERSION = (\d+)$", re.M)
SECTION_RE = re.compile(r"^## v(\d+) ", re.M)
SUMMARY_RE = re.compile(r"^# (\S.*?)\s*$")
MIGRATION_MARK = "**Migration notes.**"

# Shipped files embedded verbatim, keyed by EMIT path (where the installer writes them). The
# source lives under payload/ at src_rel(emit): the first path component undotted, so no source
# sits at a path Claude Code or GitHub would load (.claude/, .github/, CLAUDE.md).
FIXED_LIVE_FILES = [
    "scripts/workflow.py",
    ".claude/settings.json",
    ".claude/agents/slice-executor.md",
    ".claude/agents/design-drafter.md",
    ".claude/agents/design-critic.md",
    ".claude/agents/explain-critic.md",
    ".claude/agents/Explore.md",
    "executors.toml",
    "works/templates/deferred_brief.md",
    "works/templates/intent.md",
    "works/templates/phase.md",
    # Repo-level policy files. Embedded like any other shipped file; main.py emits them
    # through their own write policy (CI seed-once, .gitattributes line-merge) so an
    # adopting repo's own CI / attributes are never clobbered.
    ".github/workflows/workspace-ci.yml",
    ".gitattributes",
]

# Skill reference files the do-* twins share. Each one has ONE source (the value, under
# payload/claude/skills/do-whole-phase/reference/); the build emits a byte-identical copy at the
# key, so every installed skill directory is self-contained. A key must not also exist as a
# source file under payload/ (that would be a second copy to keep in step).
SHARED_SKILL_FILES = {
    ".claude/skills/do-next-slice/reference/dispatch.md": ".claude/skills/do-whole-phase/reference/dispatch.md",
    ".claude/skills/do-next-slice/reference/explain-chapter.md": ".claude/skills/do-whole-phase/reference/explain-chapter.md",
    ".claude/skills/do-next-slice/reference/explain-decomposition.md": ".claude/skills/do-whole-phase/reference/explain-decomposition.md",
    ".claude/skills/do-next-slice/reference/explain-review.md": ".claude/skills/do-whole-phase/reference/explain-review.md",
}

CLAUDE_HDR = "# CLAUDE.md\n\n"


def die(msg: str) -> "None":
    print(f"build error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def src_rel(emit: str) -> str:
    """payload/-relative source of an emit path: .claude/x -> claude/x, .gitattributes -> gitattributes."""
    return emit[1:] if emit.startswith(".") else emit


def read(rel: str, base: Path = SRC) -> str:
    p = base / rel
    if not p.is_file():
        die(f"missing source file: {p}")
    return p.read_text(encoding="utf-8")


def collect_live_payloads() -> "dict":
    """emit-path -> content for every shipped file (deterministic ordering), verbatim."""
    payloads: dict = {}
    for rel in FIXED_LIVE_FILES:
        payloads[rel] = read(src_rel(rel))
    # Skills are discovered from disk (sorted) so adding/removing a skill needs no code change.
    # A skill ships as its whole directory: SKILL.md (the core) plus every other file under it
    # (its reference/*.md), then the shared reference copies fan out (SHARED_SKILL_FILES).
    for skill in sorted((SRC / "claude/skills").glob("*/SKILL.md")):
        for f in sorted(p for p in skill.parent.rglob("*") if p.is_file()):
            if any(part.startswith(".") or part == "__pycache__" for part in f.relative_to(skill.parent).parts):
                continue  # editor/OS litter (.DS_Store, swap files) never ships
            payloads["." + f.relative_to(SRC).as_posix()] = f.read_text(encoding="utf-8")
    for dst, src in sorted(SHARED_SKILL_FILES.items()):
        if src not in payloads:
            die(f"SHARED_SKILL_FILES source missing from payload/: {src}")
        if dst in payloads:
            die(f"SHARED_SKILL_FILES target also exists as a source under payload/: {dst} (keep one source: {src})")
        payloads[dst] = payloads[src]
    claude_skills = {
        Path(k).parts[2]
        for k in payloads
        if k.startswith(".claude/skills/") and k.endswith("/SKILL.md")
    }
    # Release invariant: a truncated or half-collected payload is a build error.
    if len(claude_skills) != EXPECTED_SKILL_COUNT:
        die(f"expected {EXPECTED_SKILL_COUNT} Claude skills; found {len(claude_skills)}")
    return payloads


def collect_contract_body() -> str:
    claude = read("contract.md")
    if not claude.startswith(CLAUDE_HDR):
        die("payload/contract.md header changed — update CLAUDE_HDR in build.py")
    return claude[len(CLAUDE_HDR):]


def collect_seed_payloads() -> "dict":
    doc_bodies: dict = {}
    for md in sorted((HERE / "payloads/doc_bodies").glob("*.md")):
        doc_bodies[md.stem] = md.read_text(encoding="utf-8")
    if not doc_bodies:
        die("no doc bodies under installer/payloads/doc_bodies/")
    return doc_bodies


def _dict_literal(name: str, d: "dict") -> str:
    out = [f"{name} = {{"]
    for k in sorted(d):
        out.append(f"    {k!r}: {d[k]!r},")
    out.append("}")
    return "\n".join(out)


def generate_constants(payloads, contract_body, doc_bodies) -> str:
    return "\n\n".join([
        _dict_literal("PAYLOADS", payloads),
        f"CONTRACT_BODY = {contract_body!r}",
        _dict_literal("DOC_BODIES", doc_bodies),
    ])


def assemble() -> str:
    payloads = collect_live_payloads()
    contract_body = collect_contract_body()
    doc_bodies = collect_seed_payloads()

    main_py = read("main.py", base=HERE)
    if PAYLOAD_MARKER not in main_py:
        die(f"{PAYLOAD_MARKER} marker missing from installer/main.py")
    constants = generate_constants(payloads, contract_body, doc_bodies)
    body = main_py.replace(PAYLOAD_MARKER, constants)

    # Safety: the python body must compile, and no line may collide with the heredoc delimiter.
    try:
        compile(body, "<installer-body>", "exec")
    except SyntaxError as e:
        die(f"assembled python body does not compile: {e}")
    for i, ln in enumerate(body.split("\n"), 1):
        if ln == HEREDOC_DELIM:
            die(f"body line {i} collides with heredoc delimiter {HEREDOC_DELIM!r}")

    wrapper = read("wrapper.sh", base=HERE)
    if BODY_MARKER not in wrapper:
        die("#@@PYTHON_BODY@@ marker missing from installer/wrapper.sh")
    if not body.endswith("\n"):
        body += "\n"
    artifact = wrapper.replace(BODY_MARKER, body)

    # Safety: the shell wrapper must be syntactically valid (best-effort; needs sh).
    _sh_syntax_check(artifact)
    return artifact


def _sh_syntax_check(artifact: str) -> None:
    try:
        with tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False, encoding="utf-8") as f:
            f.write(artifact)
            tmp = f.name
        r = subprocess.run(["sh", "-n", tmp], capture_output=True, text=True)
        Path(tmp).unlink(missing_ok=True)
        if r.returncode != 0:
            die(f"assembled artifact fails 'sh -n':\n{r.stderr}")
    except FileNotFoundError:
        print("build warning: 'sh' not found; skipped shell syntax check", file=sys.stderr)


def write_artifact(artifact: str) -> None:
    ARTIFACT.write_text(artifact, encoding="utf-8")
    ARTIFACT.chmod(0o755)
    print(f"wrote {ARTIFACT.name} ({len(artifact)} bytes) from installer/ source")


def refuse(msg: str) -> "None":
    print(f"release refused: {msg}", file=sys.stderr)
    raise SystemExit(1)


def pending_fragments() -> "list":
    """The release fragments waiting to be stamped: changelog.d/*.md directly in the directory,
    by file name, except README.md (the format note, which is never a fragment)."""
    if not FRAGMENT_DIR.is_dir():
        return []
    return sorted((p for p in FRAGMENT_DIR.glob("*.md") if p.is_file() and p.name != FRAGMENT_README),
                  key=lambda p: p.name)


def read_fragment(path: Path) -> "tuple":
    """(summary, body) of one fragment: line 1 is `# <summary>`, the rest is the section's bullets
    and must carry a `**Migration notes.**` line. Anything else is a refusal naming the file."""
    name = f"changelog.d/{path.name}"
    lines = path.read_text(encoding="utf-8").split("\n")
    m = SUMMARY_RE.match(lines[0])
    if not m:
        refuse(f"{name}: line 1 must be '# <one-line summary>' (the release commit's subject tail)")
    body = "\n".join(lines[1:]).strip("\n").rstrip()
    if MIGRATION_MARK not in body:
        refuse(f"{name}: no '{MIGRATION_MARK}' line (say 'None.' when a sync needs no manual step)")
    if SECTION_RE.search(body):
        refuse(f"{name}: holds a numbered '## v<N>' heading; the stamp writes the heading, a fragment carries only the bullets")
    return m.group(1), body


def current_branch() -> str:
    try:
        r = subprocess.run(["git", "-C", str(REPO), "symbolic-ref", "-q", "--short", "HEAD"],
                           capture_output=True, text=True)
    except FileNotFoundError:
        refuse("git not found; --release needs it to check the branch")
    return r.stdout.strip() if r.returncode == 0 else ""


def release() -> int:
    """Stamp the next version at landing: fold every pending changelog.d fragment into one
    `## v<N+1> — <today>` section above the previous top, set WORKSPACE_VERSION = N+1, delete the
    fragments and rebuild the artifact. Every refusal happens before anything is written; a failed
    build puts the two edited files back and keeps the fragments."""
    branch = current_branch()
    if branch != RELEASE_BRANCH:
        refuse(f"HEAD is {branch or 'detached'}, not {RELEASE_BRANCH}; versions are stamped as a branch lands "
               f"(git merge --no-ff --no-commit <branch>, then --release)")
    fragments = pending_fragments()
    if not fragments:
        refuse("no pending fragment: changelog.d/ holds no *.md besides README.md")
    parsed = [read_fragment(p) for p in fragments]

    main_text = MAIN_PY.read_text(encoding="utf-8")
    changelog = CHANGELOG.read_text(encoding="utf-8")
    versions = VERSION_LINE_RE.findall(main_text)
    top = SECTION_RE.search(changelog)
    if len(versions) != 1:
        refuse(f"expected exactly one 'WORKSPACE_VERSION = <n>' line in installer/main.py; found {len(versions)}")
    if top is None:
        refuse("CHANGELOG.md has no numbered '## v<N> ' section to stamp above")
    n, top_n = int(versions[0]), int(top.group(1))
    if n != top_n:
        refuse(f"WORKSPACE_VERSION is {n} but CHANGELOG.md's top section is v{top_n}; they must agree before a stamp "
               f"(a branch must not touch either; resolve the merge first)")
    m = n + 1

    heading = f"## v{m} — {datetime.date.today().isoformat()}"
    section = heading + "\n\n" + "\n\n".join(body for _, body in parsed) + "\n\n"
    new_changelog = changelog[:top.start()] + section + changelog[top.start():]
    new_main = VERSION_LINE_RE.sub(f"WORKSPACE_VERSION = {m}", main_text, count=1)
    subject = f"build(release): workspace v{m} — " + "; ".join(summary for summary, _ in parsed)

    CHANGELOG.write_text(new_changelog, encoding="utf-8")
    MAIN_PY.write_text(new_main, encoding="utf-8")
    try:
        artifact = assemble()
    except BaseException:
        CHANGELOG.write_text(changelog, encoding="utf-8")
        MAIN_PY.write_text(main_text, encoding="utf-8")
        raise
    write_artifact(artifact)
    for p in fragments:
        p.unlink()
    print(f"released=v{m}")
    print(f"fragments_folded={len(fragments)} ({', '.join(p.name for p in fragments)})")
    print(f"commit_subject={subject}")
    print("next: git add -A CHANGELOG.md installer/main.py bootstrap_agentic_workspace.sh changelog.d "
          "&& git commit -m \"<commit_subject>\"")
    return 0


def main(argv) -> int:
    check = "--check" in argv
    if "--release" in argv:
        if check:
            die("--release writes; --check is read-only: pass one of them")
        return release()
    artifact = assemble()
    if check:
        if not ARTIFACT.exists():
            die("no committed bootstrap_agentic_workspace.sh to check against")
        if ARTIFACT.read_text(encoding="utf-8") != artifact:
            die("DRIFT: committed bootstrap_agentic_workspace.sh != installer/ source. "
                "Run: python3 installer/build.py")
        print("OK: bootstrap_agentic_workspace.sh is in sync with installer/ source")
        return 0
    write_artifact(artifact)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
