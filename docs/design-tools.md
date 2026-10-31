# Mac design tools

Use **Schnaps → Design Tools** in the menu bar or enable **Tool Overlay** for a compact, titleless floating toolbar. It is hidden by default. Enabling it persists across app restarts and opens just the toolbar at launch; disabling it or closing its window keeps it hidden next time. Tool shortcuts work independently of this preference. Drag the grip to move it; the × button hides it. The inspector button opens standard macOS controls in a popover for the active tool; **Tool Inspector…** opens it directly. Closing the toolbar leaves existing tool marks intact. Settings contains preferences rather than operational controls. Find Dimensions and Measure Area keep their existing shortcuts and interaction.

## Shortcuts

Global shortcuts below are defaults. Change or clear each one in **Settings → Shortcuts**. Edits apply immediately and persist across restarts; **Restore Default Shortcuts** resets all global bindings. Duplicate bindings and unavailable combinations are rejected. On-screen editing keys remain fixed.

| Tool or action | Global shortcut |
| --- | --- |
| Add ruler (up to two) | Control-Command-R |
| Add guide | Control-Command-G |
| Add frame | Control-Command-B |
| Add design overlay | Control-Command-O |
| Add screen template | Control-Command-S |
| Toggle Loupe | Control-Command-L |
| Toggle Crosshair | Control-Command-X |
| Enter/leave on-screen editing | Control-Command-E |
| Hide design tools | Control-Command-H |
| Copy sampled color | Control-Command-C |

While editing: drag to move, Option-drag to duplicate, drag a rectangle's bottom-right corner to resize, or drag a ruler's endpoint to set length and angle. Shift constrains ruler angles to 45° increments. Control snaps the pointer to detected edges when Screen Recording is allowed. Arrows nudge one logical point; Shift-Arrows nudge ten. Option-Arrows rotate a ruler 1°, Shift-Option-Arrows 5°, and Control-Option-Arrows 0.1°. Delete removes the selected marker. H/V/F select the next horizontal guide, vertical guide, or frame. Escape keeps markers visible and makes the windows click-through.

## Rulers, guides, and frames

Two rulers have independent position, length, scale, angle, calipers, square extensions, and quarter/third/half/golden-ratio marks. Length and angle synchronization are independent. Native numeric fields accept precise values. Ruler labels use the existing points/display-pixels preference; dimensions in the inspector are logical points.

Guides span the selected display and label their coordinates and distance to the next parallel guide. Frames expose origin, size, aspect ratio, center marks, rows/columns, margins, gutters, and baseline spacing. Matching guides or frames can move together. Markers can be shown/hidden individually, locked for on-screen editing, duplicated, centered, assigned to any connected display, and copied/saved as screenshots. Capture uses the existing export preferences and excludes Schnaps's marks.

Layouts persist across launches, but start hidden. Save/load layouts as JSON for separate projects. A layout contains geometry, colors, and grids; imported layouts detach transient window IDs and omit mockup-image references. If an imported display is absent, markers use the main display. Mockup images are copied to Application Support when selected so reopening the app does not require the original file to remain in place.

## Design overlays and responsive preview

An overlay combines a transparent mockup image (file or image clipboard), adjustable opacity, a column grid, baseline grid, and alignment marks. **Refresh Windows** lists external windows; **Follow window** keeps the overlay aligned as that window moves or resizes. Screen Recording is required to enumerate and follow windows. Window IDs detach across app launches.

Apply/Next Breakpoint changes an independent overlay's width. For an attached window it changes the outer window width through macOS Accessibility, when the target supports resizing. This is window width including browser chrome, not an assertion about CSS viewport width. Accessibility access is requested only when resizing another app, and ambiguous windows are not changed.

**Responsive Web Preview** opens a separate WebKit window with an exact logical viewport width, breakpoint choices, and optional grid. Open a website to test layout and export the full document as PDF or PNG. PNG is limited to 32 megapixels, 16,000 pixels wide, and 32,000 pixels high; larger pages can be saved as PDF. WebKit uses a nonpersistent website data store. This preview does not share Chrome/Safari cookies, control their tabs, or bypass website restrictions. Network requests go to the site you open. PNG stitches viewport snapshots to preserve screen compositing, temporarily making fixed/sticky elements scroll with the document and restoring their styles and the scroll position afterward. PDF uses WebKit’s native document renderer; some CSS compositing/filter effects differ from the screen. Dynamic/infinite-scroll content and video may not appear in an export.

