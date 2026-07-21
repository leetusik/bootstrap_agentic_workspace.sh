# Deferred: D1 Make /explain portable so public users can use it

## Context

## Why Deferred

/explain hardcodes the operator's personal Mac KB (~/projects/personal/knowledge, viewer localhost:8765, docker/mkdocs). Even when installed via --with-explain, public users can't use it as-is.

## Trigger to Promote

When shipping /explain to public users: parameterize the KB location and viewer (configurable path + port via env or a setting, or drop the docker/mkdocs assumption) so any adopter can point it at their own knowledge base.

## Notes

