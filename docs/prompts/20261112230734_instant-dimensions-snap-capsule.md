# User requests

- “When I start find dimensions there is a delay before it appears.. I want it to be instant... Also if snap is on when measuring area show a "Snap" capsule under the w x h”
- Clarification: “Automatic edge snapping” (rather than guide / selected-object settings).

# Repository workflow instructions

Create a branch and PR; commit and push changes. Use a sub-agent to monitor the PR and fix failures. Monitor again after any change following a successful run. Record requests and delegated prompts in this file.

# Delegated prompts

Monitor the PR for the current branch codex/gabriel/instant-dimensions-snap-capsule until all checks finish. Inspect any failures, fix issues caused by this change, run relevant validation, commit and push fixes, and monitor the new head again until it passes. Append any delegated follow-up prompts to this prompt log. Do not merge the PR. Report the final checks and any changes made.
