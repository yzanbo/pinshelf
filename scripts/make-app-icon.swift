// アプリのアイコンと、同じ絵を 1 色にした印を描いて、Assets.xcassets に書き出す。
// 使い方: make icon（プロジェクトのフォルダで。swift scripts/make-app-icon.swift でも動く）
//
// デザイン: トレーに入れたカード（ファイル）を、赤いピンで留める（Pin + Shelf）。
// 背景はオレンジのグラデーションの角丸の四角。作りは Pinshot のアイコンにそろえ（白いものを赤いピンで留める）、
// 色で見分けられるようにする（Pinshot は青）。
//
// 書き出すもの（アイコンを出すところは、すべてこのどちらかを使う）
// - AppIcon.appiconset: アプリのアイコン（色付き）。Finder・Dock・ログイン項目など
// - AppSymbol.imageset: アプリの印（1 色の PDF。テンプレート画像）。メニューバー・画面の端の帯・空の棚
import AppKit

let catalogDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Pinshelf/Assets.xcassets")
let outputDir = catalogDir.appendingPathComponent("AppIcon.appiconset")
let symbolDir = catalogDir.appendingPathComponent("AppSymbol.imageset")

// MARK: - 色

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
}

/// 影の色（背景のオレンジを濃くした色）
let shadowColor: UInt32 = 0x5C2405
/// カードの線と、トレーの札の色（背景のオレンジを薄くした色）
let lineColor: UInt32 = 0xF5C9A6
let labelColor: UInt32 = 0xF5A06B

// MARK: - 描く（1024 × 1024 の座標で描き、サイズに合わせて縮める。原点は左下）

func drawIcon(in ctx: CGContext) {
    // macOS のアイコンの決まり: 1024 の中に 824 の角丸の四角（まわりは影のための余白）
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // 本体の影
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(rgb(0xF28A3C))
    ctx.fillPath()
    ctx.restoreGState()

    // 背景のグラデーション（上が明るいオレンジ、下が濃いオレンジ）
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFFC15A), rgb(0xEE6E2B)]),
        start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: []
    )
    // 上半分に、ほんのり光
    ctx.drawLinearGradient(
        gradient([rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)]),
        start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.midY), options: []
    )
    ctx.restoreGState()

    // カードはトレーの中に立てるので、先に奥のカード・手前のカードを描き、最後にトレーを重ねる
    drawCard(in: ctx, center: CGPoint(x: 440, y: 536), size: CGSize(width: 278, height: 340), degrees: 12,
             colors: [rgb(0xFFF6EA), rgb(0xFFE8D0)], details: false)
    drawCard(in: ctx, center: CGPoint(x: 594, y: 556), size: CGSize(width: 288, height: 350), degrees: -8,
             colors: [rgb(0xFFFFFF), rgb(0xFFF3E8)], details: true)
    drawTray(in: ctx)
}

/// カード（ファイル）。center を中心に degrees だけ傾ける（正の向きは左へ傾く）。
/// details が true のカードには、文字の線と、留めるピンを付ける
func drawCard(in ctx: CGContext, center: CGPoint, size: CGSize, degrees: CGFloat, colors: [CGColor], details: Bool) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: degrees * .pi / 180)

    let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    let path = CGPath(roundedRect: rect, cornerWidth: 34, cornerHeight: 34, transform: nil)
    // 紙（影を付けて浮かせる）
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(shadowColor, 0.38))
    ctx.addPath(path)
    ctx.setFillColor(colors[0])
    ctx.fillPath()
    ctx.restoreGState()
    // 紙のほんのりした陰（下へ行くほど、少しオレンジがかる）
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient(colors),
        start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: []
    )
    ctx.restoreGState()

    if details {
        // 文字の線（左にそろえて 2 本）
        ctx.setFillColor(rgb(lineColor))
        for (top, width) in [(CGFloat(84), CGFloat(196)), (CGFloat(146), CGFloat(156))] {
            let line = CGRect(x: rect.minX + 46, y: rect.maxY - top - 26, width: width, height: 26)
            ctx.addPath(CGPath(roundedRect: line, cornerWidth: 13, cornerHeight: 13, transform: nil))
            ctx.fillPath()
        }
        // 留めるピン（上の辺の真ん中）
        drawPin(in: ctx, at: CGPoint(x: 0, y: rect.maxY - 10))
    }
    ctx.restoreGState()
}

