# Improve Loupe pixel control

## User request

"Make the Loupe tool better.. still hard to use (not centerd on pixel).. could arrow keys help find adjust?"

## Implementation

Center the magnified view on the sampled physical pixel and outline that pixel. Allow arrows to pin and nudge one pixel, Shift-Arrows to nudge ten, and Space to resume following the pointer without enabling marker editing. Keep keyboard focus while Loupe is active and document the controls.

## Delegated prompt

Monitor the PR for this change until all checks finish. Fix any failures caused by the change, commit and push any fixes, and monitor the updated PR again until checks pass. Report the final status.

## Follow-up user request

> [https://github.com/gabriel/Schnaps/pull/69](https://github.com/gabriel/Schnaps/pull/69)
> [https://github.com/gabriel/Schnaps/pull/66](https://github.com/gabriel/Schnaps/pull/66)
>
> which one is better .. merge the better one

## Follow-up delegated prompts

> Monitor PR #69 (gabriel/Schnaps) for current checks and report exact checked head and outcomes promptly. Stay available to monitor its checks again if the PR head changes and the main Swift workflow after merge once I send the merge commit. Investigate any failures and fix in-scope failures if needed, coordinating with me before any code edit/push to avoid races. Do not merge or close either PR.

> The PR head changed for a prompt-log update. Monitor both Swift matrix checks on the new head and investigate any failures. After merge, monitor the Swift workflow on the merge commit.
