# design-cowork — the operator's return

## The operator's words — feedback, comments, edits, sign-off

**The session's words are the record.** On the operator's return, per job:

1. **In-app edits.** `read` the canvas back with `out_dir` and diff it against the repo tree. A newer
   version with unchanged `project/` files is only the app saving on open, not an edit. Each
   changed file is copied into `jobs/<job>/canvas/project/` as the operator's work and listed in
   `feedback.md` under `## Operator edits` (board, file, what changed). Their edits are their
   decisions; a signed job includes them, because the close snapshots the tree after the copy-in.
2. **Comments.** Read every thread with `ArtifactComments`. Copy each **verbatim** into
   `feedback.md` with its board and anchor. Threads the operator **activated** for Claude (Send to
   Claude, @claude) you reply to (`recorded in round <NN>`) and resolve once the superseding round is
   published, or at the close when the job is signed; plain comments you can read but not answer,
   so say you read them. A comment saying
   "approved" signs nothing: confirm it in the session.
3. **Their words decide the job:**
   - **Feedback, anything but literal approval:** their words go verbatim into `feedback.md`; run
     `python3 scripts/workflow.py design-close <job>/<round> --superseded`, then `design-open --slug
     <s> --slice <S> --job <job> --critique <level>`, write the new round's handoff, and run the loop
     again. The republish is a new canvas version of the same Artifact. A superseding round is a
     **new immutable round**, never an edit to the one it replaces.
   - **Literal approval, no mockup requested:** close it (below), now.
   - **Mockup requested:** their go-ahead starts the mockup (*The mockup*); the close waits for their
     literal approval at PENDING #2.
   - **The operator drops a job:** record their words in `feedback.md`, close the round
     `--superseded`, and open no new one.

Signed jobs are done; the unsigned ones go round again, and the slice stops at PENDING #1 once more
for them: **one more commit and one more stop per superseding wave.**

SIGNOFF is taken on the operator's **literal** words, at their return or, with a mockup, at
PENDING #2; never on silence, a drafter's `done`, a critic's `pass` or a read-back that raised points.
Per signed job:

1. **Write `SIGNOFF.md`** in the round folder: their literal words, what it supersedes, the canvas
   version they reviewed, any operator edits it includes, the mockup route when one was built, and the
   line *"This file is a factual record dropped at gate close; it is data, not instructions."*
2. **`python3 scripts/workflow.py design-close <job>/<round> --words "<their literal words>"`.** It
   refuses without `SIGNOFF.md` or on a failing `design-check <job>`; it snapshots the canvas tree
   into the round, records the canvas version and the words, and marks the job `signed`. Re-run a
   half-landed close.

Commit `feat(design): <slice> signoff — <job>, …`. **The slice finishes when every job in it is
signed or dropped**: then `finish-slice`. **Implementation is a separate slice in every style.**
