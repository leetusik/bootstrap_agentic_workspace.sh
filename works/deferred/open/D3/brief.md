# Deferred: D3 Make installer/build.py smoke-execute the assembled artifact

## Context

## Why Deferred

build.py only compile()s the artifact body and sh -n's the wrapper -- it never runs it. So a broken installer (import-time guard mismatch, missing PAYLOADS key) passes build, --check, and the pre-commit hook, and ships. P15 worked around this by executing the artifact in every slice, which is not a guarantee.

## Trigger to Promote

Next time installer/build.py is touched, or the first time a broken artifact reaches a commit

## Notes

