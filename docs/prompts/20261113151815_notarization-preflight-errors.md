# Clarify notarization preflight errors

## User request

```text
Schnap on main via Swift v6.3.3
❯ make beta

A new release of gh is available: 2.103.3 → 2.104.0
To upgrade, run: brew upgrade gh
https://github.com/cli/cli/releases/tag/v2.104.0

Beta: 0.7.7-beta.1 (24) from 8cb182518dd1
Error: HTTP status code: 403. A required agreement is missing or has expired. This request requires an in-effect agreement that has not been signed or has expired. Ensure your team has signed the necessary legal agreements and that they are not expired.
Release failed: Notarization profile 'Schnaps' is unavailable. Set SCHNAPS_NOTARY_PROFILE to an existing notarytool Keychain profile before publishing.
make: *** [beta] Error 1
```

## Standing user instructions

Create a branch and PR; commit and push completed changes. In a sub-agent, monitor the PR and fix failures; monitor again if its head changes after a successful run. Log the user requests and delegated prompts for this change here.

## Delegated prompt

Monitor the rel-me/Schnaps PR for branch codex/gabriel/notarization-preflight-errors. Verify its head and wait for both Swift CI matrix jobs to complete. If this PR causes a failure, fix it, append any follow-up prompts to this prompt log, commit and push the fix, and monitor the updated head through completion. Report the verified head and check results. Do not merge or publish a release.
