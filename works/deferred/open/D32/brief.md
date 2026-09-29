# Deferred: D32 Widen design-check's reference scan beyond src, href and url()

## Context

## Why Deferred

DESIGN_REF_RE reads only src=, href= and url(...); a probe showed <img srcset="//cdn..."> and <style>@import "http://...";</style> both pass design-check, and poster= / <object data=> escape it by inspection. Dates from P26.S1, not an F1 regression.

## Trigger to Promote

A drafted card passes design-check but loads a resource through a form the scan does not read, or the dashboard build asks for a stricter check

## Notes

