import CoreGraphics
import Foundation

// MARK: - 保存の形式

/// 保存する中身
public enum StoredContent: Codable, Equatable, Sendable {
    /// ファイル。再起動後に開き直すためのブックマークと、ブックマークが使えないときのためのパス
    case file(path: String, bookmark: Data?)
    case link(URL)
    case text(String)
}

/// 保存する 1 つのもの
public struct StoredItem: Codable, Equatable, Sendable {
    public var id: UUID
    public var addedAt: Date
    public var content: StoredContent
    public var isLocked: Bool
    public var stackID: UUID?

    public init(id: UUID, addedAt: Date, content: StoredContent, isLocked: Bool = false, stackID: UUID? = nil) {
        self.id = id
        self.addedAt = addedAt
        self.content = content
        self.isLocked = isLocked
        self.stackID = stackID
    }

    private enum CodingKeys: String, CodingKey {
        case id, addedAt, content, isLocked, stackID
    }

    // ロック・スタックを足す前に保存したファイルも読めるよう、なければ初期値にする
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        content = try container.decode(StoredContent.self, forKey: .content)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        stackID = try container.decodeIfPresent(UUID.self, forKey: .stackID)
    }
}

/// 保存する 1 つの棚
public struct StoredShelf: Codable, Equatable, Sendable {
    public var items: [StoredItem]

    public init(items: [StoredItem] = []) {
        self.items = items
    }
}

/// 保存する棚の窓（中身・位置・置き方・名前など。浮いた棚・画面端にしまった棚・画面端の棚のどれも）
public struct StoredShelfWindow: Codable, Equatable, Sendable {
    public var id: UUID
    /// 浮いているときの枠（端にしまっているときは、戻したときの枠）
    public var frame: CGRect
    public var shelf: StoredShelf
    /// 画面端にしまっているときの端（浮いていれば nil）
    public var dockedEdge: ScreenEdge?
    /// 画面端にしまっているときの、帯の中心の高さ
    public var dockedCenterY: Double?
    /// 棚の名前（なければ件数を出す）
    public var name: String?
    /// 棚の色
    public var color: ShelfColor
    /// お気に入り（閉じても中身ごと残し、メニューバーから出し直せる）
    public var isFavorite: Bool
    /// お気に入りの棚を隠しているか
    public var isHidden: Bool
    /// 画面端の棚（ドラッグに合わせて自動で出し入れする棚）か
    public var isEdgeShelf: Bool
    /// 画面の端にあるとき（出てきたとき）の大きさ（frame は浮いているときの枠）
    public var dockedSize: CGSize?
    /// 画面の端で開いたままにするか（見出しのピン。nil なら、新しい棚のはじめの状態の設定に従う）
    public var keepsOpen: Bool?

    public init(
        id: UUID,
        frame: CGRect,
        shelf: StoredShelf,
        dockedEdge: ScreenEdge? = nil,
        dockedCenterY: Double? = nil,
        name: String? = nil,
        color: ShelfColor = .none,
        isFavorite: Bool = false,
        isHidden: Bool = false,
        isEdgeShelf: Bool = false,
        dockedSize: CGSize? = nil,
        keepsOpen: Bool? = nil
    ) {
        self.id = id
        self.frame = frame
        self.shelf = shelf
        self.dockedEdge = dockedEdge
        self.dockedCenterY = dockedCenterY
        self.name = name
        self.color = color
        self.isFavorite = isFavorite
        self.isHidden = isHidden
        self.isEdgeShelf = isEdgeShelf
        self.dockedSize = dockedSize
        self.keepsOpen = keepsOpen
    }

    private enum CodingKeys: String, CodingKey {
        // お気に入りの保存のキーは、ピン留めと呼んでいたころのまま（前に保存したファイルも読めるように）
        case id, frame, shelf, dockedEdge, dockedCenterY, name, color, isFavorite = "isPinned", isHidden, isEdgeShelf, dockedSize, keepsOpen
    }

