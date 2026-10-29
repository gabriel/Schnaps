# Measurement preferences

Schnaps keeps its native sidebar settings. General, Screenshots, Tolerance, and Appearance cover the controls inspected in the installed PixelSnap 2 preferences. Schnaps implements these independently in Swift.

## General

- Language: system default, English, Simplified Chinese, Spanish, French, Italian, Japanese, or Russian. The measurement preferences, tool feedback, and menus update immediately. Pro, Sparkle, and some existing About/shortcut copy retain their own language behavior.
- Activation: default tool, start at login through macOS Login Items, menu-bar visibility, optional Dock icon, and a short tutorial. Reopen Schnaps from Finder or use its global shortcuts if both icons are hidden.
- Retina: fractional points, rounded points, or physical display pixels. Display units, width/height indicators, and the cursor are independently configurable.
- Clipboard: width/height or height/width; CSS or indented-syntax SASS in either property order. Shift-Return always copies width-first CSS. CSS and SASS use logical points as CSS pixels, regardless of Retina scaling.
- Aspect ratios: automatic, integer standard ratios, decimal ratios, or common ratios only. Enable independently for Find Dimensions and Measure Area. Common ratios allow a 0.5% size mismatch for pixel rounding.
- Find Dimensions snaps to guides and pinned rectangles independently. Only edges crossing the pointer's ruler participate; the nearest boundary on either side wins.
- Freeze screen is on by default. Off leaves the underlying application active and displays the live desktop; Find Dimensions refreshes its edge-detection frame approximately four times per second. Holding a reading or drawing a selection keeps its geometry stable until cleared. R refreshes manually.

## Screenshots

During measurement, C copies the current area or the rectangle formed by the two distance rulers. P saves it. Captures exclude Schnaps's measurement marks and use the frozen image when Freeze screen is on, otherwise a fresh screen capture. Screen Recording permission is required; denial never prevents manual area measurement.

Choose an export folder, PNG/JPEG, native Retina or 1x resolution, and capture sounds. Padding ranges from 0–100 logical points; Auto adds 8% of the shorter side, bounded to 8–64 points. Padding clips at the display edge. Hold Option with C/P to toggle it: configured padding becomes zero; zero becomes Auto.

Optional CleanShot integration opens the local capture in CleanShot X's Quick Access Overlay via its [documented URL API](https://cleanshot.com/docs-api). CleanShot must be installed. Its own UI handles editing and any cloud upload; Schnaps does not upload screenshots. Copies handed to CleanShot use the macOS temporary directory; saved captures use the chosen folder.

## Tolerance

Customize each of Zero, Low, Medium, and High from 0–100. Choose a default preset; the menu bar, T/Shift-T, and optional scroll adjustment share this selection. Changing a preset updates active measurements immediately. Preset identity remains stable even when values overlap or are reordered.

Schnaps preserves its established defaults (0, 8, 18, 36) rather than changing existing users' edge detection. Restore Defaults resets those values and selects Medium.

## Appearance

Choose System, Light, or Dark; enable brief feedback animations; set primary, alternative, and guide colors; and enable automatic contrast. X switches between primary and alternative colors for the current canvas. Auto contrast chooses between those colors against the captured background and adds a fine contrasting stroke to rulers. Reduce Motion suppresses feedback animation. Full-screen activation never animates, avoiding a desktop zoom effect.

Restore Defaults resets only appearance preferences.
