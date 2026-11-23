import AppKit

/// 開いた棚からポインタが離れたら、すぐに知らせる（画面の端の棚で使う）
///
/// 「ポインタが外へ出た」の知らせ（`pointerExited()`）を受けたら、その場で確かめる。
/// ドラッグの直後などは、その知らせが届かないことがあるので、短い間隔で位置も直接調べる。
final class PointerLeaveWatcher {
    /// ポインタが棚の外とみなすまでの、棚の枠からの距離（pt。縁ぎりぎりで帯にたたまれないよう、ほんの少しだけ）
    private static let margin: CGFloat = 2
    /// 位置を直接調べる間隔
    private static let pollInterval: Duration = .milliseconds(80)
    /// 一度も入らないまま、離れたとみなすまでの時間（メニューから出したときなど）
    private static let entryTimeout: Duration = .seconds(4)

    private struct Watch {
        let frame: () -> CGRect
        let isActive: () -> Bool
        let defersFolding: () -> Bool
        let onLeave: () -> Void
        let entryDeadline: ContinuousClock.Instant
        var hasEntered: Bool
    }

    private var watch: Watch?
    private var task: Task<Void, Never>?

    /// 見張りを始める（前の見張りはやめる）
    /// - Parameters:
    ///   - waitForEntry: true なら、ポインタが一度棚に入るまで待つ（4 秒入らなければ離れたとみなす）
    ///   - frame: 棚の今の枠
    ///   - isActive: false になったら見張りをやめる（ドラッグが始まった・帯にたたんだなど）
    ///   - defersFolding: true の間は、離れていても帯にたたまない（Quick Look で見ている間など）
    ///   - onLeave: 離れたとき
    func start(
        waitForEntry: Bool,
        frame: @escaping () -> CGRect,
        isActive: @escaping () -> Bool,
        defersFolding: @escaping () -> Bool,
        onLeave: @escaping () -> Void
    ) {
        stop()
        MenuTracking.startObserving()
        watch = Watch(
            frame: frame,
            isActive: isActive,
            // 次の間も、帯にたたまない
            // - メニュー（… のメニュー・右クリックのメニュー）を開いている間（メニューは棚の外に出るため）
            // - マウスのボタンを押している間（見出しをつかんで運んでいる・中身を取り出している間。
            //   運んでいる窓がポインタに少し遅れると、一瞬だけポインタが棚の外に出るため）
            defersFolding: { defersFolding() || MenuTracking.isTracking || NSEvent.pressedMouseButtons & 1 != 0 },
            onLeave: onLeave,
            entryDeadline: ContinuousClock.now + Self.entryTimeout,
            hasEntered: !waitForEntry
        )
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard !Task.isCancelled else { return }
                self?.check()
            }
        }
    }

    /// ポインタが棚の外へ出たと知らされた（すぐに確かめる）
    func pointerExited() {
        check()
    }

    func stop() {
        task?.cancel()
        task = nil
        watch = nil
    }

    /// ポインタが棚の上にあるかを確かめ、離れていたら知らせる
    private func check() {
        guard var current = watch else { return }
        guard current.isActive() else {
            stop()
            return
        }
        let isInside = current.frame().insetBy(dx: -Self.margin, dy: -Self.margin).contains(NSEvent.mouseLocation)
        if isInside || current.defersFolding() {
            if isInside { current.hasEntered = true }
            watch = current
            return
        }
        // 一度も入っていないときは、決めた時間までは待つ
        if !current.hasEntered, ContinuousClock.now < current.entryDeadline {
            return
        }
        let onLeave = current.onLeave
        stop()
        onLeave()
    }
}

/// メニューを開いているか（メニューは棚の外に出るので、開いている間は棚を帯にたたまない）
enum MenuTracking {
    private(set) static var isTracking = false
    private static var observers: [any NSObjectProtocol] = []

    /// メニューを開いた・閉じたの知らせを受け始める（何度呼んでもよい）
    static func startObserving() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { isTracking = true }
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { isTracking = false }
            },
        ]
    }
}
