import CoreGraphics
import Foundation
import Testing
@testable import PinshelfCore

@Suite("浮いた棚を画面端にしまう")
struct DockLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let shelfSize = CGSize(width: 260, height: 230)

    @Test("ポインタを画面の端まで運んで放すと、その端にしまう")
    func pointerAtEdge() {
        let frame = CGRect(x: 40, y: 300, width: 260, height: 230)
        #expect(DockLayout.dockEdge(windowFrame: frame, pointer: CGPoint(x: 2, y: 500), screenFrame: screen, visibleFrame: visible) == .left)
        #expect(DockLayout.dockEdge(windowFrame: frame, pointer: CGPoint(x: 1438, y: 500), screenFrame: screen, visibleFrame: visible) == .right)
    }

    @Test("棚を端からはみ出させて放すと、その端にしまう")
    func overshoot() {
        let pastLeft = CGRect(x: -30, y: 300, width: 260, height: 230)
        #expect(DockLayout.dockEdge(windowFrame: pastLeft, pointer: CGPoint(x: 100, y: 400), screenFrame: screen, visibleFrame: visible) == .left)
        let pastRight = CGRect(x: 1200, y: 300, width: 260, height: 230)
        #expect(DockLayout.dockEdge(windowFrame: pastRight, pointer: CGPoint(x: 1300, y: 400), screenFrame: screen, visibleFrame: visible) == .right)
    }

    @Test("端に触れているだけ・画面の中ほどでは、しまわない")
    func notDocked() {
        let touching = CGRect(x: 0, y: 300, width: 260, height: 230)
        #expect(DockLayout.dockEdge(windowFrame: touching, pointer: CGPoint(x: 120, y: 400), screenFrame: screen, visibleFrame: visible) == nil)
        let middle = CGRect(x: 600, y: 300, width: 260, height: 230)
        #expect(DockLayout.dockEdge(windowFrame: middle, pointer: CGPoint(x: 700, y: 400), screenFrame: screen, visibleFrame: visible) == nil)
    }

    @Test("出てきた棚は、端から離して放したときだけ浮いた棚に戻る")
    func staysDocked() {
        #expect(DockLayout.staysDocked(windowFrame: CGRect(x: 10, y: 300, width: 260, height: 230), edge: .left, visibleFrame: visible))
        #expect(!DockLayout.staysDocked(windowFrame: CGRect(x: 80, y: 300, width: 260, height: 230), edge: .left, visibleFrame: visible))
        #expect(DockLayout.staysDocked(windowFrame: CGRect(x: 1170, y: 300, width: 260, height: 230), edge: .right, visibleFrame: visible))
        #expect(!DockLayout.staysDocked(windowFrame: CGRect(x: 1000, y: 300, width: 260, height: 230), edge: .right, visibleFrame: visible))
    }

    @Test("帯は端に寄せ、縦は見える範囲に収める")
    func tabFrame() {
        let right = DockLayout.frame(edge: .right, centerY: 400, size: DockLayout.tabSize, in: visible)
        #expect(right == CGRect(x: 1416, y: 360, width: 24, height: 80))
        let top = DockLayout.frame(edge: .left, centerY: 870, size: DockLayout.tabSize, in: visible)
        #expect(top == CGRect(x: 0, y: 795, width: 24, height: 80))
    }

    @Test("浮いた棚に戻すときは、端から少し離す")
    func undockedFrame() {
        let frame = DockLayout.undockedFrame(edge: .left, centerY: 400, size: shelfSize, in: visible)
        #expect(frame.minX == DockLayout.undockInset)
        #expect(frame.midY == 400)
    }

    @Test("ほかの帯と重ならない、いちばん近い位置に置く")
    func freeCenterY() {
        // 400 の位置には何もない
        #expect(DockLayout.freeCenterY(desired: 400, height: 80, occupied: [], in: visible) == 400)
        // 400 を中心に 80 の帯がある → すぐ上かすぐ下（近いほう）
        let occupied: [ClosedRange<CGFloat>] = [360...440]
        let center = DockLayout.freeCenterY(desired: 410, height: 80, occupied: occupied, in: visible)
        #expect(center == 440 + DockLayout.gap + 40)
        // 下の端に近くて下に入らないときは上へ
        let nearBottom = DockLayout.freeCenterY(desired: 40, height: 80, occupied: [0...80], in: visible)
        #expect(nearBottom == 80 + DockLayout.gap + 40)
    }
}

@Suite("しまった棚の保存")
struct DockPersistenceTests {
    @Test("しまった端と位置も保存して読める")
    func roundTrip() throws {
        let stored = StoredShelfWindow(
            id: UUID(),
            frame: CGRect(x: 40, y: 300, width: 260, height: 230),
            shelf: StoredShelf(),
            dockedEdge: .right,
            dockedCenterY: 512
        )
        let data = try JSONEncoder().encode(stored)
        #expect(try JSONDecoder().decode(StoredShelfWindow.self, from: data) == stored)
    }

    @Test("しまう機能を足す前の形式は、浮いた棚として読む")
    func olderFormat() throws {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","frame":[[100,200],[260,230]],"shelf":{"items":[]}}
        """
        let stored = try JSONDecoder().decode(StoredShelfWindow.self, from: Data(json.utf8))
        #expect(stored.dockedEdge == nil)
        #expect(stored.dockedCenterY == nil)
        #expect(stored.frame == CGRect(x: 100, y: 200, width: 260, height: 230))
    }
}
