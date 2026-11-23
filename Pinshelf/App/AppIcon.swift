import AppKit
import SwiftUI

/// アプリのアイコン。アイコンを出すところは、すべてここから使う
///
/// 絵は scripts/make-app-icon.swift で描いて、make icon で Assets.xcassets に書き出す。
/// - 色付きのアイコン（AppIcon）: Finder・Dock・ログイン項目など
/// - 1 色の印（AppSymbol）: 同じ絵（トレー・2 枚のカード・ピン）を 1 色にしたもの。メニューバー・画面の端の帯・空の棚
enum AppIcon {
    /// 色付きのアイコン。アプリの中のアイコンのファイル（AppIcon.icns）を直接読む。
    /// macOS が覚えているアイコンは、アイコンを入れる前の仮のもののことがあるため（Pinshot と同じ）
    static let image: NSImage = Bundle.main.image(forResource: "AppIcon") ?? NSApp.applicationIconImage

    /// アプリのアイコン（Dock・確認の画面などに出るもの）を、作ったアイコンにする。
    ///
    /// メニューバーだけに常駐している間に設定しても、Dock に出たときには使われず、macOS が覚えているアイコン
    /// （アイコンを入れる前の仮のものなど）で出ることがある。そのため、起動したときと Dock に出すたびに呼ぶ。
    /// 同じものを設定し直しても反映されないことがあるので、毎回写しを渡す
    static func applyToApp() {
        NSApp.applicationIconImage = image.copy() as? NSImage ?? image
    }

    /// 1 色の印の、アセットカタログでの名前
    static let symbolName = "AppSymbol"

    /// 1 色の印（AppKit。メニューバー用）。テンプレート画像なので、メニューバーの明るさや押したときに合わせて、macOS が色を付ける
    static func symbol(accessibilityDescription: String) -> NSImage? {
        guard let image = NSImage(named: symbolName)?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }
}

/// 1 色の印（SwiftUI）。文字の色（foregroundStyle）で塗る
struct AppSymbolImage: View {
    /// 一辺の大きさ（ポイント）
    let size: CGFloat

    var body: some View {
        Image(AppIcon.symbolName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
