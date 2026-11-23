import AppKit
import PinshelfCore

/// 使うキーのコード
enum KeyCode {
    static let space: UInt16 = 49
    static let delete: UInt16 = 51
    static let forwardDelete: UInt16 = 117
    static let escape: UInt16 = 53
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}

/// 棚のキー操作
enum ShelfKeyboard {
    /// - Returns: 処理したら true
    static func handle(_ event: NSEvent, model: ShelfModel, preview: ShelfPreviewSource) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = event.charactersIgnoringModifiers?.lowercased()

        if flags == .command {
            switch key {
            case "a":
                model.selectAll()
                return true
            case "o":
                model.selectedItems.forEach { $0.content.open() }
                return true
            case "y":
                // Finder と同じく ⌘Y でも Quick Look
                preview.toggle()
                return true
            case "v":
                // クリップボードの中身を貼り付ける
                model.pasteFromClipboard()
                return true
            case "z":
                // 最後に棚から外したものを戻す
                model.undoRemoval()
                return true
            case "l":
                // 選んでいるもののロックを切り替える
                model.toggleLockOfSelection()
                return true
            default:
                break
            }
        }

        switch event.keyCode {
        case KeyCode.space where flags.isEmpty:
            preview.toggle()
            return true
        case KeyCode.leftArrow, KeyCode.upArrow:
            model.moveSelection(by: -1)
            return true
        case KeyCode.rightArrow, KeyCode.downArrow:
            model.moveSelection(by: 1)
            return true
        case KeyCode.delete, KeyCode.forwardDelete:
            guard !model.selection.isEmpty else { return false }
            model.removeSelected()
            return true
        case KeyCode.escape:
            guard !model.selection.isEmpty else { return false }
            model.clearSelection()
            return true
        default:
            return false
        }
    }
}
