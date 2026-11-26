// README に載せる見本の画像を作る（make readme-images が動かす）。
//
// 棚・帯は、アプリと同じ部品（ShelfController・ShelfView）で実際に画面に出して写し、架空のデスクトップの上に並べる。
// ファイル・カーソル・デスクトップは絵として描く（自分の画面や、個人の情報は写さない）。
// 作っている間、画面の右端に棚が少しのあいだ出る。
//
// 使い方: ReadmeImages <書き出すフォルダ>
//   - hero.png: 全体の見本（画面の端の棚・帯・浮いた棚・メニューバーのアイコン）
//   - edge.gif: ファイルをドラッグし始める → 画面の端に帯が出る → 近づくと開く → 落とす → 離れると帯にたたむ
//   - shake.gif: ファイルをドラッグしながら振る → カーソルの位置に棚が出る → 落とす
//   - favorites.png: 見出しの ★ でお気に入りにした棚と、お気に入り一覧のウィンドウ
import AppKit
import PinshelfCore
import SwiftUI
import UniformTypeIdentifiers

let outputFolder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images")

// MARK: - 見本のファイル（架空の名前の、空のファイル。アイコンは拡張子で決まる）

let sampleFolder = FileManager.default.temporaryDirectory.appending(path: "Pinshelf-README-Samples", directoryHint: .isDirectory)

func sampleFile(_ name: String) -> URL {
    let url = sampleFolder.appending(path: name)
    if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: Data())
    }
    return url
}

func fileIcon(_ url: URL) -> NSImage {
    NSWorkspace.shared.icon(forFile: url.path)
}

// MARK: - 棚を写す

/// 写した棚（画像は scale 倍。frame は写したときのウィンドウの枠）
struct ShelfShot {
    let image: CGImage
    let frame: CGRect
}

/// 棚のウィンドウの中身を、レイヤーごと描き写す（ウィンドウの影は写らないので、並べるときに描く）
func capture(_ shelf: ShelfController, scale: CGFloat) -> ShelfShot? {
    guard let view = shelf.panel.contentView else { return nil }
    return capture(view, scale: scale).map { ShelfShot(image: $0, frame: shelf.panel.frame) }
}

/// ビューを、レイヤーごと描き写す（scale 倍の画素）
func capture(_ view: NSView, scale: CGFloat) -> CGImage? {
    guard let layer = view.layer else { return nil }
    let size = view.bounds.size
    guard size.width > 0, size.height > 0,
          let context = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.scaleBy(x: scale, y: scale)
    if view.isFlipped {
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
    }
    layer.render(in: context)
    return context.makeImage()
}

/// 動いている間、interval ごとに写す
func record(_ shelf: ShelfController, scale: CGFloat, for duration: Duration, every interval: Duration = .milliseconds(20)) async -> [ShelfShot] {
    var shots: [ShelfShot] = []
    let clock = ContinuousClock()
    let end = clock.now + duration
    while clock.now < end {
        if let shot = capture(shelf, scale: scale) { shots.append(shot) }
        try? await Task.sleep(for: interval)
    }
    return shots
}

/// 速さの変わり方（CAMediaTimingFunction の曲線）で、時間の割合 t（0〜1）のときの進み具合を求める
func progress(_ function: CAMediaTimingFunction, at t: Double) -> Double {
    var p1: [Float] = [0, 0]
    var p2: [Float] = [0, 0]
    function.getControlPoint(at: 1, values: &p1)
    function.getControlPoint(at: 2, values: &p2)
    func bezier(_ s: Double, _ a: Float, _ b: Float) -> Double {
        let a = Double(a), b = Double(b)
        return 3 * a * s * (1 - s) * (1 - s) + 3 * b * s * s * (1 - s) + s * s * s
    }
    // x が t になる s を二分法で探し、そのときの y を返す
    var low = 0.0, high = 1.0
    for _ in 0..<40 {
        let mid = (low + high) / 2
        if bezier(mid, p1[0], p2[0]) < t { low = mid } else { high = mid }
    }
    return bezier((low + high) / 2, p1[1], p2[1])
}

// MARK: - 描く

/// 点（pt）で描くキャンバス（scale 倍の画素で書き出す。原点は左下）
final class Canvas {
    let size: CGSize
    let scale: CGFloat
    let context: CGContext

