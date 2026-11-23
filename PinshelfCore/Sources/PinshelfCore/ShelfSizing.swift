import CoreGraphics
import Foundation

// MARK: - 棚の大きさ

/// 棚の大きさを変えるときに、マウスでつかむところ（辺と角）
public enum ResizeHandle: CaseIterable, Sendable {
    case top
    case bottom
    case leading
    case trailing
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    /// 動かす縦の辺（-1: 左の辺、1: 右の辺、0: 動かさない）
    public var horizontal: Int {
        switch self {
        case .leading, .topLeading, .bottomLeading: -1
        case .trailing, .topTrailing, .bottomTrailing: 1
        case .top, .bottom: 0
        }
    }

    /// 動かす横の辺（1: 上の辺、-1: 下の辺、0: 動かさない）
    public var vertical: Int {
        switch self {
        case .top, .topLeading, .topTrailing: 1
        case .bottom, .bottomLeading, .bottomTrailing: -1
        case .leading, .trailing: 0
        }
    }

    /// 角か
    public var isCorner: Bool {
        horizontal != 0 && vertical != 0
    }

    /// つかめるところ（画面端にしまった棚は、画面の端の側ではつかめない）
    /// - Parameter dockedEdge: しまっている端（浮いていれば nil）
    public static func available(dockedEdge: ScreenEdge?) -> [ResizeHandle] {
        switch dockedEdge {
        case nil: allCases
        case .right: [.top, .bottom, .leading, .topLeading, .bottomLeading]
        case .left: [.top, .bottom, .trailing, .topTrailing, .bottomTrailing]
        }
    }
}

extension ResizeHandle {
    /// 辺のつかめる幅（pt。見出しのボタンにかからない幅）
    public static let edgeThickness: CGFloat = 7
    /// 角のつかめる大きさ（pt。左上の閉じるボタンにかからない大きさ）
    public static let cornerSize: CGFloat = 12

    /// 棚の中で、つかめる範囲（ビューの座標。左上が原点で、y は下向き）
    public func zone(in size: CGSize) -> CGRect {
        let edge = Self.edgeThickness
        let corner = Self.cornerSize
        let x: CGFloat = switch horizontal {
        case -1: 0
        case 1: size.width - (isCorner ? corner : edge)
        default: corner
        }
        let y: CGFloat = switch vertical {
        case 1: 0
        case -1: size.height - (isCorner ? corner : edge)
        default: corner
        }
        let width: CGFloat = isCorner ? corner : (horizontal == 0 ? size.width - corner * 2 : edge)
        let height: CGFloat = isCorner ? corner : (vertical == 0 ? size.height - corner * 2 : edge)
        return CGRect(x: x, y: y, width: max(width, 0), height: max(height, 0))
    }

    /// その位置にあるつかめるところ（ビューの座標。左上が原点）。角を辺より先に調べる
    public static func handle(at point: CGPoint, in size: CGSize, among handles: [ResizeHandle]) -> ResizeHandle? {
        let ordered = handles.filter(\.isCorner) + handles.filter { !$0.isCorner }
        return ordered.first { $0.zone(in: size).contains(point) }
    }
}

/// 縁で大きさを変えられる向き
public enum ResizeDirections: Sendable {
    /// 広げることも、狭めることもできる
    case both
    /// 広げることだけできる（いちばん小さいとき）
    case growOnly
    /// 狭めることだけできる（いちばん大きいとき）
    case shrinkOnly
}

/// 棚の大きさの決まり（最小・最大・覚えておく大きさ）
public enum ShelfSizing {
    /// はじめの大きさ（設定の「初期値に戻す」で戻る大きさ）。画面の端では縦長に、浮いているときは正方形にする
    public static func defaultSize(for kind: Kind) -> CGSize {
        switch kind {
        case .docked: CGSize(width: 150, height: 240)
        case .floating: CGSize(width: 180, height: 180)
        }
    }
    /// いちばん小さい大きさ（見出しのボタンと件数、中身 1 列・1 段が入る）
    public static let minimumSize = CGSize(width: 150, height: 150)
    /// いちばん大きい大きさ
    public static let maximumSize = CGSize(width: 1000, height: 1000)

