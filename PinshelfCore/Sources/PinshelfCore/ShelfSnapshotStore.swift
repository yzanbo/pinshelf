import Foundation

/// 棚の保存内容を JSON ファイルに読み書きする
public struct ShelfSnapshotStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// 既定の保存場所（Application Support/Pinshelf/shelves.json）
    ///
    /// サンドボックスの中では、アプリのコンテナの中になる。
    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appending(path: "Pinshelf", directoryHint: .isDirectory).appending(path: "shelves.json")
    }

    /// 読み込む。まだ保存していなければ nil
    public func load() throws -> ShelfSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ShelfSnapshot.self, from: data)
    }

    /// 保存する（途中で落ちても壊れないよう、書き終えてから置き換える）
    public func save(_ snapshot: ShelfSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    /// 読めなかったファイルを脇へ移す（次の保存で上書きして失わないように）
    /// - Returns: 移した先
    @discardableResult
    public func moveAsideUnreadableFile(now: Date = .now) -> URL? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let stamp = Int(now.timeIntervalSince1970)
        let destination = fileURL.deletingPathExtension().appendingPathExtension("broken-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
