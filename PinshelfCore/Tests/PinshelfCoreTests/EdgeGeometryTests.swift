import CoreGraphics
import Testing
@testable import PinshelfCore

@Suite("棚の位置の計算")
struct EdgeGeometryTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    @Test("「近いほう」はカーソルに近い端を選ぶ")
    func nearestEdge() {
        #expect(EdgeGeometry.edge(forCursor: CGPoint(x: 100, y: 400), in: screen, preference: .nearest) == .left)
        #expect(EdgeGeometry.edge(forCursor: CGPoint(x: 1300, y: 400), in: screen, preference: .nearest) == .right)
    }

    @Test("端を決めてあるときはカーソルの位置によらない")
    func fixedEdge() {
        #expect(EdgeGeometry.edge(forCursor: CGPoint(x: 1300, y: 400), in: screen, preference: .left) == .left)
        #expect(EdgeGeometry.edge(forCursor: CGPoint(x: 100, y: 400), in: screen, preference: .right) == .right)
    }

    @Test("2 枚目の画面（原点がずれた画面）でも近い端を選ぶ")
    func secondaryScreen() {
        let second = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
        #expect(EdgeGeometry.edge(forCursor: CGPoint(x: 1500, y: 0), in: second, preference: .nearest) == .left)
        #expect(EdgeGeometry.edge(forCursor: CGPoint(x: 3300, y: 0), in: second, preference: .nearest) == .right)
    }

    @Test("端から決めた距離の内側に入ったら「近づいた」と見なす")
    func approaching() {
        #expect(EdgeGeometry.isApproaching(CGPoint(x: 1300, y: 400), edge: .right, in: screen))
        #expect(!EdgeGeometry.isApproaching(CGPoint(x: 1200, y: 400), edge: .right, in: screen))
        #expect(EdgeGeometry.isApproaching(CGPoint(x: 0, y: 400), edge: .left, in: screen))
    }

    @Test("端の棚は端に寄せて縦の中央に置く")
    func edgeFrame() {
        let size = CGSize(width: 150, height: 380)
        let right = EdgeGeometry.edgeFrame(size: size, edge: .right, in: visible, vertical: .middle, anchorY: nil)
        #expect(right == CGRect(x: 1290, y: 247.5, width: 150, height: 380))
        let left = EdgeGeometry.edgeFrame(size: size, edge: .left, in: visible, vertical: .middle, anchorY: nil)
        #expect(left.minX == 0)
    }

    @Test("画面より高い棚は画面の高さに縮める")
    func edgeFrameClampsHeight() {
        let small = CGRect(x: 0, y: 0, width: 800, height: 300)
        let frame = EdgeGeometry.edgeFrame(size: CGSize(width: 150, height: 380), edge: .left, in: small, vertical: .middle, anchorY: nil)
        #expect(frame.height == 300)
        #expect(frame.minY == 0)
    }

    @Test("カーソルの棚が画面の角ではみ出すときは内側に寄せる")
    func centeredFrameClamps() {
        let size = CGSize(width: 240, height: 220)
        let corner = EdgeGeometry.frame(centeredAt: CGPoint(x: 1430, y: 10), size: size, in: visible)
        #expect(corner == CGRect(x: 1200, y: 0, width: 240, height: 220))
        let middle = EdgeGeometry.frame(centeredAt: CGPoint(x: 700, y: 400), size: size, in: visible)
        #expect(middle == CGRect(x: 580, y: 290, width: 240, height: 220))
    }

    @Test("上・下はその端にそろえ、帯と広げた棚で端の位置が変わらない")
    func topAndBottom() {
        let tab = CGSize(width: 24, height: 96)
        let expanded = CGSize(width: 156, height: 400)
        let topTab = EdgeGeometry.edgeFrame(size: tab, edge: .right, in: visible, vertical: .top, anchorY: nil)
        let topExpanded = EdgeGeometry.edgeFrame(size: expanded, edge: .right, in: visible, vertical: .top, anchorY: nil)
        #expect(topTab.maxY == visible.maxY - EdgeGeometry.verticalMargin)
        #expect(topExpanded.maxY == topTab.maxY)

        let bottomTab = EdgeGeometry.edgeFrame(size: tab, edge: .left, in: visible, vertical: .bottom, anchorY: nil)
        #expect(bottomTab.minY == visible.minY + EdgeGeometry.verticalMargin)
        #expect(bottomTab.minX == 0)
    }

    @Test("真ん中は、カーソルの高さにかかわらず同じ位置")
    func middleIgnoresAnchor() {
        let size = CGSize(width: 150, height: 380)
        #expect(EdgeGeometry.edgeFrame(size: size, edge: .right, in: visible, vertical: .middle, anchorY: 100)
            == EdgeGeometry.edgeFrame(size: size, edge: .right, in: visible, vertical: .middle, anchorY: nil))
    }

    @Test("カーソルの高さを中心にし、画面の上下ではみ出す分は寄せる")
    func cursorHeight() {
        let tab = CGSize(width: 24, height: 96)
        let atCursor = EdgeGeometry.edgeFrame(size: tab, edge: .right, in: visible, vertical: .cursor, anchorY: 300)
        #expect(atCursor.midY == 300)
        let nearTop = EdgeGeometry.edgeFrame(size: tab, edge: .right, in: visible, vertical: .cursor, anchorY: 870)
        #expect(nearTop.maxY == visible.maxY)
        let nearBottom = EdgeGeometry.edgeFrame(size: tab, edge: .right, in: visible, vertical: .cursor, anchorY: 5)
        #expect(nearBottom.minY == visible.minY)
        // 高さが分からなければ真ん中
        let unknown = EdgeGeometry.edgeFrame(size: tab, edge: .right, in: visible, vertical: .cursor, anchorY: nil)
        #expect(unknown.midY == visible.midY)
    }
}