    /// 最小・最大に収めた大きさ
    public static func clamped(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, minimumSize.width), maximumSize.width),
            height: min(max(size.height, minimumSize.height), maximumSize.height)
        )
    }

    /// つかんだところを delta だけ動かしたときの枠
    ///
    /// 反対側の辺は動かさない。最小・最大の大きさと、見える範囲（visibleFrame）に収める。
    /// つかみ始めたときに、もう見える範囲をはみ出していた辺は、そこまでは動かせる（つかんだとたんに辺が飛ばないように）。
    /// 座標は macOS の画面座標（左下が原点、y は上向き）。
    /// - Parameters:
    ///   - frame: つかみ始めたときの枠
    ///   - delta: つかみ始めてから、マウスが動いた量
    public static func resized(_ frame: CGRect, handle: ResizeHandle, by delta: CGVector, within visibleFrame: CGRect) -> CGRect {
        var minX = frame.minX
        var maxX = frame.maxX
        var minY = frame.minY
        var maxY = frame.maxY

        // 辺を動かせる範囲（見える範囲。はじめからはみ出していた辺は、そこまで）
        let left = min(visibleFrame.minX, frame.minX)
        let right = max(visibleFrame.maxX, frame.maxX)
        let bottom = min(visibleFrame.minY, frame.minY)
        let top = max(visibleFrame.maxY, frame.maxY)

        switch handle.horizontal {
        case -1:
            // 左の辺: 右の辺から、最小と最大の幅の間（見える範囲の左より外には出さない）
            minX = clamp(frame.minX + delta.dx, lower: max(left, maxX - maximumSize.width), upper: maxX - minimumSize.width)
        case 1:
            maxX = clamp(frame.maxX + delta.dx, lower: minX + minimumSize.width, upper: min(right, minX + maximumSize.width))
        default:
            break
        }

        switch handle.vertical {
        case 1:
            // 上の辺: 下の辺から、最小と最大の高さの間（見える範囲の上より外には出さない）
            maxY = clamp(frame.maxY + delta.dy, lower: minY + minimumSize.height, upper: min(top, minY + maximumSize.height))
        case -1:
            minY = clamp(frame.minY + delta.dy, lower: max(bottom, maxY - maximumSize.height), upper: maxY - minimumSize.height)
        default:
            break
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// その縁で大きさを変えられる向き（つかんだ縁が動かす幅・高さが、いちばん小さい・大きいかで決まる）
    public static func resizeDirections(for handle: ResizeHandle, size: CGSize) -> ResizeDirections {
        var canGrow = false
        var canShrink = false
        if handle.horizontal != 0 {
            canGrow = canGrow || size.width < maximumSize.width
            canShrink = canShrink || size.width > minimumSize.width
        }
        if handle.vertical != 0 {
            canGrow = canGrow || size.height < maximumSize.height
            canShrink = canShrink || size.height > minimumSize.height
        }
        switch (canGrow, canShrink) {
        case (true, false): return .growOnly
        case (false, true): return .shrinkOnly
        default: return .both
        }
    }

    /// lower と upper の間に収める（はじめからはみ出していて lower が upper を超えるときは、upper にする）
    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    // MARK: - 標準の大きさ（新しく開く棚の大きさ）

    /// 標準の大きさを分ける、棚の置き方（画面の端にあるときと、浮いているときで別々に決める）
    public enum Kind: String, CaseIterable, Sendable {
        /// 浮いているとき（振る・キー・メニューで開く棚、画面端から浮かせた棚）
        case floating
        /// 画面の端にあるとき（画面の端の棚を開いたとき）。保存のキーは、前の名前（edge）のまま
        case docked = "edge"
    }

    /// 標準の幅を保存するキー（設定画面からも読み書きする）
    public static func widthKey(for kind: Kind) -> String {
        "shelfSize.\(kind.rawValue).width"
    }

    /// 標準の高さを保存するキー
    public static func heightKey(for kind: Kind) -> String {
        "shelfSize.\(kind.rawValue).height"
    }

    /// 標準の大きさ（決めていない幅・高さは、はじめの大きさ）
    public static func remembered(_ kind: Kind, defaults: UserDefaults) -> CGSize {
        let width = defaults.object(forKey: widthKey(for: kind)) as? Double ?? Double(defaultSize(for: kind).width)
        let height = defaults.object(forKey: heightKey(for: kind)) as? Double ?? Double(defaultSize(for: kind).height)
        return clamped(CGSize(width: width, height: height))
    }

    /// 標準の大きさを決める（最小・最大に収める）
    public static func remember(_ size: CGSize, for kind: Kind, defaults: UserDefaults) {
        let size = clamped(size)
        defaults.set(Double(size.width), forKey: widthKey(for: kind))
        defaults.set(Double(size.height), forKey: heightKey(for: kind))
    }

    /// 標準の大きさを、はじめの大きさに戻す
    public static func resetRemembered(_ kind: Kind, defaults: UserDefaults) {
        defaults.removeObject(forKey: widthKey(for: kind))
        defaults.removeObject(forKey: heightKey(for: kind))
    }

    /// 前の形式（幅と高さを 1 つの配列で保存していた）の標準の大きさを、今の形式に移す
    public static func migrateLegacyValues(defaults: UserDefaults) {
        for kind in Kind.allCases {
            let legacyKey = "shelfSize.\(kind.rawValue)"
            guard let values = defaults.array(forKey: legacyKey) as? [Double] else { continue }
            if values.count == 2, defaults.object(forKey: widthKey(for: kind)) == nil {
                remember(CGSize(width: values[0], height: values[1]), for: kind, defaults: defaults)
            }
            defaults.removeObject(forKey: legacyKey)
        }
    }
}