    init(size: CGSize, scale: CGFloat) {
        self.size = size
        self.scale = scale
        context = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: scale, y: scale)
        context.interpolationQuality = .high
    }

    func image() -> CGImage { context.makeImage()! }

    /// AppKit の描き方（文字・アイコン）を使うときに、このキャンバスを今の描き先にする
    func withAppKit(_ draw: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// デスクトップの背景（gradient が true なら、上から下へ色が変わる）
    func wallpaper(gradient: Bool) {
        let rect = CGRect(origin: .zero, size: size)
        if gradient {
            let colors = [color(0xC9DCF6), color(0xE4D9F3)] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: nil)!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])
        } else {
            context.setFillColor(color(0xDCE5F2))
            context.fill(rect)
        }
    }

    /// 上のメニューバー（右に Pinshelf のアイコンと時計）
    func menuBar(height: CGFloat = 24) {
        let bar = CGRect(x: 0, y: size.height - height, width: size.width, height: height)
        context.setFillColor(color(0xFFFFFF, 0.72))
        context.fill(bar)
        withAppKit {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.black]
            let clock = NSAttributedString(string: "11月26日(水) 10:00", attributes: attributes)
            let clockSize = clock.size()
            clock.draw(at: CGPoint(x: size.width - clockSize.width - 14, y: bar.midY - clockSize.height / 2))
            // Pinshelf のアイコン（メニューバーと同じ 1 色の印）
            if let symbol = AppIcon.symbol(accessibilityDescription: "Pinshelf") {
                let tinted = NSImage(size: CGSize(width: 16, height: 16), flipped: false) { rect in
                    symbol.draw(in: rect)
                    NSColor.black.set()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: CGRect(x: size.width - clockSize.width - 44, y: bar.midY - 8, width: 16, height: 16))
            }
        }
    }

    /// ウィンドウの上のバーの高さ
    static let titleBarHeight: CGFloat = 32

    /// 架空のウィンドウの枠（影・白い地・3 つの丸と題の入った上のバー）を描き、中身を描く場所を返す
    @discardableResult
    func window(_ rect: CGRect, title: String) -> CGRect {
        let barHeight = Self.titleBarHeight
        let path = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: color(0x000000, 0.18))
        context.addPath(path)
        context.setFillColor(color(0xFFFFFF))
        context.fillPath()
        context.restoreGState()
        // 上のバー（3 つの丸と題）
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setFillColor(color(0xF2F3F5))
        context.fill(CGRect(x: rect.minX, y: rect.maxY - barHeight, width: rect.width, height: barHeight))
        context.restoreGState()
        for (index, hex) in [UInt32(0xFF5F57), 0xFEBC2E, 0x28C840].enumerated() {
            context.setFillColor(color(hex))
            context.fillEllipse(in: CGRect(x: rect.minX + 14 + CGFloat(index) * 18, y: rect.maxY - barHeight / 2 - 6, width: 12, height: 12))
        }
        withAppKit {
            let titleText = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.darkGray])
            titleText.draw(at: CGPoint(x: rect.midX - titleText.size().width / 2, y: rect.maxY - barHeight / 2 - titleText.size().height / 2))
        }
        return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - barHeight)
    }

    /// 写したウィンドウの中身を、架空のウィンドウの枠に入れて置く（下の角は枠に合わせて丸める）
    func window(_ rect: CGRect, title: String, content: CGImage) {
        let contentRect = window(rect, title: title)
        context.saveGState()
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil))
        context.clip()
        context.draw(content, in: contentRect)
        context.restoreGState()
    }

    /// ファイルの並んだ、架空のウィンドウ（Finder のような見た目の絵）
    func fileWindow(_ rect: CGRect, title: String, files: [URL], hidden: Set<URL> = []) {
        window(rect, title: title)
        let barHeight = Self.titleBarHeight
        withAppKit {
            // ファイルを並べる（3 列）
            let columns = 3
            let cell = CGSize(width: (rect.width - 24) / CGFloat(columns), height: 92)
            for (index, url) in files.enumerated() where !hidden.contains(url) {
                let column = index % columns
                let row = index / columns
                let origin = CGPoint(x: rect.minX + 12 + CGFloat(column) * cell.width, y: rect.maxY - barHeight - 14 - CGFloat(row + 1) * cell.height)
                fileIcon(url).draw(in: CGRect(x: origin.x + cell.width / 2 - 26, y: origin.y + 30, width: 52, height: 52))
                let name = NSAttributedString(string: url.lastPathComponent, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black])
                name.draw(at: CGPoint(x: origin.x + cell.width / 2 - name.size().width / 2, y: origin.y + 10))
            }
        }
    }

    /// ファイルの並ぶ位置（fileWindow と同じ計算。カーソルを置くため）
    static func fileCenter(in rect: CGRect, index: Int) -> CGPoint {
        let columns = 3
        let cell = CGSize(width: (rect.width - 24) / CGFloat(columns), height: 92)
        let column = index % columns
        let row = index / columns
        return CGPoint(x: rect.minX + 12 + CGFloat(column) * cell.width + cell.width / 2, y: rect.maxY - titleBarHeight - 14 - CGFloat(row + 1) * cell.height + 56)
    }

    /// 写した棚を、影を付けて置く（scale は真ん中を中心にした大きさ。出てくるときの動きに使う）
    func shelf(_ shot: ShelfShot, at origin: CGPoint, alpha: CGFloat = 1, scale: CGFloat = 1) {
        let full = CGRect(origin: origin, size: shot.frame.size)
        let rect = full.insetBy(dx: full.width * (1 - scale) / 2, dy: full.height * (1 - scale) / 2)
        context.saveGState()
        context.setAlpha(alpha)
        context.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0x000000, 0.22))
        context.draw(shot.image, in: rect)
        context.restoreGState()
    }

    /// ドラッグしているファイル（少し透ける）
    func draggedFile(_ url: URL, at point: CGPoint) {
        withAppKit {
            fileIcon(url).draw(in: CGRect(x: point.x - 18, y: point.y - 34, width: 52, height: 52), from: .zero, operation: .sourceOver, fraction: 0.75)
        }
    }

    /// 矢印のカーソル（先端が point）
    func cursor(at point: CGPoint) {
        let path = CGMutablePath()
        path.move(to: point)
        path.addLine(to: CGPoint(x: point.x, y: point.y - 17))
        path.addLine(to: CGPoint(x: point.x + 4, y: point.y - 13))
        path.addLine(to: CGPoint(x: point.x + 7, y: point.y - 20))
        path.addLine(to: CGPoint(x: point.x + 10, y: point.y - 18.5))
        path.addLine(to: CGPoint(x: point.x + 7, y: point.y - 12))
        path.addLine(to: CGPoint(x: point.x + 12, y: point.y - 12))
        path.closeSubpath()
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -1), blur: 2, color: color(0x000000, 0.35))
        context.addPath(path)
        context.setFillColor(color(0x000000))
        context.setStrokeColor(color(0xFFFFFF))
        context.setLineWidth(1.4)
        context.setLineJoin(.round)
        context.drawPath(using: .fillStroke)
        context.restoreGState()
    }
}

