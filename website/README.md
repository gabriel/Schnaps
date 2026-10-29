# Schnaps website

A buildless static site at https://getschnaps.com, hosted on Cloudflare Workers Static Assets.

Preview from the repository root:

```sh
python3 -m http.server 5173 --directory website/dist
```

Deploy from `website/` with `npx wrangler deploy`, using the authenticated Cloudflare account. `wrangler.jsonc` retains the existing custom domain. No secrets are stored in the website source. The download points to the stable DMG alias on the latest GitHub release.

## Demo and branding

The homepage animation combines native Schnaps hover renders with genuine Schnaps 0.6.2 captures over an editorial drawing. Hover frames use the app’s unmodified `MeasurementView`, snapshot model, and edge detector, rendered offscreen by `Scripts/render-native-hover.swift`; High tolerance skips faint paper rules so both axes are visible. The area resizing and pinning frames are app captures. The encoder only removes the edge-connected desktop backdrop. No video player or animation library is loaded.

Run `swift Scripts/render-native-hover.swift` to regenerate the live hover frames from the app source. Then run `swift Scripts/export-drawing-demo.swift` from the repository root to encode the cropped captures in `website/media-source/drawing-frames/` using `timeline.json`. The animation and live Find Dimensions poster are transparent 880 × 1040 px WebPs displayed at no more than 400 CSS pixels wide. Pause/play, reduced-motion still behavior, and a no-JavaScript poster remain available. WebP tools (`img2webp`, `cwebp`) are required.

The drawing source is `Assets/Previews/Schnaps-Drawing-Subject.png`, generated with `swift Scripts/export-illustrated-demo.swift --subject-only`. The earlier illustrated walkthrough and its exporter are retained as design source, but the homepage uses real app captures.

The earlier genuine Calculator captures remain in `media-source/demo-frames/` with `Scripts/export-demo.swift`. Their original WebP assets are retained as inputs for existing product media exports.

The logo is the approved transparent liquid-glass bottle in `Assets/Artwork/Schnaps-Liquid-Glass.png`. `swift Scripts/export-icon.swift` updates the website PNG, transparent favicon, and app icon together.

## Appearance

The site follows the system color scheme by default. The sun/moon icon button switches between light and dark, with an accessible action label and tooltip. Explicit choices persist locally. Before an override is chosen, the icon follows system appearance changes. The page still follows the system theme without JavaScript or local storage.
