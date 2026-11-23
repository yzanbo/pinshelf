import Foundation

/// 「クリップボードから棚へ」のショートカット
public enum ClipboardShortcut: String, CaseIterable, Sendable {
    /// 使わない
    case off
    /// ⌥⇧V
    case optionShiftV
    /// ⌃⌥V
    case controlOptionV
    /// ⌃⇧V
    case controlShiftV

    /// 表示（「⌥⇧V」など）
    public var symbol: String {
        switch self {
        case .off: ""
        case .optionShiftV: "⌥⇧V"
        case .controlOptionV: "⌃⌥V"
        case .controlShiftV: "⌃⇧V"
        }
    }
}

/// クリップボードの画像を、ファイルにして棚に入れるときの決まり
public enum ClipboardFiles {
    /// 保存するフォルダの名前（Application Support/Pinshelf の中）
    public static let folderName = "Clipboard"

    /// 画像のファイル名（「クリップボード 2026-11-22 23.10.05.png」）
    public static func imageFileName(at date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "クリップボード \(formatter.string(from: date)).png"
    }

    /// 同じ名前のファイルがあれば、「… 2.png」のように番号を付けた名前にする
    public static func uniqueName(_ name: String, existing: Set<String>) -> String {
        guard existing.contains(name) else { return name }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var number = 2
        while existing.contains("\(base) \(number).\(ext)") {
            number += 1
        }
        return "\(base) \(number).\(ext)"
    }

    /// どの棚にも置いていない画像のファイル
    public static func unreferenced(_ files: [URL], referencedPaths: Set<String>) -> [URL] {
        files.filter { !referencedPaths.contains($0.standardizedFileURL.path) }
    }

    /// 入れたばかりの画像を残しておく長さ（秒）。書き出してから棚に置くまでの間に、片付けで消してしまわないように
    public static let gracePeriod: TimeInterval = 60

    /// 画像の片付けの仕分け
    public struct CleanUpPlan: Equatable, Sendable {
        /// 消してよい画像（どの棚にも置いていない・入れたばかりではない）
        public let removable: [URL]
        /// どの棚にも置いていないが、入れたばかりなので残す画像（残す期間が過ぎたら、もう一度片付ける）
        public let waiting: [URL]
    }

    /// 画像を、消してよいものと、入れたばかりなので残すものに仕分ける（棚に置いているものは、どちらにも入らない）
    /// - Parameters:
    ///   - files: 画像のファイルと、最後に書き換えた時刻
    ///   - referencedPaths: 棚（最近閉じた棚・元に戻せる分も）に置いているファイルのパス
    public static func cleanUpPlan(
        _ files: [(url: URL, modified: Date)],
        referencedPaths: Set<String>,
        now: Date,
        gracePeriod: TimeInterval = gracePeriod
    ) -> CleanUpPlan {
        let stale = Set(unreferenced(files.map(\.url), referencedPaths: referencedPaths))
        let unreferencedFiles = files.filter { stale.contains($0.url) }
        let isFresh = { (file: (url: URL, modified: Date)) in now.timeIntervalSince(file.modified) < gracePeriod }
        return CleanUpPlan(
            removable: unreferencedFiles.filter { !isFresh($0) }.map(\.url),
            waiting: unreferencedFiles.filter(isFresh).map(\.url)
        )
    }
}
