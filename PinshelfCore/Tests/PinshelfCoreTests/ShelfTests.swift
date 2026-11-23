import Foundation
import Testing
@testable import PinshelfCore

@Suite("棚の中身")
struct ShelfTests {
    let fileA = URL(fileURLWithPath: "/Users/test/Desktop/a.png")
    let fileB = URL(fileURLWithPath: "/Users/test/Desktop/b.pdf")

    @Test("置いた順に並ぶ")
    func addKeepsOrder() {
        var shelf = Shelf()
        let added = shelf.add([.file(fileA), .file(fileB), .text("メモ")])
        #expect(added.count == 3)
        #expect(added.map(\.id) == shelf.items.map(\.id))
        #expect(shelf.items.map(\.content) == [.file(fileA), .file(fileB), .text("メモ")])
    }

    @Test("同じファイルは 2 つ置かない（パスの表記ゆれもそろえる）")
    func addSkipsDuplicates() {
        var shelf = Shelf()
        shelf.add([.file(fileA)])
        let sameFile = URL(fileURLWithPath: "/Users/test/Desktop/../Desktop/a.png")
        let added = shelf.add([.file(sameFile), .file(fileA), .file(fileB)])
        #expect(added.map(\.content) == [.file(fileB)])
        #expect(shelf.items.count == 2)
    }

    @Test("同じ URL でもファイルとリンクは別のものとして扱う")
    func fileAndLinkAreDifferent() {
        var shelf = Shelf()
        let link = URL(string: "https://example.com/a.png")!
        shelf.add([.link(link), .link(link), .text("https://example.com/a.png")])
        #expect(shelf.items.count == 2)
    }

    @Test("1 つ取り除く・すべて取り除く")
    func remove() {
        var shelf = Shelf()
        shelf.add([.file(fileA), .file(fileB)])
        shelf.remove(id: shelf.items[0].id)
        #expect(shelf.items.map(\.content) == [.file(fileB)])
        shelf.add([.text("a"), .text("b")])
        shelf.remove(ids: Set(shelf.items.filter { $0.content != .text("b") }.map(\.id)))
        #expect(shelf.items.map(\.content) == [.text("b")])
        shelf.removeAll()
        #expect(shelf.isEmpty)
    }
}

@Suite("設定の読み込み")
struct TriggerSettingsTests {
    @Test("保存がなければ初期値（両方・近いほう・ドラッグ開始時・軽く）")
    func defaults() {
        let settings = TriggerSettings(reading: { _ in nil })
        #expect(settings == .defaults)
        #expect(settings.triggerMode == .both)
        #expect(settings.shakeSensitivity == .light)
        #expect(settings.triggerModifier == .shift)
        #expect(settings.edgeVerticalPosition == .cursor)
    }

    @Test("保存した値を読み、壊れた値は初期値にする")
    func readsStoredValues() {
        let stored = [
            TriggerSettings.Key.triggerMode: "shake",
            TriggerSettings.Key.edgePreference: "left",
            TriggerSettings.Key.edgeRevealTiming: "broken",
            TriggerSettings.Key.shakeSensitivity: "firm",
            TriggerSettings.Key.triggerModifier: "control",
            TriggerSettings.Key.edgeVerticalPosition: "top",
        ]
        let settings = TriggerSettings(reading: { stored[$0] })
        #expect(settings.triggerMode == .shake)
        #expect(settings.edgePreference == .left)
        #expect(settings.edgeRevealTiming == .onDragStart)
        #expect(settings.shakeSensitivity == .firm)
        #expect(settings.triggerModifier == .control)
        #expect(settings.edgeVerticalPosition == .top)
    }

    @Test("出し方ごとに、使うきっかけが決まる")
    func modeFlags() {
        #expect(TriggerMode.edge.usesEdge && !TriggerMode.edge.usesShake)
        #expect(!TriggerMode.shake.usesEdge && TriggerMode.shake.usesShake)
        #expect(TriggerMode.both.usesEdge && TriggerMode.both.usesShake)
        #expect(!TriggerMode.off.usesEdge && !TriggerMode.off.usesShake)
    }

    @Test("2 つのスイッチから出し方を組み立てると、元に戻る")
    func modeFromSwitches() {
        for mode in TriggerMode.allCases {
            #expect(TriggerMode(usesEdge: mode.usesEdge, usesShake: mode.usesShake) == mode)
        }
    }
}
