# Schnaps website

A buildless static site at https://getschnaps.com, hosted on Cloudflare Workers Static Assets.

Preview from the repository root:

```sh
python3 -m http.server 5173 --directory website/dist
```

Deploy from `website/` with `npx wrangler deploy`, using the authenticated Cloudflare account. `wrangler.jsonc` retains the existing custom domain. No secrets are stored in the website source. The download points to the stable DMG alias on the latest GitHub release.

## App walkthrough

The poster and 14-second walkthrough use direct screen captures of the running Schnaps app over native macOS Calculator. Find Dimensions detects a 120 × 96 px button; the subsequent captures show pinning, a gap reading, and exact area selections. These are actual measurements and app rendering, rather than drawn or browser-generated overlays. The captures are cropped to Calculator and held for two seconds per step for readability; this is an edited sequence, not a continuous recording. No surrounding desktop or other applications are published.

The cropped originals are in `media-source/`. Rebuild the H.264 video and poster using Apple's native frameworks:

```sh
swift Scripts/export-demo.swift
```

Playback starts only when requested, using native video controls. The visual description is available to screen readers.

## Appearance

The site follows the system color scheme by default. The Appearance selector offers System, Light, and Dark. Explicit choices persist locally; choosing System removes the override. The page still follows the system theme without JavaScript or local storage.