## Screen templates and Crosshair

Screens includes phone, tablet, laptop, desktop, TV, watch, and social-asset logical-size presets. Width, height, orientation, top/bottom/side usable-area insets, and keyboard height are editable. TV action/title-safe areas use 5%/10% insets. Platform chrome changes between OS/browser versions, so insets are editable rather than presented as exact universal device specifications.

Screens and Loupe offer approximate protanopia, deuteranopia, tritanopia, grayscale, and blurred-vision previews. These are design aids, not clinical simulations. Screens can downsample a Retina capture to simulate a 1× display. Live previews require Screen Recording.

Crosshair follows the pointer, reports coordinates from each display's top-left, and supports an arbitrary relative origin. While editing, click or press O to set the origin; R resets it. Relative origins remain correct across displays. Line width is adjustable; automatic contrast uses the existing preference and captured pixels when available.

## Loupe and palettes

Loupe magnifies the pointer's physical pixels with a grid and centerlines. Color samples are converted to sRGB before formatting. Available formats: hex, short hex when exact, RGB, HSL, HSB, Lab D65, AppKit, SwiftUI, and UIColor. The reference format can differ from the primary format. Set a contrast reference to compare relative luminance; the displayed ratio follows the WCAG sRGB formula. Space pins the sample position while editing. C copies the value; Shift-C saves a swatch.

Saved colors persist, support JSON and named RGB Adobe ACO export, and can be imported from either format. Non-RGB ACO records are rejected with a conversion message. Palette clearing asks for confirmation.

## Text

Text converts plain strings, HTML entities, percent-encoded URLs, C escapes, UTF-8 hex bytes, NSData-style bytes, and Unicode code-point/name lines. Decoding is explicit and does not execute input. HTML named references come from the WHATWG entity table; numeric references cover Unicode scalars. Invalid UTF-8, malformed escapes, and invalid code points report errors. A Windows-1252/UTF-8 repair action handles common mojibake.

Search Unicode by name, pasted character, U+code, or a range such as `U+0300..U+036F`. Search runs off the main thread and cancels when the query changes. Results use the Unicode version shipped with macOS; the first 200 matches are retained and 60 shown. The character inspector shows names, general category, UTF-8 bytes, UTF-16 units, and canonical/compatibility normalization. A persistent character palette collects favorites. Installed fonts can be selected to inspect advance, ascent/descent, leading, cap/x-height, and a CSS line-height estimate for the first input line. Input, results, font, and conversion format remain in memory when closing and reopening the separate Text Inspector window; they are not saved to disk. Text editors use native undo/redo, clipboard actions, and Find/Find Next/Find Previous commands (Command-F, Command-G, Shift-Command-G). Saved palette entries retain their font family for icon-font glyphs.

Command-line conversion works without opening windows:

```sh
/Applications/Schnaps.app/Contents/MacOS/Schnaps --convert html 'A & B'
printf '%%F0%%9F%%98%%80' | /Applications/Schnaps.app/Contents/MacOS/Schnaps --convert url --decode
```

Formats: `plain`, `html`, `url`, `c`, `bytes`, `nsdata`, `names`. With no text argument, stdin is read. Failed decoding exits 1; invalid arguments exit 2.

## Image and window preview

Open an image/PDF, paste an image, or select a Mac window. Live mode refreshes a file, image clipboard, or chosen window; window sources stay selected even when another window becomes frontmost. Move the preview onto any connected display (including a display connected through macOS AirPlay). Closing the preview stops capture and releases a window snapshot.

The Mac-first scope does not include an iOS/watchOS receiver, remote pairing/server, Apple Watch transfer, AirPlay session management, or proprietary Photoshop/Acorn document APIs. Preview those apps' windows or their exported files instead. Font Awesome 4.7 is bundled for icon-font inspection; search `fa-heart` or select FontAwesome and search icon names. The unmodified font and 786 CSS names/aliases have their original OFL/MIT licenses included in the app. Installed fonts remain selectable. This is an independently implemented toolset, not a claim of complete compatibility with xScope's companion apps, templates, or file formats.

Feature reference: [xScope tool guide](https://xscopeapp.com/guide) and [feature list](https://xscopeapp.com/features). No xScope application code, interface assets, or templates are included.
