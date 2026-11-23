import AppKit
import PinshelfCore
import SwiftUI

/// 画面端にしまう・出す・帯にたたむ、画面端の棚の役目
extension ShelfController {
    // MARK: - しまう・戻す

    /// しまったときの帯の枠
    var tabFrame: CGRect? {
        guard case .docked(let edge) = state.placement, let screen = dockScreen else { return nil }
        return DockLayout.frame(edge: edge, centerY: dockCenterY, size: DockLayout.tabSize, in: screen.visibleFrame)
    }

    /// しまう・浮かせるを切り替える（見出しのボタン・ダブルクリック）
    func toggleDock() {
        if state.isDocked {
            undock(animated: true)
            return
        }
        let frame = panel.frame
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = NSScreen.containing(center) else { return }
        let edge = EdgeGeometry.edge(forCursor: center, in: screen.frame, preference: .nearest)
        dock(to: edge, on: screen, centerY: frame.midY, unfolded: false, animated: true)
    }

    /// 画面端にしまう
    ///
    /// 開いたままにする棚（見出しのピンがオン）なら、unfolded にかかわらず開いたまま端に置く。
    /// - Parameters:
    ///   - centerY: 帯を置きたい高さ（ほかの帯と重なるときは、近くの空いたところに置く）
    ///   - unfolded: しまったあとも棚を出したままにするか
    func dock(to edge: ScreenEdge, on screen: NSScreen, centerY: CGFloat, unfolded: Bool, animated: Bool) {
        let unfolded = unfolded || state.keepsOpen
        setDockPosition(edge: edge, on: screen, centerY: centerY)
        // 帯と棚のフェードを、枠のアニメーションとそろえる（枠が縮むと、棚が端へ滑り込むように見える）
        withAnimation(animated ? ShelfMotion.animation : nil) {
            state.placement = .docked(edge)
            state.isUnfolded = unfolded
        }
        isUnfoldedByDrag = false
        if !unfolded {
            previewSource.close()
        }
        applyDockedFrame(animated: animated)
        if unfolded {
            startPointerWatch()
        } else {
            pointerWatcher.stop()
        }
        onStateChange?()
    }

    /// しまった棚の帯の位置を変える（画面端の棚が、ドラッグ中にカーソルについていく・反対の端へ移るとき）
    ///
    /// 出ているか帯だけかは変えない。アニメーションはしない。
    func moveDock(to edge: ScreenEdge, on screen: NSScreen, centerY: CGFloat) {
        guard state.isDocked else { return }
        setDockPosition(edge: edge, on: screen, centerY: centerY)
        state.placement = .docked(edge)
        applyDockedFrame(animated: false)
    }

    /// 帯を置く画面・高さを決める（ほかの帯と重なるときは、近くの空いたところに置く）
    private func setDockPosition(edge: ScreenEdge, on screen: NSScreen, centerY: CGFloat) {
        let occupied = occupiedTabRanges?(self, edge, screen) ?? []
        dockScreen = screen
        dockCenterY = DockLayout.freeCenterY(
            desired: centerY,
            height: DockLayout.tabSize.height,
            occupied: occupied,
            in: screen.visibleFrame
        )
    }

    /// 浮いた棚に戻す（画面端の棚なら、ただの浮いた棚になる。次のドラッグでは、新しい画面端の棚が出る）
    /// - Parameter frame: 戻す枠（nil なら、帯の近くに戻す）
    func undock(to frame: CGRect? = nil, animated: Bool) {
        guard case .docked(let edge) = state.placement, let screen = dockScreen else { return }
        let size = state.floatingSize
        let target: CGRect
        if let frame {
            // 運んで放した位置に、浮いているときの大きさで置く（見出しをつかんでいるので、左上をそろえる）
            let placed = CGRect(x: frame.minX, y: frame.maxY - size.height, width: size.width, height: size.height)
            target = EdgeGeometry.fit(placed, into: [screen.visibleFrame])
        } else {
            target = DockLayout.undockedFrame(edge: edge, centerY: dockCenterY, size: size, in: screen.visibleFrame)
        }
        pointerWatcher.stop()
        withAnimation(animated ? ShelfMotion.animation : nil) {
            state.placement = .floating
            state.isUnfolded = false
        }
        isUnfoldedByDrag = false
        setPanelFrame(target, animated: animated)
        resignEdgeShelf()
        onStateChange?()
    }

    /// しまった棚を端から出す
    /// - Parameter waitForEntry: true なら、ポインタが一度棚に入るまで引っ込めない（メニューから出したときなど）
    func unfold(byDrag: Bool = false, waitForEntry: Bool = false) {
        guard state.isFolded else { return }
        // 枠が広がると、棚が端から滑り出るように開く
        withAnimation(ShelfMotion.animation) {
            state.isUnfolded = true
        }
        isUnfoldedByDrag = byDrag
        applyDockedFrame(animated: true)
        if !byDrag {
            startPointerWatch(waitForEntry: waitForEntry)
        }
    }

    /// 開いた棚を、端の帯にたたむ
    func fold() {
        guard state.isDocked, state.isUnfolded else { return }
        previewSource.close()
        pointerWatcher.stop()
        // すぐに動き出して、画面の端に向かってなめらかに止まる。棚は、滑り込んでいる間は見えたままにする
        withAnimation(ShelfMotion.foldFadeAnimation) {
            state.isUnfolded = false
        }
        isUnfoldedByDrag = false
        applyDockedFrame(animated: true, timing: ShelfMotion.foldTimingFunction)
    }

