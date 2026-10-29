# Schnaps website

A buildless static site at https://getschnaps.com, hosted on Cloudflare Workers Static Assets.

Preview from the repository root:

```sh
python3 -m http.server 5173 --directory website/dist
```

Deploy from `website/` with `npx wrangler deploy`, using the authenticated Cloudflare account. `wrangler.jsonc` retains the existing custom domain. No secrets are stored in the website source. The download points to the stable DMG alias on the latest GitHub release.

## Demo and branding

The homepage uses an illustrated feature walkthrough over an editorial sketchbook: oversized script lettering, ruled paper, sparse hipster placeholder copy, and handwritten coral measurement notes. The static poster combines spacing, a selected region, pinned dimensions, and CSS copying. The animation introduces the same actions in sequence. This is an illustration of the workflow, not a live app capture. No video player or animation library is loaded.

Run `swift Scripts/export-illustrated-demo.swift` from the repository root to regenerate the transparent 880 × 1040 px animated WebP, static WebP poster, and `Assets/Previews/Schnaps-Layout-Demo.png`. The WebP command-line tools (`img2webp`, `cwebp`) must be installed. SwiftUI draws the fictional subject and the illustrated measurement states from the same coordinates. The artwork displays at no more than 400 CSS pixels wide, with responsive shrinking, a pause control, and the complete still image for reduced-motion preferences or disabled JavaScript.

The earlier genuine Calculator captures remain in `media-source/demo-frames/` with `Scripts/export-demo.swift`. Their original WebP assets are retained as inputs for existing product media exports.

The logo is the transparent empty-bottle blueprint in `Assets/Artwork/Schnaps-Blueprint.svg`. `swift Scripts/export-icon.swift` updates the website SVG, transparent favicon, and app icon together.

## Appearance

The site follows the system color scheme by default. The sun/moon icon button switches between light and dark, with an accessible action label and tooltip. Explicit choices persist locally. Before an override is chosen, the icon follows system appearance changes. The page still follows the system theme without JavaScript or local storage.
