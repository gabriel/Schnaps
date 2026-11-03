# Show Dock for app windows

## User request

"If showing a window like settings or window preview, show the icon in the dock with app menu.

Change the \"Show in Dock\" setting to \"Always show in dock\""

## Implementation

Temporarily use regular app activation for Settings, image/window previews, browser previews, and Text Inspector. Keep the Dock icon while these windows remain open or minimized. Rename and localize the existing preference without changing its stored key.

## Delegated prompt

Monitor the PR for this change until all checks finish. Fix any failures caused by the change, commit and push any fixes, and monitor the updated PR again until checks pass. Report the final status.
