import Foundation
import Observation

/// お気に入り一覧に出す、お気に入りの棚
///
/// 棚が変わる（お気に入りにする・外す・閉じる・名前や色・中身が変わる）たびに、AppCoordinator が読み直す。
/// 出す・削除するは、AppCoordinator に任せる
@Observable
final class FavoriteShelvesList {
    private(set) var entries: [FavoriteShelfEntry] = []

    /// 今のお気に入りの棚を読む
    @ObservationIgnored var load: () -> [FavoriteShelfEntry] = { [] }
    /// お気に入りの棚を出す
    @ObservationIgnored var onShow: (UUID) -> Void = { _ in }
    /// お気に入りから削除する
    @ObservationIgnored var onRemove: (UUID) -> Void = { _ in }

    /// 読み直す（変わっていなければ、一覧は描き直さない）
    func reload() {
        let latest = load()
        if latest != entries {
            entries = latest
        }
    }

    func show(_ id: UUID) {
        onShow(id)
    }

    func remove(_ id: UUID) {
        onRemove(id)
    }
}
