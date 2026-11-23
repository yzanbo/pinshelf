import Foundation

/// クリックのときに押していた修飾キーによる選び方
public enum SelectionModifier: Sendable {
    /// それだけを選ぶ
    case none
    /// 選んでいなければ足し、選んでいれば外す（⌘ クリック）
    case toggle
    /// 起点からそこまでをまとめて選ぶ（⇧ クリック）
    case range
}

/// 棚の中で選んでいるもの（Finder と同じ選び方）
public struct ShelfSelection: Equatable, Sendable {
    public private(set) var ids: Set<UUID> = []
    /// 範囲選択と矢印キーの起点
    public private(set) var anchor: UUID?

    public init() {}

    public var isEmpty: Bool { ids.isEmpty }

    public func contains(_ id: UUID) -> Bool {
        ids.contains(id)
    }

    /// クリックで選ぶ
    /// - Parameter order: 棚に並んでいる順の ID
    public mutating func click(_ id: UUID, in order: [UUID], modifier: SelectionModifier) {
        click(unit: [id], in: order, modifier: modifier)
    }

    /// クリックで、まとまり（スタック）ごと選ぶ
    /// - Parameters:
    ///   - unit: まとめて選ぶもの（スタックの中身。1 つでもよい）
    ///   - order: 棚に並んでいる順の ID
    public mutating func click(unit: [UUID], in order: [UUID], modifier: SelectionModifier) {
        guard let first = unit.first else { return }
        switch modifier {
        case .none:
            ids = Set(unit)
            anchor = first
        case .toggle:
            if unit.allSatisfy(ids.contains) {
                ids.subtract(unit)
            } else {
                ids.formUnion(unit)
            }
            anchor = first
        case .range:
            let positions = unit.compactMap { order.firstIndex(of: $0) }
            guard let anchor, let from = order.firstIndex(of: anchor),
                  let low = positions.min(), let high = positions.max() else {
                click(unit: unit, in: order, modifier: .none)
                return
            }
            ids = Set(order[min(from, low)...max(from, high)])
        }
    }

    /// 矢印キーで、選んでいるものを前後へ動かす（動かしたあとは 1 つだけを選ぶ）
    public mutating func move(by offset: Int, in order: [UUID]) {
        move(by: offset, inUnits: order.map { [$0] })
    }

    /// 矢印キーで、まとまり（スタック）を 1 つとして前後へ動かす
    /// - Parameter units: 並べて見せる単位ごとの ID
    public mutating func move(by offset: Int, inUnits units: [[UUID]]) {
        let units = units.filter { !$0.isEmpty }
        guard !units.isEmpty else { return }
        let current = anchor.flatMap { anchor in
            ids.contains(anchor) ? units.firstIndex { $0.contains(anchor) } : nil
        } ?? units.lastIndex { $0.contains(where: ids.contains) }
        let next: Int
        if let current {
            next = min(max(current + offset, 0), units.count - 1)
        } else {
            // 何も選んでいなければ、進む向きの端から選ぶ
            next = offset >= 0 ? 0 : units.count - 1
        }
        ids = Set(units[next])
        anchor = units[next][0]
    }

    /// すべて選ぶ
    public mutating func selectAll(_ order: [UUID]) {
        ids = Set(order)
        anchor = order.first
    }

    /// 選ぶのをやめる
    public mutating func clear() {
        ids.removeAll()
        anchor = nil
    }

    /// 棚からなくなったものを選択から外す
    public mutating func prune(keeping order: [UUID]) {
        let existing = Set(order)
        ids.formIntersection(existing)
        if let anchor, !existing.contains(anchor) {
            self.anchor = nil
        }
    }

    /// 選んでいるものを、棚に並んでいる順で返す
    public func ordered(_ order: [UUID]) -> [UUID] {
        order.filter { ids.contains($0) }
    }
}
