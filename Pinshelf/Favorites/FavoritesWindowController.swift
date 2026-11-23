import AppKit
import SwiftUI

/// お気に入り一覧のウィンドウ（メニューバーの「お気に入り一覧…」から開く）
///
/// 設定のウィンドウと同じく、開いている間は Dock に出す
final class FavoritesWindowController {
    private let list: FavoriteShelvesList
    private var window: NSWindow?

    init(list: FavoriteShelvesList) {
        self.list = list
    }

    func show() {
        list.reload()
        let window = self.window ?? makeWindow()
        self.window = window
        DockIcon.present(window)
    }

    private func makeWindow() -> NSWindow {
        let controller = NSHostingController(rootView: FavoritesListView(list: list))
        // 大きさは使う人が決める（中身に合わせて変えると、一覧が空になったときに縮んでしまう）
        controller.sizingOptions = []
        let window = NSWindow(contentViewController: controller)
        window.title = "お気に入り一覧"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 360, height: 320))
        window.contentMinSize = NSSize(width: 300, height: 200)
        window.isReleasedWhenClosed = false
        window.center()
        // 動かした位置と大きさを覚えておく
        window.setFrameAutosaveName("FavoritesWindow")
        return window
    }
}
