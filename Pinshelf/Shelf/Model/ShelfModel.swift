import AppKit
import Observation
import PinshelfCore
import UniformTypeIdentifiers

/// 画面に出す 1 つの棚の中身
///
/// ファイルは再起動後も開けるように、置いたときにブックマークを作っておく。
/// 復元したファイルは、棚に置いてある間 security-scoped のアクセスを開いておく。
@Observable
final class ShelfModel {
    /// 棚に置ける種類
    static let acceptedTypes: [UTType] = [.fileURL, .url, .plainText]
    /// 元に戻せる回数
    private static let undoLimit = 20

    private(set) var shelf = Shelf()
    /// 読み込み中のドロップの数
    private(set) var pendingLoads = 0

    /// 選んでいるもの
    private(set) var selection = ShelfSelection()
    /// 元に戻せる取り除きの数（見出しの「元に戻す」ボタンを出すため）
    private(set) var undoCount = 0

    /// 中身が変わったときに呼ぶ（保存のため）
    @ObservationIgnored var onChange: (() -> Void)?
    /// 選んでいるものが変わったときに呼ぶ（Quick Look の表示を合わせるため）
    @ObservationIgnored var onSelectionChange: (() -> Void)?
    /// Quick Look を出してほしいとき（右クリックのメニューなどから）
    @ObservationIgnored var onQuickLookRequest: (() -> Void)?

    /// 棚の中のそれぞれのものの枠（SwiftUI の座標。ドラッグでつかんだものを調べるため）
    @ObservationIgnored var tileFrames: [ShelfItem.ID: CGRect] = [:]
    /// 一覧が見えている範囲（見出しなどを押したときに、隠れたものをつかまないため）
    @ObservationIgnored var itemsArea: CGRect = .zero

    /// ファイルのブックマーク
    @ObservationIgnored private var bookmarks: [ShelfItem.ID: Data] = [:]
    /// アクセスを開いているファイル（棚から外すときに閉じる）
    @ObservationIgnored private var accessedURLs: [ShelfItem.ID: URL] = [:]
    /// 元に戻すために覚えておく、取り除いたもの（新しいものが後ろ）
    @ObservationIgnored private var undoStack: [(removal: ShelfRemoval, bookmarks: [ShelfItem.ID: Data])] = []
    @ObservationIgnored private let bookmarkCoding: any BookmarkCoding

    init(bookmarkCoding: any BookmarkCoding = SystemBookmarkCoding()) {
        self.bookmarkCoding = bookmarkCoding
    }

    var items: [ShelfItem] { shelf.items }
    var isEmpty: Bool { shelf.isEmpty }
    /// 読み込み中のドロップがないか
    var isSettled: Bool { pendingLoads == 0 }
    /// 並べて見せる単位（スタックはまとめて 1 つ）
    var units: [[ShelfItem]] { shelf.units }

    /// 「3 個」のような数の表示
    var countLabel: String {
        isEmpty ? "空の棚" : "\(items.count) 個"
    }

    private var behavior: ShelfBehaviorSettings {
        ShelfBehaviorSettings(defaults: .standard)
    }

    /// ドロップされたものを受け取る
    func accept(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        pendingLoads += 1
        Task {
            let contents = await ItemProviderLoader.contents(from: providers)
            accept(contents: contents)
            pendingLoads -= 1
        }
        return true
    }

    /// クリップボードの中身を、この棚に貼り付ける（⌘V・右クリックの「貼り付け」）
    @discardableResult
    func pasteFromClipboard() -> Bool {
        let contents = ClipboardImporter.contents()
        guard !contents.isEmpty else {
            NSSound.beep()
            return false
        }
        accept(contents: contents)
        return true
    }

    /// 読み終えた中身を受け取る（メニューバーのアイコンに落とされたときなど）
    func accept(contents: [ShelfItemContent]) {
        let added = shelf.add(contents, stacked: behavior.stackMultipleDrops)
        // ドロップで受け取ったファイルには今だけアクセスできるので、すぐブックマークにする
        for item in added {
            if case .file(let url) = item.content, let bookmark = bookmarkCoding.makeBookmark(for: url) {
                bookmarks[item.id] = bookmark
            }
        }
        if !added.isEmpty { onChange?() }
    }

    // MARK: - 取り除く・元に戻す

    func removeAll() {
        removeItems(withIDs: Set(items.map(\.id)))
    }

    /// 選んでいるものを棚から外す
    func removeSelected() {
        removeItems(withIDs: selection.ids)
    }

