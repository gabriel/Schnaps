# Schnaps website

A buildless static site at https://getschnaps.com, hosted on Cloudflare Workers Static Assets.

Preview from the repository root:

```sh
python3 -m http.server 5173 --directory website/dist
```

Deploy from `website/` with `npx wrangler deploy`, using the authenticated Cloudflare account. `wrangler.jsonc` retains the existing custom domain. No secrets are stored in the website source. The download points to the stable DMG alias on the latest GitHub release.

## Demo and branding

The animated WebP shows the running Schnaps app measuring gaps and pinning a region over the small native macOS Calculator. Its frames are genuine cropped captures with only the plain, edge-connected backdrop removed; the measurement UI is not redrawn or browser-generated. No video player or animation library is loaded.

The demo uses genuine Calculator captures in `media-source/demo-frames/`, with frame timing in `timeline.json`. Run `swift Scripts/export-demo.swift` from the repository root to rebuild the animated WebP and static poster; the WebP command-line tools (`img2webp`) must be installed. The 720 × 912 px captures display at 360 × 456 CSS pixels, with responsive shrinking, a pause control, and a still image for reduced-motion preferences or disabled JavaScript.

The logo is the transparent empty-bottle blueprint in `Assets/Artwork/Schnaps-Blueprint.svg`. `swift Scripts/export-icon.swift` updates the website SVG, transparent favicon, and app icon together.

## Appearance

The site follows the system color scheme by default. The sun/moon icon button switches between light and dark, with an accessible action label and tooltip. Explicit choices persist locally. Before an override is chosen, the icon follows system appearance changes. The page still follows the system theme without JavaScript or local storage.
