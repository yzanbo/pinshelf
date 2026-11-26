import CoreGraphics
import Foundation
import Testing
@testable import PinshelfCore

/// テスト用のブックマーク（データの中身で場所を引く）
private struct FakeBookmarkCoding: BookmarkCoding {
    /// ブックマーク → 今の場所（ないものは見つからない扱い）
    var locations: [Data: URL] = [:]
    /// 古くなっているブックマーク
    var stale: Set<Data> = []
    /// パスで探したときに見つかるファイル
    var existingPaths: Set<String> = []

    func makeBookmark(for url: URL) -> Data? {
        Data(("bookmark:" + url.path).utf8)
    }

    func resolve(_ bookmark: Data) -> (url: URL, bookmark: Data)? {
        guard let url = locations[bookmark] else { return nil }
        return (url, stale.contains(bookmark) ? makeBookmark(for: url)! : bookmark)
    }

    func existingFile(atPath path: String) -> URL? {
        existingPaths.contains(path) ? URL(fileURLWithPath: path) : nil
    }
}

/// テストごとの一時フォルダ
private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "PinshelfTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite("棚の保存と復元")
struct ShelfArchiverTests {
    let fileA = URL(fileURLWithPath: "/Users/test/Desktop/a.png")
    let fileB = URL(fileURLWithPath: "/Users/test/Desktop/b.pdf")
    let link = URL(string: "https://example.com/page")!

    /// ファイル A・B とリンク・テキストを置いた棚と、そのブックマーク
    private func sampleShelf(coding: FakeBookmarkCoding) -> (Shelf, [ShelfItem.ID: Data]) {
        var shelf = Shelf()
        let added = shelf.add([.file(fileA), .file(fileB), .link(link), .text("メモ")], at: Date(timeIntervalSince1970: 1_000))
        var bookmarks: [ShelfItem.ID: Data] = [:]
        for item in added {
            if case .file(let url) = item.content {
                bookmarks[item.id] = coding.makeBookmark(for: url)
            }
        }
        return (shelf, bookmarks)
    }

    @Test("保存して戻すと、順番・ID・追加した日時・中身がそのまま戻る")
    func roundTrip() {
        var coding = FakeBookmarkCoding()
        coding.locations = [
            coding.makeBookmark(for: fileA)!: fileA,
            coding.makeBookmark(for: fileB)!: fileB,
        ]
        let (shelf, bookmarks) = sampleShelf(coding: coding)

        let restored = ShelfArchiver.restore(ShelfArchiver.archive(shelf, bookmarks: bookmarks), using: coding)

        #expect(restored.shelf == shelf)
        #expect(restored.bookmarks == bookmarks)
        #expect(restored.files == FileRestoreTally(byBookmark: 2))
    }

    @Test("ファイルが移動していたら、新しい場所で戻す")
    func followsMovedFile() {
        let moved = URL(fileURLWithPath: "/Users/test/Documents/a.png")
        var coding = FakeBookmarkCoding()
        coding.locations = [
            coding.makeBookmark(for: fileA)!: moved,
            coding.makeBookmark(for: fileB)!: fileB,
        ]
        let (shelf, bookmarks) = sampleShelf(coding: coding)

        let restored = ShelfArchiver.restore(ShelfArchiver.archive(shelf, bookmarks: bookmarks), using: coding)

        #expect(restored.shelf.items.first?.content == .file(moved))
        #expect(restored.shelf.items.first?.id == shelf.items.first?.id)
    }

    @Test("古くなったブックマークは作り直す")
    func refreshesStaleBookmark() {
        let moved = URL(fileURLWithPath: "/Users/test/Documents/a.png")
        var coding = FakeBookmarkCoding()
        let oldBookmark = coding.makeBookmark(for: fileA)!
        coding.locations = [oldBookmark: moved, coding.makeBookmark(for: fileB)!: fileB]
        coding.stale = [oldBookmark]
        let (shelf, bookmarks) = sampleShelf(coding: coding)

        let restored = ShelfArchiver.restore(ShelfArchiver.archive(shelf, bookmarks: bookmarks), using: coding)

        let id = shelf.items[0].id
        #expect(restored.bookmarks[id] == coding.makeBookmark(for: moved))
    }

