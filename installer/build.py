#!/usr/bin/env python3
"""Assemble the single-file distributable bootstrap_agentic_workspace.sh from installer/.

The distributable is a build product: a self-contained POSIX-sh file at the repo
root that consumers `curl … | sh` (and /update-workspace clones + runs). It is
committed. This script reassembles it deterministically from source so editing a
live skill/agent/contract file + rebuilding is the whole workflow — no heredoc
mirroring.

Source of truth:
  * Live repo files (embedded verbatim, killing the double-maintenance):
      scripts/workflow.py, .claude/skills/*, the .claude subagents,
      .claude/settings.json, executors.toml, works/templates/*,
      .github/workflows/workspace-ci.yml, .gitattributes, and the CLAUDE.md
      contract body (header stripped, embedded once).
  * installer/payloads/  (fresh-install-only seeds, no live counterpart):
      doc_bodies/<doc>.md, sentinel-templated (__PROJECT_NAME__ / __PROJECT_SUMMARY__
      substituted by main.py at install time).

Determinism: sorted directory walks, sorted dict keys, repr() literals (no
timestamps or randomness) => same inputs produce a byte-identical artifact.

Usage:
  python3 installer/build.py           # write ../bootstrap_agentic_workspace.sh
  python3 installer/build.py --check   # exit non-zero if the committed artifact drifts
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent          # installer/
REPO = HERE.parent                              # repo root
ARTIFACT = REPO / "bootstrap_agentic_workspace.sh"

HEREDOC_DELIM = "INSTALLER_PY"                  # distinctive: no payload/body line may equal it
PAYLOAD_MARKER = "#@@GENERATED_PAYLOADS@@"      # in main.py — replaced by generated constants
BODY_MARKER = "#@@PYTHON_BODY@@\n"              # in wrapper.sh — replaced by the python body
EXPECTED_SKILL_COUNT = 17

# Live repo files embedded verbatim (path relative to repo root == emit target path).
FIXED_LIVE_FILES = [
    "scripts/workflow.py",
    ".claude/settings.json",
    ".claude/agents/slice-executor-mid.md",
    ".claude/agents/slice-executor-high.md",
    "executors.toml",
    "works/templates/deferred_brief.md",
    "works/templates/intent.md",
    # Repo-level policy files. Embedded like any other live file; main.py emits them
    # through their own write policy (CI seed-once, .gitattributes line-merge) so an
    # adopting repo's own CI / attributes are never clobbered.
    ".github/workflows/workspace-ci.yml",
    ".gitattributes",
]

CLAUDE_HDR = "# CLAUDE.md\n\n"


def die(msg: str) -> "None":
    print(f"build error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def read(rel: str, base: Path = REPO) -> str:
    p = base / rel
    if not p.is_file():
        die(f"missing source file: {p}")
    return p.read_text(encoding="utf-8")


def collect_live_payloads() -> "dict":
    """target-path -> content for every verbatim live file (deterministic ordering)."""
    payloads: dict = {}
    for rel in FIXED_LIVE_FILES:
        payloads[rel] = read(rel)
    # Skills are discovered from disk (sorted) so adding/removing a skill needs no code change.
    for skill in sorted((REPO / ".claude/skills").glob("*/SKILL.md")):
        payloads[str(skill.relative_to(REPO))] = skill.read_text(encoding="utf-8")
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
    claude = read("CLAUDE.md")
    if not claude.startswith(CLAUDE_HDR):
        die("CLAUDE.md header changed — update CLAUDE_HDR in build.py")
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


def main(argv) -> int:
    check = "--check" in argv
    artifact = assemble()
    if check:
        if not ARTIFACT.exists():
            die("no committed bootstrap_agentic_workspace.sh to check against")
        if ARTIFACT.read_text(encoding="utf-8") != artifact:
            die("DRIFT: committed bootstrap_agentic_workspace.sh != installer/ source. "
                "Run: python3 installer/build.py")
        print("OK: bootstrap_agentic_workspace.sh is in sync with installer/ source")
        return 0
    ARTIFACT.write_text(artifact, encoding="utf-8")
    ARTIFACT.chmod(0o755)
    print(f"wrote {ARTIFACT.name} ({len(artifact)} bytes) from installer/ source")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
