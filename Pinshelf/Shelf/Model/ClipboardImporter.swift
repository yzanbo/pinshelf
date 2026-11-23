import AppKit
import PinshelfCore

/// クリップボードの中身を、棚に入れる形にする
///
/// - Finder でコピーしたファイルは、ファイルとして入れる
/// - 画像（スクリーンショットをクリップボードに撮ったときなど）は、PNG のファイルにして入れる
/// - URL はリンク、文字はテキストとして入れる
enum ClipboardImporter {
    private static let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]

    /// 画像を保存するフォルダ（Application Support/Pinshelf/Clipboard。サンドボックスのコンテナの中）
    static var folder: URL {
        ShelfSnapshotStore.defaultFileURL()
            .deletingLastPathComponent()
            .appending(path: ClipboardFiles.folderName, directoryHint: .isDirectory)
    }

    /// クリップボードに、棚に入れられるものがあるか（種類だけを見て、中身は読まない）
    static func hasContents(_ pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.availableType(from: [.fileURL, .URL, .png, .tiff, .string]) != nil
    }

    /// クリップボードの中身を、棚に入れる形にする
    static func contents(from pasteboard: NSPasteboard = .general, now: Date = .now) -> [ShelfItemContent] {
        // ファイル（Finder でコピーしたものなど）を先に見る。ファイルにはアイコンの画像も付いているため
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !files.isEmpty {
            return files.map { .file($0) }
        }
        // 画像はファイルにする
        if let type = pasteboard.availableType(from: imageTypes),
           let data = pasteboard.data(forType: type),
           let url = saveImage(data, isPNG: type == .png, at: now) {
            return [.file(url)]
        }
        return PasteboardReader.contents(from: pasteboard)
    }

    private static func saveImage(_ data: Data, isPNG: Bool, at date: Date) -> URL? {
        let png = isPNG ? data : NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
        guard let png else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            let name = ClipboardFiles.uniqueName(ClipboardFiles.imageFileName(at: date), existing: existing)
            let url = folder.appending(path: name)
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// どの棚にも置いていない画像を片付ける（起動したときに呼ぶ）
    static func cleanUp(keeping referencedPaths: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for url in ClipboardFiles.unreferenced(files, referencedPaths: referencedPaths) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
