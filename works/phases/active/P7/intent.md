# Intent — P7

- Captured at: 2026-07-08T16:35:47+09:00
- Origin: operator

## Original Input (verbatim)

> we have /explain. the personal knowledge store. and I kinda like it and want to make it like plugin style feature. so that other users can use the feature. you make up both repo's phases. and give me execution order. note that I want to develop the knowledge feature first(improve then current, and webui feature add(github page as is). graphic, search engine, obsidien like knowledge map.. etc.. gonna use claude design for designing the webui.

Follow-up (same session):

> And I think knowledge will be eventually SaaS like feature later. just note that and proceed. it's not today's job.

## Confirmed Intent (refined + clarified)

Last phase of the knowledge-feature roadmap, and the only one in this bootstrap repo. Once the knowledge repo ships its Claude Code plugin (knowledge P7, review passed), remove the explain feature from the bootstrap distribution: the embedded skill copies (`.claude/skills/explain`, `.agents/skills/explain`), the `--with-explain` installer path, and the KB API wiring. Point users at the knowledge repo's plugin instead. Rebuild the installer (`python3 installer/build.py`) as part of the work. This likely resolves deferred D1 (hardcoded KB path/ports) by deletion.

**GATE: do not start this phase until the knowledge repo's P7 (Claude Code plugin) review passes.** Operator's explicit instruction: "leave current state as is till knowledge done."

## Clarifications Resolved

- Q: What does "plugin style" mean for how other users install the feature? — A: A real Claude Code plugin (`.claude-plugin/` + marketplace manifest) installable via `/plugin` — not an extension of this repo's installer.
- Q: Where should the plugin live? — A (verbatim): "well, after knowledge claude plugin done, the explain related stuff will discarded from this bootstrap repo. so, knowledge. and leave current state as is till knowledge done." → Plugin lives in the knowledge repo; this repo's explain machinery is discarded afterward.

## Notes

- Roadmap execution order: knowledge P4 (core improvements) → P5 (web UI redesign & search) → P6 (knowledge graph) → P7 (Claude Code plugin), then this phase.
- Upstream-repo rule applies: the removal touches embedded machinery, so `python3 installer/build.py` must run and the rebuilt `bootstrap_agentic_workspace.sh` committed in the same commit (`--check` must pass).
- Operator direction: knowledge will eventually become a SaaS-like feature. Not today's job; context only.
