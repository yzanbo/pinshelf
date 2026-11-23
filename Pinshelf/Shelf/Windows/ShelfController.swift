import AppKit
import Observation
import PinshelfCore
import SwiftUI

/// 棚（振る・キー・メニューから開く浮いた棚と、画面端の棚）
///
/// 役目ごとに、別のファイルの拡張に分けている。
/// - `ShelfController+Docking.swift`: 画面端にしまう・出す・帯にたたむ、画面端の棚の役目
/// - `ShelfController+Resizing.swift`: 縁で大きさを変える・標準の大きさ
/// - `ShelfController+Identity.swift`: 名前・色・お気に入りと、保存の形式
///
/// 画面端にしまうこともできる。画面端の棚も、この棚を画面端にしまったもので、
/// `EdgeShelfDriver` がドラッグに合わせて出し入れする（`state.isEdgeShelf`）。
/// - しまい方: 上の帯をつかんで画面の端まで運ぶ・見出しのボタン・見出しのダブルクリック
/// - しまうと、端に件数つきの細い帯にたたむ（開いたままにする棚は、開いたまま）。ポインタを乗せる・ドラッグ中に近づけると、棚が端から開く
/// - 開いた棚を端から離して放すと、浮いた棚に戻る。端に沿って運ぶと、帯の位置が変わる
final class ShelfController {
    let id: UUID
    let model: ShelfModel
    let panel: ShelfPanel
    let state = ShelfState()
    /// Quick Look・キー操作・ドラッグでの取り出し
    private let interaction: ShelfInteraction
    /// 枠を動かす・利用者が見出しをつかんで運んだのを見分ける
    let moveTracker: WindowMoveTracker
    /// 開いた棚からポインタが離れたのを見張る
    let pointerWatcher = PointerLeaveWatcher()

    var onClose: ((ShelfController) -> Void)?
    /// 動かしたときに呼ぶ（保存のため）
    var onMove: (() -> Void)?
    /// しまった・戻した・名前や色を変えた・隠したときに呼ぶ（保存のため）
    var onStateChange: (() -> Void)?
    /// 名前のない棚をお気に入りにしたときの、仮の名前を返す
    var defaultNameProvider: (() -> String)?
    /// 帯を置くとき、ほかの帯が使っている縦の範囲を返す（重ならないように置くため）
    var occupiedTabRanges: ((ShelfController, ScreenEdge, NSScreen) -> [ClosedRange<CGFloat>])?
    /// 画面端の棚でなくなった（浮かせた・閉じた・隠した）
    var onResignEdgeShelf: ((ShelfController) -> Void)?
    /// 見出しのメニューから、設定を開く
    var onOpenSettings: (() -> Void)?

    // 次の 4 つは、別のファイルの拡張（しまう・大きさ）からも変えるので private(set) にしていない

    /// しまっている画面
    var dockScreen: NSScreen?
    /// しまっているときの、帯の中心の高さ
    var dockCenterY: CGFloat = 0
    /// ドラッグ中に近づけたので開いている（ドラッグが終わったら、帯にたたむ）
    var isUnfoldedByDrag = false
    /// 縁をつかんで大きさを変え始めたときの枠（変えていなければ nil）
    var resizeStartFrame: CGRect?

    /// お気に入りの棚を隠しているか（メニューバーから出し直せる）
    private(set) var isHidden = false
    /// 閉じて捨てたか（2 回閉じても、片付けを 1 回だけにする）
    private var isDiscarded = false

    /// カーソルの位置を中心に、新しい棚を作る（大きさは、浮いているとき・画面の端にあるときの、それぞれの標準）
    convenience init(centeredAt point: CGPoint) {
        let size = ShelfSizing.remembered(.floating, defaults: .standard)
        let visible = NSScreen.containing(point)?.visibleFrame ?? CGRect(origin: .zero, size: size)
        let frame = EdgeGeometry.frame(centeredAt: point, size: size, in: visible)
        self.init(id: UUID(), frame: frame, model: ShelfModel())
    }

