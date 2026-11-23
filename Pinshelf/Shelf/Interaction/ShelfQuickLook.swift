import AppKit
import PinshelfCore
import QuickLookUI

/// Quick Look のパネルに、棚で選んでいるものを見せる
///
/// Quick Look のパネルは、キーウィンドウからたどれるところで
/// `acceptsPreviewPanelControl(_:)` に応えたものを「操作する係」にする。
/// 棚のウィンドウ（`ShelfPanel`）がそれに応え、この係にデータを任せる。
final class ShelfPreviewSource: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private weak var model: ShelfModel?
    private weak var panel: ShelfPanel?
    private var items: [ShelfPreviewItem] = []
    /// 今 Quick Look のパネルを操作しているか
    private var isControlling = false
    /// テキストを見せるために書き出した一時ファイル
    private var textFiles: [ShelfItem.ID: URL] = [:]

    init(model: ShelfModel, panel: ShelfPanel) {
        self.model = model
        self.panel = panel
    }

    /// この棚のものを Quick Look で見せているか
    var isShowing: Bool {
        isControlling && QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    /// 出す・閉じるを切り替える（スペースキー）
    func toggle() {
        if isShowing {
            QLPreviewPanel.shared().orderOut(nil)
        } else {
            show()
        }
    }

    /// 選んでいるものを Quick Look で見せる。何も選んでいなければ、最初に見られるものを選ぶ
    func show() {
        guard let model, let panel else { return }
        if model.selection.isEmpty, let first = model.items.first(where: { $0.content.isPreviewable }) {
            model.click(first, modifier: .none)
        }
        refreshItems()
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        // Quick Look は、キーウィンドウから操作する係を探す
        panel.makeKey()
        let previewPanel = QLPreviewPanel.shared()!
        Self.keepAboveShelves(previewPanel)
        if isControlling {
            previewPanel.reloadData()
        }
        previewPanel.makeKeyAndOrderFront(nil)
    }

    /// 閉じる（棚を畳む・閉じるとき）
    func close() {
        if isShowing {
            QLPreviewPanel.shared().orderOut(nil)
        }
    }

    /// 選んでいるものが変わったら、見せている中身を合わせる
    func selectionChanged() {
        guard isShowing else { return }
        refreshItems()
        if items.isEmpty {
            QLPreviewPanel.shared().orderOut(nil)
        } else {
            QLPreviewPanel.shared().reloadData()
        }
    }

    // MARK: - パネルの操作（ShelfPanel から呼ぶ）

    func beginControl(_ previewPanel: QLPreviewPanel) {
        isControlling = true
        refreshItems()
        previewPanel.dataSource = self
        previewPanel.delegate = self
        Self.keepAboveShelves(previewPanel)
        previewPanel.reloadData()
    }

    /// Pinshelf は前面のアプリにならないので、棚より上に出し、ほかのアプリに移っても隠さない
    private static func keepAboveShelves(_ previewPanel: QLPreviewPanel) {
        previewPanel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        previewPanel.hidesOnDeactivate = false
    }

    func endControl(_ previewPanel: QLPreviewPanel) {
        isControlling = false
        previewPanel.dataSource = nil
        previewPanel.delegate = nil
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        items.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        items.indices.contains(index) ? items[index] : nil
    }

    // MARK: - QLPreviewPanelDelegate

    /// 1 つだけ見ているときは、矢印キーで棚の中の選択を動かす（Finder と同じ）
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let event, event.type == .keyDown, items.count <= 1, let model else { return false }
        switch event.keyCode {
        case KeyCode.leftArrow, KeyCode.upArrow:
            model.moveSelection(by: -1)
            return true
        case KeyCode.rightArrow, KeyCode.downArrow:
            model.moveSelection(by: 1)
            return true
        default:
            return false
        }
    }

    // MARK: - 見せるもの

    private func refreshItems() {
        guard let model else {
            items = []
            return
        }
        items = model.selectedItems.compactMap { item in
            switch item.content {
            case .file(let url):
                return ShelfPreviewItem(url: url, title: item.content.displayName)
            case .text(let text):
                guard let url = textFile(for: item.id, text: text) else { return nil }
                return ShelfPreviewItem(url: url, title: item.content.displayName)
            case .link:
                return nil
            }
        }
    }

    /// テキストを Quick Look で見せるための一時ファイル
    private func textFile(for id: ShelfItem.ID, text: String) -> URL? {
        if let url = textFiles[id] { return url }
        let directory = FileManager.default.temporaryDirectory.appending(path: "Pinshelf-QuickLook", directoryHint: .isDirectory)
        let url = directory.appending(path: "\(id.uuidString).txt")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            return nil
        }
        textFiles[id] = url
        return url
    }
}

/// Quick Look に渡す 1 つのもの（題名を中身の名前にするため）
nonisolated final class ShelfPreviewItem: NSObject, QLPreviewItem {
    let previewItemURL: URL?
    let previewItemTitle: String?

    init(url: URL, title: String) {
        previewItemURL = url
        previewItemTitle = title
    }
}
