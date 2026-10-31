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

## Website design reference

> Can you make the website more like this design: https://designeer.xyz/finds/agusegui-2106459249773547798

**Result:** a paper-colored measurement canvas with thin blue floating utility windows, a custom outlined S with Bézier handles, monospace labels, and restrained motion. The existing interactive demo, downloads, installation guide, and documentation links remain available. The responsive layout reflows the windows on small screens; reduced-motion preferences disable the decorative animation.

## Simpler website and dark mode

> Simplify the design.. A LOT.. don't show fake UI... show it real in action. Add darkmode.

**Result:** removed the decorative window collage and JavaScript measurement simulation. The page now has a concise introduction, download, direct app captures with native playback controls, three brief feature descriptions, and collapsed practical details. The walkthrough shows the running Schnaps app measuring native Calculator controls, with the capture provenance documented in `website/README.md`. System, Light, and Dark appearances use CSS color schemes with an optional locally saved override.

## Static screenshot and transparent blueprint branding

> Don't do video just do screenshot. Make the icon an empty bottle being measured like a blueprint, with a clear background. Does making it macOS 15+ simplify the code? If so do it.

**Result:** replaced the video with a genuine app screenshot and removed the video export pipeline. Added a transparent vector empty-bottle mark with measurement arrows, shared by the website logo, favicon, and native ICNS. Removed Icon Composer's material backplate and SDK/host-specific packaging branches, and explicitly supplied the transparent artwork to AppKit and About. Retained macOS 14 support: the capture API already requires 14, there are no 14-only fallbacks, and raising the minimum to 15 would not remove compatibility code.

## Screenshot Retina scale

> The image example seems like it's 2x retina blown out.

**Result:** capped the 1344 × 576 pixel screenshot at its native 672 × 288 logical size, centered on desktop and scaling down on smaller screens. The full-resolution image remains intact for Retina sharpness.

## Theme icon and bright download button

> Change the light/dark mode select to an icon. Make the download button a bright color.

**Result:** replaced the dropdown with an accessible sun/moon button and kept locally saved appearance choices. The button follows the system theme before a manual override. The download uses a vivid blue with white text in both themes.

## Minimal measurement UI and named tolerance presets

> Fix tolerance in menubar.. should be Zero, Low, Medium, High choices. Remove the overlay on activation... just have the simplest UI... the user will use shortcuts to change stuff we don't need overlay buttons.

**Result:** native checked tolerance submenus and a matching settings picker replace sliders. Zero/Low/Medium/High map to 0/8/18/36. Scroll steps between these presets, while T / Shift-T cycles them. Saved slider values migrate to the nearest preset. The measurement canvas retains its rulers and selection handles but removes the toolbar, permanent hint banner, and screen tint. Only brief action/error feedback appears, with shortcuts documented in Settings.

## Mac design and inspection tools

> Add all the features from xscope that are missing.

When asked whether to include companion apps:

> All Mac tools first.

**Scope:** extend Schnaps’s existing Find Dimensions and Measure Area workflows with Mac design and inspection tools. iPhone and Apple Watch companion apps and remote pairing are deferred. This is an independent implementation, not a claim of complete xScope compatibility.

**Result:**

- **Rulers:** two independently scaled and rotated rulers, calipers, square extensions, fractional marks, length/angle synchronization, and edge snapping.
- **Guides and frames:** precise position and size fields, linked movement, locking, duplication, aspect ratios, grids, margins, gutters, baseline spacing, screenshot export, and saved JSON layouts.
- **Design overlays:** image/clipboard mockups with adjustable opacity, grids, window following, and optional Accessibility-based window resizing for breakpoint checks.
- **Screens:** editable screen presets, usable-area insets, keyboard areas, safe areas, approximate vision previews, and simulated 1× display rendering.
- **Loupe and Crosshair:** live magnification, pixel grid, sRGB color sampling, multiple color-code formats, contrast comparison, saved palettes, RGB ACO/JSON exchange, and relative-origin coordinates.
- **Text Inspector:** Unicode and Font Awesome search, explicit text encoding/decoding, normalization, glyph metrics, saved characters, native Find/Undo, and command-line conversion.
- **Content previews:** separate image/window and responsive WebKit windows, selected-window live capture, and full-page PNG/PDF export.