/// トレー（上の縁と、下へすぼまる本体。前に札を付ける）
func drawTray(in ctx: CGContext) {
    // 本体（上が広く、下がすぼまる。下の角を丸める）
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 234, y: 452))
    body.addLine(to: CGPoint(x: 790, y: 452))
    body.addArc(tangent1End: CGPoint(x: 749, y: 244), tangent2End: CGPoint(x: 275, y: 244), radius: 44)
    body.addArc(tangent1End: CGPoint(x: 275, y: 244), tangent2End: CGPoint(x: 234, y: 452), radius: 44)
    body.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 30, color: rgb(shadowColor, 0.4))
    ctx.addPath(body)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0xFFFFFF), rgb(0xFFEAD6)]),
        start: CGPoint(x: 0, y: 452), end: CGPoint(x: 0, y: 244), options: []
    )
    ctx.restoreGState()

    // 上の縁（本体より少し広く、本体に小さく影を落とす）
    let rim = CGPath(roundedRect: CGRect(x: 212, y: 426, width: 600, height: 50), cornerWidth: 25, cornerHeight: 25, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: rgb(shadowColor, 0.28))
    ctx.addPath(rim)
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    // 前の札
    let label = CGRect(x: 388, y: 316, width: 248, height: 38)
    ctx.addPath(CGPath(roundedRect: label, cornerWidth: 19, cornerHeight: 19, transform: nil))
    ctx.setFillColor(rgb(labelColor))
    ctx.fillPath()
}

/// 赤いピン（Pinshot と同じ色。小さく縮めても点が残るよう、Pinshot より少し大きい）
func drawPin(in ctx: CGContext, at center: CGPoint) {
    let r: CGFloat = 48
    let head = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
    // 頭と、その影
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 5, height: -10), blur: 12, color: rgb(0x000000, 0.35))
    ctx.setFillColor(rgb(0xE5484D))
    ctx.fillEllipse(in: head)
    ctx.restoreGState()
    // 頭の立体感
    ctx.saveGState()
    ctx.addEllipse(in: head)
    ctx.clip()
    ctx.drawRadialGradient(
        gradient([rgb(0xFF7A7E), rgb(0xC9282E)]),
        startCenter: CGPoint(x: center.x - 16, y: center.y + 18), startRadius: 4,
        endCenter: center, endRadius: r + 6,
        options: [.drawsAfterEndLocation]
    )
    ctx.restoreGState()
    // 光の点
    ctx.setFillColor(rgb(0xFFFFFF, 0.75))
    ctx.fillEllipse(in: CGRect(x: center.x - 27, y: center.y + 7, width: 22, height: 17))
}

// MARK: - アプリの印（1 色。メニューバー・画面の端の帯・空の棚に出す）

/// アプリの印の形。アイコンと同じトレー・2 枚のカード・ピンを、1 色の形にしたもの。
/// 重なるところ（カードどうし・カードとトレー・カードとピン）は、すき間を空けて見分けられるようにする。
/// 座標は 100 × 100 くらい（原点は左下）。書き出すときに、枠いっぱいに収める
func symbolPath() -> CGPath {
    /// すき間の幅
    let gap: CGFloat = 5

    /// path を、まわりに gap だけ広げた形（重なるところを抜くのに使う）
    func clearance(_ path: CGPath) -> CGPath {
        path.union(path.copy(strokingWithWidth: gap * 2, lineCap: .round, lineJoin: .round, miterLimit: 1))
    }

    // トレー（上の縁と、下へすぼまる本体。前の札は抜いて見せる）
    let rim = CGPath(roundedRect: CGRect(x: 6, y: 38, width: 88, height: 10), cornerWidth: 5, cornerHeight: 5, transform: nil)
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 12, y: 42))
    body.addLine(to: CGPoint(x: 88, y: 42))
    body.addArc(tangent1End: CGPoint(x: 82, y: 8), tangent2End: CGPoint(x: 18, y: 8), radius: 6)
    body.addArc(tangent1End: CGPoint(x: 18, y: 8), tangent2End: CGPoint(x: 12, y: 42), radius: 6)
    body.closeSubpath()
    let trayShape = rim.union(body)
    let label = CGPath(roundedRect: CGRect(x: 36, y: 19, width: 28, height: 7), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
    let tray = trayShape.subtracting(label)

    // カード（アイコンと同じく、奥のカードは左へ、手前のカードは右へ傾ける）
    func card(center: CGPoint, size: CGSize, degrees: CGFloat) -> (path: CGPath, transform: CGAffineTransform) {
        let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: degrees * .pi / 180)
        var t = transform
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        let path = CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: &t)
        return (path, transform)
    }
    // トレーから大きく出す（1 色では、出ている分が少ないと、ただの箱に見えるため）
    let back = card(center: CGPoint(x: 37, y: 68), size: CGSize(width: 32, height: 48), degrees: 12)
    let frontSize = CGSize(width: 34, height: 50)
    let front = card(center: CGPoint(x: 61, y: 70), size: frontSize, degrees: -8)

    // ピン（手前のカードの内側に、まわりにすき間を空けて置く。上の辺からはみ出すと、人の頭に見えるため）
    let pinCenter = CGPoint(x: 0, y: frontSize.height / 2 - 10).applying(front.transform)
    let pinRect = CGRect(x: pinCenter.x - 5, y: pinCenter.y - 5, width: 10, height: 10)
    let pin = CGPath(ellipseIn: pinRect, transform: nil)
    let pinRing = CGPath(ellipseIn: pinRect.insetBy(dx: -gap * 0.8, dy: -gap * 0.8), transform: nil)

    let frontCard = front.path.subtracting(pinRing).union(pin)
    // 奥のカードは、手前のカードのまわりを抜く
    let backCard = back.path.subtracting(clearance(front.path))
    // カードの下の端は、トレーの中に入れる（トレーのまわりにすき間を空ける）
    let cards = backCard.union(frontCard).subtracting(clearance(trayShape))
    return cards.union(tray)
}

