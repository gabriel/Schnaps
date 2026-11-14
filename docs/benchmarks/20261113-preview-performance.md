# Vision preview and pixel conversion benchmarks

Caching substantially reduces CPU in the measured repeated-render paths: **81% for grayscale screen previews, 87% for blur plus Retina resampling, and 88% for a stationary grayscale Loupe**. Moving pixel conversion off MainActor leaves conversion CPU approximately unchanged. It reduces median-trial p99 main-actor scheduling delay by about half in these tests, an absolute improvement of roughly 0.5–0.6 ms. It does not eliminate scheduling outliers.

These are isolated optimized-path benchmarks, **not measured reductions in whole-app CPU or end-to-end input latency**.

## Revisions and machine

- Baseline: `8cb182518dd10d3266090a7082ef7324545eb22f` (`origin/main` at measurement time).
- Candidate: `c1107e40ddb3623390f15dea62a19667dfbbf28e` (PR #83 runtime changes).
- Apple M2 Pro, 10 CPU cores, 32 GB RAM; macOS 26.7.1; Apple Swift 6.3.3; native arm64, `swiftc -O -swift-version 6`.
- Five trials per variant, run sequentially with alternating baseline/candidate order. Values below are medians across trials; ranges are the observed minimum–maximum trial values, not confidence intervals.
- [Raw measurements, source revisions, compiler version, and harness hash](20261113-preview-performance.json).

## Rendering CPU and wall time

Each trial performs 120 redraws. Frame identities change at a simulated 4 Hz relative to 30 Hz redraws: 16 fresh-frame events and 104 opportunities for reuse. The loop is unpaced to measure work rather than idle time. Both paths paint every output into the same-sized offscreen CGContext to force image realization and include common painting cost. Core Image is warmed before timing. Two deterministic 3840×2160 synthetic scenes provide distinct source identities without capturing private screen content.

Screen crops are 1200×1600 physical pixels. The Retina case downsamples to 600×800. The Loupe crop is 24×24, with a fixed pointer/crop. The miss control changes source identity on every redraw.

| Workload | main CPU ms | candidate CPU ms | CPU change | main wall ms | candidate wall ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Grayscale screen | 535.3 | 99.9 | −81.3% | 618.7 | 107.8 |
| Blur + Retina screen | 1129.5 | 146.7 | −87.0% | 1253.2 | 157.5 |
| Stationary grayscale Loupe | 29.1 | 3.6 | −87.6% | 42.9 | 4.9 |
| Every render misses cache | 536.7 | 507.6 | −5.4%, inconclusive | 609.0 | 571.8 |

The repeated-render CPU improvements are large relative to run variation: grayscale CPU ranges are 504.4–551.0 ms versus 96.8–103.3 ms; blur + Retina 1069.6–1216.5 ms versus 146.0–156.5 ms. The miss-control ranges overlap (496.1–671.8 ms versus 485.0–534.3 ms); do not interpret that median difference as a cache-miss speedup. Moving the Loupe or changing crop/settings reduces reuse. Oversized or frequently evicted renders will also benefit less.

## Pixel conversion CPU

A separate unpaced block performs 60 full-image conversions per trial with no heartbeat probe. It retains the latest snapshot during the next conversion, as the app does. Both variants use their actual `PixelBuffer(image:)` source; the candidate uses its actual detached conversion helper. Checksums agree across all variants/trials. Image generation and warm-up are outside timing.

| Image | main CPU ms / 60 conversions | candidate CPU ms / 60 conversions | Change |
| --- | ---: | ---: | ---: |
| 3840×2160 | 91.6 | 93.5 | +2.1% |
| 5120×2880 | 165.2 | 166.2 | +0.6% |

This is approximately 1.53→1.56 ms of CPU per 4K conversion and 2.75→2.77 ms per 5K conversion. The work still has to be done; offloading primarily changes which executor is occupied. CPU ranges overlap: 4K 89.5–93.5 / 91.3–96.0 ms; 5K 161.1–176.8 / 162.6–232.7 ms. There is no demonstrated conversion CPU saving.

## Main-actor responsiveness

A separate three-second block converts 12 images at four conversions per second. A detached producer waits 2 ms between probes, records the request time, then awaits `MainActor.run`. Delay is time from request to service; it excludes the producer's timer wake-up lateness. This measures access to MainActor while conversion runs, not AppKit mouse-to-paint latency.

| Image | main p99 service delay | candidate p99 service delay | Relative change | main / candidate median conversion completion latency |
| --- | ---: | ---: | ---: | ---: |
| 3840×2160 | 0.94 ms | 0.45 ms | −52.6% | 1.68 / 1.56 ms |
| 5120×2880 | 1.06 ms | 0.47 ms | −55.8% | 2.73 / 3.05 ms |

These are medians of each trial's empirical p99, not pooled percentiles. The absolute p99 improvement is about 0.50 ms at 4K and 0.59 ms at 5K. Conversion completion itself is not consistently faster; scheduling the worker can add latency.

Worst-case scheduling remains noisy. Trial maxima range from 2.28–6.88 ms on main versus 1.42–36.04 ms on the candidate at 4K, and 5.20–27.97 versus 1.38–25.84 ms at 5K. Median-trial maxima are 3.67→3.80 ms and 6.10→3.90 ms respectively. Thus this run supports better typical tail access to MainActor, **not a guaranteed improvement in worst-case latency or elimination of missed frames**. Median counts of probes exceeding 8.33 or 16.67 ms are zero for both variants.

The instrumented paced blocks consume about 11–12% more aggregate process CPU on the candidate (about 9–10 ms extra over three seconds). Those totals include the probe and scheduling work; they are separate from the conversion-only CPU numbers above and show no CPU saving from offloading.

## Scope and limitations

The harness compiles the actual MeasurementCore conversion, ScreenSnapshot, VisionRenderer, and candidate VisionPreviewCache sources from the pinned revisions. The baseline adapter mirrors main's synchronous conversion and DesignCanvas crop/filter/resampling sequence; the script rejects baselines that no longer match that implementation. Cache lookup, rendering, and offloading use production code. Existing regression tests cover per-mode pixel equivalence.

ScreenCaptureKit capture/enumeration, full NSView drawing, AppKit event dispatch, display presentation, multiple displays, GPU utilization, power use, and total app CPU are not measured. Rendering process CPU excludes GPU/WindowServer CPU, while synchronous rendering wall time includes waits. There was no exclusive-machine or thermal isolation; raw ranges and outliers are retained. No sustained full-app or Instruments responsiveness measurement was performed.

## Reproduce

From the repository root on a Mac with Xcode:

```sh
python3 Scripts/benchmark-preview-performance.py \
  --baseline 8cb182518dd10d3266090a7082ef7324545eb22f \
  --candidate c1107e40ddb3623390f15dea62a19667dfbbf28e \
  --trials 5 \
  --output /tmp/schnaps-preview-performance.json
```

The runner builds both variants into a temporary directory and removes the binaries afterward. It does not change checkouts, launch Schnaps, or need screen-recording permission. Harness: `Scripts/Benchmarks/preview-performance.swift`; runner: `Scripts/benchmark-preview-performance.py`.