Screen Recording is requested for features that inspect screen pixels or enumerate windows. Ordinary marker placement does not require it. Accessibility is used only for explicitly resizing another app’s window. Proprietary Photoshop/Acorn document APIs are not included; file/window previews provide that workflow. See [design tools](design-tools.md) for shortcuts, permissions, export limits, and supported formats.

**Validation:** geometry, color math, text conversion, marker persistence, and export bounds have automated coverage. Native checks covered ruler editing, permission cancellation/approval, live Loupe, selected-window capture, cross-display attachment, responsive exports, native Find, and saved glyph fonts. The physical-mouse hover check was skipped at the user’s request.

## Move operational controls out of Settings

> For xscope features you need to add an overlay, not have them in the Settings UI right?

**Result:** moved operational controls into a native floating toolbar and expandable inspector using AppKit panels, standard toolbar buttons, and grouped forms. Text Inspector and content previews open in separate native windows. Settings keeps preferences, permissions, shortcuts, and About. Desktop marks stay click-through outside explicit editing; the measurement canvas remains minimal.

## Optional floating tool overlay

> ok do it... the overlay should be hidden by default, but if it is enabled (in the menubar) then it should stay up across restarts.. some people want overlay always present and some people don't use it

**Result:** added a checked **Tool Overlay** menu item. The toolbar is hidden by default; enabling it persists across restarts. Disabling it or closing its window keeps it hidden next time. Closing the toolbar leaves existing tool marks intact, and menus and shortcuts remain usable while it is hidden. During measurement, the inspector temporarily collapses; exiting measurement restores it.

**Validation:** checked enabled restart, close-and-restart opt-out, toolbar activation of tools, inspector restoration after measurement, and the separate Text Inspector window. All 41 Swift tests and both macOS CI builds passed for the implementation.

## Compact overlay without window chrome

> The overlay looks like a full window when it should be an overlay... I have Xscope installed you can use it as a comparison... the overlay should be a minimal window not with "chrome".

**Result:** compared the installed xScope toolbar and replaced Schnaps’s titled utility window with a compact, draggable icon strip. It uses native symbol buttons on system HUD material, without a title bar, traffic lights, or resize controls. The inspector opens in a separate native popover rather than expanding the toolbar into a full window. The menu toggle and hide button preserve the existing opt-in visibility behavior across restarts. When enabled, relaunch opens only the strip instead of also opening Settings.

## Editable global shortcuts

> Allow shortcuts to be edited.

**Result:** added native recording sheets for all 12 global measurement and design-tool shortcuts in Settings. Bindings can be cleared or reset to defaults, persist across restarts, and update menu equivalents immediately. Recording suspends global shortcuts; duplicate, reserved, and unavailable combinations are rejected. In-tool editing and measurement keys remain fixed and are listed separately.

## Escape dismisses tools one at a time

> I wonder if escape should be a way to undo the last thing.. and escape multiple times is more undo until everything is gone.

**Result:** Escape dismisses the most recently shown design marker, Loupe, or Crosshair. Repeated presses clear the screen in reverse appearance order; key repeat is ignored. Dismissed markers retain their geometry in the layout and can be restored from the inspector. Native popovers and other applications retain their own Escape behavior. Turning off Edit on Screen still leaves marks visible and click-through. This is dismissal history, not undo for geometry or text edits.

## Interacting with Text Inspector from the overlay

> I tapped text on the overlay and the window came up but I couldn’t interact with it.

**Result:** opening Text Inspector, Image & Window Preview, or Responsive Web Preview now ends on-screen marker editing before presenting the native window. Existing marks remain visible and click-through, so the editing canvas cannot intercept the new window’s clicks or keyboard input. The guard is in each window’s show method so menu and overlay entry points behave consistently.
