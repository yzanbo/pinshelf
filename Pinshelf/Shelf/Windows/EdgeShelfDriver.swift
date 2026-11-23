import AppKit
import PinshelfCore

/// 画面端の棚を、ドラッグに合わせて出す
///
/// 画面端の棚は、振って出す棚と同じ棚（`ShelfController`）を画面端にしまったもの。
/// 特別なのは「出すまで」だけで、出たあとは、真ん中で作って画面端にしまった棚とまったく同じに動く
/// （運んだ場所にとどまり、ドラッグが帯の近くに来たときに開く）。
/// - ドラッグを始めたとき（設定によっては、端に近づいたとき）に、設定の端・高さに帯を出す
///   （開いたままにする棚＝新しい棚のはじめの状態の設定がオンなら、最初から開いて出す）
/// - 出したドラッグの間だけ、ポインタが棚に届くまで、カーソルに合わせて動かす（「近いほう」の端・「カーソルの高さ」）
/// - 何も置かずにドラッグを終えた空の棚は閉じる（次のドラッグで、また新しく出す）
/// - 浮かせる・閉じると、ただの棚になる。次のドラッグでは、新しい画面端の棚を出す
/// - 画面の端にしまった棚がほかにあれば、新しくは出さない（その棚が、帯の近くに来たら開く）
final class EdgeShelfDriver {
    /// 今の画面端の棚（出していなければ nil）
    private(set) var shelf: ShelfController?
    /// 新しい棚を作って覚えてもらう（出すのはこちらでする）
    var makeShelf: ((CGPoint) -> ShelfController?)?
    /// 画面の端にしまってある棚（隠していないもの）
    var dockedShelves: (() -> [ShelfController])?

    /// 棚を出す端（最後に出した端を保存して、次に起動したときに使う）
    private(set) var edge: ScreenEdge = .right
    private var screen: NSScreen?
    private var isDragging = false
    /// 出す端・出すとき・出す高さ（ドラッグを始めたとき・メニューから開くときに受け取る）
    private var settings = TriggerSettings.defaults
    /// カーソルの高さに出すときの高さ
    private var anchorY: CGFloat?
    /// 今のドラッグで、新しい画面端の棚を出してよいか（画面端の棚がすでにある・ほかのしまった棚があるときは出さない）
    private var mayOpenNewShelf = false
    /// 今のドラッグで新しく出した棚を、まだカーソルに合わせて動かすか（ポインタが棚に届いたら止める）
    private var isPlacingNewShelf = false
    /// 今のドラッグで新しく出した棚を、最初から開いて出したか（たたんでおかない設定のとき）
    private var openedUnfolded = false

    // MARK: - ドラッグ中

    func dragBegan(at point: CGPoint, settings: TriggerSettings) {
        isDragging = true
        self.settings = settings
        anchorY = point.y
        mayOpenNewShelf = false
        isPlacingNewShelf = false
        guard let current = NSScreen.containing(point) else { return }
        screen = current
        // 画面端の棚がすでにあれば、ほかのしまった棚と同じく、置いてある場所で帯の近くに来たら開く（ここでは何もしない）
        guard shelf == nil else { return }
        // 画面の端にしまった棚がほかにあれば、新しくは出さない（その棚が、帯の近くに来たら開く）
        guard existing(on: current).isEmpty else { return }
        mayOpenNewShelf = true
        edge = EdgeGeometry.edge(forCursor: point, in: current.frame, preference: settings.edgePreference)
        if settings.edgeRevealTiming == .onDragStart {
            openNewShelf(near: point)
        }
        update(for: point)
    }

    func dragMoved(to point: CGPoint) {
        guard isDragging, mayOpenNewShelf else { return }
        update(for: point)
    }

