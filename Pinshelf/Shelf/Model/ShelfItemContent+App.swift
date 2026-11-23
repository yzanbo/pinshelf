import AppKit
import PinshelfCore

extension ShelfItemContent {
    /// 棚に出す名前
    var displayName: String {
        switch self {
        case .file(let url):
            return FileManager.default.displayName(atPath: url.path)
        case .link(let url):
            return url.host() ?? url.absoluteString
        case .text(let text):
            let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines).first ?? ""
            return line.count > 40 ? String(line.prefix(40)) + "…" : line
        }
    }

    /// ポインタを重ねたときの説明
    var detail: String {
        switch self {
        case .file(let url): url.path
        case .link(let url): url.absoluteString
        case .text(let text): text
        }
    }

    /// Quick Look で見られるか（リンクは開くだけ）
    var isPreviewable: Bool {
        switch self {
        case .file, .text: true
        case .link: false
        }
    }

    /// 既定のアプリで開く（ファイル）・ブラウザで開く（リンク）
    func open() {
        switch self {
        case .file(let url), .link(let url):
            NSWorkspace.shared.open(url)
        case .text:
            break
        }
    }
}

extension StoredShelf {
    /// 名前のない棚を一覧に出すときの名前（「議事録.pdf ほか 2 個」など）
    var summaryTitle: String {
        guard let first = items.first else { return "空の棚" }
        let name: String = switch first.content {
        case .file(let path, _): FileManager.default.displayName(atPath: path)
        case .link(let url): url.host() ?? url.absoluteString
        case .text(let text): ShelfItemContent.text(text).displayName
        }
        return items.count > 1 ? "\(name) ほか \(items.count - 1) 個" : name
    }
}

extension ShelfItemContent {
    /// ドラッグで渡す中身（ファイル・リンクは URL、テキストは文字列）
    var pasteboardWriter: any NSPasteboardWriting {
        switch self {
        case .file(let url), .link(let url): url as NSURL
        case .text(let text): text as NSString
        }
    }

    /// ドラッグ中に見せる画像
    func dragImage(size: CGFloat) -> NSImage {
        let image: NSImage
        switch self {
        case .file(let url):
            image = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage) ?? NSImage()
        case .link:
            image = Self.symbolImage("link", size: size)
        case .text:
            image = Self.symbolImage("text.alignleft", size: size)
        }
        image.size = NSSize(width: size, height: size)
        return image
    }

    private static func symbolImage(_ name: String, size: CGFloat) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: size * 0.6, weight: .medium)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
    }
}
