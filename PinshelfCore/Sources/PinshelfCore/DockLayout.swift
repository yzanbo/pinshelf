import CoreGraphics

/// 浮いた棚を画面端にしまうときの位置の計算
///
/// 座標は macOS の画面座標（左下が原点）。`screenFrame` は画面全体、
/// `visibleFrame` はメニューバーと Dock を除いた範囲。
public enum DockLayout {
    /// しまったときに端に残す帯の大きさ
    public static let tabSize = CGSize(width: 24, height: 80)
    /// 帯どうしの間
    public static let gap: CGFloat = 8
    /// ポインタが画面の端からこの距離（pt）以内で放したら、その端にしまう
    public static let pointerEdgeTolerance: CGFloat = 6
    /// 棚が見える範囲の端からこの距離（pt）以上はみ出して放したら、その端にしまう
    public static let overshootTolerance: CGFloat = 16
    /// 出てきた棚を、端からこの距離（pt）以上離して放したら、浮いた棚に戻す
    public static let undockDistance: CGFloat = 24
    /// 浮いた棚に戻すとき、端から離す距離（pt）
    public static let undockInset: CGFloat = 40

    /// 浮いた棚を運んで放したときに、しまう端（しまわないなら nil）
    ///
    /// ポインタを画面の端まで運んだとき、または棚を端からはみ出させたときにしまう。
    public static func dockEdge(windowFrame: CGRect, pointer: CGPoint, screenFrame: CGRect, visibleFrame: CGRect) -> ScreenEdge? {
        if pointer.x <= screenFrame.minX + pointerEdgeTolerance || windowFrame.minX <= visibleFrame.minX - overshootTolerance {
            return .left
        }
        if pointer.x >= screenFrame.maxX - pointerEdgeTolerance || windowFrame.maxX >= visibleFrame.maxX + overshootTolerance {
            return .right
        }
        return nil
    }

    /// 出てきた棚を運んで放したとき、まだ端にしまったままにするか（端から離していなければ true）
    public static func staysDocked(windowFrame: CGRect, edge: ScreenEdge, visibleFrame: CGRect) -> Bool {
        switch edge {
        case .left: windowFrame.minX <= visibleFrame.minX + undockDistance
        case .right: windowFrame.maxX >= visibleFrame.maxX - undockDistance
        }
    }

    /// 端に寄せた枠（縦は centerY を中心に、見える範囲に収める）
    public static func frame(edge: ScreenEdge, centerY: CGFloat, size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let height = min(size.height, visibleFrame.height)
        let x = edge == .left ? visibleFrame.minX : visibleFrame.maxX - size.width
        let y = min(max(centerY - height / 2, visibleFrame.minY), visibleFrame.maxY - height)
        return CGRect(x: x, y: y, width: size.width, height: height)
    }

    /// 浮いた棚に戻すときの枠（端から少し離し、縦は centerY を中心にする）
    public static func undockedFrame(edge: ScreenEdge, centerY: CGFloat, size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let docked = frame(edge: edge, centerY: centerY, size: size, in: visibleFrame)
        let dx = edge == .left ? undockInset : -undockInset
        return EdgeGeometry.frame(
            centeredAt: CGPoint(x: docked.midX + dx, y: docked.midY),
            size: size,
            in: visibleFrame
        )
    }

    /// ほかの帯と重ならない、望んだ位置にいちばん近い帯の中心（縦）
    /// - Parameters:
    ///   - desired: 置きたい中心
    ///   - height: 帯の高さ
    ///   - occupied: ほかの帯が使っている縦の範囲
    public static func freeCenterY(desired: CGFloat, height: CGFloat, occupied: [ClosedRange<CGFloat>], in visibleFrame: CGRect) -> CGFloat {
        let lowest = visibleFrame.minY + height / 2
        let highest = visibleFrame.maxY - height / 2
        func clamp(_ value: CGFloat) -> CGFloat { min(max(value, lowest), highest) }
        func fits(_ center: CGFloat) -> Bool {
            let low = center - height / 2
            let high = center + height / 2
            // 間をあけて、重ならないこと（端どうしが接するのはよい）
            return !occupied.contains { range in
                range.lowerBound - gap < high && low < range.upperBound + gap
            }
        }

        var candidates = [clamp(desired)]
        for range in occupied {
            candidates.append(clamp(range.lowerBound - gap - height / 2))
            candidates.append(clamp(range.upperBound + gap + height / 2))
        }
        let best = candidates.filter(fits).min { abs($0 - desired) < abs($1 - desired) }
        return best ?? clamp(desired)
    }
}
