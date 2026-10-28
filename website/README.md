# Schnaps website

A buildless static website hosted on Cloudflare Workers Static Assets at https://getschnaps.com. The interactive browser demo is illustrative; the macOS app measures real screen content.

Preview: `python3 -m http.server 5173 --directory website/dist` from the repository root.

Deploy: `npx wrangler deploy` from `website/`, using your authenticated Cloudflare account. `wrangler.jsonc` declares the custom domain and static assets. Domain registration and DNS ownership must already be in the same Cloudflare account. There are no API keys or secrets in the website source.

The download buttons point at the stable `Schnaps.dmg` alias on the latest GitHub release. The release script generates this alias alongside the immutable versioned DMG used by Sparkle.
