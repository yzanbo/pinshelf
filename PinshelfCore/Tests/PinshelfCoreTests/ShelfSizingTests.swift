import CoreGraphics
import Foundation
import Testing
@testable import PinshelfCore

@Suite("棚の大きさを変える")
struct ShelfSizingTests {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let frame = CGRect(x: 400, y: 300, width: 260, height: 230)

    @Test("右の辺をつかんで右へ運ぶと、左の辺はそのままで幅が広がる")
    func trailing() {
        let resized = ShelfSizing.resized(frame, handle: .trailing, by: CGVector(dx: 100, dy: 40), within: visible)
        #expect(resized == CGRect(x: 400, y: 300, width: 360, height: 230))
    }

    @Test("左の辺をつかんで左へ運ぶと、右の辺はそのままで幅が広がる")
    func leading() {
        let resized = ShelfSizing.resized(frame, handle: .leading, by: CGVector(dx: -50, dy: 0), within: visible)
        #expect(resized.minX == 350)
        #expect(resized.maxX == frame.maxX)
        #expect(resized.width == 310)
    }

    @Test("左下の角をつかむと、右の辺と上の辺はそのままで広がる（下へ運ぶと y は小さくなる）")
    func bottomLeading() {
        let resized = ShelfSizing.resized(frame, handle: .bottomLeading, by: CGVector(dx: -20, dy: -70), within: visible)
        #expect(resized == CGRect(x: 380, y: 230, width: 280, height: 300))
        #expect(resized.maxX == frame.maxX)
        #expect(resized.maxY == frame.maxY)
    }

    @Test("上の辺をつかんで運ぶと、高さだけが変わる")
    func top() {
        let resized = ShelfSizing.resized(frame, handle: .top, by: CGVector(dx: 80, dy: 100), within: visible)
        #expect(resized == CGRect(x: 400, y: 300, width: 260, height: 330))
    }

    @Test("いちばん小さい大きさより小さくはならない（反対側の辺は動かさない）")
    func minimum() {
        let resized = ShelfSizing.resized(frame, handle: .topLeading, by: CGVector(dx: 500, dy: -500), within: visible)
        #expect(resized.size == ShelfSizing.minimumSize)
        #expect(resized.maxX == frame.maxX)
        #expect(resized.minY == frame.minY)
    }

    @Test("見える範囲の外へは広げない")
    func staysInVisibleFrame() {
        let resized = ShelfSizing.resized(frame, handle: .bottomTrailing, by: CGVector(dx: 5000, dy: -5000), within: visible)
        #expect(resized.minY == visible.minY)
        #expect(resized.maxX <= visible.maxX)
        #expect(resized.width <= ShelfSizing.maximumSize.width)
    }

    @Test("はじめから見える範囲をはみ出していても、つかんだ辺は飛ばずについてくる")
    func alreadyOutside() {
        // 右の辺が、見える範囲の右より 40 外に出ている棚
        let outside = CGRect(x: 1220, y: 300, width: 260, height: 230)
        let shrunk = ShelfSizing.resized(outside, handle: .trailing, by: CGVector(dx: -10, dy: 0), within: visible)
        #expect(shrunk.maxX == outside.maxX - 10)
        // そこより外へは広げない
        let grown = ShelfSizing.resized(outside, handle: .trailing, by: CGVector(dx: 100, dy: 0), within: visible)
        #expect(grown.maxX == outside.maxX)
        // メニューバーの下に入り込んでいる棚の上の辺も、飛ばない
        let underMenuBar = CGRect(x: 400, y: 700, width: 260, height: 200)
        let lowered = ShelfSizing.resized(underMenuBar, handle: .top, by: CGVector(dx: 0, dy: -5), within: visible)
        #expect(lowered.maxY == underMenuBar.maxY - 5)
    }

    @Test("いちばん大きい大きさより大きくはならない")
    func maximum() {
        let wide = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let resized = ShelfSizing.resized(frame, handle: .topTrailing, by: CGVector(dx: 5000, dy: 5000), within: wide)
        #expect(resized.size == ShelfSizing.maximumSize)
    }

    @Test("画面端にしまった棚は、画面の端の側ではつかめない")
    func dockedHandles() {
        let right = ResizeHandle.available(dockedEdge: .right)
        #expect(!right.contains { $0.horizontal == 1 })
        #expect(right.contains(.leading))
        #expect(right.contains(.top))
        let left = ResizeHandle.available(dockedEdge: .left)
        #expect(!left.contains { $0.horizontal == -1 })
        #expect(left.contains(.trailing))
        #expect(ResizeHandle.available(dockedEdge: nil).count == 8)
    }

