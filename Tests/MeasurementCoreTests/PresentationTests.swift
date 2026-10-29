import Foundation
import Testing

@testable import MeasurementCore

@Test func clipboardFormatsRespectOrderAndRetinaCoordinates() {
    let rect = CGRect(x: 10, y: 20, width: 125.5, height: 42.25)
    var p = MeasurementPresentation(unit: .pixels, roundedPoints: false)
    #expect(p.clipboard(rect, scale: 2) == "251 px, 85 px")
    p.clipboardFormat = .heightWidth
    #expect(p.clipboard(rect, scale: 2) == "85 px, 251 px")
    p.showUnits = false
    #expect(p.clipboard(rect, scale: 2) == "85, 251")
    let expected: [(ClipboardFormat, String)] = [
        (.cssWidthFirst, "width: 125.5px; height: 42.25px;"),
        (.cssHeightFirst, "height: 42.25px; width: 125.5px;"),
        (.sassWidthFirst, "width: 125.5px\nheight: 42.25px"),
        (.sassHeightFirst, "height: 42.25px\nwidth: 125.5px"),
    ]
    for (format, string) in expected {
        p.clipboardFormat = format
        #expect(p.clipboard(rect, scale: 2) == string)
    }
    #expect(p.clipboard(rect, scale: 2, forceCSS: true) == expected[0].1)
}

@Test func presentationControlsRoundingUnitsAndIndicators() {
    let rect = CGRect(x: 0, y: 0, width: 10.6, height: 20.25)
    var p = MeasurementPresentation(roundedPoints: false, showUnits: false, showIndicators: true)
    #expect(p.label(rect, scale: 2) == "W 10.6 × H 20.25")
    #expect(p.distance(20.25, scale: 2, horizontal: false) == "H 20.25")
    p.roundedPoints = true
    p.showUnits = true
    #expect(p.label(rect, scale: 2) == "W 11 × H 20 pt")
    p.unit = .pixels
    #expect(p.label(rect, scale: 2) == "W 21 × H 41 px")
    #expect(MeasurementPresentation.number(100, rounded: false) == "100")
    #expect(MeasurementPresentation.number(-0.001, rounded: false) == "0")
}

@Test func aspectRatiosHandleCommonArbitraryPortraitAndInvalidSizes() {
    #expect(AspectRatioStyle.automatic.label(width: 1920, height: 1080) == "16:9")
    #expect(AspectRatioStyle.standard.label(width: 123, height: 77) == "123:77")
    #expect(AspectRatioStyle.reduced.label(width: 1920, height: 1080) == "1.78:1")
    #expect(AspectRatioStyle.commonOnly.label(width: 900, height: 1600) == "9:16")
    #expect(AspectRatioStyle.commonOnly.label(width: 137, height: 83) == nil)
    #expect(AspectRatioStyle.automatic.label(width: 137, height: 83) == "1.65:1")
    #expect(AspectRatioStyle.standard.label(width: 0, height: 1) == nil)
    #expect(AspectRatioStyle.standard.label(width: .infinity, height: 1) == nil)
}

@Test func distanceSnappingUsesNearestIntersectingGuideAndObjectEdges() {
    let dimensions = Dimensions(
        horizontal: DimensionSpan(start: CGPoint(x: 0, y: 50), end: CGPoint(x: 200, y: 50)),
        vertical: DimensionSpan(start: CGPoint(x: 100, y: 0), end: CGPoint(x: 100, y: 200)))
    let point = CGPoint(x: 100, y: 50)
    let guide = MeasurementSnapping.apply(
        dimensions, at: point, verticalGuides: [-10, 30, 80, 130, 250], horizontalGuides: [20, 90])
    #expect(guide.horizontal.start.x == 80)
    #expect(guide.horizontal.end.x == 130)
    #expect(guide.vertical.start.y == 20)
    #expect(guide.vertical.end.y == 90)
    let object = MeasurementSnapping.apply(
        dimensions, at: point,
        rectangles: [CGRect(x: 20, y: 10, width: 50, height: 80), CGRect(x: 150, y: 100, width: 20, height: 20)])
    #expect(object.horizontal.start.x == 70)
    #expect(object.horizontal.end.x == 200)
    #expect(object.vertical.length == 200)
    #expect(MeasurementSnapping.apply(dimensions, at: point).horizontal.length == 200)
}

@Test func screenshotPaddingClipsAndOptionTogglesIt() {
    let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
    let rect = CGRect(x: 5, y: 10, width: 80, height: 60)
    #expect(
        ScreenshotGeometry.region(rect, in: bounds, padding: 20, togglePadding: false)
            == CGRect(x: 0, y: 0, width: 105, height: 90))
    #expect(ScreenshotGeometry.region(rect, in: bounds, padding: 20, togglePadding: true) == rect)
    #expect(
        ScreenshotGeometry.region(rect, in: bounds, padding: 0, togglePadding: true)
            == CGRect(x: 0, y: 2, width: 93, height: 76))
    #expect(ScreenshotGeometry.region(rect, in: bounds, padding: 101, togglePadding: true) == rect)
    #expect(
        ScreenshotGeometry.pixelRect(
            CGRect(x: 0.25, y: 1.25, width: 10, height: 20), scaleX: 2, scaleY: 3,
            imageSize: CGSize(width: 100, height: 100)) == CGRect(x: 0, y: 3, width: 21, height: 61))
    #expect(
        ScreenshotGeometry.pixelRect(.null, scaleX: 2, scaleY: 2, imageSize: CGSize(width: 100, height: 100)).isNull)
}
