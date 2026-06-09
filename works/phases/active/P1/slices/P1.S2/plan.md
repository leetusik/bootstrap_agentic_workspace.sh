# Plan

- Phase ID: P1
- Slice ID: P1.S2
- Slice: Methodology & related projects
- Created at: 2026-06-10T01:17:12+09:00

## Goal

Add the two featured sections to `README.md`: a FEATURED, first-person, opinionated
"How I work with coding agents" methodology, and a "Related / inspired by" see-also section with a
light positioning lead-in. Insert them at the anchor P1.S1 left, between "Project structure" and
"Contributing", and add their two Table-of-Contents entries.

## Scope

- **Section 7 — ⭐ How I work with coding agents** (heading exactly `## ⭐ How I work with coding agents`):
  first-person operator voice; ~5–7 punchy named principles, each 2–3 sentences with a short
  rationale; link to `CLAUDE.md` for the mechanics rather than re-explaining them. Derived from the
  repo's actual design (decomposition, phase notebook + versioned docs, review gates, deferred jobs,
  commit-per-slice, one cross-tool contract) + best practice.
- **Section 8 — Related / inspired by** (heading exactly `## Related / inspired by`): one-line
  positioning lead-in (labeled as editorial) + the verified, grouped see-also list from `phase.md`.
- **TOC:** add two entries between the `Project structure` and `Contributing` lines:
  `- [How I work with coding agents](#-how-i-work-with-coding-agents)` and
  `- [Related / inspired by](#related--inspired-by)`.

Honor `phase.md` caveats: omit star counts; use **oh-my-openagent**; do not repeat refuted claims;
keep "closest/distinct" framing explicitly editorial.

Out of scope: any change to P1.S1's sections beyond the anchor/TOC insertion.

## Milestones

1. Replace the `<!-- P1.S2 … -->` anchor with sections 7 and 8.
2. Add the two TOC entries in document order.
3. `validate`; verify the two new heading anchors match the TOC links and the related-project links
   are well-formed; finish slice; write `result.md`; append notes to `phase.md`; commit.

## Validation

- `python3 scripts/workflow.py validate` passes.
- New heading anchors (`#-how-i-work-with-coding-agents`, `#related--inspired-by`) match the TOC.
- Related-project links are well-formed `https://github.com/…` URLs; no star counts present;
  the methodology reads in a consistent first-person voice.

## Docs to Update

Use `python3 scripts/workflow.py doc-new-version ...` for durable doc changes. Do not patch `docs/current/*.md` directly.

- None. `README.md` is a root file, not a versioned `docs/` doc.
