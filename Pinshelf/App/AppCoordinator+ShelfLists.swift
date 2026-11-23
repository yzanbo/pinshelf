import AppKit
import PinshelfCore

/// お気に入りの棚・最近閉じた棚
extension AppCoordinator {
    // MARK: - 最近閉じた棚

    /// メニューバーのメニューに出す、最近閉じた棚の一覧
    func recentShelfEntries() -> [RecentShelfEntry] {
        recentShelves.entries.map { entry in
            RecentShelfEntry(
                id: entry.shelf.id,
                title: entry.shelf.name ?? entry.shelf.shelf.summaryTitle,
                color: entry.shelf.color,
                count: entry.shelf.shelf.items.count,
                closedAt: entry.closedAt
            )
        }
    }

    /// 最近閉じた棚を、閉じたときの位置に開き直す
    func reopenRecentShelf(id: UUID) {
        guard let entry = recentShelves.take(id: id) else { return }
        var stored = entry.shelf
        // 閉じたときに隠していることはないが、念のため出した状態で戻す。画面端の棚だったものも、ただの棚として戻す
        stored.isHidden = false
        stored.isEdgeShelf = false
        let coding = SystemBookmarkCoding()
        let missing = restoreShelf(stored, using: coding)
        persistence.reportMissingFiles(missing)
        if !shelves.contains(where: { $0.id == stored.id }) {
            // ファイルがすべて見つからず、戻せなかった
            NSSound.beep()
        }
        persistence.scheduleSave()
    }

    /// 最近閉じた棚をすべて忘れる
    func clearRecentShelves() {
        recentShelves.clear()
        persistence.scheduleSave()
    }

    // MARK: - お気に入りの棚

    /// メニューバーのメニューに出す、お気に入りの棚の一覧
    func favoriteShelfEntries() -> [FavoriteShelfEntry] {
        shelves.filter(\.state.isFavorite).map { shelf in
            FavoriteShelfEntry(
                id: shelf.id,
                title: shelf.state.name ?? shelf.model.countLabel,
                color: shelf.state.color,
                count: shelf.model.items.count,
                isVisible: !shelf.isHidden
            )
        }
    }

    /// メニューバーから、お気に入りの棚を出す（出していれば前に出す）
    func showFavoriteShelf(id: UUID) {
        guard let shelf = shelves.first(where: { $0.id == id }) else { return }
        if shelf.isHidden {
            shelf.showAgain()
        } else {
            shelf.show()
            if shelf.state.isFolded {
                shelf.unfold(waitForEntry: true)
            }
        }
    }
}
