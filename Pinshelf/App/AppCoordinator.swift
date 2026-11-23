import AppKit
import PinshelfCore

/// ドラッグの検出と、棚（浮いた棚・画面端にしまった棚・画面端の棚）をつなぐ
///
/// 役目ごとに、別のファイルの拡張に分けている。
/// - `AppCoordinator+Drag.swift`: ドラッグに合わせて棚を出す（画面端・振る・キー）
/// - `AppCoordinator+Persistence.swift`: 棚の保存と復元
/// - `AppCoordinator+Inbox.swift`: メニューバーのアイコン・クリップボードから棚に入れる
/// - `AppCoordinator+ShelfLists.swift`: お気に入りの棚・最近閉じた棚
///
/// どの棚も同じ `ShelfController`（`shelves` に入る）。`edgeDriver` は、そのうちの画面端の棚をドラッグに合わせて出し入れする。
///
/// 拡張からも使うものは private にしていない。
final class AppCoordinator {
    private let dragMonitor = DragMonitor()
    /// 画面端の棚を出し入れする（棚そのものは shelves に入っている）
    let edgeDriver = EdgeShelfDriver()
    /// 出している棚（画面端の棚も含む）
    var shelves: [ShelfController] = []
    let persistence = ShelfPersistence()
    /// 最近閉じた棚（メニューバーから開き直せる）
    var recentShelves = RecentShelves()
    /// お気に入り一覧に出す、お気に入りの棚（棚が変わるたびに読み直す）
    let favoritesList = FavoriteShelvesList()

    /// 設定のウィンドウを開く（棚の見出しのメニューから）
    var openSettings: (() -> Void)?

    /// 「クリップボードから棚へ」のショートカット
    var clipboardHotKey: HotKey?
    var registeredClipboardShortcut: ClipboardShortcut?
    private var defaultsObserver: (any NSObjectProtocol)?

    /// 今のドラッグで使っている設定（ドラッグを始めたときに読み直す）
    var settings = TriggerSettings.defaults
    var shakeDetector = ShakeDetector(configuration: .preset(.light))
    /// 今のドラッグでシェイクを受け付けるか
    var isShakeArmed = false
    /// ドラッグ中に修飾キーが押されたのを見つける
    var modifierDetector = ModifierTriggerDetector(trigger: .none, initial: [])
    /// 今のドラッグで、もう棚を出したか（シェイク・修飾キーで出す棚は、1 回のドラッグで 1 つまで）
    var hasOpenedShelfInThisDrag = false
    /// 今のドラッグで画面端の棚を使っているか
    var isEdgeShelfArmed = false
    /// 今のドラッグ中にシェイク・修飾キーで開いた棚（何も置かれなければドラッグの終わりに閉じる）
    var shelvesOpenedInThisDrag: [ShelfController] = []

