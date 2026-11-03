# Improve Loupe pixel control

## User request

"Make the Loupe tool better.. still hard to use (not centerd on pixel).. could arrow keys help find adjust?"

## Implementation

Center the magnified view on the sampled physical pixel and outline that pixel. Allow arrows to pin and nudge one pixel, Shift-Arrows to nudge ten, and Space to resume following the pointer without enabling marker editing. Keep keyboard focus while Loupe is active and document the controls.

## Delegated prompt

Monitor the PR for this change until all checks finish. Fix any failures caused by the change, commit and push any fixes, and monitor the updated PR again until checks pass. Report the final status.
