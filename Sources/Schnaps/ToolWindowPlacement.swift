import Foundation

struct ToolWindowPlacement {
    let overlay: CGRect
    let content: CGRect

    /// Position the outer window frame below the palette, including the title bar.
    /// Shift the pair up only when the palette is too low to fit the content.
    static func below(overlay: CGRect, contentSize: CGSize, visibleFrame: CGRect,
                      gap: CGFloat = 8) -> Self {
        let spacing = min(gap, max(0, visibleFrame.height - overlay.height))
        let size = CGSize(width: min(contentSize.width, visibleFrame.width),
                          height: min(contentSize.height, max(0, visibleFrame.height - overlay.height - spacing)))
        var palette = overlay
        palette.origin.x = max(visibleFrame.minX, min(palette.minX, visibleFrame.maxX - palette.width))
        palette.origin.y = min(visibleFrame.maxY - palette.height,
                              max(palette.minY, visibleFrame.minY + size.height + spacing))
        let x = max(visibleFrame.minX, min(palette.midX - size.width / 2, visibleFrame.maxX - size.width))
        return Self(overlay: palette,
                    content: CGRect(x: x, y: palette.minY - spacing - size.height, width: size.width, height: size.height))
    }
}
