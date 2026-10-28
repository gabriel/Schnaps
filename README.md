# Schnap

A native macOS measurement overlay, built entirely in Swift with AppKit, SwiftUI, and ScreenCaptureKit. Inspired by [Vernier](https://usevernier.com/), independently implemented without its Rust runtime or source code. Requires macOS 14 or later. No third-party dependencies.

## Run

```sh
swift Scripts/build-app.swift
open build/Schnap.app
```

The package also opens directly in Xcode. The bundled `.app` is recommended for consistent macOS permission handling. To install, copy `build/Schnap.app` into Applications. For stable local signing across rebuilds, set `SCHNAP_SIGN_IDENTITY` to an installed Apple Development signing identity before running the build script; otherwise it ad-hoc signs the app. The build script and icon generation are also Swift.

Launch Schnap, then choose **Start measuring**, use its ruler menu-bar icon, or press **Shift–Command–M** globally. If another app owns this shortcut, use the menu-bar action.

Manual measurement works immediately. Choose **Allow Screen Recording…** in the welcome window to enable edge detection, then enable Schnap in **System Settings → Privacy & Security → Screen & System Audio Recording**. Relaunch if macOS requests it. Schnap captures a still image of each display when you activate the overlay; Refresh takes a new snapshot. Captures stay in memory and are discarded when the overlay closes. No continuous recording, files, network access, or Accessibility permission is needed.

## Measurement controls

| Action | Control |
| --- | --- |
| Draw a region | Drag anywhere |
| Draw a square | Shift-drag |
| Detect a color region | Hover; click to hold the detected bounds |
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
| Toggle edge detection | S or Edges |
| Adjust color tolerance | 8 / 18 / 36 in the toolbar |
| Add horizontal / vertical guide | H / V at the pointer |
| Extend alignment lines | Hold Shift |
| Delete selection or latest pin | Delete |
| Restore the latest pin for editing | Command-Z |
| Clear current display's canvas | Command-K or Clear |
| Refresh screenshots | R or Refresh |
| Close overlay | Escape or Done |

Points correspond to logical macOS layout coordinates; physical pixels account for each display's backing scale. CSS output always uses logical coordinates. Arrow keys follow the selected unit. Each connected display has its own canvas and scale; a measurement is confined to that display. Pinned rectangles survive overlay toggles within the running app; they are not saved to disk. Display changes close the overlay safely.

Edge detection finds contiguous horizontal and vertical color runs through the pointer with adjustable RGB tolerance. It works best on solid UI surfaces; text, gradients, shadows, and photographic content can produce partial or broad bounds. Manual dragging remains available everywhere. The toolbar and bottom hint are overlay controls, so measure the content beneath them after repositioning the underlying window or using another part of the display.

This first version implements measurement. Screenshot export, annotation-tool handoff, Figma zoom integration, persistent sessions, and editable guides are outside this version.

## Development

```sh
swift test
swift Scripts/build-app.swift --debug
```

`MeasurementCore` contains the geometry, unit formatting, RGBA conversion, and deterministic edge scanner. Tests exercise reverse drags, clipping, constrained squares, Retina scaling, movement bounds, tolerance, pixel-inclusive edges, invalid buffers, and capture orientation. GitHub Actions runs tests and builds and verifies the macOS app bundle.