    func start() {
        ShelfSizing.migrateLegacyValues(defaults: .standard)
        // 画面端の棚も、ほかの棚と同じように作って覚える（復元で使うので、先に渡しておく）
        edgeDriver.makeShelf = { [weak self] point in
            guard let self else { return nil }
            // すぐに画面の端にしまうので、画面の端にあるときの標準の大きさで出る
            let shelf = ShelfController(centeredAt: point)
            self.register(shelf)
            return shelf
        }
        edgeDriver.dockedShelves = { [weak self] in
            self?.shelves.filter { $0.state.isDocked && !$0.isHidden } ?? []
        }
        restoreShelves()
        cleanUpClipboardFiles()
        updateClipboardHotKey()
        // 設定でショートカットを変えたら、登録し直す
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateClipboardHotKey()
            }
        }
        persistence.makeSnapshot = { [weak self] in
            self?.makeSnapshot() ?? ShelfSnapshot()
        }
        favoritesList.load = { [weak self] in self?.favoriteShelfEntries() ?? [] }
        favoritesList.onShow = { [weak self] id in self?.showFavoriteShelf(id: id) }
        favoritesList.onRemove = { [weak self] id in self?.removeFavorite(id: id) }

        dragMonitor.onDragBegan = { [weak self] location, window in
            self?.dragBegan(at: location, startedIn: window)
        }
        dragMonitor.onDragMoved = { [weak self] location, time in
            self?.dragMoved(to: location, at: time)
        }
        dragMonitor.onDragEnded = { [weak self] in
            self?.dragEnded()
        }
        dragMonitor.start()
    }

    func stop() {
        dragMonitor.stop()
        persistence.saveNow()
    }

    // MARK: - 棚

    /// カーソルの位置に、新しい浮いた棚を開く
    @discardableResult
    func openShelf(centeredAt point: CGPoint) -> ShelfController {
        let shelf = ShelfController(centeredAt: point)
        addShelf(shelf)
        return shelf
    }

    /// 棚を覚えて、出す
    func addShelf(_ shelf: ShelfController) {
        register(shelf)
        shelf.show()
    }

    /// 棚を覚え、閉じる・動かす・しまう・中身が変わるときに保存するようにする
    func register(_ shelf: ShelfController) {
        shelf.onClose = { [weak self] closed in
            guard let self else { return }
            // 中身のある棚を閉じたら、最近閉じた棚として覚える（空の棚は覚えない）
            if !closed.state.isFavorite {
                self.recentShelves.record(closed.archive())
            }
            self.shelves.removeAll { $0 === closed }
            self.shelvesDidChange()
        }
        shelf.onMove = { [weak self] in
            self?.persistence.scheduleSave()
        }
        shelf.onStateChange = { [weak self] in
            self?.shelvesDidChange()
        }
        shelf.defaultNameProvider = { [weak self] in
            ShelfNaming.defaultName(existing: self?.shelves.compactMap(\.state.name) ?? [])
        }
        shelf.occupiedTabRanges = { [weak self] shelf, edge, screen in
            self?.occupiedTabRanges(excluding: shelf, edge: edge, screen: screen) ?? []
        }
        shelf.model.onChange = { [weak self] in
            self?.shelvesDidChange()
        }
        shelf.onOpenSettings = { [weak self] in
            self?.openSettings?()
        }
        shelves.append(shelf)
    }

    /// 棚が変わった（閉じた・名前や色・お気に入り・隠した・中身が変わった）。保存して、お気に入り一覧を読み直す
    func shelvesDidChange() {
        persistence.scheduleSave()
        favoritesList.reload()
    }

    /// 画面端の帯が使っている縦の範囲（しまった棚の帯を、重ならないように置くため）
    private func occupiedTabRanges(excluding shelf: ShelfController, edge: ScreenEdge, screen: NSScreen) -> [ClosedRange<CGFloat>] {
        var ranges: [ClosedRange<CGFloat>] = shelves.compactMap { other in
            guard other !== shelf, !other.isHidden, other.state.placement == .docked(edge), other.dockScreen == screen,
                  let tab = other.tabFrame else { return nil }
            return tab.minY...tab.maxY
        }
        // まだ出していない画面端の棚の帯とも重ならないようにする（左右どちらに出るかは変わるので、両側で避ける）。
        // 画面端の棚を出していれば、その帯は上の一覧に入っている
        if edgeDriver.shelf == nil,
           let reserved = edgeDriver.reservedTabRange(on: screen, vertical: TriggerSettings(defaults: .standard).edgeVerticalPosition) {
            ranges.append(reserved)
        }
        return ranges
    }

    /// メニューから: カーソルのある画面の中央に新しい棚を開く
    func openShelfFromMenu() {
        let screen = NSScreen.containing(NSEvent.mouseLocation)
        let visible = screen?.visibleFrame ?? .zero
        openShelf(centeredAt: CGPoint(x: visible.midX, y: visible.midY))
    }

    /// メニューから: 画面端の棚を開く
    func openEdgeShelf() {
        edgeDriver.showShelf(near: NSEvent.mouseLocation, settings: TriggerSettings(defaults: .standard))
    }
}
