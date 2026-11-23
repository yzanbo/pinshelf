import AppKit
import PinshelfCore

/// 棚のウィンドウでの操作（Quick Look・キー操作・ドラッグでの取り出し）を、まとめてつなぐ
///
/// 画面端の棚と浮いた棚で同じつなぎ方をするので、ここにまとめる。
final class ShelfInteraction {
    /// Quick Look に選んでいるものを見せる係
    let preview: ShelfPreviewSource
    /// 棚から外へドラッグで取り出す係
    private let dragSource: ShelfDragSource
    /// 中身をつかめるか（帯にたたんでいる間は、見えていない棚の中身をつかまないよう false を返す）
    var canGrabItems: () -> Bool = { true }

    init(model: ShelfModel, panel: ShelfPanel) {
        preview = ShelfPreviewSource(model: model, panel: panel)
        dragSource = ShelfDragSource(model: model)

        // スペースキー・選択・右クリックのメニューを Quick Look につなぐ
        panel.previewSource = preview
        panel.keyHandler = { [weak model, weak preview] event in
            guard let model, let preview else { return false }
            return ShelfKeyboard.handle(event, model: model, preview: preview)
        }
        model.onSelectionChange = { [weak preview] in preview?.selectionChanged() }
        model.onQuickLookRequest = { [weak preview] in preview?.show() }

        // 棚から外へドラッグで取り出す
        panel.mouseHandler = { [weak self, weak panel] event in
            guard let self, self.canGrabItems(), let view = panel?.contentView else { return false }
            return self.dragSource.handle(event, in: view)
        }
    }
}
