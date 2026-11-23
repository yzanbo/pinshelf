import Foundation
import Testing
@testable import PinshelfCore

@Suite("クリップボードの画像のファイル")
struct ClipboardFilesTests {
    @Test("画像のファイル名に日時を入れる")
    func imageFileName() {
        let date = Date(timeIntervalSince1970: 1_795_000_000) // 2026-11-18 11:06:40 UTC
        let name = ClipboardFiles.imageFileName(at: date, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        #expect(name == "クリップボード 2026-11-18 20.06.40.png")
    }

    @Test("同じ名前があれば番号を付ける")
    func uniqueName() {
        let name = "クリップボード 2026-11-18 17.26.40.png"
        #expect(ClipboardFiles.uniqueName(name, existing: []) == name)
        #expect(ClipboardFiles.uniqueName(name, existing: [name]) == "クリップボード 2026-11-18 17.26.40 2.png")
        #expect(ClipboardFiles.uniqueName(name, existing: [name, "クリップボード 2026-11-18 17.26.40 2.png"])
            == "クリップボード 2026-11-18 17.26.40 3.png")
    }

    @Test("どの棚にも置いていないファイルだけを片付ける")
    func unreferenced() {
        let folder = URL(fileURLWithPath: "/tmp/Pinshelf/Clipboard")
        let kept = folder.appending(path: "a.png")
        let stale = folder.appending(path: "b.png")
        let result = ClipboardFiles.unreferenced([kept, stale], referencedPaths: [kept.path])
        #expect(result == [stale])
    }

    @Test("入れたばかりの画像は、どの棚にも置いていなくても 1 分は残す")
    func gracePeriod() {
        let folder = URL(fileURLWithPath: "/tmp/Pinshelf/Clipboard")
        let now = Date(timeIntervalSince1970: 1_000_000)
        let onShelf = (url: folder.appending(path: "a.png"), modified: now.addingTimeInterval(-3600))
        let old = (url: folder.appending(path: "b.png"), modified: now.addingTimeInterval(-61))
        let fresh = (url: folder.appending(path: "c.png"), modified: now.addingTimeInterval(-10))
        let plan = ClipboardFiles.cleanUpPlan([onShelf, old, fresh], referencedPaths: [onShelf.url.path], now: now)
        #expect(plan.removable == [old.url])
        #expect(plan.waiting == [fresh.url])
    }

    @Test("ショートカットの表示")
    func shortcutSymbols() {
        #expect(ClipboardShortcut.optionShiftV.symbol == "⌥⇧V")
        #expect(ClipboardShortcut.off.symbol.isEmpty)
    }
}
