import AppKit

/// ほかのアプリで始まったドラッグも含めて、ドラッグの始まり・動き・終わりを見つける
///
/// アクセシビリティの権限を使わずに済むように、次の組み合わせで判断する。
/// - マウスのボタンが押されたら（グローバルのイベント監視）、ドラッグ用のペーストボードの
///   `changeCount` を覚えて、ボタンが離されるまで位置を調べ続ける
/// - 押している間に `changeCount` が変わったら、何かがドラッグされ始めたと見なす
final class DragMonitor {
    /// ドラッグが始まった（位置・始まった Pinshelf のウィンドウ。ほかのアプリで始まったら nil）
    var onDragBegan: ((CGPoint, NSWindow?) -> Void)?
    /// ドラッグ中にカーソルが動いた（位置・時刻）
    var onDragMoved: ((CGPoint, TimeInterval) -> Void)?
    /// ドラッグが終わった（ボタンが離された）
    var onDragEnded: (() -> Void)?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var monitors: [Any] = []
    private var pollTimer: Timer?
    private var baselineChangeCount = 0
    /// ボタンが押された Pinshelf のウィンドウ
    private weak var pressWindow: NSWindow?
    private var isDragging = false

    /// 押している間に位置を調べる間隔（60 回/秒）
    private static let pollInterval: TimeInterval = 1.0 / 60.0

    func start() {
        guard monitors.isEmpty else { return }

        // ほかのアプリでボタンが押された
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            self?.mouseWentDown(in: nil)
        }) {
            monitors.append(global)
        }

        // Pinshelf の中（棚など）でボタンが押された
        if let local = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] event in
            self?.mouseWentDown(in: event.window)
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        stopPolling()
        isDragging = false
    }

    private func mouseWentDown(in window: NSWindow?) {
        baselineChangeCount = dragPasteboard.changeCount
        pressWindow = window
        startPolling()
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        // ドラッグ中（イベントを追うモード）でも止まらないように common モードに入れる
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        let isButtonDown = NSEvent.pressedMouseButtons & 1 != 0
        let location = NSEvent.mouseLocation

        guard isButtonDown else {
            stopPolling()
            if isDragging {
                isDragging = false
                onDragEnded?()
            }
            return
        }

        if !isDragging {
            // ボタンを押しただけ（クリックやウィンドウの移動）ならドラッグではない
            guard dragPasteboard.changeCount != baselineChangeCount else { return }
            isDragging = true
            onDragBegan?(location, pressWindow)
        }
        onDragMoved?(location, ProcessInfo.processInfo.systemUptime)
    }
}