    @Test("見つからないファイルは戻さず、ほかのものは戻す")
    func skipsMissingFile() {
        var coding = FakeBookmarkCoding()
        coding.locations = [coding.makeBookmark(for: fileB)!: fileB]
        let (shelf, bookmarks) = sampleShelf(coding: coding)

        let restored = ShelfArchiver.restore(ShelfArchiver.archive(shelf, bookmarks: bookmarks), using: coding)

        #expect(restored.files == FileRestoreTally(byBookmark: 1, missing: 1))
        #expect(restored.shelf.items.map(\.content) == [.file(fileB), .link(link), .text("メモ")])
    }

    @Test("ブックマークがなくても、パスにファイルがあれば戻してブックマークを作る")
    func fallsBackToPath() {
        var coding = FakeBookmarkCoding()
        coding.existingPaths = [fileA.path]
        var shelf = Shelf()
        shelf.add([.file(fileA)])

        let restored = ShelfArchiver.restore(ShelfArchiver.archive(shelf, bookmarks: [:]), using: coding)

        #expect(restored.shelf.items.map(\.content) == [.file(fileA)])
        #expect(restored.bookmarks[shelf.items[0].id] == coding.makeBookmark(for: fileA))
        #expect(restored.files == FileRestoreTally(byPath: 1))
    }

    @Test("ファイルをどう戻せたかの数は、棚をまたいで足し合わせられる")
    func talliesAddUp() {
        var files = FileRestoreTally(byBookmark: 2, missing: 1)
        files += FileRestoreTally(byBookmark: 1, byPath: 3)

        #expect(files == FileRestoreTally(byBookmark: 3, byPath: 3, missing: 1))
        #expect(files.total == 7)
        #expect(FileRestoreTally().total == 0)
    }
}

@Suite("保存ファイルの読み書き")
struct ShelfSnapshotStoreTests {
    @Test("ロックとスタックも保存して戻せる")
    func lockAndStackRoundTrip() {
        var shelf = Shelf()
        let items = shelf.add([.text("a"), .text("b")], stacked: true)
        shelf.setLocked(true, ids: [items[1].id])

        let restored = ShelfArchiver.restore(ShelfArchiver.archive(shelf, bookmarks: [:]), using: SystemBookmarkCoding())

        #expect(restored.shelf == shelf)
    }

    @Test("ロック・スタックを足す前の形式で保存したファイルも読める")
    func readsOlderFormat() throws {
        let json = """
        {"version":1,"edgeShelf":{"items":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","addedAt":0,"content":{"text":{"_0":"メモ"}}}]},"floatingShelves":[]}
        """
        let snapshot = try JSONDecoder().decode(ShelfSnapshot.self, from: Data(json.utf8))
        let item = try #require(snapshot.edgeShelf.items.first)
        #expect(item.content == .text("メモ"))
        #expect(!item.isLocked)
        #expect(item.stackID == nil)
    }

    @Test("棚の一覧は、前と同じ floatingShelves のキーで保存し、読める")
    func shelvesKeepStoredKey() throws {
        let json = """
        {"version":1,"edgeShelf":{"items":[]},"floatingShelves":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","frame":[[100,200],[260,230]],"shelf":{"items":[]}}]}
        """
        let snapshot = try JSONDecoder().decode(ShelfSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.shelves.count == 1)

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any]
        #expect(encoded?["floatingShelves"] != nil)
        #expect(encoded?["shelves"] == nil)
    }

    @Test("保存したものをそのまま読み込める")
    func saveAndLoad() throws {
        let directory = try makeTemporaryDirectory()
        // 保存先のフォルダがまだなくても作る
        let store = ShelfSnapshotStore(fileURL: directory.appending(path: "nested/shelves.json"))
        let snapshot = ShelfSnapshot(
            edgeShelf: StoredShelf(items: [
                StoredItem(id: UUID(), addedAt: Date(timeIntervalSince1970: 12.5), content: .file(path: "/tmp/a.png", bookmark: Data([1, 2, 3]))),
                StoredItem(id: UUID(), addedAt: Date(timeIntervalSince1970: 99), content: .text("こんにちは")),
            ]),
            edgeShelfEdge: .left,
            shelves: [
                StoredShelfWindow(
                    id: UUID(),
                    frame: CGRect(x: 100, y: 200, width: 260, height: 230),
                    shelf: StoredShelf(items: [
                        StoredItem(id: UUID(), addedAt: Date(timeIntervalSince1970: 7), content: .link(URL(string: "https://example.com")!)),
                    ])
                ),
            ]
        )

        try store.save(snapshot)
        let loaded = try store.load()

        #expect(loaded == snapshot)
    }

    @Test("まだ保存していなければ nil")
    func loadWithoutFile() throws {
        let store = ShelfSnapshotStore(fileURL: try makeTemporaryDirectory().appending(path: "shelves.json"))
        #expect(try store.load() == nil)
    }

    @Test("壊れたファイルは読み込みでエラーになり、脇へ移せる")
    func brokenFile() throws {
        let file = try makeTemporaryDirectory().appending(path: "shelves.json")
        try Data("{ broken".utf8).write(to: file)
        let store = ShelfSnapshotStore(fileURL: file)

        #expect(throws: (any Error).self) { try store.load() }

        let moved = try #require(store.moveAsideUnreadableFile(now: Date(timeIntervalSince1970: 1_700_000_000)))
        #expect(moved.lastPathComponent == "shelves.broken-1700000000.json")
        #expect(FileManager.default.fileExists(atPath: moved.path))
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("脇へ移した読めなかったファイルは、新しいものから 3 つだけ残す")
    func keepsFewUnreadableFiles() throws {
        let directory = try makeTemporaryDirectory()
        let file = directory.appending(path: "shelves.json")
        // 前に 4 回壊れて、脇へ移したファイルがある（ほかのファイルは消さない）
        for stamp in [1_000, 2_000, 3_000, 4_000] {
            try Data("x".utf8).write(to: directory.appending(path: "shelves.broken-\(stamp).json"))
        }
        try Data("keep".utf8).write(to: directory.appending(path: "other.json"))
        try Data("{ broken".utf8).write(to: file)

        ShelfSnapshotStore(fileURL: file).moveAsideUnreadableFile(now: Date(timeIntervalSince1970: 5_000))

        let names = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
        #expect(names == ["shelves.broken-5000.json", "shelves.broken-4000.json", "shelves.broken-3000.json", "other.json"])
    }
}

