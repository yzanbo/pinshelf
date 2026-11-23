import AppKit
import PinshelfCore
import SwiftUI

extension ShelfColor {
    /// 表示名
    var title: String {
        switch self {
        case .none: "なし"
        case .red: "赤"
        case .orange: "オレンジ"
        case .yellow: "黄"
        case .green: "緑"
        case .blue: "青"
        case .purple: "紫"
        case .gray: "グレー"
        }
    }

    /// AppKit の色（「なし」は nil）
    var nsColor: NSColor? {
        switch self {
        case .none: nil
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .gray: .systemGray
        }
    }

    /// SwiftUI の色（「なし」は nil）
    var color: Color? {
        nsColor.map(Color.init(nsColor:))
    }

    /// メニューに出す色の丸（「なし」は線だけの丸）
    var menuImage: NSImage {
        let symbol = self == .none ? "circle" : "circle.fill"
        let configuration = NSImage.SymbolConfiguration(paletteColors: [nsColor ?? .secondaryLabelColor])
        return NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
            .withSymbolConfiguration(configuration) ?? NSImage()
    }
}
