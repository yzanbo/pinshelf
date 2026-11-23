import AppKit
import PinshelfCore

/// 棚のウィンドウを自分で動かす（アニメーションで出す・消す・枠を変える）、
/// 利用者が見出しをつかんで運び終えたのを知らせる（画面端の棚・浮いた棚で使う）
///
/// 自分で枠を動かしている間（アニメーションの途中も含む）は、利用者が運んだとは数えない。
/// 運んでいる最中ではなく、マウスのボタンを離したときに知らせる。
final class WindowMoveTracker {
    /// 動いたとき（利用者・自分のどちらでも。保存のため）
    var onMove: (() -> Void)?
    /// 利用者が運び終えた（ボタンを離した）
    var onUserMoveEnded: (() -> Void)?

    private weak var window: NSWindow?
    private var observer: (any NSObjectProtocol)?
    /// 自分で枠を動かしている間
    private var isPositioning = false
    /// ボタンを離すのを待つ
    private var pending: Task<Void, Never>?
    /// 自分で動かすアニメーションの番号（新しく動かし始めたら、古いアニメーションの「終えた」を無視する）
    private var generation = 0
    /// アニメーションを終えたときに落ち着く枠（消すときは、消し終えたあとに戻す枠。動かしていなければ nil）
    private var settlingFrame: CGRect?
    /// 消すアニメーションの途中か
    private(set) var isDismissing = false

    /// 落ち着いたときの枠（アニメーションの途中なら、その行き先）
    var restingFrame: CGRect {
        settlingFrame ?? window?.frame ?? .zero
    }

    init(window: NSWindow) {
        self.window = window
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.windowDidMove()
            }
        }
    }

    /// 自分で枠を変える（この動きは、利用者が運んだとは数えない）
    /// - Parameter timing: アニメーションの速さの変わり方（帯にたたむときは、たたむとき用のもの）
    func setFrame(_ frame: CGRect, animated: Bool, timing: CAMediaTimingFunction = ShelfMotion.timingFunction) {
        guard let window else { return }
        // 消している途中なら、消し終えたあとに戻す枠だけを変える（動かすと、消えずに透明なまま残る）
        if isDismissing {
            settlingFrame = frame
            return
        }
        isPositioning = true
        if animated {
            animate(to: frame, timing: timing) {
                window.animator().setFrame(frame, display: true)
            }
        } else {
            generation += 1
            settlingFrame = nil
            // 長さ 0 のアニメーションで変える。ふつうの setFrame だと、動いている途中のアニメーションが枠を上書きし続け、
            // 最後はアニメーションの行き先に戻ってしまう（開いた直後の棚の縁をつかんで大きさを変えたときなど）
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                window.animator().setFrame(frame, display: true)
            }
            isPositioning = false
        }
    }

    /// アニメーションで出す（フェードイン。edge を渡すと、その画面の端の外から滑り込む）
    ///
    /// 消している途中に呼んでもよい（消すのをやめて、その場から出し直す）。
    func present(at frame: CGRect, slidingFrom edge: ScreenEdge? = nil) {
        guard let window else { return }
        isPositioning = true
        if !isDismissing {
            // 見えていないなら、画面の端の外の透明な位置から始める
            window.setFrame(Self.offset(frame, toward: edge), display: false)
            window.alphaValue = 0
        }
        isDismissing = false
        window.orderFrontRegardless()
        animate(to: frame, timing: ShelfMotion.timingFunction) {
            window.animator().setFrame(frame, display: true)
            window.animator().alphaValue = 1
        }
    }

    /// アニメーションで消す（フェードアウト。edge を渡すと、その画面の端の外へ滑り出る）
    func dismiss(slidingTo edge: ScreenEdge? = nil) {
        guard let window, window.isVisible, !isDismissing else { return }
        let resting = restingFrame
        generation += 1
        let current = generation
        settlingFrame = resting
        isDismissing = true
        isPositioning = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = ShelfMotion.duration * 0.8
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(Self.offset(resting, toward: edge), display: true)
            window.animator().alphaValue = 0
        } completionHandler: { [weak self, window] in
            // 閉じた棚のコントローラーが先に片付いても、消し終えるまではウィンドウを残し、最後に片付ける
            MainActor.assumeIsolated {
                // 消す途中で出し直したら、何もしない
                if let self, self.generation != current { return }
                window.orderOut(nil)
                window.alphaValue = 1
                window.setFrame(self?.settlingFrame ?? resting, display: false)
                self?.isDismissing = false
                self?.settlingFrame = nil
                self?.isPositioning = false
            }
        }
    }

    /// 枠のアニメーションを始める（いちばん新しいアニメーションを終えたときだけ、自分で動かしている印を外す）
    private func animate(to frame: CGRect, timing: CAMediaTimingFunction, changes: () -> Void) {
        generation += 1
        let current = generation
        settlingFrame = frame
        NSAnimationContext.runAnimationGroup { context in
            context.duration = ShelfMotion.duration
            context.timingFunction = timing
            changes()
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.generation == current else { return }
                self.settlingFrame = nil
                self.isPositioning = false
            }
        }
    }

    /// 画面の端の外へずらした枠（滑り込む・滑り出るときの、はじめ・終わりの位置）
    private static func offset(_ frame: CGRect, toward edge: ScreenEdge?) -> CGRect {
        guard let edge else { return frame }
        let distance = ShelfMotion.slideDistance
        return frame.offsetBy(dx: edge == .right ? distance : -distance, dy: 0)
    }

    /// 待っている「運び終えた」の知らせをやめる
    func cancelPending() {
        pending?.cancel()
        pending = nil
    }

    /// 見張りをやめる（ウィンドウを閉じるとき）
    func stop() {
        cancelPending()
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func windowDidMove() {
        onMove?()
        guard !isPositioning else { return }
        // 運び終える（ボタンを離す）のを待ってから知らせる
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            while NSEvent.pressedMouseButtons & 1 != 0 {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled else { return }
            self?.onUserMoveEnded?()
        }
    }
}
