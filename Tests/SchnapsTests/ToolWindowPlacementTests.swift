import Foundation
import Testing
@testable import Schnaps

@Test func textWindowOpensBelowPaletteWithoutMovingItWhenThereIsRoom() {
    let palette = CGRect(x: 400, y: 800, width: 448, height: 42)
    let placement = ToolWindowPlacement.below(overlay: palette, contentSize: CGSize(width: 680, height: 678),
                                              visibleFrame: CGRect(x: 0, y: 40, width: 1512, height: 910))
    #expect(placement.overlay == palette)
    #expect(placement.content.maxY == palette.minY - 8)
    #expect(placement.content.midX == palette.midX)
    #expect(!placement.content.intersects(palette))
}

@Test func lowPaletteMovesUpEnoughToKeepBothWindowsOnItsDisplay() {
    let screen = CGRect(x: -1920, y: -300, width: 1920, height: 1040)
    let palette = CGRect(x: -460, y: -250, width: 448, height: 42)
    let placement = ToolWindowPlacement.below(overlay: palette, contentSize: CGSize(width: 800, height: 900), visibleFrame: screen)
    #expect(screen.contains(placement.overlay))
    #expect(screen.contains(placement.content))
    #expect(placement.content.maxY == placement.overlay.minY - 8)
    #expect(placement.content.size == CGSize(width: 800, height: 900))
}

@Test func oversizedTextWindowFitsSmallDisplayWithoutCoveringPalette() {
    let screen = CGRect(x: 1600, y: 0, width: 800, height: 600)
    let placement = ToolWindowPlacement.below(overlay: CGRect(x: 1750, y: 20, width: 448, height: 42),
                                              contentSize: CGSize(width: 1200, height: 900), visibleFrame: screen)
    #expect(screen.contains(placement.content))
    #expect(screen.contains(placement.overlay))
    #expect(placement.content.width == 800)
    #expect(placement.content.height == 550)
    #expect(placement.content.maxY == placement.overlay.minY - 8)
}
