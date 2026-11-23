import AppKit
import PinshelfCore

/// アプリの入口
///
/// メニューバーに常駐し、ふだんは Dock には出さない（Info.plist の LSUIElement。設定・お気に入り一覧を開いている間だけ出す。DockIcon）。
/// メニューバーのアイコンにドロップを受けるため、SwiftUI の MenuBarExtra ではなく AppKit の NSStatusItem を使う。
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = AppCoordinator()
    private let launchAtLogin = LaunchAtLogin()
    private lazy var settingsWindow = SettingsWindowController(launchAtLogin: launchAtLogin)
    private lazy var favoritesWindow = FavoritesWindowController(list: coordinator.favoritesList)
    private var statusItem: StatusItemController?
    private lazy var mainMenu = MainMenu(openSettings: { [weak self] in self?.openSettings() })
    /// 終了の合図（killall など）を受けて、ふつうに終了する（棚を保存してから止まる）
    private var terminateSignal: (any DispatchSourceSignal)?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    /// Dock のアイコンを押したとき（設定・お気に入り一覧を開いている間だけ Dock に出る）。開いているウィンドウを前に出す
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DockIcon.bringWindowsToFront()
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 確認の画面などに出すアイコンを、作ったアイコンにする（Dock に出すときは、DockIcon がもう一度設定する）
        AppIcon.applyToApp()
        mainMenu.install()
        handleTerminateSignal()
        coordinator.openSettings = { [weak self] in self?.openSettings() }
        coordinator.start()

        let statusItem = StatusItemController()
        statusItem.onNewShelf = { [weak self] in self?.coordinator.openShelfFromMenu() }
        statusItem.onOpenEdgeShelf = { [weak self] in self?.coordinator.openEdgeShelf() }
        statusItem.onOpenSettings = { [weak self] in self?.openSettings() }
        statusItem.favoriteShelves = { [weak self] in self?.coordinator.favoriteShelfEntries() ?? [] }
        statusItem.onSelectFavoriteShelf = { [weak self] id in self?.coordinator.showFavoriteShelf(id: id) }
        statusItem.onRemoveFavoriteShelf = { [weak self] id in self?.coordinator.removeFavorite(id: id) }
        statusItem.onOpenFavorites = { [weak self] in self?.favoritesWindow.show() }
        statusItem.onAddFromClipboard = { [weak self] iconFrame in self?.coordinator.addFromClipboard(below: iconFrame) }
        statusItem.recentShelves = { [weak self] in self?.coordinator.recentShelfEntries() ?? [] }
        statusItem.onReopenRecentShelf = { [weak self] id in self?.coordinator.reopenRecentShelf(id: id) }
        statusItem.onClearRecentShelves = { [weak self] in self?.coordinator.clearRecentShelves() }
        statusItem.dropOperation = { [weak self] in self?.coordinator.menuBarDropOperation() ?? [] }
        statusItem.onDrop = { [weak self] pasteboard, iconFrame in
            self?.coordinator.handleMenuBarDrop(pasteboard, below: iconFrame) ?? false
        }
        self.statusItem = statusItem
    }

    /// 設定のウィンドウを開く（メニューバーのアイコン・上のメニューバー・棚のメニューから）
    private func openSettings() {
        settingsWindow.show()
    }

    /// 終了するとき（メニューの終了・ログアウト・make stop など）、棚を保存する
    func applicationWillTerminate(_ notification: Notification) {
        coordinator.stop()
    }

    /// killall（make run・make stop）で送られる終了の合図でも、すぐには止まらず、ふつうに終了する
    private func handleTerminateSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                NSApp.terminate(nil)
            }
        }
        source.resume()
        terminateSignal = source
    }
}
