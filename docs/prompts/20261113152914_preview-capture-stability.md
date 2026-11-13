# User request

Are there any hacks and weird code that we can streamline to speedup or make this more stable

## Repository instructions

Create a branch and PR. Commit and push changes when completing a task. If there are no code changes, don't create a PR. In a sub-agent, monitor the PR and fix failures. If a PR changes after a successful run, monitor the PR again in a sub-agent to make sure it passes.

Log each change’s user requests and delegated prompts in a separate timestamped file under `docs/prompts/`; append follow-up prompts for the same change.

## Scope

Review fragile workarounds and unnecessary work. Harden Image Preview against stale asynchronous capture completions, replace string source routing with an enum, and avoid decoding unchanged clipboard contents.

## Delegated PR monitoring prompt

Monitor the PR for branch `codex/gabriel/preview-capture-stability` in `rel-me/Schnaps` until all checks finish. Use `gh` to inspect the PR and CI results. If checks fail because of these changes, fix the issue, append your follow-up work to `docs/prompts/20261113152914_preview-capture-stability.md`, run appropriate local validation, commit and push the fix, and monitor the new head again. Do not merge. Report the final PR URL, head commit, and check results. Wait between polls and send meaningful progress updates so the parent can keep the user informed.

## Validation

`swift test`: all 74 tests passed, including delayed success/failure cases for source changes, window changes, and stopping live preview, plus clipboard refresh and current capture failure coverage.