// MARK: - 書き出す

func writePNG(_ image: CGImage, to url: URL) throws {
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    try data.write(to: url)
}

/// 画像を縦横 1/factor にする（2 倍で描いたものを、軽い 1 倍にする）
func downscale(_ image: CGImage, by factor: Int) -> CGImage {
    let width = image.width / factor
    let height = image.height / factor
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

func writeGIF(_ frames: [(image: CGImage, delay: Double)], to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for frame in frames {
        CGImageDestinationAddImage(destination, frame.image, [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frame.delay,
                kCGImagePropertyGIFUnclampedDelayTime: frame.delay,
            ],
        ] as CFDictionary)
    }
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

// MARK: - 見本を作る

@MainActor
final class ReadmeImages {
    let screen = NSScreen.main!
    let coordinator = AppCoordinator()

    /// 新しい棚を作る（items を 1 つずつ入れ、name・color・favorite を付ける。size を渡すと、その大きさの浮いた棚にする）
    func makeShelf(
        at point: CGPoint, items: [URL], size: CGSize? = nil, name: String? = nil, color: ShelfColor = .none, favorite: Bool = false
    ) -> ShelfController {
        let shelf = size.map { size in
            ShelfController(id: UUID(), frame: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), model: ShelfModel())
        } ?? ShelfController(centeredAt: point)
        // 本物のマウスが重なっても、ポインタを乗せたときの強調や、帯の開け閉めが写らないようにする
        shelf.panel.ignoresMouseEvents = true
        coordinator.register(shelf)
        // まとめて入れるとスタック（重なった 1 つ）になるので、1 つずつ入れて並べて見せる
        for item in items {
            shelf.model.accept(contents: [.file(item)])
        }
        if let name { shelf.rename(to: name) }
        shelf.setColor(color)
        if favorite { shelf.setFavorite(true) }
        return shelf
    }

    /// 画面の右端にしまう（unfolded なら、ドラッグで近づけたときと同じく開いたまま）
    func dockRight(_ shelf: ShelfController, centerY: CGFloat, unfolded: Bool) {
        shelf.show()
        shelf.dock(to: .right, on: screen, centerY: centerY, unfolded: false, animated: false)
        if unfolded { shelf.unfold(byDrag: true) }
    }

    func settle() async {
        try? await Task.sleep(for: .milliseconds(700))
    }

    func run() async throws {
        try FileManager.default.createDirectory(at: sampleFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        try await makeHero()
        try await makeEdgeGIF()
        try await makeShakeGIF()
        try await makeFavorites()
        for shelf in coordinator.shelves { shelf.discard() }
        try? FileManager.default.removeItem(at: sampleFolder)
    }

    // MARK: hero.png

    func makeHero() async throws {
        let visible = screen.visibleFrame
        let proposal = sampleFile("企画書.pdf")
        let estimate = sampleFile("見積もり.xlsx")
        let logo = sampleFile("ロゴ.png")
        let minutes = sampleFile("議事録.docx")
        let photo = sampleFile("旅行の写真.jpg")
        let memo = sampleFile("打ち合わせメモ.txt")

        let edge = makeShelf(at: CGPoint(x: visible.maxX - 200, y: visible.midY), items: [proposal, estimate, logo])
        // 中身が 2 列に並ぶ幅にする
        edge.state.dockedSize = CGSize(width: 180, height: 250)
        dockRight(edge, centerY: visible.midY + 100, unfolded: true)
        let folded = makeShelf(at: CGPoint(x: visible.maxX - 200, y: visible.midY), items: [minutes, photo, memo, sampleFile("請求書.pdf"), sampleFile("資料.key")], color: .blue)
        dockRight(folded, centerY: visible.midY - 220, unfolded: false)
        let floating = makeShelf(
            at: CGPoint(x: visible.midX, y: visible.midY), items: [photo, memo], size: CGSize(width: 240, height: 190),
            name: "あとで送る", color: .orange, favorite: true
        )
        floating.show()
        await settle()

        let scale: CGFloat = 2
        guard let edgeShot = capture(edge, scale: scale), let foldedShot = capture(folded, scale: scale),
              let floatingShot = capture(floating, scale: scale) else { throw CocoaError(.fileWriteUnknown) }

        let canvas = Canvas(size: CGSize(width: 880, height: 540), scale: scale)
        canvas.wallpaper(gradient: true)
        canvas.fileWindow(CGRect(x: 56, y: 150, width: 330, height: 300), title: "書類", files: [proposal, estimate, logo, minutes, photo, memo])
        canvas.shelf(floatingShot, at: CGPoint(x: 420, y: 240))
        canvas.shelf(edgeShot, at: CGPoint(x: canvas.size.width - edgeShot.frame.width, y: 240))
        canvas.shelf(foldedShot, at: CGPoint(x: canvas.size.width - foldedShot.frame.width, y: 90))
        canvas.cursor(at: CGPoint(x: 822, y: 300))
        canvas.menuBar()
        try writePNG(canvas.image(), to: outputFolder.appending(path: "hero.png"))
        print("書き出しました: hero.png")
        for shelf in [edge, folded, floating] { shelf.discard() }
        await settle()
    }

    // MARK: edge.gif

    func makeEdgeGIF() async throws {
        let visible = screen.visibleFrame
        let proposal = sampleFile("企画書.pdf")
        let estimate = sampleFile("見積もり.xlsx")
        let logo = sampleFile("ロゴ.png")
        let scale: CGFloat = 2

        // 本物の棚で、帯 → 開く → 落とす → たたむ を写す
        let shelf = makeShelf(at: CGPoint(x: visible.maxX - 200, y: visible.midY), items: [])
        dockRight(shelf, centerY: visible.midY, unfolded: false)
        await settle()
        guard let tab = capture(shelf, scale: scale) else { throw CocoaError(.fileWriteUnknown) }
        shelf.unfold(byDrag: true)
        let unfolding = await record(shelf, scale: scale, for: .milliseconds(320))
        await settle()
        shelf.model.accept(contents: [.file(proposal)])
        await settle()
        guard let filled = capture(shelf, scale: scale) else { throw CocoaError(.fileWriteUnknown) }
        shelf.fold()
        let folding = await record(shelf, scale: scale, for: .milliseconds(320))
        await settle()
        guard let filledTab = capture(shelf, scale: scale) else { throw CocoaError(.fileWriteUnknown) }
        shelf.discard()

        // 架空のデスクトップの上に並べる
        let size = CGSize(width: 640, height: 400)
        let window = CGRect(x: 36, y: 96, width: 270, height: 230)
        let files = [proposal, estimate, logo]
        let shelfCenterY: CGFloat = 196
        let start = Canvas.fileCenter(in: window, index: 0)
        var frames: [(image: CGImage, delay: Double)] = []

        /// 1 コマを描く（shot: 右端の棚、shotOffset: 端の外へのずれ、dragging: ドラッグしているか）
        func frame(cursor: CGPoint, shot: ShelfShot?, shotOffset: CGFloat = 0, shotAlpha: CGFloat = 1, dragging: Bool, fileInWindow: Bool, delay: Double) {
            let canvas = Canvas(size: size, scale: scale)
            canvas.wallpaper(gradient: false)
            canvas.fileWindow(window, title: "書類", files: files, hidden: fileInWindow ? [] : [proposal])
            if let shot {
                let origin = CGPoint(x: size.width - shot.frame.width + shotOffset, y: shelfCenterY - shot.frame.height / 2)
                canvas.shelf(shot, at: origin, alpha: shotAlpha)
            }
            canvas.menuBar(height: 22)
            if dragging { canvas.draggedFile(proposal, at: cursor) }
            canvas.cursor(at: cursor)
            frames.append((downscale(canvas.image(), by: Int(scale)), delay))
        }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }

        // 1. ファイルの上にカーソル
        frame(cursor: start, shot: nil, dragging: false, fileInWindow: true, delay: 0.8)
        // 2. ドラッグし始めると、画面の端に帯が滑り込む
        let approach = CGPoint(x: 470, y: shelfCenterY + 10)
        for step in 1...12 {
            let t = CGFloat(step) / 12
            let slide = min(1, CGFloat(step) / 5)
            frame(cursor: lerp(start, approach, t), shot: tab, shotOffset: ShelfMotion.slideDistance * (1 - slide), shotAlpha: slide,
                  dragging: true, fileInWindow: true, delay: 0.05)
        }
        // 3. 帯に近づくと、棚が開く
        let inside = CGPoint(x: size.width - 70, y: shelfCenterY + 6)
        let unfoldFrames = Array(unfolding.prefix(12))
        for (index, shot) in unfoldFrames.enumerated() {
            let t = CGFloat(index + 1) / CGFloat(unfoldFrames.count)
            frame(cursor: lerp(approach, inside, t), shot: shot, dragging: true, fileInWindow: true, delay: 0.04)
        }
        frame(cursor: inside, shot: unfoldFrames.last, dragging: true, fileInWindow: true, delay: 0.5)
        // 4. 落とすと、棚に入る（元のファイルは動かない）
        frame(cursor: inside, shot: filled, dragging: false, fileInWindow: true, delay: 1.0)
        // 5. 離れると、帯にたたむ（件数が出る）
        let away = CGPoint(x: 400, y: shelfCenterY - 30)
        let foldFrames = Array(folding.prefix(14))
        for (index, shot) in foldFrames.enumerated() {
            let t = min(1, CGFloat(index + 1) / 6)
            frame(cursor: lerp(inside, away, t), shot: shot, dragging: false, fileInWindow: true, delay: 0.04)
        }
        frame(cursor: away, shot: filledTab, dragging: false, fileInWindow: true, delay: 1.6)

        try writeGIF(frames, to: outputFolder.appending(path: "edge.gif"))
        print("書き出しました: edge.gif（\(frames.count) コマ）")
    }

    // MARK: shake.gif

    func makeShakeGIF() async throws {
        let visible = screen.visibleFrame
        let proposal = sampleFile("企画書.pdf")
        let estimate = sampleFile("見積もり.xlsx")
        let logo = sampleFile("ロゴ.png")
        let scale: CGFloat = 2

        // 本物の棚で、空の棚と、落としたあとの棚を写す
        let shelf = makeShelf(at: CGPoint(x: visible.midX, y: visible.midY), items: [], size: CGSize(width: 220, height: 170))
        shelf.show()
        await settle()
        guard let empty = capture(shelf, scale: scale) else { throw CocoaError(.fileWriteUnknown) }
        shelf.model.accept(contents: [.file(proposal)])
        await settle()
        guard let filled = capture(shelf, scale: scale) else { throw CocoaError(.fileWriteUnknown) }
        shelf.discard()
        await settle()

        // 架空のデスクトップの上に並べる
        let size = CGSize(width: 640, height: 400)
        let window = CGRect(x: 36, y: 96, width: 270, height: 230)
        let files = [proposal, estimate, logo]
        let start = Canvas.fileCenter(in: window, index: 0)
        // 振る場所（棚は、ここを真ん中にして出る）
        let shakeCenter = CGPoint(x: 470, y: 214)
        var frames: [(image: CGImage, delay: Double)] = []

        /// 1 コマを描く（shot: 出ている棚、appear: 出てくる動きの進み具合（0〜1）、dragging: ドラッグしているか）
        func frame(cursor: CGPoint, shot: ShelfShot?, appear: CGFloat = 1, dragging: Bool, delay: Double) {
            let canvas = Canvas(size: size, scale: scale)
            canvas.wallpaper(gradient: false)
            canvas.fileWindow(window, title: "書類", files: files)
            if let shot {
                // アプリと同じく、少し小さい状態からふわっと出す
                let origin = CGPoint(x: shakeCenter.x - shot.frame.width / 2, y: shakeCenter.y - shot.frame.height / 2)
                canvas.shelf(shot, at: origin, alpha: appear, scale: ShelfMotion.appearScale + (1 - ShelfMotion.appearScale) * appear)
            }
            canvas.menuBar(height: 22)
            if dragging { canvas.draggedFile(proposal, at: cursor) }
            canvas.cursor(at: cursor)
            frames.append((downscale(canvas.image(), by: Int(scale)), delay))
        }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }

        // 1. ファイルの上にカーソル
        frame(cursor: start, shot: nil, dragging: false, delay: 0.8)
        // 2. ドラッグして、何もないところへ運ぶ
        for step in 1...10 {
            frame(cursor: lerp(start, shakeCenter, CGFloat(step) / 10), shot: nil, dragging: true, delay: 0.05)
        }
        // 3. 左右に軽く振る
        let swings: [CGFloat] = [0, 32, -32, 32, -32, 24, 0]
        for (from, to) in zip(swings, swings.dropFirst()) {
            for step in 1...2 {
                let x = from + (to - from) * CGFloat(step) / 2
                frame(cursor: CGPoint(x: shakeCenter.x + x, y: shakeCenter.y), shot: nil, dragging: true, delay: 0.035)
            }
        }
        // 4. カーソルの位置に棚が出る（アプリと同じ長さ・同じ速さの変わり方）
        let appearFrames = max(1, Int((ShelfMotion.duration / 0.03).rounded()))
        for step in 1...appearFrames {
            let t = progress(ShelfMotion.timingFunction, at: Double(step) / Double(appearFrames))
            frame(cursor: shakeCenter, shot: empty, appear: CGFloat(t), dragging: true, delay: 0.03)
        }
        frame(cursor: shakeCenter, shot: empty, dragging: true, delay: 0.6)
        // 5. 落とすと、棚に入る（元のファイルは動かない）
        frame(cursor: shakeCenter, shot: filled, dragging: false, delay: 0.9)
        // 6. カーソルを離す
        let away = CGPoint(x: shakeCenter.x - 40, y: 70)
        for step in 1...6 {
            frame(cursor: lerp(shakeCenter, away, CGFloat(step) / 6), shot: filled, dragging: false, delay: 0.04)
        }
        frame(cursor: away, shot: filled, dragging: false, delay: 1.5)

        try writeGIF(frames, to: outputFolder.appending(path: "shake.gif"))
        print("書き出しました: shake.gif（\(frames.count) コマ）")
    }

    // MARK: favorites.png

    func makeFavorites() async throws {
        let visible = screen.visibleFrame
        let scale: CGFloat = 2

        // 見出しの ★ でお気に入りにした棚
        let shelf = makeShelf(
            at: CGPoint(x: visible.midX - 220, y: visible.midY), items: [sampleFile("旅行の写真.jpg"), sampleFile("打ち合わせメモ.txt")],
            size: CGSize(width: 250, height: 190), name: "あとで送る", color: .orange, favorite: true
        )
        shelf.show()

        // お気に入り一覧（アプリと同じ画面に、見本の棚を並べる）
        let list = FavoriteShelvesList()
        let entries = [
            FavoriteShelfEntry(id: shelf.id, title: "あとで送る", color: .orange, count: 2, isVisible: true),
            FavoriteShelfEntry(id: UUID(), title: "デザイン素材", color: .purple, count: 8, isVisible: false),
            FavoriteShelfEntry(id: UUID(), title: "請求書の控え", color: .green, count: 3, isVisible: false),
        ]
        list.load = { entries }
        list.reload()
        let controller = NSHostingController(rootView: FavoritesListView(list: list))
        controller.sizingOptions = []
        let listWindow = NSWindow(contentViewController: controller)
        listWindow.styleMask = [.titled, .closable, .resizable]
        listWindow.title = "お気に入り一覧"
        // 高さは一覧の最小（これより低いと、下の説明が切れる）
        listWindow.setContentSize(NSSize(width: 340, height: 200))
        listWindow.setFrameOrigin(CGPoint(x: visible.midX + 20, y: visible.midY - 100))
        listWindow.ignoresMouseEvents = true
        listWindow.orderFrontRegardless()
        await settle()

        guard let shelfShot = capture(shelf, scale: scale), let listView = listWindow.contentView,
              let listShot = capture(listView, scale: scale) else { throw CocoaError(.fileWriteUnknown) }
        let listSize = listView.bounds.size
        listWindow.orderOut(nil)
        shelf.discard()
        await settle()

        let canvas = Canvas(size: CGSize(width: 800, height: 340), scale: scale)
        canvas.wallpaper(gradient: true)
        // メニューバーの下の真ん中に、棚と一覧の高さをそろえて並べる
        let middle = (canvas.size.height - 24) / 2
        let shelfOrigin = CGPoint(x: 70, y: middle - shelfShot.frame.height / 2)
        canvas.shelf(shelfShot, at: shelfOrigin)
        let windowHeight = listSize.height + Canvas.titleBarHeight
        let windowRect = CGRect(x: 400, y: middle - windowHeight / 2, width: listSize.width, height: windowHeight)
        canvas.window(windowRect, title: "お気に入り一覧", content: listShot)
        // 見出しの ★ を指す（★ が隠れないよう、少し右下に）
        canvas.cursor(at: CGPoint(x: shelfOrigin.x + 72, y: shelfOrigin.y + shelfShot.frame.height - 27))
        canvas.menuBar()
        try writePNG(canvas.image(), to: outputFolder.appending(path: "favorites.png"))
        print("書き出しました: favorites.png")
    }
}

// MARK: - 起動

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
// README は明るい見た目で作る（ダークモードの Mac でも同じ画像になるように）
app.appearance = NSAppearance(named: .aqua)
let generator = ReadmeImages()
Task { @MainActor in
    do {
        try await generator.run()
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("README の画像を作れませんでした: \(error)\n".utf8))
        exit(1)
    }
}
app.run()
