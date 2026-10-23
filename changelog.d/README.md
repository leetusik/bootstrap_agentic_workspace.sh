# changelog.d: release fragments

This directory holds the release notes of work that has not landed on `main` yet. A branch (or a
release made on `main` directly) never touches `WORKSPACE_VERSION` in `installer/main.py` or the
numbered `## v<N>` sections of `CHANGELOG.md`. It writes one fragment here, and
`python3 installer/build.py --release` stamps the version number when the work lands on `main`.

## A fragment

`changelog.d/<slug>.md`, a short kebab-case slug of your own (two branches write two files, so
nothing collides):

- **Line 1:** `# <one-line summary>`. It becomes the tail of the release commit's subject
  (`build(release): workspace v<M> — <summary>`).
- **The rest:** the section's bullets, written exactly as they would sit under a `## v<N>` heading
  in `CHANGELOG.md`, including a line that carries `**Migration notes.**` (say `None.` when a sync
  needs no manual step). Write no `## v<N>` heading: the stamp writes it.

```markdown
# One /rotate-backlog cleans up every done phase

- **What changed.** One or two sentences an adopter can act on.
- **Migration notes.** None beyond `--update`.
```

`README.md` (this file) is never a fragment: `--release`, the hooks and CI all read only `*.md`
files directly in this directory other than `README.md`.

## Landing

```sh
git merge --no-ff --no-commit <branch>
python3 installer/build.py --release        # stamps v<N+1>, folds and deletes the fragments, rebuilds
git add -A CHANGELOG.md installer/main.py bootstrap_agentic_workspace.sh changelog.d
git commit -m "build(release): workspace v<M> — <summary>"
```

`--release` refuses unless `HEAD` is `main`, when no fragment is pending, when a fragment lacks its
line-1 summary or its Migration notes line, and when `WORKSPACE_VERSION` is not the top `## v<N>`.
Several pending fragments fold into one version, their bodies in file-name order. On `main`, the
`pre-commit` and `pre-merge-commit` hooks refuse a commit that still holds a fragment, and CI
fails a push to `main` that carries one.
