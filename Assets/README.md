# Schnaps icon and logo

`Artwork/Schnaps-Blueprint.svg` is the canonical vector source: an empty bottle outline with a centerline, construction marks, and horizontal/vertical dimension arrows. It has no fill, backplate, liquid, or lettering. The background is transparent.

`swift Scripts/export-icon.swift` uses AppKit and iconutil to generate:

- `Compiled/Schnaps.icns`: transparent 16–1024 px macOS icon representations.
- `Previews/`: transparent color and monochrome PNG previews.
- `website/dist/assets/logo.svg`: the vector website logo.
- `website/dist/assets/icon.png`: the transparent favicon and social image.

The app packages the ICNS directly on every supported macOS version. Icon Composer's adaptive rendering adds a system backplate even for a clear document fill, so it is intentionally no longer part of the packaging path. This preserves the requested unboxed bottle silhouette and removes the SDK/host-version icon branches. AppKit and the About panel explicitly load this raw artwork to avoid Icon Services adding a legacy backplate.

The new mark is drawn as vector geometry. Design brief:

> Make the icon an empty bottle being measured like a blueprint. Make the logo have a clear background; no rounded rectangle background.
