import AppKit
import PinshelfCore

/// メニューバーのアイコン
///
/// - 押すとメニューを出す（新しい棚を開く・画面端の棚を開く・最近閉じた棚・お気に入り・設定・アップデートを確認・終了）
/// - ファイル・テキスト・リンクを落とすと、棚に入れる（入れ先は設定で選ぶ）
/// - 自動で新しい版を見つけたら、アイコンの右上に小さな丸を付け、メニューのいちばん上で知らせる
///
/// アイコンのウィンドウにドラッグの種類を登録し、そのウィンドウの delegate としてドロップを受け取る
/// （NSWindow は、自分に届いたドラッグをこの delegate に回す）。
final class StatusItemController: NSObject, NSWindowDelegate, NSDraggingDestination, NSMenuDelegate {
    var onNewShelf: (() -> Void)?
    /// お気に入りの棚の一覧（メニューを開くたびに聞く）
    var favoriteShelves: (() -> [FavoriteShelfEntry])?
    /// お気に入りの棚を選んだ
    var onSelectFavoriteShelf: ((UUID) -> Void)?
    /// お気に入りから削除する棚を選んだ
    var onRemoveFavoriteShelf: ((UUID) -> Void)?
    /// 「お気に入り一覧…」を選んだ
    var onOpenFavorites: (() -> Void)?
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
    /// 更新の状態（新しい版の知らせ・「アップデートを確認…」）
    private let updates: AppUpdates
    /// 新しい版があるときに、アイコンの右上に出す小さな丸
    private let updateBadge = UpdateBadgeView()

    private static let toolTip = "Pinshelf（ここにドロップすると棚に入れます）"

