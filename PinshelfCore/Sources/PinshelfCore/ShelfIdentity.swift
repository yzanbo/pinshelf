import Foundation

/// 棚の色（Finder のタグと同じ並び）
public enum ShelfColor: String, CaseIterable, Codable, Sendable {
    case none
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray
}

/// 棚の名前
public enum ShelfNaming {
    /// 仮の名前の頭
    public static let defaultPrefix = "棚"

    /// 名前のない棚をお気に入りにしたときに付ける、仮の名前（「棚 1」「棚 2」…。使っていない番号のうち、いちばん小さいもの）
    public static func defaultName(existing names: [String]) -> String {
        let used = Set(names.compactMap(number(in:)))
        var number = 1
        while used.contains(number) {
            number += 1
        }
        return "\(defaultPrefix) \(number)"
    }

    /// 入力された名前を整える（前後の空白を除き、空なら名前なし）
    public static func normalized(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// 「棚 3」のような仮の名前の番号
    private static func number(in name: String) -> Int? {
        let prefix = defaultPrefix + " "
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }
}