    // 画面端にしまう機能を足す前に保存したファイルも読めるよう、なければ浮いた棚にする
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        frame = try container.decode(CGRect.self, forKey: .frame)
        shelf = try container.decode(StoredShelf.self, forKey: .shelf)
        dockedEdge = try container.decodeIfPresent(ScreenEdge.self, forKey: .dockedEdge)
        dockedCenterY = try container.decodeIfPresent(Double.self, forKey: .dockedCenterY)
        // 名前・色・お気に入り（前の名前はピン留め）を足す前に保存したファイルも読めるよう、なければ初期値にする
        name = try container.decodeIfPresent(String.self, forKey: .name)
        color = (try? container.decodeIfPresent(ShelfColor.self, forKey: .color)) ?? .none
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        // 画面端の棚を浮いた棚と同じ棚にする前に保存したファイルでは、画面端の棚は edgeShelf に別に入っている
        isEdgeShelf = try container.decodeIfPresent(Bool.self, forKey: .isEdgeShelf) ?? false
        // 置き方ごとの大きさを足す前に保存したファイルでは、ない（しまっていた棚は frame の大きさを使う）
        dockedSize = try container.decodeIfPresent(CGSize.self, forKey: .dockedSize)
        // 棚ごとに開いたままにできるようにする前に保存したファイルでは、ない
        keepsOpen = try container.decodeIfPresent(Bool.self, forKey: .keepsOpen)
    }
}

/// アプリ全体の棚の保存内容
public struct ShelfSnapshot: Codable, Equatable, Sendable {
    /// 保存の形式の版（形式を変えたときに読み分けるため）
    public static let currentVersion = 1

    public var version: Int
    /// 画面端の棚の中身（前の形式。いまは画面端の棚も shelves に isEdgeShelf を付けて入れ、ここは空にする）
    public var edgeShelf: StoredShelf
    /// 画面端の棚を最後に出していた端
    public var edgeShelfEdge: ScreenEdge?
    /// 棚（浮いた棚・画面端にしまった棚・画面端の棚）
    public var shelves: [StoredShelfWindow]
    /// 最近閉じた棚（新しいものが先）
    public var recentlyClosed: [StoredRecentShelf]

    public init(
        version: Int = ShelfSnapshot.currentVersion,
        edgeShelf: StoredShelf = StoredShelf(),
        edgeShelfEdge: ScreenEdge? = nil,
        shelves: [StoredShelfWindow] = [],
        recentlyClosed: [StoredRecentShelf] = []
    ) {
        self.version = version
        self.edgeShelf = edgeShelf
        self.edgeShelfEdge = edgeShelfEdge
        self.shelves = shelves
        self.recentlyClosed = recentlyClosed
    }

    private enum CodingKeys: String, CodingKey {
        // 保存のキーは前と同じ（前に保存したファイルも読めるように）
        case version, edgeShelf, edgeShelfEdge, shelves = "floatingShelves", recentlyClosed
    }

    // 最近閉じた棚を足す前に保存したファイルも読めるよう、なければ空にする
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        edgeShelf = try container.decode(StoredShelf.self, forKey: .edgeShelf)
        edgeShelfEdge = try container.decodeIfPresent(ScreenEdge.self, forKey: .edgeShelfEdge)
        shelves = try container.decodeIfPresent([StoredShelfWindow].self, forKey: .shelves) ?? []
        recentlyClosed = try container.decodeIfPresent([StoredRecentShelf].self, forKey: .recentlyClosed) ?? []
    }
}

/// 保存する、最近閉じた棚
public struct StoredRecentShelf: Codable, Equatable, Sendable {
    public var shelf: StoredShelfWindow
    public var closedAt: Date

    public init(shelf: StoredShelfWindow, closedAt: Date) {
        self.shelf = shelf
        self.closedAt = closedAt
    }
}

/// 最近閉じた棚（閉じた棚を覚えておき、開き直せるようにする）
public struct RecentShelves: Equatable, Sendable {
    /// 覚えておく数
    public static let limit = 10

    /// 新しいものが先
    public private(set) var entries: [StoredRecentShelf]