    init(updates: AppUpdates) {
        self.updates = updates
        super.init()
        if let button = statusItem.button {
            // アプリのアイコンと同じ絵の、1 色の印（テンプレート画像）
            button.image = AppIcon.symbol(accessibilityDescription: "Pinshelf")
            button.toolTip = Self.toolTip
            installUpdateBadge(on: button)
        }
        updates.onPendingVersionChange = { [weak self] version in
            self?.showPendingUpdate(version)
        }
        showPendingUpdate(updates.pendingVersion)
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
        // 自動で見つけた新しい版は、いちばん上で知らせる（選ぶと、更新の画面が出る）
        if let version = updates.pendingVersion {
            let update = item("新しいバージョン \(version) があります…", action: #selector(checkForUpdates))
            update.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
            menu.addItem(update)
            menu.addItem(.separator())
        }
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
        menu.addItem(item("お気に入り一覧…", action: #selector(openFavorites)))

        let favorites = favoriteShelves?() ?? []
        if !favorites.isEmpty {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "お気に入りの棚"))
            for entry in favorites {
                let shelfItem = self.shelfItem(entry.title, color: entry.color, id: entry.id, action: #selector(selectFavoriteShelf(_:)))
                shelfItem.subtitle = "\(entry.count) 個"
                shelfItem.state = entry.isVisible ? .on : .off
                shelfItem.toolTip = entry.isVisible ? "出している棚を前に出す" : "閉じている棚を出す"
                menu.addItem(shelfItem)
            }
            menu.addItem(makeRemoveFavoritesItem(favorites))
        }

        menu.addItem(.separator())
        menu.addItem(item("設定…", action: #selector(openSettings), key: ","))
        // 更新の機能を使えるビルドだけ（公開鍵の入っていないビルドでは出さない）
        if updates.isAvailable {
            let check = item("アップデートを確認…", action: #selector(checkForUpdates))
            // 裏で確かめている途中・ダウンロードの途中は選べない
            check.isEnabled = updates.canCheck
            menu.addItem(check)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Pinshelf を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    /// 棚 1 つの項目（色の丸と名前。選んだときに、どの棚かが分かるよう棚の ID を持たせる）
    private func shelfItem(_ title: String, color: ShelfColor, id: UUID, action: Selector) -> NSMenuItem {
        let item = item(title, action: action)
        item.image = color.menuImage
        item.representedObject = id
        return item
    }

    /// 選んだ棚の項目の、棚の ID
    private static func shelfID(of item: NSMenuItem) -> UUID? {
        item.representedObject as? UUID
    }

    @objc private func newShelf() { onNewShelf?() }
    @objc private func openEdgeShelf() { onOpenEdgeShelf?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func addFromClipboard() { onAddFromClipboard?(iconFrame) }
    @objc private func checkForUpdates() { updates.check() }

    // MARK: - 新しい版の知らせ

    /// アイコンの右上に、小さな丸を置く（ふだんは隠しておく）
    private func installUpdateBadge(on button: NSStatusBarButton) {
        updateBadge.isHidden = true
        updateBadge.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(updateBadge)
        NSLayoutConstraint.activate([
            updateBadge.widthAnchor.constraint(equalToConstant: UpdateBadgeView.diameter),
            updateBadge.heightAnchor.constraint(equalToConstant: UpdateBadgeView.diameter),
            updateBadge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
            updateBadge.topAnchor.constraint(equalTo: button.topAnchor, constant: 3),
        ])
    }

    /// 知らせる新しい版があれば丸を出し、なければ隠す
    private func showPendingUpdate(_ version: String?) {
        updateBadge.isHidden = version == nil
        statusItem.button?.toolTip = version.map { "Pinshelf（新しいバージョン \($0) があります）" } ?? Self.toolTip
    }

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
            let shelfItem = self.shelfItem(entry.title, color: entry.color, id: entry.id, action: #selector(reopenRecentShelf(_:)))
            shelfItem.subtitle = "\(entry.count) 個・\(formatter.localizedString(for: entry.closedAt, relativeTo: .now))"
            shelfItem.toolTip = "閉じたときの位置に、中身ごと開き直す"
            submenu.addItem(shelfItem)
        }
        submenu.addItem(.separator())
        submenu.addItem(item("履歴を消す", action: #selector(clearRecentShelves)))
        parent.submenu = submenu
        return parent
    }

    @objc private func reopenRecentShelf(_ sender: NSMenuItem) {
        Self.shelfID(of: sender).map { onReopenRecentShelf?($0) }
    }

    @objc private func clearRecentShelves() { onClearRecentShelves?() }

    @objc private func selectFavoriteShelf(_ sender: NSMenuItem) {
        Self.shelfID(of: sender).map { onSelectFavoriteShelf?($0) }
    }

    @objc private func openFavorites() { onOpenFavorites?() }

    /// 「お気に入りから削除 ▸」。削除する棚を、この中から選ぶ
    private func makeRemoveFavoritesItem(_ favorites: [FavoriteShelfEntry]) -> NSMenuItem {
        let parent = NSMenuItem(title: "お気に入りから削除", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for entry in favorites {
            let removeItem = shelfItem(entry.title, color: entry.color, id: entry.id, action: #selector(removeFavoriteShelf(_:)))
            removeItem.toolTip = entry.isVisible
                ? "お気に入りから外す（棚は、ふつうの棚として残る）"
                : "お気に入りから外して閉じる（「最近閉じた棚」から開き直せる）"
            submenu.addItem(removeItem)
        }
        parent.submenu = submenu
        return parent
    }

    @objc private func removeFavoriteShelf(_ sender: NSMenuItem) {
        Self.shelfID(of: sender).map { onRemoveFavoriteShelf?($0) }
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

/// 新しい版があるときに、メニューバーのアイコンの右上に出す小さな丸
private final class UpdateBadgeView: NSView {
    static let diameter: CGFloat = 6

    override func draw(_ dirtyRect: NSRect) {
        // 色は描くたびに決める（外観やアクセントカラーが変わっても合うように）
        NSColor.controlAccentColor.setFill()
        NSBezierPath(ovalIn: bounds).fill()
    }

    /// アイコンのクリックとドロップを邪魔しない
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
