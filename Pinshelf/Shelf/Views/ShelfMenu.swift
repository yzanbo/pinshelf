import PinshelfCore
import SwiftUI

/// 棚の見出しの … ボタンと、見出しの右クリックのメニュー
///
/// この棚のこと → 大きさ → すべての棚に効く設定 → 窓の操作、の順に並べ、まとまりごとに区切り線を入れる。
/// サブメニューにするのは、選ぶものが多い「色」だけ（ほかは開いてすぐ見えるように）。
struct ShelfMenu: View {
    let state: ShelfState
    let actions: ShelfActions
    // すべての棚に効く設定（設定画面の「棚」タブと同じもの）
    @AppStorage(ShelfBehaviorSettings.Key.docksWhenDraggedToEdge)
    private var docksWhenDraggedToEdge = ShelfBehaviorSettings.defaults.docksWhenDraggedToEdge
    @AppStorage(ShelfBehaviorSettings.Key.foldsNewShelves)
    private var foldsNewShelves = ShelfBehaviorSettings.defaults.foldsNewShelves

    var body: some View {
        // この棚のこと
        Button("名前を変える…", action: actions.beginRename)
        Picker("色", selection: Binding(get: { state.color }, set: actions.setColor)) {
            ForEach(ShelfColor.allCases, id: \.self) { color in
                Label {
                    Text(color.title)
                } icon: {
                    Image(nsImage: color.menuImage)
                }
                .tag(color)
            }
        }
        Toggle("お気に入り（閉じても残す）", isOn: Binding(get: { state.isFavorite }, set: { _ in actions.toggleFavorite() }))
        // 画面の端にある棚だけ（見出しのピンと同じ）
        if state.isDocked {
            Toggle("画面の端で開いたままにする", isOn: Binding(get: { state.keepsOpen }, set: { _ in actions.toggleKeepsOpen() }))
        }

        Divider()

        // 大きさ（今の置き方の標準が対象。画面の端にあれば画面の端の、浮いていれば浮いているときの標準）
        Section(state.isDocked ? "大きさ（画面の端にあるときの標準）" : "大きさ（浮いているときの標準）") {
            Button("この大きさを標準にする", action: actions.makeSizeDefault)
            Button("標準の大きさに戻す", action: actions.resetSize)
        }

        Divider()

        // すべての棚に効く設定
        Section("すべての棚") {
            Toggle("画面の端まで運んだら、自動でしまう", isOn: $docksWhenDraggedToEdge)
            Toggle("新しい棚は、画面の端で開いたままにする", isOn: $foldsNewShelves.negated)
            Button("設定を開く…", action: actions.openSettings)
        }

        Divider()

        // 棚の窓の操作
        Button(state.isDocked ? "浮かせる" : "画面の端にしまう", action: actions.toggleDock)
        Button(state.isFavorite ? "隠す" : "閉じる", action: actions.close)
    }
}
