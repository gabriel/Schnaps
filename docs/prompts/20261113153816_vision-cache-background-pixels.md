# User request

Can you tackle caching the vision filters and moving full-screen pixel conversion off the main actor too?

## Context

Follow-up to the review that identified repeated vision filtering during canvas redraws and synchronous full-screen RGBA conversion on the main actor. Implement these improvements on a separate branch and PR from the existing Image Preview fix.

## Repository instructions

Create a branch and PR, commit and push completed changes, and delegate PR monitoring and failure repair to a sub-agent. Record user requests and delegated prompts here.

## Implementation and validation

Added a canvas-local cache of rendered crops keyed by immutable source image identity, crop, vision mode, and Retina output size. The LRU retains at most 32 entries within a 64 MiB accounted-storage budget and is cleared for new frames and dismissed tools. Uncached oversized renders retain their existing drawing behavior.

Moved captured CGImage-to-PixelBuffer conversion into a detached task with cancellation forwarding and checks before/after conversion. Capture and AppKit objects stay on the main actor; snapshot values are Sendable.

`swift test`: all 75 tests passed, including cache reuse/invalidation, per-mode pixel equivalence, LRU eviction/budget, fractional Retina crops, conversion/scaling equivalence, and cancellation.

## Delegated PR monitoring prompt

Monitor the PR for branch `codex/gabriel/vision-cache-background-pixels` in `rel-me/Schnaps` until all checks finish. Use `gh` to inspect the PR and CI results. If checks fail because of these changes, fix the issue, append your follow-up work to `docs/prompts/20261113153816_vision-cache-background-pixels.md`, run appropriate local validation, commit and push the fix, and monitor the new head again. Do not merge. Report the final PR URL, head commit, and check results. Wait between polls and send meaningful progress updates so the parent can keep the user informed.
