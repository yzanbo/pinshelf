import CoreGraphics

/// 画面の左右の端
public enum ScreenEdge: String, CaseIterable, Codable, Sendable {
    case left
    case right
}

/// 棚を出す位置の計算
///
/// 座標は macOS の画面座標（左下が原点）。`screenFrame` は画面全体、
/// `visibleFrame` はメニューバーと Dock を除いた範囲を渡す。
public enum EdgeGeometry {
    /// 端からこの距離（pt）までカーソルが来たら「端に近づいた」と見なす
    public static let approachDistance: CGFloat = 160

    /// カーソルの位置と設定から、棚を出す端を決める
    public static func edge(forCursor point: CGPoint, in screenFrame: CGRect, preference: EdgePreference) -> ScreenEdge {
        switch preference {
        case .left:
            return .left
        case .right:
            return .right
        case .nearest:
            let toLeft = point.x - screenFrame.minX
            let toRight = screenFrame.maxX - point.x
            return toLeft <= toRight ? .left : .right
        }
    }

    /// カーソルから端までの横の距離
    public static func distance(from point: CGPoint, to edge: ScreenEdge, in screenFrame: CGRect) -> CGFloat {
        switch edge {
        case .left: max(0, point.x - screenFrame.minX)
        case .right: max(0, screenFrame.maxX - point.x)
        }
    }

    /// カーソルが端に近づいたか
    public static func isApproaching(
        _ point: CGPoint,
        edge: ScreenEdge,
        in screenFrame: CGRect,
        threshold: CGFloat = approachDistance
    ) -> Bool {
        distance(from: point, to: edge, in: screenFrame) <= threshold
    }

    /// 上・下に寄せるときの、見える範囲の端からの間
    public static let verticalMargin: CGFloat = 24

    /// 端に寄せた棚の枠
    /// - Parameters:
    ///   - vertical: 出す高さ（上・下はその端にそろえ、真ん中・カーソルの高さは中心をそろえる）
    ///   - anchorY: カーソルの高さに出すときの高さ（nil なら真ん中）
    public static func edgeFrame(
        size: CGSize,
        edge: ScreenEdge,
        in visibleFrame: CGRect,
        vertical: EdgeVerticalPosition,
        anchorY: CGFloat?
    ) -> CGRect {
        let height = min(size.height, visibleFrame.height)
        let x = edge == .left ? visibleFrame.minX : visibleFrame.maxX - size.width
        let proposedY: CGFloat = switch vertical {
        case .top: visibleFrame.maxY - verticalMargin - height
        case .middle: visibleFrame.midY - height / 2
        case .bottom: visibleFrame.minY + verticalMargin
        case .cursor: (anchorY ?? visibleFrame.midY) - height / 2
        }
        // 見える範囲からはみ出さないように寄せる
        let y = min(max(proposedY, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: size.width, height: height)
    }

    /// カーソルを中心にした棚の枠（画面からはみ出す分は内側に寄せる）
    public static func frame(centeredAt point: CGPoint, size: CGSize, in visibleFrame: CGRect) -> CGRect {
        var x = point.x - size.width / 2
        var y = point.y - size.height / 2
        x = min(max(x, visibleFrame.minX), visibleFrame.maxX - size.width)
        y = min(max(y, visibleFrame.minY), visibleFrame.maxY - size.height)
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// 保存しておいた棚の枠を、今つながっている画面に収める
    ///
    /// 枠の中心がある画面（なければ一番重なる画面）の内側へ寄せる。
    /// どの画面とも重ならない（つないでいた画面を外したなど）ときは、最初の画面の中央に置く。
    public static func fit(_ frame: CGRect, into visibleFrames: [CGRect]) -> CGRect {
        guard let first = visibleFrames.first else { return frame }
        let center = CGPoint(x: frame.midX, y: frame.midY)

        let target = visibleFrames.first { $0.contains(center) } ?? mostOverlapping(frame, among: visibleFrames)
        guard let target else {
            return self.frame(centeredAt: CGPoint(x: first.midX, y: first.midY), size: frame.size, in: first)
        }
        let size = CGSize(width: min(frame.width, target.width), height: min(frame.height, target.height))
        return self.frame(centeredAt: center, size: size, in: target)
    }

    /// 枠と一番広く重なる画面（どれとも重ならなければ nil）
    private static func mostOverlapping(_ frame: CGRect, among visibleFrames: [CGRect]) -> CGRect? {
        var best: CGRect?
        var bestArea: CGFloat = 0
        for candidate in visibleFrames {
            let overlap = candidate.intersection(frame)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                best = candidate
                bestArea = area
            }
        }
        return best
    }
}