    /// 棚から外す（元に戻せるように覚えておく）
    func removeItems(withIDs ids: Set<ShelfItem.ID>) {
        let removal = shelf.remove(ids: ids)
        guard !removal.isEmpty else { return }
        var removedBookmarks: [ShelfItem.ID: Data] = [:]
        for item in removal.items {
            removedBookmarks[item.id] = bookmarks[item.id]
            forget(item.id)
        }
        undoStack.append((removal, removedBookmarks))
        if undoStack.count > Self.undoLimit {
            undoStack.removeFirst(undoStack.count - Self.undoLimit)
        }
        undoCount = undoStack.count
        pruneSelection()
        onChange?()
    }

    /// ⌘Z で戻せるファイル（クリップボードから入れた画像を、戻せるうちは片付けないように）
    var undoableFileURLs: [URL] {
        undoStack.flatMap(\.removal.items).compactMap { item in
            if case .file(let url) = item.content { url } else { nil }
        }
    }

    /// 最後に取り除いたものを、元の位置に戻す（⌘Z）
    func undoRemoval() {
        guard let last = undoStack.popLast() else { return }
        undoCount = undoStack.count
        let restored = shelf.restore(last.removal)
        for item in restored {
            guard case .file(let url) = item.content else { continue }
            bookmarks[item.id] = last.bookmarks[item.id]
            if url.startAccessingSecurityScopedResource() {
                accessedURLs[item.id] = url
            }
        }
        // 戻したものを選んでおく
        updateSelection { selection in
            selection.clear()
            for item in restored {
                selection.click(item.id, in: order, modifier: .toggle)
            }
        }
        if !restored.isEmpty { onChange?() }
    }

    // MARK: - ロック

    /// 選んでいるもののロックを切り替える（⌘L。1 つでもロックしていなければ、すべてロックする）
    func toggleLockOfSelection() {
        let targets = selectedItems
        guard !targets.isEmpty else { return }
        setLocked(!targets.allSatisfy(\.isLocked), for: targets)
    }

    private func setLocked(_ locked: Bool, for targets: [ShelfItem]) {
        shelf.setLocked(locked, ids: Set(targets.map(\.id)))
        onChange?()
    }

    // MARK: - スタック

    /// そのものが入っている単位（スタックならその中身すべて）
    func unit(containing item: ShelfItem) -> [ShelfItem] {
        units.first { $0.contains { $0.id == item.id } } ?? [item]
    }

    /// 選んでいるものをまとめて 1 つのスタックにする
    func stackSelected() {
        guard shelf.stack(ids: selection.ids) != nil else { return }
        onChange?()
    }

    /// そのものが入っているスタックを分ける
    func unstack(_ item: ShelfItem) {
        shelf.unstack(containing: [item.id])
        onChange?()
    }

    // MARK: - 棚から棚へ

    /// そのもののブックマーク（ほかの棚へ移すときに引き継ぐ）
    func bookmarks(for items: [ShelfItem]) -> [ShelfItem.ID: Data] {
        var result: [ShelfItem.ID: Data] = [:]
        for item in items {
            result[item.id] = bookmarks[item.id]
        }
        return result
    }

    /// ほかの棚から移す・複製する（ファイルのブックマークも引き継ぐ）
    func receive(_ items: [ShelfItem], bookmarks sourceBookmarks: [ShelfItem.ID: Data]) {
        let added = shelf.add(items.map(\.content), stacked: behavior.stackMultipleDrops)
        for newItem in added {
            guard case .file(let url) = newItem.content else { continue }
            let original = items.first { $0.content == newItem.content }
            if let original, let bookmark = sourceBookmarks[original.id] {
                bookmarks[newItem.id] = bookmark
            } else if let bookmark = bookmarkCoding.makeBookmark(for: url) {
                bookmarks[newItem.id] = bookmark
            }
            // 元の棚が外してアクセスを閉じても使えるよう、この棚でもアクセスを開いておく
            if url.startAccessingSecurityScopedResource() {
                accessedURLs[newItem.id] = url
            }
        }
        if !added.isEmpty { onChange?() }
    }

    /// ほかの棚へ移し終えた（ロックしたものは残す）
    func finishMovingToAnotherShelf(_ moved: [ShelfItem]) {
        let current = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ids = moved.compactMap { current[$0.id] }
            .filter { DragOutRule.afterMovingToAnotherShelf($0) == .remove }
            .map(\.id)
        removeItems(withIDs: Set(ids))
    }

    // MARK: - 取り出し

    /// その位置にあるもの（SwiftUI の座標）
    func itemID(at point: CGPoint) -> ShelfItem.ID? {
        guard itemsArea.contains(point) else { return nil }
        return shelf.items.first { tileFrames[$0.id]?.contains(point) == true }?.id
    }

