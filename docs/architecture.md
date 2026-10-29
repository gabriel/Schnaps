# Architecture

## Native application

`Sources/Schnaps/App.swift` starts AppKit as a menu-bar utility, registers Carbon global hotkeys, and owns native settings and measurement windows. The settings view uses SwiftUI `NavigationSplitView`, a sidebar list, grouped forms, and system controls. About is the final settings pane, with version information and native update controls. Sparkle preferences are observed directly so changes in update dialogs stay in sync. Sparkle's `SPUStandardUpdaterController` owns update checking, UI, and installation.

`OverlayController` captures displays before showing the overlay and creates one borderless window per `NSScreen`. Starting another tool replaces the current one; activating the same tool toggles it off. A generation token prevents canceled async captures from reopening the overlay. Display topology changes close the overlay safely. Pins are held in memory across overlay toggles. The canvas has no toolbar, persistent instructions, or tint. Only measurement marks and brief action/error feedback are drawn; the canvas exposes its description to accessibility.

## Capture and coordinates

`ScreenSnapshot` uses `SCShareableContent` and `SCScreenshotManager`, excluding Schnaps's own windows. Captured CGImages are converted into tightly packed top-left-origin RGBA buffers. AppKit global coordinates are converted into local flipped canvas coordinates; each display's captured width/height ratios convert between logical points and physical pixels. The two axes are scaled independently.

Snapshot images are held in memory unless the user explicitly exports a selection. Screenshot export crops the original image without measurement marks, adds bounded logical-point padding, optionally resamples Retina images to 1x, and encodes PNG or JPEG. CleanShot handoff uses a local file URL through its documented URL scheme. Freeze screen can be disabled to use a nonactivating panel over the live desktop with periodic fresh edge-detection snapshots. A refreshed capture replaces the prior scene. The overlay does not capture its own measurement marks and does not run a recording stream. Without capture permission or after a capture error, manual selection remains usable.

## Measurement core

`MeasurementCore` is independent of AppKit's window/input system:

- `MeasurementGeometry` normalizes reverse drags, constrains selections, keeps squares inside bounds, translates rectangles, and formats units.
- `PixelBuffer.dimensions` scans horizontal and vertical continuous color runs through the pointer. RGB differences are bounded by a configurable tolerance, including one-pixel runs.
- `PixelBuffer.objectBounds` samples a loose selection's perimeter, requires a majority background color, then scans the interior for foreground bounds. This includes disconnected text or icon details. If no clear background is available, the app retains the manual selection.
- `TolerancePreset` defines stable identities for Zero, Low, Medium, and High (default thresholds 0, 8, 18, 36). User-configurable thresholds are resolved separately by `MeasurementPreferences`, including migration from saved slider values, bounded scroll steps, and wrapping keyboard cycles. Native menu checkmarks refresh when their submenu opens. Settings and every active display share the persisted value; held readings and snapped bounds recalculate on changes.
- `MeasurementPresentation` formats fractional/rounded points, Retina pixels, ordered clipboard formats, and aspect ratios. `MeasurementSnapping` constrains color-run rulers to guides and intersecting pinned objects. `ScreenshotGeometry` handles bounded padding and crop coordinates.
- `DimensionSpan` and `Dimensions` represent independent rulers and convert them to logical display coordinates.

Detection is contrast-based, not semantic object recognition. Complex imagery and gradients can produce unexpected boundaries. Shadow inclusion depends on tolerance. Use manual selection when exact visual bounds cannot be inferred.

## Validation

Swift Testing covers reverse drags, clipping, constrained squares, Retina units, movement bounds, image orientation, channel conversion, tolerance, invalid buffers, gap measurements, one-pixel features, object bounds, disconnected details, and shadow exclusion. Live UI checks used known-size rectangles and gaps on a Retina display to verify capture, snapping, copy output, and independent distance pins.
