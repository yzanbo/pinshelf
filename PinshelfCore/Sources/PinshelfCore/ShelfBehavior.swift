import Foundation

/// メニューバーのアイコンに落としたときの入れ先
public enum InboxDestination: String, CaseIterable, Sendable {
    /// アイコンの下に新しい棚を開いて入れる
    case newShelf
    /// 画面端の棚に入れる
    case edgeShelf
}

/// 棚のふるまいに関する設定
public struct ShelfBehaviorSettings: Equatable, Sendable {
    /// UserDefaults に保存するときのキー
    public enum Key {
        public static let removesCopiedItems = "removeAfterDragOut"
        public static let stackMultipleDrops = "stackMultipleDrops"
        public static let ignoredApplications = "ignoredApplications"
        public static let inboxDestination = "menuBarDropDestination"
        public static let clipboardShortcut = "clipboardShortcut"
        /// 保存のキーの文字列は、画面端の棚だけに効いていたころのまま（設定を引き継ぐため）
        public static let foldsNewShelves = "edgeShelfCollapsesOnLeave"
        public static let docksWhenDraggedToEdge = "docksWhenDraggedToEdge"
        public static let remembersResizedSize = "remembersResizedShelfSize"
        public static let closesEmptyDockedShelves = "closesEmptyDockedShelves"
        public static let closesEmptyFloatingShelves = "closesEmptyFloatingShelves"
    }

    /// 取り出したら（コピーでも）棚から外す。ロックしたものは残す
    public var removesCopiedItems: Bool
    /// 一緒に置いた 2 つ以上のものを、1 つのスタックにまとめる
    public var stackMultipleDrops: Bool
    /// ドラッグを始めても、棚を自動では出さないアプリ（バンドル ID）
    public var ignoredBundleIDs: [String]
    /// メニューバーのアイコンに落としたとき・クリップボードから入れるときの入れ先
    public var inboxDestination: InboxDestination
    /// 「クリップボードから棚へ」のショートカット（どこからでも使える）
    public var clipboardShortcut: ClipboardShortcut
    /// 新しい棚を、画面の端で細い帯にたたむか（false なら開いたまま）。棚ごとには、見出しのピンで切り替える
    public var foldsNewShelves: Bool
    /// 浮いた棚の見出しをつかんで画面の端まで運んで放したら、画面端にしまうか（false なら、しまわずに画面の中に収める）
    public var docksWhenDraggedToEdge: Bool
    /// 棚の大きさを変えたら、それを標準の大きさ（次に開く同じ種類の棚の大きさ）にするか
    public var remembersResizedSize: Bool
    /// 画面の端にある棚が空（0 個）になったら閉じるか（false なら、件数 0 の帯・空の棚のまま残す）
    public var closesEmptyDockedShelves: Bool
    /// 浮いた棚が空（0 個）になったら閉じるか（false なら、空の棚のまま残す）
    public var closesEmptyFloatingShelves: Bool

    public init(
        removesCopiedItems: Bool = false,
        stackMultipleDrops: Bool = true,
        ignoredBundleIDs: [String] = [],
        inboxDestination: InboxDestination = .newShelf,
        clipboardShortcut: ClipboardShortcut = .optionShiftV,
        foldsNewShelves: Bool = true,
        docksWhenDraggedToEdge: Bool = true,
        remembersResizedSize: Bool = true,
        closesEmptyDockedShelves: Bool = true,
        closesEmptyFloatingShelves: Bool = true
    ) {
        self.removesCopiedItems = removesCopiedItems
        self.stackMultipleDrops = stackMultipleDrops
        self.ignoredBundleIDs = ignoredBundleIDs
        self.inboxDestination = inboxDestination
        self.clipboardShortcut = clipboardShortcut
        self.foldsNewShelves = foldsNewShelves
        self.docksWhenDraggedToEdge = docksWhenDraggedToEdge
        self.remembersResizedSize = remembersResizedSize
        self.closesEmptyDockedShelves = closesEmptyDockedShelves
        self.closesEmptyFloatingShelves = closesEmptyFloatingShelves
    }

