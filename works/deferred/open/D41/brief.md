# Deferred: D41 Nested install wires a host's AGENTS.md and .agents/skills into Claude Code

## Context

## Why Deferred

Claude Code loads neither AGENTS.md nor .agents/skills, so in a host that keeps its agent rules there (first real host: glide-ilab, 4 AGENTS.md files, ~32 KB, plus a create-pull-request skill) executors ignore the team's conventions and PR format. Done by hand there on 2026-10-07: a private CLAUDE.local.md with '@AGENTS.md' next to each AGENTS.md, a root CLAUDE.local.md section (outside the managed block) importing the PR skill, and an unanchored 'CLAUDE.local.md' line in a personal info/exclude block. The installer should detect and wire these automatically on --nested and keep them on --update --nested, after a live check that a subdirectory CLAUDE.local.md loads on demand.

## Trigger to Promote

The next nested-installer change, or a second host that uses AGENTS.md

## Notes

