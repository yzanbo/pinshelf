import Foundation

/// ファイルのブックマークを作る・読み解く
///
/// テストでは差し替えられるように、プロトコルにしてある。
public protocol BookmarkCoding: Sendable {
    /// ファイルのブックマークを作る（作れなければ nil）
    func makeBookmark(for url: URL) -> Data?
    /// ブックマークから今の場所を求める。古くなっていたら作り直したデータを返す（見つからなければ nil）
    func resolve(_ bookmark: Data) -> (url: URL, bookmark: Data)?
    /// ブックマークが使えないとき、パスでファイルを探す
    func existingFile(atPath path: String) -> URL?
}

/// macOS のブックマークを使う実装
///
/// サンドボックスの中で再起動後もファイルを開けるように、security-scoped bookmark を作る。
/// 使うには entitlement の `com.apple.security.files.bookmarks.app-scope` が要る。
/// 読み解いた URL を使う間は `startAccessingSecurityScopedResource()` を呼んでおく。
public struct SystemBookmarkCoding: BookmarkCoding {
    public init() {}

    public func makeBookmark(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            return data
        }
        // security-scoped が作れない環境（サンドボックスの外のテストなど）では、ふつうのブックマークにする
        return try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    public func resolve(_ bookmark: Data) -> (url: URL, bookmark: Data)? {
        var isStale = false
        let url = (try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )) ?? (try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ))
        guard let url else { return nil }
        guard isStale else { return (url, bookmark) }

        // ファイルが移動したなどでブックマークが古くなった: 今の場所で作り直す
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        return (url, makeBookmark(for: url) ?? bookmark)
    }

    public func existingFile(atPath path: String) -> URL? {
        FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
}