    @Test("はじめの大きさ: 画面の端では 150 × 240、浮いているときは 180 × 180")
    func defaultSizes() {
        #expect(ShelfSizing.defaultSize(for: .docked) == CGSize(width: 150, height: 240))
        #expect(ShelfSizing.defaultSize(for: .floating) == CGSize(width: 180, height: 180))
        // はじめの大きさは、いちばん小さい大きさより小さくない
        #expect(ShelfSizing.clamped(ShelfSizing.defaultSize(for: .docked)) == ShelfSizing.defaultSize(for: .docked))
    }

    @Test("縁のつかめる範囲: 角を辺より先に見つける。真ん中ではつかまない")
    func handleAtPoint() {
        let size = CGSize(width: 260, height: 230)
        let all = ResizeHandle.allCases
        #expect(ResizeHandle.handle(at: CGPoint(x: 2, y: 2), in: size, among: all) == .topLeading)
        #expect(ResizeHandle.handle(at: CGPoint(x: 258, y: 228), in: size, among: all) == .bottomTrailing)
        #expect(ResizeHandle.handle(at: CGPoint(x: 130, y: 3), in: size, among: all) == .top)
        #expect(ResizeHandle.handle(at: CGPoint(x: 3, y: 115), in: size, among: all) == .leading)
        #expect(ResizeHandle.handle(at: CGPoint(x: 130, y: 115), in: size, among: all) == nil)
        // 右端にしまった棚は、右の辺ではつかまない
        let docked = ResizeHandle.available(dockedEdge: .right)
        #expect(ResizeHandle.handle(at: CGPoint(x: 257, y: 115), in: size, among: docked) == nil)
    }

    @Test("縁で変えられる向き: いちばん小さいときは広げるだけ、いちばん大きいときは狭めるだけ")
    func directions() {
        #expect(ShelfSizing.resizeDirections(for: .trailing, size: CGSize(width: 260, height: 230)) == .both)
        #expect(ShelfSizing.resizeDirections(for: .trailing, size: CGSize(width: ShelfSizing.minimumSize.width, height: 230)) == .growOnly)
        #expect(ShelfSizing.resizeDirections(for: .bottom, size: CGSize(width: 260, height: ShelfSizing.maximumSize.height)) == .shrinkOnly)
        // 角は、幅と高さのどちらかを変えられれば、その向きに動かせる
        #expect(ShelfSizing.resizeDirections(for: .bottomTrailing, size: CGSize(width: ShelfSizing.minimumSize.width, height: 230)) == .both)
        // 横の辺は、高さがいちばん小さくても関係ない
        #expect(ShelfSizing.resizeDirections(for: .leading, size: CGSize(width: 260, height: ShelfSizing.minimumSize.height)) == .both)
    }

    @Test("最後に変えた大きさを、棚の種類ごとに覚える")
    func remember() throws {
        let suite = "ShelfSizingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(ShelfSizing.remembered(.docked, defaults: defaults) == ShelfSizing.defaultSize(for: .docked))
        ShelfSizing.remember(CGSize(width: 320, height: 480), for: .docked, defaults: defaults)
        #expect(ShelfSizing.remembered(.docked, defaults: defaults) == CGSize(width: 320, height: 480))
        #expect(ShelfSizing.remembered(.floating, defaults: defaults) == ShelfSizing.defaultSize(for: .floating))

        // 小さすぎる大きさは、いちばん小さい大きさにして覚える
        ShelfSizing.remember(CGSize(width: 10, height: 10), for: .floating, defaults: defaults)
        #expect(ShelfSizing.remembered(.floating, defaults: defaults) == ShelfSizing.minimumSize)

        // はじめの大きさに戻せる
        ShelfSizing.resetRemembered(.docked, defaults: defaults)
        #expect(ShelfSizing.remembered(.docked, defaults: defaults) == ShelfSizing.defaultSize(for: .docked))
    }

    @Test("設定画面で幅・高さを別々に変えても読める（範囲の外の値は収める）")
    func separateKeys() throws {
        let suite = "ShelfSizingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(400.0, forKey: ShelfSizing.widthKey(for: .floating))
        defaults.set(5000.0, forKey: ShelfSizing.heightKey(for: .floating))
        #expect(ShelfSizing.remembered(.floating, defaults: defaults) == CGSize(width: 400, height: ShelfSizing.maximumSize.height))

        // 幅だけを変えたときは、高さははじめの大きさ
        defaults.set(320.0, forKey: ShelfSizing.widthKey(for: .docked))
        #expect(ShelfSizing.remembered(.docked, defaults: defaults) == CGSize(width: 320, height: ShelfSizing.defaultSize(for: .docked).height))
    }

    @Test("前の形式（配列）で覚えた大きさを、今の形式に移す")
    func migratesLegacy() throws {
        let suite = "ShelfSizingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set([320.0, 480.0], forKey: "shelfSize.edge")
        ShelfSizing.migrateLegacyValues(defaults: defaults)
        #expect(ShelfSizing.remembered(.docked, defaults: defaults) == CGSize(width: 320, height: 480))
        #expect(defaults.object(forKey: "shelfSize.edge") == nil)
    }
}