/// アプリの印を、size × size（ポイント）の PDF にする。まわりに margin の余白を残して、真ん中に収める
func symbolPDF(size: CGFloat, margin: CGFloat) -> Data {
    let path = symbolPath()
    let bounds = path.boundingBoxOfPath
    let scale = min((size - margin * 2) / bounds.width, (size - margin * 2) / bounds.height)
    var fit = CGAffineTransform(translationX: size / 2, y: size / 2)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -bounds.midX, y: -bounds.midY)
    let fitted = path.copy(using: &fit)!

    let data = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: size, height: size)
    let consumer = CGDataConsumer(data: data as CFMutableData)!
    let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
    pdf.beginPDFPage(nil)
    pdf.addPath(fitted)
    pdf.setFillColor(CGColor(gray: 0, alpha: 1))
    pdf.fillPath()
    pdf.endPDFPage()
    pdf.closePDF()
    return data as Data
}

// MARK: - 書き出す

func png(size: Int) -> Data? {
    guard let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    let scale = CGFloat(size) / 1024
    ctx.scaleBy(x: scale, y: scale)
    drawIcon(in: ctx)
    guard let image = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])
}

// macOS が求める大きさ（ポイント × 倍率）
let entries: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
var images: [[String: String]] = []
for entry in entries {
    let pixels = entry.points * entry.scale
    let name = "icon_\(entry.points)x\(entry.points)\(entry.scale == 2 ? "@2x" : "").png"
    guard let data = png(size: pixels) else { fatalError("描けませんでした: \(name)") }
    try data.write(to: outputDir.appendingPathComponent(name))
    images.append([
        "idiom": "mac",
        "size": "\(entry.points)x\(entry.points)",
        "scale": "\(entry.scale)x",
        "filename": name,
    ])
}

let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDir.appendingPathComponent("Contents.json"))

// アプリの印（メニューバーのアイコンと同じ 18 ポイント。ベクターのまま持つので、帯・空の棚では大きさを変えて使う）
try FileManager.default.createDirectory(at: symbolDir, withIntermediateDirectories: true)
try symbolPDF(size: 18, margin: 1).write(to: symbolDir.appendingPathComponent("AppSymbol.pdf"))
let symbolContents: [String: Any] = [
    "images": [["idiom": "universal", "filename": "AppSymbol.pdf"]],
    "info": ["version": 1, "author": "xcode"],
    // テンプレート画像にする（メニューバーの明るさ・押したとき・文字の色に合わせて、macOS が色を付ける）
    "properties": ["preserves-vector-representation": true, "template-rendering-intent": "template"],
]
let symbolJSON = try JSONSerialization.data(withJSONObject: symbolContents, options: [.prettyPrinted, .sortedKeys])
try symbolJSON.write(to: symbolDir.appendingPathComponent("Contents.json"))

// アセットカタログ自体の Contents.json
let catalogContents = try JSONSerialization.data(withJSONObject: ["info": ["version": 1, "author": "xcode"]], options: [.prettyPrinted, .sortedKeys])
try catalogContents.write(to: catalogDir.appendingPathComponent("Contents.json"))

print("書き出しました: \(outputDir.path)、\(symbolDir.path)")
