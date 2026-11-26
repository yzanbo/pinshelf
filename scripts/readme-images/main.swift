// README に載せる見本の画像を作る（make readme-images が動かす）。
//
// 棚・帯は、アプリと同じ部品（ShelfController・ShelfView）で実際に画面に出して写し、架空のデスクトップの上に並べる。
// ファイル・カーソル・デスクトップは絵として描く（自分の画面や、個人の情報は写さない）。
// 作っている間、画面に棚やウィンドウが少しのあいだ出る。
//
// 使い方: ReadmeImages <書き出すフォルダ>
//   - hero.png: 全体の見本（画面の端の棚・帯・浮いた棚・メニューバーのアイコン）
//   - edge.gif: ファイルをドラッグし始める → 画面の端に帯が出る → 近づくと開く → 落とす → 離れると帯にたたむ
//   - shake.gif: ファイルをドラッグしながら振る → カーソルの位置に棚が出る → 落とす
//   - drag-out.gif: 棚の中身をほかのウィンドウへドラッグする → 移したものは棚から外れる
//   - favorites.gif: 見出しの ☆ を押してお気に入りにする → ✕ で閉じる → お気に入り一覧から出し直す
import AppKit
import PinshelfCore
import SwiftUI
import UniformTypeIdentifiers

let outputFolder = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images")

/// 描くときの倍率（PNG はこのまま書き出し、GIF は軽くするため 1 倍に縮めて書き出す）
let renderScale: CGFloat = 2

/// README の見本の大きさ（Pinstage と同じ。README には幅 800 で載せる）
enum ReadmeLayout {
    /// どの画像も、この大きさ（pt）の架空の画面に描く（hero.png は 2 倍の画素、GIF は 1 倍の画素で書き出す）
    static let size = CGSize(width: 980, height: 700)
    /// メニューバーの下の、上下の真ん中
    static var middleY: CGFloat { (size.height - Canvas.menuBarHeight) / 2 }
}

/// 画像を作れなかったわけ
enum ReadmeImagesError: Error, CustomStringConvertible {
    case captureFailed
    case itemNotFound(String)
    case writeFailed(String)

    var description: String {
        switch self {
        case .captureFailed: "Could not capture the window contents"
        case .itemNotFound(let name): "Could not find \(name) on the shelf"
        case .writeFailed(let name): "Could not write \(name)"
        }
    }
}

// MARK: - 見本のファイル

let sampleFolder = FileManager.default.temporaryDirectory.appending(path: "Pinshelf-README-Samples", directoryHint: .isDirectory)

/// 見本のファイル（架空の名前の、空のファイル。アイコンは拡張子で決まる。初めて使うときに作る）
enum Sample {
    static var proposal: URL { file("企画書.pdf") }
    static var estimate: URL { file("見積もり.xlsx") }
    static var logo: URL { file("ロゴ.png") }
    static var minutes: URL { file("議事録.docx") }
    static var photo: URL { file("旅行の写真.jpg") }
    static var memo: URL { file("打ち合わせメモ.txt") }
    static var invoice: URL { file("請求書.pdf") }
    static var slides: URL { file("資料.key") }
    static var archive: URL { file("素材.zip") }
    static var movie: URL { file("紹介動画.mp4") }

    private static func file(_ name: String) -> URL {
        let url = sampleFolder.appending(path: name)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        return url
    }
}

func fileIcon(_ url: URL) -> NSImage {
    NSWorkspace.shared.icon(forFile: url.path)
}

// MARK: - 画像の土台

/// sRGB の、透明を持てるビットマップ（width・height は画素）
func makeBitmapContext(width: Int, height: Int) -> CGContext? {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
}

// MARK: - 写す

/// 写した棚（画像は renderScale 倍。frame は写したときのウィンドウの枠）
struct ShelfShot {
    /// 見出しのボタン
    enum HeaderButton {
        case close
        case favorite

        /// 棚の左上からの、ボタンの真ん中のずれ（見出しの左のボタンの並びは、棚の幅で変わらない）
        var offset: CGPoint {
            switch self {
            case .close: CGPoint(x: 19, y: 19)
            case .favorite: CGPoint(x: 63, y: 19)
            }
        }
    }

    let image: CGImage
    let frame: CGRect
    /// 中身のファイルのアイコンの真ん中（ファイル名ごと。棚の左上からのずれ）
    let iconCenters: [String: CGPoint]

    /// origin に置いたときの、ファイルのアイコンの真ん中（キャンバスの座標）
    func iconCenter(of file: URL, placedAt origin: CGPoint) throws -> CGPoint {
        guard let center = iconCenters[file.lastPathComponent] else { throw ReadmeImagesError.itemNotFound(file.lastPathComponent) }
        return point(at: center, placedAt: origin)
    }

