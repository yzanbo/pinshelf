import AppKit
import PinshelfCore
import SwiftUI

/// 棚から外へドラッグで取り出す
///
/// 移動か複製かは、Finder と同じく受け取る側（Finder など）が決める。
/// - 同じボリュームなら移動、別のボリュームなら複製
/// - ⌥ を押していると複製、⌘ を押していると移動、⌘⌥ でエイリアス
///
/// 取り出したあと、元の場所からなくなったファイル（移動した・ゴミ箱に入れた）は棚から外す。
/// 選んでいるものをつかんだときは、選んでいるものをまとめて取り出す。
final class ShelfDragSource: NSObject, NSDraggingSource {
    /// 棚の中のものの枠を測る座標の名前（棚のビューのいちばん外側に付ける）
    static let coordinateSpace = "ShelfRoot"
    /// これだけ動かしたらドラッグを始める（pt）
    private static let dragThreshold: CGFloat = 3
    /// ドラッグ中に見せるアイコンの大きさ
    private static let imageSize: CGFloat = 48

    private weak var model: ShelfModel?
    private var pressLocation: CGPoint?
    private var pressedItemID: ShelfItem.ID?
    /// 今取り出しているもの
    private var draggedItems: [ShelfItem] = []

    init(model: ShelfModel) {
        self.model = model
    }

    /// 棚のウィンドウに届いたマウスのイベントを見る
    /// - Returns: ドラッグを始めたら true（そのイベントは SwiftUI に渡さない）
    func handle(_ event: NSEvent, in view: NSView) -> Bool {
        switch event.type {
        case .leftMouseDown:
            let point = Self.contentPoint(of: event, in: view)
            pressLocation = point
            // 縁（大きさを変えるところ）を押したときは、下に隠れているものをつかまない
            let isOnResizeEdge = !view.bounds.insetBy(dx: ResizeHandle.edgeThickness, dy: ResizeHandle.edgeThickness).contains(point)
            pressedItemID = isOnResizeEdge ? nil : model?.itemID(at: point)
            return false
        case .leftMouseDragged:
            guard let start = pressLocation, let id = pressedItemID, let model else { return false }
            let point = Self.contentPoint(of: event, in: view)
            guard hypot(point.x - start.x, point.y - start.y) >= Self.dragThreshold else { return false }
            pressLocation = nil
            pressedItemID = nil
            return beginDrag(grabbing: id, event: event, view: view, model: model)
        case .leftMouseUp:
            pressLocation = nil
            pressedItemID = nil
            return false
        default:
            return false
        }
    }

    private func beginDrag(grabbing id: ShelfItem.ID, event: NSEvent, view: NSView, model: ShelfModel) -> Bool {
        guard let grabbed = model.items.first(where: { $0.id == id }) else { return false }
        // 選んでいないものをつかんだら、それだけを選んで取り出す（Finder と同じ）
        if !model.isSelected(grabbed) {
            model.click(grabbed, modifier: .none)
        }
        let items = model.selectedItems
        guard !items.isEmpty else { return false }

        let pointer = Self.contentPoint(of: event, in: view)
        let draggingItems = items.enumerated().map { index, item in
            let draggingItem = NSDraggingItem(pasteboardWriter: item.content.pasteboardWriter)
            // 見えているものはその場所から、見えていないものはポインタの近くから動かし始める
            let center = model.tileFrames[item.id].map { CGPoint(x: $0.midX, y: $0.minY + 26) }
                ?? CGPoint(x: pointer.x + CGFloat(index) * 4, y: pointer.y + CGFloat(index) * 4)
            let size = Self.imageSize
            let frame = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
            draggingItem.setDraggingFrame(Self.viewRect(frame, in: view), contents: item.content.dragImage(size: size))
            return draggingItem
        }

        draggedItems = items
        InternalShelfDrag.current = InternalShelfDrag(source: model, items: items)
        let session = view.beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = items.count > 1 ? .pile : .none
        return true
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        if context == .outsideApplication {
            // 受け取る側が、ボリュームと修飾キーで移動・複製・エイリアスを選べるようにする
            return [.copy, .move, .link, .generic, .delete]
        }
        // 棚から棚へは、そのままなら移動、⌥ で複製（受け取る棚が決める）
        return [.copy, .move, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let items = draggedItems
        draggedItems = []
        let internalDrag = InternalShelfDrag.current
        InternalShelfDrag.current = nil

        switch internalDrag?.result {
        case .moved:
            // ほかの棚へ移した（ロックしたものは残す）
            model?.finishMovingToAnotherShelf(items)
        case .copied:
            // ほかの棚へ複製した（この棚にも残す）
            break
        case .none, .pending:
            // 取りやめたとき（どこにも落とさなかった）は何もしない
            guard !operation.isEmpty else { return }
            // ほかのアプリへ取り出した: 設定とロック、ファイルが残っているかで、外すか決める
            model?.finishDragOut(items)
        }
    }

    // MARK: - 座標

    /// イベントの位置を、SwiftUI の座標（左上が原点）にする
    private static func contentPoint(of event: NSEvent, in view: NSView) -> CGPoint {
        let point = view.convert(event.locationInWindow, from: nil)
        return view.isFlipped ? point : CGPoint(x: point.x, y: view.bounds.height - point.y)
    }

    /// SwiftUI の座標の枠を、ビューの座標にする
    private static func viewRect(_ rect: CGRect, in view: NSView) -> CGRect {
        view.isFlipped ? rect : CGRect(x: rect.minX, y: view.bounds.height - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// 棚の中のものの枠を集める
nonisolated struct ShelfTileFramesKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// 棚の一覧が見えている範囲
nonisolated struct ShelfItemsAreaKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
