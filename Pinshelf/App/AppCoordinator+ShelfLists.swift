import AppKit
import PinshelfCore

/// お気に入りの棚（メニューバー・お気に入り一覧に出す）
struct FavoriteShelfEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let color: ShelfColor
    let count: Int
    /// 今出しているか（閉じて隠していれば false）
    let isVisible: Bool
}

/// 最近閉じた棚（メニューバーに出す）
struct RecentShelfEntry {
    let id: UUID
    let title: String
    let color: ShelfColor
    let count: Int
    let closedAt: Date
}

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
        shelvesDidChange()
    }

    /// 最近閉じた棚をすべて忘れる
    func clearRecentShelves() {
        recentShelves.clear()
        shelvesDidChange()
    }

    // MARK: - お気に入りの棚

    /// お気に入りの棚の一覧（メニューバー・お気に入り一覧に出す）
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

    /// お気に入りの棚を出す（出していれば前に出す）
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

    /// お気に入りから削除する
    ///
    /// 出している棚は、ふつうの棚としてそのまま残す。閉じて隠していた棚は、そのまま閉じる
    /// （お気に入りでなくなるので「最近閉じた棚」に入り、そこから開き直せる。空の棚は入らない）
    func removeFavorite(id: UUID) {
        guard let shelf = shelves.first(where: { $0.id == id }), shelf.state.isFavorite else { return }
        shelf.setFavorite(false)
        if shelf.isHidden {
            shelf.discard()
        }
    }
}
