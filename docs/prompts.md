# Prompts that shaped Schnaps

This is a record of the user-authored product and design requests used to build the app. It documents intent and the resulting implementation, rather than claiming every generated implementation was accepted unchanged. Formatting is normalized for readability. System instructions, private credentials, authentication state, and unrelated desktop content are excluded.

## 1. Initial product brief

> Create a macos app to create a measurement overlay... A swift version of this open source project: https://usevernier.com/
>
> It should be 100% swift.
> I've installed it at /Applications/Vernier.app and it is running.
> Vernier has lots of bugs though.
>
> First do the measurement tool. Don't stop until it's implemented. I might need to add screenrecording permissions.

**Result:** native Swift app using AppKit, SwiftUI, and ScreenCaptureKit; manual selection, pixel/point units, pinned measurements, keyboard adjustment, multi-display canvases, and clipboard output. Independent implementation inspired by the reference, not a port of its Rust source.

## 2. Native settings and Find Dimensions

> Make the macos app feel like a native app.. with a native left sidebar.. make it look like preferences. No custom stuff.
>
> Also add a "Find Dimensions" feature which is like pixelsnap Find Dimensions

**Result:** native settings sidebar and grouped forms. Find Dimensions adds independent horizontal/vertical distance scanning, gap readings, whole-object bounds from loose selections, and independent distance pins. Manual selection remains available.

## 3. Concise help and native footers

> Remove the overly verbose descriptions. Keep the tolerance one but make concise.. keep the Tools descripotion. All the descriptions should be a footer below cell row with footer text size not it's own cell row.

> I think 1px too much padding above footer text.

> There is too much spacing between row and footer text

**Result:** tool and tolerance help is small section-footer text. Extra descriptions were removed. Footer top spacing was tightened in two iterations, first by one logical point and later by another six points.

## 4. Name and icon

> Rename the app to "Schnaps" and github repo and have a picture of schnaps as it's logo.. use a apple, macos type of app icon using Icon Composer. Make it look very well designed.

> Make it just a Schnaps bottle (no shot glass).

**Result:** Schnaps app/repository name, a single glass bottle of golden schnapps, a deep blue native material background, and an editable Apple Icon Composer document. Default, dark, and monochrome previews and a full-resolution ICNS fallback are included. The original bundle identity is intentionally preserved for upgrades.

The final image-generation prompt is recorded verbatim in [Assets/README.md](../Assets/README.md). The artwork was created with the built-in image tool, then composed, scaled, and reviewed in Icon Composer.

## 5. Sidebar and standalone actions

> - Move the About Schnaps button row into sidebar entry (last).
> - Remove hide/show button for left sidebar
> - Remove row stuff if there is just a single button with no text.. should just show a button

**Result:** About is the last sidebar action and opens the native About panel. The sidebar toggle is removed. The permission action is a standalone system button below the access row.

## 6. Release, updates, documentation, and website

> Merge all the PRs.. Make a release build and DMG, publish it. Add sparkle update capabilities. Create a project README.md. Create a website. Add a docs/ dir with documentation about the prompts used to build this app.

Public app, website, and source publication were explicitly selected in the follow-up clarification.

**Result:** the initial stacked PRs were merged; Sparkle 2 was added for native signed updates. Release scripts build a universal app, Developer ID sign nested code, notarize/staple the app and DMG, generate/verify an Ed25519-signed appcast, and produce checksums. The README and documentation explain installation, architecture, updates, and reproduction.

## 7. Cloudflare and custom domain

> Host the website on cloudflare.. lets create a domain for it like... getschnaps.com or something

**Result:** a buildless static marketing website with a labeled interactive measurement demo, download links, setup instructions, and a Cloudflare Workers Static Assets deployment configuration for `getschnaps.com`. Domain registration was completed by the owner; authentication and registrant details are not recorded here.

## Engineering checks used alongside the prompts

- Deterministic Swift tests cover geometry, color scanning, image orientation, Retina scaling, gaps, one-pixel features, and object snapping.
- Live native UI checks used known-size rectangles and gaps to verify measured dimensions and clipboard output.
- CI checks both legacy and modern macOS/Xcode packaging paths.
- Release validation checks universal architectures, nested signatures, Apple notarization/stapling, DMG integrity, and Sparkle signatures.

The app's implementation is Swift. The later update request explicitly introduces Sparkle's third-party framework; its license is bundled with releases. The website uses ordinary HTML, CSS, and JavaScript.

## 8. Quick tolerance adjustment

> Add tolerance slider to menubar for easy access.. also maybe while find dimensions is live.. up/down scroll wheel to change tolerance (enabled by default in setttings)

**Result:** native tolerance sliders in the menu-bar menu, overlay, and Measurement settings, with a shared persisted value. Vertical scrolling adjusts tolerance in Find Dimensions by default; a native settings toggle disables it. Held readings and snapped bounds respond immediately, while pinned and manual measurements stay fixed.
