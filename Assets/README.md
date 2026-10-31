# Schnaps icon and logo

`Artwork/Schnaps-Liquid-Glass.png` is the approved transparent bottle with external blueprint measurement lines. [Artwork prompt](Artwork/Schnaps-Liquid-Glass.prompt.md).

Run `swift Scripts/export-icon.swift` with Xcode 26 or later to regenerate the assets:

- `Compiled/Assets.car`: Icon Composer catalog with Default, Dark and Mono appearances for macOS 26. macOS supplies the appearance-specific glass plate; the transparent bottle sits inside its safe area.
- `Compiled/Schnaps.icns` and `Schnaps-Dark.icns`: transparent light and dark app icons, 16–1024 px. The dark export deepens the glass midtones while preserving highlights and blueprint blue.
- `Compiled/Schnaps-Mark.icns` and `Schnaps-Mark-Dark.icns`: transparent About marks that follow the settings window’s appearance.
- `Previews/Schnaps.png`, `Schnaps-Dark.png`, the established preview filenames, and the website’s transparent logo and favicon.

`Schnaps.icon` is the editable Icon Composer document. On macOS 26 the Dock uses the system’s Icon Composer selection, including the user’s icon style. The process-local application image used by Sparkle and native panels is refreshed from bundled light/dark ICNS artwork so stale Launch Services registrations cannot supply an older icon. On macOS 14–15 it updates its running Dock icon when the app’s effective appearance changes. Finder on older macOS uses the default ICNS; that format does not automatically select light/dark renditions.

The compiled catalog is committed so app packaging works with both Xcode 16 and Xcode 26. Regenerate it when changing the Icon Composer document or source artwork. Both ICNS pairs and the catalog are included in every app build.

Earlier SVG artwork and the [integrated measurement exploration](Artwork/Schnaps-Liquid-Glass-Integrated.png) are retained as design sources and are not used by current exports.
