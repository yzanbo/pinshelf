import PinshelfCore
import SwiftUI

/// 「一般」のタブ: 起動・メニューバーとクリップボード・バージョン
struct GeneralSettingsView: View {
    let launchAtLogin: LaunchAtLogin

    @AppStorage(ShelfBehaviorSettings.Key.inboxDestination)
    private var inboxDestination: InboxDestination = ShelfBehaviorSettings.defaults.inboxDestination
    @AppStorage(ShelfBehaviorSettings.Key.clipboardShortcut)
    private var clipboardShortcut: ClipboardShortcut = ShelfBehaviorSettings.defaults.clipboardShortcut

    var body: some View {
        SettingsPane {
            Section("起動") {
                Toggle(isOn: Binding(
                    get: { launchAtLogin.isRegistered },
                    set: { launchAtLogin.setEnabled($0) }
                )) {
                    SettingTitle(
                        "ログイン時に起動",
                        info: "Mac にログインしたときに、Pinshelf をメニューバーに出します。システム設定の「一般」→「ログイン項目」でも切り替えられます。"
                    )
                }

                if launchAtLogin.needsApproval {
                    HStack(alignment: .firstTextBaseline) {
                        Label("システム設定の「ログイン項目」で許可すると、ログイン時に起動します。", systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.callout)
                        Spacer()
                        Button("ログイン項目を開く") {
                            launchAtLogin.openSystemSettings()
                        }
                    }
                }

                if let message = launchAtLogin.errorMessage {
                    Label(message, systemImage: "xmark.octagon.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.callout)
                }
            }

            Section("メニューバーとクリップボード") {
                OptionPicker(
                    "入れる棚",
                    info: "メニューバーの Pinshelf のアイコンに落としたときと、「クリップボードから棚へ」で入れるときに、どの棚に入れるかです。アイコンへは、ファイル・テキスト・リンクを落とせます（棚から運んできたものは移動、⌥ を押すとコピー）。",
                    selection: $inboxDestination
                )
                SettingsNote(inboxDestination.explanation)
                OptionPicker(
                    "クリップボードから棚へ",
                    info: "どのアプリを使っていても、このショートカットでコピー中のものを棚に入れます。メニューバーのメニューからも選べます。棚の上では ⌘V で、その棚に貼り付けられます。",
                    selection: $clipboardShortcut
                )
                SettingsNote(clipboardShortcut.explanation)
            }

            Section {
                LabeledContent("バージョン", value: Self.version)
            }
        }
        // システム設定で変えられることがあるので、開いたとき・戻ってきたときに問い合わせ直す
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }

    /// 版（1.0.0 より前は「（β 版）」を付ける）
    private static var version: String {
        AppVersion.displayName(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
    }
}
