import PinshelfCore
import SwiftUI

// MARK: - 画面の端の帯

/// 画面の端の棚をたたんだときの、細い帯（中身の件数を出す）
struct EdgeTab: View {
    let count: Int
    let edge: ScreenEdge
    /// 棚の名前（名前のある棚は、ポインタを乗せたときの説明に出す）
    var name: String?
    /// 帯の色（棚に色を付けたとき）
    var tint: Color?
    /// ドラッグで重ねているか（重ねている間は光らせる）
    var isTargeted = false

    private var tooltip: String {
        let contents = count == 0 ? "空" : "\(count) 個"
        let title = name.map { "\($0)（\(contents)）" } ?? "棚（\(contents)）"
        return count == 0
            ? "\(title)。ここまで運ぶと開きます"
            : "\(title)。ポインタを乗せると開きます"
    }

    var body: some View {
        VStack(spacing: 6) {
            // アプリの印（空かどうかは、色と件数で見せる）
            AppSymbolImage(size: 14)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.monospacedDigit().bold())
                    // 件数が変わったときは、数字を滑らかに入れ替える
                    .contentTransition(.numericText())
            }
        }
        .foregroundStyle(isTargeted ? Color.accentColor : tint ?? (count == 0 ? Color.secondary : Color.primary))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: EdgeShape(edge: edge, radius: 10))
        .background(isTargeted ? Color.accentColor.opacity(0.15) : .clear, in: EdgeShape(edge: edge, radius: 10))
        .overlay(EdgeShape(edge: edge, radius: 10).stroke(
            isTargeted ? Color.accentColor : tint.map { $0.opacity(0.8) } ?? Color.accentColor.opacity(count == 0 ? 0.5 : 0.2),
            lineWidth: isTargeted ? 2 : (tint == nil ? 1 : 1.5)
        ))
        .shadow(color: .black.opacity(0.12), radius: 3, x: edge == .right ? -1 : 1)
        .animation(.snappy(duration: 0.2), value: count)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
        .contentShape(Rectangle())
        .help(tooltip)
    }
}

/// 画面の内側だけ角を丸めた形
nonisolated struct EdgeShape: Shape {
    let edge: ScreenEdge
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let inner = radius
        let shape = switch edge {
        case .left:
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: inner, topTrailingRadius: inner)
        case .right:
            UnevenRoundedRectangle(topLeadingRadius: inner, bottomLeadingRadius: inner, bottomTrailingRadius: 0, topTrailingRadius: 0)
        }
        return shape.path(in: rect)
    }
}
