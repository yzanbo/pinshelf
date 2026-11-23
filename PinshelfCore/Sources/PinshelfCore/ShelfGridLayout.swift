import CoreGraphics

/// 棚の中身の並べ方（何列に並べるか）
///
/// 列の数は、棚の横幅から決める。中身の一覧の横幅から決めると、スクロールバーが出たときに狭くなって、
/// 列が減ってしまう（2 個なら横に並ぶのに、3 個目でスクロールバーが出て 3 個とも縦に並ぶ、など）。
public enum ShelfGridLayout {
    /// 1 つ分のいちばん狭い幅（これより狭くなるなら、列を減らす）
    public static let minimumTileWidth: CGFloat = 72
    /// 1 つ分のいちばん広い幅
    public static let maximumTileWidth: CGFloat = 96
    /// 列のあいだ
    public static let spacing: CGFloat = 4
    /// 一覧のまわりの余白
    public static let padding: CGFloat = 8

    /// 棚の横幅に並べる列の数（1 列より少なくはしない）
    public static func columnCount(forShelfWidth width: CGFloat) -> Int {
        let content = width - padding * 2
        let count = ((content + spacing) / (minimumTileWidth + spacing)).rounded(.down)
        return max(1, Int(count))
    }
}
