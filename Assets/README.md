# Schnaps icon and logo

`Artwork/Schnaps-Liquid-Glass.png` is the approved artwork: an empty liquid-glass bottle with external blueprint measurement lines on a genuinely transparent background. The app icon, About mark, website logo, and favicon all use it. [The built-in image-generation prompt](Artwork/Schnaps-Liquid-Glass.prompt.md) is included.

Run `swift Scripts/export-icon.swift` to regenerate:

- `Compiled/Schnaps.icns`: transparent app icon, 16–1024 px.
- `Compiled/Schnaps-Mark.icns`: transparent About mark, 16–1024 px.
- `Previews/Schnaps-Dock.png` and other established preview filenames.
- `website/dist/assets/logo.png` and `icon.png`.

The editable Icon Composer document is `Schnaps.icon`. Its source image preserves the original alpha channel, with no background fill or additional glass effects baked over the rendered bottle. The Swift packaging script includes both ICNS files on every supported macOS version; AppKit uses the app icon and About loads the separate mark resource.

Earlier SVG artwork and the [integrated measurement exploration](Artwork/Schnaps-Liquid-Glass-Integrated.png) are retained as design sources. They are not used by the current exports. [Integrated exploration prompt](Artwork/Schnaps-Liquid-Glass-Integrated.prompt.md).
