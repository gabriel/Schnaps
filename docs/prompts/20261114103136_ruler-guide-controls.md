# User request

It's hard to grab rulers and guides... I don't know how to remove them... the cursor doesn't change when trying to grab them... there should be a "Remove all" thing in menubar or something too.. or also (X) icons next to them that remove them? Fix all this stuff

# Repository instructions

Create a branch and PR, commit and push changes, and delegate PR monitoring and failure fixes to a sub-agent. Monitor again after any later PR changes. Record user requests and delegated prompts in this file.

# Delegated PR monitoring prompt

Monitor the PR for branch `codex/gabriel/ruler-guide-controls` in `rel-me/Schnaps` until all checks finish. Inspect failures, fix any failures caused by this change in the shared checkout, run relevant checks, commit and push fixes, and monitor the updated PR again until it passes. Do not merge. Preserve unrelated work. If fixes are needed, append their context and any further delegated prompts to this prompt log. Report the final head commit, check results, and any remaining external blockers. Use bounded waits and send a progress update if checks take more than a minute.
