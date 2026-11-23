import PinshelfCore
import SwiftUI

/// 「出し方」のタブ: ドラッグ中に棚を出すきっかけ（画面の端・振る・キー）
struct TriggerSettingsView: View {
    @AppStorage(TriggerSettings.Key.triggerMode)
    private var triggerMode: TriggerMode = TriggerSettings.defaults.triggerMode
    @AppStorage(TriggerSettings.Key.edgePreference)
    private var edgePreference: EdgePreference = TriggerSettings.defaults.edgePreference
    @AppStorage(TriggerSettings.Key.edgeRevealTiming)
    private var edgeRevealTiming: EdgeRevealTiming = TriggerSettings.defaults.edgeRevealTiming
    @AppStorage(TriggerSettings.Key.edgeVerticalPosition)
    private var edgeVerticalPosition: EdgeVerticalPosition = TriggerSettings.defaults.edgeVerticalPosition
    @AppStorage(TriggerSettings.Key.shakeSensitivity)
    private var shakeSensitivity: ShakeSensitivity = TriggerSettings.defaults.shakeSensitivity
    @AppStorage(TriggerSettings.Key.triggerModifier)
    private var triggerModifier: TriggerModifier = TriggerSettings.defaults.triggerModifier

    var body: some View {
        SettingsPane {
            Section {
                Toggle(isOn: usesEdge) {
                    SettingTitle(
                        "ドラッグを始めたら、画面の端に棚を出す",
                        info: "ドラッグを始めると、画面の端に棚が出ます。細い帯で出たときは、帯の近くまで運ぶと開きます（「棚」タブの「新しい棚は、画面の端で開いたままにする」がオンなら、最初から開いて出ます）。中身があれば、ドラッグを終えても棚は画面の端に残ります。棚は振って出す棚と同じもので、閉じる・浮かせる・名前や色を付けることもできます。"
                    )
                }
                Group {
                    OptionPicker("出す端", selection: $edgePreference)
                    OptionPicker("出すとき", selection: $edgeRevealTiming)
                    OptionPicker("出す高さ", selection: $edgeVerticalPosition)
                    SettingsNote(edgeVerticalPosition.explanation)
                }
                .disabled(!triggerMode.usesEdge)
            } header: {
                Text("画面の端に出す")
            } footer: {
                SettingsNote("出す端・出すとき・出す高さは、新しく棚を出すときに使います。一度出た棚は、運んだ場所にとどまり、ドラッグやポインタが帯の近くに来たときに開きます。画面の端に棚がすでにあるときは、新しくは出しません。メニューバーの「画面の端の棚を開く」は、オフにしていても使えます。")
            }

            Section {
                Toggle(isOn: usesShake) {
                    SettingTitle(
                        "ドラッグ中にマウスを振ったら、棚を出す",
                        info: "ドラッグ中にマウスを左右（または上下）に振ると、カーソルの位置に棚が出ます。"
                    )
                }
                Group {
                    OptionPicker("感度", selection: $shakeSensitivity)
                        .pickerStyle(.segmented)
                    SettingsNote(shakeSensitivity.explanation)
                }
                .disabled(!triggerMode.usesShake)
                OptionPicker("ドラッグ中に押すキー", selection: $triggerModifier)
                SettingsNote(triggerModifier.explanation)
            } header: {
                Text("カーソルの位置に出す")
            } footer: {
                SettingsNote("振る・キーのどちらでも、1 回のドラッグで出す棚は 1 つまでです。何も置かずにドラッグを終えると閉じます。")
            }
        }
    }

    private var usesEdge: Binding<Bool> {
        Binding(
            get: { triggerMode.usesEdge },
            set: { triggerMode = TriggerMode(usesEdge: $0, usesShake: triggerMode.usesShake) }
        )
    }

    private var usesShake: Binding<Bool> {
        Binding(
            get: { triggerMode.usesShake },
            set: { triggerMode = TriggerMode(usesEdge: triggerMode.usesEdge, usesShake: $0) }
        )
    }
}
