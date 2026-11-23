import AppKit
import PinshelfCore
import SwiftUI

/// 設定のウィンドウ。macOS の設定画面と同じく、上のツールバーのタブで項目を分ける
///
/// メニューバー常駐のアプリでは SwiftUI の Settings が後ろに隠れることがあるので、自前のウィンドウで開き、前面に出す。
final class SettingsWindowController {
    private let launchAtLogin: LaunchAtLogin
    private var window: NSWindow?

    init(launchAtLogin: LaunchAtLogin) {
        self.launchAtLogin = launchAtLogin
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // 開いている間は Dock にアイコンを出す（Dock と ⌘Tab から戻れるように。閉じたら消える）
        DockIcon.present(window)
    }

    private func makeWindow() -> NSWindow {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        // 一般 → 棚の出し方 → 棚そのもの → 中身 → 例外、の順に並べる
        tabs.addTabViewItem(makeTab("一般", symbol: "gearshape", view: GeneralSettingsView(launchAtLogin: launchAtLogin)))
        tabs.addTabViewItem(makeTab("出し方", symbol: "cursorarrow.motionlines", view: TriggerSettingsView()))
        tabs.addTabViewItem(makeTab("棚", symbol: "rectangle.stack", view: ShelfSettingsView()))
        tabs.addTabViewItem(makeTab("中身", symbol: "tray.full", view: ContentsSettingsView()))
        tabs.addTabViewItem(makeTab("除外するアプリ", symbol: "nosign", view: IgnoredAppsSettingsView()))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        // 最初のタブの名前を、ウィンドウの名前にする（何もしないと「Untitled」になる）
        window.title = tabs.tabViewItems.first?.label ?? "設定"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func makeTab<Content: View>(_ label: String, symbol: String, view: Content) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view)
        controller.title = label
        // タブごとの中身の大きさに合わせて、ウィンドウの大きさを変える
        controller.sizingOptions = [.preferredContentSize]
        let item = NSTabViewItem(viewController: controller)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }
}

/// 設定のタブ。選んだタブの名前を、ウィンドウの名前にする（macOS の設定画面と同じ）
private final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        if let label = tabViewItem?.label {
            view.window?.title = label
        }
    }
}
