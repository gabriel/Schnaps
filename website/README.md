# Schnaps website

A buildless static site at https://getschnaps.com, hosted on Cloudflare Workers Static Assets.

Preview from the repository root:

```sh
python3 -m http.server 5173 --directory website/dist
```

Deploy from `website/` with `npx wrangler deploy`, using the authenticated Cloudflare account. `wrangler.jsonc` retains the existing custom domain. No secrets are stored in the website source. The download points to the stable DMG alias on the latest GitHub release.

## Demo and branding

The homepage animation renders the editorial drawing through the app’s unmodified `MeasurementView`, snapshot model, and edge detector. `Scripts/render-native-hover.swift` replays pointer movement, an area drag, and Space-to-pin directly into an offscreen native view. It does not launch or send input to another application. Every frame starts from the clean drawing source; no screen-capture cursor or cursor artwork is composited into the animation. High tolerance skips faint paper rules so both distance axes remain visible.

Run `swift Scripts/render-native-hover.swift` to regenerate all seven source frames. Then run `swift Scripts/export-drawing-demo.swift` to encode them using `website/media-source/drawing-frames/timeline.json`. The exporter only clears the edge-connected backdrop and encodes WebP; it does not draw measurement UI. The transparent animation and Find Dimensions poster remain 880 × 1040 px, displayed at no more than 400 CSS pixels wide. Pause/play, reduced-motion still behavior, and a no-JavaScript poster remain available. WebP tools (`img2webp`, `cwebp`) are required.

The clean drawing is `Assets/Previews/Schnaps-Drawing-Subject.png`, generated with `swift Scripts/export-illustrated-demo.swift --subject-only`. Earlier Calculator captures remain in `media-source/demo-frames/` as design sources for existing product media exports.

The logo is the approved transparent liquid-glass bottle in `Assets/Artwork/Schnaps-Liquid-Glass.png`. `swift Scripts/export-icon.swift` updates the website PNG, transparent favicon, and app icon together.

## Appearance

The site follows the system color scheme by default. The sun/moon icon button switches between light and dark, with an accessible action label and tooltip. Explicit choices persist locally. Before an override is chosen, the icon follows system appearance changes. The page still follows the system theme without JavaScript or local storage.

## Footer

The footer groups download, project, feedback, and rel.me links beneath a short app description. A fixed bottom credit bar names Gabriel Handford and links to his GitHub profile. The expanded navigation stays in normal page flow; reserved bottom space keeps the fixed credit bar clear of the final links. Columns collapse on smaller screens and share the site's light/dark colors.


## Web Analytics

Cloudflare Web Analytics is configured for `getschnaps.com` in the account dashboard. Automatic injection is enabled with EU visitors excluded; keep that existing regional setting when changing the integration. Do not embed a second manual beacon in the HTML.

The response CSP in `dist/_headers` permits scripts from `https://static.cloudflareinsights.com`, including Cloudflare's versioned beacon path. Reports use the same-origin `/cdn-cgi/rum` endpoint, so `connect-src` remains restricted to `'self'`. The normal local preview does not inject the analytics script. Test on the deployed hostname using a real browser; curl responses may omit automatic injection.

View visits, page views, and referrers in Cloudflare → Observability → Analytics → Web analytics → getschnaps.com. The macOS app itself has no analytics. Website privacy copy distinguishes the website's cookie-free analytics from the app.
