import AppKit

/// 上のメニューバーに出すアプリのメニュー（設定…・終了・編集・ウインドウを閉じる）
///
/// Dock に出ている間（設定を開いている間）は、Pinshelf が前面のアプリになり、上のメニューバーにこのメニューが出る。
/// 編集メニューは、文字の欄（設定の大きさの欄・棚の名前）で ⌘C・⌘V・⌘A・⌘Z を効かせるためのもの
/// （キーの組み合わせはメニューを通して届く）。棚のキー操作（⌘A・⌘V・⌘Z など）は、棚がメニューより先に受け取る（ShelfPanel）
final class MainMenu: NSObject {
    private let onOpenSettings: () -> Void

    /// - Parameter openSettings: 「設定…」（⌘,）で、設定のウィンドウを開く
    init(openSettings: @escaping () -> Void) {
        onOpenSettings = openSettings
    }

    /// メニューを作って、アプリのメニューにする（起動したときに一度だけ呼ぶ）
    func install() {
        let mainMenu = NSMenu()
        mainMenu.addItem(submenuItem(appMenu()))
        mainMenu.addItem(submenuItem(editMenu()))
        mainMenu.addItem(submenuItem(windowMenu()))
        NSApp.mainMenu = mainMenu
    }

    /// アプリのメニュー（名前は macOS がアプリの名前に置き換える）
    private func appMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "設定…", action: #selector(openSettings(_:)), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Pinshelf を終了", action: #selector(quit(_:)), keyEquivalent: "q").target = self
        return menu
    }

    /// 編集（文字の欄に、応答の連鎖で届ける）
    private func editMenu() -> NSMenu {
        let menu = NSMenu(title: "編集")
        menu.addItem(withTitle: "取り消す", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "やり直す", action: Selector(("redo:")), keyEquivalent: "z").keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "カット", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "コピー", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "ペースト", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "すべてを選択", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    /// ウインドウ（設定のウインドウを ⌘W で閉じる。閉じるボタンのない棚では効かない）
    private func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "ウインドウ")
        menu.addItem(withTitle: "ウインドウを閉じる", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }

    private func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }

    // MARK: - 操作

    @objc private func openSettings(_ sender: Any?) {
        onOpenSettings()
    }

    /// 終了する（⌘Q）。ただし棚がキーのとき（棚をクリックした直後など）は終了しない。
    /// 上のメニューバーには前のアプリ（Safari など）が出ていて、そのアプリを終了するつもりで押すことが多いため（Pinshot と同じ）
    @objc private func quit(_ sender: Any?) {
        if NSApp.keyWindow is ShelfPanel {
            NSSound.beep()
            return
        }
        NSApp.terminate(sender)
    }
}
