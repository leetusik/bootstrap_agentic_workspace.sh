---
name: explain
description: Research a topic in the current repo/conversation and save a novice-friendly educational explainer document to the personal knowledge base (~/projects/personal/knowledge). Use ONLY when the user wants an explanation persisted as a document (explain and document, write this up, document what we just discussed) — NOT for ordinary questions that deserve a normal chat answer.
argument-hint: <topic> [here]
allowed-tools: Read, Grep, Glob, Write, Bash(git -C ~/projects/personal/knowledge:*)
---

# explain

Write an educational explainer document — in the house style below — about a topic
in the current repo or conversation, and file it in the personal knowledge base at
`~/projects/personal/knowledge`. This skill produces a **saved document**: if the
user only asked a question and did not ask for anything to be saved, answer
normally in chat and write no files.

## 1. Resolve the topic

- Topic = the skill arguments: $ARGUMENTS
- If the arguments end with the standalone word `here`, strip it and remember:
  PROJECT_COPY=yes (step 8).
- No arguments → the topic is the most recent substantive analysis in this
  conversation ("document what we just discussed").
- Neither → ask the user what to explain, then continue.

## 2. Locate the knowledge base

- Check that `~/projects/personal/knowledge/mkdocs.yml` exists.
- If it does not: STOP and tell the user the KB repo is missing at
  `~/projects/personal/knowledge` and can be restored from backup or
  re-scaffolded (its README has a "Recreating from scratch" section). Do not
  write the document anywhere else, and do not scaffold the KB unless asked.

## 3. Research (read-only)

- Ground every claim in reality: read the actual files involved (code, configs,
  compose files, scripts). Never invent paths, commands, config snippets, or
  behavior — quote them from real files.
- Reuse conclusions already established in this conversation rather than
  re-deriving them.
- Audience: novice programmer, unless the user says otherwise.

## 4. Write the document — the style contract

Header:

- `# <Title>` in plain language, e.g. "The Shared nginx Problem — Explained for
  Beginners".
- Then a blockquote note stating: this is an educational write-up of the topic
  in this project; "Written for a novice programmer — every piece of jargon is
  explained as it appears."; where the operational source of truth lives (link
  the real runbook/doc if one exists); and that "this file is a teaching
  companion, not the runbook."

Structure — choose by topic shape:

- Problem-shaped (incident, fragility, fix):
  `## 1. The current situation` → `## 2. The cause` → `## 3. The proposed fix`
  → `## Mini-glossary`
- Concept-shaped (tool, pattern, subsystem):
  `## 1. What it is` → `## 2. Why it exists in this project` →
  `## 3. How it works here` → `## 4. Trade-offs and alternatives` → `## Mini-glossary`

Devices (use each where it earns its place):

- **Bold** every piece of jargon on first use and define it inline in the same
  sentence.
- Phrase H3 headings as the reader's own question where natural
  ("But who would recreate that container?").
- Teaching analogies for abstract mechanics (image/container ≈ class/object).
- One ASCII topology or flow diagram in a fenced block when structure matters,
  with ★ marking the crucial line, explained just below it.
- A markdown table when an inventory of parts helps.
- Numbered lists for concrete step sequences; bullets for design rules, each
  justified by the failure it prevents.
- Progressive disclosure between sections ("And it works! So what's the problem?").
- Exactly one blockquote "lesson in one sentence" takeaway.
- Close with `## Mini-glossary`: `**Term** — one-line definition` per term.
- Length guide: ~150–250 lines.

## 5. Save to the knowledge base

- project = the current repo's root directory name, verbatim (e.g. `hi2vi_web`);
  if it contains path-unsafe characters, lowercase it and replace them with `-`.
- slug = short lowercase-kebab topic name (e.g. `shared-nginx-explained`);
  date = today, `YYYY-MM-DD`.
- Write `~/projects/personal/knowledge/docs/<project>/<date>-<slug>.md` with
  this frontmatter above the H1 — title always double-quoted (an unquoted colon
  breaks the whole site build); tags always a YAML list of 2–5 lowercase-kebab
  topic tags:

      ---
      title: "<Title>"
      date: <YYYY-MM-DD>
      tags:
        - <topic-tag>
      source:
        project: <project>
        repo: <absolute path to the current repo root>
      ---

## 6. Update the index

- In `~/projects/personal/knowledge/docs/index.md`, insert on a new line
  directly after the `<!-- explain:recent -->` marker:

      - <YYYY-MM-DD> · [<Title>](<project>/<date>-<slug>.md) — <project>

- If the marker is missing, insert as the first bullet under `## Recent`; if
  that heading is missing too, append a `## Recent` section (with the marker)
  at the end of the file.

## 7. Commit — knowledge-base repo only

The KB has an auto-commit convention (see its README). Run exactly these two
commands, spelled exactly this way, adding your own tool's standard
Co-Authored-By trailer as a second `-m` (in Codex that is
`Co-Authored-By: GPT-5.5 <noreply@openai.com>`):

    git -C ~/projects/personal/knowledge add -A
    git -C ~/projects/personal/knowledge commit -m "docs(<project>): add <slug>"

Never push. Never commit in any other repo.

## 8. Optional copy in the current project

Only when PROJECT_COPY=yes: also write the document — without the YAML
frontmatter — to `<repo-root>/<TOPIC>_EXPLAINED.md` (topic in SCREAMING_SNAKE,
e.g. `SHARED_NGINX_EXPLAINED.md`). Do not commit it; that repo belongs to the
user.

## 9. Report

Tell the user:

- KB file: the absolute path from step 5.
- View at: `http://localhost:8765/<project>/<date>-<slug>/` — if the viewer is
  down, offer to start it (`docker compose up -d` in
  `~/projects/personal/knowledge`).
- The project copy path, if one was made.