    /// 初期値
    public static let defaults = ShelfBehaviorSettings()

    /// キーから値を読む関数を使って設定を組み立てる（読めない値は初期値にする）
    public init(reading value: (String) -> Any?) {
        let base = ShelfBehaviorSettings.defaults
        self.init(
            removesCopiedItems: value(Key.removesCopiedItems) as? Bool ?? base.removesCopiedItems,
            stackMultipleDrops: value(Key.stackMultipleDrops) as? Bool ?? base.stackMultipleDrops,
            ignoredBundleIDs: value(Key.ignoredApplications) as? [String] ?? base.ignoredBundleIDs,
            inboxDestination: (value(Key.inboxDestination) as? String)
                .flatMap(InboxDestination.init(rawValue:)) ?? base.inboxDestination,
            clipboardShortcut: (value(Key.clipboardShortcut) as? String)
                .flatMap(ClipboardShortcut.init(rawValue:)) ?? base.clipboardShortcut,
            foldsNewShelves: value(Key.foldsNewShelves) as? Bool ?? base.foldsNewShelves,
            docksWhenDraggedToEdge: value(Key.docksWhenDraggedToEdge) as? Bool ?? base.docksWhenDraggedToEdge,
            remembersResizedSize: value(Key.remembersResizedSize) as? Bool ?? base.remembersResizedSize,
            closesEmptyDockedShelves: value(Key.closesEmptyDockedShelves) as? Bool ?? base.closesEmptyDockedShelves,
            closesEmptyFloatingShelves: value(Key.closesEmptyFloatingShelves) as? Bool ?? base.closesEmptyFloatingShelves
        )
    }

    /// UserDefaults から設定を読む
    public init(defaults store: UserDefaults) {
        self.init(reading: { store.object(forKey: $0) })
    }

    /// 空（0 個）になった棚を閉じるか（docked: 画面の端にある棚か）
    public func closesEmptyShelf(docked: Bool) -> Bool {
        docked ? closesEmptyDockedShelves : closesEmptyFloatingShelves
    }
}

/// 棚を自動で出すか（画面端・シェイク）の決まり
public enum TriggerPolicy {
    /// - Parameters:
    ///   - frontmostBundleID: ドラッグを始めたときに前面にあったアプリ
    ///   - startedInPinshelf: Pinshelf の棚から始まったドラッグか（棚から棚へ移すときは、いつも出す）
    ///   - ignored: 自動では出さないアプリ
    public static func allowsAutomaticShelf(frontmostBundleID: String?, startedInPinshelf: Bool, ignored: [String]) -> Bool {
        if startedInPinshelf { return true }
        guard let frontmostBundleID else { return true }
        return !ignored.contains(frontmostBundleID)
    }
}

/// 棚から取り出したあと、そのものをどうするかの決まり
public enum DragOutRule {
    public enum Outcome: Equatable, Sendable {
        /// 棚に残す
        case keep
        /// 棚から外す
        case remove
        /// 棚に残し、ファイルの新しい場所へ付け替える（ロックしたファイルが移動したとき）
        case relocate
    }

    /// 取り出した直後
    public static func immediate(for item: ShelfItem, removesCopiedItems: Bool) -> Outcome {
        removesCopiedItems && !item.isLocked ? .remove : .keep
    }

    /// 少したってから、ファイルが元の場所に残っているかを調べたとき
    public static func afterCheck(for item: ShelfItem, fileIsGone: Bool) -> Outcome {
        guard case .file = item.content, fileIsGone else { return .keep }
        return item.isLocked ? .relocate : .remove
    }

    /// ほかの棚へ移したとき（ロックしたものは元の棚にも残す）
    public static func afterMovingToAnotherShelf(_ item: ShelfItem) -> Outcome {
        item.isLocked ? .keep : .remove
    }
}
