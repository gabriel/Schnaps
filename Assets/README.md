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

## Liquid glass and blueprint design

[Transparent PNG](Artwork/Schnaps-Liquid-Glass.png) combines an empty optical-glass bottle with blueprint dimension rails. It is a separate design asset, generated with the built-in image tool; [the full prompt](Artwork/Schnaps-Liquid-Glass.prompt.md) is included. The original alpha channel is preserved. Existing app and website icon exports remain unchanged.

[Integrated measurement design](Artwork/Schnaps-Liquid-Glass-Integrated.png) embeds sapphire-blue dimension marks into the bottle glass and base. [Its generation prompt](Artwork/Schnaps-Liquid-Glass-Integrated.prompt.md) records the material and construction details. This version also preserves transparent alpha.
