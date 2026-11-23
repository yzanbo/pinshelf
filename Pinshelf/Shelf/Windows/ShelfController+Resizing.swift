import AppKit
import PinshelfCore
import SwiftUI

/// 縁で大きさを変える・標準の大きさ
extension ShelfController {
    // MARK: - 大きさを変える

    /// 縁をつかんだ
    func beginResize() {
        guard !state.isFolded else { return }
        resizeStartFrame = moveTracker.restingFrame
        state.isResizing = true
    }

    /// つかんだ縁を運んだ（つかみ始めてから delta だけ動いた。反対側の辺は動かさない）
    func resize(handle: ResizeHandle, by delta: CGVector) {
        guard let start = resizeStartFrame,
              let visible = resizeScreen(for: start)?.visibleFrame
        else { return }
        let frame = ShelfSizing.resized(start, handle: handle, by: delta, within: visible)
        if state.hoveredResizeHandle != handle {
            state.hoveredResizeHandle = handle
        }
        state.size = frame.size
        if state.isDocked {
            // しまった棚は、開いた棚の真ん中に帯を置き直す（帯にたたんだとき、棚の真ん中の高さに帯が残る）
            dockCenterY = frame.midY
        }
        // 自分で動かした枠なので、利用者が運んだとは数えない（端まで広げても、しまわない）
        setPanelFrame(frame, animated: false)
    }

    /// ポインタが棚の上で動いた（棚の外へ出たら nil）: 乗せている縁を光らせ、出すポインタの形を返す
    ///
    /// 帯だけのときは、縁はない。つかんでいる間は、つかんだ縁を光らせたままにする。
    func pointerMoved(to point: CGPoint?, in size: CGSize) -> NSCursor? {
        let handle = point.flatMap { point -> ResizeHandle? in
            guard !state.isFolded else { return nil }
            return ResizeHandle.handle(at: point, in: size, among: ResizeHandle.available(dockedEdge: state.dockedEdge))
        }
        if !state.isResizing, state.hoveredResizeHandle != handle {
            state.hoveredResizeHandle = handle
        }
        return handle.map { handle in
            // いちばん小さい・大きいときは、変えられる向きの矢印だけにする
            let directions = ShelfSizing.resizeDirections(for: handle, size: state.size)
            return NSCursor.frameResize(position: handle.cursorPosition, directions: directions.cursorDirections)
        }
    }

    /// 大きさを変えるときに収める画面（しまった棚はしまった画面。浮いた棚は、いちばん重なっている画面）
    private func resizeScreen(for frame: CGRect) -> NSScreen? {
        if state.isDocked, let dockScreen { return dockScreen }
        return panel.screen ?? NSScreen.containing(CGPoint(x: frame.midX, y: frame.midY)) ?? NSScreen.main
    }

    /// 縁を放した（設定がオンなら、次に開く同じ種類の棚も、この大きさで開く）
    func endResize() {
        guard resizeStartFrame != nil else { return }
        resizeStartFrame = nil
        state.isResizing = false
        // まだ縁の上にあれば、次にポインタが動いたときにまた光る
        state.hoveredResizeHandle = nil
        if ShelfBehaviorSettings(defaults: .standard).remembersResizedSize {
            makeSizeDefault()
        }
        onStateChange?()
    }

    /// 今の置き方の標準（画面の端にあれば画面の端の、浮いていれば浮いた棚の標準）
    private var sizeKind: ShelfSizing.Kind {
        state.isDocked ? .docked : .floating
    }

    /// 保存しておいた、画面の端にあるときの大きさを戻す（起動したとき・最近閉じた棚を開き直すとき）
    func restoreDockedSize(_ size: CGSize) {
        state.dockedSize = ShelfSizing.clamped(size)
    }

    /// 今の大きさを、今の置き方の標準（次に開く棚・次に同じ置き方にした棚の大きさ）にする
    func makeSizeDefault() {
        ShelfSizing.remember(state.size, for: sizeKind, defaults: .standard)
    }

    /// 標準の大きさに戻す（浮いた棚は左上を動かさない。しまった棚は、帯の高さを真ん中のままにする）
    func resetSize() {
        let size = ShelfSizing.remembered(sizeKind, defaults: .standard)
        guard size != state.size else { return }
        withAnimation(ShelfMotion.animation) {
            state.size = size
        }
        if state.isDocked {
            if state.isUnfolded {
                applyDockedFrame(animated: true)
            }
        } else {
            let current = moveTracker.restingFrame
            let frame = CGRect(x: current.minX, y: current.maxY - size.height, width: size.width, height: size.height)
            let visible = NSScreen.containing(CGPoint(x: current.midX, y: current.midY))?.visibleFrame
            setPanelFrame(visible.map { EdgeGeometry.fit(frame, into: [$0]) } ?? frame, animated: true)
        }
        onStateChange?()
    }
}