    /// 開いた棚を帯にたたむ（見出しの › ボタン・ポインタが離れたとき）
    ///
    /// 空になった画面端の棚は、帯を残さずに閉じる（次のドラッグで、また端に出る）。
    /// 落としたものを読み込んでいる途中は、空に見えても閉じない。
    func foldOrClose() {
        if state.isEdgeShelf, model.isEmpty, model.isSettled, !state.isFavorite {
            close()
        } else {
            fold()
        }
    }

    /// 画面の端で開いたままにする・しないを切り替える（見出しのピン）
    ///
    /// 開いたままにしたら、たたんである帯を開く。しないにしたら、開いている棚をたたむ（ポインタが棚の上にあれば、離れたときにたたむ）。
    func toggleKeepsOpen() {
        state.keepsOpen.toggle()
        onStateChange?()
        guard state.isDocked, !isHidden else { return }
        if state.keepsOpen {
            pointerWatcher.stop()
            unfold()
        } else {
            guard state.isUnfolded, !isUnfoldedByDrag else { return }
            if panel.frame.contains(NSEvent.mouseLocation) {
                startPointerWatch()
            } else {
                foldOrClose()
            }
        }
    }

    /// 開いた棚からポインタが離れたら、帯にたたむ（開いたままにする棚なら見張らない）
    func startPointerWatch(waitForEntry: Bool = false) {
        guard !state.keepsOpen else {
            pointerWatcher.stop()
            return
        }
        pointerWatcher.start(
            waitForEntry: waitForEntry,
            frame: { [weak self] in self?.panel.frame ?? .zero },
            isActive: { [weak self] in
                guard let self else { return false }
                return self.state.isDocked && self.state.isUnfolded && !self.isUnfoldedByDrag
            },
            // Quick Look で見ている間・名前を入力している間は引っ込めない
            defersFolding: { [weak self] in
                guard let self else { return false }
                return self.previewSource.isShowing || self.state.isRenaming || self.state.isResizing
            },
            onLeave: { [weak self] in self?.foldOrClose() }
        )
    }

    // MARK: - ほかのアプリからのドラッグ中

    /// ドラッグ中に、しまった帯に近づいたら棚を出す・離れたら引っ込める
    func dragMoved(to point: CGPoint) {
        guard state.isDocked else { return }
        if state.isFolded {
            guard let tab = tabFrame, tab.insetBy(dx: -40, dy: -24).contains(point) else { return }
            unfold(byDrag: true)
        } else if isUnfoldedByDrag, !panel.frame.insetBy(dx: -24, dy: -24).contains(point), !state.keepsOpen {
            fold()
        }
    }

    /// ドラッグが終わった（落としたあともポインタが棚の上にあれば、離れるまで出しておく）
    func dragEnded() {
        guard isUnfoldedByDrag else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard self.isUnfoldedByDrag else { return }
            self.finishDragUnfold()
        }
    }

    /// ドラッグで出した棚を、ドラッグが終わったあとの形にする
    ///
    /// ポインタが棚の上にあれば、離れるまで出しておく。離れていれば帯にたたむ（たたまない設定なら、開いたまま）。
    func finishDragUnfold() {
        isUnfoldedByDrag = false
        guard state.isDocked, state.isUnfolded else { return }
        if panel.frame.contains(NSEvent.mouseLocation) {
            startPointerWatch()
        } else if !state.keepsOpen {
            foldOrClose()
        }
    }

    // MARK: - 画面端の棚

    /// 画面端の棚にする（ドラッグに合わせて出し入れする）
    func becomeEdgeShelf() {
        state.isEdgeShelf = true
    }

    /// 画面端の棚をやめる（浮かせた・閉じた・隠したとき）
    func resignEdgeShelf() {
        guard state.isEdgeShelf else { return }
        state.isEdgeShelf = false
        onResignEdgeShelf?(self)
    }

    // MARK: - 利用者が運んだとき

    /// 見出しをつかんで運び終えた: 画面の端まで運んだらしまい、開いた棚を端から離したら浮かせる
    func finishUserMove() {
        let frame = panel.frame
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.containing(pointer) ?? NSScreen.containing(CGPoint(x: frame.midX, y: frame.midY)) else { return }

        switch state.placement {
        case .floating:
            // 画面の端まで運んだら、しまう（しまわない設定なら、はみ出した分を戻して画面の中に収める）
            if let edge = DockLayout.dockEdge(windowFrame: frame, pointer: pointer, screenFrame: screen.frame, visibleFrame: screen.visibleFrame) {
                if ShelfBehaviorSettings(defaults: .standard).docksWhenDraggedToEdge {
                    dock(to: edge, on: screen, centerY: frame.midY, unfolded: false, animated: true)
                } else {
                    let fitted = EdgeGeometry.fit(frame, into: [screen.visibleFrame])
                    if fitted != frame {
                        setPanelFrame(fitted, animated: true)
                    }
                }
            }
        case .docked(let edge):
            if DockLayout.staysDocked(windowFrame: frame, edge: edge, visibleFrame: screen.visibleFrame) {
                // 端に沿って運んだ: 帯の位置を変え、出したままにする
                dock(to: edge, on: screen, centerY: frame.midY, unfolded: true, animated: true)
            } else {
                // 端から離した: 浮いた棚に戻す
                dockScreen = screen
                // 浮いているときの大きさに変わるので、アニメーションで変える
                undock(to: frame, animated: true)
            }
        }
    }
}
