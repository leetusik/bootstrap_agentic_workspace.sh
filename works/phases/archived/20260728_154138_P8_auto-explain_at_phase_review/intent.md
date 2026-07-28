# Intent — P8

- Captured at: 2026-07-21T13:17:18+09:00
- Origin: operator

## Original Input (verbatim)

> you should create phase for both this repo and bootstrap_agentic_workspace. And give me execution order. You ask me questions if anything unclear.
>
> ---
> 1. I want to upgrade `/explain` skill to "https://gist.githubusercontent.com/geoffreylitt/a29df1b5f9865506e8952488eac3d524/raw/126e7fe9eecaafadfe1ac8bb183d135812b608f2/explain-diff-html.md" like this one.
> 2. for all review slices, want to use the skill automatically. basically phase review + docs + and the explain.
> 3. maybe using claude code plugin or whatever. I need to link the explain skill with knowledge webui since it's deployed publically. for all knowledge users.
> 4. knowledge should me properly render the explain skill generated html. and should be able to searchable.

Follow-up (same session):

> And maybe for explain skill, it could contain internet search kind of job for beyond codebase. so that it can contain comparing our implementation and best practices, and maybe suggest next steps.

## Confirmed Intent (refined + clarified)

Item 2 of the request, in this repo because the phase-review procedure is bootstrap machinery: extend the review so that a **passing phase review also produces a phase explainer** via the knowledge plugin's upgraded explain skill — **review = validate + consolidate docs + explain**. The explainer is the gist-style self-contained interactive HTML document (change mode: what the phase changed, why, with the citation-backed "Best practices & next steps" section), posted to the operator's own KB per their plugin configuration.

The step must **degrade gracefully** wherever the knowledge plugin / KB is not installed or reachable — this machinery ships to every adopting workspace, and explain becomes an external plugin once P7 retires the embedded copy.

Files this touches (the phase-review definition): `.claude/skills/review-phase/SKILL.md`, `.claude/agents/slice-executor-high.md`, the review paragraphs of `.claude/skills/do-whole-phase/SKILL.md` and `.claude/skills/do-next-slice/SKILL.md`, the Codex mirrors (`.codex/agents/slice-executor-high.toml`), and `CLAUDE.md`/`AGENTS.md` (byte-equal) if the contract's review wording changes — all embedded, so `python3 installer/build.py` must run and the rebuilt `bootstrap_agentic_workspace.sh` be committed in the same commit (`--check` must pass).

**GATE: do not start this phase until knowledge P16 (HTML pipeline) and P17 (explain skill v2 + public ingestion) reviews pass, and P7 (retire embedded /explain) is done.** The auto-explain step needs the upgraded skill and a KB that can render/search its output.

## Clarifications Resolved

- Q: Should explain v2 keep the markdown topic mode or always emit HTML? — A: Both modes, always HTML; the review auto-explain uses the change mode.
- Q: Always-on web research, or optional? — A: Operator delegated ("it's your call") → default-on with a judgment gate, cited "Best practices & next steps" section, graceful offline skip — so unattended review runs work anywhere.
- Q: Where does the existing P7 ("Retire embedded /explain") fit in the execution order? — A: **First** — before the knowledge phases and before this phase.
- Q: How far does "for all knowledge users" go? — A: Full multi-user public ingestion (knowledge P17's job; context for how adopters' review explainers reach their own KBs).

## Notes

- Cross-repo execution order: **bootstrap P7 → knowledge P16 → knowledge P17 → bootstrap P8 (this phase)**.
- Whether auto-explain fires only on a `pass` verdict (like doc consolidation) or on every review outcome is DECOMP detail; operator's framing was "phase review + docs + and the explain", i.e. alongside the pass-gated consolidation step.
- The explainer posts to whichever KB the adopting workspace's plugin is configured for (operator tenant on the public host, or a local KB) — per-adopter configuration, not hardcoded.
