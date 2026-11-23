import AppKit
import PinshelfCore
import UniformTypeIdentifiers

/// ドラッグのペーストボードから棚の中身を取り出す（メニューバーのアイコンに落とされたとき）
enum PasteboardReader {
    static func contents(from pasteboard: NSPasteboard) -> [ShelfItemContent] {
        // ファイルを先に見る（ファイルの URL は、ふつうの URL としても読めてしまうため）
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !files.isEmpty {
            return files.map { .file($0) }
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            return urls.map { $0.isFileURL ? .file($0) : .link($0) }
        }
        if let texts = pasteboard.readObjects(forClasses: [NSString.self]) as? [String] {
            return texts
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { .text($0) }
        }
        return []
    }
}

/// ドロップされた NSItemProvider から棚の中身を取り出す
enum ItemProviderLoader {
    static func contents(from providers: [NSItemProvider]) async -> [ShelfItemContent] {
        var result: [ShelfItemContent] = []
        for provider in providers {
            if let content = await content(from: provider) {
                result.append(content)
            }
        }
        return result
    }

    private static func content(from provider: NSItemProvider) async -> ShelfItemContent? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await loadURL(from: provider) {
            return .file(url)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = await loadURL(from: provider) {
            return url.isFileURL ? .file(url) : .link(url)
        }
        if provider.canLoadObject(ofClass: String.self),
           let text = await loadString(from: provider),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(text)
        }
        return nil
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    private static func loadString(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }
}
