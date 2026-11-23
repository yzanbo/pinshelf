import CoreGraphics
import Foundation
import Testing
@testable import PinshelfCore

/// 中身が n 個の、保存した浮いた棚
private func storedShelf(id: UUID = UUID(), items: Int = 1, name: String? = nil) -> StoredShelfWindow {
    StoredShelfWindow(
        id: id,
        frame: CGRect(x: 100, y: 100, width: 260, height: 230),
        shelf: StoredShelf(items: (0..<items).map {
            StoredItem(id: UUID(), addedAt: Date(timeIntervalSince1970: 0), content: .text("item \($0)"))
        }),
        name: name
    )
}

@Suite("最近閉じた棚")
struct RecentShelvesTests {
    @Test("閉じた棚を新しい順に覚える")
    func newestFirst() {
        var recent = RecentShelves()
        let first = storedShelf(name: "1")
        let second = storedShelf(name: "2")
        recent.record(first, closedAt: Date(timeIntervalSince1970: 10))
        recent.record(second, closedAt: Date(timeIntervalSince1970: 20))
        #expect(recent.entries.map(\.shelf.name) == ["2", "1"])
        #expect(recent.entries.first?.closedAt == Date(timeIntervalSince1970: 20))
    }

    @Test("覚えている棚に置いていたファイルのパスが分かる（テキストなどは含めない）")
    func filePaths() {
        var recent = RecentShelves()
        let shelf = StoredShelfWindow(
            id: UUID(),
            frame: CGRect(x: 100, y: 100, width: 260, height: 230),
            shelf: StoredShelf(items: [
                StoredItem(id: UUID(), addedAt: Date(timeIntervalSince1970: 0), content: .file(path: "/tmp/a.png", bookmark: nil)),
                StoredItem(id: UUID(), addedAt: Date(timeIntervalSince1970: 0), content: .text("memo")),
            ])
        )
        recent.record(shelf)
        #expect(recent.filePaths == ["/tmp/a.png"])
    }

    @Test("空の棚は覚えない")
    func skipsEmpty() {
        var recent = RecentShelves()
        recent.record(storedShelf(items: 0))
        #expect(recent.isEmpty)
    }

    @Test("覚えるのは 10 個まで（古いものから忘れる）")
    func limit() {
        var recent = RecentShelves()
        for index in 0..<12 {
            recent.record(storedShelf(name: "\(index)"))
        }
        #expect(recent.entries.count == RecentShelves.limit)
        #expect(recent.entries.first?.shelf.name == "11")
        #expect(recent.entries.last?.shelf.name == "2")
    }

    @Test("同じ棚をもう一度閉じたら、前のものと入れ替えて先頭にする")
    func replacesSameShelf() {
        var recent = RecentShelves()
        let id = UUID()
        recent.record(storedShelf(id: id, items: 1, name: "古い"))
        recent.record(storedShelf(name: "ほか"))
        recent.record(storedShelf(id: id, items: 3, name: "新しい"))
        #expect(recent.entries.count == 2)
        #expect(recent.entries.first?.shelf.name == "新しい")
        #expect(recent.entries.first?.shelf.shelf.items.count == 3)
    }

    @Test("開き直すと一覧から外れ、すべて忘れることもできる")
    func takeAndClear() {
        var recent = RecentShelves()
        let shelf = storedShelf()
        recent.record(shelf)
        recent.record(storedShelf())
        #expect(recent.take(id: shelf.id)?.shelf == shelf)
        #expect(recent.take(id: shelf.id) == nil)
        #expect(recent.entries.count == 1)
        recent.clear()
        #expect(recent.isEmpty)
    }

    @Test("最近閉じた棚も保存して読める。足す前の形式は空として読む")
    func persistence() throws {
        var recent = RecentShelves()
        recent.record(storedShelf(name: "仕事"), closedAt: Date(timeIntervalSince1970: 1_000))
        let snapshot = ShelfSnapshot(recentlyClosed: recent.entries)
        let decoded = try JSONDecoder().decode(ShelfSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(decoded == snapshot)

        let older = #"{"version":1,"edgeShelf":{"items":[]},"floatingShelves":[]}"#
        let legacy = try JSONDecoder().decode(ShelfSnapshot.self, from: Data(older.utf8))
        #expect(legacy.recentlyClosed.isEmpty)
    }
}
