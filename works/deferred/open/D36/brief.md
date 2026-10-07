# Deferred: D36 README caveats for the private install: git clean and working-tree tools

## Context

## Why Deferred

git clean -fdx deletes the ignored host-side files (workflow/ survives; --update --nested restores the rest); tools that read the working tree rather than git (local docker build COPY ., npm publish) ignore info/exclude.

## Trigger to Promote

The next README edit or an operator report

## Notes

