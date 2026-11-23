import PinshelfCore
import SwiftUI

// MARK: - 棚（浮いた棚・画面端の棚）

/// 棚の見出しからの操作（どれもメインスレッドで呼ぶ）
struct ShelfActions {
    let close: @MainActor () -> Void
    let toggleDock: @MainActor () -> Void
    let unfold: @MainActor () -> Void
    /// 開いた棚を、端の帯にたたむ
    let fold: @MainActor () -> Void
    let beginRename: @MainActor () -> Void
    let commitRename: @MainActor (String) -> Void
    let cancelRename: @MainActor () -> Void
    let setColor: @MainActor (ShelfColor) -> Void
    let toggleFavorite: @MainActor () -> Void
    /// 画面の端で開いたままにする・しない（見出しのピン）
    let toggleKeepsOpen: @MainActor () -> Void
    /// 縁をつかんだ・運んだ（つかみ始めてからの、画面の上でのマウスの動き）・放した
    let beginResize: @MainActor () -> Void
    let resize: @MainActor (ResizeHandle, CGVector) -> Void
    let endResize: @MainActor () -> Void
    /// 今の大きさを標準にする・標準の大きさに戻す
    let makeSizeDefault: @MainActor () -> Void
    let resetSize: @MainActor () -> Void
    /// 設定を開く
    let openSettings: @MainActor () -> Void
}

/// 棚（浮いた棚・画面端の棚で同じ）: 見出しと中身の一覧。画面端にしまっているときは、件数つきの帯
///
/// 見出しは `ShelfHeader`、見出しのメニューは `ShelfMenu`。
struct ShelfView: View {
    let model: ShelfModel
    let state: ShelfState
    let actions: ShelfActions
    @State private var isTargeted = false

    var body: some View {
        // 帯と棚を重ね、透明度で入れ替える。どちらもウィンドウいっぱいの枠の中に実物の大きさのまま置き、ウィンドウの枠で切り抜く。
        // - 棚は、しまう端と反対の側に寄せる。枠の内側の辺と一緒に棚が動くので、たたむと端へ滑り込み、開くと端から滑り出る
        // - 帯は、しまう端の側に寄せる。枠が縮む・広がる途中も、画面の端に付いたまま動かない
        // 出す・消すの切り替え（transition）にしないのは、SwiftUI が消えていく途中の部品の置き場所を消え始めたときのまま固定し、
        // 枠が動いても寄せる位置についてこない（ウィンドウの左上に貼り付いたまま動き、画面の端から離れて見える）ため
        ZStack {
            shelfLayer
                .shown(!state.isFolded)
            if let edge = state.dockedEdge {
                tabLayer(edge: edge)
                    .shown(state.isFolded)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        // 浮いた棚は、出るときに少し小さい状態から実物大にふわっと広げる（しまった棚は、端から滑り込むだけ）
        .scaleEffect(state.isPresented || state.isDocked ? 1 : ShelfMotion.appearScale)
        .shelfDropTarget(model: model, isTargeted: $isTargeted, cornerRadius: 16)
        .coordinateSpace(.named(ShelfDragSource.coordinateSpace))
    }

    /// 画面端にしまっているときの、件数つきの細い帯。しまう端の側に寄せる（枠が縮む・広がる途中も、画面の端に付いたまま）
    private func tabLayer(edge: ScreenEdge) -> some View {
        EdgeTab(
            count: model.items.count,
            edge: edge,
            name: state.name,
            tint: state.color.color,
            isTargeted: isTargeted
        )
            .frame(width: DockLayout.tabSize.width, height: DockLayout.tabSize.height)
            .onTapGesture(perform: actions.unfold)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .right ? .trailing : .leading)
    }

    /// 棚（見出しと中身）。帯にたたんでいる間も、透明にして置いておく
    private var shelfLayer: some View {
        shelf
            // ふだんは決まった大きさで描く（しまう・出すときに、枠が変わっても中身の大きさは変えないため）。
            // 縁をつかんで大きさを変えている間は、ウィンドウいっぱいに描く（枠の変化に遅れずについていく）
            .frame(width: state.isResizing ? nil : state.size.width, height: state.isResizing ? nil : state.size.height)
            .frame(maxWidth: state.isResizing ? .infinity : nil, maxHeight: state.isResizing ? .infinity : nil)
            // ポインタを乗せている縁を光らせる
            .overlay {
                ResizeHighlight(handle: state.hoveredResizeHandle)
            }
            // 縁（辺と角）をつかんで運ぶと、大きさが変わる
            .overlay {
                ResizeHandles(
                    handles: ResizeHandle.available(dockedEdge: state.dockedEdge),
                    onBegin: actions.beginResize,
                    onChange: actions.resize,
                    onEnd: actions.endResize
                )
            }
            // 棚のほうが大きくても枠をウィンドウの大きさにとどめ、はみ出した分は切り抜く（min を 0 にしないと、枠が棚の大きさまで広がる）
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: contentAlignment)
            .clipped()
    }

    /// 棚を寄せる位置（しまっているときは、しまう端と反対の側）
    private var contentAlignment: Alignment {
        switch state.dockedEdge {
        case .right: .leading
        case .left: .trailing
        case nil: .center
        }
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            ShelfHeader(model: model, state: state, actions: actions)
            ShelfItemsView(model: model, shelfWidth: state.size.width)
        }
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    state.color.color.map { $0.opacity(0.6) } ?? Color.primary.opacity(0.08),
                    lineWidth: state.color == .none ? 1 : 1.5
                )
        )
    }
}

private extension View {
    /// 見せる・隠す（置いたまま透明にする。隠している間は、クリックも読み上げも受けない）
    func shown(_ isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}
