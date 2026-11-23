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

    /// どの棚にも置いていない画像のファイル（起動したときに片付ける）
    public static func unreferenced(_ files: [URL], referencedPaths: Set<String>) -> [URL] {
        files.filter { !referencedPaths.contains($0.standardizedFileURL.path) }
    }
}
