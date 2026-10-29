# Schnaps icon and logo

`Artwork/Schnaps-Dock.png` is the app icon: an empty petrol-blue optical glass bottle, satin metal stopper, and fine measurement rails on a graphite tile. It is used in the Dock and Finder. The earlier SVG is retained as a design reference.

`Schnaps.icon` is the editable Icon Composer document, with a transparent fill and material effects disabled to preserve the rendered artwork. It can be opened in Apple Icon Composer. The app continues to package the ICNS for compatibility across supported macOS versions.

`Artwork/Schnaps-Blueprint.svg` is the transparent outline mark used in About and on the website.

Run `swift Scripts/export-icon.swift` to regenerate:

- `Compiled/Schnaps.icns`: sculptural glass app icon, 16–1024 px.
- `Compiled/Schnaps-Mark.icns`: transparent About mark, 16–1024 px.
- `Previews/Schnaps-Dock.png`: filled app icon preview.
- Other `Previews/` images: transparent color and monochrome marks.
- `website/dist/assets/logo.svg` and `icon.png`: transparent website branding.

The Swift packaging script includes both ICNS files on every supported macOS version. AppKit installs the filled icon; About loads the separate transparent mark.
