import AppKit
import PinshelfCore
import SwiftUI

/// 名前・色・お気に入りと、保存の形式
extension ShelfController {
    // MARK: - 名前・色・お気に入り

    /// 名前を変え始める（見出しで直接入力する）
    func beginRename() {
        if state.isFolded {
            unfold(waitForEntry: true)
        }
        state.isRenaming = true
        // 文字を打てるよう、棚をキーウィンドウにする（前面のアプリは変えない）
        panel.makeKey()
    }

    func rename(to name: String) {
        state.name = ShelfNaming.normalized(name)
        state.isRenaming = false
        onStateChange?()
    }

    func setColor(_ color: ShelfColor) {
        state.color = color
        onStateChange?()
    }

    /// お気に入りにする・外す（名前のない棚をお気に入りにしたら、仮の名前を付ける）
    func toggleFavorite() {
        state.isFavorite.toggle()
        if state.isFavorite, state.name == nil {
            state.name = defaultNameProvider?()
        }
        onStateChange?()
    }

    /// 保存しておいた名前・色・お気に入りを戻す
    func applyIdentity(name: String?, color: ShelfColor, isFavorite: Bool) {
        state.name = name
        state.color = color
        state.isFavorite = isFavorite
    }

    // MARK: - 保存

    /// 保存の形式にする（しまっているときは、戻したときの枠と、しまった端・高さ）
    func archive() -> StoredShelfWindow {
        var stored: StoredShelfWindow
        switch state.placement {
        case .floating:
            // 出す・消すアニメーションの途中でも、落ち着いたときの枠を残す
            stored = StoredShelfWindow(id: id, frame: moveTracker.restingFrame, shelf: model.archive())
        case .docked(let edge):
            let visible = dockScreen?.visibleFrame ?? panel.screen?.visibleFrame ?? panel.frame
            let frame = DockLayout.undockedFrame(edge: edge, centerY: dockCenterY, size: state.floatingSize, in: visible)
            stored = StoredShelfWindow(id: id, frame: frame, shelf: model.archive(), dockedEdge: edge, dockedCenterY: Double(dockCenterY))
        }
        stored.name = state.name
        stored.color = state.color
        stored.isFavorite = state.isFavorite
        stored.isHidden = isHidden
        stored.isEdgeShelf = state.isEdgeShelf
        stored.dockedSize = state.dockedSize
        stored.keepsOpen = state.keepsOpen
        return stored
    }
}
