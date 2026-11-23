import Foundation
import Testing
@testable import PinshelfCore

@Suite("棚の中の選択")
struct ShelfSelectionTests {
    /// 棚に並んでいる 5 つのもの
    let order = (0..<5).map { _ in UUID() }

    @Test("ふつうのクリックは、それだけを選ぶ")
    func plainClick() {
        var selection = ShelfSelection()
        selection.click(order[1], in: order, modifier: .none)
        selection.click(order[3], in: order, modifier: .none)
        #expect(selection.ids == [order[3]])
        #expect(selection.anchor == order[3])
    }

    @Test("⌘ クリックで足したり外したりできる")
    func toggleClick() {
        var selection = ShelfSelection()
        selection.click(order[0], in: order, modifier: .none)
        selection.click(order[2], in: order, modifier: .toggle)
        #expect(selection.ids == [order[0], order[2]])
        selection.click(order[0], in: order, modifier: .toggle)
        #expect(selection.ids == [order[2]])
    }

    @Test("⇧ クリックで起点からそこまでを選ぶ（逆向きも）")
    func rangeClick() {
        var selection = ShelfSelection()
        selection.click(order[1], in: order, modifier: .none)
        selection.click(order[3], in: order, modifier: .range)
        #expect(selection.ordered(order) == [order[1], order[2], order[3]])
        // 起点は動かないので、反対側へ広げ直せる
        selection.click(order[0], in: order, modifier: .range)
        #expect(selection.ordered(order) == [order[0], order[1]])
    }

    @Test("起点がないときの ⇧ クリックは、ふつうのクリックと同じ")
    func rangeWithoutAnchor() {
        var selection = ShelfSelection()
        selection.click(order[2], in: order, modifier: .range)
        #expect(selection.ids == [order[2]])
    }

    @Test("矢印キーで前後へ動き、端で止まる")
    func moveSelection() {
        var selection = ShelfSelection()
        selection.click(order[3], in: order, modifier: .none)
        selection.move(by: 1, in: order)
        #expect(selection.ids == [order[4]])
        selection.move(by: 1, in: order)
        #expect(selection.ids == [order[4]])
        selection.move(by: -2, in: order)
        #expect(selection.ids == [order[2]])
    }

    @Test("何も選んでいないときの矢印キーは、進む向きの端から選ぶ")
    func moveFromNothing() {
        var forward = ShelfSelection()
        forward.move(by: 1, in: order)
        #expect(forward.ids == [order[0]])

        var backward = ShelfSelection()
        backward.move(by: -1, in: order)
        #expect(backward.ids == [order[4]])
    }

    @Test("すべて選ぶ・選ぶのをやめる")
    func selectAllAndClear() {
        var selection = ShelfSelection()
        selection.selectAll(order)
        #expect(selection.ids.count == 5)
        selection.clear()
        #expect(selection.isEmpty)
        #expect(selection.anchor == nil)
    }

    @Test("棚からなくなったものは選択から外れる")
    func prune() {
        var selection = ShelfSelection()
        selection.selectAll(order)
        selection.click(order[1], in: order, modifier: .toggle)
        selection.click(order[1], in: order, modifier: .toggle)
        let remaining = [order[0], order[2]]
        selection.prune(keeping: remaining)
        #expect(selection.ids == Set(remaining))
        #expect(selection.anchor == nil)
    }

    @Test("スタックを押すと、中身をまとめて選ぶ")
    func clickUnit() {
        var selection = ShelfSelection()
        selection.click(unit: [order[1], order[2]], in: order, modifier: .none)
        #expect(selection.ids == [order[1], order[2]])
        // ⌘ クリックでまとめて外す
        selection.click(unit: [order[1], order[2]], in: order, modifier: .toggle)
        #expect(selection.isEmpty)
    }

    @Test("⇧ クリックでスタックまでの範囲を選ぶ")
    func rangeToUnit() {
        var selection = ShelfSelection()
        selection.click(order[0], in: order, modifier: .none)
        selection.click(unit: [order[2], order[3]], in: order, modifier: .range)
        #expect(selection.ordered(order) == [order[0], order[1], order[2], order[3]])
    }

    @Test("矢印キーはスタックを 1 つとして動く")
    func moveOverUnits() {
        let units = [[order[0]], [order[1], order[2], order[3]], [order[4]]]
        var selection = ShelfSelection()
        selection.click(order[0], in: order, modifier: .none)
        selection.move(by: 1, inUnits: units)
        #expect(selection.ids == [order[1], order[2], order[3]])
        selection.move(by: 1, inUnits: units)
        #expect(selection.ids == [order[4]])
        selection.move(by: -1, inUnits: units)
        #expect(selection.ids == [order[1], order[2], order[3]])
    }
}
