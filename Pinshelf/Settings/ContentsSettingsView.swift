import PinshelfCore
import SwiftUI

/// 「中身」のタブ: 取り出したとき・置いたときのふるまいと、棚のキー操作の一覧
struct ContentsSettingsView: View {
    @AppStorage(ShelfBehaviorSettings.Key.removesCopiedItems)
    private var removesCopiedItems = ShelfBehaviorSettings.defaults.removesCopiedItems
    @AppStorage(ShelfBehaviorSettings.Key.stackMultipleDrops)
    private var stackMultipleDrops = ShelfBehaviorSettings.defaults.stackMultipleDrops

    var body: some View {
        SettingsPane {
            Section {
                Toggle(isOn: $stackMultipleDrops) {
                    SettingTitle(
                        "一緒に置いた複数のものを、スタックにまとめる",
                        info: "まとめたものは 1 つとして並び、まとめて取り出せます。棚の上の右クリックで分けたり、あとからまとめたりできます。"
                    )
                }
                Toggle(isOn: $removesCopiedItems) {
                    SettingTitle(
                        "コピーで取り出したものも、棚から外す",
                        info: "オフのときは、コピーで取り出したものを棚に残します。移動で取り出したもの（元の場所からなくなったもの）は、この設定にかかわらず棚から外します。ロックしたもの（右クリックか ⌘L）は、どちらでも棚に残ります。"
                    )
                }
            } header: {
                Text("置く・取り出す")
            }

            Section("棚のキー操作") {
                KeyHintRow(action: "Quick Look で見る", keys: "スペース・⌘Y")
                KeyHintRow(action: "開く", keys: "ダブルクリック・⌘O")
                KeyHintRow(action: "すべて選ぶ", keys: "⌘A")
                KeyHintRow(action: "クリップボードから貼り付ける", keys: "⌘V")
                KeyHintRow(action: "ロックする・外す", keys: "⌘L")
                KeyHintRow(action: "棚から外す", keys: "delete")
                KeyHintRow(action: "外したものを戻す", keys: "⌘Z")
                KeyHintRow(action: "コピーで取り出す", keys: "⌥ を押しながらドラッグ")
            }
        }
    }
}
