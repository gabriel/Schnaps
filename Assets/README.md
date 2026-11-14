# Schnaps icon and logo

`Artwork/Schnaps-Liquid-Glass.png` is the approved transparent bottle with external blueprint measurement lines. [Artwork prompt](Artwork/Schnaps-Liquid-Glass.prompt.md).

Run `swift Scripts/export-icon.swift` with Xcode 26 or later to regenerate the assets:

- `Compiled/Assets.car`: Icon Composer catalog with Default, Dark and Mono appearances for system-owned app icon surfaces. macOS adds its required glass plate in these surfaces.
- `Compiled/Schnaps.icns` and `Schnaps-Dark.icns`: transparent light and dark app icons, 16–1024 px. The dark export deepens the glass midtones while preserving highlights and blueprint blue.
- `Compiled/Schnaps-Mark.icns` and `Schnaps-Mark-Dark.icns`: transparent marks for the running Dock icon and About. These follow the app/window appearance.
- `Previews/Schnaps.png`, `Schnaps-Dark.png`, the established preview filenames, and the website’s transparent logo and favicon.

`Schnaps.icon` is the editable Icon Composer document for surfaces that require a system icon container. App-controlled displays use the transparent bottle without that container. On all supported macOS versions, including macOS 26, the app sets its running Dock icon to the transparent mark and updates it when its effective appearance changes. Finder and other system-owned surfaces resolve the bundled icon themselves and may enforce a container. Finder on older macOS uses the default ICNS; that format does not automatically select light/dark renditions.

The compiled catalog is committed so app packaging works with both Xcode 16 and Xcode 26. Regenerate it when changing the Icon Composer document or source artwork. Both ICNS pairs and the catalog are included in every app build.

Earlier SVG artwork and the [integrated measurement exploration](Artwork/Schnaps-Liquid-Glass-Integrated.png) are retained as design sources and are not used by current exports.
