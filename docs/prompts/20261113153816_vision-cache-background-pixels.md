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

## Follow-up user request

Can you benchmark these changes against main to see how much they improve CPU usage and responsiveness?

## Benchmark approach

Compile the actual core conversion, ScreenSnapshot, VisionRenderer, and candidate cache sources from pinned main/candidate commits with Swift `-O`. Use identical synthetic scenes and a baseline adapter matching main's DesignCanvas crop/filter/resampling calls. Measure process CPU and wall time for 120 redraws with a 30:4 redraw/capture ratio, plus all-cache-miss control. Separately measure 4K/5K pixel conversion at four frames per second with a detached producer probing MainActor scheduling every 2 ms. Alternate execution order across five trials. Commit the reusable harness, raw measurements, and a report distinguishing isolated path measurements from full-app CPU/UI performance.

## Benchmark results and validation

Five final paired trials compare main `8cb1825` to candidate `c1107e4` on an M2 Pro. Median CPU reductions are 81.3% (grayscale screen), 87.0% (blur + Retina), and 87.6% (stationary Loupe). All-miss control changes are inconclusive. Conversion-only CPU changes are +2.1% at 4K and +0.6% at 5K, with overlapping trial ranges. Median-trial p99 MainActor service delay changes from 0.944 to 0.447 ms at 4K and 1.059 to 0.468 ms at 5K. Scheduling outliers persist; the report includes maxima, ranges, the instrumented workload's additional CPU, and limitations on extrapolating to whole-app behavior.

Both optimized benchmark binaries compiled and ran for five trials; all conversion checksums agree. Verified Python runner syntax, trial counts, measured harness SHA-256, and whitespace. Runtime implementation is unchanged. Results and raw measurements are under `docs/benchmarks/20261113-preview-performance.*`.

## Delegated PR monitoring prompt after benchmark additions

Monitor the PR for branch `codex/gabriel/vision-cache-background-pixels` in `rel-me/Schnaps` until all checks finish. Use `gh` to inspect the PR and CI results. If checks fail because of these changes, fix the issue, append your follow-up work to `docs/prompts/20261113153816_vision-cache-background-pixels.md`, run appropriate local validation, commit and push the fix, and monitor the new head again. Do not merge. Report the final PR URL, head commit, and check results. Wait between polls and send meaningful progress updates so the parent can keep the user informed.

## Follow-up user request

Get the stranded changes from PRs #78 and #79 into a new PR against main, including the magnet icon, and make sure the checks pass. Merge the other PRs too if they are good.

## Delegated integration and monitoring prompt

Review PRs #82 and #83 for correctness. Update each branch with latest origin/main in isolated worktrees, log follow-up prompts, push commits, and monitor both CI jobs until success. Fix integration issues and recheck before squash merging with expected head SHAs. Review merged results and monitor final main CI. Do not merge the recovery PR.

## Integration review

Reviewed cache identity, invalidation, storage accounting, rendering pixel equivalence, conversion cancellation, and benchmark limitations. No blockers found. Confirmed the existing worktree was clean, then merged latest main including PRs #80, #81, and #82. Architecture documentation merged without conflict and retains both preview generation handling and vision cache behavior.
