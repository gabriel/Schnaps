# Schnaps icon and logo

`Artwork/Schnaps-Dock.svg` is the filled blue glass bottle on a light rounded tile, with measurement arrows. It is used for the app icon in the Dock and Finder.

`Artwork/Schnaps-Blueprint.svg` is the transparent outline mark used in About and on the website.

Run `swift Scripts/export-icon.swift` to regenerate:

- `Compiled/Schnaps.icns`: filled app icon, 16–1024 px.
- `Compiled/Schnaps-Mark.icns`: transparent About mark, 16–1024 px.
- `Previews/Schnaps-Dock.png`: filled app icon preview.
- Other `Previews/` images: transparent color and monochrome marks.
- `website/dist/assets/logo.svg` and `icon.png`: transparent website branding.

The Swift packaging script includes both ICNS files on every supported macOS version. AppKit installs the filled icon; About loads the separate transparent mark.
