# Product Hunt media

Run `swift Scripts/export-product-hunt.swift` from the repository root to regenerate the 1270 × 760 gallery and 240 × 240 thumbnail.

The gallery uploads are `01-demo.gif`, `02-find-dimensions.png`, and `03-pin-and-copy.png`, in that order. `01-overview.png` is a static alternative to the animation. The GIF loops through the homepage workflow, beginning with visible horizontal and vertical Find Dimensions axes.

`Source/Frames/` and `Source/timeline.json` preserve the homepage animation states. The live hover frames render Schnaps’s unmodified measurement view and edge detector; area resizing and pinning frames are actual app captures. `Source/overview.png`, `hover.png`, and `pin.png` provide the still exports. No measurement UI is drawn by this gallery exporter.
