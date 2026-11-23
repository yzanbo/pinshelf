import Foundation
import OSLog
import PinshelfCore

/// 棚の中身をファイルに保存する・起動時に読み込む
///
/// 変更のたびに書き込まず、変更が落ち着いてから（0.5 秒後に）まとめて保存する。
final class ShelfPersistence {
    /// 保存する内容を作る
    var makeSnapshot: (() -> ShelfSnapshot)?

    private let store: ShelfSnapshotStore
    private var pendingSave: Task<Void, Never>?
    private let logger = Logger(subsystem: "app.pinshelf.Pinshelf", category: "persistence")

    private static let saveDelay: Duration = .milliseconds(500)

    init(store: ShelfSnapshotStore = ShelfSnapshotStore(fileURL: ShelfSnapshotStore.defaultFileURL())) {
        self.store = store
    }

    /// 保存してある内容を読み込む（なければ nil）
    func load() -> ShelfSnapshot? {
        do {
            return try store.load()
        } catch {
            // 読めないファイルは脇へ移して、次の保存で上書きしないようにする
            let movedTo = store.moveAsideUnreadableFile()
            logger.error("棚の保存ファイルを読めませんでした: \(error.localizedDescription, privacy: .public) 移した先: \(movedTo?.path ?? "なし", privacy: .public)")
            return nil
        }
    }

    /// 戻せなかったファイルの数を記録する（原因を調べるため）
    func reportMissingFiles(_ count: Int) {
        guard count > 0 else { return }
        logger.notice("見つからなかったファイルを \(count) 個、棚に戻しませんでした")
    }

    /// 少し待ってから保存する（続けて呼ばれたら、最後の 1 回だけ保存する）
    func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    /// すぐに保存する（終了するときなど）
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let snapshot = makeSnapshot?() else { return }
        do {
            try store.save(snapshot)
        } catch {
            logger.error("棚を保存できませんでした: \(error.localizedDescription, privacy: .public)")
        }
    }
}