    /// origin に置いたときの、見出しのボタンの真ん中（キャンバスの座標）
    func center(of button: HeaderButton, placedAt origin: CGPoint) -> CGPoint {
        point(at: button.offset, placedAt: origin)
    }

    /// 棚の左上からのずれを、キャンバスの座標（原点は左下）にする
    private func point(at offset: CGPoint, placedAt origin: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + offset.x, y: origin.y + frame.height - offset.y)
    }
}

/// 棚のウィンドウの中身を、レイヤーごと描き写す（ウィンドウの影は写らないので、並べるときに描く）
func capture(_ shelf: ShelfController) throws -> ShelfShot {
    guard let view = shelf.panel.contentView else { throw ReadmeImagesError.captureFailed }
    // アイコンの真ん中は、棚から取り出すときと同じく、並べた枠から求める
    var iconCenters: [String: CGPoint] = [:]
    for item in shelf.model.items {
        guard case .file(let url) = item.content, let tile = shelf.model.tileFrames[item.id] else { continue }
        iconCenters[url.lastPathComponent] = CGPoint(x: tile.midX, y: tile.minY + 26)
    }
    return ShelfShot(image: try capture(view), frame: shelf.panel.frame, iconCenters: iconCenters)
}

/// ビューを、レイヤーごと描き写す（renderScale 倍の画素）
func capture(_ view: NSView) throws -> CGImage {
    let size = view.bounds.size
    guard let layer = view.layer, size.width > 0, size.height > 0,
          let context = makeBitmapContext(width: Int(size.width * renderScale), height: Int(size.height * renderScale))
    else { throw ReadmeImagesError.captureFailed }
    context.scaleBy(x: renderScale, y: renderScale)
    if view.isFlipped {
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
    }
    layer.render(in: context)
    guard let image = context.makeImage() else { throw ReadmeImagesError.captureFailed }
    return image
}

/// 動いている間、interval ごとに写す
func record(_ shelf: ShelfController, for duration: Duration, every interval: Duration = .milliseconds(20)) async -> [ShelfShot] {
    var shots: [ShelfShot] = []
    let clock = ContinuousClock()
    let end = clock.now + duration
    while clock.now < end {
        if let shot = try? capture(shelf) { shots.append(shot) }
        try? await Task.sleep(for: interval)
    }
    return shots
}

// MARK: - 動き

/// a から b へ、t（0〜1）の割合だけ進んだ点
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

/// ゆっくり動き出して、ゆっくり止まる進み具合（カーソルを人が動かしたように見せる）
func smooth(_ t: CGFloat) -> CGFloat {
    t * t * (3 - 2 * t)
}

