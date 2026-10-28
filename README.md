# Schnaps

A native macOS measurement overlay, built entirely in Swift with AppKit, SwiftUI, and ScreenCaptureKit. Inspired by [Vernier](https://usevernier.com/), independently implemented without its Rust runtime or source code. Requires macOS 14 or later. No third-party dependencies.

## Run

```sh
swift Scripts/build-app.swift
open build/Schnaps.app
```

The package also opens directly in Xcode. The bundled `.app` is recommended for consistent macOS permission handling. To install, copy `build/Schnaps.app` into Applications. For stable local signing across rebuilds, set `SCHNAPS_SIGN_IDENTITY` to an installed Apple Development signing identity before running the build script; otherwise it ad-hoc signs the app. The build and icon export scripts are also Swift. Xcode 26 compiles the layered Icon Composer source; older Xcode versions use its checked-in ICNS export.

Launch Schnaps to open its native settings window: a standard macOS sidebar with General, Measurement, Shortcuts, and Permissions panes. Units, color tolerance, and the default tool are saved across launches. The window uses system forms, buttons, pickers, typography, and appearance.

Use **Find Dimensions** (**Shift–Command–F**) to measure edges and gaps under the pointer, or **Measure Area** (**Shift–Command–M**) to draw an exact rectangle. Both tools are also available in General settings and the ruler menu-bar menu. If another app owns a global shortcut, use the menu-bar action.

In Find Dimensions, horizontal and vertical rulers independently follow the nearest color boundaries through the pointer. Click to hold both readings, use H or V to pin one distance, or Space to pin both. Drag loosely around an object to trim the selection to its foreground bounds; disconnected details such as letters are included. Hold Option, hold Shift for a square, or right-drag to bypass object snapping.

Manual measurement works immediately. Choose **Allow Screen Recording…** in Settings → Permissions to enable edge detection, then enable Schnaps in **System Settings → Privacy & Security → Screen & System Audio Recording**. Relaunch if macOS requests it. Schnaps captures a still image of each display when you activate the overlay; Refresh takes a new snapshot. Captures stay in memory and are discarded when the overlay closes. No continuous recording, files, network access, or Accessibility permission is needed.

## Measurement controls

| Action | Control |
| --- | --- |
| Draw a region | Drag anywhere |
| Draw a square | Shift-drag |
| Find edge distances | Find Dimensions; move the pointer and click to hold |
| Find an object’s bounds | Find Dimensions; drag a loose rectangle around it |
| Bypass object snapping | Option-drag or right-drag |
| Move a selection | Drag inside it |
| Resize a selection | Drag a corner handle |
| Deselect / resume edge detection | Right-click |
| Pin a measurement | Space or Pin |
| Edit a pinned measurement | Click inside it |
| Move one unit | Arrow keys |
| Resize one unit | Option-arrow keys |
| Move / resize ten units | Add Shift |
| Copy dimensions | Enter or Command-C |
| Copy CSS dimensions | Shift-Enter or Shift-Command-C |
| Switch screen points / physical pixels | U or the units button |
| Switch tool | S or the tool segmented control |
| Adjust color tolerance | 8 / 18 / 36 in the toolbar |
| Pin horizontal / vertical distance | H / V |
| Add horizontal / vertical guide | Shift-H / Shift-V at the pointer |
| Extend alignment lines | Hold Shift |
| Delete selection or latest pin | Delete |
| Restore the latest pin for editing | Command-Z |
| Clear current display's canvas | Command-K or Clear |
| Refresh screenshots | R or Refresh |
| Close overlay | Escape or Done |

Points correspond to logical macOS layout coordinates; physical pixels account for each display's backing scale. CSS output always uses logical coordinates. Arrow keys follow the selected unit. Each connected display has its own canvas and scale; a measurement is confined to that display. Pinned rectangles and distances survive overlay toggles within the running app; they are not saved to disk. Display changes close the overlay safely.

Find Dimensions measures contiguous horizontal and vertical color runs through the pointer with adjustable RGB tolerance. Object snapping compares the selected area against its dominant perimeter color and trims the surrounding background. If a clear background cannot be established, it keeps the manual selection. These are contrast-based measurements, not semantic recognition: gradients, complex shadows, and photographs can produce partial or broad results. Manual dragging remains available everywhere. The toolbar and bottom hint are overlay controls, so measure the content beneath them after repositioning the underlying window or using another part of the display.

This first version implements measurement. Screenshot export, annotation-tool handoff, Figma zoom integration, persistent sessions, and editable guides are outside this version.

## Development

```sh
swift test
swift Scripts/build-app.swift --debug
```

`MeasurementCore` contains the geometry, unit formatting, RGBA conversion, and deterministic edge scanner. Tests exercise reverse drags, clipping, constrained squares, Retina scaling, movement bounds, tolerance, pixel-inclusive edges, invalid buffers, capture orientation, independent gap measurements, one-pixel runs, whole-object bounds, disconnected details, and shadow tolerance. GitHub Actions runs tests and builds and verifies the macOS app bundle.

## App icon

The bottle-only icon is designed in [Icon Composer](https://developer.apple.com/icon-composer/). Open `Assets/Schnaps.icon` to edit its artwork, scale, background, lighting, and appearances. Run `swift Scripts/export-icon.swift` with Xcode 26 / Icon Composer selected to regenerate the reviewed previews and the full-resolution legacy ICNS. The normal app build compiles adaptive Liquid Glass assets with Xcode 26 and uses the exported ICNS on older toolchains.

The app retains its original `com.gabrielhandford.Schnap` bundle identifier and settings domain to preserve preferences and Screen Recording authorization when upgrading to Schnaps.
