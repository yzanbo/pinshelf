import AppKit
import PinshelfCore
import SwiftUI

// MARK: - 棚から棚へ

/// 棚から始まったドラッグ（受け取る棚に、移す元と中身を伝える）
final class InternalShelfDrag {
    enum Result {
        /// まだどこにも落としていない
        case pending
        /// ほかの棚へ移した（元の棚から外す）
        case moved
        /// ほかの棚へ複製した（元の棚にも残す）
        case copied
    }

    /// 今の棚からのドラッグ（同時に 1 つだけ）
    static var current: InternalShelfDrag?

    weak var source: ShelfModel?
    let items: [ShelfItem]
    var result: Result = .pending

    init(source: ShelfModel, items: [ShelfItem]) {
        self.source = source
        self.items = items
    }

    /// 今押している修飾キーで、移動か複製かを決める（⌥ で複製、それ以外は移動）
    static var isCopyRequested: Bool {
        NSEvent.modifierFlags.contains(.option)
    }
}

/// 棚にドロップされたものを受け取る
///
/// - 外（Finder など）から: 場所を覚えるだけ（元のファイルは動かさない）
/// - ほかの棚から: そのままなら移動、⌥ で複製
/// - 同じ棚から: 受け取らない（自分の上に落としても消えないように）
struct ShelfDropDelegate: DropDelegate {
    let model: ShelfModel
    @Binding var isTargeted: Bool

    private enum Source {
        case outside
        case otherShelf(InternalShelfDrag, from: ShelfModel)
        case sameShelf
    }

    private var source: Source {
        guard let drag = InternalShelfDrag.current, let from = drag.source else { return .outside }
        return from === model ? .sameShelf : .otherShelf(drag, from: from)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: ShelfModel.acceptedTypes)
    }

    func dropEntered(info: DropInfo) {
        if case .sameShelf = source { return }
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        switch source {
        case .outside:
            return DropProposal(operation: .copy)
        case .otherShelf:
            return DropProposal(operation: InternalShelfDrag.isCopyRequested ? .copy : .move)
        case .sameShelf:
            return DropProposal(operation: .forbidden)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        switch source {
        case .outside:
            return model.accept(info.itemProviders(for: ShelfModel.acceptedTypes))
        case .otherShelf(let drag, let from):
            model.receive(drag.items, bookmarks: from.bookmarks(for: drag.items))
            drag.result = InternalShelfDrag.isCopyRequested ? .copied : .moved
            return true
        case .sameShelf:
            return false
        }
    }
}

// MARK: - ドロップの受け取り

extension View {
    /// 棚にドロップできるようにし、重なっている間は枠を光らせる
    func shelfDropTarget(model: ShelfModel, isTargeted: Binding<Bool>, cornerRadius: CGFloat) -> some View {
        onDrop(of: ShelfModel.acceptedTypes, delegate: ShelfDropDelegate(model: model, isTargeted: isTargeted))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(isTargeted.wrappedValue ? 0.06 : 0))
                .strokeBorder(Color.accentColor.opacity(isTargeted.wrappedValue ? 1 : 0), lineWidth: 2)
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.15), value: isTargeted.wrappedValue)
        }
    }
}
