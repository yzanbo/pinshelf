import PinshelfCore
import SwiftUI

/// 「一般」のタブ: 起動・メニューバーとクリップボード・アップデートとバージョン
struct GeneralSettingsView: View {
    let launchAtLogin: LaunchAtLogin
    let updates: AppUpdates

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
                // 更新の機能を使えるビルドだけ（公開鍵の入っていないビルドでは、版だけを出す）
                if updates.isAvailable {
                    Toggle(isOn: Binding(
                        get: { updates.checksAutomatically },
                        set: { updates.setChecksAutomatically($0) }
                    )) {
                        SettingTitle(
                            "新しい版を自動で確かめる",
                            info: "1 日に 1 回、GitHub に新しい版がないかを確かめます。見つかると、メニューバーのアイコンに小さな丸が付き、メニューのいちばん上から更新できます（画面には割り込みません）。オフにしても、メニューの「アップデートを確認…」でいつでも確かめられます。"
                        )
                    }
                }
                LabeledContent("バージョン") {
                    HStack(spacing: 10) {
                        Text(Self.version)
                        if updates.isAvailable {
                            Button("アップデートを確認…") { updates.check() }
                                .disabled(!updates.canCheck)
                        }
                    }
                }
            } header: {
                Text("アップデート")
            } footer: {
                if updates.isAvailable {
                    SettingsNote(Self.lastCheckNote(updates.lastCheckDate))
                } else {
                    SettingsNote("このビルドには、更新ファイルを確かめる鍵が入っていないので、アップデートの確認は使えません。")
                }
            }
        }
        // システム設定で変えられることがあるので、開いたとき・戻ってきたときに問い合わせ直す
        .onAppear(perform: refreshSystemState)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshSystemState()
        }
    }

    /// macOS と更新の仕組みに、今の状態を聞き直す（ログイン項目・自動で確かめるか・最後に確かめた日時）
    private func refreshSystemState() {
        launchAtLogin.refresh()
        updates.refresh()
    }

    /// 最後に確かめた日時の説明
    private static func lastCheckNote(_ date: Date?) -> String {
        guard let date else { return "まだ確かめていません。" }
        return "最後に確かめた日時：\(date.formatted(date: .abbreviated, time: .shortened))"
    }

    /// 版（1.0.0 より前は「（β 版）」を付ける）
    private static var version: String {
        AppVersion.displayName(Bundle.main.shortVersion ?? "—")
    }
}
