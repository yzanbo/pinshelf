import Foundation

/// 棚に置いたものの中身
public enum ShelfItemContent: Hashable, Sendable {
    /// ファイル・フォルダ（コピーせず、場所を覚えておくだけ）
    case file(URL)
    /// Web のリンク
    case link(URL)
    /// テキスト
    case text(String)

    /// 同じものかを比べるためのキー（ファイルは表記ゆれをそろえる）
    var identityKey: String {
        switch self {
        case .file(let url): "file:" + url.standardizedFileURL.path
        case .link(let url): "link:" + url.absoluteString
        case .text(let text): "text:" + text
        }
    }
}

/// 棚に置いた 1 つのもの
public struct ShelfItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let content: ShelfItemContent
    public let addedAt: Date
    /// ロック（取り出しても棚に残す）
    public var isLocked: Bool
    /// 一緒に置いたものをまとめるスタックの目印（nil なら 1 つで置いている）
    public var stackID: UUID?

    public init(
        id: UUID = UUID(),
        content: ShelfItemContent,
        addedAt: Date = .now,
        isLocked: Bool = false,
        stackID: UUID? = nil
    ) {
        self.id = id
        self.content = content
        self.addedAt = addedAt
        self.isLocked = isLocked
        self.stackID = stackID
    }

    /// 中身だけを差し替えたもの（ロックしたファイルが移動したときに、新しい場所へ付け替える）
    public func replacingContent(with content: ShelfItemContent) -> ShelfItem {
        ShelfItem(id: id, content: content, addedAt: addedAt, isLocked: isLocked, stackID: stackID)
    }
}

/// 棚から取り除いたもの（元に戻すために、元の位置も覚えておく）
public struct ShelfRemoval: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        /// 取り除く前の位置
        public let index: Int
        public let item: ShelfItem
    }

    public let entries: [Entry]

    public var isEmpty: Bool { entries.isEmpty }
    public var items: [ShelfItem] { entries.map(\.item) }
}

/// 1 つの棚の中身
public struct Shelf: Equatable, Sendable {
    public private(set) var items: [ShelfItem] = []

    public init(items: [ShelfItem] = []) {
        self.items = items
    }

    public var isEmpty: Bool { items.isEmpty }

    /// 中身を加える。すでに置いてあるもの・同じ回に重複したものは加えない
    /// - Parameter stacked: true なら、2 つ以上加えたときに 1 つのスタックにまとめる
    /// - Returns: 実際に加えたもの
    @discardableResult
    public mutating func add(_ contents: [ShelfItemContent], at date: Date = .now, stacked: Bool = false) -> [ShelfItem] {
        var known = Set(items.map(\.content.identityKey))
        let fresh = contents.filter { known.insert($0.identityKey).inserted }
        let stackID: UUID? = stacked && fresh.count >= 2 ? UUID() : nil
        let added = fresh.map { ShelfItem(content: $0, addedAt: date, stackID: stackID) }
        items.append(contentsOf: added)
        return added
    }

    /// ほかの棚のものを、ロック・スタックごとそのまま加える（同じものがすでにあれば加えない）
    /// - Returns: 実際に加えたもの
    @discardableResult
    public mutating func append(_ newItems: [ShelfItem]) -> [ShelfItem] {
        var known = Set(items.map(\.content.identityKey))
        let fresh = newItems.filter { known.insert($0.content.identityKey).inserted }
        items.append(contentsOf: fresh)
        return fresh
    }

    // MARK: - 取り除く・戻す

    /// 1 つ取り除く
    @discardableResult
    public mutating func remove(id: ShelfItem.ID) -> ShelfRemoval {
        remove(ids: [id])
    }

    /// まとめて取り除く
    @discardableResult
    public mutating func remove(ids: Set<ShelfItem.ID>) -> ShelfRemoval {
        let entries = items.enumerated()
            .filter { ids.contains($0.element.id) }
            .map { ShelfRemoval.Entry(index: $0.offset, item: $0.element) }
        items.removeAll { ids.contains($0.id) }
        return ShelfRemoval(entries: entries)
    }

    /// すべて取り除く
    @discardableResult
    public mutating func removeAll() -> ShelfRemoval {
        remove(ids: Set(items.map(\.id)))
    }

    /// 取り除いたものを、元の位置に戻す（その間に同じものを置き直していたら、それは戻さない）
    /// - Returns: 戻したもの
    @discardableResult
    public mutating func restore(_ removal: ShelfRemoval) -> [ShelfItem] {
        var known = Set(items.map(\.content.identityKey))
        var restored: [ShelfItem] = []
        for entry in removal.entries.sorted(by: { $0.index < $1.index })
        where known.insert(entry.item.content.identityKey).inserted {
            items.insert(entry.item, at: min(entry.index, items.count))
            restored.append(entry.item)
        }
        return restored
    }

    // MARK: - ロック

    /// ロックする・外す
    public mutating func setLocked(_ locked: Bool, ids: Set<ShelfItem.ID>) {
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isLocked = locked
        }
    }

    /// 中身を差し替える（ID・ロック・スタックはそのまま）
    public mutating func replaceContent(of id: ShelfItem.ID, with content: ShelfItemContent) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index] = items[index].replacingContent(with: content)
    }

    // MARK: - スタック

    /// 並べて見せる単位（スタックはまとめて 1 つ。最初のものの位置に置く）
    ///
    /// 取り除いてスタックに 1 つだけ残ったときは、ふつうの 1 つとして見せる（目印は残すので、元に戻すとスタックも戻る）。
    public var units: [[ShelfItem]] {
        var result: [[ShelfItem]] = []
        var stackPositions: [UUID: Int] = [:]
        for item in items {
            if let stackID = item.stackID {
                if let position = stackPositions[stackID] {
                    result[position].append(item)
                } else {
                    stackPositions[stackID] = result.count
                    result.append([item])
                }
            } else {
                result.append([item])
            }
        }
        return result
    }

    /// まとめて 1 つのスタックにする（最初のものの位置に寄せる）
    /// - Returns: スタックの目印（2 つ未満なら nil）
    @discardableResult
    public mutating func stack(ids: Set<ShelfItem.ID>) -> UUID? {
        let members = items.filter { ids.contains($0.id) }
        guard members.count >= 2, let firstIndex = items.firstIndex(where: { ids.contains($0.id) }) else { return nil }
        let stackID = UUID()
        let grouped = members.map { item -> ShelfItem in
            var item = item
            item.stackID = stackID
            return item
        }
        let before = items[..<firstIndex].filter { !ids.contains($0.id) }
        let after = items[firstIndex...].filter { !ids.contains($0.id) }
        items = Array(before) + grouped + Array(after)
        return stackID
    }

    /// そのものが入っているスタックを分ける
    public mutating func unstack(containing ids: Set<ShelfItem.ID>) {
        let stackIDs = Set(items.filter { ids.contains($0.id) }.compactMap(\.stackID))
        guard !stackIDs.isEmpty else { return }
        for index in items.indices where items[index].stackID.map(stackIDs.contains) == true {
            items[index].stackID = nil
        }
    }
}
