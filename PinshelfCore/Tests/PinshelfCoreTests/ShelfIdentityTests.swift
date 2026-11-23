import CoreGraphics
import Foundation
import Testing
@testable import PinshelfCore

@Suite("棚の名前")
struct ShelfNamingTests {
    @Test("仮の名前は、使っていないいちばん小さい番号にする")
    func defaultName() {
        #expect(ShelfNaming.defaultName(existing: []) == "棚 1")
        #expect(ShelfNaming.defaultName(existing: ["棚 1", "棚 2"]) == "棚 3")
        #expect(ShelfNaming.defaultName(existing: ["棚 2", "仕事"]) == "棚 1")
        #expect(ShelfNaming.defaultName(existing: ["棚 1", "棚 3"]) == "棚 2")
    }

    @Test("「棚 1」に似ているだけの名前は、番号として数えない")
    func ignoresLookalikes() {
        #expect(ShelfNaming.defaultName(existing: ["棚1", "棚 一", "本棚 1"]) == "棚 1")
    }

    @Test("入力した名前は前後の空白を除き、空なら名前なしにする")
    func normalized() {
        #expect(ShelfNaming.normalized("  資料  ") == "資料")
        #expect(ShelfNaming.normalized("   ") == nil)
        #expect(ShelfNaming.normalized(nil) == nil)
    }
}

@Suite("名前・色・お気に入りの保存")
struct ShelfIdentityPersistenceTests {
    @Test("名前・色・お気に入り・隠しているかを保存して読める")
    func roundTrip() throws {
        let stored = StoredShelfWindow(
            id: UUID(),
            frame: CGRect(x: 10, y: 20, width: 260, height: 230),
            shelf: StoredShelf(),
            name: "仕事",
            color: .blue,
            isFavorite: true,
            isHidden: true
        )
        let data = try JSONEncoder().encode(stored)
        #expect(try JSONDecoder().decode(StoredShelfWindow.self, from: data) == stored)
    }

    @Test("名前などを足す前の形式は、名前なし・色なし・お気に入りなしとして読む")
    func olderFormat() throws {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","frame":[[100,200],[260,230]],"shelf":{"items":[]},"dockedEdge":"left"}
        """
        let stored = try JSONDecoder().decode(StoredShelfWindow.self, from: Data(json.utf8))
        #expect(stored.name == nil)
        #expect(stored.color == ShelfColor.none)
        #expect(!stored.isFavorite)
        #expect(!stored.isHidden)
        #expect(!stored.isEdgeShelf)
        #expect(stored.dockedSize == nil)
        #expect(stored.keepsOpen == nil)
        #expect(stored.dockedEdge == .left)
    }

    @Test("画面端の棚の印を保存して読める")
    func edgeShelfRoundTrip() throws {
        let stored = StoredShelfWindow(
            id: UUID(),
            frame: CGRect(x: 0, y: 0, width: 260, height: 230),
            shelf: StoredShelf(),
            dockedEdge: .right,
            dockedCenterY: 300,
            isEdgeShelf: true,
            dockedSize: CGSize(width: 220, height: 420),
            keepsOpen: true
        )
        let data = try JSONEncoder().encode(stored)
        let decoded = try JSONDecoder().decode(StoredShelfWindow.self, from: data)
        #expect(decoded == stored)
        #expect(decoded.isEdgeShelf)
        #expect(decoded.dockedSize == CGSize(width: 220, height: 420))
        #expect(decoded.keepsOpen == true)
    }

    @Test("知らない色の名前は、色なしとして読む")
    func unknownColor() throws {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","frame":[[0,0],[260,230]],"shelf":{"items":[]},"color":"pink"}
        """
        let stored = try JSONDecoder().decode(StoredShelfWindow.self, from: Data(json.utf8))
        #expect(stored.color == ShelfColor.none)
    }
}
