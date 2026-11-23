import AppKit
import PinshelfCore

/// メニューバーのアイコン・クリップボードから棚に入れる（入れ先は設定で選ぶ）
extension AppCoordinator {
    // MARK: - メニューバーのアイコンへのドロップ

    /// メニューバーのアイコンに重ねている間の操作（棚から運んできたものは移動、⌥ でコピー）
    func menuBarDropOperation() -> NSDragOperation {
        guard InternalShelfDrag.current != nil else { return .copy }
        return InternalShelfDrag.isCopyRequested ? .copy : .move
    }

    /// メニューバーのアイコンに落とされた
    /// - Parameter iconFrame: アイコンの枠（新しい棚を、その下に開く）
    func handleMenuBarDrop(_ pasteboard: NSPasteboard, below iconFrame: CGRect) -> Bool {
        let destination = inboxDestination
        let internalDrag = InternalShelfDrag.current
        let contents = internalDrag == nil ? PasteboardReader.contents(from: pasteboard) : []
        guard internalDrag != nil || !contents.isEmpty else { return false }

        // 画面端の棚から運んできたものを、画面端の棚に入れ直すことはしない
        if destination == .edgeShelf, let source = internalDrag?.source, source === edgeDriver.shelf?.model { return false }

        let target = openInboxTarget(destination, below: iconFrame)
        // 運んできた棚そのものが入れ先になったとき（画面の端にしまった棚から運んできたときなど）は、何もしない
        if let source = internalDrag?.source, source === target { return false }
        if let internalDrag, let source = internalDrag.source {
            // 棚から運んできたもの: 棚から棚へと同じく、移動（⌥ でコピー）
            target.receive(internalDrag.items, bookmarks: source.bookmarks(for: internalDrag.items))
            internalDrag.result = InternalShelfDrag.isCopyRequested ? .copied : .moved
        } else {
            target.accept(contents: contents)
        }
        finishInboxDelivery(destination)
        return true
    }

    // MARK: - クリップボードから棚へ

    /// クリップボードの中身を棚に入れる（ショートカット・メニューバーから）
    /// - Parameter iconFrame: メニューバーから呼んだときのアイコンの枠（新しい棚をその下に開く）。nil ならカーソルの位置
    func addFromClipboard(below iconFrame: CGRect? = nil) {
        let contents = ClipboardImporter.contents()
        guard !contents.isEmpty else {
            NSSound.beep()
            return
        }
        let destination = inboxDestination
        openInboxTarget(destination, below: iconFrame).accept(contents: contents)
        finishInboxDelivery(destination)
    }

    /// 設定のショートカットを登録する（変わっていなければ何もしない）
    func updateClipboardHotKey() {
        let shortcut = ShelfBehaviorSettings(defaults: .standard).clipboardShortcut
        guard shortcut != registeredClipboardShortcut else { return }
        registeredClipboardShortcut = shortcut
        clipboardHotKey = nil
        guard let key = shortcut.carbonKey else { return }
        clipboardHotKey = HotKey(keyCode: key.keyCode, modifiers: key.modifiers) { [weak self] in
            self?.addFromClipboard()
        }
    }

    // MARK: - 入れ先

    /// メニューバー・クリップボードから入れるときの入れ先（設定）
    private var inboxDestination: InboxDestination {
        ShelfBehaviorSettings(defaults: .standard).inboxDestination
    }

    /// 入れ先の棚（新しい棚なら開く。アイコンの枠があればその下、なければカーソルの位置に開く）
    private func openInboxTarget(_ destination: InboxDestination, below iconFrame: CGRect?) -> ShelfModel {
        if destination == .edgeShelf {
            if let shelf = edgeDriver.shelfForInbox(near: NSEvent.mouseLocation, settings: TriggerSettings(defaults: .standard)) {
                return shelf.model
            }
        }
        // 新しい棚に入れる（画面端の棚を出せなかったときも）
        let center = iconFrame.map { CGPoint(x: $0.midX, y: $0.minY - ShelfSizing.remembered(.floating, defaults: .standard).height / 2 - 8) }
            ?? NSEvent.mouseLocation
        return openShelf(centeredAt: center).model
    }

    /// 入れたあと（画面端の棚に入れたら、入ったことが分かるよう少しのあいだ開く）
    private func finishInboxDelivery(_ destination: InboxDestination) {
        if destination == .edgeShelf {
            openEdgeShelf()
        }
    }
}
