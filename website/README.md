# Schnaps website

A buildless static site at https://getschnaps.com, hosted on Cloudflare Workers Static Assets.

Preview from the repository root:

```sh
python3 -m http.server 5173 --directory website/dist
```

Deploy from `website/` with `npx wrangler deploy`, using the authenticated Cloudflare account. `wrangler.jsonc` retains the existing custom domain. No secrets are stored in the website source. The download goes through `/download`, which resolves the latest stable alias to a first-party immutable archive proxy. Actual first-party transfer starts are counted separately in the multi-app dashboard.

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

View visits, page views, and referrers in Cloudflare → Observability → Analytics → Web analytics → getschnaps.com. New macOS builds report app-scoped launch/version metadata as documented below. Website privacy copy distinguishes the website's cookie-free analytics from the app.

## Legacy redirect history (read-only)

Open [Schnaps download counts in Cloudflare D1 Studio](https://dash.cloudflare.com/6128bb221178e44c1d29224882a9dd77/workers/d1/databases/f63f4b6d-00e2-4210-a7a5-c742ccc3c1aa/studio). This uses your existing Cloudflare account login. These counters freeze when the multi-app transfer tracker is deployed; current stats are at `https://rel.me/dashboard?app=schnaps`. No public stats endpoint is exposed.

- `download_totals`: the `all` row is the total since tracking was enabled. Other rows show hero, footer, and direct-link starts; do not sum those with `all`.
- `download_daily`: counts by UTC date. Sort by `day` for the daily trend.

These historical counters counted GET requests to `/download`, not completed downloads, installs, or unique visitors. HEAD and prefetch/prerender requests are excluded; bots and repeat clicks can still count. GitHub release links, Sparkle updates, and downloads that bypass the website are not included. GitHub independently exposes per-asset download counts, including historical releases. No historical counts are backfilled into the website totals.

Only a fixed source category, UTC day, and aggregate counter are stored in D1. No IP, user agent, cookie, full URL, or referrer is stored by this counter. Download redirects are never cached. They are no longer written by the new Worker. The existing Web Analytics regional setting is unchanged; aggregate download counting runs on the server for all regions.

On a new environment, apply `npx wrangler d1 migrations apply schnaps-downloads --remote` before deploying. Test the handler with `node --test website/tests/downloads.test.mjs` from the repository root. The SQL counters use an atomic D1 batch to keep total, source, and daily counts consistent.

## Multi-app operations dashboard

The private dashboard at `https://rel.me/dashboard?app=schnaps` has an app selector,
with REL as its default. Schnaps uses its historical bundle ID
`com.gabrielhandford.Schnap` as the analytics namespace; do not rename that ID.
The apps never share installation IDs or counter rows.

`/appcast.xml` proxies the combined GitHub feed byte-for-byte, including its
signature. New builds use that first-party feed. Sparkle's supported pre-download
request callback routes known immutable Schnaps archive requests through
`/updates/artifacts/<tag>/<filename>`, leaving signed feed and archive bytes
unchanged. Arbitrary upstream URLs are rejected. Existing app versions and direct
GitHub downloads bypassing these routes cannot be attributed by this service.

The Worker classifies website/direct/updater transfer starts, app versions,
successful update check requests, and Debug traffic. HEAD, prefetch, failures,
and ranges resuming after byte zero do not create transfer events. Counts do
not prove completion or identify people. The older D1 redirect counters are preserved read-only at this cutover; a
one-time scoped historical import labels those distinctly. New redirects are
not counted, so only subsequent actual file starts enter the new counters.

New app builds POST one launch UUID, version, monotonic build number, runtime,
and a random installation UUID generated only in Schnaps's preferences domain.
The Worker hashes that UUID using the Schnaps app ID, schema, and runtime before
forwarding it. The raw installation ID never reaches the central dashboard.
No licensing, account, hardware, browser, screenshot, or inspected-text identity
is used. Removing the app's preferences resets the ID. Debug builds are excluded
from reporting entirely: the client sends nothing and the Worker discards any
Debug launch/check/download telemetry it receives. The first reported build is a baseline;
only later higher builds confirm upgrades. Missing/offline/older app reports
cannot be backfilled.

For your own Release install, set
`defaults write com.gabrielhandford.Schnap SchnapsAnalyticsExcluded -bool true`
and relaunch. This suppresses launch requests and adds only a non-identifying
`X-Analytics-Excluded: 1` boolean to Sparkle requests. The Worker still serves
signed feed/archive bytes but does not forward counters. Use
`https://getschnaps.com/analytics/exclude` to exclude future downloads from this
browser with a secure HttpOnly boolean cookie, with no visitor ID. The private
REL dashboard can exclude a Schnaps analytics installation UUID retrospectively
from launch/upgrade reports. Unique installs are app-scoped distinct hashes,
not distinct people; older anonymous file/check counts cannot be separated.

Forwarding uses the private `ANALYTICS` service binding to `rel-site`, avoiding
public Worker-to-Worker HTTP routing, and the Worker secret `ANALYTICS_FORWARDING_KEY`; the matching REL
secret is `SCHNAPS_ANALYTICS_KEY`. The key is fixed to Schnaps writes, grants no
reads and no REL writes, and never appears in browser or app code. Set both with
Wrangler's credential stdin. Delivery is bounded to five seconds, does not block
files/feed responses, logs only generic failures, and is idempotent by event ID.
There is no public statistics endpoint. Cloudflare Web Analytics injection and
its existing EU exclusion remain unchanged; no second beacon is installed.

Run `node --test website/tests/*.test.mjs`. Deploy the server receiver before
this Worker, after applying its additive app-scope migration. No app release or
signed feed publication is part of a website deployment.
