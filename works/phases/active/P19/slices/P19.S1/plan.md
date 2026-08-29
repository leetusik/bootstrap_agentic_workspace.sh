# Plan — P19.S1: the `research` slice kind, and `DECOMP2` generalized

Add `research` to the closed slice-kind set with its full semantics, and turn `DECOMP2` from a
`build-after`-only device into the ordinary sequel to a research slice. Ship no version bump —
`P19.S2` writes v36 and the changelog for both halves.

`phase.md`'s `## Notes for later slices` carries the grepped blast radius with line numbers, the
byte-identical-agent-bodies trap, and the installer-rebuild rule. Read them; they are the map. This
plan says what to decide, not where the files are.

## The kind's semantics — all four, stated wherever routing is stated

1. **Findings-only.** A research slice writes no product code. Its product is what was learned.
2. **Always `slice-executor-high`.** Like `decomposition` and `review`, and *regardless of `risk`* —
   research decides what gets cut next, so a weak read is expensive. This is the one that needs care:
   the tier-routing sentences in both `do-*` skills, both agent files and `CLAUDE.md` currently read
   "decomposition and review always → high; `risk` exactly `low` → mid; anything else → high". A
   research slice must not be routable to `mid` by a `low` rating, so `research` joins the
   *always-high* clause rather than relying on its rating. Say what `--risk` should then be set to on
   a research slice (`high`, so the recorded rating never contradicts the routing) and say plainly
   that the kind wins if they ever disagree.
3. **Findings land in `phase.md`.** This is the load-bearing one and the reason the kind is worth a
   dispatch at all: the executor's context dies with the slice, so the notebook is what the next
   slice reads. `result.md` keeps the log — dead ends, commands, the detail — as always. The
   existing division-by-audience rule in `CLAUDE.md` already says this for every slice; for
   `research` it is the *point*, so state it as such rather than leaving it implied.
4. **A `DECOMP2` normally follows.** "Usually", not "must" — the operator's word. A research slice
   whose findings change nothing about the remaining breakdown needs no re-cut.

## `DECOMP2`, generalized

Today every mention ties it to the `build-after` design style. After this slice it has **two**
origins, and the prose should read that way rather than bolting research on as an aside:

- the `build-after` design style (unchanged in every particular), and
- **a research slice** — "we had to learn something before we could cut the rest".

The `plan only` rule in both `do-*` skills ("stop before anything whose plan depends on something
that has not landed yet") gains a fourth face: a `DECOMP2` following a research slice is never
pre-planned, for exactly the same reason the design one is not. The idle-window guidance's
"usually skip it for … `DECOMP2`" list needs no change in substance but should not read as
design-only either.

Keep `P<N>.DECOMP2` as the id. If you judge it worth one clause to say a phase needing a third pass
numbers it `DECOMP3`, add it; do not expand it into a scheme.

## Scope discipline

- **Do not touch `docs/current/*.md`** — generated snapshots. Do not run `doc-new-version`. Durable
  truth you change becomes a one-line note under `## Doc impact` in `phase.md`; `P19.REVIEW`
  consolidates. Expect at least an `operations.md` note (the kind set and the routing rule) and a
  `decisions.md` note (the kind exists, and why it was added).
- **Do not touch anything Aside-related.** That is S2's, and you overlap it in `CLAUDE.md` and both
  agent files — leave those regions alone so S2's edits apply cleanly.
- **No version bump, no changelog.** S2 writes both.
- Both agent bodies are **byte-identical below the frontmatter** and `tests/retrofit_smoke.sh`
  asserts it. Edit them the same way.

## Validate

`python3 scripts/workflow.py validate` · `bash tests/retrofit_smoke.sh` — and add assertions to
that file for the new kind rather than only editing prose, per the notebook's note. Prove the
engine end of it directly: creating a slice with `--kind research` succeeds and an invented kind is
still a hard error. Do that on scratch state you clean up, or on a temp copy — **never** by adding a
slice to P19, whose 4-slice cap is the operator's and is binding.

`python3 installer/build.py` after editing machinery, leaving the rebuilt
`bootstrap_agentic_workspace.sh` in the tree; `--check` must pass.

## Notebook

Edit `phase.md` under budget (200 lines / 16 KB — it is at 140/10.8 KB, so there is little room:
**consume the three `for P19.S1` notes** you have used and drop them, which is where your space
comes from). Add `## Doc impact` lines, replace rather than stack `## Decisions`, leave `## Slices`
alone, and rewrite `## Now` (≤ 15 lines) last as S2's handoff — S2 needs to know what you changed in
the files it also edits.

## Return

A structured verdict. `result.md` verdict-block-first. Do not commit, do not transition status.