/// steps コマで a から b へ動かす、各コマの点（最後のコマで b に着く）
func path(from a: CGPoint, to b: CGPoint, steps: Int) -> [CGPoint] {
    (1...steps).map { lerp(a, b, smooth(CGFloat($0) / CGFloat(steps))) }
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

/// 浮いた棚の出入りの動き（アプリと同じ長さ・同じ速さの変わり方で、各コマの出ている具合（0〜1）を求める）
enum FloatingShelfMotion {
    /// 1 コマの長さ（秒）
    static let frameDelay = 0.03

    /// 出てくる間の、各コマの出ている具合
    static func appearing() -> [CGFloat] {
        let count = frameCount(for: ShelfMotion.duration)
        return (1...count).map { CGFloat(progress(ShelfMotion.timingFunction, at: Double($0) / Double(count))) }
    }

    /// 消えていく間の、各コマの出ている具合（アプリと同じく、出るときより少し短く、だんだん速く消える）
    static func disappearing() -> [CGFloat] {
        let count = frameCount(for: ShelfMotion.duration * 0.8)
        let easeIn = CAMediaTimingFunction(name: .easeIn)
        return (1...count).map { 1 - CGFloat(progress(easeIn, at: Double($0) / Double(count))) }
    }

    private static func frameCount(for duration: TimeInterval) -> Int {
        max(1, Int((duration / frameDelay).rounded()))
    }
}

// MARK: - 描く

/// 点（pt）で描くキャンバス（renderScale 倍の画素で書き出す。原点は左下）
final class Canvas {
    /// メニューバーの高さ
    static let menuBarHeight: CGFloat = 24
    /// ウィンドウの上のバーの高さ
    static let titleBarHeight: CGFloat = 32
    /// ウィンドウの角の丸み
    static let windowCornerRadius: CGFloat = 12

    let size: CGSize
    let context: CGContext

    init(size: CGSize) {
        self.size = size
        context = makeBitmapContext(width: Int(size.width * renderScale), height: Int(size.height * renderScale))!
        context.scaleBy(x: renderScale, y: renderScale)
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

    /// デスクトップの背景（gradient が true なら、左上から右下へ色が変わる）
    func wallpaper(gradient: Bool) {
        if gradient {
            let colors = [color(0xC9DCF6), color(0xE4D9F3)] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors, locations: nil)!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])
        } else {
            context.setFillColor(color(0xDCE5F2))
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 上のメニューバー（右に Pinshelf のアイコンと時計）
    func menuBar(height: CGFloat = menuBarHeight) {
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

    /// 架空のウィンドウの枠（影・白い地・3 つの丸と題の入った上のバー）を描き、中身を描く場所を返す
    @discardableResult
    func window(_ rect: CGRect, title: String) -> CGRect {
        let barHeight = Self.titleBarHeight
        let path = Self.windowPath(rect)
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
        context.addPath(Self.windowPath(rect))
        context.clip()
        context.draw(content, in: contentRect)
        context.restoreGState()
    }

    private static func windowPath(_ rect: CGRect) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: windowCornerRadius, cornerHeight: windowCornerRadius, transform: nil)
    }

    /// ファイルの並んだ、架空のウィンドウ（Finder のような見た目の絵）
    func fileWindow(_ rect: CGRect, title: String, files: [URL]) {
        window(rect, title: title)
        withAppKit {
            for (index, url) in files.enumerated() {
                let cell = Self.fileCell(in: rect, index: index)
                fileIcon(url).draw(in: CGRect(x: cell.midX - 26, y: cell.minY + 30, width: 52, height: 52))
                let name = NSAttributedString(string: url.lastPathComponent, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black])
                name.draw(at: CGPoint(x: cell.midX - name.size().width / 2, y: cell.minY + 10))
            }
        }
    }

    /// ファイルのウィンドウで、index 番目のファイルの真ん中（アイコンの上。カーソルを置くため）
    static func fileCenter(in rect: CGRect, index: Int) -> CGPoint {
        let cell = fileCell(in: rect, index: index)
        return CGPoint(x: cell.midX, y: cell.minY + 56)
    }

    /// ファイルのウィンドウで、index 番目のファイルを描く場所（3 列に並べる）
    private static func fileCell(in rect: CGRect, index: Int) -> CGRect {
        let columns = 3
        let size = CGSize(width: (rect.width - 24) / CGFloat(columns), height: 92)
        let column = index % columns
        let row = index / columns
        return CGRect(
            x: rect.minX + 12 + CGFloat(column) * size.width, y: rect.maxY - titleBarHeight - 14 - CGFloat(row + 1) * size.height,
            width: size.width, height: size.height
        )
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

    /// 浮いた棚を、出てくる・消えていく途中の姿で置く（presence: 0 で消えている、1 で出ている。アプリと同じく、少し小さい状態から広がる）
    func floatingShelf(_ shot: ShelfShot, at origin: CGPoint, presence: CGFloat) {
        shelf(shot, at: origin, alpha: presence, scale: ShelfMotion.appearScale + (1 - ShelfMotion.appearScale) * presence)
    }

    /// クリックの印（カーソルの先の、薄い丸）
    func click(at point: CGPoint) {
        let rect = CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)
        context.setFillColor(color(0x000000, 0.12))
        context.fillEllipse(in: rect)
        context.setStrokeColor(color(0x000000, 0.28))
        context.setLineWidth(1.2)
        context.strokeEllipse(in: rect)
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

/// GIF のコマを、1 コマずつ描いて足す（毎回、架空のデスクトップ・メニューバー・カーソルを描く）
final class GIFScene {
    let size = ReadmeLayout.size
    private(set) var frames: [GIFFrame] = []

    /// 1 コマを描いて足す
    /// - dragging: カーソルに付けて描く、ドラッグしているファイル
    /// - clicking: カーソルの先にクリックの印を描く
    /// - draw: デスクトップの上に描くもの（ウィンドウ・棚）
    func addFrame(cursor: CGPoint, dragging: URL? = nil, clicking: Bool = false, delay: Double, draw: (Canvas) -> Void) {
        let canvas = Canvas(size: size)
        canvas.wallpaper(gradient: false)
        draw(canvas)
        canvas.menuBar()
        if let dragging { canvas.draggedFile(dragging, at: cursor) }
        if clicking { canvas.click(at: cursor) }
        canvas.cursor(at: cursor)
        frames.append((downscale(canvas.image(), by: Int(renderScale)), delay))
    }
}

/// ファイルをドラッグし始める「書類」のウィンドウ（edge.gif・shake.gif）
enum DocumentsWindow {
    static let rect = CGRect(x: 70, y: ReadmeLayout.middleY - 200, width: 380, height: 400)
    static var files: [URL] {
        [Sample.proposal, Sample.estimate, Sample.logo, Sample.minutes, Sample.photo, Sample.memo, Sample.invoice, Sample.archive, Sample.movie]
    }
    /// ドラッグするファイル
    static var dragged: URL { Sample.proposal }
    /// ドラッグし始める位置（ドラッグするファイルの上）
    static var start: CGPoint { Canvas.fileCenter(in: rect, index: 0) }

    static func draw(on canvas: Canvas) {
        canvas.fileWindow(rect, title: "書類", files: files)
    }
}

// MARK: - 書き出す

typealias GIFFrame = (image: CGImage, delay: Double)

/// 画像を縦横 1/factor にする（2 倍で描いたものを、軽い 1 倍にする）
func downscale(_ image: CGImage, by factor: Int) -> CGImage {
    let width = image.width / factor
    let height = image.height / factor
    let context = makeBitmapContext(width: width, height: height)!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

func writePNG(_ image: CGImage, named name: String) throws {
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw ReadmeImagesError.writeFailed(name)
    }
    try data.write(to: outputFolder.appending(path: name))
    print("書き出しました: \(name)")
}

func writeGIF(_ frames: [GIFFrame], named name: String) throws {
    let url = outputFolder.appending(path: name)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
        throw ReadmeImagesError.writeFailed(name)
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
    guard CGImageDestinationFinalize(destination) else { throw ReadmeImagesError.writeFailed(name) }
    print("書き出しました: \(name)（\(frames.count) コマ）")
}

// MARK: - 見本を作る

@MainActor
final class ReadmeImages {
    /// 棚を出して写す画面。Retina（2 倍）の画面にする（1 倍の画面に出すと、文字が 1 倍で描かれて、2 倍の画像ではぼやけるため）
    let screen = NSScreen.screens.first { $0.backingScaleFactor >= renderScale } ?? NSScreen.main!
    let coordinator = AppCoordinator()

    /// 新しい棚を作る（items を 1 つずつ入れ、name・color・favorite を付ける。size を渡すと、その大きさの浮いた棚にする）
    func makeShelf(
        at point: CGPoint, items: [URL], size: CGSize? = nil, name: String? = nil, color: ShelfColor = .none, favorite: Bool = false
    ) -> ShelfController {
        let shelf = size.map { size in
            let frame = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
            return ShelfController(id: UUID(), frame: awayFromPointer(frame), model: ShelfModel())
        } ?? ShelfController(centeredAt: point)
        // 本物のマウスが重なっても、帯の開け閉めが起きないようにする
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
        // 本物のマウスが右端の近くにあれば、上下のうち、マウスのない側にしまう
        let visible = screen.visibleFrame
        let pointer = NSEvent.mouseLocation
        let y = pointer.x > visible.maxX - 400 ? (pointer.y > visible.midY ? visible.minY + 260 : visible.maxY - 260) : centerY
        shelf.show()
        shelf.dock(to: .right, on: screen, centerY: y, unfolded: false, animated: false)
        if unfolded { shelf.unfold(byDrag: true) }
    }

    /// 本物のマウスと重ならない枠にする。重なるときは、画面の左右のうち、マウスのない側へ動かす
    /// （重なると、中身にポインタを乗せたときの強調が写る。ignoresMouseEvents にしても、この強調は出るため）
    func awayFromPointer(_ frame: CGRect) -> CGRect {
        let pointer = NSEvent.mouseLocation
        guard frame.insetBy(dx: -40, dy: -40).contains(pointer) else { return frame }
        let visible = screen.visibleFrame
        var moved = frame
        moved.origin.x = pointer.x > visible.midX ? visible.minX + 60 : visible.midX + 60
        return moved
    }

    /// 出す・動かすアニメーションが終わるのを待つ
    func settle() async {
        try? await Task.sleep(for: .milliseconds(700))
    }

    func run() async throws {
        try FileManager.default.createDirectory(at: sampleFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        try await makeHero()
        try await makeEdgeGIF()
        try await makeShakeGIF()
        try await makeDragOutGIF()
        try await makeFavoritesGIF()
        for shelf in coordinator.shelves { shelf.discard() }
        try? FileManager.default.removeItem(at: sampleFolder)
    }

    // MARK: hero.png

    func makeHero() async throws {
        let visible = screen.visibleFrame
        let edge = makeShelf(at: CGPoint(x: visible.maxX - 200, y: visible.midY), items: [Sample.proposal, Sample.estimate, Sample.logo])
        // 中身が 2 列に並ぶ幅にする
        edge.state.dockedSize = CGSize(width: 200, height: 380)
        dockRight(edge, centerY: visible.midY + 100, unfolded: true)
        let folded = makeShelf(
            at: CGPoint(x: visible.maxX - 200, y: visible.midY),
            items: [Sample.minutes, Sample.photo, Sample.memo, Sample.invoice, Sample.slides], color: .blue
        )
        dockRight(folded, centerY: visible.midY - 220, unfolded: false)
        let floating = makeShelf(
            at: CGPoint(x: visible.midX, y: visible.midY), items: [Sample.photo, Sample.memo], size: CGSize(width: 280, height: 260),
            name: "あとで送る", color: .orange, favorite: true
        )
        floating.show()
        await settle()

        let edgeShot = try capture(edge)
        let foldedShot = try capture(folded)
        let floatingShot = try capture(floating)
        for shelf in [edge, folded, floating] { shelf.discard() }

        // 左に書類のウィンドウ、真ん中に浮いた棚、右端に開いた棚と、たたんだ帯
        let canvas = Canvas(size: ReadmeLayout.size)
        let middle = ReadmeLayout.middleY
        canvas.wallpaper(gradient: true)
        canvas.fileWindow(DocumentsWindow.rect.offsetBy(dx: -10, dy: 0), title: "書類", files: DocumentsWindow.files)
        canvas.shelf(floatingShot, at: CGPoint(x: 470, y: middle - floatingShot.frame.height / 2 + 20))
        canvas.shelf(edgeShot, at: CGPoint(x: canvas.size.width - edgeShot.frame.width, y: middle - edgeShot.frame.height / 2 + 50))
        canvas.shelf(foldedShot, at: CGPoint(x: canvas.size.width - foldedShot.frame.width, y: 60))
        canvas.cursor(at: CGPoint(x: canvas.size.width - 50, y: middle + 40))
        canvas.menuBar()
        try writePNG(canvas.image(), named: "hero.png")
        await settle()
    }

    // MARK: edge.gif

    func makeEdgeGIF() async throws {
        let visible = screen.visibleFrame

        // 本物の棚で、帯 → 開く → 落とす → たたむ を写す
        let shelf = makeShelf(at: CGPoint(x: visible.maxX - 200, y: visible.midY), items: [])
        shelf.state.dockedSize = CGSize(width: 200, height: 380)
        dockRight(shelf, centerY: visible.midY, unfolded: false)
        await settle()
        let tab = try capture(shelf)
        shelf.unfold(byDrag: true)
        let unfolding = await record(shelf, for: .milliseconds(320))
        await settle()
        shelf.model.accept(contents: [.file(DocumentsWindow.dragged)])
        await settle()
        let filled = try capture(shelf)
        shelf.fold()
        let folding = await record(shelf, for: .milliseconds(320))
        await settle()
        let filledTab = try capture(shelf)
        shelf.discard()

        // 架空のデスクトップの右端に、棚を置く
        let scene = GIFScene()
        let shelfCenterY = ReadmeLayout.middleY
        /// 1 コマを描く（slide: 帯が画面の外から滑り込む進み具合（0〜1））
        func frame(cursor: CGPoint, shot: ShelfShot?, slide: CGFloat = 1, dragging: Bool, delay: Double) {
            scene.addFrame(cursor: cursor, dragging: dragging ? DocumentsWindow.dragged : nil, delay: delay) { canvas in
                DocumentsWindow.draw(on: canvas)
                guard let shot else { return }
                let origin = CGPoint(
                    x: scene.size.width - shot.frame.width + ShelfMotion.slideDistance * (1 - slide), y: shelfCenterY - shot.frame.height / 2
                )
                canvas.shelf(shot, at: origin, alpha: slide)
            }
        }

        // 1. ファイルの上にカーソル
        let start = DocumentsWindow.start
        frame(cursor: start, shot: nil, dragging: false, delay: 0.8)
        // 2. ドラッグし始めると、画面の端に帯が滑り込む
        let approach = CGPoint(x: scene.size.width - 260, y: shelfCenterY + 10)
        for step in 1...12 {
            frame(cursor: lerp(start, approach, CGFloat(step) / 12), shot: tab, slide: min(1, CGFloat(step) / 5), dragging: true, delay: 0.05)
        }
        // 3. 帯に近づくと、棚が開く
        let inside = CGPoint(x: scene.size.width - 100, y: shelfCenterY + 6)
        let unfoldFrames = Array(unfolding.prefix(12))
        for (index, shot) in unfoldFrames.enumerated() {
            frame(cursor: lerp(approach, inside, CGFloat(index + 1) / CGFloat(unfoldFrames.count)), shot: shot, dragging: true, delay: 0.04)
        }
        frame(cursor: inside, shot: unfoldFrames.last, dragging: true, delay: 0.5)
        // 4. 落とすと、棚に入る（元のファイルは動かない）
        frame(cursor: inside, shot: filled, dragging: false, delay: 1.0)
        // 5. 離れると、帯にたたむ（件数が出る）
        let away = CGPoint(x: scene.size.width - 360, y: shelfCenterY - 40)
        for (index, shot) in folding.prefix(14).enumerated() {
            frame(cursor: lerp(inside, away, min(1, CGFloat(index + 1) / 6)), shot: shot, dragging: false, delay: 0.04)
        }
        frame(cursor: away, shot: filledTab, dragging: false, delay: 1.6)

        try writeGIF(scene.frames, named: "edge.gif")
    }

    // MARK: shake.gif

    func makeShakeGIF() async throws {
        let visible = screen.visibleFrame

        // 本物の棚で、空の棚と、落としたあとの棚を写す
        let shelf = makeShelf(at: CGPoint(x: visible.midX, y: visible.midY), items: [], size: CGSize(width: 280, height: 260))
        shelf.show()
        await settle()
        let empty = try capture(shelf)
        shelf.model.accept(contents: [.file(DocumentsWindow.dragged)])
        await settle()
        let filled = try capture(shelf)
        shelf.discard()
        await settle()

        // 振る場所（棚は、ここを真ん中にして出る）
        let scene = GIFScene()
        let shakeCenter = CGPoint(x: scene.size.width - 270, y: ReadmeLayout.middleY)
        /// 1 コマを描く（appear: 棚が出てくる動きの進み具合（0〜1））
        func frame(cursor: CGPoint, shot: ShelfShot?, appear: CGFloat = 1, dragging: Bool, delay: Double) {
            scene.addFrame(cursor: cursor, dragging: dragging ? DocumentsWindow.dragged : nil, delay: delay) { canvas in
                DocumentsWindow.draw(on: canvas)
                guard let shot else { return }
                let origin = CGPoint(x: shakeCenter.x - shot.frame.width / 2, y: shakeCenter.y - shot.frame.height / 2)
                canvas.floatingShelf(shot, at: origin, presence: appear)
            }
        }

        // 1. ファイルの上にカーソル
        let start = DocumentsWindow.start
        frame(cursor: start, shot: nil, dragging: false, delay: 0.8)
        // 2. ドラッグして、何もないところへ運ぶ
        for step in 1...10 {
            frame(cursor: lerp(start, shakeCenter, CGFloat(step) / 10), shot: nil, dragging: true, delay: 0.05)
        }
        // 3. 左右に軽く振る（折り返しの間を 2 コマで動かす）
        let swings: [CGFloat] = [0, 40, -40, 40, -40, 30, 0]
        for (from, to) in zip(swings, swings.dropFirst()) {
            for step in 1...2 {
                let x = from + (to - from) * CGFloat(step) / 2
                frame(cursor: CGPoint(x: shakeCenter.x + x, y: shakeCenter.y), shot: nil, dragging: true, delay: 0.035)
            }
        }
        // 4. カーソルの位置に棚が出る（アプリと同じ長さ・同じ速さの変わり方）
        for presence in FloatingShelfMotion.appearing() {
            frame(cursor: shakeCenter, shot: empty, appear: presence, dragging: true, delay: FloatingShelfMotion.frameDelay)
        }
        frame(cursor: shakeCenter, shot: empty, dragging: true, delay: 0.6)
        // 5. 落とすと、棚に入る（元のファイルは動かない）
        frame(cursor: shakeCenter, shot: filled, dragging: false, delay: 0.9)
        // 6. カーソルを離す
        let away = CGPoint(x: shakeCenter.x - 60, y: ReadmeLayout.middleY - 200)
        for step in 1...6 {
            frame(cursor: lerp(shakeCenter, away, CGFloat(step) / 6), shot: filled, dragging: false, delay: 0.04)
        }
        frame(cursor: away, shot: filled, dragging: false, delay: 1.5)

        try writeGIF(scene.frames, named: "shake.gif")
    }

    // MARK: drag-out.gif

    func makeDragOutGIF() async throws {
        let visible = screen.visibleFrame
        let dragged = Sample.proposal

        // 本物の棚で、取り出す前と、取り出して外れたあとを写す
        let shelf = makeShelf(at: CGPoint(x: visible.midX, y: visible.midY), items: [dragged, Sample.estimate], size: CGSize(width: 300, height: 300))
        shelf.show()
        await settle()
        let full = try capture(shelf)
        // 同じディスクの Finder に落とすと移動になり、元の場所からなくなるので、棚から外れる
        let moved = shelf.model.items.filter { $0.content == .file(dragged) }.map(\.id)
        guard !moved.isEmpty else { throw ReadmeImagesError.itemNotFound(dragged.lastPathComponent) }
        shelf.model.removeItems(withIDs: Set(moved))
        await settle()
        let taken = try capture(shelf)
        shelf.discard()
        await settle()

        // 左に棚、右に落とす先のフォルダのウィンドウを置く
        let scene = GIFScene()
        let shelfOrigin = CGPoint(x: 100, y: ReadmeLayout.middleY - full.frame.height / 2)
        let folder = CGRect(x: 510, y: ReadmeLayout.middleY - 200, width: 380, height: 400)
        /// 1 コマを描く（dropped: フォルダに移ったあとか）
        func frame(cursor: CGPoint, dropped: Bool, dragging: Bool, delay: Double) {
            scene.addFrame(cursor: cursor, dragging: dragging ? dragged : nil, delay: delay) { canvas in
                canvas.fileWindow(folder, title: "提出用", files: dropped ? [dragged] : [])
                canvas.shelf(dropped ? taken : full, at: shelfOrigin)
            }
        }

        // 1. 棚の中身の上にカーソル
        let start = try full.iconCenter(of: dragged, placedAt: shelfOrigin)
        frame(cursor: start, dropped: false, dragging: false, delay: 0.8)
        // 2. ほかのウィンドウへドラッグする
        let drop = Canvas.fileCenter(in: folder, index: 0)
        for point in path(from: start, to: drop, steps: 14) {
            frame(cursor: point, dropped: false, dragging: true, delay: 0.045)
        }
        frame(cursor: drop, dropped: false, dragging: true, delay: 0.3)
        // 3. 落とすと、フォルダに移り、棚から外れる
        frame(cursor: drop, dropped: true, dragging: false, delay: 0.6)
        // 4. カーソルを離す
        let away = CGPoint(x: drop.x + 40, y: ReadmeLayout.middleY - 240)
        for point in path(from: drop, to: away, steps: 6) {
            frame(cursor: point, dropped: true, dragging: false, delay: 0.04)
        }
        frame(cursor: away, dropped: true, dragging: false, delay: 1.6)

        try writeGIF(scene.frames, named: "drag-out.gif")
    }

    // MARK: favorites.gif

    /// favorites.gif に使う、棚と一覧の写し
    struct FavoritesShots {
        /// まだお気に入りではない棚（☆）
        let plain: ShelfShot
        /// お気に入りにした棚（★）
        let favorite: ShelfShot
        /// お気に入りにする前の一覧
        let listBefore: CGImage
        /// 棚を出しているときの一覧（「前に出す」）
        let listShown: CGImage
        /// 棚を閉じているときの一覧（「出す」）
        let listHidden: CGImage
        /// 一覧の中身の大きさ
        let listSize: CGSize
        /// 一覧で、この棚（あとで送る）が何行目か（0 から）
        let shelfRow: Int
    }

    /// 本物の棚とお気に入り一覧を出して、お気に入りにする前・したあと・閉じたあとを写す
    func captureFavoritesShots() async throws -> FavoritesShots {
        let visible = screen.visibleFrame
        let shelf = makeShelf(
            at: CGPoint(x: visible.midX - 220, y: visible.midY), items: [Sample.photo, Sample.memo],
            size: CGSize(width: 290, height: 300), name: "あとで送る", color: .orange
        )
        shelf.show()
        let list = FavoriteShelvesList()
        let listWindow = makeFavoritesWindow(list: list, centeredAt: CGPoint(x: visible.midX + 190, y: visible.midY))
        defer {
            listWindow.orderOut(nil)
            shelf.discard()
        }
        guard let listView = listWindow.contentView else { throw ReadmeImagesError.captureFailed }
        /// 一覧に entries を並べて写す
        func captureList(_ entries: [FavoriteShelfEntry]) async throws -> CGImage {
            list.load = { entries }
            list.reload()
            await settle()
            return try capture(listView)
        }
        // ほかのお気に入りの棚（閉じている）と、この棚
        let others = [
            FavoriteShelfEntry(id: UUID(), title: "デザイン素材", color: .purple, count: 8, isVisible: false),
            FavoriteShelfEntry(id: UUID(), title: "請求書の控え", color: .green, count: 3, isVisible: false),
            FavoriteShelfEntry(id: UUID(), title: "旅行の写真", color: .blue, count: 12, isVisible: false),
            FavoriteShelfEntry(id: UUID(), title: "週次レポート", color: .gray, count: 4, isVisible: false),
        ]
        func entry(isVisible: Bool) -> FavoriteShelfEntry {
            FavoriteShelfEntry(id: shelf.id, title: "あとで送る", color: .orange, count: 2, isVisible: isVisible)
        }

        await settle()
        let plain = try capture(shelf)
        let listBefore = try await captureList(others)
        shelf.setFavorite(true)
        await settle()
        return FavoritesShots(
            plain: plain,
            favorite: try capture(shelf),
            listBefore: listBefore,
            listShown: try await captureList(others + [entry(isVisible: true)]),
            listHidden: try await captureList(others + [entry(isVisible: false)]),
            listSize: listView.bounds.size,
            shelfRow: others.count
        )
    }

    func makeFavoritesGIF() async throws {
        let shots = try await captureFavoritesShots()
        await settle()

        // メニューバーの下の真ん中に、棚と一覧の高さをそろえて並べる
        let scene = GIFScene()
        let middle = ReadmeLayout.middleY
        let shelfOrigin = CGPoint(x: 90, y: middle - shots.plain.frame.height / 2)
        let windowHeight = shots.listSize.height + Canvas.titleBarHeight
        let windowRect = CGRect(
            x: scene.size.width - 90 - shots.listSize.width, y: middle - windowHeight / 2, width: shots.listSize.width, height: windowHeight
        )
        /// 1 コマを描く（shot: 棚、presence: 棚の出ている具合（0〜1）、list: 一覧の中身）
        func frame(cursor: CGPoint, shot: ShelfShot?, presence: CGFloat = 1, list: CGImage, clicking: Bool = false, delay: Double) {
            scene.addFrame(cursor: cursor, clicking: clicking, delay: delay) { canvas in
                if let shot { canvas.floatingShelf(shot, at: shelfOrigin, presence: presence) }
                canvas.window(windowRect, title: "お気に入り一覧", content: list)
            }
        }

        let rest = CGPoint(x: shelfOrigin.x + 180, y: shelfOrigin.y + 60)
        let star = shots.plain.center(of: .favorite, placedAt: shelfOrigin)
        let close = shots.plain.center(of: .close, placedAt: shelfOrigin)
        // 一覧の「あとで送る」の行の「出す」ボタン（一覧の行は、上の余白 31pt から 42pt おきに並ぶ）
        let showButton = CGPoint(x: windowRect.maxX - 36, y: windowRect.maxY - Canvas.titleBarHeight - 31 - 42 * CGFloat(shots.shelfRow))

        // 1. まだお気に入りではない棚（☆）と、お気に入り一覧
        frame(cursor: rest, shot: shots.plain, list: shots.listBefore, delay: 0.8)
        // 2. 見出しの ☆ を押すと ★ になり、一覧に入る。押したら、★ が見えるようにカーソルを少しずらす
        for point in path(from: rest, to: star, steps: 9) {
            frame(cursor: point, shot: shots.plain, list: shots.listBefore, delay: 0.04)
        }
        frame(cursor: star, shot: shots.plain, list: shots.listBefore, clicking: true, delay: 0.15)
        let starAside = CGPoint(x: star.x + 12, y: star.y - 24)
        for point in path(from: star, to: starAside, steps: 4) {
            frame(cursor: point, shot: shots.favorite, list: shots.listShown, delay: 0.04)
        }
        frame(cursor: starAside, shot: shots.favorite, list: shots.listShown, delay: 1.0)
        // 3. ✕ で閉じても、お気に入りの棚は一覧に残る（閉じている）
        for point in path(from: starAside, to: close, steps: 6) {
            frame(cursor: point, shot: shots.favorite, list: shots.listShown, delay: 0.04)
        }
        frame(cursor: close, shot: shots.favorite, list: shots.listShown, clicking: true, delay: 0.15)
        for presence in FloatingShelfMotion.disappearing() {
            frame(cursor: close, shot: shots.favorite, presence: presence, list: shots.listHidden, delay: FloatingShelfMotion.frameDelay)
        }
        frame(cursor: close, shot: nil, list: shots.listHidden, delay: 0.9)
        // 4. 一覧の「出す」で、閉じたときの場所に出し直す。「前に出す」に変わったのが見えるように、カーソルを少しずらす
        for point in path(from: close, to: showButton, steps: 14) {
            frame(cursor: point, shot: nil, list: shots.listHidden, delay: 0.04)
        }
        frame(cursor: showButton, shot: nil, list: shots.listHidden, clicking: true, delay: 0.15)
        for presence in FloatingShelfMotion.appearing() {
            frame(cursor: showButton, shot: shots.favorite, presence: presence, list: shots.listShown, delay: FloatingShelfMotion.frameDelay)
        }
        let buttonAside = CGPoint(x: showButton.x + 6, y: showButton.y - 34)
        for point in path(from: showButton, to: buttonAside, steps: 4) {
            frame(cursor: point, shot: shots.favorite, list: shots.listShown, delay: 0.04)
        }
        frame(cursor: buttonAside, shot: shots.favorite, list: shots.listShown, delay: 1.8)

        try writeGIF(scene.frames, named: "favorites.gif")
    }

    /// お気に入り一覧のウィンドウを出す（アプリの FavoritesWindowController と同じ作り）
    func makeFavoritesWindow(list: FavoriteShelvesList, centeredAt center: CGPoint) -> NSWindow {
        let controller = NSHostingController(rootView: FavoritesListView(list: list))
        controller.sizingOptions = []
        let window = NSWindow(contentViewController: controller)
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "お気に入り一覧"
        // 5 行が入り、下の説明が切れない高さ（棚と同じくらいの高さにそろえる）
        let size = NSSize(width: 400, height: 320)
        window.setContentSize(size)
        window.setFrameOrigin(CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        window.setFrame(awayFromPointer(window.frame), display: false)
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        return window
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