    /// 決まった位置と中身で棚を作る（保存した棚を戻すとき）
    ///
    /// 浮いているときの大きさは枠から、画面の端にあるときの大きさは標準から決める（保存した大きさは `restoreDockedSize` で戻す）。
    init(id: UUID, frame: CGRect, model: ShelfModel) {
        self.id = id
        self.model = model
        let size = ShelfSizing.clamped(frame.size)
        panel = ShelfPanel(contentRect: CGRect(origin: frame.origin, size: size))
        interaction = ShelfInteraction(model: model, panel: panel)
        moveTracker = WindowMoveTracker(window: panel)
        state.floatingSize = size
        state.dockedSize = ShelfSizing.remembered(.docked, defaults: .standard)
        // 画面の端で開いたままにするかは、新しい棚のはじめの状態の設定に従う（保存した棚は、あとで戻す）
        state.keepsOpen = !ShelfBehaviorSettings(defaults: .standard).foldsNewShelves

        let hostingView = ShelfHostingView(rootView: ShelfView(
            model: model,
            state: state,
            actions: ShelfActions(
                close: { [weak self] in self?.close() },
                toggleDock: { [weak self] in self?.toggleDock() },
                unfold: { [weak self] in self?.unfold() },
                fold: { [weak self] in self?.foldOrClose() },
                beginRename: { [weak self] in self?.beginRename() },
                commitRename: { [weak self] name in self?.rename(to: name) },
                cancelRename: { [weak self] in self?.state.isRenaming = false },
                setColor: { [weak self] color in self?.setColor(color) },
                toggleFavorite: { [weak self] in self?.toggleFavorite() },
                toggleKeepsOpen: { [weak self] in self?.toggleKeepsOpen() },
                beginResize: { [weak self] in self?.beginResize() },
                resize: { [weak self] handle, delta in self?.resize(handle: handle, by: delta) },
                endResize: { [weak self] in self?.endResize() },
                makeSizeDefault: { [weak self] in self?.makeSizeDefault() },
                resetSize: { [weak self] in self?.resetSize() },
                openSettings: { [weak self] in self?.onOpenSettings?() }
            )
        ))
        // ビューの大きさでウィンドウの大きさを変えない
        hostingView.sizingOptions = []
        // 縁にポインタを乗せたら、その縁を光らせ、大きさを変える形のポインタにする
        hostingView.pointerMoved = { [weak self, weak hostingView] point in
            guard let self, let hostingView else { return nil }
            return self.pointerMoved(to: point, in: hostingView.bounds.size)
        }
        // 開いた棚からポインタが出たら、すぐに確かめて帯にたたむ
        hostingView.onPointerExited = { [weak self] in
            self?.pointerWatcher.pointerExited()
        }
        // しまった帯にポインタを乗せたら出す
        hostingView.onPointerEntered = { [weak self] in
            guard let self, self.state.isFolded else { return }
            self.unfold()
        }
        panel.contentView = hostingView

        moveTracker.onMove = { [weak self] in self?.onMove?() }
        moveTracker.onUserMoveEnded = { [weak self] in self?.finishUserMove() }
    }

    /// Quick Look に見せる中身（棚を帯にたたむ・閉じるときに、Quick Look も閉じる）
    var previewSource: ShelfPreviewSource { interaction.preview }

    /// 出す（まだ出ていなければ、アニメーションで出す。出ていれば前に出す）
    func show() {
        // 消している途中なら、消すのをやめてその場から出し直す
        guard !panel.isVisible || moveTracker.isDismissing else {
            panel.orderFrontRegardless()
            return
        }
        // 浮いた棚は少し小さい状態からふわっと、しまった帯は画面の端の外から滑り込む
        if !moveTracker.isDismissing {
            state.isPresented = false
        }
        moveTracker.present(at: moveTracker.restingFrame, slidingFrom: state.dockedEdge)
        withAnimation(ShelfMotion.animation) {
            state.isPresented = true
        }
    }

    /// アニメーションで消す（浮いた棚はふわっと小さくなって消え、しまった帯は画面の端の外へ滑り出る）
    private func dismissPanel() {
        withAnimation(ShelfMotion.animation) {
            state.isPresented = false
        }
        moveTracker.dismiss(slidingTo: state.dockedEdge)
    }

    /// 閉じる（お気に入りの棚は、中身ごと残して隠す）
    func close() {
        if state.isFavorite {
            hide()
        } else {
            discard()
        }
    }

    /// お気に入りの棚を隠す（メニューバーから出し直せる）
    func hide() {
        previewSource.close()
        pointerWatcher.stop()
        moveTracker.cancelPending()
        state.isRenaming = false
        dismissPanel()
        isHidden = true
        resignEdgeShelf()
        onStateChange?()
    }

    /// 隠していた棚を出し直す（しまっていた棚は、端から出して見せる）
    func showAgain() {
        isHidden = false
        show()
        if state.isDocked {
            unfold(waitForEntry: true)
        }
        onStateChange?()
    }

    /// 閉じて、中身ごと捨てる
    func discard() {
        guard !isDiscarded else { return }
        isDiscarded = true
        previewSource.close()
        pointerWatcher.stop()
        dismissPanel()
        moveTracker.stop()
        model.releaseAccess()
        resignEdgeShelf()
        onClose?(self)
    }

    // MARK: - 枠

    /// しまっているときの枠にする（出ていれば棚の大きさ、帯だけなら帯の大きさ）
    func applyDockedFrame(animated: Bool) {
        guard case .docked(let edge) = state.placement, let screen = dockScreen else { return }
        let size = state.isUnfolded ? state.size : DockLayout.tabSize
        setPanelFrame(DockLayout.frame(edge: edge, centerY: dockCenterY, size: size, in: screen.visibleFrame), animated: animated)
    }

    /// 枠を変える（自分で動かした枠なので、利用者が運んだとは数えない）
    func setPanelFrame(_ frame: CGRect, animated: Bool) {
        moveTracker.setFrame(frame, animated: animated)
    }
}
