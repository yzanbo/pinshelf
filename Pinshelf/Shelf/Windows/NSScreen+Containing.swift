import AppKit

extension NSScreen {
    /// その点を含む画面（なければメインの画面）
    static func containing(_ point: CGPoint) -> NSScreen? {
        screens.first { NSMouseInRect(point, $0.frame, false) } ?? main
    }
}
