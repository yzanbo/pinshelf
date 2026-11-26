import PinshelfCore
import SwiftUI

/// 「棚」のタブ: 新しく開く棚の大きさ・画面の端にしまう動き・空になった棚
struct ShelfSettingsView: View {
    @AppStorage(ShelfBehaviorSettings.Key.remembersResizedSize)
    private var remembersResizedSize = ShelfBehaviorSettings.defaults.remembersResizedSize
    @AppStorage(ShelfBehaviorSettings.Key.docksWhenDraggedToEdge)
    private var docksWhenDraggedToEdge = ShelfBehaviorSettings.defaults.docksWhenDraggedToEdge
    @AppStorage(ShelfBehaviorSettings.Key.foldsNewShelves)
    private var foldsNewShelves = ShelfBehaviorSettings.defaults.foldsNewShelves
    @AppStorage(ShelfBehaviorSettings.Key.closesEmptyDockedShelves)
    private var closesEmptyDockedShelves = ShelfBehaviorSettings.defaults.closesEmptyDockedShelves
    @AppStorage(ShelfBehaviorSettings.Key.closesEmptyFloatingShelves)
    private var closesEmptyFloatingShelves = ShelfBehaviorSettings.defaults.closesEmptyFloatingShelves

    var body: some View {
        SettingsPane {
            Section {
                ShelfSizeEditor(
                    "画面の端にあるとき",
                    kind: .docked,
                    info: "画面の端の棚を開いたときの大きさです。浮いた棚を画面の端にしまうと、この大きさになります。"
                )
                ShelfSizeEditor(
                    "浮いているとき",
                    kind: .floating,
                    info: "浮いた棚（振る・キー・メニューで開く棚）の大きさです。画面の端の棚を浮かせると、この大きさになります。"
                )
                Toggle(isOn: $remembersResizedSize) {
                    SettingTitle(
                        "縁をつかんで変えた大きさを、標準にする",
                        info: "オンにすると、棚の縁をつかんで大きさを変えたとき、そのときの置き方（画面の端にあるとき・浮いているとき）の標準もその大きさになります。オフにすると、変えた棚だけがその大きさになります。棚の … メニューの「大きさ」からも、標準にできます。"
                    )
                }
                HStack {
                    Spacer()
                    Button("初期値に戻す") {
                        for kind in ShelfSizing.Kind.allCases {
                            ShelfSizing.resetRemembered(kind, defaults: .standard)
                        }
                    }
                }
            } header: {
                Text("棚の大きさ（標準）")
            } footer: {
                SettingsNote("新しく開く棚の大きさです。棚は、画面の端にあるときと浮いているときの大きさを別々に持ち、しまう・浮かせると、その置き方の大きさに変わります。幅 \(Int(ShelfSizing.minimumSize.width))〜\(Int(ShelfSizing.maximumSize.width))、高さ \(Int(ShelfSizing.minimumSize.height))〜\(Int(ShelfSizing.maximumSize.height)) pt。開いている棚の大きさは、棚の縁をつかんで変えます。")
            }

            Section {
                Toggle(isOn: $docksWhenDraggedToEdge) {
                    SettingTitle(
                        "画面の端まで運んだら、自動でしまう",
                        info: "浮いた棚の見出しをつかんで、画面の左右の端まで運んで放したときの動きです。オフにすると、しまわずに画面の中に収めます。オフでも、見出しのしまうボタン・見出しのダブルクリック・… のメニューからしまえます。"
                    )
                }
                Toggle(isOn: $foldsNewShelves.negated) {
                    SettingTitle(
                        "新しい棚は、画面の端で開いたままにする",
                        info: "画面の端の棚を、細い帯にたたまずに開いたままにするかは、棚ごとに見出しのピンで切り替えます。ここでは、新しく出す棚のピンのはじめの状態を決めます。オンなら開いたまま（ドラッグで出る棚も、最初から開いて出ます）。オフなら、ドラッグやポインタが帯の近くに来たら開き、離れたらすぐにたたみます。すでに出ている棚は変わりません。"
                    )
                }
            } header: {
                Text("画面の端にしまう")
            } footer: {
                SettingsNote("棚の … メニューの「すべての棚」からも切り替えられます。")
            }

            Section {
                Toggle(isOn: $closesEmptyDockedShelves) {
                    SettingTitle(
                        "画面の端の棚が空になったら、閉じる",
                        info: "中身を取り出したり外したりして 0 個になったら、画面の端の棚を閉じます。見出しのピンで開いたままにしている棚も閉じます。オフにすると、件数 0 の帯（開いたままの棚は、空の棚）のまま残します。"
                    )
                }
                Toggle(isOn: $closesEmptyFloatingShelves) {
                    SettingTitle(
                        "浮いた棚が空になったら、閉じる",
                        info: "中身を取り出したり外したりして 0 個になったら、浮いた棚（振る・キー・メニューで開く棚）を閉じます。オフにすると、空の棚のまま残します。"
                    )
                }
            } header: {
                Text("空になった棚")
            } footer: {
                SettingsNote("ポインタが棚の上にあるうちは閉じず、離れたら閉じます（そのあいだは ⌘Z で戻せます）。お気に入りの棚は、空になっても残します。ドラッグで出た棚に何も置かなかったときは、この設定にかかわらず閉じます。")
            }
        }
    }
}

/// 標準の大きさ（幅 × 高さ）を変える欄
private struct ShelfSizeEditor: View {
    let title: String
    let info: String?
    @AppStorage private var width: Double
    @AppStorage private var height: Double

    init(_ title: String, kind: ShelfSizing.Kind, info: String? = nil) {
        self.title = title
        self.info = info
        _width = AppStorage(wrappedValue: Double(ShelfSizing.defaultSize(for: kind).width), ShelfSizing.widthKey(for: kind))
        _height = AppStorage(wrappedValue: Double(ShelfSizing.defaultSize(for: kind).height), ShelfSizing.heightKey(for: kind))
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                dimensionField("幅", value: $width, range: Double(ShelfSizing.minimumSize.width)...Double(ShelfSizing.maximumSize.width))
                Text("×")
                    .foregroundStyle(.secondary)
                dimensionField("高さ", value: $height, range: Double(ShelfSizing.minimumSize.height)...Double(ShelfSizing.maximumSize.height))
                Text("pt")
                    .foregroundStyle(.secondary)
            }
        } label: {
            SettingTitle(title, info: info)
        }
    }

    /// 数字の欄と、10 ずつ増やす・減らすボタン
    private func dimensionField(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        // 範囲の外の値を入れたら、範囲に収める
        let clamped = Binding<Double>(
            get: { min(max(value.wrappedValue, range.lowerBound), range.upperBound) },
            set: { value.wrappedValue = min(max($0.rounded(), range.lowerBound), range.upperBound) }
        )
        return HStack(spacing: 2) {
            TextField(label, value: clamped, format: .number.grouping(.never))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
            Stepper(label, value: clamped, in: range, step: 10)
                .labelsHidden()
        }
        .help(label)
    }
}
