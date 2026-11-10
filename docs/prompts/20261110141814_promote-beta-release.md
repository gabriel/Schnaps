# Promote the latest beta to stable

## User request

> Add a `make promote` target that takes the latest beta’s version, drops the beta suffix, and builds and publishes it as a stable release.

## Delegated prompt

> Monitor the rel-me/Schnaps PR for branch codex/gabriel/promote-beta-release. Verify its head and wait for both Swift CI matrix jobs to complete. If a change in this PR causes a failure, fix it, append any follow-up prompts to the existing prompt log, commit and push the fix, and monitor the new head through completion. Report the verified head and check results. Do not merge or publish a release.
