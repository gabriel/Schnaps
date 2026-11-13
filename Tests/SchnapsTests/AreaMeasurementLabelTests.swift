import Foundation
import Testing
@testable import Schnaps

@Test func selectedAreaLabelIsCenteredBelowTheRectangle() {
    let area = CGRect(x: 100, y: 100, width: 200, height: 150)
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    // Both modes share this layout; the snap icon reserves room below the text.
    for height: CGFloat in [28, 48] {
        let label = AreaMeasurementLabel.frame(for: area, size: CGSize(width: 120, height: height), in: bounds, avoiding: [])
        #expect(label.midX == area.midX)
        #expect(label.minY == area.maxY + 10)
    }
}

@Test func selectedAreaLabelFitsAtEdgesAndAvoidsExistingLabels() {
    let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
    let size = CGSize(width: 120, height: 48)
    for area in [CGRect(x: 0, y: 0, width: 20, height: 20),
                 CGRect(x: 700, y: 530, width: 100, height: 70)] {
        let label = AreaMeasurementLabel.frame(for: area, size: size, in: bounds, avoiding: [])
        #expect(bounds.insetBy(dx: 8, dy: 8).contains(label))
        #expect(!label.intersects(area))
        let other = AreaMeasurementLabel.frame(for: area, size: size, in: bounds, avoiding: [label])
        #expect(bounds.insetBy(dx: 8, dy: 8).contains(other))
        #expect(!label.insetBy(dx: -3, dy: -3).intersects(other))
    }
}
