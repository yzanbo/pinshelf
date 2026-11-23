import AppKit
import PinshelfCore
import SwiftUI

/// 棚の縁（辺と角）。つかんで運ぶと、棚の大きさが変わる
///
/// 縁にポインタを乗せたときの、大きさを変える形のポインタは、`ShelfHostingView` が出す（棚がキーウィンドウでなくても出すため）。
/// 運んでいる間はウィンドウの枠そのものが変わるので、ビューの中の座標ではなく、画面の上でのマウスの位置で動きを測る。
struct ResizeHandles: View {
    let handles: [ResizeHandle]
    let onBegin: @MainActor () -> Void
    let onChange: @MainActor (ResizeHandle, CGVector) -> Void
    let onEnd: @MainActor () -> Void

    /// 棚の角丸の半径（角丸の外の透明なところでも、つかめるようにするため）
    static let cornerRadius: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            // 角を辺より上に重ねる（角では、斜めに大きさを変えられるように）
            ForEach(handles.sorted { !$0.isCorner && $1.isCorner }, id: \.self) { handle in
                let zone = handle.zone(in: proxy.size)
                ResizeZone(handle: handle, onBegin: onBegin, onChange: onChange, onEnd: onEnd)
                    .frame(width: zone.width, height: zone.height)
                    .position(x: zone.midX, y: zone.midY)
            }
        }
    }

}

/// 辺・角の 1 つ分のつかめるところ
private struct ResizeZone: View {
    let handle: ResizeHandle
    let onBegin: @MainActor () -> Void
    let onChange: @MainActor (ResizeHandle, CGVector) -> Void
    let onEnd: @MainActor () -> Void

    /// つかみ始めたときのマウスの位置（画面の座標）
    @State private var start: CGPoint?
    /// つかんでいる間 true（途中で取りやめになったときも、放したことにするため）
    @GestureState private var isPressing = false

    var body: some View {
        ZStack {
            Color.clear
            if handle.isCorner {
                // 角丸の外の透明なところだけを、目に見えないほど薄く塗る。
                // 何も塗らないと、そこのクリックが下のウィンドウへ素通りして、角をつかめないことがある
                CornerOutside(handle: handle, radius: ResizeHandles.cornerRadius)
                    .fill(Color.black.opacity(0.01))
            }
        }
        .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .updating($isPressing) { _, pressing, _ in pressing = true }
                    .onChanged { value in
                        let now = NSEvent.mouseLocation
                        let origin: CGPoint
                        if let start {
                            origin = start
                        } else {
                            // 押した位置から測る（ビューの座標は下向きが正なので、縦は向きを逆にする）
                            origin = CGPoint(x: now.x - value.translation.width, y: now.y + value.translation.height)
                            start = origin
                            onBegin()
                        }
                        onChange(handle, CGVector(dx: now.x - origin.x, dy: now.y - origin.y))
                    }
                    .onEnded { _ in finish() }
            )
            .onChange(of: isPressing) { _, pressing in
                if !pressing { finish() }
            }
    }

    private func finish() {
        guard start != nil else { return }
        start = nil
        onEnd()
    }

}

/// 角のつかめるところのうち、棚の角丸の外になるところ（ウィンドウが透明なところ）
nonisolated private struct CornerOutside: Shape {
    let handle: ResizeHandle
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        // 角丸の円の中心（つかめるところの座標。左上が原点）
        let center = CGPoint(
            x: handle.horizontal == -1 ? rect.minX + radius : rect.maxX - radius,
            y: handle.vertical == 1 ? rect.minY + radius : rect.maxY - radius
        )
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return Path(rect).subtracting(circle)
    }
}

extension ResizeDirections {
    /// 大きさを変える形のポインタの矢印の向き
    var cursorDirections: NSCursor.FrameResizeDirection.Set {
        switch self {
        case .both: .all
        case .growOnly: .outward
        case .shrinkOnly: .inward
        }
    }
}

extension ResizeHandle {
    /// 大きさを変える形のポインタの向き
    var cursorPosition: NSCursor.FrameResizePosition {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .leading: .left
        case .trailing: .right
        case .topLeading: .topLeft
        case .topTrailing: .topRight
        case .bottomLeading: .bottomLeft
        case .bottomTrailing: .bottomRight
        }
    }
}

/// ポインタを乗せている縁の光（どこをつかめば大きさが変わるかを見せる）
///
/// ポインタの形は、棚がキーウィンドウのときしか変えられないので、こちらはいつでも出す。
struct ResizeHighlight: View {
    let handle: ResizeHandle?

    var body: some View {
        ZStack {
            if let handle {
                ResizeHighlightShape(handle: handle, radius: ResizeHandles.cornerRadius)
                    .stroke(Color.accentColor.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: handle)
        .allowsHitTesting(false)
    }
}

/// 光らせる縁の形（辺は角丸の手前まで、角は角丸に沿った L の字）
nonisolated private struct ResizeHighlightShape: Shape {
    let handle: ResizeHandle
    let radius: CGFloat

    /// 線の太さの半分だけ内側に引く（棚の外にはみ出して切れないように）
    private let inset: CGFloat = 1.5
    /// 角の L の字の、辺に沿って伸ばす長さ
    private let cornerReach: CGFloat = 10

    func path(in bounds: CGRect) -> Path {
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let r = max(radius - inset, 0)
        var path = Path()
        switch handle {
        case .top:
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        case .bottom:
            path.move(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))
        case .leading:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + r))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        case .trailing:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY + r))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        case .topLeading:
            corner(&path, from: CGPoint(x: rect.minX, y: rect.minY + r + cornerReach), corner: CGPoint(x: rect.minX, y: rect.minY),
                   to: CGPoint(x: rect.minX + r + cornerReach, y: rect.minY), radius: r)
        case .topTrailing:
            corner(&path, from: CGPoint(x: rect.maxX - r - cornerReach, y: rect.minY), corner: CGPoint(x: rect.maxX, y: rect.minY),
                   to: CGPoint(x: rect.maxX, y: rect.minY + r + cornerReach), radius: r)
        case .bottomLeading:
            corner(&path, from: CGPoint(x: rect.minX + r + cornerReach, y: rect.maxY), corner: CGPoint(x: rect.minX, y: rect.maxY),
                   to: CGPoint(x: rect.minX, y: rect.maxY - r - cornerReach), radius: r)
        case .bottomTrailing:
            corner(&path, from: CGPoint(x: rect.maxX, y: rect.maxY - r - cornerReach), corner: CGPoint(x: rect.maxX, y: rect.maxY),
                   to: CGPoint(x: rect.maxX - r - cornerReach, y: rect.maxY), radius: r)
        }
        return path
    }

    /// 角を回る線（from から角丸に沿って to まで）
    private func corner(_ path: inout Path, from start: CGPoint, corner: CGPoint, to end: CGPoint, radius: CGFloat) {
        path.move(to: start)
        path.addArc(tangent1End: corner, tangent2End: end, radius: radius)
        path.addLine(to: end)
    }
}
