# Schnaps icon

- `Schnaps.icon/`: editable Apple Icon Composer document. Open in Icon Composer to preview material, lighting, and Default/Dark/Mono appearances.
- `Artwork/Schnapps-Bottle.png`: original transparent bottle-only foreground.
- `Previews/`: rendered macOS appearance previews.
- `Compiled/Schnaps.icns`: full legacy representation set from 16px through 1024px, exported from the same design.

The foreground sits centered at 76% scale over a deep petrol-blue automatic gradient. Foreground glass effects are disabled to retain the rendered crystal and warm schnapps; the system icon background supplies the native material treatment. There is no shot glass, lettering, or label.

Run `swift Scripts/export-icon.swift` with Icon Composer selected through Xcode to regenerate exports. `swift Scripts/build-app.swift` compiles adaptive icon assets using Xcode 26 and packages the ICNS fallback on older toolchains.

Artwork was made with the built-in image generation tool, then composed and reviewed in Apple Icon Composer. Final edit prompt:

> Edit target: this transparent schnapps bottle and shot-glass illustration for the native macOS app Schnaps. Remove the shot glass completely and reconstruct the bottle behind it naturally. The finished artwork must contain ONLY ONE schnapps bottle, no glass and no other objects. Preserve the beautiful rounded-shoulder bottle design, brushed silver stopper, warm golden schnapps, realistic sculpted crystal edges and premium soft studio lighting from upper left. Recompose the entire bottle centered in a square genuinely transparent canvas, with balanced generous margins: bottle about 78% of canvas height and approximately 48-54% of canvas width. Full bottle visible from stopper to thick glass base. Premium polished Apple macOS app icon object illustration, excellent readability at small sizes. No background, no tile, no shadow outside the bottle, no words, no labels, no branding, no watermark. Keep transparency.