    public init(entries: [StoredRecentShelf] = []) {
        self.entries = Array(entries.prefix(Self.limit))
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// 閉じた棚を覚える（空の棚は覚えない。同じ棚をもう一度閉じたら、前のものと入れ替える）
    public mutating func record(_ shelf: StoredShelfWindow, closedAt date: Date = .now) {
        guard !shelf.shelf.items.isEmpty else { return }
        entries.removeAll { $0.shelf.id == shelf.id }
        entries.insert(StoredRecentShelf(shelf: shelf, closedAt: date), at: 0)
        if entries.count > Self.limit {
            entries.removeLast(entries.count - Self.limit)
        }
    }

    /// 開き直すので、一覧から取り出す
    public mutating func take(id: UUID) -> StoredRecentShelf? {
        guard let index = entries.firstIndex(where: { $0.shelf.id == id }) else { return nil }
        return entries.remove(at: index)
    }

    /// すべて忘れる
    public mutating func clear() {
        entries.removeAll()
    }

    /// 覚えている棚に置いていたファイルのパス（開き直せるうちは、クリップボードから入れた画像を片付けないように）
    public var filePaths: [String] {
        entries.flatMap(\.shelf.shelf.items).compactMap { item in
            if case .file(let path, _) = item.content { path } else { nil }
        }
    }
}

// MARK: - 棚と保存の形式の変換

/// 保存したものから組み立てた棚
public struct RestoredShelf: Sendable {
    public var shelf: Shelf
    /// ファイルのブックマーク（古くなっていたものは作り直したもの）
    public var bookmarks: [ShelfItem.ID: Data]
    /// 見つからなかったファイルの数
    public var missingCount: Int

    public init(shelf: Shelf = Shelf(), bookmarks: [ShelfItem.ID: Data] = [:], missingCount: Int = 0) {
        self.shelf = shelf
        self.bookmarks = bookmarks
        self.missingCount = missingCount
    }
}

public enum ShelfArchiver {
    /// 棚の中身を保存の形式にする
    public static func archive(_ shelf: Shelf, bookmarks: [ShelfItem.ID: Data]) -> StoredShelf {
        StoredShelf(items: shelf.items.map { item in
            let content: StoredContent = switch item.content {
            case .file(let url): .file(path: url.path, bookmark: bookmarks[item.id])
            case .link(let url): .link(url)
            case .text(let text): .text(text)
            }
            return StoredItem(id: item.id, addedAt: item.addedAt, content: content, isLocked: item.isLocked, stackID: item.stackID)
        })
    }

    /// 保存の形式から棚を組み立てる
    ///
    /// ファイルはブックマークから今の場所を求める（移動・名前の変更に追従する）。
    /// ブックマークが使えないときはパスで探し、見つからないファイルは棚に戻さない。
    public static func restore(_ stored: StoredShelf, using coding: any BookmarkCoding) -> RestoredShelf {
        var items: [ShelfItem] = []
        var bookmarks: [ShelfItem.ID: Data] = [:]
        var missing = 0

        for record in stored.items {
            switch record.content {
            case .file(let path, let bookmark):
                if let bookmark, let resolved = coding.resolve(bookmark) {
                    items.append(ShelfItem(id: record.id, content: .file(resolved.url), addedAt: record.addedAt, isLocked: record.isLocked, stackID: record.stackID))
                    bookmarks[record.id] = resolved.bookmark
                } else if let url = coding.existingFile(atPath: path) {
                    items.append(ShelfItem(id: record.id, content: .file(url), addedAt: record.addedAt, isLocked: record.isLocked, stackID: record.stackID))
                    if let fresh = coding.makeBookmark(for: url) {
                        bookmarks[record.id] = fresh
                    }
                } else {
                    missing += 1
                }
            case .link(let url):
                items.append(ShelfItem(id: record.id, content: .link(url), addedAt: record.addedAt, isLocked: record.isLocked, stackID: record.stackID))
            case .text(let text):
                items.append(ShelfItem(id: record.id, content: .text(text), addedAt: record.addedAt, isLocked: record.isLocked, stackID: record.stackID))
            }
        }
        return RestoredShelf(shelf: Shelf(items: items), bookmarks: bookmarks, missingCount: missing)
    }
}
