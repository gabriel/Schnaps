# Schnaps website

A buildless static site at https://getschnaps.com, hosted on Cloudflare Workers Static Assets.

Preview from the repository root:

```sh
python3 -m http.server 5173 --directory website/dist
```

Deploy from `website/` with `npx wrangler deploy`, using the authenticated Cloudflare account. `wrangler.jsonc` retains the existing custom domain. No secrets are stored in the website source. The download points to the stable DMG alias on the latest GitHub release.

## Screenshot and branding

The screenshot is a direct capture of the running Schnaps app measuring and pinning regions over native macOS Calculator. It has only been cropped; the measurement UI is not redrawn or browser-generated. No video is loaded or published.

The cropped source window capture is `media-source/calculator.jpg`. Rebuild the screenshot with `swift Scripts/export-screenshot.swift`.

The logo is the transparent empty-bottle blueprint in `Assets/Artwork/Schnaps-Blueprint.svg`. `swift Scripts/export-icon.swift` updates the website SVG, transparent favicon, and app icon together.

## Appearance

The site follows the system color scheme by default. The Appearance selector offers System, Light, and Dark. Explicit choices persist locally; choosing System removes the override. The page still follows the system theme without JavaScript or local storage.
