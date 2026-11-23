import AppKit
import QuickLookUI

/// 棚のウィンドウ
///
/// 前面のアプリからフォーカスを奪わず（nonactivatingPanel）、すべてのデスクトップと
/// フルスクリーンのアプリの上にも出る。
final class ShelfPanel: NSPanel {
    /// キー操作を受け取る（処理したら true を返す）
    var keyHandler: ((NSEvent) -> Bool)?
    /// 左ボタンのマウスのイベントを先に受け取る（ドラッグで取り出し始めたら true を返す）
    var mouseHandler: ((NSEvent) -> Bool)?
    /// Quick Look に見せる中身
    var previewSource: ShelfPreviewSource?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // 角丸の外の透明なところも、クリックを下のウィンドウへ素通りさせない（角をつかんで大きさを変えられるように）
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    // キー操作（スペースキーで Quick Look など）のために、キーウィンドウにはなれるようにする
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// ⌘ の付いたキー（⌘A・⌘V・⌘Z など）は、アプリのメニュー（編集メニュー）より先に、棚のキー操作として受け取る。
    /// macOS は ⌘ の付いたキーを、キーウィンドウ → メニューの順に渡し、どちらも受けなかったときだけ sendEvent に届けるため
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, handleShelfKey(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if handleShelfKey(event) { return }
        case .leftMouseDown, .leftMouseDragged, .leftMouseUp:
            // ドラッグで取り出し始めたら、そのイベントは SwiftUI に渡さない
            if mouseHandler?(event) == true { return }
        default:
            break
        }
        super.sendEvent(event)
    }

    /// 棚のキー操作として受け取る（処理したら true）。名前を入力している途中は、文字の欄に任せる
    private func handleShelfKey(_ event: NSEvent) -> Bool {
        !(firstResponder is NSText) && keyHandler?(event) == true
    }

    // MARK: - Quick Look のパネルの操作
    // NSObject のカテゴリーのメソッドなので nonisolated で受ける。Quick Look はメインスレッドから呼ぶ

    nonisolated override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        MainActor.assumeIsolated {
            previewSource != nil
        }
    }

    nonisolated override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            if let panel { previewSource?.beginControl(panel) }
        }
    }

    nonisolated override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            if let panel { previewSource?.endControl(panel) }
        }
    }
}
