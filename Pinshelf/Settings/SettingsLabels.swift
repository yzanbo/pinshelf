import PinshelfCore
import SwiftUI

// MARK: - 設定の表示名

extension InboxDestination {
    var title: String {
        switch self {
        case .newShelf: "新しい棚を開く"
        case .edgeShelf: "画面の端の棚に入れる"
        }
    }

    var explanation: String {
        switch self {
        case .newShelf: "新しい棚を開いて、そこに入れます（アイコンに落としたときはアイコンのすぐ下に、ショートカットのときはカーソルの位置に開きます）。"
        case .edgeShelf: "画面の端の棚に入れ、入ったことが分かるよう、少しのあいだ開きます（画面の端に棚がなければ、新しく出します）。"
        }
    }
}

extension EdgePreference {
    var title: String {
        switch self {
        case .nearest: "カーソルに近いほう"
        case .left: "左端"
        case .right: "右端"
        }
    }
}

extension EdgeRevealTiming {
    var title: String {
        switch self {
        case .onDragStart: "ドラッグを始めたとき"
        case .onApproach: "画面の端に近づいたとき"
        }
    }
}

extension EdgeVerticalPosition {
    var title: String {
        switch self {
        case .top: "上"
        case .middle: "中央"
        case .bottom: "下"
        case .cursor: "カーソルの高さ"
        }
    }

    var explanation: String {
        switch self {
        case .top: "画面の端の上のほうに出します。"
        case .middle: "画面の端の真ん中に出します。"
        case .bottom: "画面の端の下のほうに出します。"
        case .cursor: "出したドラッグの間は、帯がカーソルの高さについてきて、画面の端に近づくとその高さで開きます（開いたあとは動きません）。"
        }
    }
}

extension TriggerModifier {
    var title: String {
        switch self {
        case .none: "使わない"
        case .shift: "⇧ Shift"
        case .control: "⌃ Control"
        case .command: "⌘ Command"
        }
    }

    var explanation: String {
        switch self {
        case .none:
            "キーでは棚を出しません。"
        case .shift, .control:
            "ドラッグ中にこのキーだけを押すと、カーソルの位置に棚が出ます。振らなくても出せます（マウスを振って出すのをオフにしていても、除外するアプリの中でも使えます）。"
        case .command:
            "ドラッグ中に ⌘ だけを押すと、カーソルの位置に棚が出ます。⌘ は Finder で「移動」を選ぶキーでもあるので、落とすときに押したままだと移動になります。⇧ か ⌃ がおすすめです。"
        }
    }
}

extension ShakeSensitivity {
    var title: String {
        switch self {
        case .light: "軽く"
        case .normal: "ふつう"
        case .firm: "しっかり"
        }
    }

    var explanation: String {
        switch self {
        case .light: "小さく素早く 2〜3 回振るだけで出ます。"
        case .normal: "はっきり 3〜4 回振ると出ます。"
        case .firm: "大きく 4〜5 回振ったときだけ出ます。うっかり出るのを防ぎたいとき向けです。"
        }
    }
}

extension ClipboardShortcut {
    var title: String {
        switch self {
        case .off: "使わない"
        default: symbol
        }
    }

    var explanation: String {
        switch self {
        case .off: "ショートカットでは入れません（メニューバーのメニューと、棚の上の ⌘V では入れられます）。"
        default: "\(symbol) で、コピー中のファイル・画像・テキスト・リンクを棚に入れます。画像はファイルにして入れます。"
        }
    }
}

// MARK: - 選択肢として並べる

extension InboxDestination: SettingsOption {}
extension EdgePreference: SettingsOption {}
extension EdgeRevealTiming: SettingsOption {}
extension EdgeVerticalPosition: SettingsOption {}
extension TriggerModifier: SettingsOption {}
extension ShakeSensitivity: SettingsOption {}
extension ClipboardShortcut: SettingsOption {}
