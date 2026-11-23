import Foundation
import Testing
@testable import PinshelfCore

@Suite("スタック")
struct StackTests {
    let a = ShelfItemContent.text("a")
    let b = ShelfItemContent.text("b")
    let c = ShelfItemContent.text("c")
    let d = ShelfItemContent.text("d")

    @Test("一緒に置いた 2 つ以上は 1 つのスタックになる")
    func stackedAdd() {
        var shelf = Shelf()
        let added = shelf.add([a, b, c], stacked: true)
        #expect(Set(added.map(\.stackID)).count == 1)
        #expect(added.first?.stackID != nil)
        #expect(shelf.units.count == 1)
        #expect(shelf.units.first?.count == 3)
    }

    @Test("1 つだけ・重複で 1 つになったときはスタックにしない")
    func singleIsNotStacked() {
        var shelf = Shelf()
        shelf.add([a])
        let added = shelf.add([a, b], stacked: true)
        #expect(added.count == 1)
        #expect(added.first?.stackID == nil)
    }

    @Test("スタックにしない設定なら、1 つずつ並ぶ")
    func unstackedAdd() {
        var shelf = Shelf()
        shelf.add([a, b])
        #expect(shelf.units.count == 2)
    }

    @Test("選んだものを最初のものの位置に寄せてスタックにし、分けられる")
    func stackAndUnstack() {
        var shelf = Shelf()
        let items = shelf.add([a, b, c, d])
        shelf.stack(ids: [items[1].id, items[3].id])
        #expect(shelf.items.map(\.content) == [a, b, d, c])
        #expect(shelf.units.map(\.count) == [1, 2, 1])

        shelf.unstack(containing: [items[3].id])
        #expect(shelf.units.map(\.count) == [1, 1, 1, 1])
    }

    @Test("2 つ未満はスタックにできない")
    func stackNeedsTwo() {
        var shelf = Shelf()
        let items = shelf.add([a, b])
        #expect(shelf.stack(ids: [items[0].id]) == nil)
    }

    @Test("スタックに 1 つだけ残ったら、ふつうの 1 つとして並ぶ")
    func lonelyStackMember() {
        var shelf = Shelf()
        let items = shelf.add([a, b], stacked: true)
        shelf.remove(id: items[0].id)
        #expect(shelf.units.map(\.count) == [1])
    }
}

@Suite("取り除いたものを戻す")
struct RemovalTests {
    @Test("取り除いたものを元の位置に戻す")
    func restoreAtOriginalPositions() {
        var shelf = Shelf()
        let items = shelf.add((0..<5).map { .text("\($0)") })
        let removal = shelf.remove(ids: [items[1].id, items[3].id])
        #expect(shelf.items.map(\.id) == [items[0].id, items[2].id, items[4].id])

        let restored = shelf.restore(removal)

        #expect(restored.count == 2)
        #expect(shelf.items.map(\.id) == items.map(\.id))
    }

    @Test("すべて取り除いても戻せる")
    func restoreAll() {
        var shelf = Shelf()
        let items = shelf.add([.text("a"), .text("b")])
        let removal = shelf.removeAll()
        shelf.restore(removal)
        #expect(shelf.items.map(\.id) == items.map(\.id))
    }

    @Test("戻すまでに同じものを置き直していたら、それは戻さない")
    func skipDuplicates() {
        var shelf = Shelf()
        shelf.add([.text("a"), .text("b")])
        let removal = shelf.removeAll()
        shelf.add([.text("a")])

        let restored = shelf.restore(removal)

        #expect(restored.map(\.content) == [.text("b")])
        #expect(shelf.items.count == 2)
    }

    @Test("ロックとスタックも一緒に戻る")
    func keepsLockAndStack() {
        var shelf = Shelf()
        let items = shelf.add([.text("a"), .text("b")], stacked: true)
        shelf.setLocked(true, ids: [items[0].id])
        let removal = shelf.removeAll()
        shelf.restore(removal)
        #expect(shelf.items[0].isLocked)
        #expect(shelf.units.count == 1)
    }
}

@Suite("ロック")
struct LockTests {
    @Test("ロックする・外す")
    func toggle() {
        var shelf = Shelf()
        let items = shelf.add([.text("a"), .text("b")])
        shelf.setLocked(true, ids: [items[1].id])
        #expect(shelf.items.map(\.isLocked) == [false, true])
        shelf.setLocked(false, ids: [items[1].id])
        #expect(shelf.items.map(\.isLocked) == [false, false])
    }

    @Test("中身を差し替えても、ID・ロック・スタックはそのまま")
    func replaceContentKeepsAttributes() {
        var shelf = Shelf()
        let items = shelf.add([.file(URL(fileURLWithPath: "/a.png")), .text("b")], stacked: true)
        shelf.setLocked(true, ids: [items[0].id])
        let moved = URL(fileURLWithPath: "/Users/test/a.png")

        shelf.replaceContent(of: items[0].id, with: .file(moved))

        #expect(shelf.items[0].id == items[0].id)
        #expect(shelf.items[0].content == .file(moved))
        #expect(shelf.items[0].isLocked)
        #expect(shelf.items[0].stackID == items[0].stackID)
    }
}

@Suite("取り出したあとの決まり")
struct DragOutRuleTests {
    let file = ShelfItem(content: .file(URL(fileURLWithPath: "/a.png")))
    var lockedFile: ShelfItem {
        var item = file
        item.isLocked = true
        return item
    }

