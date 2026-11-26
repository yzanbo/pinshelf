import AppKit
import PinshelfCore

/// 棚の保存と復元
extension AppCoordinator {
    // MARK: - 保存と復元

    /// 前回の棚を戻す
    func restoreShelves() {
        guard let snapshot = persistence.load() else { return }
        let coding = SystemBookmarkCoding()

        var files = FileRestoreTally()
        for stored in snapshot.shelves {
            files += restoreShelf(stored, using: coding)
        }
        // 前の形式では、画面端の棚の中身を別に保存していた。中身があれば、新しい画面端の棚に入れる
        let legacy = ShelfArchiver.restore(snapshot.edgeShelf, using: coding)
        files += legacy.files
        edgeDriver.restoreLegacy(legacy, edge: snapshot.edgeShelfEdge, settings: TriggerSettings(defaults: .standard))
        recentShelves = RecentShelves(entries: snapshot.recentlyClosed)
        persistence.reportRestoredFiles(files)
    }

    /// 保存しておいた浮いた棚を戻す（再起動したとき・最近閉じた棚を開き直すとき）
    /// - Returns: ファイルをどう戻せたかの数
    @discardableResult
    func restoreShelf(_ stored: StoredShelfWindow, using coding: any BookmarkCoding) -> FileRestoreTally {
        let model = ShelfModel(bookmarkCoding: coding)
        let restored = ShelfArchiver.restore(stored.shelf, using: coding)
        model.restore(restored)
        // ファイルが見つからず空になった棚は戻さない（お気に入りの棚は、空でも戻す）
        guard !model.isEmpty || stored.isFavorite else { return restored.files }

        let frame = EdgeGeometry.fit(stored.frame, into: NSScreen.screens.map(\.visibleFrame))
        let shelf = ShelfController(id: stored.id, frame: frame, model: model)
        shelf.applyIdentity(name: stored.name, color: stored.color, isFavorite: stored.isFavorite)
        // 画面の端で開いたままにするか（前の形式で保存した棚は、新しい棚のはじめの状態の設定のまま）
        if let keepsOpen = stored.keepsOpen {
            shelf.state.keepsOpen = keepsOpen
        }
        // 画面の端にあるときの大きさ（前の形式では、しまっていた棚は 1 つの大きさを両方に使っていた）
        if let dockedSize = stored.dockedSize {
            shelf.restoreDockedSize(dockedSize)
        } else if stored.dockedEdge != nil {
            shelf.restoreDockedSize(frame.size)
        }
        register(shelf)
        // 画面端にしまっていた棚は、しまったまま戻す
        if let edge = stored.dockedEdge {
            let centerY = stored.dockedCenterY.map { CGFloat($0) } ?? frame.midY
            let screen = NSScreen.containing(CGPoint(x: frame.midX, y: centerY)) ?? NSScreen.main
            if let screen {
                shelf.dock(to: edge, on: screen, centerY: centerY, unfolded: false, animated: false)
            }
        }
        // 画面端の棚だったものは、また画面端の棚にする（置いてあった場所のまま）
        if stored.isEdgeShelf, !stored.isHidden {
            edgeDriver.restore(shelf)
        }
        // 隠していたお気に入りの棚は、隠したまま（メニューバーから出し直せる）
        if stored.isFavorite, stored.isHidden {
            shelf.hide()
        } else {
            shelf.show()
        }
        return restored.files
    }

    /// 今の棚の保存内容（空の棚は残さない。お気に入りの棚は、空でも隠していても残す）
    ///
    /// 画面端の棚も shelves に入れる（isEdgeShelf の印つき）。前の形式の edgeDriver は空にする。
    func makeSnapshot() -> ShelfSnapshot {
        ShelfSnapshot(
            edgeShelfEdge: edgeDriver.edge,
            shelves: shelves.filter { !$0.model.isEmpty || $0.state.isFavorite }.map { $0.archive() },
            recentlyClosed: recentShelves.entries
        )
    }

    /// どの棚にも置いていない、クリップボードの画像のファイルを片付ける
    /// （開いている棚に置いているもの・⌘Z で戻せるもの・最近閉じた棚に置いていたものは残す）
    /// - Returns: 入れたばかりなので残した画像があるか（あれば、あとでもう一度片付ける）
    @discardableResult
    func cleanUpClipboardFiles() -> Bool {
        let inShelves = shelves.flatMap(\.model.referencedFileURLs)
        let inRecentShelves = recentShelves.filePaths.map { URL(fileURLWithPath: $0) }
        let referenced = Set((inShelves + inRecentShelves).map(\.standardizedFileURL.path))
        return ClipboardImporter.cleanUp(keeping: referenced)
    }
}