    func dragEnded() {
        isDragging = false
        mayOpenNewShelf = false
        isPlacingNewShelf = false
        // ドロップの読み込みを待ってから片付ける
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            self.settleAfterDrag()
        }
    }

    /// 新しく出す帯を、カーソルに合わせる（まだ出していなければ、端に近づいたときに出す）
    ///
    /// 開く・帯にたたむは、棚が自分でする（ほかのしまった棚と同じく、ドラッグが帯の近くに来たら開く）。
    private func update(for point: CGPoint) {
        guard let current = NSScreen.containing(point) else { return }
        guard let shelf else {
            // 端に近づいてから出す設定: 出してよい端に近づいたら出す
            guard let approached = allowedEdges.first(where: { EdgeGeometry.isApproaching(point, edge: $0, in: current.frame) }) else { return }
            screen = current
            edge = approached
            anchorY = point.y
            openNewShelf(near: point)
            return
        }
        // 出したドラッグの間で、ポインタが棚に届くまでだけ動かす（届いたら、ほかのしまった棚と同じくその場にとどめる）
        let hasReachedShelf = openedUnfolded
            ? shelf.panel.frame.insetBy(dx: -24, dy: -24).contains(point)
            : shelf.state.isUnfolded
        guard isPlacingNewShelf, !hasReachedShelf else {
            isPlacingNewShelf = false
            return
        }
        var moves = false
        // 別の画面へ移ったら、その画面の端へ
        if current != screen {
            screen = current
            moves = true
        }
        // 「近いほう」なら、カーソルが近づいた側の端へ
        if settings.edgePreference == .nearest {
            for candidate in ScreenEdge.allCases where candidate != edge
                && EdgeGeometry.isApproaching(point, edge: candidate, in: current.frame) {
                edge = candidate
                moves = true
            }
        }
        // 「カーソルの高さ」なら、帯をカーソルの高さについてこさせる（帯の近くまで行かなくても開けるように）。
        // 最初から開いて出した棚は、高さは動かさない（落とそうとしている棚が逃げないように）
        if settings.edgeVerticalPosition == .cursor, !openedUnfolded, anchorY.map({ abs($0 - point.y) > 0.5 }) ?? true {
            anchorY = point.y
            moves = true
        }
        if moves {
            place(shelf)
        }
    }

    /// 棚を出してよい端（端を決めてある設定ならその端だけ）
    private var allowedEdges: [ScreenEdge] {
        switch settings.edgePreference {
        case .left: [.left]
        case .right: [.right]
        case .nearest: ScreenEdge.allCases
        }
    }

    /// その画面の、出してよい端にしまってある既存の棚（画面端の棚そのものは除く）
    private func existing(on target: NSScreen) -> [ShelfController] {
        (dockedShelves?() ?? []).filter { candidate in
            guard candidate !== shelf, candidate.dockScreen == target, let edge = candidate.state.dockedEdge else { return false }
            return allowedEdges.contains(edge)
        }
    }

    /// 帯がその高さにいちばん近い棚
    private static func nearest(_ candidates: [ShelfController], toY y: CGFloat) -> ShelfController? {
        candidates.min { abs(($0.tabFrame?.midY ?? y) - y) < abs(($1.tabFrame?.midY ?? y) - y) }
    }

    /// ドラッグが終わった: 何も置かれなかった空の棚は閉じる（ポインタが棚の上にあるうちは、離れるまで待つ）
    private func settleAfterDrag() {
        guard !isDragging, let shelf else { return }
        guard shelf.model.isSettled else {
            // まだ読み込み中なら少し待つ
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                self.settleAfterDrag()
            }
            return
        }
        let isPointerInside = shelf.state.isUnfolded && shelf.panel.frame.contains(NSEvent.mouseLocation)
        if shelf.model.isEmpty, !shelf.state.isFavorite, !isPointerInside {
            shelf.close()
        }
    }

    // MARK: - ドラッグ以外

    /// メニューから・メニューバーのアイコンに落としたあとに開く（ポインタが棚に入らないまま時間がたったら、帯にたたむ）
    func showShelf(near point: CGPoint, settings: TriggerSettings) {
        self.settings = settings
        let target: ShelfController?
        if let shelf {
            // 置いてある場所で開く（ほかのしまった棚と同じく、動かさない）
            shelf.show()
            target = shelf
        } else if let existing = nearestExisting(near: point) {
            // 画面の端にしまった棚がすでにあれば、新しくは作らずに、それを開く
            existing.show()
            target = existing
        } else {
            target = openForInbox(near: point)
        }
        target?.unfold(waitForEntry: true)
    }

    /// 画面端の棚を返す（なければ、帯だけの新しい棚を端に出す。メニューバーのアイコン・クリップボードから入れるとき）
    func shelfForInbox(near point: CGPoint, settings: TriggerSettings) -> ShelfController? {
        if let shelf { return shelf }
        self.settings = settings
        // 画面の端にしまった棚がすでにあれば、それに入れる
        if let existing = nearestExisting(near: point) {
            return existing
        }
        return openForInbox(near: point)
    }

    /// ポインタのある画面の、出してよい端にしまってある既存の棚のうち、帯がポインタの高さにいちばん近いもの
    private func nearestExisting(near point: CGPoint) -> ShelfController? {
        guard let current = NSScreen.containing(point) ?? NSScreen.main else { return nil }
        return Self.nearest(existing(on: current), toY: point.y)
    }

    private func openForInbox(near point: CGPoint) -> ShelfController? {
        guard let current = NSScreen.containing(point) ?? NSScreen.main else { return nil }
        screen = current
        anchorY = point.y
        edge = EdgeGeometry.edge(forCursor: point, in: current.frame, preference: settings.edgePreference)
        return openNewShelf(near: point, placesWithCursor: false)
    }

    // MARK: - 保存と復元

    /// 保存しておいた画面端の棚を、また画面端の棚にする（起動したとき。置いてあった場所のまま）
    func restore(_ restored: ShelfController) {
        guard shelf == nil, restored.state.isDocked else { return }
        adopt(restored)
        if let dockedEdge = restored.state.dockedEdge {
            edge = dockedEdge
        }
    }

    /// 前の形式で保存した画面端の棚の中身を、新しい画面端の棚に入れて、帯を出す（起動したとき）
    func restoreLegacy(_ restored: RestoredShelf, edge savedEdge: ScreenEdge?, settings: TriggerSettings) {
        guard shelf == nil, !restored.shelf.items.isEmpty, let main = NSScreen.main else { return }
        self.settings = settings
        screen = main
        anchorY = main.visibleFrame.midY
        edge = preferredEdge(current: savedEdge ?? edge)
        openNewShelf(near: CGPoint(x: main.visibleFrame.midX, y: main.visibleFrame.midY), placesWithCursor: false)?.model.restore(restored)
    }

    // MARK: - しまった棚の帯との関係

    /// まだ画面端の棚がないとき、帯を出す縦の範囲（しまった棚の帯を、重ならないように置くため）
    ///
    /// 画面端の棚があるときは、その帯がほかの帯と同じように避けられるので nil。カーソルの高さに出すときも、決まった範囲がないので nil。
    func reservedTabRange(on screen: NSScreen, vertical: EdgeVerticalPosition) -> ClosedRange<CGFloat>? {
        guard shelf == nil, vertical != .cursor else { return nil }
        let frame = EdgeGeometry.edgeFrame(size: DockLayout.tabSize, edge: edge, in: screen.visibleFrame, vertical: vertical, anchorY: nil)
        return frame.minY...frame.maxY
    }

    // MARK: - 棚

    /// 新しい画面端の棚を作り、設定の端・高さに出す（画面の端の外から滑り込む）
    ///
    /// 新しい棚を開いたままにする設定（見出しのピンのはじめの状態）がオンなら最初から開いて、オフなら細い帯で出す。
    /// - Parameter placesWithCursor: 今のドラッグの間、ポインタが棚に届くまで、カーソルに合わせて動かすか
    @discardableResult
    private func openNewShelf(near point: CGPoint, placesWithCursor: Bool = true) -> ShelfController? {
        guard let screen = screen ?? NSScreen.containing(point), let created = makeShelf?(point) else { return nil }
        self.screen = screen
        adopt(created)
        // 開いたままにする棚（新しい棚のはじめの状態の設定がオン）は、dock が開いたまま置く
        created.dock(to: edge, on: screen, centerY: tabCenterY(on: screen), unfolded: false, animated: false)
        openedUnfolded = created.state.keepsOpen
        created.show()
        isPlacingNewShelf = placesWithCursor && isDragging
        return created
    }

    /// 画面端の棚として覚える（浮かせた・閉じたら忘れる）
    private func adopt(_ adopted: ShelfController) {
        shelf = adopted
        adopted.becomeEdgeShelf()
        adopted.onResignEdgeShelf = { [weak self] resigned in
            guard let self, self.shelf === resigned else { return }
            self.shelf = nil
        }
    }

    /// 新しく出した帯を、今の端・高さに置き直す（出したドラッグの間だけ）
    private func place(_ target: ShelfController) {
        guard let screen = screen ?? target.dockScreen else { return }
        target.moveDock(to: edge, on: screen, centerY: tabCenterY(on: screen))
    }

    /// 帯の中心の高さ（設定の高さ。カーソルの高さに出すなら、カーソルの高さ）
    private func tabCenterY(on screen: NSScreen) -> CGFloat {
        EdgeGeometry.edgeFrame(
            size: DockLayout.tabSize,
            edge: edge,
            in: screen.visibleFrame,
            vertical: settings.edgeVerticalPosition,
            anchorY: anchorY
        ).midY
    }

    /// 出す端（端を決めてある設定ならその端、「近いほう」なら今の端のまま）
    private func preferredEdge(current: ScreenEdge) -> ScreenEdge {
        switch settings.edgePreference {
        case .left: .left
        case .right: .right
        case .nearest: current
        }
    }
}
