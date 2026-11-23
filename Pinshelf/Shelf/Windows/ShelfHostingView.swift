import AppKit
import SwiftUI

/// 棚の中身を表示するビュー
///
/// - アプリが前面になくても 1 回目のクリックから反応する
/// - アプリが前面になくても、ポインタが入ったことを知らせる（出たことは PointerLeaveWatcher が位置で調べる）
final class ShelfHostingView<Content: View>: NSHostingView<Content> {
    var onPointerEntered: (() -> Void)?
    /// ポインタが棚の外へ出た（すぐに帯にたたむため）
    var onPointerExited: (() -> Void)?
    /// ポインタが動いた（ビューの座標。左上が原点。棚の外へ出たら nil）。縁の上なら、出す大きさを変える形のポインタを返す
    var pointerMoved: ((CGPoint?) -> NSCursor?)?
    /// 大きさを変える形のポインタを出しているか（縁から離れたら、ふつうの矢印に戻すため）
    private var showsResizeCursor = false

    private var hoverArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea {
            removeTrackingArea(hoverArea)
        }
        // ポインタの動きも受ける。activeAlways なので、棚がキーウィンドウでなくても（ほかのアプリを使っている間も）届く
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea === hoverArea {
            onPointerEntered?()
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === hoverArea {
            _ = pointerMoved?(nil)
            if showsResizeCursor {
                showsResizeCursor = false
                NSCursor.arrow.set()
            }
            onPointerExited?()
        }
    }

    // MARK: - 縁のポインタの形
    // macOS は、前面にないアプリがポインタの形を変えるのを許さない（棚がキーウィンドウのときだけ変えられる）。
    // ポインタの動きはいつでも届くので、形を変えられるときは変え、縁の光り方（棚の側）でもつかめるところを見せる

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateResizeCursor(for: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        // 縁の上なら大きさを変える形にする。縁でなければ、SwiftUI に任せる
        if !updateResizeCursor(for: event) {
            super.cursorUpdate(with: event)
        }
    }

    /// ポインタの位置に合わせて形を変える
    /// - Returns: 大きさを変える形にしたら true
    @discardableResult
    private func updateResizeCursor(for event: NSEvent) -> Bool {
        let location = convert(event.locationInWindow, from: nil)
        let point = isFlipped ? location : CGPoint(x: location.x, y: bounds.height - location.y)
        if let cursor = pointerMoved?(point) {
            cursor.set()
            showsResizeCursor = true
            return true
        }
        if showsResizeCursor {
            showsResizeCursor = false
            NSCursor.arrow.set()
        }
        return false
    }
}
