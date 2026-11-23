import PinshelfCore
import SwiftUI

/// お気に入り一覧（お気に入りの棚を出す・お気に入りから削除する）
///
/// - ダブルクリック・return・行の「出す」ボタン: 棚を出す（出していれば前に出す）
/// - 右クリック・delete キー: お気に入りから削除（閉じていた棚は「最近閉じた棚」に入る）
struct FavoritesListView: View {
    let list: FavoriteShelvesList
    @State private var selection: Set<UUID> = []

    var body: some View {
        Group {
            if list.entries.isEmpty {
                ContentUnavailableView {
                    Label("お気に入りの棚はありません", systemImage: "star")
                } description: {
                    Text("棚の … メニューの「お気に入り（閉じても残す）」で足せます。お気に入りの棚は、閉じても中身ごと残ります。")
                }
            } else {
                VStack(spacing: 0) {
                    List(list.entries, selection: $selection) { entry in
                        FavoriteShelfRow(entry: entry) { list.show(entry.id) }
                    }
                    .contextMenu(forSelectionType: UUID.self) { ids in
                        if !ids.isEmpty {
                            Button(ids.count == 1 ? "出す" : "\(ids.count) 個の棚を出す") { show(ids) }
                            Divider()
                            Button(ids.count == 1 ? "お気に入りから削除" : "\(ids.count) 個の棚をお気に入りから削除") { remove(ids) }
                        }
                    } primaryAction: { ids in
                        show(ids)
                    }
                    .onDeleteCommand { remove(selection) }
                    Divider()
                    Text("ダブルクリックで出す・右クリックでお気に入りから削除")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
        }
        .frame(minWidth: 300, minHeight: 200)
    }

    private func show(_ ids: Set<UUID>) {
        ids.forEach(list.show)
    }

    private func remove(_ ids: Set<UUID>) {
        ids.forEach(list.remove)
        selection.subtract(ids)
    }
}

/// お気に入り一覧の 1 行（色・名前・件数・出しているか・出すボタン）
private struct FavoriteShelfRow: View {
    let entry: FavoriteShelfEntry
    let show: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: entry.color.menuImage)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .lineLimit(1)
                Text("\(entry.count) 個・\(entry.isVisible ? "出している" : "閉じている")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(entry.isVisible ? "前に出す" : "出す", action: show)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
        .help(entry.isVisible ? "出している棚を前に出す" : "閉じている棚を、閉じたときの場所に出す")
    }
}