    /// ほかのアプリへ取り出し終えた
    ///
    /// - 「取り出したら棚から外す」がオンなら、すぐに外す（ロックしたものは残す）
    /// - 元の場所からなくなったファイル（移動した・ゴミ箱に入れた）は外す。ロックしたものは新しい場所へ付け替える
    /// - 受け取った側（Finder など）が移動し終えるのを待ちながら、何度か調べる
    func finishDragOut(_ taken: [ShelfItem]) {
        let removesCopiedItems = behavior.removesCopiedItems
        let current = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let immediate = taken.compactMap { current[$0.id] }
            .filter { DragOutRule.immediate(for: $0, removesCopiedItems: removesCopiedItems) == .remove }
        removeItems(withIDs: Set(immediate.map(\.id)))

        let fileIDs = Set(taken.filter { if case .file = $0.content { true } else { false } }.map(\.id))
        guard !fileIDs.isEmpty else { return }
        Task {
            for delay in [Duration.milliseconds(300), .seconds(1), .seconds(3)] {
                try? await Task.sleep(for: delay)
                checkFilesAfterDragOut(fileIDs)
            }
        }
    }

    private func checkFilesAfterDragOut(_ ids: Set<ShelfItem.ID>) {
        var gone: Set<ShelfItem.ID> = []
        for item in items where ids.contains(item.id) {
            guard case .file(let url) = item.content else { continue }
            let isGone = !FileManager.default.fileExists(atPath: url.path)
            switch DragOutRule.afterCheck(for: item, fileIsGone: isGone) {
            case .keep:
                break
            case .remove:
                gone.insert(item.id)
            case .relocate:
                relocate(item)
            }
        }
        removeItems(withIDs: gone)
    }

    /// ロックしたファイルが移動していたら、ブックマークから新しい場所を探して付け替える
    private func relocate(_ item: ShelfItem) {
        guard let bookmark = bookmarks[item.id], let resolved = bookmarkCoding.resolve(bookmark),
              item.content != .file(resolved.url) else { return }
        accessedURLs.removeValue(forKey: item.id)?.stopAccessingSecurityScopedResource()
        shelf.replaceContent(of: item.id, with: .file(resolved.url))
        bookmarks[item.id] = resolved.bookmark
        if resolved.url.startAccessingSecurityScopedResource() {
            accessedURLs[item.id] = resolved.url
        }
        onChange?()
    }

    // MARK: - 選択

    private var order: [ShelfItem.ID] { shelf.items.map(\.id) }
    private var unitIDs: [[ShelfItem.ID]] { units.map { $0.map(\.id) } }

    /// 選んでいるもの（棚に並んでいる順）
    var selectedItems: [ShelfItem] {
        shelf.items.filter { selection.contains($0.id) }
    }

    /// 選んでいる単位の数（スタックは 1 つと数える）
    var selectedUnitCount: Int {
        units.filter { $0.contains { selection.contains($0.id) } }.count
    }

    func isSelected(_ item: ShelfItem) -> Bool {
        selection.contains(item.id)
    }

    /// クリックで選ぶ（スタックなら中身をまとめて選ぶ）
    func click(_ item: ShelfItem, modifier: SelectionModifier) {
        let unit = unit(containing: item).map(\.id)
        updateSelection { $0.click(unit: unit, in: order, modifier: modifier) }
    }

    /// それだけを選ぶ（すでに選んでいるなら、そのままにする）
    func selectForAction(_ item: ShelfItem) {
        guard !selection.contains(item.id) else { return }
        click(item, modifier: .none)
    }

    func selectAll() {
        updateSelection { $0.selectAll(order) }
    }

    func clearSelection() {
        updateSelection { $0.clear() }
    }

    /// 矢印キーで前後へ動かす（スタックは 1 つとして動く）
    func moveSelection(by offset: Int) {
        let units = unitIDs
        updateSelection { $0.move(by: offset, inUnits: units) }
    }

    private func pruneSelection() {
        updateSelection { $0.prune(keeping: order) }
    }

    private func updateSelection(_ change: (inout ShelfSelection) -> Void) {
        var next = selection
        change(&next)
        guard next != selection else { return }
        selection = next
        onSelectionChange?()
    }

    // MARK: - 保存と復元

    /// 保存の形式にする
    func archive() -> StoredShelf {
        ShelfArchiver.archive(shelf, bookmarks: bookmarks)
    }

    /// 保存したものから中身を戻す
    func restore(_ restored: RestoredShelf) {
        releaseAccess()
        shelf = restored.shelf
        bookmarks = restored.bookmarks
        pruneSelection()
        for item in shelf.items where bookmarks[item.id] != nil {
            guard case .file(let url) = item.content else { continue }
            if url.startAccessingSecurityScopedResource() {
                accessedURLs[item.id] = url
            }
        }
    }

    /// 開いているアクセスをすべて閉じる（棚を閉じるとき）
    func releaseAccess() {
        for url in accessedURLs.values {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }

    private func forget(_ id: ShelfItem.ID) {
        bookmarks[id] = nil
        accessedURLs.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
    }
}
