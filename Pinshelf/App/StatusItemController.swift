import AppKit
import PinshelfCore

/// メニューに出す、お気に入りの棚
struct FavoriteShelfEntry {
    let id: UUID
    let title: String
    let color: ShelfColor
    let count: Int
    /// 今出しているか（隠していれば false）
    let isVisible: Bool
}

/// メニューに出す、最近閉じた棚
struct RecentShelfEntry {
    let id: UUID
    let title: String
    let color: ShelfColor
    let count: Int
    let closedAt: Date
}

/// メニューバーのアイコン
///
/// - 押すとメニューを出す（新しい棚を開く・画面端の棚を開く・設定・終了）
/// - ファイル・テキスト・リンクを落とすと、棚に入れる（入れ先は設定で選ぶ）
///
/// アイコンのウィンドウにドラッグの種類を登録し、そのウィンドウの delegate としてドロップを受け取る
/// （NSWindow は、自分に届いたドラッグをこの delegate に回す）。
final class StatusItemController: NSObject, NSWindowDelegate, NSDraggingDestination, NSMenuDelegate {
    var onNewShelf: (() -> Void)?
    /// お気に入りの棚の一覧（メニューを開くたびに聞く）
    var favoriteShelves: (() -> [FavoriteShelfEntry])?
    /// お気に入りの棚を選んだ
    var onSelectFavoriteShelf: ((UUID) -> Void)?
    /// 「クリップボードから棚へ」を選んだ（アイコンの枠）
    var onAddFromClipboard: ((CGRect) -> Void)?
    /// 最近閉じた棚の一覧（メニューを開くたびに聞く）
    var recentShelves: (() -> [RecentShelfEntry])?
    /// 最近閉じた棚を選んだ
    var onReopenRecentShelf: ((UUID) -> Void)?
    /// 最近閉じた棚の履歴を消す
    var onClearRecentShelves: (() -> Void)?
    var onOpenEdgeShelf: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    /// 重ねている間に見せる操作（コピー・移動）
    var dropOperation: (() -> NSDragOperation)?
    /// 落とされた（ペーストボード・アイコンの枠）。受け取ったら true を返す
    var onDrop: ((NSPasteboard, CGRect) -> Bool)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    override init() {
        super.init()
        if let button = statusItem.button {
            // アプリのアイコンと同じ絵の、1 色の印（テンプレート画像）
            button.image = AppIcon.symbol(accessibilityDescription: "Pinshelf")
            button.toolTip = "Pinshelf（ここにドロップすると棚に入れます）"
        }
        let menu = NSMenu()
        menu.delegate = self
        // 「クリップボードから棚へ」は、クリップボードの中身があるときだけ選べるようにする
        menu.autoenablesItems = false
        statusItem.menu = menu
        registerForDrops()
    }

    // MARK: - メニュー

    /// メニューを開くたびに作り直す（お気に入りの棚の一覧が変わるため）
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(item("新しい棚を開く", action: #selector(newShelf)))
        menu.addItem(item("画面の端の棚を開く", action: #selector(openEdgeShelf)))
        let paste = item("クリップボードから棚へ", action: #selector(addFromClipboard))
        let shortcut = ShelfBehaviorSettings(defaults: .standard).clipboardShortcut
        if shortcut != .off {
            paste.keyEquivalent = "v"
            paste.keyEquivalentModifierMask = shortcut.menuModifiers
        }
        paste.isEnabled = ClipboardImporter.hasContents()
        menu.addItem(paste)
        menu.addItem(makeRecentShelvesItem())

        let favorites = favoriteShelves?() ?? []
        if !favorites.isEmpty {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "お気に入りの棚"))
            for entry in favorites {
                let shelfItem = item(entry.title, action: #selector(selectFavoriteShelf(_:)))
                shelfItem.subtitle = "\(entry.count) 個"
                shelfItem.image = entry.color.menuImage
                shelfItem.state = entry.isVisible ? .on : .off
                shelfItem.representedObject = entry.id
                shelfItem.toolTip = entry.isVisible ? "出している棚を前に出す" : "隠している棚を出す"
                menu.addItem(shelfItem)
            }
        }

        menu.addItem(.separator())
        menu.addItem(item("設定…", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Pinshelf を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func newShelf() { onNewShelf?() }
    @objc private func openEdgeShelf() { onOpenEdgeShelf?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func addFromClipboard() { onAddFromClipboard?(iconFrame) }

    /// 「最近閉じた棚 ▸」（閉じた棚がなければ選べない）
    private func makeRecentShelvesItem() -> NSMenuItem {
        let recent = recentShelves?() ?? []
        let parent = NSMenuItem(title: "最近閉じた棚", action: nil, keyEquivalent: "")
        parent.isEnabled = !recent.isEmpty
        guard !recent.isEmpty else { return parent }

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        for entry in recent {
            let shelfItem = item(entry.title, action: #selector(reopenRecentShelf(_:)))
            shelfItem.subtitle = "\(entry.count) 個・\(formatter.localizedString(for: entry.closedAt, relativeTo: .now))"
            shelfItem.image = entry.color.menuImage
            shelfItem.representedObject = entry.id
            shelfItem.toolTip = "閉じたときの位置に、中身ごと開き直す"
            submenu.addItem(shelfItem)
        }
        submenu.addItem(.separator())
        submenu.addItem(item("履歴を消す", action: #selector(clearRecentShelves)))
        parent.submenu = submenu
        return parent
    }

    @objc private func reopenRecentShelf(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onReopenRecentShelf?(id)
    }

    @objc private func clearRecentShelves() { onClearRecentShelves?() }

    @objc private func selectFavoriteShelf(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onSelectFavoriteShelf?(id)
    }

    // MARK: - ドロップ

    private func registerForDrops() {
        guard let window = statusItem.button?.window else {
            // まだアイコンのウィンドウができていなければ、少し待ってから
            DispatchQueue.main.async { [weak self] in self?.registerForDrops() }
            return
        }
        window.registerForDraggedTypes([.fileURL, .URL, .string])
        window.delegate = self
    }

    /// アイコンの枠（画面座標）
    private var iconFrame: CGRect {
        statusItem.button?.window?.frame ?? .zero
    }

    func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let operation = dropOperation?() ?? .copy
        statusItem.button?.highlight(!operation.isEmpty)
        return operation
    }

    func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        // ⌥ を押した・離したときに、コピーと移動を切り替える
        dropOperation?() ?? .copy
    }

    func draggingExited(_ sender: (any NSDraggingInfo)?) {
        statusItem.button?.highlight(false)
    }

    func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        statusItem.button?.highlight(false)
        return onDrop?(sender.draggingPasteboard, iconFrame) ?? false
    }

    func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        statusItem.button?.highlight(false)
    }
}