@Suite("macOS のブックマーク")
struct SystemBookmarkCodingTests {
    @Test("ファイルを移動・名前変更しても、ブックマークから新しい場所が分かる")
    func followsMovedFile() throws {
        let directory = try makeTemporaryDirectory()
        let original = directory.appending(path: "report.txt")
        try Data("hello".utf8).write(to: original)

        let coding = SystemBookmarkCoding()
        let bookmark = try #require(coding.makeBookmark(for: original))

        let subfolder = directory.appending(path: "moved", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        let moved = subfolder.appending(path: "renamed.txt")
        try FileManager.default.moveItem(at: original, to: moved)

        let resolved = try #require(coding.resolve(bookmark))
        #expect(resolved.url.resolvingSymlinksInPath().path == moved.resolvingSymlinksInPath().path)
    }

    @Test("消したファイルのブックマークは読み解けない")
    func deletedFile() throws {
        let directory = try makeTemporaryDirectory()
        let file = directory.appending(path: "gone.txt")
        try Data("bye".utf8).write(to: file)

        let coding = SystemBookmarkCoding()
        let bookmark = try #require(coding.makeBookmark(for: file))
        try FileManager.default.removeItem(at: file)

        #expect(coding.resolve(bookmark) == nil)
        #expect(coding.existingFile(atPath: file.path) == nil)
    }
}

@Suite("保存した棚の位置を画面に収める")
struct FitFrameTests {
    let main = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let second = CGRect(x: 1440, y: 0, width: 1920, height: 1055)

    @Test("画面の中にあればそのまま")
    func insideScreen() {
        let frame = CGRect(x: 100, y: 100, width: 260, height: 230)
        #expect(EdgeGeometry.fit(frame, into: [main, second]) == frame)
    }

    @Test("2 枚目の画面にあれば、2 枚目の画面のまま")
    func onSecondScreen() {
        let frame = CGRect(x: 2000, y: 300, width: 260, height: 230)
        #expect(EdgeGeometry.fit(frame, into: [main, second]) == frame)
    }

    @Test("はみ出していれば内側へ寄せる")
    func partlyOutside() {
        let frame = CGRect(x: -100, y: 800, width: 260, height: 230)
        #expect(EdgeGeometry.fit(frame, into: [main]) == CGRect(x: 0, y: 645, width: 260, height: 230))
    }

    @Test("外した画面にあった棚は、最初の画面の中央へ移す")
    func disconnectedScreen() {
        let frame = CGRect(x: 2000, y: 300, width: 260, height: 230)
        #expect(EdgeGeometry.fit(frame, into: [main]) == CGRect(x: 590, y: 322.5, width: 260, height: 230))
    }
}