    @Test("「取り出したら外す」がオンなら、取り出した直後に外す（ロックしたものは残す）")
    func immediate() {
        #expect(DragOutRule.immediate(for: file, removesCopiedItems: true) == .remove)
        #expect(DragOutRule.immediate(for: lockedFile, removesCopiedItems: true) == .keep)
        #expect(DragOutRule.immediate(for: file, removesCopiedItems: false) == .keep)
    }

    @Test("ファイルがなくなっていたら外し、ロックしたものは新しい場所へ付け替える")
    func afterCheck() {
        #expect(DragOutRule.afterCheck(for: file, fileIsGone: true) == .remove)
        #expect(DragOutRule.afterCheck(for: lockedFile, fileIsGone: true) == .relocate)
        #expect(DragOutRule.afterCheck(for: file, fileIsGone: false) == .keep)
        #expect(DragOutRule.afterCheck(for: ShelfItem(content: .text("a")), fileIsGone: true) == .keep)
    }

    @Test("ほかの棚へ移したとき、ロックしたものは元の棚にも残す")
    func movedToAnotherShelf() {
        #expect(DragOutRule.afterMovingToAnotherShelf(file) == .remove)
        #expect(DragOutRule.afterMovingToAnotherShelf(lockedFile) == .keep)
    }
}

@Suite("棚のふるまいの設定")
struct ShelfBehaviorSettingsTests {
    @Test("保存がなければ初期値（取り出しても外さない・スタックにまとめる・除外なし）")
    func defaults() {
        let settings = ShelfBehaviorSettings(reading: { _ in nil })
        #expect(settings == .defaults)
        #expect(!settings.removesCopiedItems)
        #expect(settings.stackMultipleDrops)
        #expect(settings.ignoredBundleIDs.isEmpty)
        #expect(settings.inboxDestination == .newShelf)
        #expect(settings.clipboardShortcut == .optionShiftV)
        #expect(settings.foldsNewShelves)
        #expect(settings.docksWhenDraggedToEdge)
        #expect(settings.remembersResizedSize)
    }

    @Test("保存した値を読み、型の違う値は初期値にする")
    func readsStoredValues() {
        let stored: [String: Any] = [
            ShelfBehaviorSettings.Key.removesCopiedItems: true,
            ShelfBehaviorSettings.Key.stackMultipleDrops: "broken",
            ShelfBehaviorSettings.Key.ignoredApplications: ["com.figma.Desktop"],
            ShelfBehaviorSettings.Key.inboxDestination: "edgeShelf",
            ShelfBehaviorSettings.Key.clipboardShortcut: "off",
            ShelfBehaviorSettings.Key.foldsNewShelves: false,
            ShelfBehaviorSettings.Key.docksWhenDraggedToEdge: false,
            ShelfBehaviorSettings.Key.remembersResizedSize: false,
        ]
        let settings = ShelfBehaviorSettings(reading: { stored[$0] })
        #expect(settings.removesCopiedItems)
        #expect(settings.stackMultipleDrops)
        #expect(settings.ignoredBundleIDs == ["com.figma.Desktop"])
        #expect(settings.inboxDestination == .edgeShelf)
        #expect(settings.clipboardShortcut == .off)
        #expect(!settings.foldsNewShelves)
        #expect(!settings.docksWhenDraggedToEdge)
        #expect(!settings.remembersResizedSize)
    }
}

@Suite("自動では出さないアプリ")
struct TriggerPolicyTests {
    let ignored = ["com.figma.Desktop"]

    @Test("除外したアプリでドラッグを始めたら、自動では出さない")
    func ignoredApp() {
        #expect(!TriggerPolicy.allowsAutomaticShelf(frontmostBundleID: "com.figma.Desktop", startedInPinshelf: false, ignored: ignored))
        #expect(TriggerPolicy.allowsAutomaticShelf(frontmostBundleID: "com.apple.finder", startedInPinshelf: false, ignored: ignored))
    }

    @Test("棚から始まったドラッグは、いつも出す（棚から棚へ移せるように）")
    func fromShelf() {
        #expect(TriggerPolicy.allowsAutomaticShelf(frontmostBundleID: "com.figma.Desktop", startedInPinshelf: true, ignored: ignored))
    }

    @Test("前面のアプリが分からないときは出す")
    func unknownApp() {
        #expect(TriggerPolicy.allowsAutomaticShelf(frontmostBundleID: nil, startedInPinshelf: false, ignored: ignored))
    }
}

@Suite("ほかの棚から中身を移す")
struct TransferTests {
    @Test("ロック・スタック・ID・追加した日時ごと移す")
    func keepsAttributes() {
        var source = Shelf()
        let items = source.add([.text("a"), .text("b")], at: Date(timeIntervalSince1970: 100), stacked: true)
        source.setLocked(true, ids: [items[0].id])

        var destination = Shelf()
        let moved = destination.append(source.items)

        #expect(moved == source.items)
        #expect(destination.items == source.items)
        #expect(destination.units.count == 1)
    }

    @Test("すでに同じものがあれば加えない")
    func skipsDuplicates() {
        var destination = Shelf()
        destination.add([.text("a")])
        let moved = destination.append([ShelfItem(content: .text("a")), ShelfItem(content: .text("b"))])
        #expect(moved.map(\.content) == [.text("b")])
        #expect(destination.items.count == 2)
    }
}
